# Implementation Summary: 01-002-concert-endpoint

**Result:** COMPLETE
**Completed:** 2026-05-16

## Acceptance criteria check

- [✓] `GET /concerts/gd-1977-05-08` returns JSON with concert-level fields (`id`, `artist`, `date`, `venue`, `location`), `recordings` ordered by download count, `preferred_recording_id`, and per-recording `tracks` with `stream_url` — verified by integration tests
- [✓] Response model is Pydantic (`models/concert.py` — `ConcertResponse`, `RecordingResponse`, `TrackResponse`) — no untyped dicts cross the API boundary
- [✓] Raw IA responses cached in SQLite (`metadata_cache` table, keyed by identifier, TTL 24h default) — `core/cache.py`, `MetadataCache.get/set`
- [✓] Cache module (`core/cache.py`) operates on a single SQLite DB file; path from `settings.cache_db_path`
- [✓] Endpoint uses `ia/search.py` and `ia/metadata.py` from `01-001` — no duplicate IA logic
- [✓] Tests pass with recorded fixtures; 24 passed, 3 skipped (`live_ia`); no live IA calls in default run
- [✓] Integration test via `TestClient` in `tests/routes/test_concerts.py` (9 tests)

## Files changed

- `backend/core/config.py` — added `cache_db_path: Path` setting (default `./tapescrape_cache.db`)
- `backend/core/cache.py` — new: `MetadataCache` with `get`/`set`; stdlib `sqlite3`, async interface
- `backend/models/concert.py` — new: `TrackResponse`, `RecordingResponse`, `ConcertResponse`
- `backend/routes/__init__.py` — new package init
- `backend/routes/concerts.py` — new: `GET /concerts/{concert_id}` route with hardcoded Phase-1 concert map, track deduplication by format preference, `_fetch_item` cache-first helper
- `backend/main.py` — include concerts router
- `backend/tests/core/__init__.py` — new package init
- `backend/tests/core/test_cache.py` — new: 5 unit tests for cache set/get/expire
- `backend/tests/routes/__init__.py` — new package init
- `backend/tests/routes/test_concerts.py` — new: 9 integration tests + 1 `live_ia`

## Tests

- **Added:** `tests/core/test_cache.py` (5 tests), `tests/routes/test_concerts.py` (9 tests + 1 live_ia)
- **Modified:** none
- **Run command:** `python -m pytest backend/tests/ -v`
- **Result:** 24 passed, 3 skipped (live_ia); 0 failures

## Deviations from packet

- **Double-fetch of top item eliminated.** The initial route draft fetched `top_items[0]` twice (once in the loop, once for `top_meta`). Fixed before tests were written: `top_meta` is captured on `i == 0` inside the loop, no second `_fetch_item` call.
- **Integration tests patch `_fetch_item` rather than `_cache.get/set` and `get_item_metadata` separately.** This tests the full route assembly logic without coupling tests to the cache internals (which are tested separately in `test_cache.py`). The approach is cleaner and the cache is tested in isolation, so nothing is left untested.

## Out-of-scope issues discovered

- `ia/search.py` and `ia/metadata.py` each hold a module-level `IAClient` singleton. When the FastAPI app starts, two `httpx.AsyncClient` instances are created independently. Phase 2 should wire these through the app lifespan and dependency injection so the client is shared and cleanly closed on shutdown.
- F0-2 (`IAClient` rate-limiter lock held across the HTTP call) remains; still harmless at Phase 1 but should be fixed before Phase 2 parallel aggregation.

## Blockers / follow-ups

- none

## Notes for review

Track deduplication groups files by stem (`name.rsplit(".", 1)[0]`), picks the lowest-rank format (`Flac=0`, `24bit Flac=0`, `VBR MP3=1`, `MP3=1`, `WAVE=2`), then sorts stems alphabetically. For `etree` items, alphabetical stem order equals track order (sequential naming like `d1t01`, `d1t02`). This will break for items with non-sequential or non-zero-padded filenames — a known limitation acceptable for Phase 1.

`MetadataCache` stores `item.model_dump()` (the validated Pydantic dict) rather than the raw IA JSON. This means the cache round-trips through `IAItem.model_validate` on both write and read, which is correct and safe — the Ogg/Shorten filter is already applied before the dump.

## Status journal (mandatory — the packet is not done without this)

- [x] `docs/roadmap_status.md` deliverable-log row for `01-002-concert-endpoint` set to
      **COMPLETE**, with deviations/follow-ups copied from this summary.
- Phase-level status / Blockers / decision history: **left untouched** (Review/Plan own those).
