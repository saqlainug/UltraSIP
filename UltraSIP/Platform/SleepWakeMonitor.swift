import AppKit

/// Reports system wake on the main actor so the SIP runtime can recover
/// (SPEC: sleep/wake must not corrupt the runtime).
@MainActor
final class SleepWakeMonitor {
    var onWake: (() -> Void)?

    private var token: NSObjectProtocol?

    func start() {
        token = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.onWake?() }
        }
    }

    func stop() {
        if let token {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
        token = nil
    }
}
