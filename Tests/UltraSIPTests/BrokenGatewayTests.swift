import XCTest

@testable import UltraSIP

/// Reproduces a live interop failure: a gateway that sends a RELIABLE 180
/// (Require: 100rel) whose SDP body is blank — `c=IN IP4 0.0.0.0`, zero
/// m= lines. RFC 3262 makes that body the formal answer, so without the
/// usp-sdp-guard module the call dies with PJMEDIA_SDPNEG_ENOMEDIA before
/// the real answer in the 200 OK arrives. The scripted UAS below speaks
/// raw SIP over UDP exactly as the observed switch did.
@MainActor
final class BrokenGatewayTests: XCTestCase {
    private static let enginePort = 5066
    private static let gatewayPort = 5068

    private var engine: SIPEngine!
    private var gateway: BlankSDPGateway!
    private var updates: [SIPEngine.CallUpdate] = []

    override func setUp() async throws {
        guard ProcessInfo.processInfo.environment["ULTRASIP_INTEGRATION"] == "1" else {
            throw XCTSkip("Integration tests run via scripts/integration-test.sh (ULTRASIP_INTEGRATION=1)")
        }
        gateway = BlankSDPGateway(port: Self.gatewayPort)
        engine = SIPEngine()
        updates = []
        engine.onEvent = { [weak self] event in
            if case .callChanged(let update) = event { self?.updates.append(update) }
        }
        try await engine.start(port: Self.enginePort, nullAudio: true)
        try await engine.configureAccount(
            SIPAccountConfig(
                label: "gw", domain: "127.0.0.1", username: "mactest",
                registrationEnabled: false),
            password: "")
    }

    override func tearDown() async throws {
        gateway?.stop()
        if let engine { await engine.stop() }
        engine = nil
    }

    private func waitForUpdate(
        timeout: TimeInterval, where predicate: @escaping (SIPEngine.CallUpdate) -> Bool
    ) async throws -> SIPEngine.CallUpdate {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let match = updates.last(where: predicate) { return match }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTFail("Timed out waiting for call update; got: \(updates.map(\.phase))")
        throw XCTSkip("wait failed")
    }

    /// The blank early SDP must NOT be treated as the negotiation answer:
    /// the call must survive to the 200 OK's real answer and connect.
    func testBlankSDPInReliable180DoesNotKillCall() async throws {
        try gateway.start()

        let id = try await engine.makeCall(to: "sip:900@127.0.0.1:\(Self.gatewayPort)")
        let connected = try await waitForUpdate(timeout: 10) {
            $0.id == id && $0.phase == .connected(HoldState.none)
        }
        XCTAssertEqual(connected.id, id)
        XCTAssertTrue(gateway.sawPRACK, "reliable 180 must still be PRACKed after body strip")

        // The pre-guard failure mode was an engine-initiated CANCEL with
        // "SDP negotiation failed" — reaching connected proves it's gone.
        engine.hangup(id)
        _ = try await waitForUpdate(timeout: 8) {
            if case .disconnected = $0.phase { return $0.id == id }
            return false
        }
        XCTAssertTrue(gateway.sawBYE, "hangup must reach the gateway as BYE")
    }
}

/// Minimal scripted UAS speaking raw SIP over a UDP socket. Responds to an
/// INVITE with 100 → reliable 180 carrying a BLANK SDP (the interop bug
/// under test) → 200 OK to the PRACK → 200 OK to the INVITE with a real
/// audio answer → 200 OK to the BYE. Loopback only; no RTP is sent.
final class BlankSDPGateway: @unchecked Sendable {
    private let port: Int
    private let queue = DispatchQueue(label: "com.ultranet.ultrasip.tests.blank-sdp-gateway")
    private let lock = NSLock()
    private var fd: Int32 = -1  // guarded by lock (stop() races receiveLoop otherwise)
    private var running = false
    private var prackSeen = false
    private var byeSeen = false
    /// Headers captured from the INVITE — its 200 OK must carry the
    /// INVITE's Via branch and CSeq, not the PRACK's (RFC 3261 §17.2.1).
    private var inviteHeaders = ""

    var sawPRACK: Bool { lock.withLock { prackSeen } }
    var sawBYE: Bool { lock.withLock { byeSeen } }

    init(port: Int) {
        self.port = port
    }

    func start() throws {
        let socketFD = socket(AF_INET, SOCK_DGRAM, 0)
        guard socketFD >= 0 else { throw POSIXError(.EMFILE) }
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(UInt16(port).bigEndian)
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        let bindResult = withUnsafePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            close(socketFD)
            throw POSIXError(.EADDRINUSE)
        }
        lock.withLock {
            fd = socketFD
            running = true
        }
        queue.async { [weak self] in self?.receiveLoop() }
    }

    func stop() {
        let socketFD: Int32 = lock.withLock {
            running = false
            let current = fd
            fd = -1
            return current
        }
        // Closing unblocks the loop's recvfrom with EBADF; it then sees
        // running == false and exits.
        if socketFD >= 0 { close(socketFD) }
    }

    private func receiveLoop() {
        var buffer = [UInt8](repeating: 0, count: 65536)
        while true {
            let socketFD: Int32 = lock.withLock { running ? fd : -1 }
            guard socketFD >= 0 else { return }
            var sender = sockaddr_in()
            var senderLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let received = withUnsafeMutablePointer(to: &sender) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    recvfrom(socketFD, &buffer, buffer.count, 0, $0, &senderLen)
                }
            }
            guard received > 0,
                let message = String(bytes: buffer[0..<received], encoding: .utf8)
            else { continue }
            for response in responses(to: message) {
                _ = response.withCString { cString in
                    withUnsafePointer(to: &sender) { pointer in
                        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                            sendto(socketFD, cString, strlen(cString), 0, $0, senderLen)
                        }
                    }
                }
            }
        }
    }

    private func header(_ name: String, of message: String) -> String {
        for line in message.components(separatedBy: "\r\n") {
            if line.lowercased().hasPrefix(name.lowercased() + ":") {
                return line
            }
        }
        return ""
    }

    /// Mirrored response headers per RFC 3261 §8.2.6.2 (Via/From/Call-ID/
    /// CSeq copied; To gets our tag on non-100 responses).
    private func mirrored(_ message: String, toTag: Bool) -> String {
        let to = header("To", of: message)
        return [
            header("Via", of: message),
            header("From", of: message),
            toTag ? to + ";tag=gw180" : to,
            header("Call-ID", of: message),
            header("CSeq", of: message),
        ].joined(separator: "\r\n")
    }

    private func responses(to message: String) -> [String] {
        let blankSDP = "v=0\r\no=- 1 1 IN IP4 185.0.0.1\r\ns=-\r\nc=IN IP4 0.0.0.0\r\nt=0 0\r\n"
        let answerSDP =
            "v=0\r\no=- 2 2 IN IP4 127.0.0.1\r\ns=-\r\nc=IN IP4 127.0.0.1\r\nt=0 0\r\n"
            + "m=audio 4666 RTP/AVP 0\r\na=rtpmap:0 PCMU/8000\r\na=sendrecv\r\n"
        let contact = "Contact: <sip:gw@127.0.0.1:\(port)>"

        if message.hasPrefix("INVITE ") {
            lock.withLock { inviteHeaders = mirrored(message, toTag: true) }
            let trying = "SIP/2.0 100 Trying\r\n\(mirrored(message, toTag: false))\r\nContent-Length: 0\r\n\r\n"
            let ringing =
                "SIP/2.0 180 Ringing\r\n\(mirrored(message, toTag: true))\r\n\(contact)\r\n"
                + "Require: 100rel\r\nRSeq: 1\r\nContent-Type: application/sdp\r\n"
                + "Content-Length: \(blankSDP.utf8.count)\r\n\r\n\(blankSDP)"
            return [trying, ringing]
        }
        if message.hasPrefix("PRACK ") {
            let invite = lock.withLock { () -> String in
                prackSeen = true
                return inviteHeaders
            }
            let prackOK = "SIP/2.0 200 OK\r\n\(mirrored(message, toTag: false))\r\nContent-Length: 0\r\n\r\n"
            let ok =
                "SIP/2.0 200 OK\r\n\(invite)\r\n\(contact)\r\n"
                + "Content-Type: application/sdp\r\nContent-Length: \(answerSDP.utf8.count)\r\n\r\n\(answerSDP)"
            return [prackOK, ok]
        }
        if message.hasPrefix("BYE ") {
            lock.withLock { byeSeen = true }
            return ["SIP/2.0 200 OK\r\n\(mirrored(message, toTag: false))\r\nContent-Length: 0\r\n\r\n"]
        }
        return []  // ACK and retransmissions need no reply
    }
}
