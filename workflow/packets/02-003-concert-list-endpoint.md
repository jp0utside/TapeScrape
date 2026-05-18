# Task Packet: Concert list endpoint — /concerts?artist= backed by aggregation

**Packet ID:** 02-003-concert-list-endpoint
**Phase:** 2
**Created:** 2026-05-17
**Status:** READY
**Auto-proceed:** true
**High-risk:** false

## Goal

Expose the concert list and detail endpoints backed by the persisted aggregation from
`02-002`. After this packet, the client can: (1) search for an artist (already working),
(2) browse that artist's concerts as a paginated list, (3) view concert detail with
recordings ordered by source quality and tracks with stream URLs.

This replaces the Phase 1 hardcoded `_CONCERT_MAP` in `routes/concerts.py` with real
aggregation-backed routes. The on-demand-when-stale trigger fires aggregation
transparently on first browse of an artist.

## Acceptance criteria

- [ ] `GET /concerts?artist=<canonical_artist>&page=<n>` returns paginated concerts
      for an artist (default page size 20). Response: `ConcertListResponse` with
      `concerts[]`, `total`, `page`, `page_size`
- [ ] Each concert in the list includes: `id`, `display_artist`, `date`,
      `date_precision`, `display_venue`, `location`, `recording_count`,
      `preferred_recording_id`
- [ ] Endpoint triggers `aggregate_artist` on-demand-when-stale: if no persisted data
      or staleness exceeds `aggregation_staleness_seconds`, re-aggregate before responding
- [ ] `GET /concerts/{concert_id}` is rewritten to load from persisted aggregation
      (UUID-based IDs). Returns full `ConcertDetailResponse` with recordings + tracks
- [ ] The old Phase 1 slug-based route (`gd-1977-05-08`) is removed — client already
      treats IDs as opaque
- [ ] Response models are Pydantic; no untyped dicts cross the boundary
- [ ] Tests: list endpoint (pagination, empty artist, stale trigger), detail endpoint
      (found, not found), integration with fixture data via pre-seeded repository

## Read first

- `backend/aggregation/orchestrate.py` — the function to call for on-demand aggregation
- `backend/db/repository.py` — persistence read functions
- `backend/routes/concerts.py` — current Phase 1 implementation (to be rewritten)
- `backend/models/concert.py` — existing response models (update or replace)
- `docs/design/02-DATA-MODEL.md` § 3 (API surface shape)

## Files expected to change

- `backend/routes/concerts.py` — rewritten: list + detail backed by repository/orchestrate
- `backend/models/concert.py` — update: add `ConcertListResponse`, `ConcertListItem`;
  update `ConcertResponse` → `ConcertDetailResponse` if needed; ensure recording
  includes `source_quality` field
- `backend/core/config.py` — add `concerts_page_size: int = 20` (if not configuring via
  query param alone)
- `backend/tests/routes/test_concerts.py` — rewritten: test list pagination, stale
  trigger, detail from persisted data, 404 on unknown ID

## Interface sketch

```python
# models/concert.py (additions)
class ConcertListItem(BaseModel):
    id: str
    display_artist: str
    date: str
    date_precision: str  # "day" | "year"
    display_venue: str | None
    location: str | None
    recording_count: int
    preferred_recording_id: str

class ConcertListResponse(BaseModel):
    concerts: list[ConcertListItem]
    total: int
    page: int
    page_size: int

# ConcertDetailResponse keeps: id, artist, date, venue, location,
# preferred_recording_id, recordings[] (with source_quality + tracks[])
```

```python
# routes/concerts.py
@router.get("", response_model=ConcertListResponse)
async def list_concerts(
    artist: str,                        # canonical artist key
    page: int = 1,
    ia_client: IAClient = Depends(get_ia_client),
) -> ConcertListResponse: ...

@router.get("/{concert_id}", response_model=ConcertDetailResponse)
async def get_concert(concert_id: str) -> ConcertDetailResponse: ...
```

## Constraints to preserve

- See `workflow/CONVENTIONS.md` (always applicable)
- See `CLAUDE.md` § "Core constraints" (always applicable)
- All IA calls through injected `IAClient` — no ad-hoc HTTP
- Stream URLs are opaque strings (built during aggregation, passed through)
- `pytest` default run never hits IA — seed the repo with fixture aggregation data
- On-demand-when-stale: fresh means ≤ `aggregation_staleness_seconds` old; stale or
  absent triggers `aggregate_artist`. The endpoint must not block indefinitely on a
  slow IA — but Phase 2 timeout handling is acceptable as a log + 504 (not silent hang)

## Tests

- REQUIRED
- `test_concerts.py` — rewritten:
  - List: returns paginated concerts from pre-seeded DB; correct page/total math
  - List: stale or missing data triggers orchestration (mock `aggregate_artist`, verify called)
  - List: fresh data does NOT trigger orchestration
  - List: unknown artist returns empty list (not 404)
  - Detail: valid UUID returns full concert with recordings + tracks
  - Detail: unknown UUID returns 404
  - Detail: recordings ordered by source quality (SBD before AUD)
  - Detail: tracks include `stream_url` in expected format

## Known ambiguities / open questions

- **Artist param: canonical key vs display name?** Use canonical key (what `02-001`
  returns in `ArtistMatch.canonical_artist`). The client passes it opaquely from search
  results.
- **First-browse latency.** On-demand aggregation for a new artist hits IA (search +
  up to N metadata calls). This can take several seconds. Acceptable for Phase 2; a
  loading state on the client handles it. Future: background pre-aggregation for
  followed artists.

## Out of scope

- Client changes — separate packet (`02-004+`)
- Background/scheduled re-aggregation — on-demand only per resolved decision
- Concert search (`/search?type=concert`) — later packet (501 remains)
- Track search — later
- Pagination cursor-based (offset is fine at this scale)

## Summary output path

`workflow/packets/02-003-concert-list-endpoint.summary.md`
