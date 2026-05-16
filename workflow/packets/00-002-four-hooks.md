# Task Packet: Install the four forward-compatibility hooks

**Packet ID:** 00-002-four-hooks
**Phase:** 0
**Created:** 2026-05-16
**Status:** READY
**Auto-proceed:** true
**High-risk:** false

## Goal

Install the four forward-compatibility hooks from `00-ARCHITECTURE.md` § 3 with trivial
default implementations. After this packet, all future code that touches audio storage,
navigation, library data, or persistence goes through these seams — not around them.

## Acceptance criteria

- [ ] `AudioStorage` protocol exists with `url(for:file:)`, `store(_:identifier:file:)`,
      `delete(identifier:file:)`, `usage()` shape; a `DocumentsAudioStorage` default impl
      writes to `Documents/Recordings/<identifier>/<file>`
- [ ] `tapescrape://` URL scheme registered in Info.plist; a `DeepLinkRouter` resolves
      `tapescrape://concert/<id>` and `tapescrape://recording/<identifier>` to navigation
      actions (stub: prints/logs, no real navigation yet)
- [ ] A `Tag` model and `LibraryRepository` protocol exist expressing the tag-first
      library concept (favorites, playlists as tags); implementation is an in-memory stub
- [ ] Repository protocols declared: `LibraryRepository`, `PlaybackHistoryRepository`;
      trivial in-memory default implementations
- [ ] The app still builds and runs (tabs unchanged)

## Read first

- `docs/design/00-ARCHITECTURE.md` § 3 — the four hooks specification
- `docs/design/03-CLIENT-AND-PLAYBACK.md` § 3 — hooks in practice (client-side)
- `docs/design/02-DATA-MODEL.md` § 5 — tag-first library model

## Files expected to change

- `TapeScrape/Storage/AudioStorage.swift` — protocol + `DocumentsAudioStorage`
- `TapeScrape/Navigation/DeepLinkRouter.swift` — URL scheme routing
- `TapeScrape/Models/Tag.swift` — tag model
- `TapeScrape/Repositories/LibraryRepository.swift` — protocol + in-memory stub
- `TapeScrape/Repositories/PlaybackHistoryRepository.swift` — protocol + in-memory stub
- `TapeScrape/TapeScrapeApp.swift` — wire URL scheme handler (`onOpenURL`)
- `TapeScrape/Info.plist` or project settings — register `tapescrape://` scheme

## Interface sketch

```swift
// AudioStorage.swift
protocol AudioStorage {
    func url(for identifier: String, file: String) -> URL?
    func store(_ data: Data, identifier: String, file: String) throws
    func delete(identifier: String, file: String) throws
    func usage() throws -> UInt64  // bytes
}

// Tag.swift
struct Tag: Identifiable, Codable {
    let id: UUID
    var name: String        // e.g. "favorite", playlist name
    var kind: TagKind       // .favorite, .playlist, .smart, .user
}

enum TagKind: String, Codable {
    case favorite, playlist, smart, user
}

// LibraryRepository.swift
protocol LibraryRepository {
    func tags() async -> [Tag]
    func addTag(_ tag: Tag) async throws
    func removeTag(_ id: Tag.ID) async throws
    func items(for tag: Tag.ID) async -> [TaggedItem]
    func tagItem(_ itemID: String, with tagID: Tag.ID) async throws
    func untagItem(_ itemID: String, from tagID: Tag.ID) async throws
}

// PlaybackHistoryRepository.swift
protocol PlaybackHistoryRepository {
    func recordPlay(identifier: String, trackFile: String, at: Date) async throws
    func recentPlays(limit: Int) async -> [PlayRecord]
}

// DeepLinkRouter.swift
struct DeepLinkRouter {
    enum Destination {
        case concert(id: String)
        case recording(identifier: String)
    }
    func resolve(_ url: URL) -> Destination?
}
```

## Constraints to preserve

- See `workflow/CONVENTIONS.md` (always applicable)
- See `CLAUDE.md` § "Core constraints" (always applicable)
- These are **passive hooks** — shape how code is organized, not what gets built. Trivial
  defaults only; no real persistence, no real navigation, no App Group.
- Do NOT add modularity beyond these four hooks (over-architecture risk)

## Tests

- REQUIRED
- `TapeScrapeTests/Storage/AudioStorageTests.swift` — test `DocumentsAudioStorage`
  store/retrieve/delete round-trip (use a temp directory)
- `TapeScrapeTests/Navigation/DeepLinkRouterTests.swift` — test URL parsing for both
  route shapes + unknown URLs return nil

## Known ambiguities / open questions

- The exact `TaggedItem` shape (what fields identify a concert vs recording vs track)
  will solidify in Phase 1 when real data arrives. For now a `String` itemID suffices.
- `PlaybackHistoryRepository` may gain fields (duration listened, position) in Phase 2;
  the protocol can evolve.

## Out of scope

- Real persistence (SwiftData/SQLite) behind repositories — that's Phase 1+
- Real navigation (pushing screens from deep links) — that's Phase 1+
- Download manager, PlaybackCoordinator — later packets
- CoverRenderer protocol — Phase 5
- App Group entitlement, IPC, plugin system
- Any backend code

## Summary output path

`workflow/packets/00-002-four-hooks.summary.md`
