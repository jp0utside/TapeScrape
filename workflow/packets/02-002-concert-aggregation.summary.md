# 02-002 Concert Aggregation — Implementation Summary

**Packet:** 02-002-concert-aggregation
**Status:** COMPLETE
**Date:** 2026-05-17

## What was delivered

The aggregation engine that groups flat IA items into canonical, persisted concerts with
source quality classification and a computed preferred recording. All acceptance criteria
met.

### New modules

- `backend/aggregation/venue.py` — Token-set similarity clustering (0.85 threshold) +
  alias map. `canonical_venue_key`, `cluster_venues`, `display_venue`.
- `backend/aggregation/source_quality.py` — `SourceQuality` IntEnum (SBD/MTX/AUD/FM/
  UNKNOWN) with regex parsing. MTX checked before SBD so "Matrix (SBD + AUD)" classifies
  correctly. "audience" added to AUD pattern.
- `backend/aggregation/aggregate.py` — Pure grouping logic. Concert key =
  `(canonical_artist, date, canonical_venue)`. UUID5 IDs. Year-only dates as separate
  tier. Preferred-recording pick: quality → track count → downloads.
- `backend/aggregation/orchestrate.py` — Top-level async: search IA → fetch metadata for
  top-3 items per date group → aggregate → persist. On-demand-when-stale (skips if fresh).
- `backend/db/models.py` — `CREATE TABLE` statements for `concerts`, `recordings`,
  `tracks`.
- `backend/db/repository.py` — `save_aggregation`, `get_concerts_for_artist`,
  `get_concert_by_id`, `get_aggregation_age`. Plain sqlite3, consistent with cache pattern.

### Config

- `backend/core/config.py` — added `aggregation_staleness_seconds: int = 3600`.

### Tests (49 new, 111 total pass, 3 skipped live_ia)

- `tests/aggregation/test_venue.py` — clustering, aliases, display pick (11 tests)
- `tests/aggregation/test_source_quality.py` — parametrized parsing (14 tests)
- `tests/aggregation/test_aggregate.py` — grouping, ordering, tiebreaks, edge cases (11)
- `tests/db/test_repository.py` — round-trip, resave, staleness, by-id (10 tests)

## Deviations

- **MTX before SBD in pattern order.** The packet's interface sketch implied SBD first;
  real data shows "Matrix (SBD + AUD)" must classify as MTX, not SBD. MTX is now checked
  first in the regex chain.
- **`audience` added to AUD pattern.** IA descriptions write "Audience recording" not
  just "AUD"; the regex now matches both.
- **No `is_marker` flag on tracks yet.** The data model doc mentions it; implementing the
  heuristic (detect "Tuning", "Crowd", set markers) is deferred — it's UI-facing and not
  needed until the client renders track lists.

## Follow-ups

- `02-003`: Wire `/concerts?artist=` endpoint backed by persisted aggregation +
  on-demand-when-stale trigger.
- Uncut master detection (mentioned in packet as deferred).
- `is_marker` track classification — when client track list lands.
- Venue alias map growth — append from real data evidence as artists are browsed.

## Notes

- Token-set similarity at 0.85 works well for the test cases (MSG variants, Red Rocks
  variants). May need tuning once real multi-artist data flows through.
- The `aggregate_items` function handles the "items without fetched metadata cluster with
  same-date items that have venue" case — avoids splitting concerts just because some
  recordings weren't in the sample.

---

**Status journal:** `docs/roadmap_status.md` row updated → COMPLETE.
