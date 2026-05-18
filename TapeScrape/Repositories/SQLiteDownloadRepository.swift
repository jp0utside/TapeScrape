import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

actor SQLiteDownloadRepository: DownloadRepository {
    nonisolated(unsafe) private var db: OpaquePointer?

    init(database: LibraryDatabase) {
        db = database.pointer
    }

    func startDownload(request: DownloadRequest) async throws {
        let sql = """
            INSERT OR REPLACE INTO download_recordings
                (identifier, state, total_tracks, completed_tracks,
                 concert_id, artist, date, venue, error_message)
            VALUES (?, 'downloading', ?, 0, ?, ?, ?, ?, NULL);
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, request.identifier, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 2, Int32(request.tracks.count))
        sqlite3_bind_text(stmt, 3, request.concertID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 4, request.artist, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 5, request.date, -1, SQLITE_TRANSIENT)
        if let venue = request.venue {
            sqlite3_bind_text(stmt, 6, venue, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 6)
        }
        if sqlite3_step(stmt) != SQLITE_DONE {
            print("[LibrarySQLite] download_recordings insert failed")
        }

        let trackSQL = """
            INSERT OR REPLACE INTO download_tracks
                (identifier, filename, stream_url, state, local_path, error_message)
            VALUES (?, ?, ?, 'pending', NULL, NULL);
            """
        for track in request.tracks {
            var tStmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, trackSQL, -1, &tStmt, nil) == SQLITE_OK else { continue }
            defer { sqlite3_finalize(tStmt) }
            sqlite3_bind_text(tStmt, 1, request.identifier, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(tStmt, 2, track.filename, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(tStmt, 3, track.streamUrl, -1, SQLITE_TRANSIENT)
            if sqlite3_step(tStmt) != SQLITE_DONE {
                print("[LibrarySQLite] download_tracks insert failed")
            }
        }
    }

    func downloadState(for identifier: String) async -> DownloadState {
        let sql = """
            SELECT state, total_tracks, completed_tracks, error_message
            FROM download_recordings WHERE identifier = ?;
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return .notDownloaded }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, identifier, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return .notDownloaded }
        return parseState(stateCol: 0, totalCol: 1, completedCol: 2, errorCol: 3, stmt: stmt)
    }

    func allDownloads() async -> [DownloadRecord] {
        let sql = """
            SELECT identifier, state, total_tracks, completed_tracks,
                   concert_id, artist, date, venue, error_message
            FROM download_recordings;
            """
        return queryDownloadRecords(sql: sql, bindIdentifier: nil)
    }

    func completedDownloads() async -> [DownloadRecord] {
        let sql = """
            SELECT identifier, state, total_tracks, completed_tracks,
                   concert_id, artist, date, venue, error_message
            FROM download_recordings WHERE state = 'downloaded';
            """
        return queryDownloadRecords(sql: sql, bindIdentifier: nil)
    }

    func tracksForRecording(identifier: String) async -> [(filename: String, localPath: String)] {
        let sql = """
            SELECT filename, local_path FROM download_tracks
            WHERE identifier = ? AND state = 'complete' AND local_path IS NOT NULL;
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, identifier, -1, SQLITE_TRANSIENT)
        var results: [(filename: String, localPath: String)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let filename = String(cString: sqlite3_column_text(stmt, 0))
            let localPath = String(cString: sqlite3_column_text(stmt, 1))
            results.append((filename: filename, localPath: localPath))
        }
        return results
    }

    // Shared row-parsing logic for allDownloads / completedDownloads.
    // Columns: 0=identifier, 1=state, 2=total_tracks, 3=completed_tracks,
    //          4=concert_id, 5=artist, 6=date, 7=venue, 8=error_message
    private func queryDownloadRecords(sql: String, bindIdentifier: String?) -> [DownloadRecord] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        if let id = bindIdentifier {
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
        }
        var results: [DownloadRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let identifier = String(cString: sqlite3_column_text(stmt, 0))
            let total = Int(sqlite3_column_int(stmt, 2))
            let completed = Int(sqlite3_column_int(stmt, 3))
            let concertID = String(cString: sqlite3_column_text(stmt, 4))
            let artist = String(cString: sqlite3_column_text(stmt, 5))
            let date = String(cString: sqlite3_column_text(stmt, 6))
            let venue = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
            let state = parseState(stateCol: 1, totalCol: 2, completedCol: 3, errorCol: 8, stmt: stmt)
            results.append(DownloadRecord(
                identifier: identifier, concertID: concertID, state: state,
                totalTracks: total, completedTracks: completed,
                artist: artist, date: date, venue: venue
            ))
        }
        return results
    }

    func markTrackComplete(identifier: String, filename: String,
                           localPath: String) async {
        let sql = """
            UPDATE download_tracks SET state = 'complete', local_path = ?
            WHERE identifier = ? AND filename = ?;
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, localPath, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, identifier, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, filename, -1, SQLITE_TRANSIENT)
        if sqlite3_step(stmt) != SQLITE_DONE {
            print("[LibrarySQLite] download_tracks update failed")
        }

        let countSQL = """
            SELECT COUNT(*) FROM download_tracks
            WHERE identifier = ? AND state = 'complete';
            """
        var cStmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, countSQL, -1, &cStmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(cStmt) }
        sqlite3_bind_text(cStmt, 1, identifier, -1, SQLITE_TRANSIENT)
        if sqlite3_step(cStmt) == SQLITE_ROW {
            let completed = Int(sqlite3_column_int(cStmt, 0))
            let updateSQL = "UPDATE download_recordings SET completed_tracks = ? WHERE identifier = ?;"
            var uStmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, updateSQL, -1, &uStmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(uStmt) }
            sqlite3_bind_int(uStmt, 1, Int32(completed))
            sqlite3_bind_text(uStmt, 2, identifier, -1, SQLITE_TRANSIENT)
            if sqlite3_step(uStmt) != SQLITE_DONE {
                print("[LibrarySQLite] download_recordings completed_tracks update failed")
            }
        }
    }

    func markTrackFailed(identifier: String, filename: String,
                         error: String) async {
        let sql = """
            UPDATE download_tracks SET state = 'failed', error_message = ?
            WHERE identifier = ? AND filename = ?;
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, error, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, identifier, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, filename, -1, SQLITE_TRANSIENT)
        if sqlite3_step(stmt) != SQLITE_DONE {
            print("[LibrarySQLite] download_tracks failed update failed")
        }

        let recSQL = """
            UPDATE download_recordings SET state = 'failed', error_message = ?
            WHERE identifier = ?;
            """
        var rStmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, recSQL, -1, &rStmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(rStmt) }
        sqlite3_bind_text(rStmt, 1, error, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(rStmt, 2, identifier, -1, SQLITE_TRANSIENT)
        if sqlite3_step(rStmt) != SQLITE_DONE {
            print("[LibrarySQLite] download_recordings failed update failed")
        }
    }

    func markRecordingComplete(identifier: String) async {
        let sql = "UPDATE download_recordings SET state = 'downloaded' WHERE identifier = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, identifier, -1, SQLITE_TRANSIENT)
        if sqlite3_step(stmt) != SQLITE_DONE {
            print("[LibrarySQLite] download_recordings complete update failed")
        }
    }

    func deleteDownload(identifier: String) async throws {
        let trackSQL = "DELETE FROM download_tracks WHERE identifier = ?;"
        var tStmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, trackSQL, -1, &tStmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(tStmt) }
        sqlite3_bind_text(tStmt, 1, identifier, -1, SQLITE_TRANSIENT)
        if sqlite3_step(tStmt) != SQLITE_DONE {
            print("[LibrarySQLite] download_tracks delete failed")
        }

        let recSQL = "DELETE FROM download_recordings WHERE identifier = ?;"
        var rStmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, recSQL, -1, &rStmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(rStmt) }
        sqlite3_bind_text(rStmt, 1, identifier, -1, SQLITE_TRANSIENT)
        if sqlite3_step(rStmt) != SQLITE_DONE {
            print("[LibrarySQLite] download_recordings delete failed")
        }
    }

    func isTrackDownloaded(identifier: String, filename: String) async -> Bool {
        let sql = """
            SELECT 1 FROM download_tracks
            WHERE identifier = ? AND filename = ? AND state = 'complete';
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, identifier, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, filename, -1, SQLITE_TRANSIENT)
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    func failedTracks(for identifier: String) async -> [(filename: String, streamUrl: String)] {
        let sql = """
            SELECT filename, stream_url FROM download_tracks
            WHERE identifier = ? AND state != 'complete';
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, identifier, -1, SQLITE_TRANSIENT)
        var results: [(filename: String, streamUrl: String)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let filename = String(cString: sqlite3_column_text(stmt, 0))
            let streamUrl = String(cString: sqlite3_column_text(stmt, 1))
            results.append((filename: filename, streamUrl: streamUrl))
        }
        return results
    }

    func findTrackByStreamURL(_ url: String) async -> (identifier: String, filename: String)? {
        let sql = """
            SELECT identifier, filename FROM download_tracks
            WHERE stream_url = ? LIMIT 1;
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, url, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        let identifier = String(cString: sqlite3_column_text(stmt, 0))
        let filename = String(cString: sqlite3_column_text(stmt, 1))
        return (identifier: identifier, filename: filename)
    }

    func resetTrack(identifier: String, filename: String) async {
        let sql = """
            UPDATE download_tracks SET state = 'pending', error_message = NULL
            WHERE identifier = ? AND filename = ?;
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, identifier, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, filename, -1, SQLITE_TRANSIENT)
        if sqlite3_step(stmt) != SQLITE_DONE {
            print("[LibrarySQLite] download_tracks reset failed")
        }
    }

    func markRecordingFailed(identifier: String, error: String) async {
        let sql = """
            UPDATE download_recordings SET state = 'failed', error_message = ?
            WHERE identifier = ?;
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, error, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, identifier, -1, SQLITE_TRANSIENT)
        if sqlite3_step(stmt) != SQLITE_DONE {
            print("[LibrarySQLite] download_recordings failed update failed")
        }
    }

    // MARK: - Private

    private func parseState(stateCol: Int32, totalCol: Int32, completedCol: Int32,
                            errorCol: Int32, stmt: OpaquePointer?) -> DownloadState {
        let stateStr = String(cString: sqlite3_column_text(stmt, stateCol))
        switch stateStr {
        case "downloading":
            let completed = Double(sqlite3_column_int(stmt, completedCol))
            let total = Double(sqlite3_column_int(stmt, totalCol))
            let progress = total > 0 ? completed / total : 0
            return .downloading(progress: progress)
        case "downloaded":
            return .downloaded
        case "failed":
            let msg = sqlite3_column_text(stmt, errorCol).map { String(cString: $0) } ?? "Unknown error"
            return .failed(msg)
        default:
            return .notDownloaded
        }
    }
}
