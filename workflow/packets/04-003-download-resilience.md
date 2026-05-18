# Task Packet: Download resilience — retry, taskMap recovery, storage usage

**Packet ID:** 04-003-download-resilience
**Phase:** 4
**Created:** 2026-05-18
**Status:** READY
**Auto-proceed:** true
**High-risk:** false

## Goal

Close the Phase 4 "Done when" gap: *"a download interrupted by a network drop recovers
instead of getting stuck."* Today a failed track marks the whole recording as `failed`
with no recovery path except delete-and-redownload. This packet adds:

1. **Retry failed downloads** — a "Retry" button on failed recordings re-enqueues only
   the failed/pending tracks, not the ones already completed.
2. **`taskMap` rehydration on relaunch** — the in-memory `taskMap` that maps
   `URLSessionTask.taskIdentifier` → `(identifier, filename)` is lost on app relaunch.
   Background `URLSession` tasks survive, but their delegate callbacks silently drop
   because the mapping is gone. Fix: persist the task mapping in the repository, or
   reconstruct it by querying the session's pending tasks on init.
3. **Storage-usage display** — a simple readout (e.g. "2.3 GB used") on the Library tab
   or a lightweight storage screen, using the existing `AudioStorage.usage()`. The
   roadmap mentions "a storage-usage screen" as a Phase 4 bullet.

Together with `04-001` (background download + prefer-local) and `04-002` (concert-level
download + Library section), this satisfies both "Done when" conditions.

## Acceptance criteria

### Retry failed downloads

- [ ] `DownloadManager.retryDownload(identifier: String)` — queries the repository for
      the recording's failed and pending tracks (not completed ones), re-enqueues
      `URLSessionDownloadTask`s for each, resets the recording state to `downloading`.
- [ ] The existing `RecordingDownloadButton` in `ConcertDetailView` already shows a
      retry-looking button on `failed` state — wire it to call `retryDownload` instead of
      starting a fresh full download.
- [ ] The concert-level download button (`ConcertDownloadButton`) also calls
      `retryDownload` when the preferred recording is in `failed` state.
- [ ] `DownloadRepository.failedTracks(for identifier: String) async ->
      [(filename: String, streamUrl: String)]` — new method. Returns tracks with state
      `failed` or `pending` for a recording (i.e. not `complete`). Both SQLite and
      InMemory impls.

### taskMap rehydration on relaunch

- [ ] On `DownloadManager.init`, after creating the background `URLSession`, call
      `session.getAllTasks` to get any tasks the OS resumed. For each task, extract the
      original URL, match it to a `download_tracks` row by `stream_url`, and rebuild
      `taskMap`. This is the recommended pattern for background `URLSession` — the
      session remembers its tasks across launches; you just need to re-map them.
- [ ] If a task's URL doesn't match any pending download track (e.g. the user deleted the
      download while the app was suspended), cancel the task.
- [ ] `DownloadRepository.findTrackByStreamURL(_ url: String) async ->
      (identifier: String, filename: String)?` — new method. Looks up a track by its
      `stream_url`. Used by the rehydration logic.
- [ ] After rehydration, any recording in `downloading` state in the repo with no
      matching active tasks is treated as interrupted — set to `failed` state so the user
      can retry. (This catches the case where the OS killed background tasks that never
      completed.)

### Storage-usage display

- [ ] `LibraryTab` shows total download storage usage at the bottom of the Downloads
      section: e.g. "2.3 GB used" in a footer. Uses `AudioStorage.usage()`.
- [ ] The value is refreshed on appear (same pattern as favorites/playlists).
- [ ] Format: human-readable bytes (KB/MB/GB) via `ByteCountFormatter`.
- [ ] If usage is 0, the footer is hidden.

## Read first

> Floor (CLAUDE.md, CONVENTIONS.md, this packet) not relisted.

- `TapeScrape/Downloads/DownloadManager.swift` — current `download()`,
  `restoreState()`, `taskMap`, delegate callbacks
- `TapeScrape/Repositories/DownloadRepository.swift` — protocol; needs new methods
- `TapeScrape/Repositories/SQLiteDownloadRepository.swift` — `download_tracks` table
  already stores `stream_url` and per-track `state` (pending/complete/failed)
- `TapeScrape/Views/ConcertDetailView.swift` — `RecordingDownloadButton` (failed state
  handler), `ConcertDownloadButton` (if it exists after `04-002`)
- `TapeScrape/Views/LibraryTab.swift` — Downloads section where footer goes
- `TapeScrape/Storage/AudioStorage.swift` — `usage() throws -> UInt64`
- Apple docs: `URLSession.getAllTasks(completionHandler:)` — the API for rehydrating
  background session tasks

## Files expected to change

### Modified files
- `TapeScrape/Downloads/DownloadManager.swift` — `retryDownload(identifier:)`,
  `rehydrateTaskMap()` in init, cancel orphaned tasks
- `TapeScrape/Repositories/DownloadRepository.swift` — `failedTracks(for:)` and
  `findTrackByStreamURL(_:)` on protocol + InMemory impl
- `TapeScrape/Repositories/SQLiteDownloadRepository.swift` — implement new methods
- `TapeScrape/Views/ConcertDetailView.swift` — wire failed-state buttons to
  `retryDownload` instead of `download`
- `TapeScrape/Views/LibraryTab.swift` — storage-usage footer in Downloads section

### Test files
- **UPDATED** `TapeScrapeTests/Repositories/DownloadRepositoryTests.swift` — tests for
  `failedTracks`, `findTrackByStreamURL`
- **NEW or UPDATED** — test that `retryDownload` only re-enqueues non-completed tracks
  (mock repo + verify taskMap entries)

## Interface sketch

```swift
// DownloadManager — retry
func retryDownload(identifier: String) {
    Task {
        let tracks = await repository.failedTracks(for: identifier)
        guard !tracks.isEmpty else { return }
        // Reset recording state
        recordingProgress[identifier] = .downloading(progress: 0)
        // Reset failed tracks to pending in repo
        for track in tracks {
            await repository.resetTrack(identifier: identifier,
                                        filename: track.filename)
        }
        // Re-enqueue
        for track in tracks {
            guard let url = URL(string: track.streamUrl) else { continue }
            let task = session.downloadTask(with: url)
            taskMap[task.taskIdentifier] = (identifier, track.filename)
            task.resume()
        }
    }
}

// DownloadManager — rehydrate on init (inside restoreState)
private func rehydrateTaskMap() async {
    let tasks = await session.allTasks
    for task in tasks {
        guard let url = task.originalRequest?.url?.absoluteString else {
            task.cancel()
            continue
        }
        if let match = await repository.findTrackByStreamURL(url) {
            taskMap[task.taskIdentifier] = (match.identifier, match.filename)
        } else {
            task.cancel()
        }
    }
    // Mark any downloading recording with no active tasks as failed
    let downloads = await repository.allDownloads()
    let activeIdentifiers = Set(taskMap.values.map(\.identifier))
    for record in downloads {
        if case .downloading = record.state,
           !activeIdentifiers.contains(record.identifier) {
            await repository.markRecordingFailed(
                identifier: record.identifier,
                error: "Download interrupted — tap to retry"
            )
            recordingProgress[record.identifier] = .failed(
                "Download interrupted — tap to retry"
            )
        }
    }
}

// DownloadRepository additions
protocol DownloadRepository: Sendable {
    // ... existing methods ...
    func failedTracks(for identifier: String) async
        -> [(filename: String, streamUrl: String)]
    func findTrackByStreamURL(_ url: String) async
        -> (identifier: String, filename: String)?
    func resetTrack(identifier: String, filename: String) async
    func markRecordingFailed(identifier: String, error: String) async
}

// LibraryTab — storage footer
@State private var storageUsage: UInt64 = 0

// Inside Downloads section:
Section("Downloads") {
    ForEach(downloads) { ... }
} footer: {
    if storageUsage > 0 {
        Text(ByteCountFormatter.string(
            fromByteCount: Int64(storageUsage), countStyle: .file
        ))
    }
}
```

## Known ambiguities / open questions

- **`session.allTasks` is async (completion-handler-based).** Use the async version
  `session.allTasks` (available on iOS 15+; we target iOS 17). This is the cleanest
  approach for rehydration.
- **`resetTrack` vs just updating state.** When retrying, failed tracks need their state
  set back to `pending` and error cleared. A `resetTrack` method is clearer than
  overloading `markTrackFailed` with a nil error. Also reset the recording-level state
  from `failed` back to `downloading`.
- **`markRecordingFailed` is new.** Currently recording failure is set inside
  `markTrackFailed`. But for the rehydration "no active tasks → failed" case, we need
  to mark the recording failed without a specific track failure. Add
  `markRecordingFailed(identifier:error:)` — straightforward UPDATE.
- **Partial completion on retry.** If a recording has 10 tracks, 7 completed, 3 failed,
  retry re-enqueues only the 3. Progress starts from 0.7 (7/10), not 0. The existing
  `checkRecordingCompletion` logic handles this correctly because it reads
  `completedTracks` from the repo.

## Constraints to preserve

- No backend changes.
- Files stored verbatim through `AudioStorage`.
- Repository pattern — all state through `DownloadRepository`.
- `taskMap` can still be in-memory — the rehydration via `session.allTasks` +
  `findTrackByStreamURL` reconstructs it. No need to persist task IDs (they change
  across launches anyway).

## Out of scope

- Automatic retry (exponential backoff, network reachability monitoring). Manual retry
  is sufficient for v1.
- Pause/resume individual downloads.
- Per-file/format drill-in for downloads.
- Eviction policy (automatic deletion of old downloads).
- A dedicated full-screen storage management view. The footer readout is enough.
- Download queue management or concurrent download limits.

## Summary output path

`workflow/packets/04-003-download-resilience.summary.md`
