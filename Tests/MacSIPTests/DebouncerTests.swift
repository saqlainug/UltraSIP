import XCTest

@testable import MacSIP

@MainActor
final class DebouncerTests: XCTestCase {
    func testRapidTriggersCollapseToOneAction() async throws {
        let debouncer = Debouncer(interval: 0.15)
        var count = 0
        for _ in 0..<5 {
            debouncer.trigger { count += 1 }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertEqual(count, 1, "five rapid triggers must produce exactly one action")
    }

    func testSeparatedTriggersEachFire() async throws {
        let debouncer = Debouncer(interval: 0.05)
        var count = 0
        debouncer.trigger { count += 1 }
        try await Task.sleep(nanoseconds: 200_000_000)
        debouncer.trigger { count += 1 }
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(count, 2)
    }

    func testCancelPreventsPendingAction() async throws {
        let debouncer = Debouncer(interval: 0.05)
        var count = 0
        debouncer.trigger { count += 1 }
        debouncer.cancel()
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(count, 0)
    }
}
