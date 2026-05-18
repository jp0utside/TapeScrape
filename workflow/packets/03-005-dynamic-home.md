# Task Packet: Dynamic Home tab shelves

**Packet ID:** 03-005-dynamic-home
**Phase:** 3
**Created:** 2026-05-18
**Status:** READY
**Auto-proceed:** true
**High-risk:** false

## Goal

Turn the Home tab from a static "Recently Played + Browse GD" screen into the dynamic
discovery surface described in `03-CLIENT-AND-PLAYBACK.md` § 2: "recently played,
favorited-show anniversaries, artists you've engaged with, 'more from this run.'" All
data is derived from existing repositories (playback history + favorites) — no backend
changes, no new persistence.

## Acceptance criteria

- [ ] `PlaybackHistoryRepository` gains `distinctArtists(limit:) async -> [EngagedArtist]`
      returning distinct artists the user has listened to, ordered by most-recently-played,
      with play count. `EngagedArtist` struct: `canonicalArtist`, `displayArtist`,
      `lastPlayedAt`, `playCount`.
- [ ] `InMemoryPlaybackHistoryRepository` and `SQLitePlaybackHistoryRepository` implement
      `distinctArtists(limit:)`.
- [ ] HomeTab shows an **"Artists You Listen To"** section when the user has history.
      Each row shows artist name + play count context (e.g. "12 tracks played"), tappable
      to navigate to `ConcertListView` for that artist. Capped at 5 artists; does not
      show when empty.
- [ ] HomeTab shows an **"On This Day"** section when any favorited concert has a
      month-day matching today. Each row is a `ConcertSnapshot` navigating to detail.
      Parsing uses the `date` string's month-day portion (IA dates are `YYYY-MM-DD`).
      Does not show when empty or when no favorites match today.
- [ ] The existing "Recently Played" section remains at the top, unchanged.
- [ ] The static "Browse Grateful Dead" hardcoded link is replaced by the
      "Artists You Listen To" section when the user has history. When history is empty,
      the GD browse link remains as a starter prompt (the user still needs an entry point
      before they've played anything).
- [ ] Section ordering: Recently Played → On This Day → Artists You Listen To → (fallback
      browse if no history). Empty sections are hidden, not shown with empty state.
- [ ] BUILD SUCCEEDED with zero errors. Existing tests still pass. New tests pass.

## Read first

> Floor (CLAUDE.md, CONVENTIONS.md, this packet) not relisted.

- `TapeScrape/Views/HomeTab.swift` — the view being rewritten
- `TapeScrape/Repositories/PlaybackHistoryRepository.swift` — protocol, `RecentConcert`,
  `InMemoryPlaybackHistoryRepository`; adding `distinctArtists`
- `TapeScrape/Repositories/SQLitePlaybackHistoryRepository.swift` — SQL patterns for the
  new query
- `TapeScrape/Repositories/LibraryRepository.swift` — `favoritedConcerts()` used for
  "On This Day" filtering
- `TapeScrape/Models/Concert.swift` — `ArtistMatch` (used for navigation to
  `ConcertListView`); `ConcertSnapshot` for favorites

## Files expected to change

- `TapeScrape/Repositories/PlaybackHistoryRepository.swift` — add `EngagedArtist` struct;
  add `distinctArtists(limit:)` to protocol; implement in `InMemoryPlaybackHistoryRepository`
- `TapeScrape/Repositories/SQLitePlaybackHistoryRepository.swift` — implement
  `distinctArtists(limit:)` with `GROUP BY artist`
- `TapeScrape/Views/HomeTab.swift` — add On This Day and Artists You Listen To sections;
  conditional GD fallback; section ordering

## Interface sketch

```swift
// PlaybackHistoryRepository.swift — new struct + method

struct EngagedArtist: Identifiable, Hashable, Sendable {
    var id: String { canonicalArtist }
    let canonicalArtist: String
    let displayArtist: String
    let lastPlayedAt: Date
    let playCount: Int
}

protocol PlaybackHistoryRepository: Sendable {
    // ... existing ...
    func distinctArtists(limit: Int) async -> [EngagedArtist]
}

// HomeTab.swift — section structure
List {
    if !recentConcerts.isEmpty {
        Section("Recently Played") { ... }         // existing
    }
    if !onThisDayConcerts.isEmpty {
        Section("On This Day") { ... }             // new
    }
    if !engagedArtists.isEmpty {
        Section("Artists You Listen To") { ... }   // new
    }
    if recentConcerts.isEmpty {
        Section("Browse") { /* GD starter link */ } // existing fallback
    }
}
```

## Constraints to preserve

- See `workflow/CONVENTIONS.md` and `CLAUDE.md` § "Core constraints" (always applicable)
- No backend changes — all data from existing client repositories
- No new persistence — `distinctArtists` is a query over existing `playback_history` table;
  "On This Day" filters in-memory from `favoritedConcerts()`
- `PlaybackCoordinator` unchanged
- Navigation destinations for `ConcertListView` and `ConcertDetailLoaderView` already
  exist on HomeTab — reuse them
- `EngagedArtist` → `ArtistMatch` conversion for `ConcertListView` navigation (the
  view takes `ArtistMatch`); use `canonicalArtist` as the artist key

## Tests

- REQUIRED
- `TapeScrapeTests/PlaybackHistoryRepositoryTests.swift` (new or extend existing):
  - `distinctArtists` returns artists sorted by most-recently-played
  - `distinctArtists` respects limit
  - `distinctArtists` aggregates play count across multiple tracks/concerts
  - `distinctArtists` returns empty when no history
- Test against `InMemoryPlaybackHistoryRepository` (unit). SQLite integration test
  optional but recommended.

## Known ambiguities / open questions

- **"On This Day" date parsing.** IA dates in `ConcertSnapshot.date` are typically
  `YYYY-MM-DD` but may have imprecise dates. Parse with a simple suffix match on
  `-MM-DD` against today's date. If the date doesn't match the pattern, skip it —
  no crash, no inclusion. This is a best-effort feature.
- **`EngagedArtist.canonicalArtist` vs `displayArtist`.** The playback history stores
  `artist` from `ConcertContext` which is the display form (e.g. "Grateful Dead"). For
  the `ConcertListView` navigation, we need the canonical form (lowercased, as used by
  the backend search). Use `artist.lowercased()` as `canonicalArtist` — this matches
  the backend's canonicalization for common cases. Imperfect for edge cases (e.g.
  "The Band" vs "band") but acceptable at v1; the backend search is fuzzy enough.
- **"More from this run/tour"** is listed in the design doc but requires knowing which
  concerts are nearby in a tour, which needs backend data not available client-side.
  Deferred to a future packet — the "Artists You Listen To" shelf serves the same
  browse-more intent for v1.

## Out of scope

- "More from this run/tour" shelf (requires backend tour/date-proximity data)
- Library tab changes (already dynamic with favorites + playlists)
- Scoped per-track search (separate packet, requires backend `track_index`)
- Cover art on shelves (Phase 5)
- Personalized recommendations or algorithmic sorting
- Pull-to-refresh (`.onAppear` reload is sufficient for v1)
- Backend changes of any kind

## Summary output path

`workflow/packets/03-005-dynamic-home.summary.md`
