# Summary: 02-004-client-search-browse

**Status:** COMPLETE
**Date:** 2026-05-17

## What was built

- **`Models/Concert.swift`** — renamed `ConcertResponse` → `ConcertDetailResponse`; added
  `sourceQuality: String` to `RecordingResponse` (`downloadCount` retained — backend still
  sends it); added `ArtistMatch`, `ArtistSearchResponse`, `ConcertListItem`,
  `ConcertListResponse`. `ArtistMatch` and `ConcertListItem` are `Codable & Hashable`
  for `NavigationLink(value:)`.

- **`Networking/CatalogClient.swift`** — added `searchArtists(query:)`,
  `getConcerts(artist:page:)`, `getConcertDetail(id:)` using `URLComponents` for query
  params; extracted private `fetch<T>(_:url:)` to eliminate repetition; removed old
  `getConcert(id:)` slug-based method.

- **`Views/SearchTab.swift`** — rewritten: `.searchable(text:)` + `.onChange(of:)` with
  `Task.cancel + Task.sleep(300ms)` debounce; artist results list; `ContentUnavailableView`
  for empty state; `navigationDestination` for both `ArtistMatch` and `ConcertListItem`.

- **`Views/ConcertListView.swift`** — new: loads `getConcerts` on appear; date/venue/
  location rows; "Load more" button for pagination; `navigationDestination(for: ConcertListItem.self)`.
  Private `ConcertDetailLoaderView` fetches `getConcertDetail(id:)` then renders
  `ConcertDetailView`. Loading + empty state via `ContentUnavailableView`.

- **`Views/ConcertDetailView.swift`** — updated: `ConcertResponse` → `ConcertDetailResponse`;
  recording section header uses `recording.source ?? recording.sourceQuality`.

- **`Views/HomeTab.swift`** — updated: replaced live `getConcert("gd-1977-05-08")` fetch
  (which 404s since Phase 1 slugs are removed) with a hardcoded `ArtistMatch` for
  "Grateful Dead" that navigates to `ConcertListView`. Cornell '77 is reachable via the
  concert list.

- **`TapeScrapeTests/CatalogClientTests.swift`** — updated: fixture JSON updated
  (`source_quality` added, struct reference renamed); added 11 tests covering
  `ArtistSearchResponse`, `ConcertListResponse`, and `ConcertDetailResponse` decoding.

## Build and test results

- `xcodebuild BUILD SUCCEEDED` — zero errors, zero warnings
- 31 Swift Testing tests pass (up from 26; 5 new CatalogClient tests + 6 new decoding
  tests)

## Deviations

- `downloadCount` kept in `RecordingResponse` — the backend model I wrote in 02-003
  retains `download_count` in `ConcertDetailResponse`, so the field stays on the wire.
  The packet ambiguity note ("drops `download_count`") referred to the possibility it
  might be removed; it wasn't.

## Follow-ups / notes

- `ConcertListView` uses a "Load more" button (not infinite scroll) — per packet
  acceptance criteria, either is acceptable. Infinite scroll is a future refinement.
- `ContentUnavailableView.search(text:)` used for zero search results — iOS 17+ only,
  consistent with deployment target.
- `HomeTab` now navigates to the GD concert list rather than directly to Cornell '77.
  This is slightly more navigation but avoids maintaining a hardcoded UUID or doing a
  two-step fetch on app launch.

## Status journal

`docs/roadmap_status.md` row for `02-004-client-search-browse` updated to COMPLETE.
