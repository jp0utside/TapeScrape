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

- **Phase:** 2 — COMPLETE + reviewed (2026-05-17). Phase 1 COMPLETE + reviewed.
- **Repo:** Phase 2 complete. Artist search → paginated concert list → concert detail → play-through with full-screen NowPlayer, lock-screen controls, and a legible playback state machine. Backend canonicalizes + aggregates IA into persisted SQLite concerts, on-demand-when-stale.
- **Next action:** Plan Phase 3 (library/queue) — **unblocked**: D3 and library-subset depth resolved 2026-05-18 (see below). First Plan step: decide whether 🟡 F2-2 (metadata-cache regression) is a Phase-3-opening fix packet or folded into early Phase 3 work; then write the first Phase 3 packet (smallest: favorite tag on concerts/recordings).
- **Phase 2 decisions (2026-05-17):** D2b backend host → *consciously deferred*, stay local through Phase 2 (revisit trigger: first off-home-Wi-Fi need). Re-aggregation trigger → on-demand-when-stale. See `docs/design/04-OPEN-QUESTIONS.md`.
- **Phase 3 decisions (2026-05-18):** D3 → **local-only v1** (CloudKit later, additive, no migration; revisit trigger = 2nd device / clean-reinstall resilience). Library subset → **favorites + minimal playlists** (defer smart collections / tag UI / notes). See `docs/design/04-OPEN-QUESTIONS.md`.

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
| `02-001-artist-search` | Backend: `GET /search?type=artist` + canonical artist key + search cache | COMPLETE |
| `02-002-concert-aggregation` | Backend: aggregation (venue clustering, concert key, persist, preferred pick) | COMPLETE |
| `02-003-concert-list-endpoint` | Backend: `/concerts?artist=` list + `/concerts/{id}` detail, on-demand-when-stale | COMPLETE |
| `02-004-client-search-browse` | Client: debounced artist search → concert list → detail | COMPLETE |
| `02-005-player-queue-nowplaying` | Client: queue, KVO state machine, full-screen NowPlaying, system integration | COMPLETE |

## Phase status

| Phase | Status | Notes |
|---|---|---|
| 0 — Set the stage | COMPLETE | all 4 packets done 2026-05-16; boundary review passed 2026-05-16 (1 blocking follow-up resolved: README updated) |
| 1 — One concert E2E | COMPLETE | started 2026-05-16; all 3 packets done 2026-05-16; boundary review passed 2026-05-16 (1 blocking follow-up: README update) |
| 2 — Browse/search/player | COMPLETE | all 6 packets done 2026-05-17 (`01.5-001`,`02-001`..`02-005`); boundary review passed 2026-05-17 (1 blocking follow-up resolved in-review: README; 4 🟡 debt follow-ups recorded) |
| 3 — Library/queue | NOT STARTED | gated on user decisions D3 + library-subset depth |
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
| `02-001-artist-search` | COMPLETE | `GET /search?type=artist` collapses messy IA `creator` → canonical artists; `aggregation/canonicalize.py` (pure, §5.1); `SearchCache`; `get_ia_client` promoted to `routes/deps.py`; concert/track → honest 501; 62 pass + 3 live_ia skipped | summary: `workflow/packets/02-001-artist-search.summary.md` | Dropped one off-spec HTML-entity test case; both caches now module-global in 2 places — natural trigger for the recorded app.state follow-up at Phase 2 review |
| `02-002-concert-aggregation` | COMPLETE | Aggregation engine: venue clustering (token-set 0.85), `SourceQuality` parsing (MTX>SBD>AUD>FM>UNKNOWN), concert grouping by `(artist,date,venue)`, UUID5 IDs, preferred-recording pick, SQLite persistence via `db/` package; 111 pass + 3 live_ia skipped | summary: `workflow/packets/02-002-concert-aggregation.summary.md` | MTX checked before SBD in regex chain; `audience` added to AUD pattern; `is_marker` track flag deferred to client packet |
| `02-003-concert-list-endpoint` | COMPLETE | `GET /concerts?artist=` paginated list + `GET /concerts/{id}` detail, both backed by persisted aggregation; on-demand-when-stale trigger with 30s timeout → 504; `ConcertListResponse`/`ConcertDetailResponse`; `source_quality` on `RecordingResponse`; `concerts_page_size` config; Phase 1 `_CONCERT_MAP` removed; 21 route tests + 122 suite-wide pass | summary: `workflow/packets/02-003-concert-list-endpoint.summary.md` | — |
| `02-004-client-search-browse` | COMPLETE | SearchTab with debounced artist search → ConcertListView (paginated, Load more) → ConcertDetailView; `CatalogClient` gains `searchArtists`/`getConcerts`/`getConcertDetail`; Swift models updated (`ConcertDetailResponse`, `ConcertListItem`, `ArtistMatch`); HomeTab updated to browse via GD concert list; BUILD SUCCEEDED, 31 Swift tests pass | summary: `workflow/packets/02-004-client-search-browse.summary.md` | `downloadCount` retained on wire (backend kept it); HomeTab navigates to GD concert list rather than directly to Cornell '77 |
| `02-005-player-queue-nowplaying` | COMPLETE | KVO-based state machine (loading/stalled/failed states); queue + sequential auto-advance; skipForward/skipBack (>3s restart convention); NowPlayingView (scrubber, track list, art placeholder); MPRemoteCommandCenter + MPNowPlayingInfoCenter; AVAudioSession interruption handling; BUILD SUCCEEDED, 53 Swift tests pass | summary: `workflow/packets/02-005-player-queue-nowplaying.summary.md` | Sendable warnings on AVPlayerBackend KVO closures (non-errors at minimal concurrency); `PlaybackError` moved to PlayerBackend.swift |

## Phase 2 boundary review (2026-05-17)

Scope: `01.5-001`, `02-001`, `02-002`, `02-003`, `02-004`, `02-005`.

**Build checks:** `pytest backend/tests/` → **122 passed, 2 skipped** (`live_ia`,
skipped by default; the count is 2 not 3 because `02-003` removed the Phase-1
slug route and its live test — legitimate, not a regression). `xcodebuild test`
→ **53 Swift Testing tests pass**, app build clean (only a benign AppIntents
metadata note; no Sendable warnings in the app build). No linter/type-checker in
CI; run ad hoc for the review: `ruff` → 13 trivial findings (unused imports +
1 f-string, all auto-fixable); `mypy` → 47 source files clean, 1 test-only
type error. Details in F2-6 / F2-8.

**Cross-file consistency:**

- 🟡 **Metadata caching regressed (dead code + design divergence).**
  `core/cache.py:7 MetadataCache` now has **no production caller**: Phase 1's
  `routes/concerts.py` used it; `02-003` rewrote that route and dropped it.
  `ia/metadata.py:5 get_item_metadata` does a bare `client.get(/metadata/..)`
  with no caching, and `orchestrate.py:63-68` calls it per sampled item on every
  stale re-aggregation. `00-ARCHITECTURE.md` §2.1 explicitly requires ~24 h
  persistent metadata caching ("IA is slow and rate-limited; one cache warmed
  once"). Code is wrong vs. design → F2-2.
- 🟡 **Two divergent audio-format policies.** Parse-time denylist
  `models/ia.py:3 _UNSUPPORTED_FORMATS={"Ogg Vorbis","Shorten"}` vs. aggregate-time
  allowlist `aggregate.py:23 _PLAYABLE_FORMATS`. The allowlist silently drops
  iOS-playable bitrate-labelled MP3s (e.g. "64Kbps MP3", "128Kbps MP3"). CLAUDE.md
  says drop unplayable formats *at parse* — one policy, one layer → F2-4.
- 🟡 **On-demand-when-stale decision duplicated.** `routes/concerts.py:84-96`
  checks `get_aggregation_age` then calls `aggregate_artist`, which re-checks
  staleness itself (`orchestrate.py:34-37`) and may return cached anyway. Two
  layers own the same rule; drift risk → F2-5.
- 🟡 **Silent IA failure.** `orchestrate.py:67 except Exception: continue` with
  no log — a flaky IA is invisible there; CLAUDE.md §Audit requires logging IA
  errors → F2-3.
- 🟢 The standing "module-global caches → `app.state`" item (noted in
  `01.5-001`/`02-001`) has partly dissolved: the `MetadataCache` global is gone
  (concerts.py rewritten); only `routes/search.py:22 _cache = SearchCache(...)`
  remains. Downgraded to 🟢, fold into F2-2 if metadata caching is rewired.
- 🟢 API naming drift: `ConcertListItem` exposes `display_artist`/`display_venue`;
  `ConcertDetailResponse` exposes `artist`/`venue` for the same concepts
  (`models/concert.py:22-47`). Client mirrors faithfully — no decode bug → F2-7.
- 🟢 `PlaybackCoordinator.skipBack()` calls `seek(to:0)` then `backend.seek(to:0)`
  (`PlaybackCoordinator.swift:76-77`); `seek(to:)` already hits the backend —
  redundant, harmless → F2-9.
- 🟢 `AggregatedTrack.size` is persisted + carried but never surfaced on
  `TrackResponse` — intentional for Phase 4 downloads; logged so it isn't
  mistaken for dead data → F2-10.
- Positives: backend response models ↔ Swift `Codable` structs are 1:1 under
  `.convertFromSnakeCase`; DI seam (`routes/deps.py`) and `PlayerBackend`
  testability seam are consistent across packets; no layering violations; the
  pure-core/edge-I/O split in `aggregation/` holds.

**Doc-to-code reconciliation:**

| Issue | Location | Verdict |
|---|---|---|
| README "Status: Phase 1 complete… No browsing, search, library… exist yet" | `README.md` | 🔴 **Code is right, doc is wrong.** Phase 2 shipped all of it. **Fixed in this review** (precedent: F0-1, F1-1). |
| §2.1 requires ~24 h persistent metadata cache | `docs/design/00-ARCHITECTURE.md` | **Design is right, code regressed.** Not a design edit — follow-up packet F2-2. |
| Phase 2 roadmap bullet "Aggressive prefetch + retry-with-backoff on streaming" | `docs/development_roadmap.md` | Not shipped; `02-005` explicitly scoped it out and Phase 2 "Done when" does not gate on it. Honest deferral, recorded F2-11 (not a doc edit). |
| CONVENTIONS §6 client clause was "starter — unverified" | `workflow/CONVENTIONS.md` | Now verified by shipped code (01-003 + 02-005). Updated in this review. |
| `03-CLIENT-AND-PLAYBACK.md` §4 state machine | `docs/design/03-CLIENT-AND-PLAYBACK.md` | Code matches (loading/stalled/failed + retry). No discrepancy. |

**Phase 2 "Done when":** *"search a band you actually want, find a show, play
through it like a real music app — and when streaming fails it says so instead of
hanging silently."* — **Met.** Search (`02-001`/`02-004`), browse/list/detail
(`02-003`/`02-004`), play-through + legible state + retry (`02-005`) all ship.
Prefetch/auto-backoff is a roadmap bullet but not a "Done when" gate (F2-11).

**Conventions formalized:** §6 (error handling — client half verified, backend
still unverified per its own ≥2-packet rule), §14 refined (PlayerBackend now
carries the observation/state-machine surface), §15 (DI provider in
`routes/deps.py`), §16 (raw-sqlite3 persistence in the shared cache DB), §17
(pure aggregation core, I/O at the edges).

**Follow-ups:**

| # | Item | Urgency | Notes |
|---|---|---|---|
| F2-1 | Update `README.md` Phase 1 → Phase 2 status | 🔴 blocking | **Resolved in this review** — stale-status README is the explicit predecessor anti-pattern (cf. F0-1, F1-1) |
| F2-2 | Restore persistent metadata caching: wire `MetadataCache` into `get_item_metadata`/`orchestrate` (and onto `app.state`), **or** consciously drop it and amend `00-ARCHITECTURE.md` §2.1 (needs Plan decision) | 🟡 important | Dead code + IA-politeness regression vs design; safe at 1-user scale tonight but fix early in Phase 3 / fix packet |
| F2-3 | Log the swallowed exception in `orchestrate.py:67` | 🟡 important | CLAUDE.md §Audit: IA errors must be logged; flaky IA currently invisible |
| F2-4 | Consolidate audio-format policy to the parse layer; aggregate trusts it (don't re-filter with a divergent allowlist) | 🟡 important | `_PLAYABLE_FORMATS` drops playable bitrate-MP3 variants |
| F2-5 | De-duplicate the on-demand-when-stale decision (one owner: route or orchestrate, not both) | 🟡 important | Drift risk between `routes/concerts.py` and `orchestrate.py` |
| F2-6 | `ruff check --fix` (13 trivial: unused imports incl. pre-existing `ia/metadata.py:2`, `aggregate.py:13/15`, `db/repository.py:7 json`; 1 f-string) + consider adding ruff to the loop | 🟢 optional | Auto-fixable; no behavior change |
| F2-7 | Unify list/detail field naming (`display_artist`/`display_venue` vs `artist`/`venue`) | 🟢 optional | Cosmetic API consistency; no client bug |
| F2-8 | `tests/aggregation/test_aggregate.py:52` dict-vs-`IAFile` mypy error (runtime-OK via Pydantic) | 🟢 optional | Test-only; source clean |
| F2-9 | Remove redundant `backend.seek(to:0)` in `PlaybackCoordinator.skipBack()` | 🟢 optional | Harmless double-seek |
| F2-10 | `AggregatedTrack.size` collected/persisted but unexposed | 🟢 optional | Intentional for Phase 4; noted so it isn't pruned as dead data |
| F2-11 | Aggressive prefetch + retry-with-backoff on streaming | 🟢 optional | Roadmap Phase 2 bullet, not a "Done when" gate; revisit when streaming robustness is needed (Phase 6 polish-ish) |

Carried Phase-1 🟢 (not revisited this boundary, still optional): F1-3 (`makeTrack`
helper URL interpolation), F1-4 (`Color.accentColor` → `.tint`, Phase 6 polish).

**Gating Phase 3:** none of the above is 🔴-blocking for starting Phase 3 (the
only 🔴, F2-1, is resolved). Phase 3 Plan is gated instead on two **user
decisions**: D3 (CloudKit vs local) and library-subset depth — see Blockers.

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
- ~~**D3 (CloudKit vs local)**~~ — RESOLVED 2026-05-18: **local-only v1**. CloudKit
  deferred (additive, no data migration; revisit trigger = 2nd Apple device or
  clean-reinstall resilience mattering). See `docs/design/04-OPEN-QUESTIONS.md`.
- ~~**Library subset depth**~~ — RESOLVED 2026-05-18: **favorites + minimal playlists**;
  smart collections / tag UI / notes deferred (additive on the tag-first model). See
  `docs/design/04-OPEN-QUESTIONS.md` ambiguity 1.
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
- **2026-05-17 (Phase 2 boundary review)** — Phase 2 marked COMPLETE + reviewed; all 6
  packets done. "Done when" met. One 🔴 (README stale status) resolved in-review; 4 🟡
  debt follow-ups recorded (F2-2 metadata-cache regression, F2-3 silent IA failure,
  F2-4 split format policy, F2-5 duplicated staleness decision), none blocking Phase 3.
  CONVENTIONS §15–§17 added, §6/§14 refined. Phase 3 Plan gated on user decisions D3 +
  library-subset depth.
- **2026-05-18 (Phase 3 pre-Plan decisions)** — user resolved both Phase-3 gating
  questions. **D3 → local-only v1** (CloudKit deferred; additive with no data migration;
  revisit trigger = 2nd Apple device or clean-reinstall resilience). **Library subset →
  favorites + minimal playlists** (smart collections / tag UI / notes deferred). Both are
  the documented defaults, now confirmed not assumed. Phase 3 Plan is unblocked. Recorded
  in `docs/design/04-OPEN-QUESTIONS.md` (D3; ambiguity 1) with history preserved.
