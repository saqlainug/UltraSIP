import Foundation

nonisolated protocol SettingsStoring {
    func set(_ value: String, for key: String) throws
    func value(for key: String) throws -> String?
    func remove(_ key: String) throws
}

/// Small key/value app settings (active account id, etc.). Never secrets —
/// those are Keychain-only (CLAUDE.md).
nonisolated final class SettingsRepository: SettingsStoring {
    enum Key {
        static let activeAccountID = "active_account_id"
    }

    private let db: Database

    init(db: Database) {
        self.db = db
    }

    func set(_ value: String, for key: String) throws {
        try db.execute(
            "INSERT INTO app_settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
            [.text(key), .text(value)])
    }

    func value(for key: String) throws -> String? {
        try db.query("SELECT value FROM app_settings WHERE key = ?", [.text(key)])
            .first?["value"]?.textValue
    }

    func remove(_ key: String) throws {
        try db.execute("DELETE FROM app_settings WHERE key = ?", [.text(key)])
    }
}
