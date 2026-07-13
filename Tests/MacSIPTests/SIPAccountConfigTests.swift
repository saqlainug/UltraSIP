import XCTest

@testable import MacSIP

final class SIPAccountConfigTests: XCTestCase {
    private func validConfig() -> SIPAccountConfig {
        SIPAccountConfig(label: "Test", domain: "pbx.example.com", username: "alice")
    }

    func testValidConfigPasses() {
        XCTAssertEqual(validConfig().validate(), [])
    }

    func testAORAndRegistrarDerivation() {
        var config = validConfig()
        XCTAssertEqual(config.aor, "sip:alice@pbx.example.com")
        XCTAssertEqual(config.effectiveRegistrar, "sip:pbx.example.com")
        config.registrar = "sip:edge.example.com:5061"
        XCTAssertEqual(config.effectiveRegistrar, "sip:edge.example.com:5061")
    }

    func testEmptyFieldsRejected() {
        var config = validConfig()
        config.username = ""
        config.domain = ""
        let errors = config.validate()
        XCTAssertTrue(errors.contains(.emptyUsername))
        XCTAssertTrue(errors.contains(.emptyDomain))
    }

    func testHostValidation() {
        XCTAssertTrue(SIPAccountConfig.isValidHostPort("pbx.example.com"))
        XCTAssertTrue(SIPAccountConfig.isValidHostPort("10.0.0.5:5060"))
        XCTAssertTrue(SIPAccountConfig.isValidHostPort("[2001:db8::1]:5060"))
        XCTAssertFalse(SIPAccountConfig.isValidHostPort("pbx.example.com:99999"))
        XCTAssertFalse(SIPAccountConfig.isValidHostPort("host with space"))
        XCTAssertFalse(SIPAccountConfig.isValidHostPort("evil\r\nVia: attacker"))
        XCTAssertFalse(SIPAccountConfig.isValidHostPort(String(repeating: "a", count: 300)))
        XCTAssertFalse(SIPAccountConfig.isValidHostPort(""))
    }

    func testInjectionAttemptsInUsernameRejected() {
        var config = validConfig()
        config.username = "alice\r\nContact: <sip:evil>"
        XCTAssertTrue(config.validate().contains(.emptyUsername))
    }

    func testConfigNeverExposesPassword() {
        // Structural guarantee: the type has no password property — only the
        // Keychain reference. This test documents the invariant.
        let config = validConfig()
        let mirror = Mirror(reflecting: config)
        let labels = mirror.children.compactMap(\.label)
        XCTAssertFalse(labels.contains("password"))
        XCTAssertTrue(labels.contains("keychainPasswordRef"))
    }
}
