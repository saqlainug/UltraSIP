import XCTest

@testable import UltraSIP

final class SecurityTests: XCTestCase {
    // MARK: LogRedactor (CLAUDE.md: redaction has automated tests — extend
    // this suite with every new log site)

    func testDTMFNeverAppearsInLogText() {
        let redacted = LogRedactor.redactDTMF("1234#*")
        XCTAssertFalse(redacted.contains("1234"))
        XCTAssertEqual(redacted, "<6 DTMF digits>")
        XCTAssertEqual(LogRedactor.redactDTMF("5"), "<1 DTMF digit>")
    }

    func testURIPasswordFragmentRedacted() {
        let uri = "sip:alice@pbx.example.com;password=hunter2"
        let redacted = LogRedactor.redactURI(uri)
        XCTAssertFalse(redacted.contains("hunter2"))
        XCTAssertTrue(redacted.contains("password=<redacted>"))
        XCTAssertEqual(LogRedactor.redactURI("sip:alice@pbx.example.com"), "sip:alice@pbx.example.com")
    }

    func testDigestResponseRedacted() {
        let header = #"Digest username="alice", realm="pbx", nonce="abc", response="deadbeef""#
        let redacted = LogRedactor.redactAuthorizationHeader(header)
        XCTAssertFalse(redacted.contains("deadbeef"))
        XCTAssertTrue(redacted.contains("response=<redacted>"))
    }

    // MARK: DisconnectReason mapping (docs/SIP_STATE_MACHINES.md tables)

    func testDisconnectReasonMapping() {
        XCTAssertEqual(DisconnectReason.from(sipCode: 487, reasonText: "", wasConnected: false), .cancelled)
        XCTAssertEqual(DisconnectReason.from(sipCode: 486, reasonText: "", wasConnected: false), .busy)
        XCTAssertEqual(DisconnectReason.from(sipCode: 600, reasonText: "", wasConnected: false), .busy)
        XCTAssertEqual(DisconnectReason.from(sipCode: 603, reasonText: "", wasConnected: false), .rejected)
        XCTAssertEqual(
            DisconnectReason.from(sipCode: 404, reasonText: "Not Found", wasConnected: false),
            .failed(code: 404, reason: "Not Found"))
        // Once connected, any BYE is a normal end regardless of code.
        XCTAssertEqual(DisconnectReason.from(sipCode: 200, reasonText: "", wasConnected: true), .normal)
        XCTAssertEqual(DisconnectReason.from(sipCode: 487, reasonText: "", wasConnected: true), .normal)
        XCTAssertEqual(
            DisconnectReason.from(sipCode: 0, reasonText: "transport error", wasConnected: false),
            .failed(code: nil, reason: "transport error"))
    }

    // MARK: KeychainStore round-trip (real Keychain; app-hosted tests)

    func testKeychainRoundTrip() throws {
        let store = KeychainStore(service: "com.ultranet.ultrasip.tests")
        let ref = "test-\(UUID().uuidString)"
        do {
            try store.setPassword("s3cret-π", forRef: ref)
        } catch KeychainError.unexpectedStatus(let status)
            where status == errSecNotAvailable || status == errSecInteractionNotAllowed
        {
            throw XCTSkip("Keychain unavailable in this environment (status \(status))")
        }
        defer { try? store.deletePassword(forRef: ref) }
        XCTAssertEqual(try store.password(forRef: ref), "s3cret-π")
        try store.setPassword("rotated", forRef: ref)
        XCTAssertEqual(try store.password(forRef: ref), "rotated")
        try store.deletePassword(forRef: ref)
        XCTAssertNil(try store.password(forRef: ref))
        // Deleting a missing item is not an error.
        XCTAssertNoThrow(try store.deletePassword(forRef: ref))
    }

    /// Rebrand safety net: the Keychain service is derived from the bundle id,
    /// which the MacSIP→UltraSIP rename changed. A secret stored by the old
    /// build must be adopted on first read, not silently lost — otherwise
    /// every upgrading user is asked to re-enter their SIP password.
    func testKeychainAdoptsSecretFromLegacyService() throws {
        let legacyService = "com.ultranet.ultrasip.tests.legacy-\(UUID().uuidString)"
        let newService = "com.ultranet.ultrasip.tests.new-\(UUID().uuidString)"
        let legacyStore = KeychainStore(service: legacyService, legacyServices: [])
        let store = KeychainStore(service: newService, legacyServices: [legacyService])
        let ref = "acct-\(UUID().uuidString)"

        do {
            try legacyStore.setPassword("old-build-secret", forRef: ref)
        } catch KeychainError.unexpectedStatus(let status)
            where status == errSecNotAvailable || status == errSecInteractionNotAllowed
        {
            throw XCTSkip("Keychain unavailable in this environment (status \(status))")
        }
        defer {
            try? legacyStore.deletePassword(forRef: ref)
            try? store.deletePassword(forRef: ref)
        }

        // Read through the new service: the legacy secret is served...
        XCTAssertEqual(try store.password(forRef: ref), "old-build-secret")
        // ...and migrated, so it now lives under the new service...
        let newOnly = KeychainStore(service: newService, legacyServices: [])
        XCTAssertEqual(try newOnly.password(forRef: ref), "old-build-secret")
        // ...and no longer under the old one (no duplicate secret left behind).
        XCTAssertNil(try legacyStore.password(forRef: ref))
    }
}
