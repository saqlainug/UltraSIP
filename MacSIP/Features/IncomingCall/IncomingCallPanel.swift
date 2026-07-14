import AppKit
import SwiftUI

/// Floating incoming-call panel (docs/UI_LAYOUT_SPEC.md): 340×128 pt,
/// top-right of the active screen, floats above other apps, joins all
/// Spaces, and NEVER steals key focus (non-activating panel) — you can
/// keep typing in another app while it rings. It does not reposition
/// itself once shown.
@MainActor
final class IncomingCallPanel: NSPanel {
    private static let size = NSSize(width: 340, height: 128)
    private static let margin: CGFloat = 16

    init(model: AppModel, snapshot: CallSnapshot, stackIndex: Int) {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.titled, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false)
        isFloatingPanel = true
        level = .floating
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        worksWhenModal = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isReleasedWhenClosed = false
        contentView = NSHostingView(rootView: IncomingCallPanelView(model: model, snapshot: snapshot))
        position(stackIndex: stackIndex)
    }

    /// Top-right of the screen that currently has keyboard focus
    /// (multi-monitor safe); additional calls stack downward.
    private func position(stackIndex: Int) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let frame = screen?.visibleFrame else { return }
        let x = frame.maxX - Self.size.width - Self.margin
        let y =
            frame.maxY - Self.size.height - Self.margin
            - CGFloat(stackIndex) * (Self.size.height + 8)
        setFrameOrigin(NSPoint(x: x, y: max(frame.minY + Self.margin, y)))
    }

    /// Shows without activating the app or stealing focus.
    func present() {
        orderFrontRegardless()
    }
}

/// Panel content: caller identity, receiving account, and the three
/// actions. Keyboard shortcuts work when the panel is focused; the menu
/// bar and main window carry global equivalents.
struct IncomingCallPanelView: View {
    @ObservedObject var model: AppModel
    let snapshot: CallSnapshot

    private var callerName: String {
        snapshot.remoteDisplayName.isEmpty ? snapshot.remoteURI : snapshot.remoteDisplayName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "phone.arrow.down.left")
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)
                Text("Incoming call")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if let account = model.account {
                    Text(account.label.isEmpty ? account.aor : account.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .accessibilityLabel("Receiving account \(account.label)")
                }
            }
            Text(callerName)
                .font(.headline)
                .lineLimit(1)
            if !snapshot.remoteDisplayName.isEmpty {
                Text(snapshot.remoteURI)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            HStack(spacing: 8) {
                Button {
                    model.answer(snapshot.id)
                } label: {
                    Label("Answer", systemImage: "phone.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .keyboardShortcut(.return, modifiers: [])
                .accessibilityLabel("Answer call from \(callerName)")

                Button("Busy") {
                    model.reject(snapshot.id, busy: true)
                }
                .accessibilityLabel("Reject as busy")

                Button(role: .destructive) {
                    model.reject(snapshot.id, busy: false)
                } label: {
                    Label("Decline", systemImage: "phone.down.fill")
                }
                .keyboardShortcut(.escape, modifiers: [])
                .accessibilityLabel("Decline call")
            }
        }
        .padding(12)
        .frame(width: 340, height: 128, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Incoming call from \(callerName)")
    }
}
