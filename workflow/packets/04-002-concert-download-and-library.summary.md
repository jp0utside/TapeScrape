# Packet Summary: 04-002-concert-download-and-library

**Status:** COMPLETE
**Date:** 2026-05-18

## What was built

### Concert-level download button
`ConcertDownloadButton` added as a private struct in `ConcertDetailView.swift`, inserted in the concert header section. Reads `downloadManager.recordingState(for: concert.preferredRecordingId)` to display four states:
- `.notDownloaded` → `Label("Download", systemImage: "arrow.down.circle")`
- `.downloading(progress:)` → circular `ProgressView` + "Downloading..."
- `.downloaded` → `Label("Downloaded", systemImage: "checkmark.circle.fill")` (green)
- `.failed` → `Label("Retry Download", systemImage: "exclamationmark.circle")` (red)

Disabled when `downloaded` or `isDownloading`. Tapping constructs a `ConcertContext` from the preferred recording and calls `downloadManager.download(recording:concert:)`. The per-recording `RecordingDownloadButton` remains.

### Downloads section in Library tab
`LibraryTab` now loads `downloadRepo.completedDownloads()` on refresh, showing a "Downloads" section between Favorites and Playlists when non-empty. Each row (`DownloadRow`) shows date, artist, venue, and a downloaded badge icon. Navigation constructs a `ConcertSnapshot` from `DownloadRecord`'s denormalized fields (same pattern as favorites) to navigate via `ConcertDetailLoaderView`. Swipe-to-delete calls `downloadManager.deleteDownload(identifier:)` and optimistically removes the row. Empty-state now checks all three sources.

### DownloadManager.deleteDownload
New synchronous `deleteDownload(identifier:)` on `DownloadManager`. Dispatches a `Task` that calls `storage.deleteRecording(identifier:)` (removes the directory), `repository.deleteDownload(identifier:)` (removes DB rows), and `recordingProgress.removeValue(forKey:)`.

### DownloadRepository additions
`completedDownloads()` and `tracksForRecording(identifier:)` added to the protocol and both implementations:
- `InMemoryDownloadRepository`: `completedDownloads` filters `recordings` dict to `.downloaded` state; `tracksForRecording` returns completed tracks with their `localPath`.
- `SQLiteDownloadRepository`: `completedDownloads` adds `WHERE state = 'downloaded'`; `tracksForRecording` queries `download_tracks` for `state = 'complete'`. Both share a new private synchronous `queryDownloadRecords(sql:bindIdentifier:)` helper (non-async, called directly from actor-isolated methods to avoid actor-reentrancy issues).

### AudioStorage additions
`deleteRecording(identifier:)` added to the protocol and `DocumentsAudioStorage`. Removes the entire `root/<identifier>/` directory using `FileManager.removeItem(at:)`. No-ops gracefully if the directory doesn't exist.

### DownloadRecord.concertID
Added `concertID: String` to `DownloadRecord` (was already in `DownloadRequest` and the `download_recordings` SQL schema; just not surfaced). Both impls updated to carry it through. Needed by `LibraryTab` to construct `ConcertSnapshot` for navigation.

### DownloadState.isDownloading
Added a computed property to `DownloadState` for clean disable-condition syntax in `ConcertDownloadButton`.

## Deviations

- **Pre-existing LibraryDatabase lifetime bug fixed.** `SQLiteDownloadRepositoryTests.makeRepo()` was releasing the `LibraryDatabase` (and thus closing the SQLite connection) immediately after constructing `SQLiteDownloadRepository`, because the `LibraryDatabase` instance had no other strong reference. This caused most SQLite tests to silently fail (queries on a closed handle return empty; `downloadState` returns `.notDownloaded` which is also the "not found" case, masking the bug). Fixed by returning `(SQLiteDownloadRepository, LibraryDatabase)` from `makeRepo()` and binding `_db` in each test to keep the connection alive. This is a deviation from the "no unrelated files changed" rule, but the tests are part of this packet's own test target and the fix is prerequisite to the new tests being meaningful.
- **`deleteDownload` does not call `tracksForRecording` first.** The acceptance criteria mentioned calling it to get filenames before deleting files, but since `deleteRecording(identifier:)` removes the entire directory, per-track deletion is unnecessary. `tracksForRecording` is implemented (per protocol requirement) but not used by `deleteDownload`. The sketch in the packet itself also didn't use the return value.

## Tests

- `AudioStorageTests.swift`: +2 tests (`deleteRecordingRemovesDirectory`, `deleteRecordingNoopsWhenMissing`). All 8 AudioStorage tests pass.
- `DownloadRepositoryTests.swift`: +4 InMemory tests (`completedDownloadsFiltersToDownloadedOnly`, `tracksForRecordingReturnsCompletedPaths`, `tracksForRecordingEmptyWhenNoneComplete`; existing `allDownloadsReturnsList` unchanged) + same 4 tests for SQLite + `allDownloadsPreservesContext` now also checks `concertID`. All InMemory and SQLite suites pass.
- `PlaybackCoordinatorTests.swift`: `MockAudioStorage` updated with stub `deleteRecording(identifier:)` to satisfy the protocol (no behavior change).

## Status journal

`docs/roadmap_status.md` row for `04-002-concert-download-and-library` updated to `COMPLETE`.
