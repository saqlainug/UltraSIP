import AppKit

/// AppKit application delegate. The AppKit-primary shell (main window chrome,
/// menu bar item, incoming-call panel) attaches here starting in Milestone 3;
/// until then it only sets standard utility-app window behavior.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
