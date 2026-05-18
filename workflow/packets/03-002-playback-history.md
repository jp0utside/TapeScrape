# Task Packet: Playback history — persist plays, recently played on Home tab

**Packet ID:** 03-002-playback-history
**Phase:** 3
**Created:** 2026-05-18
**Status:** READY
**Auto-proceed:** true
**High-risk:** false

## Goal

Wire up the Phase-0 `PlaybackHistoryRepository` stub with SQLite persistence and make the
Home tab dynamic. When a track plays, the app records it. The Home tab shows **recently
played concerts** (grouped by concert, most recent first) — replacing the hardcoded
Grateful Dead link with real history. Persisted across launches. No backend changes.

This directly serves the Phase 3 "Done when" gate: *"you can get back to a show you liked
without re-searching."*

## Acceptance criteria

- [ ] `SQLitePlaybackHistoryRepository` conforms to `PlaybackHistoryRepository`, backed
      by the same `library.db` SQLite database used by `SQLiteLibraryRepository`
      (Application Support directory). Schema: `playback_history` table
      (`id INTEGER PK AUTOINCREMENT, identifier TEXT, track_file TEXT,
      played_at REAL, concert_id TEXT, artist TEXT, date TEXT, venue TEXT`).
      Table created idempotently (`CREATE TABLE IF NOT EXISTS`).
- [ ] `PlaybackCoordinator` records a play event when a track starts playing
      (transition to `.playing` state on `onPlaybackReady`). Records the
      recording identifier, track filename, current date, and concert context
      (concert ID, artist, date, venue from the current concert detail).
- [ ] `PlaybackCoordinator` knows the current concert context. When `play(_:startingAt:)`
      is called, the concert context is passed alongside the tracks (either as a
      parameter or set beforehand). This is needed so history entries carry enough
      display info to render without a network call.
- [ ] `PlaybackHistoryRepository` protocol gains `recentConcerts(limit:)` returning
      `[RecentConcert]` — a lightweight struct with concert ID, artist, date, venue,
      and last-played timestamp. Groups by concert, ordered by most recent play.
- [ ] Home tab shows a "Recently Played" section listing recent concerts (display
      artist, date, venue, relative timestamp like "Today" / "Yesterday" / date).
      Tapping navigates to concert detail via `ConcertDetailLoaderView`. The hardcoded
      Grateful Dead link is replaced (or moved to a "Browse" section below history).
      Empty state: show a prompt like "Play a concert to see it here" plus the
      existing GD browse link so there's always something actionable.
- [ ] History persists across app launches.
- [ ] `InMemoryPlaybackHistoryRepository` updated with the new method for tests.
- [ ] Swift tests: record a play → `recentConcerts` returns it; multiple plays of
      different concerts → ordered by most recent; multiple plays of same concert →
      grouped (one entry, latest timestamp).
- [ ] BUILD SUCCEEDED with zero errors. Existing tests still pass.

## Read first

> Floor (CLAUDE.md, CONVENTIONS.md, this packet) not relisted.

- `docs/design/02-DATA-MODEL.md` § 5 — `PlaybackHistory` schema
  (`recordingID, trackIndex, playedAt, stoppedPosition`)
- `docs/design/03-CLIENT-AND-PLAYBACK.md` § 2 — Home tab intent: "dynamic shelves:
  recently played, favorited-show anniversaries, artists you've engaged with"
- `TapeScrape/Repositories/PlaybackHistoryRepository.swift` — existing protocol +
  `InMemoryPlaybackHistoryRepository` + `PlayRecord` struct
- `TapeScrape/Playback/PlaybackCoordinator.swift` — where play events are detected
  (the `onPlaybackReady` callback); needs concert context
- `TapeScrape/Views/HomeTab.swift` — current hardcoded GD link; becomes dynamic
- `TapeScrape/Repositories/SQLiteLibraryRepository.swift` — reference for the SQLite
  pattern (same `library.db` file, `sqlite3` C API, idempotent table creation)
- `TapeScrape/Views/ConcertDetailView.swift` — calls `playback.play(tracks, startingAt:)`
  — must also pass concert context
- `TapeScrape/TapeScrapeApp.swift` — where the repository is constructed and injected

## Files expected to change

- `TapeScrape/Repositories/PlaybackHistoryRepository.swift` — extend protocol with
  `recentConcerts(limit:)` and `RecentConcert` struct; add concert-context fields to
  `recordPlay`; update `InMemoryPlaybackHistoryRepository`
- `TapeScrape/Repositories/SQLitePlaybackHistoryRepository.swift` — **new**:
  SQLite-backed implementation. Shares the `library.db` file path (pass at init or
  use same default). Idempotent table creation in the existing DB.
- `TapeScrape/Playback/PlaybackCoordinator.swift` — (a) add a `concertContext`
  property (set when `play` is called); (b) inject `PlaybackHistoryRepository`;
  (c) record play event in `onPlaybackReady` callback
- `TapeScrape/Views/ConcertDetailView.swift` — pass concert context when calling
  `playback.play(...)` (artist, date, venue, concert ID from the `ConcertDetailResponse`)
- `TapeScrape/Views/HomeTab.swift` — replace hardcoded GD link with recently played
  section; retain GD as a fallback/browse link in empty state
- `TapeScrape/TapeScrapeApp.swift` — construct `SQLitePlaybackHistoryRepository`,
  inject into `PlaybackCoordinator` and/or environment
- `TapeScrapeTests/Playback/PlaybackCoordinatorTests.swift` — updated: verify play
  recording is called when track starts
- `TapeScrapeTests/Repositories/PlaybackHistoryRepositoryTests.swift` — **new/updated**:
  test `recentConcerts` grouping and ordering

## Interface sketch

```swift
// PlaybackHistoryRepository.swift — extended protocol
struct RecentConcert: Identifiable, Hashable {
    var id: String { concertID }
    let concertID: String
    let artist: String
    let date: String
    let venue: String?
    let lastPlayedAt: Date
}

struct ConcertContext {
    let concertID: String
    let artist: String
    let date: String
    let venue: String?
}

protocol PlaybackHistoryRepository: Sendable {
    func recordPlay(identifier: String, trackFile: String, at: Date,
                    context: ConcertContext) async throws
    func recentPlays(limit: Int) async -> [PlayRecord]
    func recentConcerts(limit: Int) async -> [RecentConcert]
}

// PlaybackCoordinator.swift — context + history recording
@Observable @MainActor
final class PlaybackCoordinator {
    private(set) var concertContext: ConcertContext?
    private let history: any PlaybackHistoryRepository

    func play(_ tracks: [TrackResponse], startingAt index: Int = 0,
              concert: ConcertContext? = nil) {
        if let concert { concertContext = concert }
        queue = tracks
        currentIndex = index
        loadCurrentTrack()
    }

    // In setupCallbacks, onPlaybackReady:
    // Task { await history.recordPlay(..., context: concertContext) }
}

// ConcertDetailView.swift — pass context
Button { playback.play(recording.tracks, startingAt: idx,
    concert: ConcertContext(concertID: concert.id, artist: concert.artist,
                            date: concert.date, venue: concert.venue))
} label: { ... }

// HomeTab.swift — recently played
struct HomeTab: View {
    @State private var recentConcerts: [RecentConcert] = []

    var body: some View {
        NavigationStack {
            List {
                if !recentConcerts.isEmpty {
                    Section("Recently Played") {
                        ForEach(recentConcerts) { concert in
                            NavigationLink(value: concert) { ... }
                        }
                    }
                }
                Section("Browse") {
                    // GD link (always present)
                }
            }
            .navigationDestination(for: RecentConcert.self) { concert in
                ConcertDetailLoaderView(concertId: concert.concertID,
                                        title: concert.date)
            }
        }
    }
}
```

## Constraints to preserve

- See `workflow/CONVENTIONS.md` and `CLAUDE.md` § "Core constraints" (always applicable)
- Library/history data is **client-side only** — no backend changes
- Repository access only — views and `PlaybackCoordinator` never touch SQLite directly
- The four hooks remain intact — playback history through `PlaybackHistoryRepository`
- `PlaybackCoordinator` stays `@Observable @MainActor` — history recording is a fire-
  and-forget `Task` (don't block the playback state machine on a DB write)
- Existing `PlaybackCoordinator` tests use a mock `PlayerBackend` — the history
  repository should also be injectable for testability
- The `PlayRecord` struct and `recentPlays(limit:)` method remain (backwards compatible)

## Tests

- REQUIRED
- `TapeScrapeTests/Repositories/PlaybackHistoryRepositoryTests.swift` (new/updated):
  record plays across concerts → `recentConcerts` returns grouped, most-recent-first;
  same concert played twice → one entry with latest timestamp; limit works
- `TapeScrapeTests/Playback/PlaybackCoordinatorTests.swift` (updated): inject a mock
  history repository; verify `recordPlay` is called when playback starts (track reaches
  `.playing` state via `onPlaybackReady`)
- Tests use `InMemoryPlaybackHistoryRepository` — no SQLite in unit tests

## Known ambiguities / open questions

- **When to record a play.** On `onPlaybackReady` (track actually started playing, not
  just tapped). This avoids recording failed loads. If the same track is retried after
  a failure, it records again — acceptable, the grouping by concert deduplicates in the
  recent list.
- **`stoppedPosition` from the design doc.** The design doc mentions
  `(recordingID, trackIndex, playedAt, stoppedPosition)`. This packet records plays
  but does **not** track `stoppedPosition` (resume-from-where-you-left-off). That's a
  separate, more complex feature (requires recording position on pause/stop/app
  background). Note it in the summary as a future addition.
- **Sharing the SQLite file.** Both `SQLiteLibraryRepository` and
  `SQLitePlaybackHistoryRepository` write to `library.db`. At single-user scale with
  no concurrent writes this is fine (both are actors, so writes within each are serial).
  Cross-actor concurrent writes to the same file could conflict — if this becomes an
  issue, a shared DB manager is the fix, but not in this packet.

## Out of scope

- Resume-from-position (`stoppedPosition` tracking and resume on relaunch)
- "Favorited-show anniversaries" or "more from this run/tour" shelves on Home
- "Artists engaged with" section on Home
- Queue management (play-next, add-to-end, reorder)
- Playlists
- Backend changes of any kind
- Cover art on history rows (Phase 5)

## Summary output path

`workflow/packets/03-002-playback-history.summary.md`
