# Implementation Summary: 03-001-favorites

**Result:** COMPLETE
**Completed:** 2026-05-18

## Acceptance criteria check

- [✓] `SQLiteLibraryRepository` conforms to `LibraryRepository`, backed by SQLite in Application Support. Tables `tags`, `tagged_items`, `concert_snapshots` created idempotently via `CREATE TABLE IF NOT EXISTS`.
- [✓] System `favorite` tag (fixed UUID `00000000-0000-0000-0000-000000000001`) seeded on first launch via `INSERT OR IGNORE`.
- [✓] `ConcertDetailView` shows a heart toolbar button (top-bar trailing, red fill = favorited). Tap is optimistic (state flips immediately, persist async via `Task`). State loaded in `.task`.
- [✓] `LibraryTab` shows a "Favorites" section listing favorited concerts (artist, date, venue). Tapping navigates to `ConcertDetailLoaderView` → `ConcertDetailView`. Empty state shown when none.
- [✓] Favorites persist across app launches — SQLite-backed, app-support directory.
- [✓] `InMemoryLibraryRepository` kept in `LibraryRepository.swift` for tests and previews; pre-seeds the favorite tag.
- [✓] Swift tests: `SQLiteLibraryRepositoryTests` (10 tests) + `LibraryRepositoryTests` (8 tests) — all pass without network.
- [✓] BUILD SUCCEEDED; 79 Swift Testing tests pass (up from 53).

## Files changed

- `TapeScrape/Models/Tag.swift` — added `Tag.favoriteTagID` (stable UUID) and `Tag.favoriteTag` extension
- `TapeScrape/Repositories/LibraryRepository.swift` — added `ConcertSnapshot` struct; added `Sendable` to protocol; extended protocol with `isFavorited`, `favoritedConcerts`, `setFavorite`; added `LibraryRepositoryKey` + `EnvironmentValues` extension; updated `InMemoryLibraryRepository` to implement new methods and pre-seed the favorite tag
- `TapeScrape/Repositories/SQLiteLibraryRepository.swift` — new; SQLite-backed actor implementation
- `TapeScrape/TapeScrapeApp.swift` — constructs `SQLiteLibraryRepository` at app-support path; injects via `.environment(\.libraryRepository, library)`
- `TapeScrape/Views/ConcertDetailView.swift` — added `@Environment(\.libraryRepository)`, `@State isFavorited`, heart toolbar button, `.task` to load state, `toggleFavorite()` helper
- `TapeScrape/Views/LibraryTab.swift` — replaced stub with favorites list using `ConcertSnapshot`, `NavigationStack`, `ContentUnavailableView` empty state, `navigationDestination` → `ConcertDetailLoaderView`
- `TapeScrapeTests/Repositories/SQLiteLibraryRepositoryTests.swift` — new; 10 tests covering init, CRUD, idempotency, multi-favorite independence
- `TapeScrapeTests/Repositories/LibraryRepositoryTests.swift` — new; 8 protocol-contract tests against `InMemoryLibraryRepository`

## Tests

- **Added:** `TapeScrapeTests/Repositories/SQLiteLibraryRepositoryTests.swift` (10 tests), `TapeScrapeTests/Repositories/LibraryRepositoryTests.swift` (8 tests)
- **Modified:** none
- **Run command:** `xcodebuild test -project TapeScrape.xcodeproj -scheme TapeScrape -destination 'platform=iOS Simulator,name=iPhone 16'`
- **Result:** 79 passed, 0 failed

## Deviations from packet

- **`EnvironmentKey` is `private`** in `LibraryRepository.swift` (the type itself, not the `EnvironmentValues` extension). The packet's interface sketch showed it as `struct LibraryRepositoryKey` (internal); making it `private` is strictly cleaner since callers use the `\.libraryRepository` key path only. No behavioral difference.
- **`SQLiteLibraryRepository.db` is `nonisolated(unsafe)`** rather than actor-isolated. Swift 6 forbids accessing non-`Sendable` stored properties from `deinit` (which is nonisolated). Since the actor serializes all access and `deinit` has exclusive ownership, `nonisolated(unsafe)` is the correct and safe fix. `OpaquePointer` is not `Sendable`.
- **Setup calls moved to `private static` functions** (`createTables`, `seedFavoriteTag`). Swift 6 forbids calling actor-isolated instance methods from `init` in a synchronous nonisolated context. Static methods are not actor-isolated and can be called from `init` safely.
- **`SQLITE_TRANSIENT` defined locally** as `unsafeBitCast(-1, to: sqlite3_destructor_type.self)`. The C macro is not automatically bridged to Swift.
- **`LibraryRepository` conforms to `Sendable`** — required so that `any LibraryRepository` can be passed across actor boundaries from `@MainActor`-isolated views (Swift 6 strict concurrency).
- **`LibraryTab` uses `.onAppear` for refresh** in addition to `.task` for initial load, so favorites update when returning from `ConcertDetailView` after toggling.

## Out-of-scope issues discovered

- `ConcertDetailView` still uses deprecated `Color.accentColor` on the track play icon (F1-4 from Phase 1 review). Out of scope.
- `TapeScrapeApp` constructs `SQLiteLibraryRepository` as a `let` constant via `private let library: any LibraryRepository`. The `@State` wrapper isn't appropriate for an actor-based repository (actors aren't `Observable`). This is correct — the repository itself is long-lived and the view system is driven by the data it returns, not by observing the repository directly.

## Blockers / follow-ups

- none

## Notes for review

The three Swift 6 actor-init issues (`SQLITE_TRANSIENT` bridging, `nonisolated(unsafe)` for `deinit`, static helpers for init) are the primary surprises. All are correctness requirements of Swift 6 strict concurrency, not workarounds. `ConcertDetailLoaderView` was already internal (not `private`) in `ConcertListView.swift`, so `LibraryTab` could reuse it directly without any change to that file.

## Status journal (mandatory — the packet is not done without this)

- [ ] `docs/roadmap_status.md` deliverable-log row for `03-001-favorites` set to
      **COMPLETE**, with deviations/follow-ups copied from this summary.
- Phase-level status / Blockers / decision history: **left untouched** (Review/Plan own those).
