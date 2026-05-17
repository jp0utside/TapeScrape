# Implementation Summary: 02-001-artist-search

**Result:** COMPLETE
**Completed:** 2026-05-17

## Acceptance criteria check

- [✓] `aggregation/canonicalize.py::canonical_artist_key` implements §5.1
  (lowercase → strip leading `the `/trailing `, the` → collapse `&`/`+`/`and` →
  strip punctuation → collapse whitespace → append-only alias map). Verified by
  `test_canonicalize.py` (GD/Phish/Ratdog variants, punctuation, empty).
- [✓] `display_artist(raw_names)` returns most common original casing; ties → first
  seen (`max` over insertion order). `test_display_artist_*`.
- [✓] `GET /search?type=artist&q=&page=` returns `ArtistSearchResponse`
  (`query`,`type`,`matches[]`); `ArtistMatch` has `canonical_artist`,
  `display_artist`, `recording_count`. `test_artist_search_collapses_to_canonical`.
- [✓] `type=concert`/`track` → HTTP 501 with structured `detail` naming where they
  land; unknown type → 422; missing `q` → 422. `test_*_501`,
  `test_unknown_type_is_rejected`, `test_missing_query_is_rejected`.
- [✓] `search_cache` SQLite table keyed by `sha256(type|q.strip().lower()|page)`,
  TTL `settings.search_cache_ttl_seconds` (1800); cache hit makes no IA call —
  `test_second_call_is_served_from_cache` asserts `mock.await_count == 1`.
- [✓] Endpoint uses lifespan `IAClient` via `Depends(get_ia_client)`; no module-level
  `IAClient()` (grep: only `main.py:14`). `get_ia_client` promoted to
  `backend/routes/deps.py`, imported by both `concerts.py` and `search.py`.
- [✓] All IA HTTP via the one client; `pytest` default = 62 passed, 3 skipped
  (live_ia); the prior 28 still pass.

## Files changed

- `backend/aggregation/__init__.py` — new package
- `backend/aggregation/canonicalize.py` — new: `canonical_artist_key`,
  `display_artist`, `_ARTIST_ALIASES` (seeded `jgb` only); pure, no I/O
- `backend/models/search.py` — new: `ArtistMatch`, `ArtistSearchResponse`
- `backend/routes/deps.py` — new: `get_ia_client` (moved from `concerts.py`)
- `backend/routes/concerts.py` — import `get_ia_client` from `routes.deps`; dropped
  the local copy and the now-unused `Request` import (no behaviour change)
- `backend/routes/search.py` — new: `GET /search`
- `backend/core/cache.py` — add `SearchCache` (distinct `search_cache` table, same DB)
- `backend/core/config.py` — add `search_cache_ttl_seconds: int = 1800`
- `backend/main.py` — include the search router

## Tests

- **Added:** `backend/tests/aggregation/__init__.py`,
  `backend/tests/aggregation/test_canonicalize.py` (parametrized key cases +
  variant-collapse + display casing/ties);
  `backend/tests/routes/test_search.py` (collapse, default type, cache-hit,
  variant creators, no-creator skip, 501s, 422s)
- **Modified:** `backend/tests/core/test_cache.py` (+`search_cache` fixture and
  set/get/expire/separate-table tests)
- **Run command:** `.venv/bin/python -m pytest backend/tests/ -q`
- **Result:** 62 passed, 3 skipped (live_ia). No live IA in the default run.

## Deviations from packet

- Dropped one planned canonicalize test case (`"Bob Weir &amp; RatDog"`): with the
  spec'd pipeline it normalizes to `bob weir andamp ratdog`, an unspecified
  HTML-entity edge. Asserting a contrived value would have been misleading; removed
  rather than encode behaviour the spec doesn't define. All spec'd variants covered.
- Search query is built as `creator:"q"` (passed `search_items(..., creator=q)`),
  not free-text `query=q` — `creator:` is the artist field (`01-INTERNET-ARCHIVE.md`
  §2.1) so it is the correct precision for artist search. Within packet intent.

## Out-of-scope issues discovered

- `routes/search.py` `_cache = SearchCache(...)` is the same module-global pattern as
  `routes/concerts.py:16` `_cache = MetadataCache(...)`. Deliberately kept consistent
  per packet scope; both remain candidates for the recorded post-Phase-1 follow-up to
  move caches onto `app.state`. No new debt — same pattern, now in two places, which
  is the natural trigger to revisit it at the Phase 2 review.
- `backend/ia/metadata.py:1` still imports unused `IAFile, IAItemMetadata`
  (pre-existing, noted in `01.5-001`; untouched — unrelated).

## Blockers / follow-ups

- None. `02-002` (concert grouping: canonical venue clustering, concert key,
  persistence, `SourceQuality`, preferred pick) can build on
  `aggregation/canonicalize.py` and the search/cache layer landed here.

## Notes for review

The `routes/deps.py` promotion happened exactly at the pre-registered "second
consumer" trigger from the `01.5-001` summary — worth a CONVENTIONS entry at the
Phase 2 review (DI provider in `routes/deps.py`, overridable via
`app.dependency_overrides`; the module-scope `TestClient` pattern needs the override
because no lifespan runs). `recording_count` is documented in the Pydantic field and
named in `test_*` as pre-aggregation (items in this response), not a catalog total —
guards the drift the packet flagged. The cache-isolation test fixture patches the
module-global `_cache` with a tmp `SearchCache`; if caches move to `app.state` later,
that override seam moves with them.

## Status journal (mandatory — the packet is not done without this)

- [✓] `docs/roadmap_status.md` deliverable-log row for `02-001-artist-search` set to
      **COMPLETE**, with deviations/follow-ups copied from this summary.
- Phase-level status / Blockers / decision history: **left untouched** (Review/Plan
  own those). The Phase 2 packet-plan table cell is a Plan-mode sequencing aid;
  updated to COMPLETE only to keep the status doc internally consistent.
