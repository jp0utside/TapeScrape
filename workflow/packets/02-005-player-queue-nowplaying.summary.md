# Summary: 02-005-player-queue-nowplaying

**Status:** COMPLETE
**Date:** 2026-05-17

## What was built

- **`Playback/PlayerBackend.swift`** (new) — `PlayerBackend` protocol extracted from the
  coordinator; `AVPlayerBackend` implemented with KVO callbacks: `onTrackEnd`
  (AVPlayerItemDidPlayToEndTime notification), `onPlaybackReady` (AVPlayerItem.status
  KVO), `onPlaybackFailed`, `onPlaybackStalled` / `onPlaybackResumed`
  (AVPlayer.timeControlStatus KVO), `onTimeUpdate` (addPeriodicTimeObserver 0.5s). Added
  `seek(to:)` to both protocol and impl. `PlaybackError` moved here.

- **`Playback/PlaybackCoordinator.swift`** (major rewrite):
  - New API: `play(_ tracks: [TrackResponse], startingAt index: Int = 0)`, `skipForward()`,
    `skipBack()`, `seek(to fraction: Double)`, `retry()`
  - New observable state: `queue`, `currentIndex`, `elapsed`, `duration`
  - `.stalled` state added
  - KVO state machine: `loading → playing` via `onPlaybackReady`; `playing → stalled` via
    `onPlaybackStalled`; `stalled → playing` via `onPlaybackResumed`; `→ failed` via
    `onPlaybackFailed`
  - Auto-advance: `onTrackEnd` calls `skipForward()`
  - Skip-back: elapsed > 3s or index == 0 → restart; otherwise → previous track
  - MPRemoteCommandCenter: play/pause/toggle/next/prev/seek registered
  - MPNowPlayingInfoCenter: updated at every state + time change
  - AVAudioSession interruption: pause on `.began`, resume on `.ended` with `shouldResume`
  - Concurrency fix: `Notification` (non-Sendable) extracted to `UInt` primitives before
    crossing into `@MainActor` task

- **`Views/NowPlayingView.swift`** (new) — full-screen cover: deterministic color art
  placeholder (seed from filename), `ProgressView` overlay when loading/stalled, track
  title, `Slider` scrubber with local drag state + seek-on-release, play/pause/skip
  controls, retry button on failure, scrollable track list with active track highlight

- **`Views/MiniPlayerView.swift`** — accepts `Binding<Bool>` for NowPlaying expansion;
  entire view is a tap target; shows "Loading…"/"Buffering…" status for
  `.loading`/`.stalled`; dedicated play/pause button separate from expand tap

- **`Views/ConcertDetailView.swift`** — `playback.play(recording.tracks, startingAt: idx)`
  so tapping any track loads the full recording queue

- **`TapeScrapeApp.swift`** — `ContentView` gains `@State var showNowPlaying`; passes
  `$showNowPlaying` binding to `MiniPlayerView`; `.fullScreenCover` presents `NowPlayingView`

- **`Models/Concert.swift`** — `TrackResponse.durationSeconds: TimeInterval?` extension
  parses both "312.02" (decimal seconds) and "5:12" (M:SS) formats

## Build and test results

- `xcodebuild BUILD SUCCEEDED` — zero errors; non-blocking Sendable warnings on
  `AVPlayerBackend` self captures (acceptable at `minimal` concurrency mode)
- 53 Swift Testing tests pass (up from 31)

## Deviations

- `TrackResponse` used as `Hashable` in `NowPlayingView` track list via `id: \.index` on
  `ForEach` — not full `Hashable` conformance on the struct. This is fine for the list.
- `onPlaybackResumed` fires from `timeControlStatus == .playing`, which also fires on
  initial playback start after `replaceAndPlay`. Guarded by `isStalled` check in the
  coordinator, so it's a no-op in that case.

## Follow-ups / notes

- `AVPlayerBackend` has Sendable warnings on self captures in KVO closures. These are
  expected when using `NSKeyValueObservation` in Swift 6 minimal mode — not errors.
- NowPlayingView `enumerated()` track list uses `id: \.offset` — SourceKit complains but
  compiler accepts it.
- The art placeholder color is deterministic (filename hash → hue) but not beautiful.
  A real `CoverRenderer` is Phase 5.

## Status journal

`docs/roadmap_status.md` row for `02-005-player-queue-nowplaying` updated to COMPLETE.
