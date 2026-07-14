import XCTest

@testable import MacSIP

/// Milestone 2 transport-security verification against the Asterisk
/// TestPBX: TCP registration, TLS certificate validation (must FAIL on
/// the PBX's untrusted self-signed cert by default; succeeds only with
/// the visible per-account override), and SDES-SRTP policy both ways.
/// Gated like PBXIntegrationTests (MACSIP_PBX=1 via integration-test.sh).
@MainActor
final class TransportSecurityTests: XCTestCase {
    private static let pbxHost = "127.0.0.1"
    private static let enginePort = 5066

    private var engine: SIPEngine!
    private var registrations: [RegistrationState] = []
    private var updates: [SIPEngine.CallUpdate] = []

    override func setUp() async throws {
        guard ProcessInfo.processInfo.environment["MACSIP_PBX"] == "1" else {
            throw XCTSkip("PBX tests run via scripts/integration-test.sh with the TestPBX up")
        }
        engine = SIPEngine()
        registrations = []
        updates = []
        engine.onEvent = { [weak self] event in
            switch event {
            case .registration(let state): self?.registrations.append(state)
            case .callChanged(let update): self?.updates.append(update)
            case .incomingCall(let update): self?.updates.append(update)
            }
        }
        try await engine.start(port: Self.enginePort, nullAudio: true)
    }

    override func tearDown() async throws {
        if let engine {
            await engine.stop()
        }
        engine = nil
    }

    private func configure(
        user: String, password: String, transport: SIPAccountConfig.Transport,
        encryption: SIPAccountConfig.MediaEncryption = .none,
        tlsVerificationDisabled: Bool = false
    ) async throws {
        try await engine.configureAccount(
            SIPAccountConfig(
                label: "pbx", domain: Self.pbxHost, username: user, transport: transport,
                mediaEncryption: encryption, tlsVerificationDisabled: tlsVerificationDisabled),
            password: password)
    }

    private func waitForRegistration(
        timeout: TimeInterval, where predicate: @escaping (RegistrationState) -> Bool
    ) async throws -> RegistrationState {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let match = registrations.last(where: predicate) { return match }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTFail("Timed out; registration events: \(registrations)")
        throw XCTSkip("wait failed")
    }

    private func waitForUpdate(
        timeout: TimeInterval, where predicate: @escaping (SIPEngine.CallUpdate) -> Bool
    ) async throws -> SIPEngine.CallUpdate {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let match = updates.last(where: predicate) { return match }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTFail("Timed out; call updates: \(updates.map(\.phase))")
        throw XCTSkip("wait failed")
    }

    // MARK: Transports

    func testTCPRegistration() async throws {
        try await configure(user: "101", password: "test101pw", transport: .tcp)  // secretscan:allow throwaway TestPBX cred
        let state = try await waitForRegistration(timeout: 15) {
            if case .registered = $0 { return true }
            return false
        }
        guard case .registered = state else { return XCTFail("expected registered, got \(state)") }
    }

    /// SPEC §2 / CLAUDE.md: TLS verification is ON by default and must
    /// reject the TestPBX's self-signed certificate.
    func testTLSRejectsUntrustedCertificateByDefault() async throws {
        try await configure(user: "101", password: "test101pw", transport: .tls)  // secretscan:allow throwaway TestPBX cred
        let state = try await waitForRegistration(timeout: 20) {
            if case .failed = $0 { return true }
            return false
        }
        guard case .failed(let code, let reason) = state else {
            return XCTFail("expected failure, got \(state)")
        }
        XCTAssertNotEqual(code, 401, "must fail on TLS trust, not auth")
        XCTAssertFalse(reason.isEmpty, "failure must carry detail for the user")
        XCTAssertFalse(
            registrations.contains { if case .registered = $0 { return true } else { return false } },
            "must NEVER register through an untrusted certificate by default")
    }

    /// The per-account, visible, default-off override (SPEC §2) — and the
    /// proof that encrypted signaling works end-to-end once trusted.
    func testTLSWithVisibleInsecureOverrideRegisters() async throws {
        try await configure(
            user: "101", password: "test101pw", transport: .tls, tlsVerificationDisabled: true)  // secretscan:allow throwaway TestPBX cred
        let state = try await waitForRegistration(timeout: 20) {
            if case .registered = $0 { return true }
            return false
        }
        guard case .registered = state else { return XCTFail("expected registered, got \(state)") }
    }

    // MARK: Multiple accounts (SPEC §1: switch without restart)

    /// Reconfiguring to a different account on the RUNNING engine must
    /// re-register as the new identity — no engine restart involved.
    func testAccountSwitchWithoutRestart() async throws {
        try await configure(user: "101", password: "test101pw", transport: .udp)  // secretscan:allow throwaway TestPBX cred
        _ = try await waitForRegistration(timeout: 15) {
            if case .registered = $0 { return true }
            return false
        }

        registrations.removeAll()
        try await configure(user: "102", password: "test102pw", transport: .udp)  // secretscan:allow throwaway TestPBX cred
        let state = try await waitForRegistration(timeout: 15) {
            if case .registered = $0 { return true }
            return false
        }
        guard case .registered = state else { return XCTFail("expected re-registration as 102") }

        // The switched account must be the one making calls now: 102 can
        // reach the echo extension.
        let id = try await engine.makeCall(to: "sip:600@\(Self.pbxHost)")
        _ = try await waitForUpdate(timeout: 15) {
            $0.id == id && $0.phase == .connected(HoldState.none)
        }
        engine.hangup(id)
        _ = try await waitForUpdate(timeout: 8) {
            if case .disconnected = $0.phase { return $0.id == id }
            return false
        }
    }

    // MARK: ICE

    /// ICE-enabled call against the PBX's ice_support endpoint: candidates
    /// negotiate over loopback and media must still flow both ways.
    func testICECallWithMedia() async throws {
        try await engine.configureAccount(
            SIPAccountConfig(
                label: "ice", domain: Self.pbxHost, username: "102", iceEnabled: true),
            password: "test102pw")  // secretscan:allow throwaway TestPBX cred
        _ = try await waitForRegistration(timeout: 15) {
            if case .registered = $0 { return true }
            return false
        }
        let id = try await engine.makeCall(to: "sip:600@\(Self.pbxHost)")
        _ = try await waitForUpdate(timeout: 20) {
            $0.id == id && $0.phase == .connected(HoldState.none)
        }
        try await Task.sleep(nanoseconds: 3_000_000_000)
        let stats = await engine.rtpStats(for: id)
        XCTAssertGreaterThan(stats.tx, 20, "expected RTP out via ICE path, got \(stats.tx)")
        XCTAssertGreaterThan(stats.rx, 20, "expected echoed RTP via ICE path, got \(stats.rx)")
        engine.hangup(id)
        _ = try await waitForUpdate(timeout: 8) {
            if case .disconnected = $0.phase { return $0.id == id }
            return false
        }
    }

    // MARK: SRTP (SDES)
    // The positive SRTP case (mandatory ↔ SRTP peer, media verified) lives
    // in SIPIntegrationTests.testSRTPMandatoryCallWithSRTPPeer — the
    // TestPBX's Asterisk image ships without res_srtp and 488s all SAVP
    // offers (docs/INTEROP_TEST_MATRIX.md).

    /// Mandatory SRTP against an endpoint that cannot encrypt must FAIL,
    /// never silently fall back to clear RTP.
    func testSRTPMandatoryFailsAgainstPlainEndpoint() async throws {
        try await configure(
            user: "101", password: "test101pw", transport: .udp, encryption: .srtpMandatory)  // secretscan:allow throwaway TestPBX cred
        _ = try await waitForRegistration(timeout: 15) {
            if case .registered = $0 { return true }
            return false
        }
        let id = try await engine.makeCall(to: "sip:600@\(Self.pbxHost)")
        let final = try await waitForUpdate(timeout: 20) {
            if case .disconnected = $0.phase { return $0.id == id }
            return false
        }
        guard case .disconnected(let sipCode, _) = final.phase else { return XCTFail() }
        XCTAssertNotEqual(sipCode, 200, "call must not succeed in the clear")
        XCTAssertFalse(
            updates.contains { $0.id == id && $0.phase == .connected(HoldState.none) },
            "mandatory SRTP must never connect unencrypted")
    }
}
