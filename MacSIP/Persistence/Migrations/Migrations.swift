import Foundation

/// Versioned schema migrations. APPEND-ONLY (CLAUDE.md "do not edit
/// casually"): never rewrite a shipped entry — add a new version. Applied
/// state is tracked in PRAGMA user_version.
///
/// Security invariant: no table may ever contain a password/secret column;
/// accounts store only the opaque Keychain reference. Enforced by
/// MigrationTests.testNoSecretColumnsExist for every future version.
nonisolated enum Migrations {
    /// version → SQL, contiguous from 1.
    static let all: [(version: Int, sql: String)] = [
        (
            1,
            """
            CREATE TABLE accounts (
                id TEXT PRIMARY KEY,
                label TEXT NOT NULL DEFAULT '',
                domain TEXT NOT NULL,
                registrar TEXT NOT NULL DEFAULT '',
                username TEXT NOT NULL,
                auth_id TEXT NOT NULL DEFAULT '',
                display_name TEXT NOT NULL DEFAULT '',
                transport TEXT NOT NULL DEFAULT 'udp',
                reg_interval INTEGER NOT NULL DEFAULT 0,
                keychain_ref TEXT NOT NULL,
                registration_enabled INTEGER NOT NULL DEFAULT 1
            );
            CREATE TABLE call_history (
                id TEXT PRIMARY KEY,
                direction TEXT NOT NULL,
                remote_uri TEXT NOT NULL,
                remote_display TEXT NOT NULL DEFAULT '',
                started_at REAL NOT NULL,
                connected_at REAL,
                ended_at REAL NOT NULL,
                outcome TEXT NOT NULL,
                raw_sip_code INTEGER
            );
            CREATE INDEX idx_history_started ON call_history(started_at DESC);
            """
        ),
        (
            2,
            """
            ALTER TABLE accounts ADD COLUMN media_encryption TEXT NOT NULL DEFAULT 'none';
            ALTER TABLE accounts ADD COLUMN tls_verify_disabled INTEGER NOT NULL DEFAULT 0;
            """
        ),
    ]

    static var latestVersion: Int { all.map(\.version).max() ?? 0 }

    /// Applies pending migrations transactionally, one version at a time.
    static func migrate(_ db: Database) throws {
        let current = try currentVersion(db)
        for migration in all.sorted(by: { $0.version < $1.version }) where migration.version > current {
            try db.execute("BEGIN")
            do {
                for statement in migration.sql.components(separatedBy: ";")
                where !statement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    try db.execute(statement)
                }
                try db.execute("PRAGMA user_version = \(migration.version)")
                try db.execute("COMMIT")
            } catch {
                try? db.execute("ROLLBACK")
                throw error
            }
        }
    }

    static func currentVersion(_ db: Database) throws -> Int {
        let rows = try db.query("PRAGMA user_version")
        return Int(rows.first?["user_version"]?.intValue ?? 0)
    }
}
