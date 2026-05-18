# Implementation Summary: 03-005-dynamic-home

**Packet:** 03-005-dynamic-home
**Status:** COMPLETE
**Date:** 2026-05-18

## What was done

- Added `EngagedArtist` struct (`canonicalArtist`, `displayArtist`, `lastPlayedAt`, `playCount`) to `PlaybackHistoryRepository.swift`.
- Extended `PlaybackHistoryRepository` protocol with `distinctArtists(limit:) async -> [EngagedArtist]`.
- Implemented `distinctArtists` in `InMemoryPlaybackHistoryRepository`: groups entries by `artist.lowercased()`, picks the most recent play date, counts plays, sorts descending by recency.
- Implemented `distinctArtists` in `SQLitePlaybackHistoryRepository`: `GROUP BY LOWER(artist)`, `MAX(played_at)`, `COUNT(*)`, `ORDER BY last_played DESC LIMIT ?`. Uses `displayArtist.lowercased()` for `canonicalArtist`.
- Added `distinctArtists(limit:) -> []` stub to `MockPlaybackHistoryRepository` in `PlaybackCoordinatorTests.swift` (protocol conformance).
- Rewrote `HomeTab` sections:
  - **Recently Played** — unchanged, top position.
  - **On This Day** — new; loads `favoritedConcerts()` from `LibraryRepository`, filters by suffix-match `-MM-DD` against today, navigates to `ConcertDetailLoaderView` via `navigationDestination(for: ConcertSnapshot.self)`.
  - **Artists You Listen To** — new; loads `distinctArtists(limit: 5)`, navigates to `ConcertListView` via `ArtistMatch` conversion (canonical = `artist.canonicalArtist`).
  - **Browse** (GD fallback) — conditional on `recentConcerts.isEmpty`; hidden once history exists.
- Added `OnThisDayRow` and `EngagedArtistRow` private view structs.
- Added 4 new tests to `PlaybackHistoryRepositoryTests.swift` against `InMemoryPlaybackHistoryRepository`:
  - `distinctArtistsEmptyWhenNoHistory`
  - `distinctArtistsOrderedByMostRecentPlay`
  - `distinctArtistsRespectsLimit`
  - `distinctArtistsAggregatesPlayCountAcrossTracksAndConcerts`

## Test results

BUILD SUCCEEDED. 110 Swift tests pass, 0 failures.

## Deviations

None. All acceptance criteria met as specified.

## Notes

- `todayMonthDay` is computed on `.onAppear` load, so on the rare case the app is open across midnight the "On This Day" section won't refresh until next appear — acceptable at v1.
- SQLite `GROUP BY LOWER(artist)` is correct but will pick whichever row SQLite selects for the `artist` display string within a case group (implementation-defined in standard SQL; in practice it picks the first row encountered). For the single-user, single-artist-name-per-play scenario this is fine.

## Status journal

Deliverable log row in `docs/roadmap_status.md` updated to COMPLETE as the final step of this build.
