# Implementation Summary: 03-003-queue-management

**Status:** COMPLETE
**Date:** 2026-05-18

## What shipped

- `QueueItem` struct (`id: UUID`, `track: TrackResponse`, `concertContext: ConcertContext?`) added to `PlaybackCoordinator.swift`; `queue` changed from `[TrackResponse]` to `[QueueItem]`
- Global `concertContext` property removed; per-item context now flows from `queue[currentIndex].concertContext` in history recording and `loadCurrentTrack()`
- `play(_:startingAt:concert:)` wraps tracks into `QueueItem`s on replacement — external callers unchanged
- `playNext(_:concert:)` — inserts after `currentIndex`; if idle starts playback from the front of the inserted block
- `addToEnd(_:concert:)` — appends to tail; if idle starts playback from the front of the appended block
- `removeFromQueue(at:)` — removes item; decrements `currentIndex` when removed before current; advances to next (or stops) when removed at current; no change when removed after current
- `moveInQueue(from:to:)` — moves via `Array.move(fromOffsets:toOffset:)`; `currentIndex` follows the current item by UUID lookup
- `skipTo(index:)` — jumps within the existing queue without replacing it; used by `NowPlayingView` track-row taps
- `NowPlayingView.trackList` rewritten to iterate `[QueueItem]`, add `.onDelete`/`.onMove`, dim past-tracks at 0.5 opacity, use `skipTo(index:)` instead of replacing the queue on tap
- `ConcertDetailView` track rows gain a context menu ("Play Next", "Add to Queue"); each recording section header gains a `Menu` button with "Play Recording Next" / "Add Recording to Queue"
- 13 new tests: `playNext*`, `addToEnd*`, `removeFromQueue*`, `moveInQueue*`, `skipTo*`
- BUILD SUCCEEDED; 92 Swift tests pass (79 pre-existing + 13 new)

## Deviations

None. The `currentTrack` stored-property approach (vs computed) was chosen as specified in the ambiguities section. The recording-level header menu was implemented as a `Menu { } label: { Image(systemName: "ellipsis.circle") }` in the `Section` header `HStack` — fits the SwiftUI constraint and gives clean UX without a separate row.

## Status journal

- `docs/roadmap_status.md` row updated to COMPLETE.
