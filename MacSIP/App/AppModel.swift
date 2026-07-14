import AppKit
import Foundation
import os

/// Central main-actor state. Applies engine events through the Domain state
/// machines (illegal transitions from stale callbacks are dropped and
/// logged), owns the in-memory call table, and appends history.
/// Account persistence arrives with the M1 persistence slice; until then
/// the account lives for the app's lifetime only.
@MainActor
final class AppModel: ObservableObject {
    enum EngineStatus: Equatable {
        case stopped, starting, running
        case failed(String)
    }

    @Published private(set) var engineStatus: EngineStatus = .stopped
    @Published private(set) var registrationState: RegistrationState = .unregistered
    @Published private(set) var calls: [CallID: CallSnapshot] = [:]
    @Published private(set) var history: [CallHistoryEntry] = []
    /// All stored accounts; ONE is active at a time (MicroSIP parity).
    @Published private(set) var accounts: [SIPAccountConfig] = []
    @Published private(set) var activeAccountID: UUID?
    @Published var lastError: String?
    @Published var showAccountForm = false
    /// Do Not Disturb (SPEC §8): incoming calls are rejected as busy and
    /// recorded as missed. Persisted.
    @Published private(set) var doNotDisturb = false
    @Published private(set) var launchAtLogin = false
    @Published private(set) var lastDialedNumber: String?
    @Published private(set) var audioDevices: [AudioDevice] = []
    @Published private(set) var captureDeviceIndex = AudioDevice.systemDefaultIndex
    @Published private(set) var playbackDeviceIndex = AudioDevice.systemDefaultIndex

    var account: SIPAccountConfig? {
        guard let activeAccountID else { return nil }
        return accounts.first { $0.id == activeAccountID }
    }

    /// MicroSIP "Local Account" mode: the account never registers; calls
    /// go straight to the configured server and credentials are used only
    /// when the switch challenges. The UI shows "Ready" (green) instead of
    /// a registration state.
    var isDirectDialing: Bool {
        account?.registrationEnabled == false
    }

    /// True when a direct-dialing account is ready to place calls.
    var directDialingReady: Bool {
        isDirectDialing && engineStatus == .running
    }

    private let engine: SIPEngine
    private let secrets: any SecretStore
    private var persistence: PersistenceStack?
    private let networkMonitor = NetworkPathMonitor()
    private let sleepWakeMonitor = SleepWakeMonitor()
    private let recoveryDebouncer = Debouncer(interval: 2.0)
    private static let log = Logger(subsystem: "com.example.macsip", category: "AppModel")

    var incomingCalls: [CallSnapshot] {
        calls.values.filter { $0.state == .incomingRinging }.sorted { $0.startedAt < $1.startedAt }
    }

    var activeCalls: [CallSnapshot] {
        calls.values
            .filter { !$0.state.isTerminal && $0.state != .incomingRinging }
            .sorted { $0.startedAt < $1.startedAt }
    }

    init(
        engine: SIPEngine = SIPEngine(), secrets: any SecretStore = KeychainStore(),
        persistence: PersistenceStack? = nil
    ) {
        self.engine = engine
        self.secrets = secrets
        engine.onEvent = { [weak self] event in self?.handle(event) }
        do {
            // The app bundle is the XCTest host, so this initializer runs
            // during unit tests too — never let a test touch the user's
            // real database. Tests get a throwaway file.
            let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            let stack =
                try persistence
                ?? PersistenceStack.open(
                    at: isTesting
                        ? NSTemporaryDirectory() + "macsip-testhost-\(UUID().uuidString).sqlite" : nil)
            self.persistence = stack
            accounts = try stack.accounts.loadAll()
            if let stored = try stack.settings.value(for: SettingsRepository.Key.activeAccountID),
                let id = UUID(uuidString: stored), accounts.contains(where: { $0.id == id })
            {
                activeAccountID = id
            } else {
                activeAccountID = accounts.first?.id
            }
            history = try stack.history.recent(limit: 50)
            doNotDisturb = (try stack.settings.value(for: SettingsRepository.Key.doNotDisturb)) == "1"
            lastDialedNumber = try stack.settings.value(for: SettingsRepository.Key.lastDialed)
            captureDeviceIndex =
                Int(try stack.settings.value(for: SettingsRepository.Key.captureDevice) ?? "")
                ?? AudioDevice.systemDefaultIndex
            playbackDeviceIndex =
                Int(try stack.settings.value(for: SettingsRepository.Key.playbackDevice) ?? "")
                ?? AudioDevice.systemDefaultIndex
        } catch {
            // App remains usable without persistence; state is session-only.
            lastError = "Storage unavailable: \(error.localizedDescription)"
            Self.log.error("Persistence open failed: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: Engine lifecycle

    func startEngine() async {
        // Under XCTest the host app must NOT start PJSIP: the library is a
        // process-wide singleton and integration tests own their instance.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        guard engineStatus == .stopped || engineStatus.isFailure else { return }
        engineStatus = .starting
        do {
            try await engine.start()
            engineStatus = .running
        } catch {
            engineStatus = .failed(error.localizedDescription)
            return
        }
        // Re-register the persisted active account from the last session.
        await configureEngineForActiveAccount()
        startRecoveryMonitors()
        await refreshAudioDevices()
        launchAtLogin = LaunchAtLogin.isEnabled
        // Re-apply the stored device selection to the fresh engine.
        if captureDeviceIndex != AudioDevice.systemDefaultIndex
            || playbackDeviceIndex != AudioDevice.systemDefaultIndex
        {
            try? await engine.setAudioDevices(
                captureIndex: captureDeviceIndex, playbackIndex: playbackDeviceIndex)
        }
    }

    // MARK: Settings (SPEC §22 subset shipped with M3)

    func setDoNotDisturb(_ enabled: Bool) {
        doNotDisturb = enabled
        persistSetting(enabled ? "1" : "0", for: SettingsRepository.Key.doNotDisturb)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLogin.set(enabled)
            launchAtLogin = LaunchAtLogin.isEnabled
        } catch {
            lastError = "Could not change launch at login: \(error.localizedDescription)"
            launchAtLogin = LaunchAtLogin.isEnabled
        }
    }

    func refreshAudioDevices() async {
        let result = await engine.audioDevices()
        audioDevices = result.devices
    }

    func selectAudioDevices(capture: Int, playback: Int) async {
        do {
            try await engine.setAudioDevices(captureIndex: capture, playbackIndex: playback)
            captureDeviceIndex = capture
            playbackDeviceIndex = playback
            persistSetting(String(capture), for: SettingsRepository.Key.captureDevice)
            persistSetting(String(playback), for: SettingsRepository.Key.playbackDevice)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func persistSetting(_ value: String, for key: String) {
        guard let persistence else { return }
        do {
            try persistence.settings.set(value, for: key)
        } catch {
            Self.log.error("Persisting \(key, privacy: .public) failed")
        }
    }

    /// Fetches secrets transiently and (re)configures the engine for the
    /// active account; clears the engine account when none is active.
    private func configureEngineForActiveAccount() async {
        guard let account else {
            await engine.removeAccount()
            registrationState = .unregistered
            return
        }
        do {
            let password = try secrets.password(forRef: account.keychainPasswordRef) ?? ""
            let turnPassword =
                account.turnPasswordRef.isEmpty
                ? "" : (try secrets.password(forRef: account.turnPasswordRef) ?? "")
            try await engine.configureAccount(account, password: password, turnPassword: turnPassword)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Network-change + wake recovery (SPEC M2): debounced path events and
    /// wake notifications hand recovery to PJSIP's IP-change handling.
    private func startRecoveryMonitors() {
        networkMonitor.onChange = { [weak self] in
            guard let self else { return }
            self.recoveryDebouncer.trigger { [weak self] in
                guard let self, self.engineStatus == .running, self.account != nil else { return }
                Self.log.info("Network path changed — recovering registration/calls")
                self.engine.handleNetworkChanged()
            }
        }
        sleepWakeMonitor.onWake = { [weak self] in
            guard let self, self.engineStatus == .running, self.account != nil else { return }
            Self.log.info("System woke — recovering registration/calls")
            self.engine.handleNetworkChanged()
        }
        networkMonitor.start()
        sleepWakeMonitor.start()
    }

    // MARK: Account

    /// Saves an account (new or edited) and makes it active. Empty/nil
    /// passwords = keep stored secrets (SPEC §1: never displayed back).
    func saveAccount(_ config: SIPAccountConfig, newPassword: String?, newTURNPassword: String? = nil)
        async
    {
        // Reconfiguring tears down the SIP account; the bridge refuses with
        // calls up (F1/F4) — surface the friendly message first.
        guard activeCalls.isEmpty, incomingCalls.isEmpty else {
            lastError = "End active calls before changing account settings"
            return
        }
        var config = config
        let validationErrors = config.validate()
        guard validationErrors.isEmpty else {
            lastError = validationErrors.map(\.message).joined(separator: "\n")
            return
        }
        if config.keychainPasswordRef.isEmpty {
            config.keychainPasswordRef = "sip-account-\(config.id.uuidString)"
        }
        if !config.turnServer.isEmpty, config.turnPasswordRef.isEmpty {
            config.turnPasswordRef = "turn-cred-\(config.id.uuidString)"
        }
        do {
            if let newPassword, !newPassword.isEmpty {
                try secrets.setPassword(newPassword, forRef: config.keychainPasswordRef)
            }
            if let newTURNPassword, !newTURNPassword.isEmpty, !config.turnPasswordRef.isEmpty {
                try secrets.setPassword(newTURNPassword, forRef: config.turnPasswordRef)
            }
            if let persistence {
                try persistence.accounts.save(config)
            }
            if let index = accounts.firstIndex(where: { $0.id == config.id }) {
                accounts[index] = config
            } else {
                accounts.append(config)
            }
            setActiveAccount(config.id)
            // A non-registering account emits no registration events —
            // clear any state left over from a previous account.
            if !config.registrationEnabled {
                registrationState = .unregistered
            }
            await configureEngineForActiveAccount()
            showAccountForm = false
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Switch the active account without restarting (SPEC §1).
    func switchAccount(to id: UUID) async {
        guard activeCalls.isEmpty, incomingCalls.isEmpty else {
            lastError = "End active calls before switching accounts"
            return
        }
        guard accounts.contains(where: { $0.id == id }), id != activeAccountID else { return }
        setActiveAccount(id)
        registrationState = .unregistered
        await configureEngineForActiveAccount()
    }

    func deleteAccount(id: UUID) async {
        guard activeCalls.isEmpty, incomingCalls.isEmpty else {
            lastError = "End active calls before deleting accounts"
            return
        }
        guard let target = accounts.first(where: { $0.id == id }) else { return }
        do {
            if let persistence {
                try persistence.accounts.delete(id: id)
            }
            try? secrets.deletePassword(forRef: target.keychainPasswordRef)
            if !target.turnPasswordRef.isEmpty {
                try? secrets.deletePassword(forRef: target.turnPasswordRef)
            }
            accounts.removeAll { $0.id == id }
            if activeAccountID == id {
                setActiveAccount(accounts.first?.id)
                registrationState = .unregistered
                await configureEngineForActiveAccount()
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func setActiveAccount(_ id: UUID?) {
        activeAccountID = id
        guard let persistence else { return }
        do {
            if let id {
                try persistence.settings.set(id.uuidString, for: SettingsRepository.Key.activeAccountID)
            } else {
                try persistence.settings.remove(SettingsRepository.Key.activeAccountID)
            }
        } catch {
            Self.log.error("Persisting active account failed: \(String(describing: error), privacy: .public)")
        }
    }

    func refreshRegistration() {
        engine.refreshRegistration()
    }

    // MARK: Call control

    func dial(_ input: String) async {
        guard let account else {
            lastError = "Configure an account first"
            return
        }
        let prefixed = DialTarget.applyingDialPrefix(account.dialPrefix, to: input)
        switch DialTarget.parse(prefixed, accountDomain: account.domain) {
        case .failure(let parseError):
            lastError = parseError.message
        case .success(let uri):
            do {
                let id = try await engine.makeCall(to: uri)
                if calls[id] == nil {
                    calls[id] = CallSnapshot(
                        id: id, direction: .outgoing, remoteURI: uri, remoteDisplayName: "",
                        state: .dialing, muted: false, mediaActive: false,
                        startedAt: Date(), connectedAt: nil, endedAt: nil)
                }
                lastDialedNumber = input.trimmingCharacters(in: .whitespaces)
                persistSetting(lastDialedNumber ?? "", for: SettingsRepository.Key.lastDialed)
                lastError = nil
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    /// Redial the last dialed destination (SPEC §3).
    func redial() async {
        guard let number = lastDialedNumber, !number.isEmpty else { return }
        await dial(number)
    }

    // MARK: History management (SPEC §18)

    func deleteHistoryEntry(_ id: UUID) async {
        history.removeAll { $0.id == id }
        guard let persistence else { return }
        do {
            try persistence.history.delete(id: id)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func clearHistory() async {
        let alert = NSAlert()
        alert.messageText = "Clear all call history?"
        alert.informativeText = "This permanently deletes every entry. It cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear History")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        history.removeAll()
        guard let persistence else { return }
        do {
            try persistence.history.deleteAll()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Dials the account's voicemail number (SPEC §3; button appears only
    /// when configured). Bypasses the dial prefix — the number is already
    /// PBX-local.
    func dialVoicemail() async {
        guard let account, !account.voicemailNumber.isEmpty else { return }
        switch DialTarget.parse(account.voicemailNumber, accountDomain: account.domain) {
        case .failure(let parseError):
            lastError = parseError.message
        case .success(let uri):
            do {
                let id = try await engine.makeCall(to: uri)
                if calls[id] == nil {
                    calls[id] = CallSnapshot(
                        id: id, direction: .outgoing, remoteURI: uri, remoteDisplayName: "Voicemail",
                        state: .dialing, muted: false, mediaActive: false,
                        startedAt: Date(), connectedAt: nil, endedAt: nil)
                }
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func answer(_ id: CallID) { engine.answer(id) }
    func reject(_ id: CallID, busy: Bool = false) { engine.reject(id, busy: busy) }
    func hangup(_ id: CallID) { engine.hangup(id) }

    func toggleMute(_ id: CallID) {
        guard var snapshot = calls[id] else { return }
        snapshot.muted.toggle()
        calls[id] = snapshot
        engine.setMute(id, muted: snapshot.muted)
    }

    func toggleHold(_ id: CallID) {
        guard let snapshot = calls[id], case .connected(let hold) = snapshot.state else { return }
        switch hold {
        case .none: engine.setHold(id, held: true)
        case .local, .both: engine.setHold(id, held: false)
        case .remote: engine.setHold(id, held: true)
        }
    }

    func sendDTMF(_ digit: String, to id: CallID) {
        engine.sendDTMF(digit, to: id)
    }

    func diagnostics() async -> String {
        await engine.diagnostics()
    }

    // MARK: Event handling

    private func handle(_ event: SIPEngine.Event) {
        switch event {
        case .registration(let newState):
            if !registrationState.canTransition(to: newState) {
                Self.log.warning(
                    "Unexpected registration transition \(String(describing: self.registrationState), privacy: .public) -> \(String(describing: newState), privacy: .public)"
                )
            }
            registrationState = newState
        case .incomingCall(let update):
            guard calls[update.id] == nil else { return }
            let snapshot = CallSnapshot(
                id: update.id, direction: .incoming, remoteURI: update.remoteURI,
                remoteDisplayName: update.remoteDisplayName, state: .incomingRinging,
                muted: false, mediaActive: false, startedAt: Date(), connectedAt: nil, endedAt: nil)
            // DND (SPEC §8): reject as busy, but still record the missed
            // call — the user must be able to see who called.
            if doNotDisturb {
                calls[update.id] = snapshot
                engine.reject(update.id, busy: true)
                return
            }
            calls[update.id] = snapshot
        case .callChanged(let update):
            apply(update)
        }
    }

    private func apply(_ update: SIPEngine.CallUpdate) {
        var snapshot =
            calls[update.id]
            ?? CallSnapshot(
                id: update.id, direction: update.direction, remoteURI: update.remoteURI,
                remoteDisplayName: update.remoteDisplayName,
                state: update.direction == .incoming ? .incomingRinging : .dialing,
                muted: false, mediaActive: false, startedAt: Date(), connectedAt: nil, endedAt: nil)

        let proposed = proposedState(for: update, previous: snapshot)
        if snapshot.state != proposed {
            guard snapshot.state.canTransition(to: proposed, direction: snapshot.direction) else {
                Self.log.warning(
                    "Dropped illegal call transition \(String(describing: snapshot.state), privacy: .public) -> \(String(describing: proposed), privacy: .public) for \(update.id, privacy: .public)"
                )
                return
            }
            snapshot.state = proposed
        }
        snapshot.mediaActive = update.mediaActive
        if snapshot.connectedAt == nil, proposed.isConnected {
            snapshot.connectedAt = Date()
        }
        if case .disconnected = proposed {
            snapshot.endedAt = Date()
            let entry = CallHistoryEntry.from(snapshot: snapshot)
            history.insert(entry, at: 0)
            if let persistence {
                do {
                    try persistence.history.append(entry)
                } catch {
                    Self.log.error("History write failed: \(String(describing: error), privacy: .public)")
                }
            }
            calls[update.id] = nil
            return
        }
        calls[update.id] = snapshot
    }

    private func proposedState(for update: SIPEngine.CallUpdate, previous: CallSnapshot) -> CallState {
        switch update.phase {
        case .dialing: .dialing
        case .incomingRinging: .incomingRinging
        case .ringing: .ringing
        case .earlyMedia: .earlyMedia
        case .connecting: .connecting
        case .connected(let hold): .connected(hold: hold)
        case .disconnected(let sipCode, let reason):
            .disconnected(
                DisconnectReason.from(
                    sipCode: sipCode, reasonText: reason,
                    wasConnected: previous.connectedAt != nil))
        }
    }
}

extension AppModel.EngineStatus {
    fileprivate var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}
