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

private func tempStorage() -> DocumentsAudioStorage {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    return DocumentsAudioStorage(root: dir)
}

@Suite("DownloadManager retry")
struct DownloadManagerTests {
    @Test @MainActor func retryDownloadResetsProgressToDownloading() async throws {
        let repo = InMemoryDownloadRepository()
        let storage = tempStorage()

        // Set up repo state before creating manager (simulates a previous session + relaunch)
        try await repo.startDownload(request: makeRequest(trackCount: 3))
        await repo.markTrackFailed(identifier: "gd77-05-08.sbd", filename: "track0.flac", error: "timeout")
        await repo.markRecordingFailed(identifier: "gd77-05-08.sbd", error: "timeout")

        let manager = DownloadManager(storage: storage, repository: repo)
        await manager.whenRestored()

        let stateBefore = manager.recordingState(for: "gd77-05-08.sbd")
        #expect(stateBefore != .downloaded)

        manager.retryDownload(identifier: "gd77-05-08.sbd")
        try await Task.sleep(nanoseconds: 100_000_000)

        let stateAfter = manager.recordingState(for: "gd77-05-08.sbd")
        guard case .downloading = stateAfter else {
            Issue.record("Expected .downloading, got \(stateAfter)")
            return
        }
    }

    @Test @MainActor func retryDownloadDoesNothingWhenAllTracksComplete() async throws {
        let repo = InMemoryDownloadRepository()
        let storage = tempStorage()

        // Set up repo state before creating manager (simulates a previous session + relaunch)
        try await repo.startDownload(request: makeRequest(trackCount: 1))
        await repo.markTrackComplete(identifier: "gd77-05-08.sbd", filename: "track0.flac", localPath: "/tmp/t0")
        await repo.markRecordingComplete(identifier: "gd77-05-08.sbd")

        let manager = DownloadManager(storage: storage, repository: repo)
        await manager.whenRestored()

        manager.retryDownload(identifier: "gd77-05-08.sbd")
        try await Task.sleep(nanoseconds: 100_000_000)

        let state = manager.recordingState(for: "gd77-05-08.sbd")
        #expect(state == .downloaded)
    }

    @Test @MainActor func retryDownloadStartsFromPartialProgress() async throws {
        let repo = InMemoryDownloadRepository()
        let storage = tempStorage()

        // Set up repo state before creating manager (simulates a previous session + relaunch)
        try await repo.startDownload(request: makeRequest(trackCount: 3))
        await repo.markTrackComplete(identifier: "gd77-05-08.sbd", filename: "track0.flac", localPath: "/tmp/t0")
        await repo.markTrackFailed(identifier: "gd77-05-08.sbd", filename: "track1.flac", error: "err")
        await repo.markRecordingFailed(identifier: "gd77-05-08.sbd", error: "err")

        let manager = DownloadManager(storage: storage, repository: repo)
        await manager.whenRestored()

        manager.retryDownload(identifier: "gd77-05-08.sbd")
        try await Task.sleep(nanoseconds: 100_000_000)

        let state = manager.recordingState(for: "gd77-05-08.sbd")
        if case .downloading(let progress) = state {
            // 1 of 3 completed → initial progress ~0.333
            #expect(progress > 0.0)
            #expect(progress < 1.0)
        } else {
            Issue.record("Expected .downloading, got \(state)")
        }
    }

    @Test @MainActor func restoreMirrorEqualsRepositoryAfterRestore() async throws {
        let repo = InMemoryDownloadRepository()
        let storage = tempStorage()

        // Prime the repository: one downloaded, one failed
        try await repo.startDownload(request: makeRequest(identifier: "gd77-05-08.sbd", trackCount: 1))
        await repo.markTrackComplete(identifier: "gd77-05-08.sbd", filename: "track0.flac", localPath: "/tmp/t0")
        await repo.markRecordingComplete(identifier: "gd77-05-08.sbd")

        try await repo.startDownload(request: makeRequest(identifier: "gd77-05-08.aud", trackCount: 2))
        await repo.markTrackFailed(identifier: "gd77-05-08.aud", filename: "track0.flac", error: "err")
        await repo.markRecordingFailed(identifier: "gd77-05-08.aud", error: "err")

        // Fresh manager on the same repo — simulates a relaunch
        let manager = DownloadManager(storage: storage, repository: repo)
        await manager.whenRestored()

        let downloads = await repo.allDownloads()
        for record in downloads {
            let mirror = manager.recordingState(for: record.identifier)
            #expect(mirror == record.state,
                    "mirror[\(record.identifier)] = \(mirror), repo = \(record.state)")
        }
    }
}
