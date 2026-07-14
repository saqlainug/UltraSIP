import XCTest
@testable import UltraSIP

final class SIPStatusMappingTests: XCTestCase {
    /// Every mapping mandated by SPEC §4 must hold exactly.
    func testSpecMandatedMappings() {
        let expected: [Int: String] = [
            400: "Invalid request",
            401: "Authentication required",
            403: "Call forbidden",
            404: "Number not found",
            407: "Proxy authentication required",
            408: "Request timed out",
            480: "Temporarily unavailable",
            481: "Call no longer exists",
            486: "Busy",
            487: "Call cancelled",
            488: "Incompatible media",
            500: "Server error",
            502: "Bad gateway",
            503: "Service unavailable",
            600: "Busy",
            603: "Call declined",
        ]
        for (code, text) in expected {
            XCTAssertEqual(SIPStatusMapping.userFacingResult(forStatusCode: code), text, "SIP \(code)")
        }
    }

    /// SPEC §4: SIP 404 must not be reported as a generic "Call failed".
    func testNotFoundIsNeverGeneric() {
        XCTAssertFalse(SIPStatusMapping.userFacingResult(forStatusCode: 404).contains("failed"))
    }

    /// Unmapped codes keep the raw numeric code visible rather than hiding it.
    func testUnmappedCodePreservesRawCode() {
        XCTAssertEqual(SIPStatusMapping.userFacingResult(forStatusCode: 604), "Call failed (604)")
        XCTAssertEqual(SIPStatusMapping.userFacingResult(forStatusCode: 380), "Call failed (380)")
    }
}
