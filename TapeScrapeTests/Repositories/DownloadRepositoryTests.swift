import Testing
import Foundation
@testable import TapeScrape

private func makeRequest(
    identifier: String = "gd77-05-08.sbd",
    trackCount: Int = 3
) -> DownloadRequest {
    DownloadRequest(
        identifier: identifier,
        tracks: (0..<trackCount).map { i in
            ("track\(i).flac", "https://archive.org/download/\(identifier)/track\(i).flac")
        },
        concertID: "gd1977-05-08",
        artist: "Grateful Dead",
        date: "1977-05-08",
        venue: "Barton Hall"
    )
}

// MARK: - InMemoryDownloadRepository

@Suite("InMemoryDownloadRepository")
struct InMemoryDownloadRepositoryTests {
    @Test func startDownloadCreatesRecord() async throws {
        let repo = InMemoryDownloadRepository()
        try await repo.startDownload(request: makeRequest())
        let state = await repo.downloadState(for: "gd77-05-08.sbd")
        #expect(state == .downloading(progress: 0))
    }

    @Test func notDownloadedByDefault() async {
        let repo = InMemoryDownloadRepository()
        let state = await repo.downloadState(for: "nonexistent")
        #expect(state == .notDownloaded)
    }

    @Test func markTrackCompleteUpdatesProgress() async throws {
        let repo = InMemoryDownloadRepository()
        try await repo.startDownload(request: makeRequest(trackCount: 2))
        await repo.markTrackComplete(identifier: "gd77-05-08.sbd", filename: "track0.flac", localPath: "/tmp/t0")
        let state = await repo.downloadState(for: "gd77-05-08.sbd")
        #expect(state == .downloading(progress: 0.5))
    }

    @Test func markRecordingCompleteTransitionsToDownloaded() async throws {
        let repo = InMemoryDownloadRepository()
        try await repo.startDownload(request: makeRequest(trackCount: 1))
        await repo.markTrackComplete(identifier: "gd77-05-08.sbd", filename: "track0.flac", localPath: "/tmp/t0")
        await repo.markRecordingComplete(identifier: "gd77-05-08.sbd")
        let state = await repo.downloadState(for: "gd77-05-08.sbd")
        #expect(state == .downloaded)
    }

    @Test func markTrackFailedTransitionsToFailed() async throws {
        let repo = InMemoryDownloadRepository()
        try await repo.startDownload(request: makeRequest())
        await repo.markTrackFailed(identifier: "gd77-05-08.sbd", filename: "track0.flac", error: "timeout")
        let state = await repo.downloadState(for: "gd77-05-08.sbd")
        #expect(state == .failed("timeout"))
    }

    @Test func deleteDownloadRemovesRecord() async throws {
        let repo = InMemoryDownloadRepository()
        try await repo.startDownload(request: makeRequest())
        try await repo.deleteDownload(identifier: "gd77-05-08.sbd")
        let state = await repo.downloadState(for: "gd77-05-08.sbd")
        #expect(state == .notDownloaded)
    }

    @Test func isTrackDownloadedReflectsCompletion() async throws {
        let repo = InMemoryDownloadRepository()
        try await repo.startDownload(request: makeRequest())
        #expect(await !repo.isTrackDownloaded(identifier: "gd77-05-08.sbd", filename: "track0.flac"))
        await repo.markTrackComplete(identifier: "gd77-05-08.sbd", filename: "track0.flac", localPath: "/tmp/t0")
        #expect(await repo.isTrackDownloaded(identifier: "gd77-05-08.sbd", filename: "track0.flac"))
    }

    @Test func allDownloadsReturnsList() async throws {
        let repo = InMemoryDownloadRepository()
        try await repo.startDownload(request: makeRequest(identifier: "a"))
        try await repo.startDownload(request: makeRequest(identifier: "b"))
        let all = await repo.allDownloads()
        #expect(all.count == 2)
    }

    @Test func completedDownloadsFiltersToDownloadedOnly() async throws {
        let repo = InMemoryDownloadRepository()
        try await repo.startDownload(request: makeRequest(identifier: "complete"))
        try await repo.startDownload(request: makeRequest(identifier: "inprogress"))
        await repo.markRecordingComplete(identifier: "complete")
        let completed = await repo.completedDownloads()
        #expect(completed.count == 1)
        #expect(completed[0].identifier == "complete")
        #expect(completed[0].state == .downloaded)
    }

    @Test func tracksForRecordingReturnsCompletedPaths() async throws {
        let repo = InMemoryDownloadRepository()
        try await repo.startDownload(request: makeRequest(trackCount: 2))
        await repo.markTrackComplete(identifier: "gd77-05-08.sbd", filename: "track0.flac", localPath: "/tmp/t0")
        let tracks = await repo.tracksForRecording(identifier: "gd77-05-08.sbd")
        #expect(tracks.count == 1)
        #expect(tracks[0].filename == "track0.flac")
        #expect(tracks[0].localPath == "/tmp/t0")
    }

    @Test func tracksForRecordingEmptyWhenNoneComplete() async throws {
        let repo = InMemoryDownloadRepository()
        try await repo.startDownload(request: makeRequest())
        let tracks = await repo.tracksForRecording(identifier: "gd77-05-08.sbd")
        #expect(tracks.isEmpty)
    }

    @Test func failedTracksReturnsNonCompleted() async throws {
        let repo = InMemoryDownloadRepository()
        try await repo.startDownload(request: makeRequest(trackCount: 3))
        await repo.markTrackComplete(identifier: "gd77-05-08.sbd", filename: "track0.flac", localPath: "/tmp/t0")
        await repo.markTrackFailed(identifier: "gd77-05-08.sbd", filename: "track1.flac", error: "timeout")
        let failed = await repo.failedTracks(for: "gd77-05-08.sbd")
        #expect(failed.count == 2)
        #expect(!failed.map(\.filename).contains("track0.flac"))
    }

    @Test func failedTracksEmptyWhenAllComplete() async throws {
        let repo = InMemoryDownloadRepository()
        try await repo.startDownload(request: makeRequest(trackCount: 1))
        await repo.markTrackComplete(identifier: "gd77-05-08.sbd", filename: "track0.flac", localPath: "/tmp/t0")
        let failed = await repo.failedTracks(for: "gd77-05-08.sbd")
        #expect(failed.isEmpty)
    }

    @Test func findTrackByStreamURLReturnsMatch() async throws {
        let repo = InMemoryDownloadRepository()
        try await repo.startDownload(request: makeRequest())
        let url = "https://archive.org/download/gd77-05-08.sbd/track0.flac"
        let match = await repo.findTrackByStreamURL(url)
        #expect(match?.identifier == "gd77-05-08.sbd")
        #expect(match?.filename == "track0.flac")
    }

    @Test func findTrackByStreamURLReturnsNilForUnknown() async throws {
        let repo = InMemoryDownloadRepository()
        let match = await repo.findTrackByStreamURL("https://archive.org/download/unknown/track.flac")
        #expect(match == nil)
    }

    @Test func resetTrackClearsErrorAndCompletion() async throws {
        let repo = InMemoryDownloadRepository()
        try await repo.startDownload(request: makeRequest(trackCount: 1))
        await repo.markTrackFailed(identifier: "gd77-05-08.sbd", filename: "track0.flac", error: "err")
        await repo.resetTrack(identifier: "gd77-05-08.sbd", filename: "track0.flac")
        let failed = await repo.failedTracks(for: "gd77-05-08.sbd")
        #expect(failed.count == 1)
        #expect(await !repo.isTrackDownloaded(identifier: "gd77-05-08.sbd", filename: "track0.flac"))
    }

    @Test func markRecordingFailedSetsFailedState() async throws {
        let repo = InMemoryDownloadRepository()
        try await repo.startDownload(request: makeRequest())
        await repo.markRecordingFailed(identifier: "gd77-05-08.sbd", error: "interrupted")
        let state = await repo.downloadState(for: "gd77-05-08.sbd")
        #expect(state == .failed("interrupted"))
    }
}

// MARK: - SQLiteDownloadRepository

@Suite("SQLiteDownloadRepository")
struct SQLiteDownloadRepositoryTests {
    // Returns (repo, database) — caller must hold database to keep SQLite connection open.
    private func makeRepo() -> (SQLiteDownloadRepository, LibraryDatabase) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".sqlite")
        let database = LibraryDatabase(url: url)
        return (SQLiteDownloadRepository(database: database), database)
    }

    @Test func startAndQueryState() async throws {
        let (repo, _db) = makeRepo()
        try await repo.startDownload(request: makeRequest())
        let state = await repo.downloadState(for: "gd77-05-08.sbd")
        #expect(state == .downloading(progress: 0))
        _ = _db
    }

    @Test func notDownloadedByDefault() async {
        let (repo, _db) = makeRepo()
        let state = await repo.downloadState(for: "nonexistent")
        #expect(state == .notDownloaded)
        _ = _db
    }

    @Test func markTrackCompleteUpdatesCount() async throws {
        let (repo, _db) = makeRepo()
        try await repo.startDownload(request: makeRequest(trackCount: 2))
        await repo.markTrackComplete(identifier: "gd77-05-08.sbd", filename: "track0.flac", localPath: "/tmp/t0")
        let all = await repo.allDownloads()
        let record = try #require(all.first)
        #expect(record.completedTracks == 1)
        _ = _db
    }

    @Test func markRecordingComplete() async throws {
        let (repo, _db) = makeRepo()
        try await repo.startDownload(request: makeRequest(trackCount: 1))
        await repo.markTrackComplete(identifier: "gd77-05-08.sbd", filename: "track0.flac", localPath: "/tmp/t0")
        await repo.markRecordingComplete(identifier: "gd77-05-08.sbd")
        let state = await repo.downloadState(for: "gd77-05-08.sbd")
        #expect(state == .downloaded)
        _ = _db
    }

    @Test func markTrackFailedSetsFailedState() async throws {
        let (repo, _db) = makeRepo()
        try await repo.startDownload(request: makeRequest())
        await repo.markTrackFailed(identifier: "gd77-05-08.sbd", filename: "track0.flac", error: "network")
        let state = await repo.downloadState(for: "gd77-05-08.sbd")
        #expect(state == .failed("network"))
        _ = _db
    }

    @Test func deleteRemovesEverything() async throws {
        let (repo, _db) = makeRepo()
        try await repo.startDownload(request: makeRequest())
        try await repo.deleteDownload(identifier: "gd77-05-08.sbd")
        let state = await repo.downloadState(for: "gd77-05-08.sbd")
        #expect(state == .notDownloaded)
        let all = await repo.allDownloads()
        #expect(all.isEmpty)
        _ = _db
    }

    @Test func isTrackDownloaded() async throws {
        let (repo, _db) = makeRepo()
        try await repo.startDownload(request: makeRequest())
        #expect(await !repo.isTrackDownloaded(identifier: "gd77-05-08.sbd", filename: "track0.flac"))
        await repo.markTrackComplete(identifier: "gd77-05-08.sbd", filename: "track0.flac", localPath: "/tmp/t0")
        #expect(await repo.isTrackDownloaded(identifier: "gd77-05-08.sbd", filename: "track0.flac"))
        _ = _db
    }

    @Test func allDownloadsPreservesContext() async throws {
        let (repo, _db) = makeRepo()
        try await repo.startDownload(request: makeRequest())
        let all = await repo.allDownloads()
        let record = try #require(all.first)
        #expect(record.artist == "Grateful Dead")
        #expect(record.date == "1977-05-08")
        #expect(record.venue == "Barton Hall")
        #expect(record.totalTracks == 3)
        #expect(record.concertID == "gd1977-05-08")
        _ = _db
    }

    @Test func completedDownloadsFiltersToDownloadedOnly() async throws {
        let (repo, _db) = makeRepo()
        try await repo.startDownload(request: makeRequest(identifier: "complete"))
        try await repo.startDownload(request: makeRequest(identifier: "inprogress"))
        await repo.markRecordingComplete(identifier: "complete")
        let completed = await repo.completedDownloads()
        #expect(completed.count == 1)
        #expect(completed[0].identifier == "complete")
        #expect(completed[0].state == .downloaded)
        _ = _db
    }

    @Test func tracksForRecordingReturnsCompletedPaths() async throws {
        let (repo, _db) = makeRepo()
        try await repo.startDownload(request: makeRequest(trackCount: 2))
        await repo.markTrackComplete(identifier: "gd77-05-08.sbd", filename: "track0.flac", localPath: "/tmp/t0")
        let tracks = await repo.tracksForRecording(identifier: "gd77-05-08.sbd")
        #expect(tracks.count == 1)
        #expect(tracks[0].filename == "track0.flac")
        #expect(tracks[0].localPath == "/tmp/t0")
        _ = _db
    }

    @Test func tracksForRecordingEmptyWhenNoneComplete() async throws {
        let (repo, _db) = makeRepo()
        try await repo.startDownload(request: makeRequest())
        let tracks = await repo.tracksForRecording(identifier: "gd77-05-08.sbd")
        #expect(tracks.isEmpty)
        _ = _db
    }

    @Test func failedTracksReturnsNonCompleted() async throws {
        let (repo, _db) = makeRepo()
        try await repo.startDownload(request: makeRequest(trackCount: 3))
        await repo.markTrackComplete(identifier: "gd77-05-08.sbd", filename: "track0.flac", localPath: "/tmp/t0")
        await repo.markTrackFailed(identifier: "gd77-05-08.sbd", filename: "track1.flac", error: "timeout")
        let failed = await repo.failedTracks(for: "gd77-05-08.sbd")
        #expect(failed.count == 2)
        #expect(!failed.map(\.filename).contains("track0.flac"))
        _ = _db
    }

    @Test func failedTracksEmptyWhenAllComplete() async throws {
        let (repo, _db) = makeRepo()
        try await repo.startDownload(request: makeRequest(trackCount: 1))
        await repo.markTrackComplete(identifier: "gd77-05-08.sbd", filename: "track0.flac", localPath: "/tmp/t0")
        let failed = await repo.failedTracks(for: "gd77-05-08.sbd")
        #expect(failed.isEmpty)
        _ = _db
    }

    @Test func findTrackByStreamURLReturnsMatch() async throws {
        let (repo, _db) = makeRepo()
        try await repo.startDownload(request: makeRequest())
        let url = "https://archive.org/download/gd77-05-08.sbd/track0.flac"
        let match = await repo.findTrackByStreamURL(url)
        #expect(match?.identifier == "gd77-05-08.sbd")
        #expect(match?.filename == "track0.flac")
        _ = _db
    }

    @Test func findTrackByStreamURLReturnsNilForUnknown() async throws {
        let (repo, _db) = makeRepo()
        let match = await repo.findTrackByStreamURL("https://archive.org/download/unknown/track.flac")
        #expect(match == nil)
        _ = _db
    }

    @Test func resetTrackSetsStateToPending() async throws {
        let (repo, _db) = makeRepo()
        try await repo.startDownload(request: makeRequest(trackCount: 1))
        await repo.markTrackFailed(identifier: "gd77-05-08.sbd", filename: "track0.flac", error: "err")
        await repo.resetTrack(identifier: "gd77-05-08.sbd", filename: "track0.flac")
        let failed = await repo.failedTracks(for: "gd77-05-08.sbd")
        #expect(failed.count == 1)
        #expect(await !repo.isTrackDownloaded(identifier: "gd77-05-08.sbd", filename: "track0.flac"))
        _ = _db
    }

    @Test func markRecordingFailedSetsFailedState() async throws {
        let (repo, _db) = makeRepo()
        try await repo.startDownload(request: makeRequest())
        await repo.markRecordingFailed(identifier: "gd77-05-08.sbd", error: "interrupted")
        let state = await repo.downloadState(for: "gd77-05-08.sbd")
        #expect(state == .failed("interrupted"))
        _ = _db
    }
}
