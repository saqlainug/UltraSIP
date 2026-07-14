import AppKit
import SwiftUI
import UserNotifications

/// AppKit-primary application shell (ARCHITECTURE.md): owns the model, the
/// main window, the menu-bar extra, the incoming-call panels, and the
/// settings window. SwiftUI renders inside these AppKit containers.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    private var mainWindowController: MainWindowController?
    private var menuBarController: MenuBarController?
    private var incomingCallPresenter: IncomingCallPresenter?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let windowController = MainWindowController(model: model)
        mainWindowController = windowController
        windowController.show()

        let presenter = IncomingCallPresenter(model: model)
        presenter.start()
        incomingCallPresenter = presenter

        let menuBar = MenuBarController(model: model)
        menuBar.onShowWindow = { [weak self] in self?.mainWindowController?.show() }
        menuBar.onDial = { [weak self] in self?.mainWindowController?.show() }
        menuBar.onSettings = { [weak self] in self?.showSettings() }
        menuBarController = menuBar

        // Notifications are the incoming-call fallback; ask once, non-fatal.
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// The app is a menu-bar utility: closing the window keeps it running.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        mainWindowController?.show()
        return true
    }

    /// Quitting with active calls must warn (SPEC menu-bar requirement).
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let liveCalls = model.activeCalls.count + model.incomingCalls.count
        guard liveCalls > 0 else { return .terminateNow }

        let alert = NSAlert()
        alert.messageText = liveCalls == 1 ? "Quit during an active call?" : "Quit during \(liveCalls) active calls?"
        alert.informativeText = "Quitting MacSIP will end the call."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Quit and End Call")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
    }

    @MainActor
    private func showSettings() {
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false)
        window.title = "MacSIP Settings"
        window.contentView = NSHostingView(rootView: SettingsView(model: model))
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    @objc func openSettings(_ sender: Any?) {
        Task { @MainActor in showSettings() }
    }
}
