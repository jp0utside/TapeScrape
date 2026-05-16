# Task Packet: IA client — Advanced Search + Metadata for one concert

**Packet ID:** 01-001-ia-metadata
**Phase:** 1
**Created:** 2026-05-16
**Status:** READY
**Auto-proceed:** false
**High-risk:** false

## Goal

Wire up real Internet Archive calls through the `core/http_client.py` scaffolding. Hit
Advanced Search (query for GD 1977-05-08 items) and Metadata (per-item detail), parse
responses into typed models, and capture real IA responses as recorded test fixtures so
`pytest` never needs the network.

After this packet the backend can fetch and parse IA data for any artist/date combination,
tested against the fixed Cornell '77 case.

## Acceptance criteria

- [ ] `ia/search.py` — async function calling IA Advanced Search; accepts artist + date
      (or arbitrary query); returns typed list of search-result items
- [ ] `ia/metadata.py` �� async function calling IA Metadata for one identifier; returns
      typed item metadata including the file list
- [ ] `models/ia.py` — Pydantic models: `IASearchResult`, `IAItem`, `IAFile` (with
      format filtering: drop Ogg Vorbis / Shorten at parse time)
- [ ] Both functions go through `core/http_client.py` (rate-limited, logged) — no direct
      `httpx` usage
- [ ] Recorded fixtures: real JSON responses for GD 1977-05-08 search + at least one
      item's metadata, stored under `backend/tests/fixtures/`
- [ ] `pytest` passes using fixtures only; no live IA calls without `@pytest.mark.live_ia`
- [ ] A `live_ia` marker exists and a test decorated with it hits the real API (skipped by
      default, runnable with `pytest -m live_ia`)

## Read first

- `docs/design/01-INTERNET-ARCHIVE.md` — full doc (§ 1–3 especially: APIs, unreliable
  fields, format filtering)
- `docs/design/02-DATA-MODEL.md` § 1 — Recording/Track model shape (informs parsed fields)
- `backend/core/http_client.py` — the shared client to build on

## Files expected to change

- `backend/ia/__init__.py` — package
- `backend/ia/search.py` — Advanced Search wrapper
- `backend/ia/metadata.py` — Metadata API wrapper
- `backend/models/__init__.py` — package
- `backend/models/ia.py` — Pydantic models for IA responses
- `backend/core/http_client.py` — may need minor adjustments (base URL, response helpers)
- `backend/tests/fixtures/gd1977-05-08_search.json` — recorded search response
- `backend/tests/fixtures/gd1977-05-08.sbd.miller.20453.flac16_metadata.json` — recorded metadata
- `backend/tests/ia/__init__.py`
- `backend/tests/ia/test_search.py` — tests using recorded fixtures
- `backend/tests/ia/test_metadata.py` — tests using recorded fixtures
- `backend/tests/conftest.py` — fixture loading helpers, `live_ia` marker registration
- `backend/pyproject.toml` — add `pytest-asyncio` if needed, register markers

## Interface sketch

```python
# models/ia.py
from pydantic import BaseModel

class IASearchItem(BaseModel):
    identifier: str
    title: str
    creator: str | None = None
    date: str | None = None
    downloads: int = 0
    # fields from fl[]

class IASearchResult(BaseModel):
    items: list[IASearchItem]
    total: int

class IAFile(BaseModel):
    name: str
    format: str
    title: str | None = None
    length: str | None = None  # "9:43"
    size: str | None = None

class IAItemMetadata(BaseModel):
    identifier: str
    title: str
    creator: str | None = None
    date: str | None = None
    venue: str | None = None
    coverage: str | None = None
    source: str | None = None
    taper: str | None = None
    lineage: str | None = None
    description: str | None = None

class IAItem(BaseModel):
    metadata: IAItemMetadata
    files: list[IAFile]  # post-filter: Ogg/Shorten dropped

# ia/search.py
async def search_items(
    query: str | None = None,
    creator: str | None = None,
    date: str | None = None,
    rows: int = 50,
    page: int = 1,
) -> IASearchResult: ...

# ia/metadata.py
async def get_item_metadata(identifier: str) -> IAItem: ...
```

## Constraints to preserve

- See `workflow/CONVENTIONS.md` (always applicable)
- See `CLAUDE.md` § "Core constraints" (always applicable)
- All HTTP through `core/http_client.py` — no ad-hoc `httpx.get`
- Drop Ogg Vorbis and Shorten at parse time (§ 01-3.5)
- `pytest` with no arguments must never hit IA (§ Testing)
- Preserve IA lineage fields (`source`, `taper`, `lineage`, `identifier`) in models

## Tests

- REQUIRED
- `backend/tests/ia/test_search.py` — parse recorded search fixture into typed models;
  verify expected item count, identifier format, field presence
- `backend/tests/ia/test_metadata.py` — parse recorded metadata fixture; verify file list
  filtering (Ogg/Shorten removed), track count, field extraction
- One `@pytest.mark.live_ia` test per module (skipped by default) that hits real IA and
  asserts a non-empty response

## Known ambiguities / open questions

- The exact `fl[]` field list for Advanced Search — start with
  `identifier,title,creator,date,downloads` and expand if needed in later packets.
- Whether `IAFile.length` should be parsed to seconds now or stay as a string — keep as
  string for now; parse when the client needs duration math (Phase 2 player).

## Out of scope

- Concert aggregation (grouping items into concerts) — packet `01-002` or Phase 2
- Persistent cache (SQLite) for IA responses — packet `01-002`
- SourceQuality parsing — Phase 2
- Venue canonicalization — Phase 2
- Any client code
- Deployment

## Summary output path

`workflow/packets/01-001-ia-metadata.summary.md`
