import Foundation

/// Opens (creating if needed) the app database, runs migrations, and vends
/// repositories. Default location: ~/Library/Application Support/MacSIP/.
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
            let directory = support.appendingPathComponent("MacSIP", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            databasePath = directory.appendingPathComponent("macsip.sqlite").path
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
}
