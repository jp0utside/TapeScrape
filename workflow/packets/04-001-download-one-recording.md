# Task Packet: Download one recording via background URLSession through AudioStorage

**Packet ID:** 04-001-download-one-recording
**Phase:** 4
**Created:** 2026-05-18
**Status:** READY
**Auto-proceed:** false
**High-risk:** true

## Goal

Prove the download path end-to-end: tap "Download" on a recording in `ConcertDetailView`,
download all its tracks from `archive.org` via a **background `URLSession`**, persist the
files through `AudioStorage`, and track download state in a new `DownloadRepository`.
The player transparently prefers the local file when it exists. This is the Phase 4
vertical slice — the plane-mode proof-of-concept.

The roadmap flags background `URLSession` lifecycle as the **#3 known risk**
(`03-CLIENT-AND-PLAYBACK.md` §5). This packet deliberately scopes to the happy path +
one recovery case (app relaunch mid-download) and defers pause/resume, eviction,
storage-usage UI, concert-level download, and per-format choice.

## Acceptance criteria

### DownloadRepository protocol + SQLite implementation

- [ ] New `DownloadRepository` protocol in `Repositories/`:
  ```
  func startDownload(recording: DownloadRequest) async throws
  func downloadState(for identifier: String) -> DownloadState
  func allDownloads() async -> [DownloadRecord]
  func markTrackComplete(identifier: String, filename: String, localPath: String) async
  func markTrackFailed(identifier: String, filename: String, error: String) async
  func markRecordingComplete(identifier: String) async
  func deleteDownload(identifier: String) async throws
  func isTrackDownloaded(identifier: String, filename: String) async -> Bool
  ```
- [ ] `DownloadState` enum: `notDownloaded | downloading(progress: Double) | downloaded |
  failed(String)`.
- [ ] `DownloadRequest` struct: `identifier`, `tracks: [(filename, streamUrl)]`,
  concert context for display.
- [ ] `DownloadRecord` struct: `identifier`, `state`, `totalTracks`, `completedTracks`,
  concert context fields (artist, date, venue) denormalized for offline Library display.
- [ ] `SQLiteDownloadRepository` actor backed by `LibraryDatabase` (§18 pattern). New
  tables: `download_recordings` (recording-level state) and `download_tracks` (per-track
  state + local path). Schema added to `LibraryDatabase.init`.
- [ ] `InMemoryDownloadRepository` actor stub for tests/previews (§11).
- [ ] DI via `EnvironmentKey` (§19 pattern): `\.downloadRepository`.

### DownloadManager

- [ ] New `DownloadManager` class (or `@Observable @MainActor` like
  `PlaybackCoordinator`) that wraps a **background `URLSession`**
  (`URLSessionConfiguration.background(withIdentifier: "com.tapescrape.downloads")`).
- [ ] Conforms to `URLSessionDownloadDelegate` to receive completion/progress callbacks.
- [ ] On download start: enqueues one `URLSessionDownloadTask` per track in the
  recording. Files download from the `stream_url` (the opaque `archive.org` URL).
- [ ] On `urlSession(_:downloadTask:didFinishDownloadingTo:)`: moves the temp file to
  its permanent location via `AudioStorage.store(...)` (reading `Data` from the temp URL
  and writing through the protocol — the temp file is ephemeral, the stored file is
  permanent). Marks the track complete in `DownloadRepository`.
- [ ] On all tracks complete for a recording: marks recording complete.
- [ ] On failure: marks track failed with error description; does not retry automatically
  (retry is a future packet).
- [ ] On `application(_:handleEventsForBackgroundURLSession:completionHandler:)`: the
  background session reconnects after app relaunch and finishes pending downloads.
  `TapeScrapeApp` must store and call the completion handler.
- [ ] Progress: `DownloadManager` publishes per-recording progress (fraction of tracks
  completed + current track bytes received / expected). Observable from views.

### AudioStorage changes

- [ ] `AudioStorage.fileExists(identifier:file:) -> Bool` — new method. Returns whether
  the file is present at the expected path. (Today `url(for:file:)` always returns a URL
  regardless of existence — F0-4 noted this.)
- [ ] `DocumentsAudioStorage` implements it via `FileManager.default.fileExists`.
- [ ] No other changes to `AudioStorage`. Files are stored verbatim — **no
  transcode/re-encode** (`CLAUDE.md` core constraint).

### PlaybackCoordinator: prefer local

- [ ] `loadCurrentTrack()` checks `AudioStorage.fileExists(identifier:file:)` before
  using the stream URL. If the file exists locally, plays from the local `file://` URL
  instead of the remote `https://archive.org/...` URL.
- [ ] This is the "prefer local transparently" behavior from `03-CLIENT-AND-PLAYBACK.md`
  §4 — no UI change, no user action; if it's downloaded, it plays locally.

### ConcertDetailView: download button

- [ ] A download button on the recording header (next to existing "Play Next" /
  "Add to End" context menu items). Tapping it starts a download of all tracks in that
  recording.
- [ ] Download state is visible: not downloaded → downloading (progress) → downloaded
  (checkmark) → failed (retry affordance).
- [ ] The download button is on the **recording** level, not the concert level (concert-
  level "download preferred" is a future packet).
- [ ] Downloaded tracks show a small downloaded indicator (e.g. a filled arrow or
  checkmark) in the track list.

### Background session lifecycle

- [ ] The background `URLSession` identifier is stable across app launches
  (`"com.tapescrape.downloads"`).
- [ ] `TapeScrapeApp` handles `handleEventsForBackgroundURLSession` by storing the
  system completion handler and calling it when the background session finishes processing
  events. This requires switching from a pure `SwiftUI` `App` to one that also sets up an
  `AppDelegate` (via `UIApplicationDelegateAdaptor`) to receive the callback.
- [ ] On relaunch: `DownloadManager` reconnects to the existing background session. Any
  in-progress downloads resume automatically (this is `URLSession`'s built-in behavior).
  Completed downloads that arrived while the app was suspended are processed (moved to
  `AudioStorage`, marked complete).

## Read first

> Floor (CLAUDE.md, CONVENTIONS.md, this packet) not relisted.

- `docs/design/03-CLIENT-AND-PLAYBACK.md` §5 (downloads), §6 (offline-first) — the
  design intent; this packet implements the core of §5
- `docs/design/00-ARCHITECTURE.md` §2.2 — backend does NOT manage downloads; client owns
  it entirely
- `docs/design/02-DATA-MODEL.md` §5 — `DownloadPin` model (adapt as needed; the field
  names are guidance, not frozen)
- `TapeScrape/Storage/AudioStorage.swift` — current protocol + `DocumentsAudioStorage`
- `TapeScrape/Playback/PlaybackCoordinator.swift` — `loadCurrentTrack()` at line 169
  (where local-prefer logic goes)
- `TapeScrape/Repositories/LibraryDatabase.swift` — shared connection; new download
  tables go here
- `TapeScrape/Models/Concert.swift` — `RecordingResponse`, `TrackResponse` (the data
  shapes the download button uses)
- `TapeScrape/Views/ConcertDetailView.swift` — where the download button goes
- `TapeScrape/TapeScrapeApp.swift` — where `DownloadManager` and
  `AppDelegate` wire up
- `backend/aggregation/aggregate.py:29` — `AggregatedTrack.size` is persisted but not
  on `TrackResponse` (F2-10); useful for download size estimates in a future packet but
  not required here

## Files expected to change

### New files
- `TapeScrape/Repositories/DownloadRepository.swift` — protocol + `DownloadState` +
  `DownloadRequest` + `DownloadRecord` + `InMemoryDownloadRepository` + `EnvironmentKey`
- `TapeScrape/Repositories/SQLiteDownloadRepository.swift` — SQLite-backed impl
- `TapeScrape/Downloads/DownloadManager.swift` — background `URLSession` wrapper +
  delegate

### Modified files
- `TapeScrape/Storage/AudioStorage.swift` — add `fileExists(identifier:file:)`
- `TapeScrape/Repositories/LibraryDatabase.swift` — add download tables schema
- `TapeScrape/Playback/PlaybackCoordinator.swift` — `loadCurrentTrack()` prefer-local
  logic; accept `AudioStorage` at init
- `TapeScrape/Views/ConcertDetailView.swift` — download button on recording header,
  per-track downloaded indicator
- `TapeScrape/TapeScrapeApp.swift` — construct `DownloadManager`,
  `SQLiteDownloadRepository`, inject into environment; add `AppDelegate` for background
  session

### Test files
- **NEW** `TapeScrapeTests/DownloadRepositoryTests.swift` — CRUD on
  `InMemoryDownloadRepository` and `SQLiteDownloadRepository`
- **NEW** `TapeScrapeTests/DownloadManagerTests.swift` — mock URLSession delegate
  callbacks; verify AudioStorage.store called; verify repository state transitions
- **UPDATED** `TapeScrapeTests/PlaybackCoordinatorTests.swift` — test prefer-local path
  (mock AudioStorage returns `fileExists = true` → verify local URL used)
- **UPDATED** `TapeScrapeTests/AudioStorageTests.swift` — test `fileExists`

## Interface sketch

```swift
// DownloadRepository.swift

enum DownloadState: Sendable {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case failed(String)
}

struct DownloadRequest: Sendable {
    let identifier: String
    let tracks: [(filename: String, streamUrl: String)]
    let concertID: String
    let artist: String
    let date: String
    let venue: String?
}

struct DownloadRecord: Identifiable, Sendable {
    var id: String { identifier }
    let identifier: String
    let state: DownloadState
    let totalTracks: Int
    let completedTracks: Int
    let artist: String
    let date: String
    let venue: String?
}

protocol DownloadRepository: Sendable {
    func startDownload(request: DownloadRequest) async throws
    func downloadState(for identifier: String) async -> DownloadState
    func allDownloads() async -> [DownloadRecord]
    func markTrackComplete(identifier: String, filename: String,
                           localPath: String) async
    func markTrackFailed(identifier: String, filename: String,
                         error: String) async
    func markRecordingComplete(identifier: String) async
    func deleteDownload(identifier: String) async throws
    func isTrackDownloaded(identifier: String, filename: String) async -> Bool
}

// DownloadManager.swift

@Observable
@MainActor
final class DownloadManager: NSObject {
    private var session: URLSession!
    private let storage: AudioStorage
    private let repository: any DownloadRepository
    private var taskMap: [Int: (identifier: String, filename: String)] = [:]
    // system completion handler for background session
    var backgroundCompletionHandler: (() -> Void)?

    init(storage: AudioStorage, repository: any DownloadRepository) { ... }

    func download(recording: RecordingResponse, concert: ConcertContext) { ... }
    func recordingState(for identifier: String) -> DownloadState { ... }
}

extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didFinishDownloadingTo location: URL) { ... }
    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didWriteData: Int64, totalBytesWritten: Int64,
                                totalBytesExpectedToWrite: Int64) { ... }
    nonisolated func urlSession(_ session: URLSession,
                                task: URLSessionTask,
                                didCompleteWithError error: Error?) { ... }
}

// PlaybackCoordinator — loadCurrentTrack() change
private func loadCurrentTrack() {
    ...
    let track = queue[currentIndex].track
    // Prefer local file if downloaded
    let url: URL
    if let ctx = queue[currentIndex].concertContext,
       storage.fileExists(identifier: ctx.recordingIdentifier, file: track.filename),
       let localURL = storage.url(for: ctx.recordingIdentifier, file: track.filename) {
        url = localURL
    } else {
        guard let remoteURL = URL(string: track.streamUrl) else { ... }
        url = remoteURL
    }
    state = .loading
    backend.replaceAndPlay(url: url)
    ...
}
```

## Constraints to preserve

- **Audio bytes go client→`archive.org` directly** — `DownloadManager` fetches from
  `stream_url`, which points to `archive.org/download/...`. The backend is not involved.
- **Files stored verbatim** — no transcode, no re-encode (`CLAUDE.md`). The bytes from
  IA are written as-is through `AudioStorage.store`.
- **`AudioStorage` is the only path to audio files** — `DownloadManager` writes through
  it, `PlaybackCoordinator` reads through it (§3 hook 1).
- **Repository pattern** — download state through `DownloadRepository`, never raw
  SQLite in feature code (§3 hook 4).
- **`LibraryDatabase` shared connection** — download tables in the same `library.sqlite`
  through the shared actor (§18, updated in `03.5-001`).
- **No backend changes** in this packet.
- Swift tests don't hit the network; mock `URLSession` delegate calls.

## Tests

- REQUIRED
- See "Test files" in § Files expected to change for the full list.
- The `DownloadManager` tests use mock delegate callbacks (simulate
  `didFinishDownloadingTo` with a temp file) — no real network.
- PlaybackCoordinator prefer-local test: inject a mock `AudioStorage` where `fileExists`
  returns true; verify the coordinator calls `backend.replaceAndPlay` with a `file://`
  URL, not `https://`.

## Known ambiguities / open questions

- **`URLSessionDownloadDelegate` is nonisolated but `DownloadManager` is `@MainActor`.**
  The delegate callbacks arrive on the session's delegate queue, not the main actor.
  Standard pattern: dispatch to `@MainActor` inside each callback. This is the same
  pattern `AVPlayerBackend` uses for KVO callbacks.
- **`AudioStorage.store` takes `Data`, but `didFinishDownloadingTo` gives a temp file
  URL.** For large files, reading the entire file into `Data` is a memory concern.
  Acceptable for v1 (typical IA FLAC tracks are 20–60 MB; iPhone has plenty of RAM for
  one at a time). A future optimization can add a `store(from temporaryURL:...)` method
  that moves/copies the file without loading into memory. Note this in the summary if
  implemented as `Data` read.
- **`PlaybackCoordinator` currently doesn't know about `AudioStorage`.** It needs the
  storage injected at init (alongside `PlayerBackend` and `PlaybackHistoryRepository`).
  The init signature changes — update all call sites (`TapeScrapeApp`, tests).
- **Background session and SwiftUI App lifecycle.** `handleEventsForBackgroundURLSession`
  is a `UIApplicationDelegate` method. SwiftUI apps use `UIApplicationDelegateAdaptor` to
  bridge this. The `AppDelegate` only needs this one method.

## Out of scope

- Pause/resume individual downloads.
- Automatic retry on failure (manual retry via deleting + re-downloading is acceptable).
- Concert-level "download preferred recording" button.
- Per-file/format drill-in for downloads.
- Storage-usage screen or eviction policy.
- Download queue management (prioritization, max concurrent downloads).
- Exposing `AggregatedTrack.size` on `TrackResponse` (F2-10; useful for size estimates
  but not needed for the download itself).
- Uncut-master alternate download target.
- Downloaded badge in Library tab (future packet — Library tab changes are separate).
- Offline Library rendering of downloaded recordings.

## Summary output path

`workflow/packets/04-001-download-one-recording.summary.md`
