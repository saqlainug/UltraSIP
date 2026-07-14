import AppKit
import SwiftUI

/// AppKit-primary main window (docs/UI_LAYOUT_SPEC.md): compact utility
/// window, 360×560 pt initial, resizable only within 340×520 … 380×620.
/// Frame is remembered across launches.
@MainActor
final class MainWindowController: NSWindowController, NSWindowDelegate {
    private let model: AppModel
    /// When true, closing hides the window instead of terminating.
    var hidesOnClose: Bool = true

    init(model: AppModel) {
        self.model = model
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false)
        window.title = "UltraSIP"
        window.titlebarAppearsTransparent = false
        window.contentMinSize = NSSize(width: 340, height: 520)
        window.contentMaxSize = NSSize(width: 380, height: 620)
        window.setFrameAutosaveName("UltraSIPMainWindow")
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: MainView(model: model))
        super.init(window: window)
        window.delegate = self
        if window.frameAutosaveName.isEmpty || window.frame.origin == .zero {
            window.center()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("MainWindowController is created programmatically")
    }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func toggle() {
        guard let window else { return }
        if window.isVisible, window.isKeyWindow {
            window.orderOut(nil)
        } else {
            show()
        }
    }

    // Close = hide (utility app lives in the menu bar); Quit handles exit,
    // with the active-call warning.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard hidesOnClose else { return true }
        sender.orderOut(nil)
        return false
    }
}
