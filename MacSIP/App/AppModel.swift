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
    @Published private(set) var account: SIPAccountConfig?
    @Published var lastError: String?
    @Published var showAccountForm = false

    private let engine: SIPEngine
    private let secrets: any SecretStore
    private var persistence: PersistenceStack?
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
            let stack = try persistence ?? PersistenceStack.open()
            self.persistence = stack
            account = try stack.accounts.loadAll().first
            history = try stack.history.recent(limit: 50)
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
        // Re-register the persisted account from the previous session.
        if let account {
            do {
                let password = try secrets.password(forRef: account.keychainPasswordRef) ?? ""
                try await engine.configureAccount(account, password: password)
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    // MARK: Account

    /// Saves the account. `newPassword` nil/empty = keep the stored secret
    /// (SPEC §1: existing passwords are never displayed back on edit).
    func saveAccount(_ config: SIPAccountConfig, newPassword: String?) async {
        var config = config
        let validationErrors = config.validate()
        guard validationErrors.isEmpty else {
            lastError = validationErrors.map(\.message).joined(separator: "\n")
            return
        }
        if config.keychainPasswordRef.isEmpty {
            config.keychainPasswordRef = "sip-account-\(config.id.uuidString)"
        }
        do {
            if let newPassword, !newPassword.isEmpty {
                try secrets.setPassword(newPassword, forRef: config.keychainPasswordRef)
            }
            // Fetched transiently at configuration time only; not retained.
            let password = try secrets.password(forRef: config.keychainPasswordRef) ?? ""
            try await engine.configureAccount(config, password: password)
            if let persistence {
                try persistence.accounts.save(config)
            }
            account = config
            showAccountForm = false
            lastError = nil
        } catch {
            lastError = error.localizedDescription
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
        switch DialTarget.parse(input, accountDomain: account.domain) {
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
                lastError = nil
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
            calls[update.id] = CallSnapshot(
                id: update.id, direction: .incoming, remoteURI: update.remoteURI,
                remoteDisplayName: update.remoteDisplayName, state: .incomingRinging,
                muted: false, mediaActive: false, startedAt: Date(), connectedAt: nil, endedAt: nil)
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
