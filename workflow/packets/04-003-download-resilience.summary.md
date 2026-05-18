# Packet Summary: 04-003-download-resilience

**Status:** COMPLETE
**Date:** 2026-05-18

## What shipped

### 1. Retry failed downloads

- `DownloadRepository` protocol gained four new methods: `failedTracks(for:)`, `findTrackByStreamURL(_:)`, `resetTrack(identifier:filename:)`, `markRecordingFailed(identifier:error:)`.
- `InMemoryDownloadRepository` implements all four. `TrackEntry` gained `streamUrl: String` to support `findTrackByStreamURL`.
- `SQLiteDownloadRepository` implements all four via parameterized SQL queries on the existing `download_tracks` / `download_recordings` tables.
- `DownloadManager.retryDownload(identifier:)` queries `failedTracks`, resets them, and re-enqueues only the non-complete tracks. Initial progress is computed from the ratio of already-completed tracks (not hard-coded 0) so a partial retry starts at the correct fraction.
- `RecordingDownloadButton` (in `ConcertDetailView`) `.failed` case now calls `retryDownload(identifier:)` instead of starting a fresh download.
- `ConcertDownloadButton` `.failed` case also calls `retryDownload(identifier:)`.

### 2. taskMap rehydration on relaunch

- `DownloadManager.restoreState()` now calls `rehydrateTaskMap()` after loading the repository state.
- `rehydrateTaskMap()` uses `withCheckedContinuation` over `URLSession.getAllTasks(completionHandler:)` to get any OS-resumed background tasks, maps each via `findTrackByStreamURL`, cancels orphaned tasks (no matching repo row), and rebuilds `taskMap`.
- After rebuilding `taskMap`, recordings with active tasks get their `recordingProgress` updated to `.downloading(progress:)` from the current completion fraction. Recordings that were in `downloading` state but have no active tasks are marked failed in the repo (`markRecordingFailed`) and in memory.

### 3. Storage-usage footer

- `LibraryTab` gains `@State private var storageUsage: UInt64 = 0`.
- `refresh()` calls `downloadManager.storageUsage()` (a new method on `DownloadManager` that wraps `storage.usage()`).
- The Downloads `Section` now uses `header:` + `footer:` initializer; the footer renders `ByteCountFormatter.string(fromByteCount:countStyle:.file)` and is hidden when `storageUsage == 0`.

### Tests

- `DownloadRepositoryTests.swift` extended with 8 new tests (4 InMemory + 4 SQLite) covering `failedTracks`, `findTrackByStreamURL`, `resetTrack`, and `markRecordingFailed`.
- New `TapeScrapeTests/Downloads/DownloadManagerTests.swift` with 3 `@MainActor` tests: retry resets progress to `.downloading`, retry is a no-op when all tracks are complete, partial-progress start after retry.

### Build / project

- `xcodegen generate` run to include `TapeScrapeTests/Downloads/DownloadManagerTests.swift` in the test target.

## Deviations

- **Initial retry progress from actual completed fraction, not 0.** The interface sketch showed `progress: 0` but the ambiguity section explicitly says "Progress starts from 0.7 (7/10), not 0." Implemented the correct behavior.
- **`rehydrateTaskMap` handles active-tasks-for-any-state.** The packet sketch only checks `if case .downloading = record.state` for both branches, but to correctly handle post-retry relaunch (where DB state is `failed` but tasks are active), the rehydration also updates `recordingProgress` to `.downloading` for any recording that has active tasks regardless of its DB state.

## Follow-ups

- None blocking. The `retryDownload` test uses `Task.sleep(100ms)` to wait for the async Task inside; this is acceptable for v1 but could be replaced with a proper continuation hook if the tests become flaky.

## Status journal

→ `docs/roadmap_status.md` row for `04-003-download-resilience` updated to COMPLETE.
