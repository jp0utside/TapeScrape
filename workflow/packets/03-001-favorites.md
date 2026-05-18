# Task Packet: Favorite concerts — persistent tag, heart toggle, Library tab

**Packet ID:** 03-001-favorites
**Phase:** 3
**Created:** 2026-05-18
**Status:** READY
**Auto-proceed:** true
**High-risk:** false

## Goal

The smallest useful Phase 3 deliverable: a user can **heart a concert** from the concert
detail screen, and the **Library tab** shows all favorited concerts, persisted across
launches. This wires up the Phase-0 tag-first model (`Tag`, `TaggedItem`,
`LibraryRepository`) with a real SQLite-backed implementation and minimal UI. No backend
changes — favorites are entirely client-side (`02-DATA-MODEL.md` § 5).

## Acceptance criteria

- [ ] `SQLiteLibraryRepository` conforms to `LibraryRepository`, backed by a SQLite
      database in the app's Application Support directory. Schema: `tags` table
      (`id TEXT PK, name TEXT, kind TEXT`) and `tagged_items` table
      (`tag_id TEXT, item_id TEXT, created_at REAL, PK(tag_id, item_id)`).
      Tables created idempotently on init (`CREATE TABLE IF NOT EXISTS`).
- [ ] A system `favorite` tag (fixed UUID, `kind = .favorite`) is seeded on first
      launch. The tag is never deleted by user action.
- [ ] `ConcertDetailView` shows a heart button (toolbar, trailing) that toggles the
      concert's favorite status. Filled heart = favorited; outline = not. Tap is
      responsive (optimistic UI update, persist async).
- [ ] `LibraryTab` shows a "Favorites" section listing all favorited concerts (display
      artist, date, venue). Tapping a row navigates to the concert detail (fetches from
      the backend via `CatalogClient.getConcertDetail`). Empty state shows a message
      like "No favorites yet."
- [ ] Favorites persist across app launches (kill and relaunch → favorites still there).
- [ ] `InMemoryLibraryRepository` remains for tests (no SQLite in unit tests).
- [ ] Swift tests: toggle favorite on/off via `LibraryRepository`, verify `items(for:)`
      reflects the change; verify the system favorite tag is present after init.
- [ ] BUILD SUCCEEDED with zero errors. Existing tests still pass.

## Read first

> Floor (CLAUDE.md, CONVENTIONS.md, this packet) not relisted.

- `docs/design/02-DATA-MODEL.md` § 5 — tag-first schema, repository access only,
  local-only v1 decision
- `docs/design/03-CLIENT-AND-PLAYBACK.md` § 2–3 — app structure, Library tab intent
  ("dynamic, not a flat list"), repository hook
- `TapeScrape/Models/Tag.swift` — existing `Tag`, `TagKind`, `TaggedItem` models
- `TapeScrape/Repositories/LibraryRepository.swift` — existing protocol +
  `InMemoryLibraryRepository`
- `TapeScrape/Views/LibraryTab.swift` — current stub (just "Library" text)
- `TapeScrape/Views/ConcertDetailView.swift` — where the heart button goes
- `TapeScrape/TapeScrapeApp.swift` — app entry point; where the repository is
  constructed and injected into the environment
- `TapeScrape/Models/Concert.swift` — `ConcertListItem` / `ConcertDetailResponse`
  (the item IDs used in tagging)

## Files expected to change

- `TapeScrape/Repositories/SQLiteLibraryRepository.swift` — **new**: SQLite-backed
  `LibraryRepository` implementation using Foundation's `sqlite3` C API (no SwiftData
  dependency). Idempotent schema creation, seeds system `favorite` tag.
- `TapeScrape/Repositories/LibraryRepository.swift` — minor: may add a
  `isFavorited(_ itemID:)` convenience method to the protocol (avoids each caller
  fetching all items then filtering)
- `TapeScrape/Models/Tag.swift` — add `static let favoriteTagID: UUID` (fixed, stable
  UUID for the system favorite tag)
- `TapeScrape/Views/ConcertDetailView.swift` — add heart toolbar button; inject
  `LibraryRepository` from environment; toggle favorite on tap
- `TapeScrape/Views/LibraryTab.swift` — replace stub with favorites list; inject
  `LibraryRepository` from environment; navigate to concert detail on tap
- `TapeScrape/TapeScrapeApp.swift` — construct `SQLiteLibraryRepository` (or
  `InMemoryLibraryRepository` based on a flag/protocol), inject into environment
- `TapeScrapeTests/Repositories/SQLiteLibraryRepositoryTests.swift` — **new**: tests
  for the SQLite implementation (uses a temp file, not in-memory stub)
- `TapeScrapeTests/Repositories/LibraryRepositoryTests.swift` — new/updated: protocol
  contract tests (tag/untag, isFavorited, system tag seeded)

## Interface sketch

```swift
// Tag.swift — stable favorite tag ID
extension Tag {
    static let favoriteTagID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let favoriteTag = Tag(id: favoriteTagID, name: "Favorites", kind: .favorite)
}

// LibraryRepository.swift — convenience addition
protocol LibraryRepository {
    // ... existing methods ...
    func isFavorited(_ itemID: String) async -> Bool
}

// SQLiteLibraryRepository.swift
actor SQLiteLibraryRepository: LibraryRepository {
    private let dbPath: URL

    init(directory: URL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!) {
        self.dbPath = directory.appendingPathComponent("library.db")
        createTablesIfNeeded()
        seedSystemTags()
    }

    // ... LibraryRepository conformance via sqlite3 C API ...
}

// ConcertDetailView.swift — heart button
struct ConcertDetailView: View {
    let concert: ConcertDetailResponse
    @State private var isFavorited = false

    var body: some View {
        List { ... }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { toggleFavorite() } label: {
                        Image(systemName: isFavorited ? "heart.fill" : "heart")
                    }
                }
            }
            .task { isFavorited = await repository.isFavorited(concert.id) }
    }
}

// LibraryTab.swift — favorites list
struct LibraryTab: View {
    @State private var favorites: [TaggedItem] = []

    var body: some View {
        NavigationStack {
            Group {
                if favorites.isEmpty {
                    ContentUnavailableView("No Favorites Yet",
                        systemImage: "heart",
                        description: Text("Heart a concert to save it here."))
                } else {
                    List(favorites, id: \.id) { item in
                        NavigationLink(value: item.itemID) { ... }
                    }
                }
            }
            .navigationTitle("Library")
            .navigationDestination(for: String.self) { concertID in
                // Fetch detail and show ConcertDetailView
            }
            .task { await loadFavorites() }
        }
    }
}
```

## Constraints to preserve

- See `workflow/CONVENTIONS.md` and `CLAUDE.md` § "Core constraints" (always applicable)
- Library data is **client-side only** — no backend endpoint for favorites
  (`02-DATA-MODEL.md` § 5, resolved D3 = local-only v1)
- Repository access only — views never touch SQLite directly (CONVENTIONS §1 client
  clause, `02-DATA-MODEL.md` § 5 "Repository access only")
- The four hooks remain intact — library data goes through `LibraryRepository`, not a
  new persistence path (`00-ARCHITECTURE.md` § 3 hook 4)
- No SwiftData — use sqlite3 C API or a thin wrapper, consistent with the backend's
  raw-sqlite3 approach. SwiftData adds a heavyweight framework dependency for a
  two-table schema. The design doc says "SwiftData (or a thin SQLite wrapper)" — the
  wrapper is the right call at this scale.
- Existing `InMemoryLibraryRepository` remains for unit tests (CONVENTIONS §11)

## Tests

- REQUIRED
- `TapeScrapeTests/Repositories/SQLiteLibraryRepositoryTests.swift` (new): init creates
  tables; system favorite tag is seeded; tagItem + isFavorited round-trip; untagItem
  removes; duplicate tagItem is idempotent; uses a temp-directory SQLite file (deleted
  in teardown)
- `TapeScrapeTests/Repositories/LibraryRepositoryTests.swift` (new/updated): protocol
  contract tests against `InMemoryLibraryRepository` — same assertions as above,
  verifying the in-memory stub still works for other tests

## Known ambiguities / open questions

- **What ID is used for tagging?** The `concert.id` (UUID5 string from the backend).
  This ties the favorite to the canonical concert, not a specific recording. If
  re-aggregation produces a new concert ID for the same show (e.g., venue clustering
  changes), the favorite is orphaned. Acceptable at v1 — concert IDs are deterministic
  (`artist|date|venue` → UUID5) and stable unless the canonical key changes. A future
  reconciliation pass could re-link orphans.
- **Library tab shows only favorites now.** The roadmap says "recently played,
  favorited-show anniversaries, artists engaged with" — those are later packets.
  This packet gives it a favorites section only. The tab structure should accommodate
  future sections (use a `List` with `Section`, not a flat list).
- **Favorite concerts need display info.** `TaggedItem` stores only `itemID` (the
  concert UUID). To show artist/date/venue in the Library tab we need to fetch concert
  detail. Options: (a) store display metadata alongside the tagging (denormalized),
  (b) fetch from backend on Library tab load. Option (a) is better — avoids N network
  calls on every Library tab open, and the display data is small and rarely changes.
  Add `display_artist`, `date`, `display_venue` columns to `tagged_items` (or a
  companion `concert_cache` table). This is a pragmatic denormalization, not a layering
  violation — the Library tab shouldn't require network to show saved concerts.

## Out of scope

- Favoriting individual **recordings** or **tracks** (only concerts for now; the
  tag-first model supports finer granularity later)
- Playlists (next Phase 3 packet)
- Recently played / dynamic shelves on Library or Home tab (later Phase 3 packets)
- Smart collections, tag UI, notes (deferred per library-subset decision)
- CloudKit sync (deferred per D3 = local-only v1)
- Playback history persistence (separate concern; `PlaybackHistoryRepository` is still
  in-memory — a later packet)
- Cover art on the library rows (Phase 5)
- Backend changes of any kind
- Offline/download state on favorites (Phase 4)

## Summary output path

`workflow/packets/03-001-favorites.summary.md`
