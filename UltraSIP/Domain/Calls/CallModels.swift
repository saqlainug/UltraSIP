import Foundation

/// Stable call identity across the bridge (wraps the PJSUA call id, which
/// the bridge guarantees not to reuse while a snapshot is live).
nonisolated struct CallID: Hashable, Sendable, CustomStringConvertible {
    let raw: Int
    init(_ raw: Int) { self.raw = raw }
    var description: String { "call#\(raw)" }
}

nonisolated enum CallDirection: String, Sendable {
    case incoming, outgoing
}

nonisolated enum HoldState: Equatable, Sendable {
    case none
    case local
    case remote
    case both
}

nonisolated enum DisconnectReason: Equatable, Sendable {
    case normal
    case cancelled
    case busy
    case rejected
    case remoteHangup
    case failed(code: Int?, reason: String)

    /// Maps a final SIP code to the user-facing reason
    /// (docs/SIP_STATE_MACHINES.md event tables).
    static func from(sipCode: Int, reasonText: String, wasConnected: Bool) -> DisconnectReason {
        if wasConnected { return .normal }
        switch sipCode {
        case 487: return .cancelled
        case 486, 600: return .busy
        case 603: return .rejected
        case 200: return .normal
        case let code where code >= 300: return .failed(code: code, reason: reasonText)
        default: return .failed(code: sipCode == 0 ? nil : sipCode, reason: reasonText)
        }
    }

    /// User-facing outcome (SPEC §4: raw code preserved in diagnostics only).
    var userFacingDescription: String {
        switch self {
        case .normal, .remoteHangup: "Ended"
        case .cancelled: "Cancelled"
        case .busy: "Busy"
        case .rejected: "Call declined"
        case .failed(let code, let reason):
            if let code {
                SIPStatusMapping.userFacingResult(forStatusCode: code)
            } else {
                reason.isEmpty ? "Call failed" : reason
            }
        }
    }
}

/// Call lifecycle per docs/SIP_STATE_MACHINES.md. `disconnected` is terminal.
nonisolated enum CallState: Equatable, Sendable {
    case dialing
    case ringing
    case earlyMedia
    case incomingRinging
    case connecting
    case connected(hold: HoldState)
    case disconnected(DisconnectReason)

    var isTerminal: Bool {
        if case .disconnected = self { return true }
        return false
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    /// Legal transitions for the given direction (stale/duplicate callback
    /// guard: illegal transitions are dropped and logged by the caller).
    func canTransition(to next: CallState, direction: CallDirection) -> Bool {
        if isTerminal { return false }
        switch (self, next) {
        // Outgoing progress
        case (.dialing, .ringing), (.dialing, .earlyMedia), (.ringing, .earlyMedia):
            return direction == .outgoing
        case (.dialing, .connecting), (.ringing, .connecting), (.earlyMedia, .connecting):
            return direction == .outgoing
        // Incoming progress
        case (.incomingRinging, .connecting):
            return direction == .incoming
        // Shared
        case (.connecting, .connected):
            return true
        case (.connected, .connected):
            return true  // hold-state changes
        case (_, .disconnected):
            return true  // any non-terminal state can end
        default:
            return false
        }
    }

    var userFacingDescription: String {
        switch self {
        case .dialing: "Calling…"
        case .ringing: "Ringing…"
        case .earlyMedia: "Ringing…"
        case .incomingRinging: "Incoming call"
        case .connecting: "Connecting…"
        case .connected(let hold):
            switch hold {
            case .none: "Connected"
            case .local: "On hold"
            case .remote: "Held by remote"
            case .both: "On hold"
            }
        case .disconnected(let reason): reason.userFacingDescription
        }
    }
}

/// Immutable view of a call, published to the UI. Produced only by the SIP
/// engine wrapper; the UI never mutates call state directly.
nonisolated struct CallSnapshot: Equatable, Identifiable, Sendable {
    let id: CallID
    let direction: CallDirection
    let remoteURI: String
    let remoteDisplayName: String
    var state: CallState
    var muted: Bool
    var mediaActive: Bool
    let startedAt: Date
    var connectedAt: Date?
    var endedAt: Date?

    /// Talk duration; nil until connected (SPEC §18: unanswered calls show
    /// outcome, never a zero duration).
    func talkDuration(now: Date = Date()) -> TimeInterval? {
        guard let connectedAt else { return nil }
        return (endedAt ?? now).timeIntervalSince(connectedAt)
    }

    func ringDuration(now: Date = Date()) -> TimeInterval {
        (connectedAt ?? endedAt ?? now).timeIntervalSince(startedAt)
    }
}
