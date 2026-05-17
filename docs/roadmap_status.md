# Roadmap Status

The development journal. Current phase, per-deliverable status, deviations, and
blockers/open decisions. Owned by the manager loop in the slimmed workflow (see
`workflow/WORKFLOW.md`). One to three lines per entry; link to packets/summaries for
detail rather than duplicating.

This is the working surface read at the start of every session to know where things
stand. It is *not* an architecture doc — that's `docs/design/`; not sequencing — that's
`docs/development_roadmap.md`.

---

## Current state

- **Phase:** 2 — planning (2026-05-17). Phase 1 COMPLETE + reviewed.
- **Repo:** Phase 1 complete. One concert (GD 1977-05-08) streams end-to-end: backend fetches/caches IA metadata, client plays audio directly from archive.org.
- **Next action:** Write Phase 2 packet `02-001` (backend artist search → recordings + canonical artist key). Review-gated fix `01.5-001` is COMPLETE — parallel aggregation is unblocked.
- **Phase 2 decisions (2026-05-17):** D2b backend host → *consciously deferred*, stay local through Phase 2 (revisit trigger: first off-home-Wi-Fi need). Re-aggregation trigger → on-demand-when-stale. See `docs/design/04-OPEN-QUESTIONS.md`.

### Phase 0 packet plan

| Packet | Deliverable | Status |
|---|---|---|
| `00-001-xcode-skeleton` | Xcode project, SwiftUI app target, bottom-tab shell (Home/Search/Library stubs), runs on device | COMPLETE |
| `00-002-four-hooks` | AudioStorage protocol, tapescrape:// URL scheme + router, tag-first library model, repository protocols — trivial defaults only | COMPLETE |
| `00-003-backend-hello` | FastAPI project skeleton, one stub route, local uvicorn, core/ module structure | COMPLETE |
| `00-004-phase1-slice` | Agree the Phase-1 vertical slice (one concert, one screen, one stream) | COMPLETE (decision: GD 1977-05-08 Cornell '77 as fixed test concert; app is artist-agnostic) |

### Phase 1 packet plan

| Packet | Deliverable | Status |
|---|---|---|
| `01-001-ia-metadata` | IA client calls (Advanced Search + Metadata) for one known concert, typed models, response parsing, recorded test fixtures | COMPLETE |
| `01-002-concert-endpoint` | `/concerts/{id}` endpoint returning parsed recordings + tracks for the test concert; persistent cache wired | COMPLETE |
| `01-003-client-playback` | Client screen showing recordings/tracks for the test concert; tap a track → AVPlayer streams from IA | COMPLETE |

### Phase 2 packet plan

Sequenced loosely (roadmap warns against over-speccing); only the first packet is firm.
Aggregation packets depend on the fix packet landing first.

| Packet | Deliverable | Status |
|---|---|---|
| `01.5-001-iaclient-di` | Single `IAClient` via FastAPI lifespan + DI; non-serializing rate limiter (closes F1-2, F1-5/F0-2). Prerequisite for parallel aggregation | COMPLETE |
| `02-001-artist-search` | Backend: `GET /search?type=artist` + canonical artist key + search cache | READY |
| `02-002` (tentative) | Backend: aggregation (venue clustering, concert key, persist, preferred pick) | not written |
| `02-003` (tentative) | Backend: `/concerts?artist=` list endpoint + on-demand-when-stale re-aggregation | not written |
| `02-004+` (tentative) | Client: search screen, concert list, detail best-first, full-screen NowPlaying, playback state machine | not written |

## Phase status

| Phase | Status | Notes |
|---|---|---|
| 0 — Set the stage | COMPLETE | all 4 packets done 2026-05-16; boundary review passed 2026-05-16 (1 blocking follow-up resolved: README updated) |
| 1 — One concert E2E | COMPLETE | started 2026-05-16; all 3 packets done 2026-05-16; boundary review passed 2026-05-16 (1 blocking follow-up: README update) |
| 2 — Browse/search/player | PLANNING | started 2026-05-17; decisions resolved (D2b deferred-local, re-aggregation on-demand-when-stale); first packet = review-gated fix `01.5-001` |
| 3 — Library/queue | NOT STARTED | |
| 4 — Downloads/offline | NOT STARTED | |
| 5 — Cover art | NOT STARTED | |
| 6 — Polish/TestFlight | NOT STARTED | |

## Deliverable log

One row per packet. **Status lifecycle is enforced** (`workflow/WORKFLOW.md`
§ "Discipline", `CLAUDE.md` § "Definition of done"):

`READY` (Packet creates) → `IN PROGRESS` (Build, before code) →
`COMPLETE | PARTIAL | BLOCKED` (Build, as its mandatory final step, copied from the
packet summary). A packet is not done until its row here matches its summary.

Scoped writes: **Build edits only its own row.** Phase status, the Blockers section, and
decision history are written by Review/Plan, never by Build. Format:

`| <packet-id> | <status> | <one-line outcome> | summary: <path> | deviations/follow-ups |`

| `00-001-xcode-skeleton` | COMPLETE | Xcode project, SwiftUI app target, three-tab shell (Home/Search/Library stubs) | summary: `workflow/packets/00-001-xcode-skeleton.summary.md` | — |
| `00-002-four-hooks` | COMPLETE | AudioStorage + DocumentsAudioStorage, DeepLinkRouter, Tag/LibraryRepository/PlaybackHistoryRepository stubs, tapescrape:// registered, 9 tests pass | summary: `workflow/packets/00-002-four-hooks.summary.md` | Info.plist properties must live in project.yml (XcodeGen overwrites direct edits); onOpenURL is a View modifier not Scene; test targets need GENERATE_INFOPLIST_FILE |
| `00-003-backend-hello` | COMPLETE | FastAPI app, /health route, core/{config,http_client,logging}.py, 1 test passes | summary: `workflow/packets/00-003-backend-hello.summary.md` | No editable install — pyproject.toml inside backend/ can't declare backend as a package; deps installed directly; run from repo root |
| `01-001-ia-metadata` | COMPLETE | ia/search.py + ia/metadata.py + models/ia.py; Ogg/Shorten filtered at parse; 10 tests pass (2 live_ia skipped); fixtures from real IA GD 1977-05-08 | summary: `workflow/packets/01-001-ia-metadata.summary.md` | Fixture identifier differs from packet spec (stream_only item returned {}; used aud.moore.berger.28354 instead); load_fixture in tests/helpers.py not conftest.py; IAItem.model_validate used end-to-end |
| `01-002-concert-endpoint` | COMPLETE | GET /concerts/{id} route; MetadataCache (sqlite3); ConcertResponse/RecordingResponse/TrackResponse; 24 tests pass (3 live_ia skipped); track dedup by format rank | summary: `workflow/packets/01-002-concert-endpoint.summary.md` | Tests patch _fetch_item rather than _cache+get_item_metadata separately (cleaner isolation); double-fetch of top item eliminated in route |
| `01-003-client-playback` | COMPLETE | CatalogClient actor; PlaybackCoordinator + PlayerBackend protocol; ConcertDetailView + MiniPlayerView; HomeTab fetches Cornell '77; AVAudioSession + UIBackgroundModes; 26 Swift tests pass | summary: `workflow/packets/01-003-client-playback.summary.md` | loading state is pass-through in Phase 1 (KVO observation Phase 2); PlayerBackend.replaceAndPlay(url:) keeps AVFoundation out of test mock |
| `01.5-001-iaclient-di` | COMPLETE | Single `IAClient` in FastAPI lifespan + `Depends`-injected; rate-limiter lock now O(1) (sleep+HTTP outside it); two module singletons removed; 28 pass + 3 live_ia skipped | summary: `workflow/packets/01.5-001-iaclient-di.summary.md` | Phase-1 lock spanned only `asyncio.sleep` (not HTTP) — fix + retuned concurrency test still apply; cache singleton (`concerts.py:15`) left as future fix per scope |
| `02-001-artist-search` | READY | `GET /search?type=artist` resolving messy IA `creator` → canonical artists; `aggregation/canonicalize.py`; `search_cache`; promote `get_ia_client` to `routes/deps.py` | summary: `workflow/packets/02-001-artist-search.summary.md` | — |

## Phase 1 boundary review (2026-05-16)

**Build checks:** `xcodebuild` BUILD SUCCEEDED (zero warnings), 26 Swift Testing tests
pass, `pytest backend/tests/` 24 passed + 3 skipped (live_ia). No linter configured yet.

**Cross-file consistency:** Module-level `IAClient` singletons in `ia/search.py` and
`ia/metadata.py` create two independent httpx clients — acceptable at Phase 1 scale, must
be injected via app lifespan before Phase 2. `CatalogClient.shared` on the Swift side is
the same pattern. `CONVENTIONS.md` §1 said `api/` but code uses `routes/` — fixed.
Backend response models and client Codable structs are in 1:1 alignment. No dead code, no
layering violations, no pattern drift across the three packets.

**Doc-to-code reconciliation:**

| Issue | Location | Verdict |
|---|---|---|
| README said "No streaming… features exist yet" | `README.md` | 🔴 **Code is right, doc is wrong.** Phase 1 streams. Fixed in this review. |
| CONVENTIONS §1 listed `api/` as route layer | `workflow/CONVENTIONS.md` | Fixed → `routes/`. |
| `03-CLIENT-AND-PLAYBACK.md` §2 lists future components | `docs/design/03-CLIENT-AND-PLAYBACK.md` | Future intent, not claims. Not a discrepancy. |
| `00-ARCHITECTURE.md` §2.1 mentions aggregation | `docs/design/00-ARCHITECTURE.md` | Phase 2 work; design describes intent. Fine. |

**Conventions formalized:** §12 (Pydantic response models), §13 (fixture-based
integration tests via TestClient), §14 (PlayerBackend protocol for testable playback).

**Follow-ups:**

| # | Item | Urgency | Notes |
|---|---|---|---|
| F1-1 | Update `README.md` to reflect Phase 1 completion | 🔴 blocking | Fixed in this review |
| F1-2 | Inject `IAClient` via FastAPI lifespan + DI (eliminate module-level singletons) | 🟡 important | Two independent httpx clients; fix before Phase 2 parallel aggregation |
| F1-3 | Fix `makeTrack` test helper URL interpolation (`\(0)` → `\(index)`) | 🟢 optional | Tests pass; cosmetic |
| F1-4 | Replace deprecated `Color.accentColor` with `.tint` in `ConcertDetailView` | 🟢 optional | Phase 6 polish |
| F1-5 | F0-2 still open: `IAClient._lock` held across HTTP call serializes concurrent requests | 🟡 important | Fix before Phase 2 (same deadline as F1-2) |

---

## Phase 0 boundary review (2026-05-16)

**Build checks:** `xcodebuild` BUILD SUCCEEDED (zero warnings), 9 Swift Testing tests
pass, `pytest backend/tests/` 1 test passes. No linter configured yet.

**Cross-file consistency:** No pattern drift — only 3 packets of implementation. Actor
stubs, Swift Testing, and XcodeGen usage are consistent across the two client packets.
No dead code. No layering violations.

**Doc-to-code reconciliation:**

| Issue | Location | Verdict |
|---|---|---|
| README claims "pre-implementation… no Xcode project and no backend code yet" | `README.md` lines 12–17 | 🔴 **Code is right, doc is wrong.** Phase 0 is complete; README must be updated. |
| CONVENTIONS §1 was marked "starter — unverified" | `workflow/CONVENTIONS.md` | Fixed in this review — module boundaries confirmed by shipped code. |
| CONVENTIONS §6 still "starter — unverified" (error handling) | `workflow/CONVENTIONS.md` | Left as-is — no error hierarchy shipped yet (Phase 1+ work). |
| `00-ARCHITECTURE.md` §3 describes the four hooks | `docs/design/00-ARCHITECTURE.md` | Code matches. Routes, protocol shapes, tag model, repository protocols all align. |
| `03-CLIENT-AND-PLAYBACK.md` §2 lists `PlaybackCoordinator`, `DownloadManager`, `CoverRenderer`, `Catalog` repo | `docs/design/03-CLIENT-AND-PLAYBACK.md` | These are future — doc describes intent, not current state. Not a discrepancy (the roadmap doesn't claim they exist yet). |

**Follow-ups:**

| # | Item | Urgency | Notes |
|---|---|---|---|
| F0-1 | Update `README.md` to reflect Phase 0 completion (remove "pre-implementation" language, add "Getting started" with actual build instructions) | 🔴 blocking | README claiming nonexistent state is the explicit anti-pattern from `IDEA.md` |
| F0-2 | `IAClient` rate limiter holds the lock across `asyncio.sleep` + the HTTP call; concurrent callers serialize unnecessarily | 🟡 important | Fine at single-user Phase 1 scale; fix before Phase 2 parallel aggregation |
| F0-3 | Add explicit `Sendable` conformance to `Tag`, `TaggedItem`, `PlayRecord` before enabling strict concurrency | 🟢 optional | Implicitly Sendable now; explicit conformance prevents future warnings |
| F0-4 | `AudioStorage.url(for:file:)` always returns non-nil (constructs path regardless of file existence); callers must check `fileExists` separately | 🟢 optional | Acceptable API shape for download-target use; note for Phase 4 |

## Blockers / open decisions

Mirror of the actionable items in `docs/design/04-OPEN-QUESTIONS.md` — the design doc is
authoritative; this is the at-a-glance tracker.

- ~~**D1 (minimum iOS)**~~ — RESOLVED 2026-05-16: iOS 17.
- ~~**Setlist source**~~ — RESOLVED 2026-05-16: IA-description parse only for v1; revisit
  only if insufficient in use.
- ~~**D2b (backend host)**~~ — RESOLVED 2026-05-17: consciously deferred — stay local
  through Phase 2; revisit trigger = first off-home-Wi-Fi need. No backend code depends
  on it. See `docs/design/04-OPEN-QUESTIONS.md`.
- **D3 (CloudKit vs local)** — user input, by Phase 3. Default local-only.
- **Library subset depth** — user input, by Phase 3. Default favorites + minimal
  playlists.
- ~~**Re-aggregation trigger**~~ — RESOLVED 2026-05-17: on-demand-when-stale
  (re-aggregate an artist on browse iff its persisted aggregation is older than a
  configurable TTL). See `docs/design/04-OPEN-QUESTIONS.md` ambiguity 4.
- **D6 (cover-art look)** — user reference points, by Phase 5.
- **"Two builds"** — user, by Phase 6; only if review rejects a downloads-capable build.

## Decision history

- **2026-05-16** — D2 thin FastAPI backend; D2d scoped track search; D5 unified library;
  D7 Python+FastAPI+SQLite; spec = focused design package; workflow = slimmed solo loop.
  Resolved with the user before the spec was written.
- **2026-05-16 (follow-up)** — D1 confirmed iOS 17 (no older-device requirement);
  setlist source confirmed IA-description-only for v1. Phase 0 fully unblocked. See
  `docs/design/04-OPEN-QUESTIONS.md` § Resolved.
- **2026-05-17 (Phase 2 planning)** — D2b backend host *consciously deferred* (user):
  stay on local `uvicorn` through Phase 2; revisit trigger = first off-home-Wi-Fi need.
  Re-aggregation trigger resolved on-demand-when-stale (orchestrator, user-confirmed).
  First Phase 2 packet is the review-gated fix `01.5-001-iaclient-di` (F1-2 + F1-5/F0-2).
