# Task Packet: Client playback — concert detail screen + stream from IA

**Packet ID:** 01-003-client-playback
**Phase:** 1
**Created:** 2026-05-16
**Status:** READY
**Auto-proceed:** false
**High-risk:** true

## Goal

Close the Phase 1 vertical slice: the user taps a button on the phone, sees a real
concert's recordings and tracks fetched from the backend, taps a track, and hears it
stream from archive.org via AVPlayer.

This is the first time audio plays in the app. It proves the full IA path works end to
end: backend → client → stream. After this packet, Phase 1's "done when" criterion is
met.

## Acceptance criteria

- [ ] A `CatalogClient` (or similar) fetches `GET /concerts/gd-1977-05-08` from the
      backend, decodes to typed Swift models, and is the app's only network-touching
      type for catalog data
- [ ] A **ConcertDetailView** shows: artist, date, venue, and a list of recordings with
      their tracks. Tracks show title (or filename if no title), duration, and a tap
      affordance
- [ ] Tapping a track starts streaming via `AVPlayer` — audio is audible on device
- [ ] A **PlaybackCoordinator** (`@Observable`, `@MainActor`) owns playback state:
      `idle | loading | playing | paused | failed(Error)`. No other type mutates the
      player
- [ ] A minimal **mini-player** bar (track title + play/pause) appears at the bottom when
      playback is active, persists across tabs
- [ ] Play/pause works; tapping another track replaces the current one
- [ ] `AVAudioSession` is configured for `.playback` category so audio continues when the
      app is backgrounded (requires `UIBackgroundModes: audio` in Info.plist)
- [ ] The Home tab provides navigation to the test concert (a "Play Cornell '77" button
      or similar — just enough to reach the detail screen)
- [ ] Swift tests: `CatalogClient` decoding test with a fixture JSON; `PlaybackCoordinator`
      state transitions tested with a mock/stub player

## Read first

- `docs/design/03-CLIENT-AND-PLAYBACK.md` § 1–4 (app structure, hooks, playback state
  machine)
- `docs/design/00-ARCHITECTURE.md` § 3 (the four hooks — respect existing protocol shapes)
- `backend/models/concert.py` — the response shape the client must decode
- `backend/routes/concerts.py` — to understand what the endpoint returns
- `TapeScrape/Storage/AudioStorage.swift` — existing protocol (don't bypass for streaming)
- `TapeScrape/Navigation/DeepLinkRouter.swift` — existing router (don't duplicate routing)

## Files expected to change

- `TapeScrape/Networking/CatalogClient.swift` — new: API client for backend catalog endpoints
- `TapeScrape/Models/Concert.swift` — new: `Concert`, `Recording`, `Track` Codable structs
  matching the API response
- `TapeScrape/Playback/PlaybackCoordinator.swift` — new: `@Observable` playback state
  machine wrapping AVPlayer
- `TapeScrape/Views/ConcertDetailView.swift` — new: recordings + track list UI
- `TapeScrape/Views/MiniPlayerView.swift` — new: persistent bottom bar during playback
- `TapeScrape/Views/HomeTab.swift` — modified: add navigation to test concert
- `TapeScrape/TapeScrapeApp.swift` — modified: inject PlaybackCoordinator into environment,
  add mini-player overlay, configure AVAudioSession
- `TapeScrape/Info.plist` or project settings — `UIBackgroundModes: audio`
- `TapeScrapeTests/CatalogClientTests.swift` — new: decoding test
- `TapeScrapeTests/PlaybackCoordinatorTests.swift` — new: state transition tests

## Interface sketch

```swift
// Models/Concert.swift
struct ConcertResponse: Codable {
    let id: String
    let artist: String
    let date: String
    let venue: String?
    let location: String?
    let preferredRecordingId: String
    let recordings: [RecordingResponse]
}

struct RecordingResponse: Codable {
    let identifier: String
    let source: String?
    let taper: String?
    let lineage: String?
    let downloadCount: Int
    let tracks: [TrackResponse]
}

struct TrackResponse: Codable {
    let index: Int
    let title: String?
    let filename: String
    let duration: String?
    let streamUrl: String
}
```

```swift
// Playback/PlaybackCoordinator.swift
@Observable
@MainActor
final class PlaybackCoordinator {
    enum State { case idle, loading, playing, paused, failed(Error) }

    private(set) var state: State = .idle
    private(set) var currentTrack: TrackResponse?

    func play(_ track: TrackResponse) { ... }
    func togglePlayPause() { ... }
    func stop() { ... }
}
```

```swift
// Networking/CatalogClient.swift
actor CatalogClient {
    func getConcert(id: String) async throws -> ConcertResponse { ... }
}
```

## Constraints to preserve

- See `workflow/CONVENTIONS.md` (always applicable)
- See `CLAUDE.md` § "Core constraints" (always applicable)
- **Client never constructs `archive.org` URLs** — stream URLs are opaque strings from the
  backend response. The client passes them directly to AVPlayer
- **Audio streams directly from IA** — no backend proxy
- **Playback logic lives outside view code** — PlaybackCoordinator is the single owner;
  views observe it
- **AudioStorage protocol is not bypassed** — streaming uses URLs (not files), so it
  doesn't go through AudioStorage (that's for downloaded files only). But do not create a
  parallel file-write path that circumvents it
- **Repository pattern** — CatalogClient is the catalog repository for remote data;
  local persistence (library) stays behind LibraryRepository
- Swift tests do not hit the network or real backend — use fixture JSON / mock URLSession

## Tests

- REQUIRED
- `TapeScrapeTests/CatalogClientTests.swift` — decode a fixture JSON matching the real
  backend response shape into typed Swift models; verify field mapping (especially
  `snake_case` → `camelCase` via `keyDecodingStrategy` or `CodingKeys`)
- `TapeScrapeTests/PlaybackCoordinatorTests.swift` — test state transitions: idle → loading
  → playing; play → pause; play track A then play track B (replaces); test that `failed`
  state is reachable

## Known ambiguities / open questions

- **Backend URL configuration.** For Phase 1 (Wi-Fi only), a hardcoded `localhost:8000`
  or a `#if DEBUG` compile-time constant is fine. A config/environment approach can wait
  for deployment in Phase 2.
- **Mini-player vs NowPlaying.** Phase 1 only needs the mini-player bar. The full-screen
  NowPlaying view (scrubber, queue, artwork) is Phase 2 scope.
- **Playback of full recording vs single track.** Phase 1: tap plays one track. Phase 2
  adds sequential playback / queue through the recording. Keep the coordinator's API
  shaped for a queue (accept a track list) even if Phase 1 only ever passes one track.
- **Error UI.** Phase 1: a failed state shows in the mini-player (text or icon). No retry
  button, toast, or modal — just legible state. Phase 2 adds retry affordance.

## Out of scope

- Full-screen NowPlaying view — Phase 2
- Lock screen / Control Center controls (MPRemoteCommandCenter) — Phase 2
- Sequential playback / queue — Phase 2
- Search, browse, artist listing — Phase 2
- Downloads / offline playback — Phase 4
- Cover art — Phase 5
- Real error handling beyond state visibility — Phase 2
- Backend deployment / non-localhost URL — separate task (D2b)

## Summary output path

`workflow/packets/01-003-client-playback.summary.md`
