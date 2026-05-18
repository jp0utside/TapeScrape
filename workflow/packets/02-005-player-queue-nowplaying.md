# Task Packet: Player queue, NowPlaying, and system integration

**Packet ID:** 02-005-player-queue-nowplaying
**Phase:** 2
**Created:** 2026-05-17
**Status:** READY
**Auto-proceed:** false
**High-risk:** true

## Goal

Transform the one-track-at-a-time player into a real recording player: tapping a track
plays the rest of the recording sequentially; a full-screen NowPlaying view shows
progress, scrubber, source/lineage, and the track list; lock-screen / Control Center
controls work; the playback state machine observes AVPlayer status (loading/stalled/
failed are legible, not silent). After this packet the app meets the Phase 2 "done when"
criterion: "play through it like a real music app."

## Acceptance criteria

- [ ] **Sequential playback.** Tapping a track loads the entire recording's track list
      into the coordinator. When a track finishes, the next plays automatically. Reaching
      the end of the recording stops playback
- [ ] **KVO-based state observation.** PlaybackCoordinator observes
      `AVPlayerItem.status` and `AVPlayer.timeControlStatus` to drive real
      `loading → playing → paused → stalled → failed` transitions (replaces the
      Phase 1 pass-through)
- [ ] **Full-screen NowPlaying view.** Accessible via tap on the mini-player. Shows:
  - Large placeholder artwork area (solid color or waveform placeholder — no real art)
  - Track title, artist, recording source/taper
  - Scrubber / progress bar (elapsed / remaining) — draggable to seek
  - Play/pause, skip forward, skip back controls
  - Current track list with highlight on active track; tap another track to jump
- [ ] **Mini-player update.** Shows track title, play/pause, and a tap target to expand
      NowPlaying. Skip forward on swipe or small chevron (optional polish)
- [ ] **MPRemoteCommandCenter integration.** Play/pause, next/previous track, seek
      (scrub) commands registered. Lock screen and Control Center work
- [ ] **MPNowPlayingInfoCenter.** Title, artist, duration, elapsed, artwork (placeholder)
      published so the system UI is populated
- [ ] **AVAudioSession interruption handling.** Phone calls and other interruptions
      pause; resumption resumes (basic — no sophisticated route-change logic yet)
- [ ] **Retry on failure.** Failed state shows a retry button (NowPlaying) or tap-again
      affordance (mini-player). Retry replays the same track
- [ ] Swift tests: queue advancement, state transitions with mock player,
      `playNext`/`playPrevious` logic

## Read first

- `docs/design/03-CLIENT-AND-PLAYBACK.md` § 4 (playback state machine, system integration)
- `TapeScrape/Playback/PlaybackCoordinator.swift` — current implementation
- `TapeScrape/Views/MiniPlayerView.swift` — current mini-player
- `TapeScrape/Views/ConcertDetailView.swift` — where play is initiated

## Files expected to change

- `TapeScrape/Playback/PlaybackCoordinator.swift` — major rewrite: queue, KVO
  observation, track advancement, seek, MPRemoteCommand, MPNowPlayingInfo
- `TapeScrape/Playback/PlayerBackend.swift` — extract protocol + AVPlayerBackend to own
  file; extend protocol for observation (current item status, time)
- `TapeScrape/Views/NowPlayingView.swift` — new: full-screen player
- `TapeScrape/Views/MiniPlayerView.swift` — update: tap-to-expand, track info
- `TapeScrape/Views/ConcertDetailView.swift` — update: pass full track list to
  coordinator on tap (not just single track)
- `TapeScrape/TapeScrapeApp.swift` — add `.fullScreenCover` or `.sheet` for NowPlaying
  presentation
- `TapeScrapeTests/PlaybackCoordinatorTests.swift` — rewrite/extend: queue tests, state
  observation tests, skip tests

## Interface sketch

```swift
// PlaybackCoordinator (evolved)
@Observable
@MainActor
final class PlaybackCoordinator {
    enum State { case idle, loading, playing, paused, stalled, failed(Error) }

    private(set) var state: State = .idle
    private(set) var currentTrack: TrackResponse?
    private(set) var queue: [TrackResponse] = []
    private(set) var currentIndex: Int = 0
    private(set) var elapsed: TimeInterval = 0
    private(set) var duration: TimeInterval = 0

    /// Start playing a recording from a specific track index.
    func play(_ tracks: [TrackResponse], startingAt index: Int = 0) { ... }

    func togglePlayPause() { ... }
    func skipForward() { ... }
    func skipBack() { ... }
    func seek(to fraction: Double) { ... }
    func retry() { ... }
    func stop() { ... }
}
```

```swift
// NowPlayingView
struct NowPlayingView: View {
    @Environment(PlaybackCoordinator.self) private var playback
    @Environment(\.dismiss) private var dismiss
    // Large art placeholder, scrubber, controls, track list
}
```

## Design decisions (within this packet)

1. **Queue scope = one recording.** The queue is the track list of the current recording.
   Cross-recording queue (play-next from another show) is Phase 3 / library. This keeps
   the state machine simple.

2. **KVO via Combine or Swift Concurrency.** Prefer `AsyncStream` wrapping KVO
   publishers (`AVPlayer.publisher(for:)`) for clean cancellation. If the ergonomics are
   poor, Combine `sink` stored in a `Set<AnyCancellable>` is acceptable.

3. **NowPlaying presentation.** Full-screen cover (not a navigation push) triggered by
   tapping the mini-player. Matches Apple Music / Spotify pattern. Dismissed by drag-down
   or explicit close button.

4. **Seek implementation.** `player.seek(to: CMTime)` on scrubber change-end. Periodic
   time observation via `addPeriodicTimeObserver(forInterval: 0.5s)` drives elapsed time.

5. **Skip-back behavior.** If >3s into current track, restart it. If ≤3s, go to previous.
   Standard music-player convention.

## Constraints to preserve

- See `workflow/CONVENTIONS.md` (always applicable)
- See `CLAUDE.md` § "Core constraints" (always applicable)
- Playback logic lives **outside view code** — views observe the coordinator
- PlayerBackend protocol preserved for testability — new observation surface exposed via
  protocol extensions or callbacks, not by views touching AVPlayer directly
- No network calls from the player — stream URLs are opaque, already have them
- `UIBackgroundModes: audio` already configured (Phase 1)

## Tests

- REQUIRED
- `PlaybackCoordinatorTests.swift` — rewrite/extend:
  - `play([tracks], startingAt: 2)` sets queue, currentIndex, currentTrack correctly
  - `skipForward` advances index; at end → stop
  - `skipBack` at >3s restarts; at ≤3s goes previous; at index 0 restarts
  - State transitions: mock player reports status changes → coordinator state updates
  - `retry` from failed replays current track
  - `seek(to:)` calls through to player backend

## Known ambiguities / open questions

- **Track-end detection.** `AVPlayerItemDidPlayToEndTime` notification on the current
  item. When received, advance the queue. If the PlayerBackend protocol abstraction
  makes this hard to inject in tests, add a `didFinishTrack` callback to the protocol.
- **Duration parsing.** IA durations are strings ("312.02" or "5:12"). The coordinator
  needs `TimeInterval` for the scrubber. Parse in the coordinator or in a model extension?
  Prefer a `TrackResponse` computed property or a standalone function.
- **Stalled state.** `timeControlStatus == .waitingToPlayAtSpecifiedRate`. Show in
  NowPlaying as a spinner overlay on the art. Mini-player can just show "Buffering..." text.

## Out of scope

- Cross-recording queue (play-next from another show) — Phase 3
- Queue editing (reorder, add-to-end, save as playlist) — Phase 3
- Download/offline playback switching — Phase 4
- Real cover art — Phase 5
- AirPlay / route-change handling beyond basic interruption — Phase 6 polish
- Aggressive prefetch / buffer-ahead strategy — nice to have, not required for "done when"

## Summary output path

`workflow/packets/02-005-player-queue-nowplaying.summary.md`
