import Foundation
import SQLite3

/// Thin wrapper over system SQLite. NOT thread-safe by design — Milestone 1
/// repositories are used from the main actor only; a serial database queue
/// arrives if/when profiling demands it.
nonisolated final class Database {
    /// The SQL is retained for logs/tests but deliberately kept OUT of the
    /// user-facing description — a UI error should read "table accounts
    /// has no column named x", not dump a 30-line statement.
    enum DatabaseError: Error, Equatable, LocalizedError {
        case open(String)
        case prepare(String, sql: String)
        case step(String, sql: String)

        var errorDescription: String? {
            switch self {
            case .open(let message): "Could not open the database: \(message)"
            case .prepare(let message, _), .step(let message, _): "Database error: \(message)"
            }
        }

        /// Full statement, for logging only.
        var sql: String? {
            switch self {
            case .open: nil
            case .prepare(_, let sql), .step(_, let sql): sql
            }
        }
    }

    private var handle: OpaquePointer?

    /// Transient bindings (SQLITE_TRANSIENT): SQLite copies bound buffers.
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(path: String) throws {
        var db: OpaquePointer?
        guard sqlite3_open(path, &db) == SQLITE_OK, let db else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "cannot open"
            sqlite3_close(db)
            throw DatabaseError.open(message)
        }
        handle = db
        try execute("PRAGMA foreign_keys = ON")
    }

    deinit {
        sqlite3_close(handle)
    }

    private func lastMessage() -> String {
        handle.map { String(cString: sqlite3_errmsg($0)) } ?? "no database"
    }

    /// Executes a statement with optional bindings; discards rows.
    func execute(_ sql: String, _ bindings: [SQLValue] = []) throws {
        _ = try query(sql, bindings)
    }

    /// Runs a query, returning all rows as dictionaries keyed by column name.
    func query(_ sql: String, _ bindings: [SQLValue] = []) throws -> [[String: SQLValue]] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepare(lastMessage(), sql: sql)
        }
        defer { sqlite3_finalize(statement) }

        for (index, value) in bindings.enumerated() {
            let position = Int32(index + 1)
            switch value {
            case .null: sqlite3_bind_null(statement, position)
            case .integer(let integer): sqlite3_bind_int64(statement, position, integer)
            case .real(let double): sqlite3_bind_double(statement, position, double)
            case .text(let string): sqlite3_bind_text(statement, position, string, -1, Self.transient)
            }
        }

        var rows: [[String: SQLValue]] = []
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_DONE { break }
            guard result == SQLITE_ROW else {
                throw DatabaseError.step(lastMessage(), sql: sql)
            }
            var row: [String: SQLValue] = [:]
            for column in 0..<sqlite3_column_count(statement) {
                let name = String(cString: sqlite3_column_name(statement, column))
                switch sqlite3_column_type(statement, column) {
                case SQLITE_INTEGER: row[name] = .integer(sqlite3_column_int64(statement, column))
                case SQLITE_FLOAT: row[name] = .real(sqlite3_column_double(statement, column))
                case SQLITE_TEXT: row[name] = .text(String(cString: sqlite3_column_text(statement, column)))
                default: row[name] = .null
                }
            }
            rows.append(row)
        }
        return rows
    }
}

nonisolated enum SQLValue: Equatable, Sendable {
    case null
    case integer(Int64)
    case real(Double)
    case text(String)

    var intValue: Int64? {
        if case .integer(let value) = self { return value }
        return nil
    }

    var doubleValue: Double? {
        switch self {
        case .real(let value): return value
        case .integer(let value): return Double(value)
        default: return nil
        }
    }

    var textValue: String? {
        if case .text(let value) = self { return value }
        return nil
    }
}
