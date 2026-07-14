import Foundation
import os

/// Typed Swift facade over the Obj-C++ bridge (MSPEngine). Translates
/// bridge events into Domain values on arrival (bridge types never travel
/// further) and republishes them on the main actor.
@MainActor
final class SIPEngine: NSObject {
    /// A translated call event, ready for AppModel state-machine handling.
    struct CallUpdate: Sendable {
        enum Phase: Sendable, Equatable {
            case dialing
            case incomingRinging
            case ringing
            case earlyMedia
            case connecting
            case connected(HoldState)
            case disconnected(sipCode: Int, reason: String)
        }

        let id: CallID
        let direction: CallDirection
        let remoteURI: String
        let remoteDisplayName: String
        let phase: Phase
        let mediaActive: Bool
    }

    enum Event: Sendable {
        case registration(RegistrationState)
        case incomingCall(CallUpdate)
        case callChanged(CallUpdate)
    }

    var onEvent: ((Event) -> Void)?

    private let bridge = MSPEngine()
    private static let log = Logger(subsystem: "com.example.macsip", category: "SIPEngine")

    override init() {
        super.init()
        bridge.delegate = self
    }

    // MARK: Lifecycle

    /// port 0 = ephemeral. nullAudio is for integration tests only (media
    /// flows without microphone/TCC involvement).
    func start(port: Int = 0, nullAudio: Bool = false) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            bridge.start(withUserAgent: "MacSIP/0.1.0", port: port, useNullAudio: nullAudio) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func stop() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            bridge.stop { continuation.resume() }
        }
    }

    // MARK: Account

    /// Password is passed transiently (fetched from Keychain by the caller
    /// immediately before this call) and never retained on the Swift side.
    func configureAccount(_ config: SIPAccountConfig, password: String) async throws {
        let bridgeConfig = MSPAccountConfig()
        bridgeConfig.aorUri = config.aor
        // Empty registrar = local account, no REGISTER sent (SPEC §1).
        // Non-UDP transports: transport parameter on the registrar + an
        // outbound proxy so ALL account requests (INVITE included) use it.
        bridgeConfig.registrarUri =
            config.registrationEnabled ? config.effectiveRegistrar + config.transportParameter : ""
        bridgeConfig.proxyUri =
            config.transport == .udp ? "" : "sip:\(config.domain)\(config.transportParameter);lr"
        bridgeConfig.srtpPolicy =
            switch config.mediaEncryption {
            case .none: .disabled
            case .srtpOptional: .optional
            case .srtpMandatory: .mandatory
            }
        bridgeConfig.tlsVerifyDisabled = config.tlsVerificationDisabled
        bridgeConfig.username = config.username
        bridgeConfig.authID = config.authorizationID
        bridgeConfig.password = password
        bridgeConfig.regIntervalSeconds = config.registrationInterval
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            bridge.configureAccount(bridgeConfig) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func removeAccount() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            bridge.removeAccount { continuation.resume() }
        }
    }

    func refreshRegistration() {
        bridge.refreshRegistration()
    }

    /// Network-path / wake recovery (docs/SIP_STATE_MACHINES.md
    /// registration triggers). Idempotent.
    func handleNetworkChanged() {
        bridge.handleNetworkChanged()
    }

    // MARK: Calls

    func makeCall(to uri: String) async throws -> CallID {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CallID, Error>) in
            bridge.makeCall(to: uri) { error, callId in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: CallID(callId))
                }
            }
        }
    }

    func answer(_ id: CallID) { bridge.answerCall(id.raw) }
    func reject(_ id: CallID, busy: Bool) { bridge.rejectCall(id.raw, busy: busy) }
    func hangup(_ id: CallID) { bridge.hangupCall(id.raw) }
    func setHold(_ id: CallID, held: Bool) { bridge.setCall(id.raw, held: held) }
    func setMute(_ id: CallID, muted: Bool) { bridge.setCall(id.raw, muted: muted) }

    func sendDTMF(_ digits: String, to id: CallID) {
        Self.log.info("Sending \(LogRedactor.redactDTMF(digits), privacy: .public) on \(id, privacy: .public)")
        bridge.sendDTMF(digits, toCall: id.raw)
    }

    func diagnostics() async -> String {
        await withCheckedContinuation { (continuation: CheckedContinuation<String, Never>) in
            bridge.diagnostics { info in continuation.resume(returning: info) }
        }
    }

    /// RTP packet counters (tx, rx) for media verification; (-1, -1) when
    /// the call/stream is gone.
    func rtpStats(for id: CallID) async -> (tx: Int, rx: Int) {
        await withCheckedContinuation { (continuation: CheckedContinuation<(tx: Int, rx: Int), Never>) in
            bridge.stats(forCall: id.raw) { tx, rx in continuation.resume(returning: (tx, rx)) }
        }
    }

    // MARK: Translation (bridge thread → Sendable values → main actor)

    private nonisolated static func registrationState(from event: MSPRegistrationEvent) -> RegistrationState {
        switch event.state {
        case .unregistered:
            .unregistered
        case .registering:
            .registering
        case .registered:
            .registered(
                expiresAt: event.expiresSeconds > 0
                    ? Date().addingTimeInterval(TimeInterval(event.expiresSeconds)) : nil)
        case .failed:
            .failed(code: event.sipCode == 0 ? nil : event.sipCode, reason: event.reason)
        @unknown default:
            .failed(code: nil, reason: "Unknown registration state")
        }
    }

    private nonisolated static func callUpdate(from event: MSPCallEvent) -> CallUpdate {
        let direction: CallDirection = event.isIncoming ? .incoming : .outgoing
        let hold: HoldState =
            switch event.mediaStatus {
            case .localHold: .local
            case .remoteHold: .remote
            default: .none
            }
        let phase: CallUpdate.Phase =
            switch event.phase {
            case .calling: .dialing
            case .incoming: .incomingRinging
            case .early: event.earlyFlag == .earlyMedia ? .earlyMedia : .ringing
            case .connecting: .connecting
            case .confirmed: .connected(hold)
            case .disconnected: .disconnected(sipCode: event.sipCode, reason: event.reason)
            @unknown default: .disconnected(sipCode: 0, reason: "Unknown call phase")
            }
        return CallUpdate(
            id: CallID(event.callId),
            direction: direction,
            remoteURI: event.remoteUri,
            remoteDisplayName: event.remoteDisplayName,
            phase: phase,
            mediaActive: event.mediaStatus == .active)
    }
}

extension SIPEngine: MSPEngineDelegate {
    // Events hop via DispatchQueue.main (FIFO), NOT independent Tasks:
    // unordered delivery could interleave a disconnect with a new incoming
    // call on a reused PJSUA call id (security review F8).
    nonisolated private func deliver(_ event: Event) {
        DispatchQueue.main.async {
            MainActor.assumeIsolated { self.onEvent?(event) }
        }
    }

    nonisolated func sipEngineRegistrationChanged(_ event: MSPRegistrationEvent) {
        deliver(.registration(Self.registrationState(from: event)))
    }

    nonisolated func sipEngineCallChanged(_ event: MSPCallEvent) {
        deliver(.callChanged(Self.callUpdate(from: event)))
    }

    nonisolated func sipEngineIncomingCall(_ event: MSPCallEvent) {
        deliver(.incomingCall(Self.callUpdate(from: event)))
    }
}
