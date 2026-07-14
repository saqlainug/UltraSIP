import Foundation
import os

/// Post-migration schema verification and additive repair.
///
/// `PRAGMA user_version` alone is not trustworthy: a database can carry a
/// version stamp that does not match its actual schema (e.g. it was
/// written by a build from a different branch/worktree whose migration
/// definitions diverged, which is normal during development and possible
/// after a botched upgrade). When that happens the app would otherwise
/// fail every write with a raw SQL error.
///
/// This guard states the schema the CURRENT code requires, checks it after
/// migrations run, and repairs anything missing with additive DDL only
/// (`CREATE TABLE IF NOT EXISTS`, `ALTER TABLE … ADD COLUMN`). It never
/// drops or rewrites anything, so unknown/orphan columns from another
/// lineage are left alone and simply ignored.
///
/// It is NOT a substitute for migrations (CLAUDE.md: migrations stay
/// append-only) — it is the corruption-handling safety net SPEC requires.
nonisolated enum SchemaGuard {
    private static let log = Logger(subsystem: "com.example.macsip", category: "SchemaGuard")

    /// Tables the running code requires, with the DDL to create them from
    /// scratch. Keep in sync with the latest migration.
    private static let requiredTables: [(name: String, createSQL: String)] = [
        (
            "accounts",
            """
            CREATE TABLE IF NOT EXISTS accounts (
                id TEXT PRIMARY KEY,
                username TEXT NOT NULL,
                domain TEXT NOT NULL,
                keychain_ref TEXT NOT NULL
            )
            """
        ),
        (
            "call_history",
            """
            CREATE TABLE IF NOT EXISTS call_history (
                id TEXT PRIMARY KEY,
                direction TEXT NOT NULL,
                remote_uri TEXT NOT NULL,
                started_at REAL NOT NULL,
                ended_at REAL NOT NULL,
                outcome TEXT NOT NULL
            )
            """
        ),
        (
            "app_settings",
            """
            CREATE TABLE IF NOT EXISTS app_settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            )
            """
        ),
    ]

    /// Columns the running code reads/writes, with the DDL used to add one
    /// if it is missing. Every entry must have a DEFAULT (existing rows).
    private static let requiredColumns: [(table: String, column: String, definition: String)] = [
        ("accounts", "label", "TEXT NOT NULL DEFAULT ''"),
        ("accounts", "registrar", "TEXT NOT NULL DEFAULT ''"),
        ("accounts", "auth_id", "TEXT NOT NULL DEFAULT ''"),
        ("accounts", "display_name", "TEXT NOT NULL DEFAULT ''"),
        ("accounts", "transport", "TEXT NOT NULL DEFAULT 'udp'"),
        ("accounts", "reg_interval", "INTEGER NOT NULL DEFAULT 0"),
        ("accounts", "registration_enabled", "INTEGER NOT NULL DEFAULT 1"),
        ("accounts", "media_encryption", "TEXT NOT NULL DEFAULT 'none'"),
        ("accounts", "tls_verify_disabled", "INTEGER NOT NULL DEFAULT 0"),
        ("accounts", "stun_server", "TEXT NOT NULL DEFAULT ''"),
        ("accounts", "ice_enabled", "INTEGER NOT NULL DEFAULT 0"),
        ("accounts", "turn_server", "TEXT NOT NULL DEFAULT ''"),
        ("accounts", "turn_username", "TEXT NOT NULL DEFAULT ''"),
        ("accounts", "turn_password_ref", "TEXT NOT NULL DEFAULT ''"),
        ("accounts", "outbound_proxy", "TEXT NOT NULL DEFAULT ''"),
        ("accounts", "keepalive_interval", "INTEGER NOT NULL DEFAULT 0"),
        ("accounts", "session_timer_mode", "TEXT NOT NULL DEFAULT 'optional'"),
        ("accounts", "session_timer_expiry", "INTEGER NOT NULL DEFAULT 0"),
        ("accounts", "contact_rewrite", "INTEGER NOT NULL DEFAULT 1"),
        ("accounts", "via_rewrite", "INTEGER NOT NULL DEFAULT 1"),
        ("accounts", "voicemail_number", "TEXT NOT NULL DEFAULT ''"),
        ("accounts", "dial_prefix", "TEXT NOT NULL DEFAULT ''"),
        ("call_history", "remote_display", "TEXT NOT NULL DEFAULT ''"),
        ("call_history", "connected_at", "REAL"),
        ("call_history", "raw_sip_code", "INTEGER"),
    ]

    /// Verifies the schema and repairs it additively.
    /// Returns a description of every repair performed (empty = healthy).
    @discardableResult
    static func verifyAndRepair(_ db: Database) throws -> [String] {
        var repairs: [String] = []

        for table in requiredTables where try !tableExists(db, table.name) {
            try db.execute(table.createSQL)
            repairs.append("created missing table \(table.name)")
        }

        for required in requiredColumns {
            let existing = try columns(db, table: required.table)
            guard !existing.contains(required.column) else { continue }
            try db.execute(
                "ALTER TABLE \(required.table) ADD COLUMN \(required.column) \(required.definition)")
            repairs.append("added missing column \(required.table).\(required.column)")
        }

        if !repairs.isEmpty {
            // Loud on purpose: this means the DB and the version stamp
            // disagreed, which is worth knowing about.
            log.warning(
                "Schema repaired (stamp disagreed with actual schema): \(repairs.joined(separator: "; "), privacy: .public)"
            )
        }
        return repairs
    }

    static func tableExists(_ db: Database, _ name: String) throws -> Bool {
        try !db.query(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?", [.text(name)]
        ).isEmpty
    }

    static func columns(_ db: Database, table: String) throws -> Set<String> {
        // PRAGMA does not accept bound parameters; the table name comes
        // from the static list above, never from user input.
        Set(try db.query("PRAGMA table_info(\(table))").compactMap { $0["name"]?.textValue })
    }
}
