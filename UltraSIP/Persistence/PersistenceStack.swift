import Foundation

/// Opens (creating if needed) the app database, runs migrations, and vends
/// repositories. Default location: ~/Library/Application Support/UltraSIP/.
nonisolated struct PersistenceStack {
    let accounts: any AccountStoring
    let history: any HistoryStoring
    let settings: any SettingsStoring

    static func open(at path: String? = nil) throws -> PersistenceStack {
        let databasePath: String
        if let path {
            databasePath = path
        } else {
            let support = try FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask,
                appropriateFor: nil, create: true)
            let directory = support.appendingPathComponent("UltraSIP", isDirectory: true)
            try adoptLegacyStoreIfNeeded(in: support, newDirectory: directory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            databasePath = directory.appendingPathComponent("ultrasip.sqlite").path
        }
        let db = try Database(path: databasePath)
        try Migrations.migrate(db)
        // Safety net: migrations key off PRAGMA user_version, which can be
        // stamped without the matching schema (divergent build lineages,
        // interrupted upgrades). Repair additively rather than failing
        // every later write with a raw SQL error.
        try SchemaGuard.verifyAndRepair(db)
        return PersistenceStack(
            accounts: AccountRepository(db: db), history: HistoryRepository(db: db),
            settings: SettingsRepository(db: db))
    }

    /// One-time carry-over from the pre-rebrand product name: accounts,
    /// history and settings lived in `Application Support/MacSIP/
    /// macsip.sqlite`. Move that store to the UltraSIP location so an
    /// upgrading user keeps their data instead of silently starting empty.
    /// Only fires when the new store does not exist yet, so it can never
    /// clobber live data; the legacy directory is left in place (renamed
    /// aside) rather than deleted.
    static func adoptLegacyStoreIfNeeded(in support: URL, newDirectory: URL) throws {
        let fileManager = FileManager.default
        let newDatabase = newDirectory.appendingPathComponent("ultrasip.sqlite")
        guard !fileManager.fileExists(atPath: newDatabase.path) else { return }

        let legacyDirectory = support.appendingPathComponent("MacSIP", isDirectory: true)
        let legacyDatabase = legacyDirectory.appendingPathComponent("macsip.sqlite")
        guard fileManager.fileExists(atPath: legacyDatabase.path) else { return }

        try fileManager.createDirectory(at: newDirectory, withIntermediateDirectories: true)
        // SQLite may have -wal/-shm siblings; carry them so no committed
        // transaction is lost.
        for suffix in ["", "-wal", "-shm"] {
            let source = URL(fileURLWithPath: legacyDatabase.path + suffix)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            let destination = URL(fileURLWithPath: newDatabase.path + suffix)
            try fileManager.copyItem(at: source, to: destination)
        }
        // Keep the original as a rollback copy, but move it out of the way so
        // this migration runs exactly once.
        let retired = support.appendingPathComponent("MacSIP (migrated to UltraSIP)", isDirectory: true)
        if !fileManager.fileExists(atPath: retired.path) {
            try? fileManager.moveItem(at: legacyDirectory, to: retired)
        }
    }
}
