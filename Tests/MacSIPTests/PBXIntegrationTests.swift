import XCTest

@testable import MacSIP

/// Tier-2 integration tests against the real Asterisk TestPBX (Docker).
/// Verifies what the pjsua local loop cannot: REGISTER + digest auth,
/// failure detail, and calls routed THROUGH a PBX with echo-verified media.
/// Gated by MACSIP_PBX=1 (scripts/integration-test.sh starts the PBX check).
/// Credentials below are throwaway TestPBX-only extensions (TestPBX/).
@MainActor
final class PBXIntegrationTests: XCTestCase {
    private static let pbxHost = "127.0.0.1"
    private static let enginePort = 5065

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

    // MARK: Helpers

    private func configure(user: String, password: String) async throws {
        try await engine.configureAccount(
            SIPAccountConfig(label: "pbx", domain: Self.pbxHost, username: user),
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

    // MARK: Tests

    /// SPEC §1 / acceptance 7: REGISTER with digest auth against the PBX.
    func testRegistrationSucceeds() async throws {
        try await configure(user: "101", password: "test101pw")  // secretscan:allow throwaway TestPBX cred
        let state = try await waitForRegistration(timeout: 15) {
            if case .registered = $0 { return true }
            return false
        }
        guard case .registered(let expiresAt) = state else {
            return XCTFail("expected registered, got \(state)")
        }
        XCTAssertNotNil(expiresAt, "registrar should report an expiry")
    }

    /// Wrong password must fail with auth detail, not a generic error.
    func testWrongPasswordFailsWithAuthDetail() async throws {
        try await configure(user: "102", password: "definitely-wrong")
        let state = try await waitForRegistration(timeout: 20) {
            if case .failed = $0 { return true }
            return false
        }
        guard case .failed(let code, _) = state else {
            return XCTFail("expected failed, got \(state)")
        }
        XCTAssertEqual(code, 401, "Asterisk rejects bad digest credentials with 401")
        XCTAssertTrue(
            state.userFacingDescription.contains("Authentication required"),
            "got: \(state.userFacingDescription)")
    }

    /// Registered call THROUGH the PBX to the echo app: INVITE is
    /// challenged (digest), media flows both ways via Asterisk's RTP relay.
    func testCallThroughPBXWithEchoMedia() async throws {
        try await configure(user: "101", password: "test101pw")  // secretscan:allow throwaway TestPBX cred
        _ = try await waitForRegistration(timeout: 15) {
            if case .registered = $0 { return true }
            return false
        }

        let id = try await engine.makeCall(to: "sip:600@\(Self.pbxHost)")
        _ = try await waitForUpdate(timeout: 15) {
            $0.id == id && $0.phase == .connected(HoldState.none)
        }

        try await Task.sleep(nanoseconds: 3_000_000_000)
        let stats = await engine.rtpStats(for: id)
        XCTAssertGreaterThan(stats.tx, 20, "expected RTP to the PBX, got \(stats.tx)")
        XCTAssertGreaterThan(stats.rx, 20, "expected echoed RTP from the PBX, got \(stats.rx)")

        engine.hangup(id)
        _ = try await waitForUpdate(timeout: 8) {
            if case .disconnected = $0.phase { return $0.id == id }
            return false
        }
    }

    /// PBX failure generators: busy must surface 486 (mapped to "Busy").
    func testBusyOutcome() async throws {
        try await configure(user: "101", password: "test101pw")  // secretscan:allow throwaway TestPBX cred
        _ = try await waitForRegistration(timeout: 15) {
            if case .registered = $0 { return true }
            return false
        }
        let id = try await engine.makeCall(to: "sip:486@\(Self.pbxHost)")
        let final = try await waitForUpdate(timeout: 20) {
            if case .disconnected = $0.phase { return $0.id == id }
            return false
        }
        guard case .disconnected(let sipCode, _) = final.phase else { return XCTFail() }
        XCTAssertEqual(sipCode, 486)
        XCTAssertEqual(DisconnectReason.from(sipCode: sipCode, reasonText: "", wasConnected: false), .busy)
    }

    /// Unknown destination must surface 404 → "Number not found" (SPEC §4).
    func testNotFoundOutcome() async throws {
        try await configure(user: "101", password: "test101pw")  // secretscan:allow throwaway TestPBX cred
        _ = try await waitForRegistration(timeout: 15) {
            if case .registered = $0 { return true }
            return false
        }
        let id = try await engine.makeCall(to: "sip:99999@\(Self.pbxHost)")
        let final = try await waitForUpdate(timeout: 20) {
            if case .disconnected = $0.phase { return $0.id == id }
            return false
        }
        guard case .disconnected(let sipCode, _) = final.phase else { return XCTFail() }
        XCTAssertEqual(sipCode, 404)
        XCTAssertEqual(SIPStatusMapping.userFacingResult(forStatusCode: sipCode), "Number not found")
    }
}
