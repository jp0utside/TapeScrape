# Packet Summary: 03-006-track-search

**Status:** COMPLETE
**Date:** 2026-05-18

## What was delivered

- `backend/models/search.py` — added `TrackMatch` and `TrackSearchResponse` Pydantic models
- `backend/routes/deps.py` — added `get_db_path()` dependency returning `str(settings.cache_db_path)`
- `backend/routes/search.py` — implemented `_search_tracks()` with parameterized JOIN query; removed `"track"` from `_NOT_YET`; route dispatches `type=track` to track path; route return type is `ArtistSearchResponse | TrackSearchResponse`
- `backend/tests/routes/test_search.py` — replaced `test_track_type_is_honest_501` with 5 new track-search tests (matches, no-matches, concert context, case-insensitive, empty DB); added `_seed_track_db` helper; injected `get_db_path` override in `_isolate` fixture
- `TapeScrape/Models/Concert.swift` — added `TrackMatch` and `TrackSearchResponse` Codable structs
- `TapeScrape/Networking/CatalogClient.swift` — added `searchTracks(query:) async throws -> TrackSearchResponse`
- `TapeScrape/Views/SearchTab.swift` — added `SearchScope` enum; scope picker via `.searchScopes()`; track results list with `TrackRow`; navigation to concert detail via `String` (concertId) navigation destination

## Test results

- 13 backend route/search tests pass (5 new, 8 existing)
- Full suite: 125 pass, 2 skipped (12 pre-existing failures in `test_cache.py`/`test_http_client.py` unrelated to this packet)
- BUILD SUCCEEDED (zero errors)

## Deviations

None. All acceptance criteria met as specified.

## Notes

- `source_quality` is stored as `IntEnum` in the DB; serialized to `.name` (e.g., `"SBD"`) in `TrackMatch.source_quality`, consistent with `concerts.py` route
- `_ensure_tables()` is called at the top of `_search_tracks` (idempotent); handles the no-tables case by returning empty results on a fresh DB
- `.searchScopes()` (iOS 16+) renders below the search bar as a segmented control — cleanest UX per the packet's ambiguity note
- `concert` type remains 501 (out of scope)

## Status journal

Packet row in `docs/roadmap_status.md` updated to COMPLETE. ✓
