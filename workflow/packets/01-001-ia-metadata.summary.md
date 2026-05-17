# Implementation Summary: 01-001-ia-metadata

**Result:** COMPLETE
**Completed:** 2026-05-16

## Acceptance criteria check

- [✓] `ia/search.py` — async `search_items()` calling IA Advanced Search, returns `IASearchResult`
- [✓] `ia/metadata.py` — async `get_item_metadata()` calling IA Metadata, returns `IAItem`
- [✓] `models/ia.py` — Pydantic models `IASearchItem`, `IASearchResult`, `IAFile`, `IAItemMetadata`, `IAItem`; Ogg Vorbis and Shorten dropped via `field_validator` on `IAItem.files`
- [✓] Both functions go through `core/http_client.py` — no direct `httpx` usage
- [✓] Recorded fixtures: `gd1977-05-08_search.json` (8 items, real IA response) and `gd1977-05-08.aud.moore.berger.28354.flac16_metadata.json` (151 raw files, 151KB) under `backend/tests/fixtures/`
- [✓] `pytest` passes using fixtures only; 10 passed, 2 skipped — no live IA call in default run
- [✓] `live_ia` marker already registered in `pyproject.toml` (Phase 0 work); one `@pytest.mark.live_ia` test per module, skipped by default, runnable with `pytest -m live_ia`

## Files changed

- `backend/models/__init__.py` — new package init
- `backend/models/ia.py` — new: Pydantic models for IA responses
- `backend/ia/__init__.py` — new package init
- `backend/ia/search.py` — new: Advanced Search wrapper
- `backend/ia/metadata.py` — new: Metadata API wrapper
- `backend/tests/fixtures/gd1977-05-08_search.json` — new: recorded search response (8 items)
- `backend/tests/fixtures/gd1977-05-08.aud.moore.berger.28354.flac16_metadata.json` — new: recorded metadata response
- `backend/tests/helpers.py` — new: `load_fixture()` helper shared across test modules
- `backend/tests/conftest.py` — new: `live_ia` skip hook + marker registration (marker itself pre-existed in pyproject.toml)
- `backend/tests/ia/__init__.py` — new package init
- `backend/tests/ia/test_search.py` — new: 3 fixture-based tests + 1 live_ia
- `backend/tests/ia/test_metadata.py` — new: 6 fixture-based tests + 1 live_ia

## Tests

- **Added:** `tests/ia/test_search.py` (4 tests), `tests/ia/test_metadata.py` (7 tests)
- **Modified:** none
- **Run command:** `python -m pytest backend/tests/ -v`
- **Result:** 10 passed, 2 skipped (live_ia); 0 failures

## Deviations from packet

- **Fixture identifier differs from packet spec.** The packet specified `gd1977-05-08.sbd.miller.20453.flac16` as the metadata fixture target. That identifier returned `{}` from the IA Metadata API (item excluded by `stream_only` filter or no longer public). Replaced with `gd1977-05-08.aud.moore.berger.28354.flac16`, which was in the actual search results and returned a full response. The packet's search query (`AND NOT collection:stream_only`) correctly excludes the original identifier — this is consistent behavior, not a bug.
- **`load_fixture` placed in `tests/helpers.py` not `conftest.py`.** The packet sketched it as a conftest helper; importing directly from `conftest.py` doesn't work cleanly across sub-packages (`tests/ia/` can't do `from tests.conftest import ...`). A separate `helpers.py` is the standard pattern.
- **`IAItem.model_validate(data)` used end-to-end** rather than constructing `IAItemMetadata` and `list[IAFile]` separately before passing to `IAItem`. This is cleaner: the `field_validator(mode="before")` on `IAItem.files` receives raw dicts, which is what it expects. Pre-parsing to `IAFile` objects before construction caused `.get()` attribute errors in the validator.

## Out-of-scope issues discovered

- F0-2 confirmed still present: `IAClient._lock` held across the HTTP call in `http_client.py:39–45`. Harmless at single-caller Phase 1 scale; fix before Phase 2 parallel aggregation.
- `ia/search.py` uses a module-level `IAClient` singleton. Fine for now; Phase 2 should inject it via app lifespan/dependency injection when the FastAPI app manages the client lifecycle.

## Blockers / follow-ups

- none

## Notes for review

The IA Metadata response shape is flat: `{"metadata": {...}, "files": [...], "created": ..., "d1": ..., ...}`. `IAItem.model_validate(data)` works directly because Pydantic ignores extra top-level fields by default. No schema gymnastics needed.

`IAFile.length` is heterogeneous across formats: FLAC files use float-as-string seconds (`"312.02"`), VBR MP3 uses `"MM:SS"` (`"05:12"`). Kept as `str` per packet spec; normalization deferred to Phase 2 when the player needs duration math.

## Status journal (mandatory — the packet is not done without this)

- [x] `docs/roadmap_status.md` deliverable-log row for `01-001-ia-metadata` set to
      **COMPLETE**, with deviations/follow-ups copied from this summary.
- Phase-level status / Blockers / decision history: **left untouched** (Review/Plan own those).
