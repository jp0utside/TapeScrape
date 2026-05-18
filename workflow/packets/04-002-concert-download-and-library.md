# Task Packet: Concert-level download + Downloads section in Library

**Packet ID:** 04-002-concert-download-and-library
**Phase:** 4
**Created:** 2026-05-18
**Status:** READY
**Auto-proceed:** true
**High-risk:** false

## Goal

Two tightly coupled pieces that make downloads feel like part of the app rather than a
hidden per-recording feature:

1. **Concert-level "Download" button** — the natural user gesture. Tapping it downloads
   the **preferred recording** automatically (the roadmap's "concert-level download grabs
   the preferred recording"). Lives in the concert header section of `ConcertDetailView`
   and in the toolbar.
2. **"Downloads" section in Library tab** — downloaded recordings appear as a section so
   the user can find them without remembering which concert they came from. Each row shows
   artist/date/venue and navigates to concert detail. A delete swipe action removes the
   download (files + repo record).

Both build directly on `04-001`'s `DownloadManager`, `DownloadRepository`, and
`AudioStorage` infrastructure with no new architecture.

## Acceptance criteria

### Concert-level download button

- [ ] `ConcertDetailView` header section gains a "Download" button. It downloads the
      **preferred recording** (the recording whose `identifier` matches
      `concert.preferredRecordingId`).
- [ ] The button reflects the download state of the preferred recording:
  - `notDownloaded` → `arrow.down.circle` icon + "Download" label
  - `downloading` → circular progress indicator
  - `downloaded` → `checkmark.circle.fill` (green) + "Downloaded"
  - `failed` → `exclamationmark.circle` (red) + "Retry Download"
- [ ] Tapping when `notDownloaded` or `failed` starts the download. Tapping when
      `downloaded` does nothing (a future packet could offer "Remove Download" here).
- [ ] The existing per-recording download buttons (from `04-001`) remain — advanced users
      can still download a non-preferred recording. The concert-level button is the
      primary affordance.
- [ ] If the preferred recording is already downloading or downloaded (started via the
      per-recording button), the concert-level button reflects that state correctly —
      it reads from the same `DownloadManager.recordingState(for:)`.

### Downloads section in Library tab

- [ ] `LibraryTab` gains a "Downloads" section showing all recordings with state
      `downloaded` (completed downloads only; in-progress downloads are visible on
      `ConcertDetailView`).
- [ ] Each row shows: artist, date, venue (from `DownloadRecord`'s denormalized fields),
      and a downloaded badge icon.
- [ ] Tapping a row navigates to concert detail (via `ConcertDetailLoaderView`, same
      as favorites).
- [ ] Swipe-to-delete removes the download: calls `DownloadManager.deleteDownload(
      identifier:)` which deletes files via `AudioStorage` and removes the repo record.
- [ ] The section appears between Favorites and Playlists (if it has items). Empty state
      text is not needed — the section simply doesn't render if there are no downloads.
- [ ] The empty-state `ContentUnavailableView` condition now includes downloads in its
      check (library is empty only when favorites, downloads, and playlists are all empty).

### DownloadManager.deleteDownload

- [ ] New method on `DownloadManager`: `deleteDownload(identifier: String)`.
- [ ] Deletes all track files for the recording via `AudioStorage.delete(identifier:
      file:)` for each track in the download record.
- [ ] Calls `repository.deleteDownload(identifier:)` to remove the repo record.
- [ ] Clears `recordingProgress[identifier]`.
- [ ] `AudioStorage.deleteRecording(identifier:)` — new convenience method that removes
      the entire `<identifier>/` directory. Simpler than deleting track-by-track and
      ensures no orphaned files.

### DownloadRepository additions

- [ ] `completedDownloads() async -> [DownloadRecord]` — returns only records with
      state `downloaded`. The Library tab needs this (it shouldn't show in-progress or
      failed downloads).
- [ ] `tracksForRecording(identifier: String) async -> [(filename: String, localPath:
      String)]` — returns the list of downloaded track filenames for a recording. Needed
      by `deleteDownload` to know which files to delete from `AudioStorage`.
- [ ] Both `InMemoryDownloadRepository` and `SQLiteDownloadRepository` implement these.

## Read first

> Floor (CLAUDE.md, CONVENTIONS.md, this packet) not relisted.

- `TapeScrape/Views/ConcertDetailView.swift` — current view structure, the
  `RecordingDownloadButton`, the concert header section
- `TapeScrape/Views/LibraryTab.swift` — current sections (Favorites, Playlists),
  empty-state handling, `refresh()` pattern
- `TapeScrape/Downloads/DownloadManager.swift` — `download(recording:concert:)`,
  `recordingState(for:)`, `recordingProgress` dict
- `TapeScrape/Repositories/DownloadRepository.swift` — protocol + `InMemoryDownloadRepository`
- `TapeScrape/Repositories/SQLiteDownloadRepository.swift` — SQLite impl
- `TapeScrape/Storage/AudioStorage.swift` — `delete(identifier:file:)`, `url(for:file:)`
- `TapeScrape/Models/Concert.swift` — `ConcertDetailResponse.preferredRecordingId`,
  `RecordingResponse`

## Files expected to change

### Modified files
- `TapeScrape/Views/ConcertDetailView.swift` — concert-level download button in header
  section
- `TapeScrape/Views/LibraryTab.swift` — Downloads section, updated empty-state check,
  swipe-to-delete
- `TapeScrape/Downloads/DownloadManager.swift` — `deleteDownload(identifier:)` method
- `TapeScrape/Repositories/DownloadRepository.swift` — `completedDownloads()`,
  `tracksForRecording(identifier:)` on protocol + `InMemoryDownloadRepository`
- `TapeScrape/Repositories/SQLiteDownloadRepository.swift` — implement new protocol
  methods
- `TapeScrape/Storage/AudioStorage.swift` — `deleteRecording(identifier:)` convenience

### Test files
- **UPDATED** `TapeScrapeTests/DownloadRepositoryTests.swift` — tests for
  `completedDownloads()` and `tracksForRecording(identifier:)`
- **UPDATED** `TapeScrapeTests/AudioStorageTests.swift` — test `deleteRecording`

## Interface sketch

```swift
// ConcertDetailView.swift — concert-level button in header section
Section {
    VStack(alignment: .leading, spacing: 4) {
        Text(concert.artist).font(.headline)
        ...
    }
    ConcertDownloadButton(concert: concert)
}

// ConcertDownloadButton — reads preferred recording state
private struct ConcertDownloadButton: View {
    let concert: ConcertDetailResponse
    @Environment(DownloadManager.self) private var downloadManager

    private var preferredRecording: RecordingResponse? {
        concert.recordings.first { $0.identifier == concert.preferredRecordingId }
    }

    var body: some View {
        let state = downloadManager.recordingState(
            for: concert.preferredRecordingId
        )
        Button { download() } label: {
            HStack {
                stateIcon(state)
                stateLabel(state)
            }
        }
        .disabled(state == .downloaded || state.isDownloading)
    }

    private func download() {
        guard let recording = preferredRecording else { return }
        let context = ConcertContext(...)
        downloadManager.download(recording: recording, concert: context)
    }
}

// LibraryTab.swift — Downloads section
@Environment(\.downloadRepository) private var downloadRepo
@State private var downloads: [DownloadRecord] = []

private var isEmpty: Bool {
    favorites.isEmpty && downloads.isEmpty && playlists.isEmpty
}

// in List:
if !downloads.isEmpty {
    Section("Downloads") {
        ForEach(downloads) { record in
            NavigationLink(value: ConcertSnapshot(
                id: /* concertID from record — see note */,
                ...
            )) {
                DownloadRow(record: record)
            }
        }
        .onDelete { indexSet in
            let toDelete = indexSet.map { downloads[$0] }
            for record in toDelete {
                downloadManager.deleteDownload(identifier: record.identifier)
            }
        }
    }
}

// DownloadManager.deleteDownload
func deleteDownload(identifier: String) {
    Task {
        let tracks = await repository.tracksForRecording(identifier: identifier)
        try? storage.deleteRecording(identifier: identifier)
        try? await repository.deleteDownload(identifier: identifier)
        recordingProgress.removeValue(forKey: identifier)
    }
}

// AudioStorage — deleteRecording
func deleteRecording(identifier: String) throws {
    let dir = root.appendingPathComponent(identifier)
    if FileManager.default.fileExists(atPath: dir.path) {
        try FileManager.default.removeItem(at: dir)
    }
}
```

## Known ambiguities / open questions

- **`DownloadRecord` lacks `concertID`.** The current `DownloadRecord` has `identifier`
  (recording), `artist`, `date`, `venue` but not `concertID`. The Library tab needs
  `concertID` to navigate to concert detail. Two options: (a) add `concertID` to
  `DownloadRecord` and `DownloadRequest` (it's already on `DownloadRequest` — just carry
  it through to the record), or (b) store it in the `download_recordings` table. Option
  (a) is straightforward — `DownloadRequest` already has it, just persist and return it.
  **Go with (a).**
- **`ConcertSnapshot` for navigation.** The Library tab's `navigationDestination(for:
  ConcertSnapshot.self)` goes to `ConcertDetailLoaderView`. Downloads section can reuse
  this by constructing a `ConcertSnapshot` from the `DownloadRecord`'s denormalized
  fields. This mirrors how Favorites work.
- **Stale `DownloadRecord.state` after swipe-delete.** After `deleteDownload`, the
  `downloads` array in LibraryTab should be refreshed. The simplest approach: `refresh()`
  is already called on appear; also call it after the delete action completes.

## Constraints to preserve

- No backend changes.
- Repository protocol pattern (§3 hook 4) — all download state through
  `DownloadRepository`.
- `AudioStorage` is the only path to audio files (§3 hook 1).
- Files stored/deleted verbatim — no content modification.
- `InMemory*` stubs kept working for tests/previews (§11).
- Library tab reads from repository, never raw SQLite.

## Tests

- REQUIRED
- **Updated** `DownloadRepositoryTests.swift` — `completedDownloads()` returns only
  `downloaded`-state records; `tracksForRecording` returns filenames/paths for a recording
- **Updated** `AudioStorageTests.swift` — `deleteRecording` removes the directory and
  all files
- Existing tests continue to pass; no behavior change to existing download/playback paths

## Out of scope

- "Remove Download" option on the concert-level button when already downloaded (keep it
  simple — use Library swipe-delete).
- Storage-usage screen or eviction policy.
- Download queue management or concurrent download limits.
- In-progress or failed downloads in Library (only completed).
- Offline Library rendering without network (the Library section shows downloaded rows,
  but tapping still goes to `ConcertDetailLoaderView` which fetches from the backend —
  a future packet can add an offline detail view).
- Badge on the Library tab icon showing download count.

## Summary output path

`workflow/packets/04-002-concert-download-and-library.summary.md`
