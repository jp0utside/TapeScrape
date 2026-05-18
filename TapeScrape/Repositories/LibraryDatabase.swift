import Foundation
import SQLite3

// SQLITE_TRANSIENT is a C macro ((sqlite3_destructor_type)-1) that Swift can't bridge.
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// Owns the single shared connection to library.sqlite.
// All repositories receive the pointer at init; none open or close connections themselves.
actor LibraryDatabase {
    nonisolated(unsafe) private var db: OpaquePointer?

    // Exposed synchronously so repos can capture the pointer in their synchronous inits.
    nonisolated var pointer: OpaquePointer? { db }

    init(url: URL) {
        var dbPointer: OpaquePointer?
        guard sqlite3_open(url.path, &dbPointer) == SQLITE_OK else {
            fatalError("[LibrarySQLite] cannot open \(url.path)")
        }
        db = dbPointer
        sqlite3_exec(db, "PRAGMA journal_mode=WAL", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA busy_timeout=3000", nil, nil, nil)
        LibraryDatabase.createLibraryTables(db)
        LibraryDatabase.createHistoryTables(db)
        LibraryDatabase.createDownloadTables(db)
    }

    deinit { sqlite3_close(db) }

    // MARK: - Schema (static — called once from init before actor is reachable)

    private static func createLibraryTables(_ db: OpaquePointer?) {
        let stmts = [
            """
            CREATE TABLE IF NOT EXISTS tags (
                id   TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                kind TEXT NOT NULL
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS tagged_items (
                tag_id  TEXT NOT NULL,
                item_id TEXT NOT NULL,
                PRIMARY KEY (tag_id, item_id)
            );
            """,
            // Denormalized concert display data so LibraryTab needs no network call.
            """
            CREATE TABLE IF NOT EXISTS concert_snapshots (
                id       TEXT PRIMARY KEY,
                artist   TEXT NOT NULL,
                date     TEXT NOT NULL,
                venue    TEXT,
                location TEXT
            );
            """,
            // Denormalized playlist track data — enough to display and play without a network call.
            """
            CREATE TABLE IF NOT EXISTS playlist_items (
                playlist_id          TEXT NOT NULL,
                recording_identifier TEXT NOT NULL,
                track_filename       TEXT NOT NULL,
                stream_url           TEXT NOT NULL,
                track_title          TEXT,
                track_duration       TEXT,
                track_index          INT  NOT NULL DEFAULT 0,
                sort_order           INT  NOT NULL,
                concert_id           TEXT,
                artist               TEXT,
                date                 TEXT,
                venue                TEXT,
                PRIMARY KEY (playlist_id, sort_order)
            );
            """
        ]
        for sql in stmts {
            sqlite3_exec(db, sql, nil, nil, nil)
        }
    }

    private static func createDownloadTables(_ db: OpaquePointer?) {
        let stmts = [
            """
            CREATE TABLE IF NOT EXISTS download_recordings (
                identifier      TEXT PRIMARY KEY,
                state           TEXT NOT NULL DEFAULT 'downloading',
                total_tracks    INT  NOT NULL,
                completed_tracks INT NOT NULL DEFAULT 0,
                concert_id      TEXT NOT NULL,
                artist          TEXT NOT NULL,
                date            TEXT NOT NULL,
                venue           TEXT,
                error_message   TEXT
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS download_tracks (
                identifier    TEXT NOT NULL,
                filename      TEXT NOT NULL,
                stream_url    TEXT NOT NULL,
                state         TEXT NOT NULL DEFAULT 'pending',
                local_path    TEXT,
                error_message TEXT,
                PRIMARY KEY (identifier, filename)
            );
            """
        ]
        for sql in stmts {
            sqlite3_exec(db, sql, nil, nil, nil)
        }
    }

    private static func createHistoryTables(_ db: OpaquePointer?) {
        let sql = """
            CREATE TABLE IF NOT EXISTS playback_history (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                identifier  TEXT NOT NULL,
                track_file  TEXT NOT NULL,
                played_at   REAL NOT NULL,
                concert_id  TEXT NOT NULL,
                artist      TEXT NOT NULL,
                date        TEXT NOT NULL,
                venue       TEXT
            );
            """
        sqlite3_exec(db, sql, nil, nil, nil)
    }
}
