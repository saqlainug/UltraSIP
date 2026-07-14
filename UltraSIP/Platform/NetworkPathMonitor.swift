import Foundation
import Network

/// Watches network-path changes (interface switches, VPN up/down,
/// connectivity return) and reports them on the main actor. The initial
/// path snapshot on start is swallowed — only real changes fire.
@MainActor
final class NetworkPathMonitor {
    var onChange: (() -> Void)?

    private let monitor = NWPathMonitor()
    private var sawInitialPath = false

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            let satisfied = path.status == .satisfied
            Task { @MainActor in self?.handle(satisfied: satisfied) }
        }
        monitor.start(queue: DispatchQueue(label: "com.ultranet.ultrasip.network-path"))
    }

    func stop() {
        monitor.cancel()
    }

    private func handle(satisfied: Bool) {
        guard sawInitialPath else {
            sawInitialPath = true
            return
        }
        // Fire on any usable-path update: interface switches surface as
        // satisfied-path changes; loss without recovery has nothing to fix.
        if satisfied {
            onChange?()
        }
    }
}
