import Foundation
import SQLite3

public final class ReverbDatabase: @unchecked Sendable {
    private var db: OpaquePointer?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(url: URL = ReverbDatabase.defaultURL()) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard sqlite3_open(url.path, &db) == SQLITE_OK else {
            throw databaseError("Unable to open database")
        }
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        try migrate()
    }

    deinit {
        sqlite3_close(db)
    }

    public static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("Audio Convolution Reverb/reverb.sqlite")
    }

    public func saveRender(_ record: RenderRecord) throws -> Int64 {
        let sql = """
        INSERT INTO renders (name, created_at, dry_path, impulse_path, output_path, settings_json, sample_rate, duration)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?);
        """
        try execute(sql) { statement in
            bind(record.name, to: statement, at: 1)
            bind(record.createdAt.timeIntervalSince1970, to: statement, at: 2)
            bind(record.dryPath, to: statement, at: 3)
            bind(record.impulsePath, to: statement, at: 4)
            bind(record.outputPath, to: statement, at: 5)
            bind(String(data: try self.encoder.encode(record.settings), encoding: .utf8) ?? "{}", to: statement, at: 6)
            bind(Int64(record.sampleRate), to: statement, at: 7)
            bind(record.duration, to: statement, at: 8)
        }
        return sqlite3_last_insert_rowid(db)
    }

    public func renders(limit: Int = 30) throws -> [RenderRecord] {
        let sql = "SELECT id, name, created_at, dry_path, impulse_path, output_path, settings_json, sample_rate, duration FROM renders ORDER BY created_at DESC LIMIT ?;"
        return try query(sql, bind: { statement in
            bind(Int64(limit), to: statement, at: 1)
        }) { statement in
            let json = text(statement, 6).data(using: .utf8) ?? Data()
            let settings = (try? decoder.decode(ReverbSettings.self, from: json)) ?? ReverbSettings()
            return RenderRecord(
                id: sqlite3_column_int64(statement, 0),
                name: text(statement, 1),
                createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 2)),
                dryPath: text(statement, 3),
                impulsePath: text(statement, 4),
                outputPath: text(statement, 5),
                settings: settings,
                sampleRate: Int(sqlite3_column_int64(statement, 7)),
                duration: sqlite3_column_double(statement, 8)
            )
        }
    }

    public func savePreset(_ preset: ReverbPreset) throws -> Int64 {
        let sql = "INSERT INTO presets (name, created_at, settings_json) VALUES (?, ?, ?);"
        try execute(sql) { statement in
            bind(preset.name, to: statement, at: 1)
            bind(preset.createdAt.timeIntervalSince1970, to: statement, at: 2)
            bind(String(data: try self.encoder.encode(preset.settings), encoding: .utf8) ?? "{}", to: statement, at: 3)
        }
        return sqlite3_last_insert_rowid(db)
    }

    public func presets() throws -> [ReverbPreset] {
        try query("SELECT id, name, created_at, settings_json FROM presets ORDER BY created_at DESC;") { statement in
            let json = text(statement, 3).data(using: .utf8) ?? Data()
            let settings = (try? decoder.decode(ReverbSettings.self, from: json)) ?? ReverbSettings()
            return ReverbPreset(
                id: sqlite3_column_int64(statement, 0),
                name: text(statement, 1),
                createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 2)),
                settings: settings
            )
        }
    }

    private func migrate() throws {
        try execute("""
        CREATE TABLE IF NOT EXISTS renders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            created_at REAL NOT NULL,
            dry_path TEXT NOT NULL,
            impulse_path TEXT NOT NULL,
            output_path TEXT NOT NULL,
            settings_json TEXT NOT NULL,
            sample_rate INTEGER NOT NULL,
            duration REAL NOT NULL
        );
        """)

        try execute("""
        CREATE TABLE IF NOT EXISTS presets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            created_at REAL NOT NULL,
            settings_json TEXT NOT NULL
        );
        """)

        if try presets().isEmpty {
            _ = try savePreset(ReverbPreset(name: "Clean Room", settings: ReverbSettings(dryLevel: 0.65, wetLevel: 0.35, decayScale: 0.9)))
            _ = try savePreset(ReverbPreset(name: "Wide Hall", settings: ReverbSettings(dryLevel: 0.45, wetLevel: 0.65, preDelayMilliseconds: 18, decayScale: 1.35, highCutHz: 14_000)))
            _ = try savePreset(ReverbPreset(name: "Reverse Bloom", settings: ReverbSettings(dryLevel: 0.5, wetLevel: 0.6, preDelayMilliseconds: 12, decayScale: 1.2, reverseImpulse: true)))
        }
    }

    private func execute(_ sql: String, binder: ((OpaquePointer) throws -> Void)? = nil) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw databaseError("Unable to prepare SQL")
        }
        defer { sqlite3_finalize(statement) }
        try binder?(statement)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw databaseError("Unable to execute SQL")
        }
    }

    private func query<T>(_ sql: String, bind binder: ((OpaquePointer) throws -> Void)? = nil, map: (OpaquePointer) throws -> T) throws -> [T] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw databaseError("Unable to prepare query")
        }
        defer { sqlite3_finalize(statement) }
        try binder?(statement)

        var values: [T] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            values.append(try map(statement))
        }
        return values
    }

    private func databaseError(_ prefix: String) -> NSError {
        let message = db.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "Unknown database error"
        return NSError(domain: "AudioConvolutionReverb.Database", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(prefix): \(message)"])
    }
}

private func bind(_ value: String, to statement: OpaquePointer, at index: Int32) {
    sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
}

private func bind(_ value: Int64, to statement: OpaquePointer, at index: Int32) {
    sqlite3_bind_int64(statement, index, value)
}

private func bind(_ value: Double, to statement: OpaquePointer, at index: Int32) {
    sqlite3_bind_double(statement, index, value)
}

private func text(_ statement: OpaquePointer, _ column: Int32) -> String {
    guard let pointer = sqlite3_column_text(statement, column) else { return "" }
    return String(cString: pointer)
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
