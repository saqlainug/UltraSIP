import XCTest

@testable import MacSIP

final class PersistenceTests: XCTestCase {
    private var dbPath: String!
    private var db: Database!

    override func setUpWithError() throws {
        dbPath = NSTemporaryDirectory() + "macsip-test-\(UUID().uuidString).sqlite"
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
}
