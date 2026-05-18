# Task Packet: Scoped per-track search

**Packet ID:** 03-006-track-search
**Phase:** 3
**Created:** 2026-05-18
**Status:** READY
**Auto-proceed:** true
**High-risk:** false

## Goal

Implement the scoped per-track search described in `00-ARCHITECTURE.md` § 4: "find every
show with Scarlet Begonias" across tracks of recordings already aggregated. The `tracks`
table is already populated by aggregation (`db/models.py`); the `type=track` branch of
`GET /search` currently returns 501. This packet wires the query, adds a response model,
and surfaces results in the client SearchTab. No new persistence — queries the existing
`tracks` table joined with `recordings` and `concerts`.

## Acceptance criteria

- [ ] Backend: `GET /search?type=track&q=<query>` returns a `TrackSearchResponse`
      containing matching tracks with concert/recording context. Query matches against
      `tracks.title` using case-insensitive `LIKE '%query%'`. Results ordered by concert
      date descending, limited to a configurable page size (default 50).
- [ ] `TrackSearchResponse` Pydantic model: `query`, `type`, `results: list[TrackMatch]`,
      `total: int`. `TrackMatch`: `title`, `filename`, `duration`, `stream_url`,
      `recording_identifier`, `concert_id`, `artist`, `date`, `venue`, `source_quality`.
- [ ] The `"track"` entry is removed from `_NOT_YET` in `routes/search.py`. The route
      dispatches on `type` to either the existing artist-search path or the new
      track-search path.
- [ ] Backend tests: track search returns results from the persisted `tracks` table;
      empty query or no matches returns empty results; results include correct
      concert/recording context from joins.
- [ ] Client: `TrackMatch` Codable struct + `TrackSearchResponse` model in
      `Models/Concert.swift`.
- [ ] `CatalogClient` gains `searchTracks(query:) async throws -> TrackSearchResponse`.
- [ ] SearchTab gains a **scope picker** (Picker/segmented control) to switch between
      "Artists" and "Tracks" search modes. In "Tracks" mode, results show track title,
      artist, date, and venue. Tapping a track result navigates to the concert detail.
- [ ] BUILD SUCCEEDED with zero errors. Existing tests still pass. New tests pass.

## Read first

> Floor (CLAUDE.md, CONVENTIONS.md, this packet) not relisted.

- `docs/design/00-ARCHITECTURE.md` § 4 — per-track search design and v1 scoping
- `docs/design/01-INTERNET-ARCHIVE.md` § 3.9 — IA track title limitation (why scoped)
- `backend/routes/search.py` — current search route with `_NOT_YET` stub for track
- `backend/db/models.py` — `TRACKS_TABLE` schema (already exists)
- `backend/db/repository.py` — existing DB query patterns
- `backend/models/search.py` — `ArtistSearchResponse` model to parallel
- `TapeScrape/Views/SearchTab.swift` — client search UI to extend
- `TapeScrape/Networking/CatalogClient.swift` — client API layer
- `TapeScrape/Models/Concert.swift` — where `TrackMatch` model goes

## Files expected to change

- `backend/models/search.py` — add `TrackMatch`, `TrackSearchResponse`
- `backend/routes/search.py` — implement `type=track` query; remove from `_NOT_YET`;
  add track-search function querying `tracks` JOIN `recordings` JOIN `concerts`
- `backend/routes/deps.py` — add `get_db_path` dependency if not already available
  (search route needs DB access for track queries)
- `TapeScrape/Models/Concert.swift` — add `TrackMatch`, `TrackSearchResponse`
- `TapeScrape/Networking/CatalogClient.swift` — add `searchTracks(query:)`
- `TapeScrape/Views/SearchTab.swift` — scope picker, track results list, navigation

## Interface sketch

```python
# models/search.py — new models
class TrackMatch(BaseModel):
    title: str | None
    filename: str
    duration: str | None
    stream_url: str
    recording_identifier: str
    concert_id: str
    artist: str
    date: str
    venue: str | None
    source_quality: str

class TrackSearchResponse(BaseModel):
    query: str
    type: str = "track"
    results: list[TrackMatch]
    total: int

# routes/search.py — track search query
async def _search_tracks(q: str, db_path: str, limit: int = 50) -> TrackSearchResponse:
    # SELECT t.title, t.filename, t.duration, t.stream_url,
    #        r.identifier, r.source_quality,
    #        c.id, c.display_artist, c.date, c.display_venue
    # FROM tracks t
    # JOIN recordings r ON t.recording_id = r.identifier
    # JOIN concerts c ON r.concert_id = c.id
    # WHERE t.title LIKE ? COLLATE NOCASE
    # ORDER BY c.date DESC
    # LIMIT ?
    ...
```

```swift
// Models/Concert.swift — new structs
struct TrackMatch: Codable, Hashable, Identifiable {
    var id: String { "\(recordingIdentifier)/\(filename)" }
    let title: String?
    let filename: String
    let duration: String?
    let streamUrl: String
    let recordingIdentifier: String
    let concertId: String
    let artist: String
    let date: String
    let venue: String?
    let sourceQuality: String
}

struct TrackSearchResponse: Codable {
    let query: String
    let type: String
    let results: [TrackMatch]
    let total: Int
}

// SearchTab.swift — scope picker
enum SearchScope: String, CaseIterable {
    case artists = "Artists"
    case tracks = "Tracks"
}
// .searchScopes($scope, scopes: { ... })
```

## Constraints to preserve

- See `workflow/CONVENTIONS.md` and `CLAUDE.md` § "Core constraints" (always applicable)
- `docs/design/01-INTERNET-ARCHIVE.md` — IA does not index track titles; the search
  queries only the local `tracks` table (populated by aggregation), not IA
- All SQL is parameterized — the `LIKE` query must use `?` binding, not string
  interpolation
- The search endpoint's `type` parameter shape (`artist | concert | track`) is preserved
  per `00-ARCHITECTURE.md` § 4 — "the shape must not foreclose F1"
- `concert` type remains 501 (out of scope for this packet)
- Stream URLs in results are opaque strings — client does not construct `archive.org`
  URLs
- Backend persistence is in the shared `cache_db_path` SQLite file
- Track search only finds tracks for artists that have been aggregated (browsed); this
  is the documented v1 scoping

## Tests

- REQUIRED
- `backend/tests/routes/test_search.py` (extend existing):
  - `type=track` returns `TrackSearchResponse` with matches from persisted tracks
  - `type=track` with no matches returns empty results list
  - `type=track` results include correct concert context (artist, date, venue)
  - `type=track` search is case-insensitive
  - `type=concert` still returns 501
- `TapeScrapeTests/` — no new Swift tests required (SearchTab is a view; track search
  exercises the same `CatalogClient.fetch` pattern already covered)

## Known ambiguities / open questions

- **Search ranking.** Simple `LIKE '%query%'` with `ORDER BY c.date DESC` is the
  minimal approach. A relevance ranking (exact match > starts-with > contains) could be
  added but is unnecessary at v1 scale where the user is searching their own browsed
  catalog. Keep it simple.
- **Pagination.** The first implementation uses a single-page result with a hard limit
  (50). Adding `page` parameter is trivial but deferred — the user's browsed catalog is
  unlikely to produce 50+ matches for a song title.
- **SearchTab scope picker UX.** SwiftUI offers `.searchScopes()` (iOS 16+) which
  renders a segmented control below the search bar. This is the cleanest option.
  Alternative: a Picker in the toolbar. Implementer's call.
- **`_ensure_tables` in search route.** The track-search query reads from tables created
  by `db/repository._ensure_tables`. If no artist has been aggregated yet, the tables
  don't exist and the query fails. The search function should call `_ensure_tables`
  (idempotent) or handle the missing-table case gracefully (return empty results).

## Out of scope

- Global track search (full catalog crawl — future F1)
- `type=concert` search (currently 501, separate packet)
- Track search result playback directly from search results (tap navigates to concert
  detail; playing from search results would need queue integration)
- Full-text search / FTS5 (overkill at v1 scale; revisit if `LIKE` is too slow)
- Search result caching (track queries are local SQLite, fast enough)
- Client-side track search (all queries go through the backend)

## Summary output path

`workflow/packets/03-006-track-search.summary.md`
