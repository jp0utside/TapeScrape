# Summary: 00-002-four-hooks

**Status:** Complete  
**Date:** 2026-05-16

## What was delivered

All four forward-compatibility hooks installed with trivial default implementations:

1. **`AudioStorage` protocol** (`TapeScrape/Storage/AudioStorage.swift`)  
   Protocol with `url(for:file:)`, `store(_:identifier:file:)`, `delete(identifier:file:)`, `usage()`.  
   `DocumentsAudioStorage` default impl writes to `Documents/Recordings/<identifier>/<file>`.

2. **`tapescrape://` URL scheme** (`TapeScrape/Navigation/DeepLinkRouter.swift`, `Info.plist`)  
   Scheme registered via `project.yml` (XcodeGen manages Info.plist — direct edits are overwritten on `xcodegen generate`).  
   `DeepLinkRouter` resolves `tapescrape://concert/<id>` and `tapescrape://recording/<identifier>`; unknown routes return `nil`. Wired via `.onOpenURL` on `ContentView` (must be on a `View`, not a `Scene`).

3. **Tag-first library model** (`TapeScrape/Models/Tag.swift`)  
   `Tag` (Identifiable, Codable), `TagKind` enum (favorite/playlist/smart/user), `TaggedItem` with `tagID` + `itemID: String`.

4. **Repository pattern** (`TapeScrape/Repositories/`)  
   `LibraryRepository` protocol + `InMemoryLibraryRepository` actor stub.  
   `PlaybackHistoryRepository` protocol + `InMemoryPlaybackHistoryRepository` actor stub with `PlayRecord`.

## Tests

9 tests, all passing:
- `AudioStorageTests`: store/retrieve, delete, usage-zero-when-empty, usage-reflects-stored-bytes
- `DeepLinkRouterTests`: concert route, recording route, unknown host → nil, wrong scheme → nil, missing path → nil

## Deviations

- **`project.yml` is the canonical home for Info.plist properties**, not `Info.plist` directly. XcodeGen regenerates Info.plist on every `xcodegen generate` run, overwriting direct edits. The `tapescrape://` URL type was added to `project.yml → info.properties`.
- **`GENERATE_INFOPLIST_FILE: YES`** added to `TapeScrapeTests` and `TapeScrapeUITests` targets in `project.yml` — test targets had no Info.plist and code signing was failing.
- **`onOpenURL` is a view modifier** (on `ContentView`), not a scene modifier. Placing it on `WindowGroup` is a compile error in iOS 17 SwiftUI.

## Notes

- In-memory stubs use Swift actors for safe concurrent access, consistent with async protocol requirements.
- `DocumentsAudioStorage.root` is `internal` (not `private`) to allow test injection of a temp directory without a separate initializer parameter being needed in tests.
