import XCTest

@testable import MacSIP

final class RegistrationStateTests: XCTestCase {
    func testHappyPath() {
        XCTAssertTrue(RegistrationState.unregistered.canTransition(to: .registering))
        XCTAssertTrue(RegistrationState.registering.canTransition(to: .registered(expiresAt: nil)))
        XCTAssertTrue(RegistrationState.registered(expiresAt: nil).canTransition(to: .registering))
    }

    func testFailurePathAndRetry() {
        XCTAssertTrue(RegistrationState.registering.canTransition(to: .failed(code: 401, reason: "Unauthorized")))
        XCTAssertTrue(RegistrationState.failed(code: 401, reason: "x").canTransition(to: .registering))
    }

    func testForcedUnregisterAllowedFromAnywhere() {
        XCTAssertTrue(RegistrationState.registering.canTransition(to: .unregistered))
        XCTAssertTrue(RegistrationState.registered(expiresAt: nil).canTransition(to: .unregistered))
        XCTAssertTrue(RegistrationState.failed(code: nil, reason: "timeout").canTransition(to: .unregistered))
    }

    func testIllegalJumps() {
        XCTAssertFalse(RegistrationState.unregistered.canTransition(to: .registered(expiresAt: nil)))
        XCTAssertFalse(RegistrationState.unregistered.canTransition(to: .failed(code: 500, reason: "x")))
        XCTAssertFalse(RegistrationState.failed(code: 403, reason: "x").canTransition(to: .registered(expiresAt: nil)))
    }

    func testFailureDescriptionUsesSpecMapping() {
        let state = RegistrationState.failed(code: 401, reason: "Unauthorized")
        XCTAssertEqual(state.userFacingDescription, "Registration failed: Authentication required")
    }
}
