import Foundation

nonisolated protocol HistoryStoring {
    func append(_ entry: CallHistoryEntry) throws
    func recent(limit: Int) throws -> [CallHistoryEntry]
    func delete(id: UUID) throws
    func deleteAll() throws
}

/// SQLite-backed call history (SPEC §18 Milestone-1 subset).
nonisolated final class HistoryRepository: HistoryStoring {
    private let db: Database

    init(db: Database) {
        self.db = db
    }

    func append(_ entry: CallHistoryEntry) throws {
        try db.execute(
            """
            INSERT INTO call_history (id, direction, remote_uri, remote_display,
                started_at, connected_at, ended_at, outcome, raw_sip_code)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                .text(entry.id.uuidString), .text(entry.direction.rawValue),
                .text(entry.remoteURI), .text(entry.remoteDisplayName),
                .real(entry.startedAt.timeIntervalSince1970),
                entry.connectedAt.map { .real($0.timeIntervalSince1970) } ?? .null,
                .real(entry.endedAt.timeIntervalSince1970),
                .text(entry.outcome),
                entry.rawSIPCode.map { .integer(Int64($0)) } ?? .null,
            ])
    }

    func recent(limit: Int) throws -> [CallHistoryEntry] {
        try db.query(
            "SELECT * FROM call_history ORDER BY started_at DESC LIMIT ?",
            [.integer(Int64(limit))]
        ).compactMap { row in
            guard let idText = row["id"]?.textValue, let id = UUID(uuidString: idText),
                let directionText = row["direction"]?.textValue,
                let direction = CallDirection(rawValue: directionText),
                let startedAt = row["started_at"]?.doubleValue,
                let endedAt = row["ended_at"]?.doubleValue,
                let outcome = row["outcome"]?.textValue
            else { return nil }
            return CallHistoryEntry(
                id: id,
                direction: direction,
                remoteURI: row["remote_uri"]?.textValue ?? "",
                remoteDisplayName: row["remote_display"]?.textValue ?? "",
                startedAt: Date(timeIntervalSince1970: startedAt),
                connectedAt: row["connected_at"]?.doubleValue.map(Date.init(timeIntervalSince1970:)),
                endedAt: Date(timeIntervalSince1970: endedAt),
                outcome: outcome,
                rawSIPCode: row["raw_sip_code"]?.intValue.map(Int.init))
        }
    }

    func delete(id: UUID) throws {
        try db.execute("DELETE FROM call_history WHERE id = ?", [.text(id.uuidString)])
    }

    func deleteAll() throws {
        try db.execute("DELETE FROM call_history")
    }
}
