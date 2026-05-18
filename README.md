# TapeScrape

A personal, native-iPhone app for browsing, streaming, downloading, and re-listening to
live-music recordings from the Internet Archive `etree` collection — with a library that
feels like a record collection.

It aggregates the many individual taper uploads of a show into a single **concert** with
a preferred default recording (tap to play, no version-picker gate), a real full-screen
player with legible playback state, first-class offline downloads, and a tag-first
library. Personal-use first; not an AI project at v1.

> **Status: Phase 2 complete (browse, search, and a real player).** You can search for
> an artist, browse that artist's concerts as a paginated list, open a concert, and play
> through a recording like a real music app. The FastAPI backend canonicalizes messy IA
> `creator`/venue strings, aggregates the many taper uploads of a show into persisted
> canonical concerts (SQLite) with a computed preferred recording, and serves paginated
> list/detail with opaque stream URLs; aggregation runs on-demand when an artist's data
> is stale. The iOS client has a debounced artist search, concert list/detail, sequential
> in-recording playback with a full-screen NowPlaying view (scrubber, track list),
> mini-player, lock-screen / Control Center controls, and a legible playback state
> machine (loading/stalled/failed with retry — no silent hangs). Not yet: a persisted
> library/favorites, offline downloads, real cover art, and global track search. This
> README describes only what is shipped; the predecessor (`set-scrape`) shipped a README
> claiming features that didn't exist, and avoiding that is an explicit project rule.

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

**Prerequisites:** Python 3.12+, Xcode 16+, XcodeGen (`brew install xcodegen`), a
physical iPhone (iOS 17+) or simulator, and your Mac on the same Wi-Fi as the phone.

### 1. Backend

From the repo root:

```bash
pip install fastapi uvicorn[standard] httpx pydantic pydantic-settings
uvicorn backend.main:app --reload
```

The backend runs on `http://localhost:8000`. Verify with:

```bash
curl http://localhost:8000/health
```

### 2. iOS app

```bash
xcodegen generate          # regenerate .xcodeproj from project.yml
open TapeScrape.xcodeproj
```

In Xcode: select your device or simulator, set your signing team under
**TapeScrape target > Signing & Capabilities**, and run.

### 3. Connecting the phone to the backend

The app defaults to `http://localhost:8000`, which works on simulators. On a **physical
device**, the phone must reach your Mac's local IP. Find it with:

```bash
ipconfig getifaddr en0      # Wi-Fi IP, e.g. 192.168.1.42
```

Then either:

- **Quick (code change):** Edit `CatalogClient.swift` line 10 — change `localhost` to
  your Mac's IP (e.g. `http://192.168.1.42:8000`). Don't commit this.
- **Proper (environment):** Set `TAPESCRAPE_BASE_URL` before launching uvicorn — the
  client-side URL is currently hardcoded, so for now use the code change above.

Make sure your Mac's firewall allows incoming connections on port 8000, and that both
devices are on the same Wi-Fi network.

## Manual testing guide

### Smoke test (backend only)

```bash
# Health check
curl http://localhost:8000/health

# Artist search — should return canonical artist matches from IA
curl 'http://localhost:8000/search?type=artist&q=grateful+dead'

# Concert list — uses the canonical artist key from search results
curl 'http://localhost:8000/concerts?artist=Grateful+Dead'

# Concert detail — use an id from the list response
curl 'http://localhost:8000/concerts/<concert-id>'
```

Expect: search returns artist names with `canonical_key`; concert list is paginated with
`total`/`page`/`page_size`; detail includes recordings sorted best-first with
`stream_url` pointing to `archive.org`.

### End-to-end (phone or simulator)

1. **Launch the backend** (`uvicorn backend.main:app --reload`).
2. **Run the app** on simulator or device.
3. **Search tab:** type an artist name (e.g. "Grateful Dead"). Results should appear
   after a short debounce. Try partial names, misspellings, lesser-known artists.
4. **Concert list:** tap an artist. Expect a paginated list of concerts with dates and
   venues. Scroll to "Load more" if there are multiple pages.
5. **Concert detail:** tap a concert. Expect recordings sorted by quality (SBD > AUD),
   each with a track list showing titles/durations and stream URLs.
6. **Playback:** tap a track. Expect:
   - Mini-player appears at the bottom with play/pause, track title, artist.
   - Audio streams from IA (may take a few seconds on first load).
   - Tap the mini-player to open the full-screen NowPlaying view.
7. **NowPlaying:** verify scrubber, track list, skip forward/back, play/pause. Lock the
   phone — lock-screen controls should work.
8. **Queue/auto-advance:** let a track finish. The next track in the recording should
   start automatically.
9. **Error states:** kill the backend mid-stream. The player should show a
   stalled/failed state with a retry button, not hang silently. Restart the backend and
   tap retry.
10. **Home tab:** should show Grateful Dead concerts (navigates to the concert list).

### What to watch for

- **Streaming latency:** first-track load under ~5s on Wi-Fi is normal for IA. If it
  hangs indefinitely, check the backend logs for IA errors.
- **Missing tracks:** if a concert shows 0 tracks for a recording, it may be an
  IA item with only non-playable formats (Ogg/Shorten are filtered at parse).
- **Aggregation delay:** the first request for an artist triggers a full IA aggregation
  (search + metadata fetch for sampled items). This can take 10-30s depending on the
  artist's catalog size. Subsequent requests within the staleness window (~1 hour) are
  instant from cache.
- **504 timeout:** if aggregation takes >30s the backend returns 504. Try again — IA may
  have been slow. Artists with very large catalogs (1000+ items) may hit this
  consistently; that's a known limitation at current page size (50 items).

## Automated tests

```bash
python -m pytest backend/tests/          # backend (no live IA calls by default)
xcodebuild test -project TapeScrape.xcodeproj -scheme TapeScrape \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Live IA tests (optional, requires network): `python -m pytest -m live_ia backend/tests/`
