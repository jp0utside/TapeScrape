# Task Packet: Concert endpoint — recordings + tracks for one concert

**Packet ID:** 01-002-concert-endpoint
**Phase:** 1
**Created:** 2026-05-16
**Status:** READY
**Auto-proceed:** false
**High-risk:** false

## Goal

Expose one FastAPI endpoint that, given the test concert identifier (GD 1977-05-08),
returns the concert's recordings with their tracks and opaque stream URLs. This is the
minimal backend contract the client needs to show a concert detail screen in packet
`01-003`.

Phase 1 does **not** require full aggregation, persistent concert entities, or
SourceQuality parsing. The endpoint can hardcode the artist/date lookup, call the IA
modules from `01-001`, assemble the response, and cache raw IA responses in SQLite so
repeated hits don't pound IA.

## Acceptance criteria

- [ ] `GET /concerts/gd-1977-05-08` returns a JSON response with:
  - Concert-level fields: `id`, `artist`, `date`, `venue`, `location`
  - `recordings`: list ordered by download count (proxy for quality until SourceQuality
    lands in Phase 2), each with `identifier`, `source`, `taper`, `lineage`,
    `download_count`
  - `preferred_recording_id`: the first recording's identifier (simplest heuristic for
    Phase 1)
  - Each recording includes `tracks`: ordered list with `title`, `filename`, `duration`,
    `stream_url` (opaque `https://archive.org/download/<id>/<filename>`)
- [ ] Response model is a Pydantic schema (`models/concert.py`) — no untyped dicts cross
      the API boundary
- [ ] Raw IA responses are cached in SQLite (`metadata_cache` table, keyed by identifier,
      TTL 24h) so the endpoint doesn't hit IA on every request
- [ ] Cache module (`core/cache.py`) with `get`/`set` operating on a single SQLite DB
      file; location from config
- [ ] Endpoint uses the `ia/search.py` and `ia/metadata.py` modules from `01-001` — no
      duplicate IA logic
- [ ] Tests pass with recorded fixtures; no live IA calls in `pytest` default run
- [ ] At least one integration test hitting the FastAPI app via `TestClient`

## Read first

- `docs/design/01-INTERNET-ARCHIVE.md` § 2.2 (Metadata shape, derived URLs)
- `docs/design/02-DATA-MODEL.md` § 1–3 (Recording/Track model, cache tables, API surface)
- `backend/ia/search.py`, `backend/ia/metadata.py` — the IA modules to call
- `backend/models/ia.py` — existing Pydantic models
- `backend/core/http_client.py` — shared client (already rate-limited)
- `backend/core/config.py` — where to add cache path config

## Files expected to change

- `backend/models/concert.py` — new: response Pydantic models (`ConcertResponse`,
  `RecordingResponse`, `TrackResponse`)
- `backend/core/cache.py` — new: SQLite metadata cache (get/set/expire)
- `backend/core/config.py` — add `cache_db_path` setting
- `backend/routes/__init__.py` — new package
- `backend/routes/concerts.py` — new: `/concerts/{concert_id}` route
- `backend/main.py` — include the concerts router
- `backend/tests/routes/__init__.py` — new package
- `backend/tests/routes/test_concerts.py` — integration test via TestClient
- `backend/tests/core/test_cache.py` — unit tests for cache module

## Interface sketch

```python
# models/concert.py
class TrackResponse(BaseModel):
    index: int
    title: str | None
    filename: str
    duration: str | None  # raw string from IA; parse deferred to Phase 2
    stream_url: str       # opaque: https://archive.org/download/<id>/<filename>

class RecordingResponse(BaseModel):
    identifier: str
    source: str | None
    taper: str | None
    lineage: str | None
    download_count: int
    tracks: list[TrackResponse]

class ConcertResponse(BaseModel):
    id: str               # "gd-1977-05-08" for Phase 1; opaque UUID after aggregation
    artist: str
    date: str
    venue: str | None
    location: str | None
    preferred_recording_id: str
    recordings: list[RecordingResponse]
```

```python
# core/cache.py
class MetadataCache:
    def __init__(self, db_path: Path): ...
    async def get(self, identifier: str) -> dict | None: ...
    async def set(self, identifier: str, data: dict, ttl_seconds: int = 86400): ...
```

```python
# routes/concerts.py
router = APIRouter(prefix="/concerts")

@router.get("/{concert_id}", response_model=ConcertResponse)
async def get_concert(concert_id: str) -> ConcertResponse: ...
```

## Constraints to preserve

- See `workflow/CONVENTIONS.md` (always applicable)
- See `CLAUDE.md` § "Core constraints" (always applicable)
- Stream URLs are **opaque strings built by the backend** — client never constructs
  `archive.org` URLs (`CLAUDE.md` § "Network and external services")
- All HTTP through `core/http_client.py` — no ad-hoc `httpx.get`
- `pytest` with no arguments must never hit IA
- Preserve IA lineage fields (`source`, `taper`, `lineage`, `identifier`) in responses
- Drop Ogg Vorbis / Shorten (already handled by `IAItem` model, but verify tracks built
  from filtered file list only)

## Tests

- REQUIRED
- `backend/tests/core/test_cache.py` — cache set/get/expire logic (unit, no network)
- `backend/tests/routes/test_concerts.py` — TestClient integration test: mock the IA
  layer (or inject fixtures), assert response shape, field presence, track count, stream
  URL format, Ogg/Shorten absence
- Reuse existing fixture `gd1977-05-08.aud.moore.berger.28354.flac16_metadata.json` for
  the recording detail; existing `gd1977-05-08_search.json` for the search step

## Known ambiguities / open questions

- **Concert ID format for Phase 1.** Using a slug like `gd-1977-05-08` is expedient but
  not the final shape (Phase 2 uses opaque UUIDs after aggregation). The client should
  treat it as opaque regardless.
- **Multiple recordings per concert.** The test concert has ~8 items. Fetching metadata
  for all 8 on every request is expensive without cache. Strategy: fetch metadata for the
  top N by downloads (e.g. 3), cache them, return those. The rest can be fetched lazily
  in Phase 2 when the user taps "Other versions."
- **Async SQLite.** Use `aiosqlite` for non-blocking cache access, or synchronous
  `sqlite3` behind `run_in_executor`? Prefer `aiosqlite` if already a dependency;
  otherwise synchronous is fine at Phase 1 single-user scale.

## Out of scope

- Full concert aggregation (canonical artist/venue, SourceQuality enum, preferred
  recording heuristic beyond "most downloads") — Phase 2
- Persistent `Concert`/`Recording`/`Track` tables — Phase 2
- Search endpoints (`/concerts?artist=`, `/search`) — Phase 2
- Artist canonicalization — Phase 2
- Deployment / hosting decision (D2b) — separate task
- Any client code — packet `01-003`
- `search_cache` table — not needed until browse/search endpoints exist

## Summary output path

`workflow/packets/01-002-concert-endpoint.summary.md`
