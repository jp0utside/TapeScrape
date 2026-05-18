# Summary: 02-003-concert-list-endpoint

**Status:** COMPLETE
**Date:** 2026-05-17

## What was built

- `GET /concerts?artist=<canonical_artist>&page=<n>` — paginated list endpoint backed by
  persisted aggregation. Returns `ConcertListResponse` with `concerts[]`, `total`, `page`,
  `page_size`. Default page size 20 (configurable via `concerts_page_size` in
  `core/config.py`).
- `GET /concerts/{concert_id}` — detail endpoint rewritten to load from
  `get_concert_by_id`. Returns `ConcertDetailResponse` with full recordings and tracks.
- On-demand-when-stale trigger: route checks `get_aggregation_age` directly; if absent
  or stale, calls `aggregate_artist` wrapped in `asyncio.wait_for(timeout=30s)`. Timeout
  → HTTP 504. Fresh data path skips `aggregate_artist` entirely (testable mock boundary).
- Phase 1 `_CONCERT_MAP`, `_cache`, `_build_tracks`, `_fetch_item`,
  `_recording_from_item` all removed from `routes/concerts.py`.
- `models/concert.py` updated: added `ConcertListItem`, `ConcertListResponse`,
  `ConcertDetailResponse` (renamed from `ConcertResponse`); added `source_quality: str`
  (enum `.name`) to `RecordingResponse`.

## Files changed

- `backend/routes/concerts.py` — full rewrite
- `backend/models/concert.py` — additions + rename
- `backend/core/config.py` — added `concerts_page_size: int = 20`
- `backend/tests/routes/test_concerts.py` — full rewrite (21 tests)

## Tests

21 route tests, all passing. Full suite: 122 passed + 2 live_ia skipped. No live IA
calls in default run. Tests use temp SQLite DB seeded with `AggregatedConcert` fixtures
and `monkeypatch` to redirect `settings.cache_db_path`. `aggregate_artist` mocked at
module level for stale/fresh/trigger tests.

## Deviations

None.

## Follow-ups / notes

- The `_MockSettings` class in the test file uses `concerts_page_size = 3` (not the
  production default of 20) to make pagination tests work with few fixtures. This is
  intentional test setup, not a production change.
- The Phase 1 `ConcertResponse` name is gone; any future reference should use
  `ConcertDetailResponse`.

## Status journal

`docs/roadmap_status.md` row for `02-003-concert-list-endpoint` updated to COMPLETE.
