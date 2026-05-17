# TapeScrape

A personal, native-iPhone app for browsing, streaming, downloading, and re-listening to
live-music recordings from the Internet Archive `etree` collection — with a library that
feels like a record collection.

It aggregates the many individual taper uploads of a show into a single **concert** with
a preferred default recording (tap to play, no version-picker gate), a real full-screen
player with legible playback state, first-class offline downloads, and a tag-first
library. Personal-use first; not an AI project at v1.

> **Status: Phase 1 complete (one concert, end to end).** The app streams live audio
> from the Internet Archive for one hardcoded concert (GD 1977-05-08 Cornell '77). The
> FastAPI backend fetches and caches IA metadata, returns recordings and track lists with
> opaque stream URLs; the iOS client displays them and plays via AVPlayer directly from
> `archive.org`. Background audio, play/pause, and a mini-player bar work. No browsing,
> search, library, or download features exist yet. This README describes only what is
> shipped; the predecessor (`set-scrape`) shipped a README claiming features that didn't
> exist, and avoiding that is an explicit project rule.

## Architecture in one paragraph

A **thin Python/FastAPI backend** mediates Internet Archive *metadata* (search,
aggregation into canonical concerts, caching). A **native Swift/SwiftUI iOS client** is
the whole product experience. The client streams and downloads *audio* directly from
`archive.org`; the backend never touches audio bytes. See
`docs/design/00-ARCHITECTURE.md`.

## Map of the docs

| Path | What it is |
|---|---|
| `IDEA.md` | Motivation, requirements, the "why." Start here. |
| `docs/design/` | Architecture & behavior spec. `01-INTERNET-ARCHIVE.md` is the load-bearing one. |
| `docs/development_roadmap.md` | Phase sequencing (0 → 6), each phase usable on the phone. |
| `docs/roadmap_status.md` | Current progress, deviations, blockers. |
| `docs/design/04-OPEN-QUESTIONS.md` | The decision log (resolved / deferred / open). |
| `CLAUDE.md` | Hard constraints and the working protocol. |
| `workflow/` | The slimmed solo development loop. |

## Reference projects (read, don't extend)

- `/Users/Jake/Programs/set-scrape/` — paper prototype for the IA logic and data model.
  Its real implementation is distilled in `docs/design/01-INTERNET-ARCHIVE.md`.
- `/Users/Jake/Programs/tape_scrape/` — the prior planning set this spec is derived from.
- `/Users/Jake/Programs/setlist-ai/` — a separate Setlist.fm RAG project; no IA code.

## Getting started

**iOS app:** Open `TapeScrape.xcodeproj` in Xcode 16+, select an iPhone simulator or
device, and run. The project is generated from `project.yml` via XcodeGen — regenerate
with `xcodegen generate` after structural changes.

**Backend:** From the repo root:
```
pip install fastapi uvicorn[standard] httpx pydantic pydantic-settings
uvicorn backend.main:app --reload
```

**Tests:**
```
python -m pytest backend/tests/          # backend (no live IA calls)
xcodebuild test -project TapeScrape.xcodeproj -scheme TapeScrape \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```
