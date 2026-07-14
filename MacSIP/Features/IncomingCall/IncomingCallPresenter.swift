import AppKit
import Combine
import UserNotifications

/// Owns the lifecycle of incoming-call panels: one per ringing call,
/// stacked; dismissed the moment the call leaves the ringing state
/// (answered, rejected, cancelled by the caller, or DND-rejected).
/// Falls back to a user notification when panels are suppressed.
@MainActor
final class IncomingCallPresenter {
    private let model: AppModel
    private var panels: [CallID: IncomingCallPanel] = [:]
    private var cancellable: AnyCancellable?

    /// When true, ring via notification instead of the floating panel.
    var usesNotificationFallback = false

    init(model: AppModel) {
        self.model = model
    }

    func start() {
        cancellable = model.$calls
            .receive(on: RunLoop.main)
            .sink { [weak self] calls in
                self?.sync(with: calls)
            }
    }

    private func sync(with calls: [CallID: CallSnapshot]) {
        let ringing = calls.values
            .filter { $0.state == .incomingRinging }
            .sorted { $0.startedAt < $1.startedAt }
        let ringingIDs = Set(ringing.map(\.id))

        // Close panels for calls that stopped ringing.
        for (id, panel) in panels where !ringingIDs.contains(id) {
            panel.close()
            panels[id] = nil
        }

        // DND rejects without ever showing a panel.
        guard !model.doNotDisturb else { return }

        for (index, snapshot) in ringing.enumerated() where panels[snapshot.id] == nil {
            if usesNotificationFallback {
                notify(snapshot)
                continue
            }
            let panel = IncomingCallPanel(model: model, snapshot: snapshot, stackIndex: index)
            panels[snapshot.id] = panel
            panel.present()
        }
    }

    private func notify(_ snapshot: CallSnapshot) {
        let content = UNMutableNotificationContent()
        content.title = "Incoming call"
        content.body = snapshot.remoteDisplayName.isEmpty ? snapshot.remoteURI : snapshot.remoteDisplayName
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "incoming-\(snapshot.id.raw)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
