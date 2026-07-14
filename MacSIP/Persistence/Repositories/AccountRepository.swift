import Foundation

nonisolated protocol AccountStoring {
    func save(_ account: SIPAccountConfig) throws
    func loadAll() throws -> [SIPAccountConfig]
    func delete(id: UUID) throws
}

/// SQLite-backed account storage. Passwords never touch this layer — only
/// the opaque Keychain reference is persisted (schema has no such column,
/// enforced by tests).
nonisolated final class AccountRepository: AccountStoring {
    private let db: Database

    init(db: Database) {
        self.db = db
    }

    func save(_ account: SIPAccountConfig) throws {
        try db.execute(
            """
            INSERT INTO accounts (id, label, domain, registrar, username, auth_id,
                display_name, transport, reg_interval, keychain_ref, registration_enabled,
                media_encryption, tls_verify_disabled, stun_server, ice_enabled,
                turn_server, turn_username, turn_password_ref)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                label = excluded.label, domain = excluded.domain,
                registrar = excluded.registrar, username = excluded.username,
                auth_id = excluded.auth_id, display_name = excluded.display_name,
                transport = excluded.transport, reg_interval = excluded.reg_interval,
                keychain_ref = excluded.keychain_ref,
                registration_enabled = excluded.registration_enabled,
                media_encryption = excluded.media_encryption,
                tls_verify_disabled = excluded.tls_verify_disabled,
                stun_server = excluded.stun_server, ice_enabled = excluded.ice_enabled,
                turn_server = excluded.turn_server, turn_username = excluded.turn_username,
                turn_password_ref = excluded.turn_password_ref
            """,
            [
                .text(account.id.uuidString), .text(account.label), .text(account.domain),
                .text(account.registrar), .text(account.username), .text(account.authorizationID),
                .text(account.displayName), .text(account.transport.rawValue),
                .integer(Int64(account.registrationInterval)), .text(account.keychainPasswordRef),
                .integer(account.registrationEnabled ? 1 : 0),
                .text(account.mediaEncryption.rawValue),
                .integer(account.tlsVerificationDisabled ? 1 : 0),
                .text(account.stunServer), .integer(account.iceEnabled ? 1 : 0),
                .text(account.turnServer), .text(account.turnUsername),
                .text(account.turnPasswordRef),
            ])
    }

    func loadAll() throws -> [SIPAccountConfig] {
        try db.query("SELECT * FROM accounts ORDER BY label").compactMap { row in
            guard let idText = row["id"]?.textValue, let id = UUID(uuidString: idText),
                let domain = row["domain"]?.textValue, let username = row["username"]?.textValue
            else { return nil }
            return SIPAccountConfig(
                id: id,
                label: row["label"]?.textValue ?? "",
                domain: domain,
                registrar: row["registrar"]?.textValue ?? "",
                username: username,
                authorizationID: row["auth_id"]?.textValue ?? "",
                displayName: row["display_name"]?.textValue ?? "",
                transport: SIPAccountConfig.Transport(rawValue: row["transport"]?.textValue ?? "udp") ?? .udp,
                registrationInterval: Int(row["reg_interval"]?.intValue ?? 0),
                keychainPasswordRef: row["keychain_ref"]?.textValue ?? "",
                registrationEnabled: (row["registration_enabled"]?.intValue ?? 1) == 1,
                mediaEncryption: SIPAccountConfig.MediaEncryption(
                    rawValue: row["media_encryption"]?.textValue ?? "none") ?? .none,
                tlsVerificationDisabled: (row["tls_verify_disabled"]?.intValue ?? 0) == 1,
                stunServer: row["stun_server"]?.textValue ?? "",
                iceEnabled: (row["ice_enabled"]?.intValue ?? 0) == 1,
                turnServer: row["turn_server"]?.textValue ?? "",
                turnUsername: row["turn_username"]?.textValue ?? "",
                turnPasswordRef: row["turn_password_ref"]?.textValue ?? "")
        }
    }

    func delete(id: UUID) throws {
        try db.execute("DELETE FROM accounts WHERE id = ?", [.text(id.uuidString)])
    }
}
