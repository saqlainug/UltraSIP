import XCTest

@testable import UltraSIP

final class PersistenceTests: XCTestCase {
    private var dbPath: String!
    private var db: Database!

    override func setUpWithError() throws {
        dbPath = NSTemporaryDirectory() + "ultrasip-test-\(UUID().uuidString).sqlite"
        db = try Database(path: dbPath)
        try Migrations.migrate(db)
    }

    override func tearDownWithError() throws {
        db = nil
        if let dbPath {
            try? FileManager.default.removeItem(atPath: dbPath)
        }
    }

    // MARK: Migrations

    func testFreshDatabaseMigratesToLatest() throws {
        XCTAssertEqual(try Migrations.currentVersion(db), Migrations.latestVersion)
    }

    func testMigrationIsIdempotentOnReopen() throws {
        db = nil
        let reopened = try Database(path: dbPath)
        try Migrations.migrate(reopened)
        XCTAssertEqual(try Migrations.currentVersion(reopened), Migrations.latestVersion)
    }

    func testMigrationVersionsAreContiguousFromOne() {
        let versions = Migrations.all.map(\.version).sorted()
        XCTAssertEqual(versions, Array(1...versions.count), "migrations must be append-only and contiguous")
    }

    /// CLAUDE.md security rule: no password/secret columns, ever. Guards
    /// every future migration as well as v1.
    func testNoSecretColumnsExist() throws {
        let tables = try db.query("SELECT name FROM sqlite_master WHERE type = 'table'")
            .compactMap { $0["name"]?.textValue }
        XCTAssertFalse(tables.isEmpty)
        for table in tables {
            let columns = try db.query("PRAGMA table_info(\(table))")
                .compactMap { $0["name"]?.textValue?.lowercased() }
            for column in columns {
                // "*_ref" columns are opaque Keychain references — the
                // sanctioned mechanism (CLAUDE.md). Anything else that
                // smells like a secret is forbidden.
                if column.hasSuffix("_ref") { continue }
                XCTAssertFalse(
                    column.contains("password") || column.contains("secret") || column == "credential",
                    "table \(table) has forbidden column \(column)")
            }
        }
        // The Keychain reference columns must exist instead.
        let accountColumns = try db.query("PRAGMA table_info(accounts)")
            .compactMap { $0["name"]?.textValue }
        XCTAssertTrue(accountColumns.contains("keychain_ref"))
        XCTAssertTrue(accountColumns.contains("turn_password_ref"))
    }

    // MARK: Accounts

    func testAccountRoundTrip() throws {
        let repo = AccountRepository(db: db)
        var config = SIPAccountConfig(
            label: "Work", domain: "pbx.example.com", registrar: "sip:edge.example.com",
            username: "alice", authorizationID: "alice-auth", displayName: "Alice",
            transport: .tls, registrationInterval: 120, keychainPasswordRef: "sip-account-x",
            registrationEnabled: false, mediaEncryption: .srtpMandatory,
            tlsVerificationDisabled: true)
        try repo.save(config)
        XCTAssertEqual(try repo.loadAll(), [config])

        config.label = "Home"
        config.registrationEnabled = true
        try repo.save(config)
        let reloaded = try repo.loadAll()
        XCTAssertEqual(reloaded.count, 1, "upsert must not duplicate")
        XCTAssertEqual(reloaded.first, config)

        try repo.delete(id: config.id)
        XCTAssertEqual(try repo.loadAll(), [])
    }

    // MARK: Schema guard (corruption handling)

    /// Reproduces the real failure: a database whose user_version claims it
    /// is fully migrated while the table is missing columns (written by a
    /// build with divergent migration definitions). Migrations skip it —
    /// the guard must repair it so writes succeed.
    func testStaleVersionStampIsRepaired() throws {
        let stalePath = NSTemporaryDirectory() + "ultrasip-stale-\(UUID().uuidString).sqlite"
        defer { try? FileManager.default.removeItem(atPath: stalePath) }

        do {
            let stale = try Database(path: stalePath)
            // v1-era accounts table + an orphan column from another lineage.
            try stale.execute(
                """
                CREATE TABLE accounts (
                    id TEXT PRIMARY KEY, label TEXT NOT NULL DEFAULT '',
                    domain TEXT NOT NULL, registrar TEXT NOT NULL DEFAULT '',
                    username TEXT NOT NULL, auth_id TEXT NOT NULL DEFAULT '',
                    display_name TEXT NOT NULL DEFAULT '', transport TEXT NOT NULL DEFAULT 'udp',
                    reg_interval INTEGER NOT NULL DEFAULT 0, keychain_ref TEXT NOT NULL,
                    registration_enabled INTEGER NOT NULL DEFAULT 1,
                    turn_keychain_ref TEXT NOT NULL DEFAULT ''
                )
                """)
            // Claim it is fully migrated — the bug's signature.
            try stale.execute("PRAGMA user_version = \(Migrations.latestVersion)")
        }

        let db = try Database(path: stalePath)
        try Migrations.migrate(db)  // no-op: stamp says we are current
        let repairs = try SchemaGuard.verifyAndRepair(db)
        XCTAssertFalse(repairs.isEmpty, "guard must repair the stale schema")

        // The columns the code needs now exist…
        let columns = try SchemaGuard.columns(db, table: "accounts")
        XCTAssertTrue(columns.contains("turn_password_ref"))
        XCTAssertTrue(columns.contains("dial_prefix"))
        XCTAssertTrue(columns.contains("session_timer_mode"))
        // …the orphan column from the other lineage is left alone…
        XCTAssertTrue(columns.contains("turn_keychain_ref"))
        // …missing tables were created…
        XCTAssertTrue(try SchemaGuard.tableExists(db, "app_settings"))
        XCTAssertTrue(try SchemaGuard.tableExists(db, "call_history"))

        // …and the write that used to fail now succeeds and round-trips.
        let repo = AccountRepository(db: db)
        let config = SIPAccountConfig(
            label: "Repaired", domain: "pbx.example.com", username: "101",
            keychainPasswordRef: "ref")
        try repo.save(config)
        XCTAssertEqual(try repo.loadAll(), [config])
    }

    func testGuardIsNoOpOnHealthyDatabase() throws {
        XCTAssertEqual(try SchemaGuard.verifyAndRepair(db), [], "fresh schema needs no repair")
    }

    /// A SQL failure must not surface the whole statement to the user.
    func testDatabaseErrorDescriptionOmitsSQL() {
        let error = Database.DatabaseError.step(
            "table accounts has no column named turn_password_ref",
            sql: "INSERT INTO accounts (id, label) VALUES (?, ?)")
        let description = error.localizedDescription
        XCTAssertTrue(description.contains("has no column named turn_password_ref"))
        XCTAssertFalse(description.contains("INSERT INTO"), "user-facing text must not dump SQL")
        XCTAssertEqual(error.sql, "INSERT INTO accounts (id, label) VALUES (?, ?)", "SQL kept for logs")
    }

    // MARK: Settings

    func testSettingsRoundTrip() throws {
        let repo = SettingsRepository(db: db)
        XCTAssertNil(try repo.value(for: "active_account_id"))
        try repo.set("abc-123", for: "active_account_id")
        XCTAssertEqual(try repo.value(for: "active_account_id"), "abc-123")
        try repo.set("def-456", for: "active_account_id")
        XCTAssertEqual(try repo.value(for: "active_account_id"), "def-456", "upsert must replace")
        try repo.remove("active_account_id")
        XCTAssertNil(try repo.value(for: "active_account_id"))
    }

    func testAccountNATFieldsRoundTrip() throws {
        let repo = AccountRepository(db: db)
        var config = SIPAccountConfig(domain: "pbx.example.com", username: "n1")
        config.stunServer = "stun.example.com:3478"
        config.iceEnabled = true
        config.turnServer = "turn.example.com:3478"
        config.turnUsername = "turnuser"
        config.turnPasswordRef = "turn-cred-x"
        config.transport = .auto
        config.outboundProxy = "sip:edge.example.com"
        config.keepaliveInterval = 25
        config.sessionTimerMode = .required
        config.sessionTimerExpiry = 900
        config.contactRewrite = false
        config.viaRewrite = false
        config.voicemailNumber = "*97"
        config.dialPrefix = "9"
        try repo.save(config)
        XCTAssertEqual(try repo.loadAll(), [config])
    }

    // MARK: History

    func testHistoryRoundTripAndOrdering() throws {
        let repo = HistoryRepository(db: db)
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let answered = CallHistoryEntry(
            id: UUID(), direction: .outgoing, remoteURI: "sip:100@pbx", remoteDisplayName: "Echo",
            startedAt: base, connectedAt: base.addingTimeInterval(2),
            endedAt: base.addingTimeInterval(62), outcome: "Ended", rawSIPCode: nil)
        let missed = CallHistoryEntry(
            id: UUID(), direction: .incoming, remoteURI: "sip:101@pbx", remoteDisplayName: "",
            startedAt: base.addingTimeInterval(100), connectedAt: nil,
            endedAt: base.addingTimeInterval(115), outcome: "Cancelled", rawSIPCode: 487)
        try repo.append(answered)
        try repo.append(missed)

        let recent = try repo.recent(limit: 10)
        XCTAssertEqual(recent.count, 2)
        XCTAssertEqual(recent.first?.id, missed.id, "newest first")
        XCTAssertNil(recent.first?.talkDuration, "unanswered call has no talk duration")
        XCTAssertEqual(recent.last?.talkDuration ?? 0, 60, accuracy: 0.5)
        XCTAssertEqual(recent.first?.rawSIPCode, 487)

        XCTAssertEqual(try repo.recent(limit: 1).count, 1)
        try repo.deleteAll()
        XCTAssertEqual(try repo.recent(limit: 10), [])
    }

    // MARK: Rebrand carry-over

    /// The rename moved the store from Application Support/MacSIP/
    /// macsip.sqlite to UltraSIP/ultrasip.sqlite. An upgrading user's
    /// accounts, history and settings must come with it — arriving at an
    /// empty app after an update is data loss from the user's point of view.
    func testLegacyStoreIsAdoptedOnFirstLaunch() throws {
        let support = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("support-\(UUID().uuidString)", isDirectory: true)
        let legacyDirectory = support.appendingPathComponent("MacSIP", isDirectory: true)
        try FileManager.default.createDirectory(at: legacyDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: support) }

        // A populated store written by the old build.
        let legacyDatabase = legacyDirectory.appendingPathComponent("macsip.sqlite")
        let legacyDB = try Database(path: legacyDatabase.path)
        try Migrations.migrate(legacyDB)
        let account = SIPAccountConfig(
            label: "Ultranet", domain: "sip.example.net", username: "923336726475",
            keychainPasswordRef: "ref-legacy")
        try AccountRepository(db: legacyDB).save(account)

        let newDirectory = support.appendingPathComponent("UltraSIP", isDirectory: true)
        try PersistenceStack.adoptLegacyStoreIfNeeded(in: support, newDirectory: newDirectory)

        let adopted = newDirectory.appendingPathComponent("ultrasip.sqlite")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: adopted.path), "legacy store was not carried over")
        let migratedDB = try Database(path: adopted.path)
        XCTAssertEqual(try AccountRepository(db: migratedDB).loadAll(), [account])

        // Runs exactly once: the legacy directory is moved aside, and a
        // second call must not touch the now-live store.
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyDatabase.path))
        XCTAssertNoThrow(
            try PersistenceStack.adoptLegacyStoreIfNeeded(in: support, newDirectory: newDirectory))
    }

    /// Never clobber a real UltraSIP store with a stale MacSIP one.
    func testLegacyStoreIsIgnoredWhenCurrentStoreExists() throws {
        let support = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("support-\(UUID().uuidString)", isDirectory: true)
        let legacyDirectory = support.appendingPathComponent("MacSIP", isDirectory: true)
        let newDirectory = support.appendingPathComponent("UltraSIP", isDirectory: true)
        try FileManager.default.createDirectory(at: legacyDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: newDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: support) }

        let legacyDatabase = legacyDirectory.appendingPathComponent("macsip.sqlite")
        let legacyDB = try Database(path: legacyDatabase.path)
        try Migrations.migrate(legacyDB)
        try AccountRepository(db: legacyDB).save(
            SIPAccountConfig(
                label: "stale", domain: "old.example", username: "old",
                keychainPasswordRef: "ref-old"))

        // The current store already holds the live account.
        let current = newDirectory.appendingPathComponent("ultrasip.sqlite")
        let currentDB = try Database(path: current.path)
        try Migrations.migrate(currentDB)
        let live = SIPAccountConfig(
            label: "live", domain: "sip.example.net", username: "live",
            keychainPasswordRef: "ref-live")
        try AccountRepository(db: currentDB).save(live)

        try PersistenceStack.adoptLegacyStoreIfNeeded(in: support, newDirectory: newDirectory)

        let reopened = try Database(path: current.path)
        XCTAssertEqual(
            try AccountRepository(db: reopened).loadAll(), [live],
            "the live store must never be overwritten by the legacy one")
    }
}
