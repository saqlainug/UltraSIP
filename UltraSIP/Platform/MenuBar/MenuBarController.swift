import AppKit
import Combine

/// Menu bar extra (docs/UI_LAYOUT_SPEC.md): state-reflecting icon plus a
/// menu for registration, account switching, active-call control, recent
/// calls, DND, and window/quit actions. Rebuilt on state changes so it
/// never shows stale or dead items.
@MainActor
final class MenuBarController {
    private let model: AppModel
    private let statusItem: NSStatusItem
    private var cancellables: Set<AnyCancellable> = []

    var onShowWindow: (() -> Void)?
    var onDial: (() -> Void)?
    var onSettings: (() -> Void)?

    init(model: AppModel) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.behavior = .terminationOnRemoval
        configure()
    }

    private func configure() {
        let menu = NSMenu()
        menu.delegate = MenuRebuilder.shared
        statusItem.menu = menu
        MenuRebuilder.shared.builder = { [weak self] menu in self?.rebuild(menu) }

        // Icon + tooltip follow registration/call state.
        Publishers.CombineLatest3(model.$registrationState, model.$calls, model.$doNotDisturb)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _, _ in self?.updateIcon() }
            .store(in: &cancellables)
        updateIcon()
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let hasCall = !model.activeCalls.isEmpty || !model.incomingCalls.isEmpty
        let symbol: String
        let description: String
        if hasCall {
            symbol = "phone.fill"
            description = "UltraSIP — call in progress"
        } else if model.doNotDisturb {
            symbol = "moon.fill"
            description = "UltraSIP — Do Not Disturb"
        } else if model.isDirectDialing {
            // Local-account mode: availability, not registration.
            symbol = model.directDialingReady ? "phone" : "phone.down"
            description =
                model.directDialingReady
                ? "UltraSIP — ready (direct dialing)" : "UltraSIP — engine starting"
        } else {
            switch model.registrationState {
            case .registered:
                symbol = "phone"
                description = "UltraSIP — registered"
            case .registering:
                symbol = "phone.badge.waveform"
                description = "UltraSIP — registering"
            case .failed:
                symbol = "phone.badge.checkmark"
                description = "UltraSIP — registration failed"
            case .unregistered:
                symbol = "phone.down"
                description = "UltraSIP — not registered"
            }
        }
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: description)
        button.toolTip = description
    }

    private func rebuild(_ menu: NSMenu) {
        menu.removeAllItems()

        let statusTitle =
            model.isDirectDialing
            ? (model.directDialingReady ? "Ready — direct dialing" : "Engine starting…")
            : model.registrationState.userFacingDescription
        let status = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)

        if model.accounts.count > 1 {
            let accountsItem = NSMenuItem(title: "Account", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            for account in model.accounts {
                let item = NSMenuItem(
                    title: account.label.isEmpty ? account.aor : account.label,
                    action: #selector(MenuActions.switchAccount(_:)), keyEquivalent: "")
                item.target = MenuActions.shared
                item.representedObject = account.id
                item.state = account.id == model.activeAccountID ? .on : .off
                submenu.addItem(item)
            }
            accountsItem.submenu = submenu
            menu.addItem(accountsItem)
        }
        menu.addItem(.separator())

        let dial = NSMenuItem(title: "Dial…", action: #selector(MenuActions.dial), keyEquivalent: "")
        dial.target = MenuActions.shared
        menu.addItem(dial)

        // Active-call controls appear ONLY while a call exists.
        for snapshot in model.incomingCalls {
            let answer = NSMenuItem(
                title: "Answer \(displayName(snapshot))", action: #selector(MenuActions.answer(_:)),
                keyEquivalent: "")
            answer.target = MenuActions.shared
            answer.representedObject = snapshot.id
            menu.addItem(answer)
        }
        for snapshot in model.activeCalls {
            let hangup = NSMenuItem(
                title: "Hang Up \(displayName(snapshot))", action: #selector(MenuActions.hangup(_:)),
                keyEquivalent: "")
            hangup.target = MenuActions.shared
            hangup.representedObject = snapshot.id
            menu.addItem(hangup)

            if snapshot.state.isConnected {
                let mute = NSMenuItem(
                    title: snapshot.muted ? "Unmute" : "Mute", action: #selector(MenuActions.mute(_:)),
                    keyEquivalent: "")
                mute.target = MenuActions.shared
                mute.representedObject = snapshot.id
                menu.addItem(mute)

                let hold = NSMenuItem(
                    title: "Hold / Resume", action: #selector(MenuActions.hold(_:)), keyEquivalent: "")
                hold.target = MenuActions.shared
                hold.representedObject = snapshot.id
                menu.addItem(hold)
            }
        }

        if !model.history.isEmpty {
            let recentItem = NSMenuItem(title: "Recent Calls", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            for entry in model.history.prefix(5) {
                let item = NSMenuItem(
                    title: entry.remoteDisplayName.isEmpty ? entry.remoteURI : entry.remoteDisplayName,
                    action: #selector(MenuActions.redial(_:)), keyEquivalent: "")
                item.target = MenuActions.shared
                item.representedObject = entry.remoteURI
                submenu.addItem(item)
            }
            recentItem.submenu = submenu
            menu.addItem(recentItem)
        }
        menu.addItem(.separator())

        let dnd = NSMenuItem(
            title: "Do Not Disturb", action: #selector(MenuActions.toggleDND), keyEquivalent: "")
        dnd.target = MenuActions.shared
        dnd.state = model.doNotDisturb ? .on : .off
        menu.addItem(dnd)

        let show = NSMenuItem(
            title: "Show UltraSIP", action: #selector(MenuActions.showWindow), keyEquivalent: "")
        show.target = MenuActions.shared
        menu.addItem(show)

        let settings = NSMenuItem(
            title: "Settings…", action: #selector(MenuActions.settings), keyEquivalent: ",")
        settings.target = MenuActions.shared
        menu.addItem(settings)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit UltraSIP", action: #selector(MenuActions.quit), keyEquivalent: "q")
        quit.target = MenuActions.shared
        menu.addItem(quit)

        MenuActions.shared.model = model
        MenuActions.shared.onShowWindow = onShowWindow
        MenuActions.shared.onDial = onDial
        MenuActions.shared.onSettings = onSettings
    }

    private func displayName(_ snapshot: CallSnapshot) -> String {
        snapshot.remoteDisplayName.isEmpty ? snapshot.remoteURI : snapshot.remoteDisplayName
    }
}

/// NSMenu needs an ObjC target; this keeps the controller free of
/// selector plumbing.
@MainActor
final class MenuActions: NSObject {
    static let shared = MenuActions()

    var model: AppModel?
    var onShowWindow: (() -> Void)?
    var onDial: (() -> Void)?
    var onSettings: (() -> Void)?

    @objc func switchAccount(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID, let model else { return }
        Task { await model.switchAccount(to: id) }
    }

    @objc func dial() {
        onDial?()
    }

    @objc func answer(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? CallID else { return }
        model?.answer(id)
    }

    @objc func hangup(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? CallID else { return }
        model?.hangup(id)
    }

    @objc func mute(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? CallID else { return }
        model?.toggleMute(id)
    }

    @objc func hold(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? CallID else { return }
        model?.toggleHold(id)
    }

    @objc func redial(_ sender: NSMenuItem) {
        guard let uri = sender.representedObject as? String, let model else { return }
        Task { await model.dial(uri) }
    }

    @objc func toggleDND() {
        guard let model else { return }
        model.setDoNotDisturb(!model.doNotDisturb)
    }

    @objc func showWindow() {
        onShowWindow?()
    }

    @objc func settings() {
        onSettings?()
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }
}

/// Rebuilds the menu each time it opens so items reflect live state.
@MainActor
final class MenuRebuilder: NSObject, NSMenuDelegate {
    static let shared = MenuRebuilder()
    var builder: ((NSMenu) -> Void)?

    func menuNeedsUpdate(_ menu: NSMenu) {
        builder?(menu)
    }
}
