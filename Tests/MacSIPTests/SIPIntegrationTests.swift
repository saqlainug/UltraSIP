import XCTest

@testable import MacSIP

/// End-to-end SIP/RTP verification against a REAL local peer: the pjsua
/// CLI from our pinned PJSIP build, speaking actual SIP/RTP over localhost
/// UDP. A 200 OK is never treated as success — RTP packet counters and
/// peer-side DTMF logs are asserted (CLAUDE.md media verification).
///
/// Environment-gated: runs only via scripts/integration-test.sh
/// (MACSIP_INTEGRATION=1 + MACSIP_PJSUA=<path>). Registration against a
/// registrar needs the TestPBX (Docker) and is skipped here honestly.
@MainActor
final class SIPIntegrationTests: XCTestCase {
    private static let enginePort = 5064
    private static let peerPort = 5062

    private var engine: SIPEngine!
    private var peer: PJSUAPeer!
    private var updates: [SIPEngine.CallUpdate] = []
    private var incoming: [SIPEngine.CallUpdate] = []

    override func setUp() async throws {
        guard ProcessInfo.processInfo.environment["MACSIP_INTEGRATION"] == "1" else {
            throw XCTSkip("Integration tests run via scripts/integration-test.sh (MACSIP_INTEGRATION=1)")
        }
        guard let pjsuaPath = ProcessInfo.processInfo.environment["MACSIP_PJSUA"],
            FileManager.default.isExecutableFile(atPath: pjsuaPath)
        else {
            throw XCTSkip("MACSIP_PJSUA not set or not executable; run scripts/build-pjsip.sh first")
        }
        peer = PJSUAPeer(binary: pjsuaPath, port: Self.peerPort)
        engine = SIPEngine()
        updates = []
        incoming = []
        engine.onEvent = { [weak self] event in
            switch event {
            case .callChanged(let update): self?.updates.append(update)
            case .incomingCall(let update): self?.incoming.append(update)
            case .registration: break
            }
        }
        try await engine.start(port: Self.enginePort, nullAudio: true)
        try await engine.configureAccount(
            SIPAccountConfig(
                label: "loop", domain: "127.0.0.1", username: "mactest",
                registrationEnabled: false),
            password: "")
    }

    override func tearDown() async throws {
        peer?.terminate()
        if let engine {
            await engine.stop()
        }
        engine = nil
    }

    // MARK: Helpers

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

    private func waitForIncoming(timeout: TimeInterval) async throws -> SIPEngine.CallUpdate {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let first = incoming.first { return first }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTFail("Timed out waiting for incoming call")
        throw XCTSkip("wait failed")
    }

    // MARK: Tests

    /// Outgoing call: INVITE → 200 → bidirectional RTP (peer loops our
    /// packets back) → DTMF received by peer → hold/resume → hangup.
    func testOutgoingCallMediaDTMFHoldHangup() async throws {
        try peer.launch(extraArgs: ["--auto-answer=200", "--auto-loop"])
        try await peer.waitUntilReady()

        let id = try await engine.makeCall(to: "sip:loop@127.0.0.1:\(Self.peerPort)")
        _ = try await waitForUpdate(timeout: 10) {
            $0.id == id && $0.phase == .connected(HoldState.none)
        }

        // Media verification: RTP must flow BOTH ways (SPEC: 200 OK ≠ working call).
        try await Task.sleep(nanoseconds: 3_000_000_000)
        let stats = await engine.rtpStats(for: id)
        XCTAssertGreaterThan(stats.tx, 20, "expected outbound RTP packets, got \(stats.tx)")
        XCTAssertGreaterThan(stats.rx, 20, "expected inbound (looped) RTP packets, got \(stats.rx)")

        // DTMF: assert the PEER actually received the digit (RFC 4733).
        engine.sendDTMF("5", to: id)
        try await peer.waitForOutput(containing: "DTMF", timeout: 8)

        // Hold → local-hold state; resume → active again.
        engine.setHold(id, held: true)
        _ = try await waitForUpdate(timeout: 8) {
            $0.id == id && $0.phase == .connected(.local)
        }
        engine.setHold(id, held: false)
        _ = try await waitForUpdate(timeout: 8) {
            $0.id == id && $0.phase == .connected(HoldState.none)
        }

        engine.hangup(id)
        let final = try await waitForUpdate(timeout: 8) {
            if case .disconnected = $0.phase { return $0.id == id }
            return false
        }
        if case .disconnected = final.phase {} else { XCTFail("expected disconnected, got \(final.phase)") }
    }

    /// Incoming call from the peer: ring → answer → RTP both ways → remote hangup.
    func testIncomingCallAnswerMediaRemoteHangup() async throws {
        try peer.launch(extraArgs: ["--auto-loop"])
        try await peer.waitUntilReady()

        peer.send(command: "m")
        peer.send(command: "sip:mactest@127.0.0.1:\(Self.enginePort)")

        let ringing = try await waitForIncoming(timeout: 10)
        // The peer identifies itself by its own contact (often the LAN IP,
        // not 127.0.0.1) — only the URI shape is asserted.
        XCTAssertTrue(ringing.remoteURI.hasPrefix("sip:"), "unexpected remote \(ringing.remoteURI)")

        engine.answer(ringing.id)
        _ = try await waitForUpdate(timeout: 10) {
            $0.id == ringing.id && $0.phase == .connected(HoldState.none)
        }

        try await Task.sleep(nanoseconds: 2_000_000_000)
        let stats = await engine.rtpStats(for: ringing.id)
        XCTAssertGreaterThan(stats.tx, 20, "expected outbound RTP, got \(stats.tx)")
        XCTAssertGreaterThan(stats.rx, 20, "expected inbound RTP, got \(stats.rx)")

        peer.send(command: "h")
        _ = try await waitForUpdate(timeout: 8) {
            if case .disconnected = $0.phase { return $0.id == ringing.id }
            return false
        }
    }

    /// Incoming call rejected as busy: the peer must see 486.
    func testIncomingCallRejectBusy() async throws {
        try peer.launch(extraArgs: [])
        try await peer.waitUntilReady()

        peer.send(command: "m")
        peer.send(command: "sip:mactest@127.0.0.1:\(Self.enginePort)")

        let ringing = try await waitForIncoming(timeout: 10)
        engine.reject(ringing.id, busy: true)
        try await peer.waitForOutput(containing: "Busy", timeout: 8)
    }
}

/// Wraps a pjsua CLI process as a real SIP peer on localhost.
@MainActor
final class PJSUAPeer {
    private let binary: String
    private let port: Int
    private let process = Process()
    private let stdinPipe = Pipe()
    private let stdoutPipe = Pipe()
    private let outputBuffer = OutputBuffer()

    init(binary: String, port: Int) {
        self.binary = binary
        self.port = port
    }

    func launch(extraArgs: [String]) throws {
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments =
            [
                "--null-audio",
                "--local-port=\(port)",
                "--no-tcp",
                "--app-log-level=3",
            ] + extraArgs
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stdoutPipe
        let buffer = outputBuffer
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let text = String(data: data, encoding: .utf8) {
                buffer.append(text)
            }
        }
        try process.run()
    }

    /// pjsua prints its startup banner + "Ready" console marker; wait for
    /// the account/transport lines before dialing at it.
    func waitUntilReady() async throws {
        try await waitForOutput(containing: "Ready:", timeout: 10)
    }

    func send(command: String) {
        stdinPipe.fileHandleForWriting.write(Data((command + "\n").utf8))
    }

    func waitForOutput(containing needle: String, timeout: TimeInterval) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if outputBuffer.contains(needle) { return }
            try await Task.sleep(nanoseconds: 150_000_000)
        }
        XCTFail("pjsua output never contained '\(needle)'. Tail:\n\(outputBuffer.tail(1200))")
        throw XCTSkip("peer wait failed")
    }

    func terminate() {
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        if process.isRunning {
            send(command: "q")
            process.terminate()
        }
    }
}

/// Thread-safe accumulator for peer output (readability handler runs on a
/// background queue).
final class OutputBuffer: @unchecked Sendable {
    private var text = ""
    private let lock = NSLock()

    func append(_ chunk: String) {
        lock.withLock { text += chunk }
    }

    func contains(_ needle: String) -> Bool {
        lock.withLock { text.contains(needle) }
    }

    func tail(_ count: Int) -> String {
        lock.withLock { String(text.suffix(count)) }
    }
}
