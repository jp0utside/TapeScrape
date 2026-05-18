# Implementation Summary: 03-004-playlists

**Status:** COMPLETE
**Date:** 2026-05-18

## What shipped

- `PlaylistItem` struct (`Identifiable`, `Sendable`) added to `Tag.swift`; `Tag` and `TagKind` gained `Hashable` conformance (required for `NavigationLink(value:)`)
- `LibraryRepository` protocol extended with 8 playlist methods: `createPlaylist`, `deletePlaylist`, `renamePlaylist`, `playlistTags`, `playlistItems(for:)`, `addToPlaylist`, `removeFromPlaylist`, `moveInPlaylist`
- `InMemoryLibraryRepository` implements all playlist methods; uses a `storedPlaylistItems: [Tag.ID: [PlaylistItem]]` dict; `renumbered()` helper maintains contiguous sort_orders after remove/move
- `SQLiteLibraryRepository`: `playlist_items` table added to schema (`CREATE TABLE IF NOT EXISTS`); all 8 playlist methods implemented using `fetchPlaylistItems`, `insertPlaylistItem`, `rewritePlaylistItems` private helpers; `rewritePlaylistItems` (delete-all + re-insert) is used for move/remove to sidestep PK conflict ordering in SQLite
- `ConcertDetailView`: track context menus gain "Add to Playlist..." (single track); recording section header menu gains "Add Recording to Playlist..." (all recording tracks); both present `AddToPlaylistSheet`
- `AddToPlaylistSheet` (file-private in `ConcertDetailView.swift`): lists existing playlist tags + "New Playlist..." row; inline alert for new-playlist name entry; adds tracks and dismisses
- `PlaylistDetailView.swift` (new file): ordered track list with `ContentUnavailableView` empty state; tap-to-play via `PlaybackCoordinator.play()`; swipe-to-delete + drag-to-reorder via `.onDelete`/`.onMove`; toolbar `Menu` with Rename (alert) and Delete (confirmation dialog)
- `LibraryTab`: added `playlists: [Tag]` state; Playlists section (below Favorites); `ContentUnavailableView` shown only when both are empty; `navigationDestination(for: Tag.self)` navigates to `PlaylistDetailView`
- `xcodegen generate` run to include `PlaylistDetailView.swift` in project
- 14 new tests: 7 in `LibraryRepositoryTests` (InMemory unit), 7 in `SQLiteLibraryRepositoryTests` (integration); BUILD SUCCEEDED; 106 Swift tests pass

## Deviations

- `PlaylistItem.id` is not persisted in `playlist_items` (not in the packet's schema spec) — UUID() is generated on each DB load; stable within a view session, ephemeral across loads (acceptable: SwiftUI identity is session-scoped)
- `rewritePlaylistItems` (delete-all + re-insert) used for move/remove instead of in-place SQL UPDATEs — avoids PK conflict ordering issues in SQLite; correct and safe at personal-use scale

## Status journal

- `docs/roadmap_status.md` row updated to COMPLETE.
