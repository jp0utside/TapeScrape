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

- **Phase:** 3 — COMPLETE + reviewed (2026-05-18). Phases 0–2 COMPLETE + reviewed.
- **Repo:** Phase 3 complete. On-device tag-first library (SQLite `library.sqlite`): favorites, cross-concert playlists, real cross-recording queue (play-next/add-to-end/reorder/remove), dynamic Home (Recently Played / On This Day / Artists You Listen To) + dynamic Library, scoped per-track search over the aggregated catalog. Phase-2 backend debt cleared by `02.5-001` (F2-2..F2-6). Backend otherwise unchanged except the new `type=track` search.
- **Next action:** Plan Phase 4 (downloads/offline). First Plan step: confirm the **D2b** backend-host posture for a downloads-capable build (deferred since Phase 2; the off-home-Wi-Fi trigger has not formally fired, but offline downloads make a real URL likelier — user call), then write the first Phase 4 packet (smallest: background `URLSession` download of one preferred recording through `AudioStorage`). No 🔴 blocks Phase 4 — the only 🔴 (F3-1, stale README) was resolved in this review.
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

### Phase 3 packet plan

Opened with the Phase-2 debt fix packet (`02.5-001`), then six client-led deliverables
sequenced smallest-first (favorites → history → queue → playlists → dynamic home →
track search). Only `03-001` was firm at the boundary; the rest were written one ahead.

| Packet | Deliverable | Status |
|---|---|---|
| `02.5-001-backend-debt` | Phase-2 debt: restore metadata cache (F2-2), log IA errors (F2-3), one format policy (F2-4), single staleness owner (F2-5), ruff clean (F2-6) | COMPLETE |
| `03-001-favorites` | Client: `SQLiteLibraryRepository`, heart toggle, Library favorites section | COMPLETE |
| `03-002-playback-history` | Client: `SQLitePlaybackHistoryRepository`, record plays, Recently Played on Home | COMPLETE |
| `03-003-queue-management` | Client: cross-recording queue — play-next/add-to-end/reorder/remove, editable NowPlaying list | COMPLETE |
| `03-004-playlists` | Client: minimal cross-concert playlists (create/add/play/reorder/delete) | COMPLETE |
| `03-005-dynamic-home` | Client: On This Day + Artists You Listen To shelves; conditional GD fallback | COMPLETE |
| `03-006-track-search` | Backend `GET /search?type=track` over aggregated tracks + client scope picker | COMPLETE |

## Phase status

| Phase | Status | Notes |
|---|---|---|
| 0 — Set the stage | COMPLETE | all 4 packets done 2026-05-16; boundary review passed 2026-05-16 (1 blocking follow-up resolved: README updated) |
| 1 — One concert E2E | COMPLETE | started 2026-05-16; all 3 packets done 2026-05-16; boundary review passed 2026-05-16 (1 blocking follow-up: README update) |
| 2 — Browse/search/player | COMPLETE | all 6 packets done 2026-05-17 (`01.5-001`,`02-001`..`02-005`); boundary review passed 2026-05-17 (1 blocking follow-up resolved in-review: README; 4 🟡 debt follow-ups recorded) |
| 3 — Library/queue | COMPLETE | opened with `02.5-001` (Phase-2 debt F2-2..F2-6); 6 client packets `03-001`..`03-006` done 2026-05-18; boundary review passed 2026-05-18 (1 🔴 README resolved in-review; F2-2..F2-6 confirmed closed; 3 design-doc proposals + debt follow-ups recorded) |
| 4 — Downloads/offline | NOT STARTED | next; Plan should confirm D2b host posture for a downloads build |
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
| `02.5-001-backend-debt` | COMPLETE | Metadata cache restored (F2-2); IA errors logged (F2-3); format policy unified to parse-layer allowlist incl. bitrate-MP3s (F2-4); staleness owned solely by orchestrate (F2-5); ruff clean (F2-6); 133 pass 2 skipped | summary: `workflow/packets/02.5-001-backend-debt.summary.md` | — |
| `03-001-favorites` | COMPLETE | SQLiteLibraryRepository (3 tables, favorite tag seeded); heart toggle on ConcertDetailView (optimistic); LibraryTab shows favorites with empty state; 79 Swift tests pass | summary: `workflow/packets/03-001-favorites.summary.md` | Swift 6: SQLITE_TRANSIENT bridged manually; db nonisolated(unsafe) for deinit; static init helpers; LibraryRepository: Sendable required for any-existential across actors |
| `03-002-playback-history` | COMPLETE | SQLitePlaybackHistoryRepository; PlaybackCoordinator records plays on onPlaybackReady; HomeTab shows recently played grouped by concert, most-recent-first; 79 Swift tests pass | summary: `workflow/packets/03-002-playback-history.summary.md` | ConcertContext gained recordingIdentifier (needed by recordPlay); single SQLitePlaybackHistoryRepository shared between coordinator and environment |
| `03-003-queue-management` | COMPLETE | QueueItem wrapper; playNext/addToEnd/removeFromQueue/moveInQueue/skipTo on PlaybackCoordinator; context menus on ConcertDetailView track rows + recording headers; NowPlayingView delete/reorder/dim; 92 Swift tests pass | summary: `workflow/packets/03-003-queue-management.summary.md` | — |
| `03-004-playlists` | COMPLETE | PlaylistItem + Hashable Tag; playlist CRUD in protocol/InMemory/SQLite (playlist_items table); AddToPlaylistSheet in ConcertDetailView; PlaylistDetailView (play/reorder/delete/rename); Playlists section in LibraryTab; 106 Swift tests pass | summary: `workflow/packets/03-004-playlists.summary.md` | PlaylistItem.id not persisted (schema spec); rewritePlaylistItems for move/remove (PK safety) |
| `03-005-dynamic-home` | COMPLETE | Dynamic Home shelves: On This Day (favorite anniversaries), Artists You Listen To (from history); GD browse link becomes conditional fallback; 110 Swift tests pass | summary: `workflow/packets/03-005-dynamic-home.summary.md` | — |
| `03-006-track-search` | COMPLETE | `GET /search?type=track` over aggregated tracks table (JOIN recordings+concerts); `TrackMatch`/`TrackSearchResponse` models; SearchTab scope picker (Artists/Tracks); tap navigates to concert detail; 13 backend tests pass, BUILD SUCCEEDED | summary: `workflow/packets/03-006-track-search.summary.md` | — |

## Phase 3 boundary review (2026-05-18)

Scope: `02.5-001` (Phase-2 debt, shipped in the Phase-3 window), `03-001`..`03-006`.

**Build checks:** `python -m pytest backend/tests/` → **137 passed, 2 skipped**
(`live_ia`, skipped by default — no live IA call in the default run, `CLAUDE.md`
§ Testing holds). `xcodebuild test` (Swift Testing) → **110 tests passed,
`** TEST SUCCEEDED **`**, app build clean. Ad-hoc (no CI): `ruff check backend/`
→ **all checks passed** (F2-6 holds post-`02.5-001`); `mypy backend/` → **3 errors,
all test-only** (`tests/models/test_ia.py:9`, `tests/aggregation/test_aggregate.py:50`,
`tests/aggregation/test_orchestrate.py:27`) — the same `list[dict]`-vs-`list[IAFile]`
runtime-OK-via-Pydantic pattern as F2-8, **50 source files clean**. *Discrepancy noted:*
the `03-006` summary claimed "12 pre-existing failures in
`test_cache.py`/`test_http_client.py`"; these **do not reproduce** here (full green) —
treated as a transient artifact of that build session, current truth is 137/2.

**Cross-file consistency:**

- 🟡 **Two independent sqlite3 connections to one file; write results unchecked.**
  `TapeScrapeApp.swift:15-17` builds `SQLitePlaybackHistoryRepository` and
  `SQLiteLibraryRepository` on the *same* `library.sqlite` via separate
  `sqlite3_open` handles; no `PRAGMA busy_timeout`/WAL, and every write does
  `sqlite3_step(stmt)` discarding the return code (`SQLiteLibraryRepository.swift`
  `exec`/`insertPlaylistItem`/`seedFavoriteTag`; `SQLitePlaybackHistoryRepository.swift:62`).
  A concurrent-write `SQLITE_BUSY` (the coordinator's fire-and-forget `recordPlay`
  `Task` racing a heart toggle) is silently dropped. Flagged in the `03-002` packet's
  own "known ambiguities"; acceptable at one-user scale tonight but a real
  silent-data-loss path → F3-2.
- 🟢 **Duplicated client-sqlite boilerplate.** `private let SQLITE_TRANSIENT = …`
  defined identically at `SQLiteLibraryRepository.swift:5` and
  `SQLitePlaybackHistoryRepository.swift:4`; same actor /
  `nonisolated(unsafe) db` / `init(dbURL:)` / static-schema / `deinit` skeleton in
  both (~30 lines). A shared helper DRYs it, but over-abstracting two impls is the
  larger risk (`CLAUDE.md`) — pattern formalized in CONVENTIONS §18; fix only on a
  3rd impl → F3-3.
- 🟢 **Refresh-on-appear pattern drift.** `LibraryTab.swift:49-54` uses
  `.task` + `.onAppear`; `HomeTab.swift:69` `.onAppear` only;
  `PlaylistDetailView.swift:91` / `ConcertDetailView.swift:120` `.task` only — three
  combinations for the same "reload repo data when the view appears" intent.
  Functionally fine at one-user scale → F3-4 (cosmetic).
- 🟢 **`Color.accentColor` (Phase-1 F1-4) has spread.** Now in
  `ConcertDetailView.swift:230` *and* `NowPlayingView.swift:173,183` (1 file at
  Phase 1). Still Phase-6 polish; sweep all three at once — folded into F1-4.
- 🟢 **Stale 501 reason string.** `routes/search.py:23-25`
  `_NOT_YET = {"concert": "concert aggregation lands in packets 02-002/02-003"}` —
  that aggregation shipped; `type=concert`→501 is correctly out of scope but the
  message now misleads → F3-5 (one-line cosmetic).
- Positives: backend `TrackMatch`/`TrackSearchResponse` ↔ Swift `Codable` are 1:1
  under `.convertFromSnakeCase`; `get_db_path` added to `routes/deps.py` follows the
  §15 DI pattern exactly; track-search SQL is fully parameterized
  (`search.py:44-47`, `?`-bound, no interpolation — `CLAUDE.md`/CONVENTIONS §2);
  per-item `ConcertContext` is threaded through `QueueItem` and the global
  `concertContext` was removed exactly as `03-003` required; `InMemory*` stubs are
  kept (§11) and behaviorally mirror the SQLite impls (sort-order renumbering parity);
  no layering violations (views → repository protocols only, no raw SQLite in feature
  code); `_search_tracks` touches only the local `tracks` table — zero new IA calls;
  the pure-core/edge-I/O backend split (§17) is intact.

**Doc-to-code reconciliation:**

| Issue | Location | Verdict |
|---|---|---|
| README "Status: Phase 2 complete… Not yet: persisted library/favorites… global track search" | `README.md` | 🔴 **Code is right, doc is wrong.** Phase 3 shipped favorites, playlists, dynamic Home/Library, queue mgmt, scoped track search. The recurring predecessor anti-pattern (cf. F0-1/F1-1/F2-1). **Fixed in this review** (status block + manual-test items 10–12). → F3-1 |
| Tag model: design says `kind ∈ {system,user}`, "`favorite` is a system tag" | `02-DATA-MODEL.md` §5 vs `Tag.swift:9-11` (`enum TagKind { favorite, playlist, smart, user }`) | **Code is right (cleaner — kind encodes purpose; `playlistTags()` filters `kind='playlist'`).** Design wording stale → propose design edit (Plan-owned) → F3-6 |
| Scoped track search reads a `track_index` table written at Metadata-parse, scoped to "recordings opened in detail" | `02-DATA-MODEL.md` §2/§4, `00-ARCHITECTURE.md` §4 vs `routes/search.py:33-65` (queries the aggregated `tracks` JOIN recordings/concerts; scope = "artists aggregated") | 🟡 **Code is right (reuses aggregation `tracks` — simpler, broader, API shape unchanged; `03-006` documented the reframed scoping).** Design describes an unbuilt `track_index` table + wrong trigger → propose design edit → F3-7 |
| CloudKit hook "custom zone-shaped container from day one" | `02-DATA-MODEL.md` §5 vs flat `library.sqlite` + repository seam | **Code is right per D3 (local-only v1; CloudKit additive, no migration).** The repository protocol *is* the swap seam; literal zone container not built and not needed → propose softening design wording → F3-8 (🟢) |
| `PlaybackHistory` tuple includes `stoppedPosition` (resume) | `02-DATA-MODEL.md` §5 | Not shipped; `03-002` explicitly deferred resume-from-position. Honest deferral, not a "Done when" gate (mirror of F2-11). F3-9 (🟢), not a doc edit |
| Home "more from this run" shelf | `03-CLIENT-AND-PLAYBACK.md` §2 | Not shipped; `03-005` deferred it (needs backend tour/date-proximity data). The other 3 shelves ship. Honest deferral → F3-10 (🟢) |
| "SwiftData (or a thin SQLite wrapper) behind repositories" | `03-CLIENT-AND-PLAYBACK.md` §1 | Shipped: thin raw-sqlite3 wrapper behind repositories. **Matches** — no discrepancy |
| Phase-2 follow-ups F2-2..F2-6 | Phase 2 review | **Resolved** by `02.5-001-backend-debt` (committed `3067acf`): metadata cache restored + on `app.state`, IA errors logged, one parse-layer format policy, single staleness owner, ruff clean. Verified against code + suite this review |

**Phase 3 "Done when":** *"the app remembers what you care about across launches, you
can get back to a show you liked without re-searching, and you can build and play a
multi-show playlist."* — **Met.** Persistence across launches (SQLite favorites/
history/playlists, `03-001/02/04`); get-back-without-re-searching (Recently Played +
On This Day + Library favorites, `03-002/05/01`); build-and-play a cross-show playlist
(`03-004` CRUD + `PlaylistDetailView` play). "More from this run" and resume-from-
position are roadmap/design bullets, not "Done when" gates (F3-9/F3-10).

**Conventions formalized:** §18 (client raw-sqlite3 `actor` repository in
`library.sqlite` — the §16 client parallel; appeared `03-001`/`03-002`, extended
`03-004`), §19 (repository DI via a private `EnvironmentKey` defaulting to the
`InMemory*` stub + one shared instance split between the environment and
`PlaybackCoordinator`; appeared `03-001`/`03-002`). §6 backend gap note updated
(F2-3's "flaky IA invisible" gap closed by `02.5-001`).

**Follow-ups:**

| # | Item | Urgency | Notes |
|---|---|---|---|
| F3-1 | README still said "Phase 2 complete / library not yet" | 🔴 blocking | **Resolved in this review** — stale-status README is the explicit predecessor anti-pattern (cf. F0-1/F1-1/F2-1) |
| F3-2 | Two sqlite3 connections to one `library.sqlite`; no `busy_timeout`/WAL; `sqlite3_step` write results unchecked → silent `SQLITE_BUSY` data loss | 🟡 important | Safe at one-user scale tonight; fix early when touching persistence (Phase 4 downloads adds a 3rd writer). Options: shared DB actor, or `busy_timeout`+WAL+checked steps |
| F3-3 | DRY the duplicated client-sqlite boilerplate (`SQLITE_TRANSIENT`, actor/db/init/deinit skeleton) | 🟢 optional | Only on a 3rd impl; over-abstracting two is worse. Pattern captured in CONVENTIONS §18 |
| F3-4 | Unify the refresh-on-appear modifier (`.task` vs `.onAppear` vs both) across Home/Library/Playlist/ConcertDetail | 🟢 optional | Cosmetic; no bug at one-user scale |
| F3-5 | Fix the stale `_NOT_YET["concert"]` 501 reason string in `routes/search.py` | 🟢 optional | One line; `type=concert`→501 itself is correct/out-of-scope |
| F3-6 | Propose `02-DATA-MODEL.md` §5 edit: `TagKind` is the purpose enum `{favorite,playlist,smart,user}`, not `kind∈{system,user}` (code is the better model) | 🟡 important | Plan-owned design edit; doc currently misdescribes a shipped core model |
| F3-7 | Propose `02-DATA-MODEL.md` §2/§4 + `00-ARCHITECTURE.md` §4 edit: scoped track search reuses the aggregated `tracks` table, not a separate metadata-parse `track_index`; scope = "artists aggregated" | 🟡 important | Plan-owned; doc describes an unbuilt table + wrong trigger for a shipped subsystem |
| F3-8 | Propose `02-DATA-MODEL.md` §5 wording: the repository protocol is the CloudKit swap seam; "zone-shaped container from day one" not literally built (D3-accepted) | 🟢 optional | Plan-owned; consistent with D3 (additive, no migration) |
| F3-9 | `stoppedPosition` / resume-from-position not shipped | 🟢 optional | `03-002`-deferred; future packet, not a "Done when" gate |
| F3-10 | "More from this run/tour" Home shelf not shipped | 🟢 optional | `03-005`-deferred (needs backend tour/date-proximity data) |

Phase-2 follow-ups status after this review: **F2-2/F2-3/F2-4/F2-5/F2-6 — RESOLVED**
(`02.5-001-backend-debt`). **F2-8 carried** — now 3 test-only `mypy` occurrences of
the same dict-vs-`IAFile` (runtime-OK via Pydantic), source clean, still 🟢.
F2-7/F2-9/F2-10/F2-11 and Phase-1 F1-3/F1-4 carried (🟢; F1-4 now spans 2 files,
see Phase-3 consistency note).

**Gating Phase 4:** none of F3-2..F3-10 is 🔴-blocking; the only 🔴 (F3-1) is
resolved. Phase 4 Plan should confirm the **D2b** backend-host posture for a
downloads-capable build (deferred since Phase 2, trigger not formally fired) — a user
call, not a code blocker.

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
  on it. **Phase 4 Plan should reconfirm** for a downloads-capable build (offline
  downloads make a real off-network URL likelier even if the trigger hasn't formally
  fired) — user call, not a code blocker. See `docs/design/04-OPEN-QUESTIONS.md`.
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
- **2026-05-18 (Phase 3 boundary review)** — Phase 3 marked COMPLETE + reviewed;
  `02.5-001` (Phase-2 debt) + `03-001`..`03-006` done. "Done when" met (persistence
  across launches, get-back-without-re-searching, build/play a cross-show playlist).
  F2-2..F2-6 confirmed resolved by `02.5-001`; F2-8 carried (3 test-only mypy). One 🔴
  (F3-1 stale README) resolved in-review; F3-2 (two sqlite3 connections / unchecked
  writes) recorded 🟡. Three **design-doc reconciliation proposals** for Plan: F3-6
  (`TagKind` is the purpose enum, not `kind∈{system,user}`), F3-7 (scoped track search
  reuses the aggregated `tracks` table, not a metadata-parse `track_index`), F3-8
  (repository protocol is the CloudKit seam; "zone-shaped container" not literal) —
  Review proposes, Plan/user decides the wording. CONVENTIONS §18/§19 added, §6 gap
  note updated. Phase 4 Plan gated only on a user D2b host call; no 🔴.
- **2026-05-18 (Phase 3 pre-Plan decisions)** — user resolved both Phase-3 gating
  questions. **D3 → local-only v1** (CloudKit deferred; additive with no data migration;
  revisit trigger = 2nd Apple device or clean-reinstall resilience). **Library subset →
  favorites + minimal playlists** (smart collections / tag UI / notes deferred). Both are
  the documented defaults, now confirmed not assumed. Phase 3 Plan is unblocked. Recorded
  in `docs/design/04-OPEN-QUESTIONS.md` (D3; ambiguity 1) with history preserved.
