# Implementation Summary: 03-002-playback-history

**Status:** COMPLETE
**Date:** 2026-05-18

## What was done

- `PlaybackHistoryRepository.swift` — Extended protocol with `ConcertContext` (concertID, recordingIdentifier, artist, date, venue), `RecentConcert` (Identifiable, Hashable, Sendable), updated `recordPlay` signature to accept `context: ConcertContext`, added `recentConcerts(limit:)`. Added `playbackHistoryRepository` environment key (same pattern as `libraryRepository`). Updated `InMemoryPlaybackHistoryRepository` with actor-based grouping logic.
- `SQLitePlaybackHistoryRepository.swift` (new) — SQLite-backed actor using the same `library.sqlite` file. Idempotent `CREATE TABLE IF NOT EXISTS playback_history` (id, identifier, track_file, played_at, concert_id, artist, date, venue). `recentConcerts` uses `GROUP BY concert_id / MAX(played_at)` SQL.
- `PlaybackCoordinator.swift` — Added `private(set) var concertContext: ConcertContext?`; injected `history: any PlaybackHistoryRepository` (default `InMemoryPlaybackHistoryRepository()`); updated `play(_:startingAt:concert:)`; added fire-and-forget `Task { try? await h.recordPlay(...) }` in `onPlaybackReady` callback (only records when both `currentTrack` and `concertContext` are set).
- `ConcertDetailView.swift` — Passes `ConcertContext(concertID:recordingIdentifier:artist:date:venue:)` when calling `playback.play(...)`.
- `HomeTab.swift` — Shows a "Recently Played" section (artist, date, venue, relative timestamp); empty-state prompt + GD browse link always in "Browse" section. Refreshes on `.onAppear`. `navigationDestination(for: RecentConcert.self)` navigates to `ConcertDetailLoaderView`.
- `TapeScrapeApp.swift` — Constructs one `SQLitePlaybackHistoryRepository` instance; passes it to `PlaybackCoordinator(history:)` and injects it via `.environment(\.playbackHistoryRepository, ...)`.
- `TapeScrapeTests/Repositories/PlaybackHistoryRepositoryTests.swift` (new) — 5 tests: single play, grouping, ordering, limit, `recentPlays` order.
- `PlaybackCoordinatorTests.swift` — Added `MockPlaybackHistoryRepository` actor; updated `makeCoordinator` to accept injectable history; 2 new tests: `playbackReadyRecordsPlayWhenContextIsSet`, `playbackReadyDoesNotRecordWithoutConcertContext`.
- All 79 Swift tests pass. BUILD SUCCEEDED.

## Deviations from packet spec

- **`ConcertContext` gained `recordingIdentifier`** — The interface sketch didn't include it, but `recordPlay(identifier:...)` requires the IA recording identifier (the `RecordingResponse.identifier`). Adding it to `ConcertContext` was the natural carrier since `play(recording.tracks, ...)` is called from the recording context in `ConcertDetailView`.
- **History data flows through one instance** — A single `SQLitePlaybackHistoryRepository` is shared between `PlaybackCoordinator` and the environment (both receive the same instance). This ensures `HomeTab` reads exactly what the coordinator writes, without a second SQLite connection.

## Known omissions (per packet scope)

- `stoppedPosition` tracking (resume-from-position) — explicitly out of scope, not tracked. Future packet.
- `HomeTab` refresh is `.onAppear`-triggered (polls once per tab visit), not reactive/push. Sufficient for single-user use; a live observable shelf is a future polish item.

## Status journal

`docs/roadmap_status.md` row for `03-002-playback-history` updated to COMPLETE.
