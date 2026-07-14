import XCTest

@testable import UltraSIP

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

    func testTransportParameterSemantics() {
        var config = validConfig()
        config.transport = .auto
        XCTAssertEqual(config.transportParameter, "", "auto = RFC 3263 selection, no parameter")
        config.transport = .udp
        XCTAssertEqual(config.transportParameter, ";transport=udp")
        config.transport = .tcp
        XCTAssertEqual(config.transportParameter, ";transport=tcp")
        config.transport = .tls
        XCTAssertEqual(config.transportParameter, ";transport=tls")
    }

    func testNetworkFieldValidation() {
        var config = validConfig()
        config.outboundProxy = "not a host"
        config.keepaliveInterval = -1
        config.sessionTimerExpiry = 30
        config.voicemailNumber = "vm@host"
        config.dialPrefix = "9;rm -rf"
        let errors = config.validate()
        XCTAssertTrue(errors.contains(.invalidOutboundProxy("not a host")))
        XCTAssertTrue(errors.contains(.invalidKeepalive(-1)))
        XCTAssertTrue(errors.contains(.invalidSessionTimerExpiry(30)))
        XCTAssertTrue(errors.contains(.invalidVoicemailNumber("vm@host")))
        XCTAssertTrue(errors.contains(.invalidDialPrefix("9;rm -rf")))
    }

    func testValidNetworkFieldsPass() {
        var config = validConfig()
        config.outboundProxy = "sip:edge.example.com:5061"
        config.keepaliveInterval = 30
        config.sessionTimerMode = .required
        config.sessionTimerExpiry = 1800
        config.voicemailNumber = "*97"
        config.dialPrefix = "9"
        XCTAssertEqual(config.validate(), [])
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
