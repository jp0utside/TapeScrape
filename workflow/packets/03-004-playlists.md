# Task Packet: Minimal playlists — create, add, play, delete

**Packet ID:** 03-004-playlists
**Phase:** 3
**Created:** 2026-05-18
**Status:** READY
**Auto-proceed:** true
**High-risk:** false

## Goal

Cross-concert playlists — the predecessor app has none and the user cares
(`development_roadmap.md` Phase 3, `IDEA.md`). A playlist is an ordered list of tracks
with a name, backed by the tag-first model (`02-DATA-MODEL.md` § 5: "a playlist is an
ordered pair-list with a name tag"). Minimal: create, add tracks, view, play, reorder,
remove tracks, delete playlist. No backend changes.

## Acceptance criteria

- [ ] New `playlist_items` table in `SQLiteLibraryRepository` schema:
      `(playlist_id TEXT, recording_identifier TEXT, track_filename TEXT,
      stream_url TEXT, track_title TEXT, track_duration TEXT, track_index INT,
      sort_order INT, concert_id TEXT, artist TEXT, date TEXT, venue TEXT,
      PRIMARY KEY (playlist_id, sort_order))`. Stores enough data to display and play
      without a network call.
- [ ] `LibraryRepository` gains playlist methods:
      `createPlaylist(name:) async throws -> Tag`,
      `deletePlaylist(id:) async throws`,
      `renamePlaylist(id:name:) async throws`,
      `playlistTags() async -> [Tag]`,
      `playlistItems(for:) async -> [PlaylistItem]`,
      `addToPlaylist(id:items:) async throws`,
      `removeFromPlaylist(id:at:) async throws`,
      `moveInPlaylist(id:from:to:) async throws`.
- [ ] `PlaylistItem` struct: `id` (UUID), `track` info (title, filename, duration,
      streamURL), recording identifier, concert context (id, artist, date, venue).
      Enough to feed `PlaybackCoordinator.play()` and display a row.
- [ ] `InMemoryLibraryRepository` implements all playlist methods (test support).
- [ ] `SQLiteLibraryRepository` implements all playlist methods with parameterized SQL.
- [ ] `ConcertDetailView` track context menu gains "Add to Playlist..." that presents a
      sheet listing existing playlists + "New Playlist..." option. Recording-level header
      menu gains the same. Tapping a playlist adds the track(s); tapping "New Playlist..."
      prompts for a name, creates the playlist, then adds the track(s).
- [ ] `LibraryTab` shows a "Playlists" section (below Favorites) listing user playlists
      by name. Tapping navigates to a `PlaylistDetailView`. Empty state when no
      playlists exist.
- [ ] `PlaylistDetailView`: shows ordered tracks with concert context (artist, date),
      tap-to-play (plays the full playlist starting at that track via
      `PlaybackCoordinator.play()`), swipe-to-delete, drag-to-reorder, toolbar button to
      delete the playlist (with confirmation). Toolbar button to rename.
- [ ] BUILD SUCCEEDED with zero errors. Existing tests still pass. New tests pass.

## Read first

> Floor (CLAUDE.md, CONVENTIONS.md, this packet) not relisted.

- `TapeScrape/Repositories/LibraryRepository.swift` — the protocol being extended;
  `ConcertSnapshot`, `InMemoryLibraryRepository`, environment key
- `TapeScrape/Repositories/SQLiteLibraryRepository.swift` — persistence layer being
  extended; understand the sqlite3 C API patterns, `SQLITE_TRANSIENT`, `exec` helper
- `TapeScrape/Models/Tag.swift` — `Tag`, `TagKind` (`.playlist` already exists),
  `TaggedItem`
- `TapeScrape/Playback/PlaybackCoordinator.swift` — `play(_:startingAt:concert:)` and
  `QueueItem` / `ConcertContext` to understand how playlist playback feeds in
- `TapeScrape/Views/ConcertDetailView.swift` — existing context menus to extend
- `TapeScrape/Views/LibraryTab.swift` — where playlists section is added
- `TapeScrape/Models/Concert.swift` — `TrackResponse` shape (what playlist items store)
- `docs/design/02-DATA-MODEL.md` § 5 — tag-first schema design for playlists

## Files expected to change

- `TapeScrape/Models/Tag.swift` — add `PlaylistItem` struct
- `TapeScrape/Repositories/LibraryRepository.swift` — add playlist methods to protocol;
  implement in `InMemoryLibraryRepository`
- `TapeScrape/Repositories/SQLiteLibraryRepository.swift` — `playlist_items` table
  creation; implement playlist methods
- `TapeScrape/Views/LibraryTab.swift` — playlists section, navigation to detail
- `TapeScrape/Views/ConcertDetailView.swift` — "Add to Playlist..." in context menus
- `TapeScrape/Views/PlaylistDetailView.swift` — **new file**: ordered track list with
  play/reorder/delete

## Interface sketch

```swift
// Tag.swift — new struct
struct PlaylistItem: Identifiable {
    let id: UUID
    let recordingIdentifier: String
    let trackFilename: String
    let streamURL: String
    let trackTitle: String?
    let trackDuration: String?
    let trackIndex: Int
    let sortOrder: Int
    // Concert context for display and playback history
    let concertID: String?
    let artist: String?
    let date: String?
    let venue: String?
}

// LibraryRepository.swift — additions to protocol
protocol LibraryRepository: Sendable {
    // ... existing ...

    // Playlists
    func createPlaylist(name: String) async throws -> Tag
    func deletePlaylist(id: Tag.ID) async throws
    func renamePlaylist(id: Tag.ID, name: String) async throws
    func playlistTags() async -> [Tag]
    func playlistItems(for playlistID: Tag.ID) async -> [PlaylistItem]
    func addToPlaylist(id: Tag.ID, items: [PlaylistItem]) async throws
    func removeFromPlaylist(id: Tag.ID, at sortOrder: Int) async throws
    func moveInPlaylist(id: Tag.ID, from: Int, to: Int) async throws
}

// PlaylistDetailView.swift — new view
struct PlaylistDetailView: View {
    let playlistID: Tag.ID
    let playlistName: String
    // Loads items from LibraryRepository, plays via PlaybackCoordinator
}

// ConcertDetailView.swift — "Add to Playlist..." sheet
struct AddToPlaylistSheet: View {
    let tracks: [TrackResponse]
    let recordingIdentifier: String
    let concert: ConcertDetailResponse
    // Lists existing playlists + "New Playlist..." row
}
```

## Constraints to preserve

- See `workflow/CONVENTIONS.md` and `CLAUDE.md` § "Core constraints" (always applicable)
- Library/playlist data is **client-side only** — no backend changes
- All persistence through repository protocols — no raw SQLite in feature code
- `PlaybackCoordinator` API unchanged — playlists feed tracks through existing
  `play(_:startingAt:concert:)` or `addToEnd`
- `TagKind.playlist` is the kind for playlist tags — use the existing tag-first model
- Playlist items store enough data to display and play without a network call
  (denormalized, like `ConcertSnapshot` for favorites)
- All SQL is parameterized (no string interpolation)

## Tests

- REQUIRED
- `TapeScrapeTests/Repositories/LibraryRepositoryTests.swift` (new or extend existing):
  - `createPlaylist` creates a tag with `.playlist` kind
  - `playlistTags` returns only playlist-kind tags
  - `addToPlaylist` + `playlistItems` round-trips items in order
  - `removeFromPlaylist` removes the item and adjusts ordering
  - `moveInPlaylist` reorders correctly
  - `deletePlaylist` removes the tag and all its items
  - `renamePlaylist` updates the tag name
- Test against `InMemoryLibraryRepository` (unit) and/or `SQLiteLibraryRepository`
  (integration, in-memory `:memory:` DB or temp file)

## Known ambiguities / open questions

- **Playlist item identity for playback.** A playlist item stores `streamURL` +
  `trackFilename` + `recordingIdentifier` — enough to construct a `TrackResponse` and
  `ConcertContext` for `PlaybackCoordinator.play()`. The `streamURL` may become stale if
  IA changes URLs, but this is the same risk as favorites displaying cached data — the
  stream URL comes from the backend and is treated as opaque. Acceptable at v1 scale;
  a "refresh URLs" action could be added later.
- **Sort order management.** `removeFromPlaylist` and `moveInPlaylist` require updating
  `sort_order` values in SQLite. Simplest approach: on remove, decrement all sort_orders
  above the removed index; on move, rewrite sort_orders for the affected range. This is
  fine for playlists of reasonable length (hundreds of items max).
- **"Add to Playlist" UX.** A sheet with a list of playlists + "New Playlist..." row.
  Creating a new playlist inline uses a simple `TextField` + `Button` or an alert with
  a text field. Implementer's call on exact UX — keep it simple.

## Out of scope

- "Save queue as playlist" — stretch goal, separate packet if wanted
- Smart collections / saved queries
- Playlist cover art or thumbnails (Phase 5)
- Playlist sharing or export
- Playlist track deduplication (user can add the same track twice — intentional for
  set-list flexibility)
- Playlist limits or pagination (reasonable at personal-use scale)
- Offline playlist tracks (Phase 4 downloads)
- Reordering playlists themselves in LibraryTab (alphabetical is fine for v1)

## Summary output path

`workflow/packets/03-004-playlists.summary.md`
