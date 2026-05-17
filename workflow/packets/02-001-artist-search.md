# Task Packet: Artist search endpoint + canonical artist key + search cache

**Packet ID:** 02-001-artist-search
**Phase:** 2
**Created:** 2026-05-17
**Status:** READY
**Auto-proceed:** true
**High-risk:** false

## Goal

Ship the first Phase-2 backend slice toward "search by artist": a `GET /search`
endpoint that resolves a messy IA `creator` query into **canonical artists**, backed by
the canonical-artist-key logic (`01-INTERNET-ARCHIVE.md` §5.1) and a 30-minute
`search_cache` (`02-DATA-MODEL.md` §2, `00-ARCHITECTURE.md` §6). This is the load-bearing
canonicalization primitive the concert-grouping packet (`02-002`) will build on, exposed
through a real, design-specified endpoint so it is exercised end-to-end now.

No concert grouping, no venue logic, no persistence, no `SourceQuality` — those are
`02-002`/`02-003`.

## Acceptance criteria

- [ ] `backend/aggregation/canonicalize.py` provides `canonical_artist_key(raw: str) -> str`
      implementing §5.1: lowercase; strip leading `the `, trailing `, the`; collapse
      `&`/`and`/` + ` to a single ` and `; strip punctuation; collapse whitespace; then
      apply an append-only hand-curated alias map (seeded with the spec's
      `jgb → jerry garcia band`, nothing speculative).
- [ ] `display_artist(raw_names: list[str]) -> str` returns the most common original
      casing among the grouped raw names (ties: first seen).
- [ ] `GET /search?type=artist&q=<query>&page=<n>` returns `ArtistSearchResponse`
      (Pydantic): `query`, `type`, `matches: list[ArtistMatch]`, where each `ArtistMatch`
      has `canonical_artist`, `display_artist`, `recording_count` (distinct IA items in
      this search response that map to that canonical key — explicitly *pre-aggregation*,
      not a catalog total).
- [ ] `type=concert` and `type=track` are accepted by the param but return **HTTP 501**
      with a structured body naming where they land (`concert` → `02-002`/`02-003`;
      `track` → scoped/future per `00-ARCHITECTURE.md` §4). The param shape must not
      foreclose F1. Unknown `type` → HTTP 422/400.
- [ ] IA Advanced Search responses are cached in a `search_cache` SQLite table keyed by a
      hash of normalized `(type, q, page)`, TTL from config (~1800 s); a cache hit makes
      no IA call (assert in a test).
- [ ] The endpoint uses the lifespan-injected `IAClient` via `Depends` — no new client,
      no module-level `IAClient()`. `get_ia_client` is **promoted** to
      `backend/routes/deps.py` and imported by both `concerts.py` and `search.py` (this
      is the "second consumer" trigger pre-registered in the `01.5-001` summary).
- [ ] All IA HTTP still goes through the one `IAClient` (CONVENTIONS §2); `pytest`
      default run makes zero live IA calls; existing 28 tests still pass.

## Read first

> Floor (CLAUDE.md, CONVENTIONS.md, this packet) not relisted. IA/aggregation work →
> `01-INTERNET-ARCHIVE.md` is required reading.

- `docs/design/01-INTERNET-ARCHIVE.md` §3.3 (artist-name inconsistency) and §5.1
  (canonical artist key — the exact algorithm) — load-bearing
- `docs/design/02-DATA-MODEL.md` §1 (`canonical_artist`/`display_artist`), §2
  (`search_cache`), §3 (API surface: `/search?type=`)
- `docs/design/00-ARCHITECTURE.md` §4 (search `type` accepts `artist|concert|track`;
  `track` scoped in v1)
- `backend/ia/search.py` — `search_items(client, *, creator=..., query=..., page=...)`
  to call
- `backend/models/ia.py` — `IASearchItem` / `IASearchResult` to reuse (do not re-parse)
- `backend/core/cache.py` — `MetadataCache` is the pattern to mirror for `SearchCache`
- `backend/routes/concerts.py` — current home of `get_ia_client` (to promote to `deps.py`)
- `backend/core/config.py` — `cache_db_path`; where to add the search-cache TTL setting

## Files expected to change

- `backend/aggregation/__init__.py` — new package (CONVENTIONS §1: imports core, models, ia)
- `backend/aggregation/canonicalize.py` — new: `canonical_artist_key`, `display_artist`,
  `_ARTIST_ALIASES`
- `backend/models/search.py` — new: `ArtistMatch`, `ArtistSearchResponse`
- `backend/routes/deps.py` — new: `get_ia_client` moved here from `concerts.py`
- `backend/routes/concerts.py` — import `get_ia_client` from `routes.deps` (delete the
  local copy; no behaviour change)
- `backend/routes/search.py` — new: `GET /search`
- `backend/core/cache.py` — add `SearchCache` (same sqlite file, new `search_cache` table)
- `backend/core/config.py` — add `search_cache_ttl_seconds: int = 1800`
- `backend/main.py` — include the search router
- `backend/tests/aggregation/__init__.py`, `backend/tests/aggregation/test_canonicalize.py`
  — new
- `backend/tests/core/test_cache.py` — extend for `SearchCache`
- `backend/tests/routes/test_search.py` — new (TestClient + DI override, fixture-based)

> ~7 source + 3 test files. Above the ~3–5 guideline but cohesive ("artist search"): the
> `deps.py` promotion is the pre-registered second-consumer move, not new scope. If it
> grows further while building (e.g. pagination balloons), split — do not silently expand.

## Interface sketch

```python
# aggregation/canonicalize.py
_ARTIST_ALIASES: dict[str, str] = {"jgb": "jerry garcia band"}  # append-only, curated

def canonical_artist_key(raw: str) -> str: ...
def display_artist(raw_names: list[str]) -> str: ...

# models/search.py
class ArtistMatch(BaseModel):
    canonical_artist: str
    display_artist: str
    recording_count: int           # items in THIS response; pre-aggregation, not a total

class ArtistSearchResponse(BaseModel):
    query: str
    type: str
    matches: list[ArtistMatch]

# core/cache.py  (mirror of MetadataCache; distinct table in the same DB file)
class SearchCache:
    def __init__(self, db_path: Path): ...
    async def get(self, key: str) -> dict | None: ...
    async def set(self, key: str, data: dict, ttl_seconds: int = 1800) -> None: ...

# routes/deps.py
def get_ia_client(request: Request) -> IAClient:
    return request.app.state.ia_client

# routes/search.py
router = APIRouter()

@router.get("/search", response_model=ArtistSearchResponse)
async def search(q: str, type: str = "artist", page: int = 1,
                 ia_client: IAClient = Depends(get_ia_client)) -> ArtistSearchResponse:
    # type != "artist": 501 (concert→02-002/02-003, track→scoped/future)
    # cache key = sha256(f"{type}|{q.strip().lower()}|{page}")
    ...
```

## Constraints to preserve

- See `workflow/CONVENTIONS.md` and `CLAUDE.md` § "Core constraints" (always applicable)
- Backend calls only IA, through the one lifespan `IAClient` (CONVENTIONS §2). Reuse
  `Depends(get_ia_client)`; never instantiate `IAClient()` outside the lifespan.
- Untrusted IA JSON parsed through `models/ia.py` types before use — no raw dict across a
  layer (CONVENTIONS §4).
- `aggregation/` may import only core, models, ia (CONVENTIONS §1). `canonicalize.py`
  must be pure (no I/O) — independently unit-testable.
- `pytest` default run never hits live IA (`CLAUDE.md` §Testing). New live-IA-dependent
  assertions, if any, gated behind `@pytest.mark.live_ia`.
- Don't claim unbuilt behaviour: `type=concert|track` must honestly 501, not fake a
  result (the predecessor's exact failure mode).

## Tests

- REQUIRED
- `tests/aggregation/test_canonicalize.py` — table-driven over the §3.3 real variants:
  `"Grateful Dead"`, `"The Grateful Dead"`, `"Grateful Dead, The"` → same key;
  `"Phish"`/`"phish"` → same; `"Bob Weir & Ratdog"`/`"Bob Weir and Ratdog"`/`"Bob Weir +
  Ratdog"` → same; alias `"JGB"` → `"jerry garcia band"`; `display_artist` casing pick.
- `tests/core/test_cache.py` — `SearchCache` set/get/expire; distinct from `metadata_cache`.
- `tests/routes/test_search.py` — TestClient with `app.dependency_overrides` /
  `_patched` IA layer using the existing `gd1977-05-08_search.json` fixture: assert
  `type=artist` collapses the 8 GD items into one `ArtistMatch` with the right
  display name and `recording_count`; assert a second call hits cache (IA layer called
  once); assert `type=concert` and `type=track` → 501; unknown `type` → 4xx.
- Reuse `backend/tests/helpers.py::load_fixture`; do **not** hand-fabricate IA shapes.

## Known ambiguities / open questions

- **Alias map seed.** Decided: seed only the spec's `jgb → jerry garcia band`. The map is
  append-only and grows from real data evidence — do not invent a large speculative map.
- **`recording_count` semantics.** Decided: count of distinct IA items in *this search
  response* mapping to the canonical key. It is explicitly pre-aggregation and not a
  catalog total; the model field doc and a test name must say so to avoid future drift.
- **Pagination.** v1 returns the requested `page` (default 1) of IA results only; deep
  paging / date-windowing for huge artists (`01-INTERNET-ARCHIVE.md` §3.7) is **out of
  scope** — note as a future tuning packet.
- **`type=concert|track` now.** Decided: HTTP 501 + structured body. The param is
  accepted so F1 is not foreclosed; the feature is honestly absent.

## Out of scope

- Concert grouping, concert key, venue canonicalization/clustering, `date_precision`
  year-only tier → `02-002`.
- Persisting canonical `Concert`/`Recording`/`Track` to SQLite → `02-002`.
- `SourceQuality` parsing and best-first recording ordering / preferred-recording pick →
  `02-002`.
- `GET /concerts?artist=` concert-list endpoint and on-demand-when-stale re-aggregation →
  `02-003`.
- Real `type=concert` / `type=track` results; `track_index` table (`02-DATA-MODEL.md` §2:
  add it when track search lands, not before).
- Deep pagination / date-windowing fallback for very common queries.
- Moving the caches onto `app.state`/DI (the recorded post-Phase-1 follow-up) — keep the
  Phase-1 module-global cache pattern for consistency; note it, don't fix it here.
- Capturing new live IA fixtures — reuse the existing search fixture; a richer
  multi-creator fixture is a `live_ia`-gated optional follow-up.
- Any client/Swift code → `02-004+`.

## Summary output path

`workflow/packets/02-001-artist-search.summary.md`
