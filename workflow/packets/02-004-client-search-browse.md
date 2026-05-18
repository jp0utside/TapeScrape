# Task Packet: Client search + concert list

**Packet ID:** 02-004-client-search-browse
**Phase:** 2
**Created:** 2026-05-17
**Status:** READY
**Auto-proceed:** false
**High-risk:** false

## Goal

Replace the stub Search tab with a working artist search → concert list → concert detail
flow. After this packet, the user can type an artist name, see matching artists, tap one
to browse their concerts (paginated), and tap a concert to see the existing detail view
(recordings/tracks, tap to play).

This is the first real navigation flow in the app beyond the hardcoded Home tab button.

## Acceptance criteria

- [ ] **SearchTab** shows a search bar. Typing queries `GET /search?type=artist&q=...`
      (debounced ~300ms). Results display as a list of artist names with recording count
- [ ] Tapping an artist navigates to a **ConcertListView** showing that artist's concerts
      (from `GET /concerts?artist=<canonical_artist>`)
- [ ] Concert list shows: date, venue, location. Sorted chronologically (backend returns
      in date order). Pagination loads more on scroll (or a "Load more" button — either
      acceptable)
- [ ] Tapping a concert navigates to the existing **ConcertDetailView** (using the
      concert's UUID `id` → `GET /concerts/{id}`)
- [ ] **CatalogClient** gains methods: `searchArtists(query:)`, `getConcerts(artist:page:)`,
      `getConcertDetail(id:)` (replaces the old `getConcert(id:)` which used a slug)
- [ ] **Swift models** updated to match the new backend response shapes:
      `ConcertDetailResponse` (replaces `ConcertResponse`), `ArtistSearchResponse`,
      `ConcertListResponse`
- [ ] Loading states shown while awaiting network (a `ProgressView` is sufficient)
- [ ] Empty state for no search results / no concerts
- [ ] The Home tab's hardcoded "Play Cornell '77" button still works (update to use the
      new UUID-based concert ID from aggregation, or navigate via search — either fine)
- [ ] Swift tests: model decoding for new response shapes; basic view model state tests

## Read first

- `backend/models/concert.py` — the response shapes the client must decode
- `backend/models/search.py` — `ArtistSearchResponse` shape
- `TapeScrape/Networking/CatalogClient.swift` — current client (to extend)
- `TapeScrape/Models/Concert.swift` — current models (to update)
- `TapeScrape/Views/ConcertDetailView.swift` — existing view (reuse as-is or update for
  new field names)
- `docs/design/03-CLIENT-AND-PLAYBACK.md` § 2 (app structure / navigation)

## Files expected to change

- `TapeScrape/Models/Concert.swift` — update/add: `ConcertDetailResponse` (rename from
  `ConcertResponse`), `ConcertListItem`, `ConcertListResponse`, `ArtistMatch`,
  `ArtistSearchResponse`
- `TapeScrape/Networking/CatalogClient.swift` — add: `searchArtists`, `getConcerts`,
  `getConcertDetail`; remove or rename old `getConcert`
- `TapeScrape/Views/SearchTab.swift` — rewrite: search bar + artist results list +
  navigation
- `TapeScrape/Views/ConcertListView.swift` — new: paginated concert list for one artist
- `TapeScrape/Views/ConcertDetailView.swift` — update to accept `ConcertDetailResponse`
  (field name changes: `artist` → `artist`, but `source_quality` is new, old
  `downloadCount` gone from the detail response shape)
- `TapeScrape/Views/HomeTab.swift` — update: Cornell '77 navigation to use new ID
  or remove if redundant with search
- `TapeScrapeTests/CatalogClientTests.swift` — update: new response decoding tests
- `TapeScrapeTests/SearchViewModelTests.swift` — new (if a view model is extracted)

## Interface sketch

```swift
// Models (additions)
struct ArtistMatch: Codable {
    let canonicalArtist: String
    let displayArtist: String
    let recordingCount: Int
}

struct ArtistSearchResponse: Codable {
    let query: String
    let type: String
    let matches: [ArtistMatch]
}

struct ConcertListItem: Codable {
    let id: String
    let displayArtist: String
    let date: String
    let datePrecision: String
    let displayVenue: String?
    let location: String?
    let recordingCount: Int
    let preferredRecordingId: String
}

struct ConcertListResponse: Codable {
    let concerts: [ConcertListItem]
    let total: Int
    let page: Int
    let pageSize: Int
}

struct ConcertDetailResponse: Codable {
    let id: String
    let artist: String
    let date: String
    let venue: String?
    let location: String?
    let preferredRecordingId: String
    let recordings: [RecordingResponse]
}
```

```swift
// CatalogClient additions
func searchArtists(query: String) async throws -> ArtistSearchResponse
func getConcerts(artist: String, page: Int = 1) async throws -> ConcertListResponse
func getConcertDetail(id: String) async throws -> ConcertDetailResponse
```

```swift
// SearchTab — NavigationStack with .searchable
struct SearchTab: View {
    @State private var query = ""
    @State private var results: [ArtistMatch] = []
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            List(results, id: \.canonicalArtist) { artist in
                NavigationLink(value: artist) { ... }
            }
            .navigationDestination(for: ArtistMatch.self) { artist in
                ConcertListView(artist: artist)
            }
            .searchable(text: $query)
        }
    }
}
```

## Constraints to preserve

- See `workflow/CONVENTIONS.md` (always applicable)
- See `CLAUDE.md` § "Core constraints" (always applicable)
- Client never constructs `archive.org` URLs — stream URLs from backend only
- Navigation uses `NavigationStack` + typed `navigationDestination` (iOS 17)
- CatalogClient remains the sole network-touching type for catalog data
- Playback logic stays in PlaybackCoordinator — views don't touch AVPlayer
- Tests don't hit the network — use fixture JSON or mock URLSession

## Tests

- REQUIRED
- Decoding tests: `ArtistSearchResponse`, `ConcertListResponse`, `ConcertDetailResponse`
  from fixture JSON matching real backend shape
- View model / state tests if a view model is extracted (optional — `@State` in view is
  acceptable for Phase 2 given the simplicity)

## Known ambiguities / open questions

- **Debounce approach.** `task.cancel` on new input + `Task.sleep(300ms)` before calling
  API is the simplest iOS 17 pattern. No external dependency needed.
- **Pagination UX.** Infinite scroll via `.onAppear` of last item vs explicit "Load more"
  button. Either is fine for Phase 2; infinite scroll is slightly better UX but more
  complex.
- **Home tab fate.** The hardcoded "Play Cornell '77" can either stay (updated to use the
  aggregated UUID) or be replaced with a "recently browsed" placeholder. Keeping it
  working is the only requirement.
- **RecordingResponse field changes.** The backend now includes `source_quality: str` and
  drops `download_count` on the detail response. The client model must match. Confirm the
  exact wire shape before decoding.

## Out of scope

- Full-screen NowPlaying view — separate packet
- Lock screen controls / MPRemoteCommandCenter — separate packet
- Playback queue / sequential track play — separate packet
- Library / favorites — Phase 3
- Error handling beyond showing empty/loading states — later
- Concert search (`/search?type=concert`) — not yet implemented on backend

## Summary output path

`workflow/packets/02-004-client-search-browse.summary.md`
