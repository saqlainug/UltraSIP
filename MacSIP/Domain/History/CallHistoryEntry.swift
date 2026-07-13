import Foundation

/// One completed call (SPEC §18 basic subset for Milestone 1).
nonisolated struct CallHistoryEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let direction: CallDirection
    let remoteURI: String
    let remoteDisplayName: String
    let startedAt: Date
    let connectedAt: Date?
    let endedAt: Date
    /// User-facing outcome ("Ended", "Busy", "Number not found", …).
    let outcome: String
    /// Raw final SIP code for diagnostics (never shown as the outcome).
    let rawSIPCode: Int?

    var wasAnswered: Bool { connectedAt != nil }

    /// nil for unanswered calls — they show the outcome instead (SPEC §18).
    var talkDuration: TimeInterval? {
        guard let connectedAt else { return nil }
        return endedAt.timeIntervalSince(connectedAt)
    }

    static func from(snapshot: CallSnapshot) -> CallHistoryEntry {
        var outcome = "Ended"
        var code: Int?
        if case .disconnected(let reason) = snapshot.state {
            outcome = reason.userFacingDescription
            if case .failed(let rawCode, _) = reason { code = rawCode }
        }
        return CallHistoryEntry(
            id: UUID(),
            direction: snapshot.direction,
            remoteURI: snapshot.remoteURI,
            remoteDisplayName: snapshot.remoteDisplayName,
            startedAt: snapshot.startedAt,
            connectedAt: snapshot.connectedAt,
            endedAt: snapshot.endedAt ?? Date(),
            outcome: outcome,
            rawSIPCode: code)
    }
}
