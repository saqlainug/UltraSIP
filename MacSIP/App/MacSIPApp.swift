import SwiftUI

@main
struct MacSIPApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .windowResizability(.contentSize)
    }
}
