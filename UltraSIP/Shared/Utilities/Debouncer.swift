import Foundation

/// Main-actor debouncer: rapid triggers collapse into one action after the
/// quiet interval. Used to coalesce network-path flapping before poking
/// the SIP engine (unit-tested in DebouncerTests).
@MainActor
final class Debouncer {
    private let interval: TimeInterval
    private var pending: Task<Void, Never>?

    init(interval: TimeInterval) {
        self.interval = interval
    }

    func trigger(_ action: @escaping @MainActor () -> Void) {
        pending?.cancel()
        pending = Task { @MainActor [interval] in
            do {
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            } catch {
                return  // superseded by a newer trigger
            }
            action()
        }
    }

    func cancel() {
        pending?.cancel()
        pending = nil
    }
}
