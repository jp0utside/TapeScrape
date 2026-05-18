# Task Packet: Concert aggregation — group IA items into persisted concerts

**Packet ID:** 02-002-concert-aggregation
**Phase:** 2
**Created:** 2026-05-17
**Status:** READY
**Auto-proceed:** false
**High-risk:** true

## Goal

Build the aggregation engine that groups IA items (recordings) into canonical concerts
and persists them to SQLite. This is the core logic that turns a flat list of IA search
results into the product's concert hierarchy (`01-INTERNET-ARCHIVE.md` § 5).

After this packet, calling the aggregation function for an artist produces persisted
`Concert → Recording → Track` rows with opaque IDs, source quality classification, and a
computed preferred recording. The existing `/concerts/{id}` endpoint is not yet rewired
(that's `02-003`); this packet is pure backend logic + persistence + tests.

## Acceptance criteria

- [ ] `aggregation/venue.py` — canonical venue key: token-set similarity clustering
      (~0.85 threshold) + append-only alias map. Fixes the raw-majority-vote bug from
      `set-scrape`
- [ ] `aggregation/source_quality.py` — parse `SourceQuality` enum
      (`SBD | MTX | AUD | FM | UNKNOWN`) from the item's `source`, `description`, and
      identifier tokens. Order: first match wins (regex + token scan)
- [ ] `aggregation/aggregate.py` — given a list of `IASearchItem`s + fetched
      `IAItem` metadata for a sample, produce `Concert` / `Recording` / `Track` rows:
  - Concert key = `(canonical_artist, date, canonical_venue)`
  - Year-only dates → separate tier (not dropped)
  - Opaque concert ID = deterministic hash of the canonical key (UUID5 or sha256 prefix)
  - Preferred recording = best `SourceQuality` → most tracks → highest `downloads`
- [ ] `db/models.py` — SQLAlchemy (or plain SQL) table definitions for `concerts`,
      `recordings`, `tracks` persisted to the existing `cache_db_path` SQLite file
- [ ] `db/repository.py` — `save_aggregation(concerts)` and
      `get_concerts_for_artist(canonical_artist)` with `aggregated_at` timestamp for
      staleness checks
- [ ] `aggregation/orchestrate.py` — top-level function: search IA for an artist, fetch
      metadata for top-N items per candidate concert (sample, not all), aggregate, persist.
      Uses `IAClient` (injected). Respects on-demand-when-stale trigger (skip if fresh)
- [ ] Tests: venue clustering, source quality parsing, end-to-end aggregation with
      fixtures, persistence round-trip. All fixture-based; no live IA

## Read first

- `docs/design/01-INTERNET-ARCHIVE.md` § 4–5 (predecessor failures, TapeScrape algorithm)
- `docs/design/02-DATA-MODEL.md` § 1–2 (Concert/Recording/Track schema, cache tables)
- `backend/aggregation/canonicalize.py` — artist canonicalization (already landed)
- `backend/core/cache.py` — existing cache (the DB file is shared; new tables go here)
- `backend/models/ia.py` — `IASearchItem`, `IAItem`, `IAFile` (inputs to aggregation)

## Files expected to change

- `backend/aggregation/venue.py` — new: `canonical_venue_key`, `display_venue`,
  `_VENUE_ALIASES`, token-set similarity
- `backend/aggregation/source_quality.py` — new: `SourceQuality` enum, `parse_source_quality`
- `backend/aggregation/aggregate.py` — new: core grouping logic
- `backend/aggregation/orchestrate.py` — new: top-level "aggregate artist" function
- `backend/db/__init__.py` — new package
- `backend/db/models.py` — new: table schemas (plain SQL `CREATE TABLE` statements)
- `backend/db/repository.py` — new: persistence read/write functions
- `backend/core/config.py` — add `aggregation_staleness_seconds: int` (configurable TTL)
- `backend/tests/aggregation/test_venue.py` — new
- `backend/tests/aggregation/test_source_quality.py` — new
- `backend/tests/aggregation/test_aggregate.py` — new
- `backend/tests/db/__init__.py` — new
- `backend/tests/db/test_repository.py` — new

## Interface sketch

```python
# aggregation/venue.py
def canonical_venue_key(raw: str) -> str: ...
def display_venue(raw_names: list[str]) -> str: ...
def cluster_venues(raw_names: list[str]) -> dict[str, list[str]]:
    """Group raw venue strings into clusters; return {canonical_key: [raw_names]}."""
    ...

# aggregation/source_quality.py
from enum import IntEnum

class SourceQuality(IntEnum):
    SBD = 0
    MTX = 1
    AUD = 2
    FM = 3
    UNKNOWN = 4

def parse_source_quality(
    source: str | None,
    description: str | None,
    identifier: str,
) -> SourceQuality: ...

# aggregation/aggregate.py
from dataclasses import dataclass

@dataclass
class AggregatedConcert:
    id: str  # deterministic from canonical key
    canonical_artist: str
    display_artist: str
    date: str
    date_precision: str  # "day" | "year"
    canonical_venue: str
    display_venue: str | None
    location: str | None
    recordings: list["AggregatedRecording"]
    preferred_recording_id: str
    aggregated_at: float  # time.time()

@dataclass
class AggregatedRecording:
    identifier: str
    source_quality: SourceQuality
    source: str | None
    taper: str | None
    lineage: str | None
    downloads: int
    tracks: list["AggregatedTrack"]

@dataclass
class AggregatedTrack:
    index: int
    title: str | None
    filename: str
    duration: str | None
    stream_url: str

def aggregate_items(
    canonical_artist: str,
    display_artist: str,
    search_items: list[IASearchItem],
    fetched_items: dict[str, IAItem],  # identifier → IAItem (sampled subset)
) -> list[AggregatedConcert]: ...

# aggregation/orchestrate.py
async def aggregate_artist(
    canonical_artist: str,
    ia_client: IAClient,
    force: bool = False,
) -> list[AggregatedConcert]:
    """Fetch, aggregate, persist. Skip if fresh (unless force=True)."""
    ...
```

```python
# db/repository.py
def save_aggregation(db_path: Path, concerts: list[AggregatedConcert]) -> None: ...
def get_concerts_for_artist(db_path: Path, canonical_artist: str) -> list[AggregatedConcert]: ...
def get_concert_by_id(db_path: Path, concert_id: str) -> AggregatedConcert | None: ...
def get_aggregation_age(db_path: Path, canonical_artist: str) -> float | None:
    """Seconds since last aggregation, or None if never aggregated."""
    ...
```

## Design decisions (within this packet)

1. **Venue clustering: token-set ratio, not Levenshtein edit distance.** Token-set ratio
   handles word-order differences ("Madison Square Garden" vs "Garden, Madison Square")
   better than raw edit distance. Use a simple Python implementation (sorted token overlap
   / union) — no external dependency like `thefuzz`. Threshold ~0.85.

2. **Sample strategy for metadata fetches.** Per candidate concert (items sharing
   artist+date), fetch metadata for the top 3 by downloads. This gives venue/source data
   without hammering IA for all 10+ items of a popular show. Others get
   `SourceQuality.UNKNOWN` and no tracks until the user drills in.

3. **Persistence is plain SQL, not SQLAlchemy ORM.** The existing caches use raw
   `sqlite3`; stay consistent. Table creation in `db/models.py` as `CREATE TABLE IF NOT
   EXISTS` statements. Repository functions use parameterized SQL.

4. **Concert ID = UUID5 from canonical key.** `uuid.uuid5(NAMESPACE, f"{artist}|{date}|{venue}")`.
   Deterministic so re-aggregation produces stable IDs; no pipes in URL paths (the UUID
   is what routes use).

5. **Shared DB file.** Aggregation tables live in the same `cache_db_path` SQLite file as
   the caches. Single-writer at this scale is fine. Future: separate if contention appears.

## Constraints to preserve

- See `workflow/CONVENTIONS.md` (always applicable)
- See `CLAUDE.md` § "Core constraints" (always applicable)
- All HTTP through `IAClient` (injected) — no ad-hoc `httpx.get`
- Preserve IA lineage fields in persisted recordings
- Drop Ogg/Shorten (already done at IAItem parse; verify tracks only built from filtered
  files)
- `pytest` default run must never hit IA — all aggregation tests use fixture data
- Aggregation functions are **pure** where possible (given typed inputs, produce typed
  outputs). I/O (fetching, persisting) lives in `orchestrate.py` and `repository.py`

## Tests

- REQUIRED
- `test_venue.py` — clustering: "Madison Square Garden" / "MSG" / "MSG, NYC" cluster
  together; "Red Rocks Amphitheatre" / "Red Rocks" cluster; two genuinely different
  venues stay separate. Display venue picks most common. Alias map overrides.
- `test_source_quality.py` — parametrized: `"SBD > ..."` → SBD; `"AUD"` in description →
  AUD; `.sbd.` in identifier → SBD; no signal → UNKNOWN; MTX/FM cases
- `test_aggregate.py` — end-to-end: given fixture search results + fixture metadata for a
  sample, produce expected concerts with correct grouping, recording ordering (SBD before
  AUD), preferred pick, track lists, stream URLs. Year-only date → separate concert.
  Two-venue same-day → two concerts.
- `test_repository.py` — round-trip: save aggregation, read back, verify all fields.
  Staleness check returns correct age. Re-save overwrites cleanly.

## Known ambiguities / open questions

- **Token-set similarity threshold.** Starting at 0.85; may need tuning against real
  venue data. The alias map is the escape hatch for cases the algorithm gets wrong.
- **What happens to the Phase 1 `/concerts/gd-1977-05-08` route?** It continues to work
  unchanged in this packet. `02-003` replaces it with a route backed by persisted
  aggregation. The slug `gd-1977-05-08` will become a UUID; client treats IDs as opaque
  so no breaking change on the wire.
- **Uncut master detection.** `02-DATA-MODEL.md` mentions capturing uncut masters. Defer
  to a follow-up — detection heuristic is non-trivial and not needed for the concert
  list/detail flow.

## Out of scope

- Rewiring the existing `/concerts/{id}` or adding `/concerts?artist=` — packet `02-003`
- Client changes — later packets
- Track-title search index (`track_index` table) — later Phase 2 or Phase 3
- Venue canonicalization alias map population beyond a seed set — grows from real data
- Uncut master detection — future follow-up
- Re-aggregation scheduling / background jobs — on-demand only per resolved decision

## Summary output path

`workflow/packets/02-002-concert-aggregation.summary.md`
