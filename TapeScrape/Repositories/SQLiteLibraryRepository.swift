import Foundation
import SQLite3

// SQLITE_TRANSIENT is a C macro ((sqlite3_destructor_type)-1) that Swift can't bridge.
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// SQLite-backed LibraryRepository. Uses the stdlib sqlite3 C API (no ORM).
// All SQL is parameterized. Schema creation is idempotent.
// The system "favorite" tag is seeded once on first open.
actor SQLiteLibraryRepository: LibraryRepository {
    // nonisolated(unsafe): actor serializes all access; deinit has exclusive ownership.
    nonisolated(unsafe) private var db: OpaquePointer?

    init(dbURL: URL) {
        if sqlite3_open(dbURL.path, &db) != SQLITE_OK {
            db = nil
            return
        }
        // Static helpers run synchronously in init before the actor is reachable
        // from outside, so Swift 6 isolation is satisfied.
        SQLiteLibraryRepository.createTables(db)
        SQLiteLibraryRepository.seedFavoriteTag(db)
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Schema (static — safe to call from init)

    private static func createTables(_ db: OpaquePointer?) {
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

    private static func seedFavoriteTag(_ db: OpaquePointer?) {
        let sql = "INSERT OR IGNORE INTO tags (id, name, kind) VALUES (?, ?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        let tag = Tag.favoriteTag
        sqlite3_bind_text(stmt, 1, tag.id.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, tag.name, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, tag.kind.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_step(stmt)
    }

    // MARK: - LibraryRepository: tags

    func tags() async -> [Tag] {
        var results: [Tag] = []
        var stmt: OpaquePointer?
        let sql = "SELECT id, name, kind FROM tags;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard
                let rawID   = sqlite3_column_text(stmt, 0),
                let rawName = sqlite3_column_text(stmt, 1),
                let rawKind = sqlite3_column_text(stmt, 2),
                let id = UUID(uuidString: String(cString: rawID)),
                let kind = TagKind(rawValue: String(cString: rawKind))
            else { continue }
            results.append(Tag(id: id, name: String(cString: rawName), kind: kind))
        }
        return results
    }

    func addTag(_ tag: Tag) async throws {
        let sql = "INSERT OR IGNORE INTO tags (id, name, kind) VALUES (?, ?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, tag.id.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, tag.name, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, tag.kind.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_step(stmt)
    }

    func removeTag(_ id: Tag.ID) async throws {
        exec("DELETE FROM tagged_items WHERE tag_id = ?;", id.uuidString)
        exec("DELETE FROM tags WHERE id = ?;", id.uuidString)
    }

    func items(for tagID: Tag.ID) async -> [TaggedItem] {
        var results: [TaggedItem] = []
        let sql = "SELECT item_id FROM tagged_items WHERE tag_id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, tagID.uuidString, -1, SQLITE_TRANSIENT)
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let raw = sqlite3_column_text(stmt, 0) else { continue }
            results.append(TaggedItem(tagID: tagID, itemID: String(cString: raw)))
        }
        return results
    }

    func tagItem(_ itemID: String, with tagID: Tag.ID) async throws {
        exec("INSERT OR IGNORE INTO tagged_items (tag_id, item_id) VALUES (?, ?);",
             tagID.uuidString, itemID)
    }

    func untagItem(_ itemID: String, from tagID: Tag.ID) async throws {
        exec("DELETE FROM tagged_items WHERE tag_id = ? AND item_id = ?;",
             tagID.uuidString, itemID)
    }

    // MARK: - LibraryRepository: favorites convenience

    func isFavorited(_ itemID: String) async -> Bool {
        let sql = "SELECT 1 FROM tagged_items WHERE tag_id = ? AND item_id = ? LIMIT 1;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, Tag.favoriteTagID.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, itemID, -1, SQLITE_TRANSIENT)
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    func favoritedConcerts() async -> [ConcertSnapshot] {
        let sql = """
            SELECT cs.id, cs.artist, cs.date, cs.venue, cs.location
            FROM concert_snapshots cs
            INNER JOIN tagged_items ti ON ti.item_id = cs.id
            WHERE ti.tag_id = ?
            ORDER BY cs.date DESC;
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, Tag.favoriteTagID.uuidString, -1, SQLITE_TRANSIENT)
        var results: [ConcertSnapshot] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard
                let rawID     = sqlite3_column_text(stmt, 0),
                let rawArtist = sqlite3_column_text(stmt, 1),
                let rawDate   = sqlite3_column_text(stmt, 2)
            else { continue }
            let venue    = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
            let location = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
            results.append(ConcertSnapshot(
                id: String(cString: rawID),
                artist: String(cString: rawArtist),
                date: String(cString: rawDate),
                venue: venue,
                location: location
            ))
        }
        return results
    }

    func setFavorite(_ snapshot: ConcertSnapshot, isFavorite: Bool) async throws {
        if isFavorite {
            upsertSnapshot(snapshot)
            exec("INSERT OR IGNORE INTO tagged_items (tag_id, item_id) VALUES (?, ?);",
                 Tag.favoriteTagID.uuidString, snapshot.id)
        } else {
            exec("DELETE FROM tagged_items WHERE tag_id = ? AND item_id = ?;",
                 Tag.favoriteTagID.uuidString, snapshot.id)
        }
    }

    // MARK: - LibraryRepository: playlists

    func createPlaylist(name: String) async throws -> Tag {
        let tag = Tag(id: UUID(), name: name, kind: .playlist)
        let sql = "INSERT INTO tags (id, name, kind) VALUES (?, ?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return tag }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, tag.id.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, tag.name, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, tag.kind.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_step(stmt)
        return tag
    }

    func deletePlaylist(id: Tag.ID) async throws {
        exec("DELETE FROM playlist_items WHERE playlist_id = ?;", id.uuidString)
        exec("DELETE FROM tags WHERE id = ?;", id.uuidString)
    }

    func renamePlaylist(id: Tag.ID, name: String) async throws {
        exec("UPDATE tags SET name = ? WHERE id = ?;", name, id.uuidString)
    }

    func playlistTags() async -> [Tag] {
        var results: [Tag] = []
        let sql = "SELECT id, name FROM tags WHERE kind = 'playlist' ORDER BY name;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let rawID = sqlite3_column_text(stmt, 0),
                  let rawName = sqlite3_column_text(stmt, 1),
                  let id = UUID(uuidString: String(cString: rawID))
            else { continue }
            results.append(Tag(id: id, name: String(cString: rawName), kind: .playlist))
        }
        return results
    }

    func playlistItems(for playlistID: Tag.ID) async -> [PlaylistItem] {
        fetchPlaylistItems(playlistID: playlistID.uuidString)
    }

    func addToPlaylist(id: Tag.ID, items: [PlaylistItem]) async throws {
        var nextSort: Int32 = 0
        let maxSQL = "SELECT COALESCE(MAX(sort_order), -1) + 1 FROM playlist_items WHERE playlist_id = ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, maxSQL, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW { nextSort = sqlite3_column_int(stmt, 0) }
            sqlite3_finalize(stmt)
        }
        for (offset, item) in items.enumerated() {
            insertPlaylistItem(item, playlistID: id.uuidString, sortOrder: Int(nextSort) + offset)
        }
    }

    func removeFromPlaylist(id: Tag.ID, at sortOrder: Int) async throws {
        var items = fetchPlaylistItems(playlistID: id.uuidString)
        items.removeAll { $0.sortOrder == sortOrder }
        rewritePlaylistItems(items, playlistID: id.uuidString)
    }

    func moveInPlaylist(id: Tag.ID, from: Int, to: Int) async throws {
        var items = fetchPlaylistItems(playlistID: id.uuidString)
        guard from < items.count else { return }
        items.move(fromOffsets: IndexSet(integer: from), toOffset: to)
        rewritePlaylistItems(items, playlistID: id.uuidString)
    }

    // MARK: - Helpers

    private func upsertSnapshot(_ s: ConcertSnapshot) {
        let sql = """
            INSERT INTO concert_snapshots (id, artist, date, venue, location)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                artist   = excluded.artist,
                date     = excluded.date,
                venue    = excluded.venue,
                location = excluded.location;
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, s.id, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, s.artist, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, s.date, -1, SQLITE_TRANSIENT)
        bindNullableText(stmt, index: 4, value: s.venue)
        bindNullableText(stmt, index: 5, value: s.location)
        sqlite3_step(stmt)
    }

    private func exec(_ sql: String, _ params: String...) {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        for (i, p) in params.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), p, -1, SQLITE_TRANSIENT)
        }
        sqlite3_step(stmt)
    }

    private func bindNullableText(_ stmt: OpaquePointer?, index: Int32, value: String?) {
        if let v = value {
            sqlite3_bind_text(stmt, index, v, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    private func fetchPlaylistItems(playlistID: String) -> [PlaylistItem] {
        let sql = """
            SELECT recording_identifier, track_filename, stream_url,
                   track_title, track_duration, track_index, sort_order,
                   concert_id, artist, date, venue
            FROM playlist_items
            WHERE playlist_id = ?
            ORDER BY sort_order;
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, playlistID, -1, SQLITE_TRANSIENT)
        var results: [PlaylistItem] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let rawRecording = sqlite3_column_text(stmt, 0),
                  let rawFilename  = sqlite3_column_text(stmt, 1),
                  let rawStream    = sqlite3_column_text(stmt, 2)
            else { continue }
            let trackTitle    = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
            let trackDuration = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
            let trackIndex    = Int(sqlite3_column_int(stmt, 5))
            let sortOrder     = Int(sqlite3_column_int(stmt, 6))
            let concertID     = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
            let artist        = sqlite3_column_text(stmt, 8).map { String(cString: $0) }
            let date          = sqlite3_column_text(stmt, 9).map { String(cString: $0) }
            let venue         = sqlite3_column_text(stmt, 10).map { String(cString: $0) }
            results.append(PlaylistItem(
                id: UUID(),
                recordingIdentifier: String(cString: rawRecording),
                trackFilename: String(cString: rawFilename),
                streamURL: String(cString: rawStream),
                trackTitle: trackTitle,
                trackDuration: trackDuration,
                trackIndex: trackIndex,
                sortOrder: sortOrder,
                concertID: concertID,
                artist: artist,
                date: date,
                venue: venue
            ))
        }
        return results
    }

    private func insertPlaylistItem(_ item: PlaylistItem, playlistID: String, sortOrder: Int) {
        let sql = """
            INSERT INTO playlist_items
            (playlist_id, recording_identifier, track_filename, stream_url,
             track_title, track_duration, track_index, sort_order,
             concert_id, artist, date, venue)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, playlistID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, item.recordingIdentifier, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, item.trackFilename, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 4, item.streamURL, -1, SQLITE_TRANSIENT)
        bindNullableText(stmt, index: 5, value: item.trackTitle)
        bindNullableText(stmt, index: 6, value: item.trackDuration)
        sqlite3_bind_int(stmt, 7, Int32(item.trackIndex))
        sqlite3_bind_int(stmt, 8, Int32(sortOrder))
        bindNullableText(stmt, index: 9, value: item.concertID)
        bindNullableText(stmt, index: 10, value: item.artist)
        bindNullableText(stmt, index: 11, value: item.date)
        bindNullableText(stmt, index: 12, value: item.venue)
        sqlite3_step(stmt)
    }

    private func rewritePlaylistItems(_ items: [PlaylistItem], playlistID: String) {
        exec("DELETE FROM playlist_items WHERE playlist_id = ?;", playlistID)
        for (idx, item) in items.enumerated() {
            insertPlaylistItem(item, playlistID: playlistID, sortOrder: idx)
        }
    }
}
