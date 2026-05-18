import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

actor SQLitePlaybackHistoryRepository: PlaybackHistoryRepository {
    nonisolated(unsafe) private var db: OpaquePointer?

    init(dbURL: URL) {
        if sqlite3_open(dbURL.path, &db) != SQLITE_OK {
            db = nil
            return
        }
        SQLitePlaybackHistoryRepository.createTable(db)
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Schema

    private static func createTable(_ db: OpaquePointer?) {
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

    // MARK: - PlaybackHistoryRepository

    func recordPlay(identifier: String, trackFile: String, at date: Date,
                    context: ConcertContext) async throws {
        let sql = """
            INSERT INTO playback_history
                (identifier, track_file, played_at, concert_id, artist, date, venue)
            VALUES (?, ?, ?, ?, ?, ?, ?);
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, identifier, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, trackFile, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 3, date.timeIntervalSince1970)
        sqlite3_bind_text(stmt, 4, context.concertID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 5, context.artist, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 6, context.date, -1, SQLITE_TRANSIENT)
        if let venue = context.venue {
            sqlite3_bind_text(stmt, 7, venue, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 7)
        }
        sqlite3_step(stmt)
    }

    func recentPlays(limit: Int) async -> [PlayRecord] {
        let sql = """
            SELECT identifier, track_file, played_at
            FROM playback_history
            ORDER BY played_at DESC
            LIMIT ?;
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, Int64(limit))
        var results: [PlayRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard
                let rawIdentifier = sqlite3_column_text(stmt, 0),
                let rawTrackFile  = sqlite3_column_text(stmt, 1)
            else { continue }
            let timestamp = sqlite3_column_double(stmt, 2)
            results.append(PlayRecord(
                identifier: String(cString: rawIdentifier),
                trackFile: String(cString: rawTrackFile),
                playedAt: Date(timeIntervalSince1970: timestamp)
            ))
        }
        return results
    }

    func distinctArtists(limit: Int) async -> [EngagedArtist] {
        let sql = """
            SELECT artist, MAX(played_at) AS last_played, COUNT(*) AS play_count
            FROM playback_history
            GROUP BY LOWER(artist)
            ORDER BY last_played DESC
            LIMIT ?;
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, Int64(limit))
        var results: [EngagedArtist] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let rawArtist = sqlite3_column_text(stmt, 0) else { continue }
            let lastPlayed = sqlite3_column_double(stmt, 1)
            let playCount = Int(sqlite3_column_int64(stmt, 2))
            let displayArtist = String(cString: rawArtist)
            results.append(EngagedArtist(
                canonicalArtist: displayArtist.lowercased(),
                displayArtist: displayArtist,
                lastPlayedAt: Date(timeIntervalSince1970: lastPlayed),
                playCount: playCount
            ))
        }
        return results
    }

    func recentConcerts(limit: Int) async -> [RecentConcert] {
        let sql = """
            SELECT concert_id, artist, date, venue, MAX(played_at) AS last_played
            FROM playback_history
            GROUP BY concert_id
            ORDER BY last_played DESC
            LIMIT ?;
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, Int64(limit))
        var results: [RecentConcert] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard
                let rawConcertID = sqlite3_column_text(stmt, 0),
                let rawArtist    = sqlite3_column_text(stmt, 1),
                let rawDate      = sqlite3_column_text(stmt, 2)
            else { continue }
            let venue     = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
            let timestamp = sqlite3_column_double(stmt, 4)
            results.append(RecentConcert(
                concertID: String(cString: rawConcertID),
                artist: String(cString: rawArtist),
                date: String(cString: rawDate),
                venue: venue,
                lastPlayedAt: Date(timeIntervalSince1970: timestamp)
            ))
        }
        return results
    }
}
