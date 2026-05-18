# Task Packet: Queue management — play-next, add-to-end, reorder, remove

**Packet ID:** 03-003-queue-management
**Phase:** 3
**Created:** 2026-05-18
**Status:** READY
**Auto-proceed:** true
**High-risk:** false

## Goal

Turn the single-recording queue into a cross-concert queue with play-next, add-to-end,
reorder, and remove. This is the prerequisite for playlists (03-004) and directly serves
the Phase 3 roadmap bullet "Real queue management: reorder, play-next, add-to-end"
(`docs/design/03-CLIENT-AND-PLAYBACK.md` § 4: "Queue is real"). No backend changes.

## Acceptance criteria

- [ ] `QueueItem` struct (track + optional concert context + stable UUID) replaces the
      raw `[TrackResponse]` queue in `PlaybackCoordinator`. The existing
      `play(_:startingAt:concert:)` API still works (wraps tracks into `QueueItem`s
      internally and replaces the queue as before).
- [ ] `PlaybackCoordinator.playNext(_ tracks: [TrackResponse], concert: ConcertContext?)`
      inserts tracks immediately after `currentIndex`. If idle, starts playback of the
      first inserted track.
- [ ] `PlaybackCoordinator.addToEnd(_ tracks: [TrackResponse], concert: ConcertContext?)`
      appends tracks at the tail of the queue. If idle, starts playback of the first
      appended track.
- [ ] `PlaybackCoordinator.removeFromQueue(at index: Int)` removes the track at
      `index`. If the removed track is the current track, advances to the next (or
      stops if queue is empty). Adjusts `currentIndex` correctly when removing before
      the current position.
- [ ] `PlaybackCoordinator.moveInQueue(from source: Int, to destination: Int)` reorders
      a track. `currentIndex` follows the currently-playing track through the move.
      Moving the current track or moving items around it keeps playback uninterrupted.
- [ ] `ConcertDetailView` track rows gain a context menu with "Play Next" and
      "Add to Queue" actions. Each inserts/appends the tapped track (single track, not
      the whole recording). A recording-level "Play Recording Next" / "Add Recording to
      Queue" appears on the recording section header.
- [ ] `NowPlayingView` track list supports swipe-to-delete (removes from queue) and
      drag-to-reorder via `.onMove` / `.onDelete` modifiers or equivalent. Past tracks
      (index < currentIndex) are visually dimmed. The current track is highlighted.
- [ ] Playback history recording uses the `ConcertContext` from the current `QueueItem`
      (not a global `concertContext`), so cross-concert queue entries record history
      correctly. The global `concertContext` property on `PlaybackCoordinator` is
      removed.
- [ ] `MiniPlayerView` is unchanged (it reads `currentTrack` which still works).
- [ ] BUILD SUCCEEDED with zero errors. Existing tests still pass. New tests pass.

## Read first

> Floor (CLAUDE.md, CONVENTIONS.md, this packet) not relisted.

- `TapeScrape/Playback/PlaybackCoordinator.swift` — the coordinator being modified;
  understand the state machine, `play()`, `skipForward/Back`, `setupCallbacks` (history
  recording), and `updateNowPlayingInfo`
- `TapeScrape/Views/NowPlayingView.swift` — the track list that becomes the queue UI
- `TapeScrape/Views/ConcertDetailView.swift` — where context menus are added
- `TapeScrape/Views/MiniPlayerView.swift` — verify it reads `currentTrack` only (no
  queue index)
- `TapeScrapeTests/PlaybackCoordinatorTests.swift` — existing test patterns + mock setup
- `docs/design/03-CLIENT-AND-PLAYBACK.md` § 4 — "Queue is real: reorder, play-next,
  add-to-end"

## Files expected to change

- `TapeScrape/Playback/PlaybackCoordinator.swift` — add `QueueItem`; change `queue` to
  `[QueueItem]`; add `playNext`, `addToEnd`, `removeFromQueue`, `moveInQueue`; update
  `loadCurrentTrack` and history recording to use per-item context; remove global
  `concertContext`
- `TapeScrape/Views/ConcertDetailView.swift` — context menus on track rows and recording
  section headers for "Play Next" / "Add to Queue"
- `TapeScrape/Views/NowPlayingView.swift` — track list reads `QueueItem`; add
  `.onDelete` and `.onMove`; dim past tracks; keep tap-to-jump behavior
- `TapeScrapeTests/PlaybackCoordinatorTests.swift` — new tests for `playNext`,
  `addToEnd`, `removeFromQueue`, `moveInQueue`; update existing tests for
  `QueueItem`-based queue

## Interface sketch

```swift
// PlaybackCoordinator.swift

struct QueueItem: Identifiable {
    let id: UUID = UUID()
    let track: TrackResponse
    let concertContext: ConcertContext?
}

@Observable @MainActor
final class PlaybackCoordinator {
    private(set) var queue: [QueueItem] = []
    private(set) var currentIndex: Int = 0

    // Existing: replaces queue entirely (unchanged external signature)
    func play(_ tracks: [TrackResponse], startingAt index: Int = 0,
              concert: ConcertContext? = nil) { ... }

    // New: insert after current track
    func playNext(_ tracks: [TrackResponse], concert: ConcertContext? = nil) { ... }

    // New: append to end
    func addToEnd(_ tracks: [TrackResponse], concert: ConcertContext? = nil) { ... }

    // New: remove from queue
    func removeFromQueue(at index: Int) { ... }

    // New: reorder within queue
    func moveInQueue(from source: Int, to destination: Int) { ... }

    // New: jump to a position in the existing queue without replacing it
    func skipTo(index: Int) { ... }
}

// ConcertDetailView.swift — context menu on track row
TrackRow(track: track, isCurrentTrack: ...) { /* play action */ }
    .contextMenu {
        Button("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward") {
            playback.playNext([track], concert: context)
        }
        Button("Add to Queue", systemImage: "text.badge.plus") {
            playback.addToEnd([track], concert: context)
        }
    }

// NowPlayingView.swift — editable queue list
List {
    ForEach(Array(playback.queue.enumerated()), id: \.element.id) { idx, item in
        QueueRow(item: item, isCurrent: idx == playback.currentIndex,
                 isPast: idx < playback.currentIndex) {
            playback.skipTo(index: idx)
        }
    }
    .onDelete { offsets in
        for idx in offsets.sorted().reversed() {
            playback.removeFromQueue(at: idx)
        }
    }
    .onMove { source, destination in
        guard let from = source.first else { return }
        playback.moveInQueue(from: from, to: destination)
    }
}
.environment(\.editMode, .constant(.active))
```

## Constraints to preserve

- See `workflow/CONVENTIONS.md` and `CLAUDE.md` § "Core constraints" (always applicable)
- Library/history data is **client-side only** — no backend changes
- `PlaybackCoordinator` stays `@Observable @MainActor` — single owner of playback state
- Queue modifications must not interrupt current playback (no re-`replaceAndPlay` on
  reorder/remove of non-current items)
- `PlayerBackend` protocol is unchanged — queue management is purely coordinator-level
- History recording is still fire-and-forget `Task` — don't block the state machine
- `MiniPlayerView` must not break — verify it reads only `currentTrack` / `state`
- The `play(_:startingAt:concert:)` signature remains source-compatible with existing
  callers (ConcertDetailView track taps, NowPlayingView track list taps)

## Tests

- REQUIRED
- `TapeScrapeTests/PlaybackCoordinatorTests.swift` (updated + new):
  - `playNext` inserts tracks after current position; `currentIndex` unchanged if
    insertion is after current
  - `playNext` when idle starts playback
  - `addToEnd` appends; doesn't change `currentIndex` if already playing
  - `addToEnd` when idle starts playback
  - `removeFromQueue` at index before current → `currentIndex` decrements
  - `removeFromQueue` at current track → advances to next or stops
  - `removeFromQueue` at index after current → `currentIndex` unchanged
  - `moveInQueue` — current track follows through move (several cases)
  - Existing tests updated to work with `QueueItem`-based queue (access `.track`
    where needed)

## Known ambiguities / open questions

- **`currentTrack` as stored vs computed.** Currently `currentTrack` is a `private(set)
  var` set in `loadCurrentTrack`. Changing it to a computed property derived from
  `queue[currentIndex]` is cleaner for queue modifications but changes observation
  behavior — `@Observable` only notifies on stored property writes, not computed reads.
  Decision: keep `currentTrack` as a stored property, updated in `loadCurrentTrack` and
  in `removeFromQueue`/`moveInQueue` when the current item changes. Simpler observation,
  matches the existing pattern.
- **Tap-to-jump in NowPlayingView.** Currently tapping a queue row calls
  `playback.play(playback.queue, startingAt: idx)` which replaces the queue. With
  queue management, tapping should just jump within the existing queue (set
  `currentIndex` and `loadCurrentTrack`) without rebuilding it. Add a
  `skipTo(index:)` method for this.
- **Recording-level context menu placement.** SwiftUI `Section` headers don't natively
  support `.contextMenu`. Use a `Button`-styled header or place the recording-level
  actions in a separate row within the section. Implementer's call on the best UX.

## Out of scope

- Playlists (create/save/persist) — 03-004
- "Save queue as playlist" — stretch goal, deferred
- Queue persistence across app launches (queue is ephemeral in-memory state)
- Shuffle / repeat modes
- Cross-fade or gapless transitions between tracks from different recordings
- Backend changes of any kind
- Cover art on queue rows (Phase 5)
- Edit mode toggle button in NowPlayingView toolbar (always-active drag handles are
  sufficient; a toggle can be added as polish)

## Summary output path

`workflow/packets/03-003-queue-management.summary.md`
