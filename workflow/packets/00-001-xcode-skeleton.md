# Task Packet: Xcode project skeleton

**Packet ID:** 00-001-xcode-skeleton
**Phase:** 0
**Created:** 2026-05-16
**Status:** READY
**Auto-proceed:** true
**High-risk:** false

## Goal

Create the Xcode project and SwiftUI app that builds and runs on a real iPhone. Three-tab
shell (Home / Search / Library) with stub views. This is the container everything else
lands in.

## Acceptance criteria

- [ ] Xcode project exists at repo root, targets iOS 17+, iPhone only
- [ ] App launches and displays a bottom tab bar with three tabs: Home, Search, Library
- [ ] Each tab shows a distinct placeholder view (title label minimum)
- [ ] Project builds with zero warnings on Xcode 16 / Swift 6 (strict concurrency off for now — revisit Phase 2)
- [ ] App runs on a physical device (the user's iPhone)

## Read first

- `docs/design/03-CLIENT-AND-PLAYBACK.md` § 1–2 — platform, app structure, tab layout

## Files expected to change

- `TapeScrape.xcodeproj/` — new Xcode project (created)
- `TapeScrape/TapeScrapeApp.swift` — app entry point with tab view
- `TapeScrape/Views/HomeTab.swift` — stub
- `TapeScrape/Views/SearchTab.swift` — stub
- `TapeScrape/Views/LibraryTab.swift` — stub
- `TapeScrape/Assets.xcassets/` — default asset catalog

## Constraints to preserve

- See `workflow/CONVENTIONS.md` (always applicable)
- See `CLAUDE.md` § "Core constraints" (always applicable)
- iOS 17 deployment target (D1 resolved)
- No navigation beyond the tab shell — resist designing the navigation graph

## Tests

- NONE — the skeleton has no logic to test. Swift unit/UI test targets are created but
  empty, ready for future packets.

## Known ambiguities / open questions

- none

## Out of scope

- The four hooks (AudioStorage, URL scheme, tag-first library, repositories) — packet `00-002`
- Any backend code — packet `00-003`
- Navigation within tabs, real screens, data models
- App icon, launch screen polish
- Swift strict concurrency (`Sendable` conformance audit) — revisit when playback logic exists
- SwiftData / persistence setup

## Summary output path

`workflow/packets/00-001-xcode-skeleton.summary.md`
