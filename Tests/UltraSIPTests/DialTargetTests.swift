import XCTest

@testable import UltraSIP

final class DialTargetTests: XCTestCase {
    private let domain = "pbx.example.com"

    func testBareExtensionResolvesAgainstAccountDomain() {
        XCTAssertEqual(DialTarget.parse("100", accountDomain: domain), .success("sip:100@pbx.example.com"))
        XCTAssertEqual(DialTarget.parse("*97", accountDomain: domain), .success("sip:*97@pbx.example.com"))
        XCTAssertEqual(
            DialTarget.parse("+15551234567", accountDomain: domain), .success("sip:+15551234567@pbx.example.com"))
    }

    func testFullURIsPreserved() {
        XCTAssertEqual(DialTarget.parse("sip:bob@other.com", accountDomain: domain), .success("sip:bob@other.com"))
        XCTAssertEqual(DialTarget.parse("sips:bob@secure.com", accountDomain: domain), .success("sips:bob@secure.com"))
        XCTAssertEqual(
            DialTarget.parse("bob@other.com:5080", accountDomain: domain), .success("sip:bob@other.com:5080"))
    }

    func testDirectHostDialing() {
        XCTAssertEqual(DialTarget.parse("10.0.0.5:5060", accountDomain: domain), .success("sip:10.0.0.5:5060"))
        XCTAssertEqual(DialTarget.parse("sip:10.0.0.5", accountDomain: domain), .success("sip:10.0.0.5"))
    }

    func testWhitespaceTrimmedButInnerWhitespaceRejected() {
        XCTAssertEqual(DialTarget.parse("  100  ", accountDomain: domain), .success("sip:100@pbx.example.com"))
        XCTAssertEqual(DialTarget.parse("1 00", accountDomain: domain), .failure(.illegalCharacters))
    }

    func testInjectionRejected() {
        XCTAssertEqual(
            DialTarget.parse("100\r\nRoute: <sip:evil>", accountDomain: domain),
            .failure(.illegalCharacters))
        XCTAssertEqual(DialTarget.parse("100\u{0000}", accountDomain: domain), .failure(.illegalCharacters))
        XCTAssertEqual(DialTarget.parse("<sip:evil>", accountDomain: domain), .failure(.illegalCharacters))
    }

    func testBoundsAndEmpties() {
        XCTAssertEqual(DialTarget.parse("", accountDomain: domain), .failure(.empty))
        XCTAssertEqual(DialTarget.parse("   ", accountDomain: domain), .failure(.empty))
        XCTAssertEqual(
            DialTarget.parse(String(repeating: "1", count: 300), accountDomain: domain),
            .failure(.tooLong))
        XCTAssertEqual(DialTarget.parse("sip:", accountDomain: domain), .failure(.invalidURI))
        XCTAssertEqual(DialTarget.parse("user@", accountDomain: domain), .failure(.invalidURI))
        XCTAssertEqual(DialTarget.parse("@host", accountDomain: domain), .failure(.invalidURI))
    }

    func testBareNumberWithoutAccountDomainFails() {
        XCTAssertEqual(DialTarget.parse("100", accountDomain: ""), .failure(.invalidURI))
    }

    // MARK: Dialing prefix (SPEC §3: bare numbers only)

    func testPrefixAppliedToBareNumbersOnly() {
        XCTAssertEqual(DialTarget.applyingDialPrefix("9", to: "5551234"), "95551234")
        XCTAssertEqual(DialTarget.applyingDialPrefix("9", to: " *97 "), "9*97")
        XCTAssertEqual(DialTarget.applyingDialPrefix("00", to: "+4912345"), "00+4912345")
    }

    func testPrefixNeverCorruptsURIsOrHosts() {
        XCTAssertEqual(DialTarget.applyingDialPrefix("9", to: "sip:bob@other.com"), "sip:bob@other.com")
        XCTAssertEqual(DialTarget.applyingDialPrefix("9", to: "bob@other.com"), "bob@other.com")
        XCTAssertEqual(DialTarget.applyingDialPrefix("9", to: "10.0.0.5:5060"), "10.0.0.5:5060")
        XCTAssertEqual(DialTarget.applyingDialPrefix("", to: "5551234"), "5551234")
    }
}
