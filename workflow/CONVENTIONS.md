# CONVENTIONS.md

Shared implementation conventions for TapeScrape. Read alongside `CLAUDE.md` and the
packet on every Build.

This is a **living, deliberately thin document.** Conventions are formalized here only
after a pattern has appeared in **two or more packets** — never speculatively (that is
the single rule that kept the predecessor's conventions doc from becoming fiction). It is
updated only in Review mode (`workflow/WORKFLOW.md`), at phase boundaries, to match
shipped code. If you discover a broadly-applicable pattern mid-Build, note it in the
packet summary's "Notes" — don't add it here yourself.

The sections below are the **starter**, aligned with `docs/design/`. Expect most to be
refined or replaced once real code exists. Where a section says _(starter — unverified)_
it has not yet been confirmed against shipped code.

---

## 1. Module boundaries

Two codebases. Boundaries follow `docs/design/00-ARCHITECTURE.md`.

**Backend (Python/FastAPI):**

| Layer | May import from |
|---|---|
| `core/` (config, logging, the one HTTP client) | stdlib + Pydantic |
| `models/` (Pydantic API + dataclasses) | core |
| `ia/` (Advanced Search + Metadata clients, parsing) | core, models |
| `aggregation/` (canonicalization, grouping, preferred pick) | core, models, ia |
| `routes/` (FastAPI routes) | all of the above |

Circular imports are forbidden. `core/config` and `core/logging` are exempt (any layer).

**Client (Swift/SwiftUI):** feature code never touches SwiftData/SQLite directly — only
repository protocols. Audio I/O only through `AudioStorage`. Playback state only through
`PlaybackCoordinator`. Views never construct `archive.org` URLs.

## 2. Network access

- Backend calls **only the Internet Archive**, through the single `core` HTTP client
  (rate-limited, cached, logged). No ad-hoc `httpx`/`requests` in route or parsing code.
  Any other external host requires an explicit authorization note in the packet citing
  `CLAUDE.md` § "Network and external services."
- Backend **never** fetches/proxies/caches audio bytes. It returns opaque audio URLs.
- Client streams/downloads audio directly from `archive.org`; treats stream/download
  URLs as opaque strings from the backend.

## 3. The four hooks

`AudioStorage` protocol, `tapescrape://` URL scheme + routing, tag-first library,
repository pattern (`docs/design/00-ARCHITECTURE.md` § 3,
`03-CLIENT-AND-PLAYBACK.md` § 3). Installed Phase 0. Do not bypass; do not add
modularity beyond them.

## 4. Typed boundaries

- Backend API request/response: Pydantic models in `models/`. Internal cross-module
  structures: dataclasses (`frozen=True` where mutation isn't needed). Untrusted IA JSON
  is parsed through a typed model before use — never pass raw `dict` across a layer.
- Client: `Codable` structs / typed models for the catalog API; no untyped JSON or
  dictionaries across module boundaries.

## 5. Async

- FastAPI route handlers and any I/O function: `async def`.
- Client: structured concurrency (`async`/`await`); playback/download lifecycle off the
  view layer.

## 6. Error handling

- Backend _(starter — unverified)_: no typed exception root has shipped. Routes raise
  `fastapi.HTTPException` directly with a `detail` string (`routes/concerts.py` → 404
  unknown concert, 504 aggregation timeout; `routes/search.py` → 422 bad type, 501 not
  yet implemented). A `TapeScrapeError` hierarchy with IA-unavailable / rate-limited /
  not-found subtypes is still intended but is formalized here only once it ships in ≥2
  packets, not before. **Gap to watch:** `orchestrate.py` swallows per-item metadata
  fetch failures with a bare `except Exception: continue` and no log line — a flaky IA
  is currently invisible there (Phase 2 review follow-up).
- Client _(verified)_: playback is an explicit state machine —
  `idle/loading/playing/paused/stalled/failed(Error)` on `PlaybackCoordinator.State`;
  `stalled`/`failed` are legible in `MiniPlayerView`/`NowPlayingView` and `failed`
  always renders a retry affordance (`retry()`), never a silent hang
  (`docs/design/03-CLIENT-AND-PLAYBACK.md` § 4). _Appeared in: 01-003-client-playback
  (initial `failed`), 02-005-player-queue-nowplaying (full machine + `stalled` + retry)._
  Catalog network errors collapse to one `CatalogError.badResponse` — richer
  distinction (404 vs 504 vs offline) is deferred, not yet a convention.

## 7. Testing

- `pytest` with no arguments **never** makes a live IA call. Live-IA tests are marked
  (e.g. `@pytest.mark.live_ia`) and skipped by default; otherwise use recorded fixtures.
- IA fixtures (real Advanced Search / Metadata JSON for known items, e.g. GD
  1977-05-08) live under the backend test tree and are loaded by a small helper. Capture
  fixtures from real responses; do not hand-fabricate IA shapes.
- Swift unit tests don't hit the network; the catalog API client is stubbed
  deterministically.
- Test file mirrors source: `ia/search.py` → `tests/ia/test_search.py`;
  `Foo.swift` → `FooTests.swift`.

## 8. Configuration

- Backend config via one settings module (env-var driven, prefixed `TAPESCRAPE_`). No
  hardcoded hosts, TTLs, or the optional static secret in feature code.
- Client config (backend base URL, audio-quality preference) in one place, not scattered
  literals.

---

## 9. XcodeGen as source of truth

`project.yml` is the canonical definition for the Xcode project. Info.plist properties
(URL schemes, orientations, launch screen) are declared in `project.yml → info.properties`,
not edited directly in `Info.plist`. Running `xcodegen generate` regenerates the
`.xcodeproj` and overwrites direct edits. Test targets use `GENERATE_INFOPLIST_FILE: YES`.

_Appeared in: 00-001-xcode-skeleton (`project.yml`), 00-002-four-hooks (URL scheme
registration, test target Info.plist fix)._

## 10. Swift Testing framework

Unit tests use Swift Testing (`import Testing`, `@Test`, `#expect`, `#require`) — not
XCTest. Test structs (not classes), no inheritance.

_Appeared in: 00-002-four-hooks (`AudioStorageTests.swift`, `DeepLinkRouterTests.swift`)._

## 11. Actor-based in-memory stubs

Repository protocol stubs use Swift `actor` for thread-safe state without manual locking.
Replace with persistence-backed implementations in later phases; the async protocol
signatures accommodate both.

_Appeared in: 00-002-four-hooks (`InMemoryLibraryRepository`, `InMemoryPlaybackHistoryRepository`)._

## 12. Pydantic response models on the API surface

Route handlers return Pydantic `BaseModel` subclasses declared in `models/`. Internal
data moves as validated Pydantic models (not raw dicts). Use `response_model=` on the
route decorator for OpenAPI documentation.

_Appeared in: 01-001-ia-metadata (`models/ia.py`), 01-002-concert-endpoint
(`models/concert.py`)._

## 13. Fixture-based integration tests via TestClient

Route tests patch the data-fetching layer (not the cache or HTTP internals) and exercise
the full response assembly through `TestClient`. Separate unit tests cover lower layers
in isolation. Fixtures are captured from real IA responses, not hand-fabricated.

_Appeared in: 01-002-concert-endpoint (`test_concerts.py` patches `_fetch_item`),
01-001-ia-metadata (fixture-based unit tests for `ia/` modules)._

## 14. PlayerBackend protocol for testable playback

`PlaybackCoordinator` accepts any `PlayerBackend` conformer; tests inject a mock that
records calls without importing AVFoundation. Production uses `AVPlayerBackend`. The
protocol carries the full observation surface as settable closure callbacks
(`onPlaybackReady`, `onPlaybackFailed`, `onPlaybackStalled`, `onPlaybackResumed`,
`onTrackEnd`, `onTimeUpdate`) — the coordinator drives its state machine off these, so
KVO/notification details (and AVFoundation itself) never reach the coordinator or views.
`PlayerBackend.swift` is its own file holding the protocol, `AVPlayerBackend`, and
`PlaybackError`.

_Appeared in: 01-003-client-playback (`PlaybackCoordinator.swift`,
`PlaybackCoordinatorTests.swift`), 02-005-player-queue-nowplaying (`PlayerBackend.swift`
extracted, observation callbacks added, mock-driven state-transition tests)._

## 15. DI provider in `routes/deps.py`, overridable in tests

Shared FastAPI dependencies live in `backend/routes/deps.py` (not `core/` — they need
`fastapi.Request`, and §1 restricts `core/` to stdlib + Pydantic). `get_ia_client`
returns the single `IAClient` built in the `main.py` lifespan and stored on
`app.state.ia_client`. Routes consume it via `Depends(get_ia_client)`. The module-scope
`TestClient(app)` pattern does **not** run the lifespan, so non-live route tests inject a
stub via `app.dependency_overrides[get_ia_client]` (safe — IA is fully mocked there);
live tests opt into the real lifespan with `with TestClient(app)`.

_Appeared in: 01.5-001-iaclient-di (`get_ia_client` created in `routes/concerts.py`),
02-001-artist-search (promoted to `routes/deps.py` at the second-consumer trigger;
`routes/search.py` consumes it), 02-003-concert-list-endpoint (`list_concerts` injects
it)._

## 16. Persistence is raw sqlite3 in the shared cache DB

All persistence — caches and aggregated concerts — uses stdlib `sqlite3` (sync, no ORM)
against the one `settings.cache_db_path` file. Schema is idempotent `CREATE TABLE IF NOT
EXISTS` run on first access (`MetadataCache._init_db`, `SearchCache._init_db`,
`db.repository._ensure_tables` over `db.models.ALL_TABLES`). All SQL is parameterized.
Caches expose an `async` get/set surface over the sync calls so callers need not change
if storage moves; the aggregation repository is plain sync functions taking `db_path`.
Single-writer at one-user scale is accepted; revisit only if contention appears.

_Appeared in: 01-002-concert-endpoint (`core/cache.py` `MetadataCache`),
02-001-artist-search (`core/cache.py` `SearchCache`), 02-002-concert-aggregation
(`db/models.py`, `db/repository.py`)._

## 17. Aggregation is a pure core with I/O only at the edges

`aggregation/` transform functions are pure: given typed inputs they return typed
outputs (dataclasses), no I/O, no global state — `canonicalize.py`, `venue.py`,
`source_quality.py`, and `aggregate.aggregate_items`. Network (IA search/metadata) and
persistence live only in `aggregation/orchestrate.py` and `db/repository.py`. This is
what keeps aggregation fully fixture-testable with zero live IA, and is the structural
fix for the predecessor's in-memory-dict aggregation.

_Appeared in: 02-001-artist-search (`canonicalize.py` pure, route does I/O),
02-002-concert-aggregation (`venue.py`/`source_quality.py`/`aggregate.py` pure;
`orchestrate.py`/`repository.py` hold all I/O)._

---

_New sections are added by Review at phase boundaries, citing the packets and file paths
where the pattern appeared. Do not add conventions speculatively._
