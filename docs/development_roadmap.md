# TapeScrape Development Roadmap

Deliberately loose. The user has been burned by detailed specs (DB schemas, API
contracts, architecture diagrams) written before the first vertical slice ships. This is
a phased outline, not a plan of record.

**Core principle: each phase ends with something usable on the actual phone.** No phase
exists only to prepare the next. Don't start phase N+1 until phase N is honestly usable.

Owned by the orchestrator role (slimmed workflow). Sequencing and scope live here;
architecture/behavior intent lives in `docs/design/`; current status lives in
`docs/roadmap_status.md`. On conflict, `CLAUDE.md` § "If they conflict" governs.

Derived 2026-05-16 from `tape_scrape/04-roadmap-sketch.md` and `IDEA.md` § 8, reconciled
to the resolved decisions in `docs/design/04-OPEN-QUESTIONS.md` (thin FastAPI backend
exists; unified library; scoped track search).

---

## Phase 0 — Set the stage

- All Phase-0 inputs resolved (D1 = iOS 17, confirmed). No decision gates this phase.
- Xcode project skeleton: empty SwiftUI app, bottom-tab shell (Home/Search/Library
  stubs), runs on the real phone.
- **Install the four forward-compatibility hooks before any code crosses them**
  (`docs/design/00-ARCHITECTURE.md` § 3, `03-CLIENT-AND-PLAYBACK.md` § 3):
  `AudioStorage` protocol + trivial `Documents/`-backed default; `tapescrape://` URL
  scheme + routing layer; tag-first library model; repository pattern around the library
  DB. Trivial defaults only — no real implementations yet.
- Hello-world FastAPI backend running locally (`uvicorn`). One stub route. **Do not
  deploy.**
- Pick the single smallest Phase-1 vertical slice — one screen, one concert, one stream.
  Resist designing the whole navigation graph.

**Done when:** the project opens, runs an empty tabbed screen on the phone, the four
hooks are in place (defaults only), the backend runs locally, and the Phase-1 slice is
agreed.

## Phase 1 — One concert, end to end

Prove the IA path works in Swift on the phone, through the backend.

- Backend: one real endpoint that hits IA Advanced Search + Metadata for **one known
  concert** (e.g. Grateful Dead 1977-05-08), with the persistent cache wired
  (`docs/design/00` § 6). No aggregation polish yet — even returning the raw recordings
  for one hardcoded concert is fine.
- Backend host decision (D2b) lands here — deploy to the chosen host so the phone can
  reach a real URL, or stay local if Phase 1 is exercised on Wi-Fi only.
- Client: simplest screen showing that concert's recordings and track lists; play one
  track via `AVPlayer`, play/pause only.

**Don't yet:** search, browse, real aggregation, library, downloads, cover art,
navigation polish, error states beyond log-and-toast.

**Done when:** you tap a button on the phone, see a real concert, tap a track, hear it
stream from IA.

## Phase 2 — Browse, search, and a real player

Turn "one hardcoded concert" into a usable browser, with a player that does not repeat
the predecessor app's failures.

- Backend: artist search → list of canonical concerts; concert aggregation runs and
  **persists** (`docs/design/01-INTERNET-ARCHIVE.md` § 5,
  `02-DATA-MODEL.md` § 1). Start simple — even naive `artist|date` grouping is acceptable
  to begin; canonicalize artists/venues and compute the stored preferred recording as the
  data shows where it breaks. Decide the re-aggregation trigger (`04` open ambiguity 4).
- Client: search by artist; concert list; concert detail with recordings best-first.
  **Preferred version is tap-to-play; "Other versions" is a clearly secondary
  affordance, never a gate.**
- **Full-screen NowPlaying** (large art placeholder, scrubber, track list, source/
  lineage) in addition to the mini-player chip.
- **Explicit playback state machine** — loading/playing/stalled/failed always legible;
  failed tracks show retry; rapid retaps debounced (`03-CLIENT-AND-PLAYBACK.md` § 4).
- Aggressive prefetch + retry-with-backoff on streaming. Lock-screen / Control Center
  controls, scrubbing, skip, queue within a recording.

**Don't yet:** library persistence, downloads, cover art beyond placeholder, global
track search, queue editing beyond the current recording.

**Done when:** you can search a band you actually want, find a show, and play through it
like a real music app — and when streaming fails it says so instead of hanging silently.

## Phase 3 — Library, queue, and dynamic browse

Make it feel like *your* music app. Explicit fix for the predecessor's static,
playlist-less library.

- Favoriting (smallest thing first: a heart on concerts/recordings — a `favorite` tag in
  the tag-first model).
- Library tab that is **dynamic, not a flat list**: recently played, favorited-show
  anniversaries, artists engaged with, "more from this run/tour."
- Real queue management: reorder, play-next, add-to-end. "Save queue as playlist" is a
  stretch.
- Playlists across concerts (minimal: create / add / play) — the predecessor has none
  and the user cares.
- **D3 decision lands here:** local-only (default) vs CloudKit. If local-only, store via
  repositories and revisit sync later; the custom-zone-shaped container hook is already
  in place.
- Scoped per-track search: across tracks of recordings already opened
  (`docs/design/00` § 4). Persist the `track_index` table now.
- Smart collections / tags / notes: pick the essential subset (open ambiguity 1 — user
  call at this boundary; default favorites + minimal playlists, defer the rest).

**Don't yet:** downloads, real cover art.

**Done when:** the app remembers what you care about across launches, you can get back to
a show you liked without re-searching, and you can build and play a multi-show playlist.

## Phase 4 — Downloads and offline

It works on a plane.

- Background `URLSession` downloads; app-relaunch + partial-file recovery (the #3 known
  risk — budget for it).
- Local file management via `AudioStorage`: location, eviction, a storage-usage screen.
- Player falls back to local files transparently; Library shows a downloaded badge.
- Concert-level download grabs the preferred recording; advanced per-file/format drill-in.
- **Store files verbatim — no transcode/re-encode.** Where IA exposes a single uncut
  master, expose it as an alternate download target (future-F2 hook).
- Optional, only if the user supplies a setlist source decision (open ambiguity 2):
  IA-`description` setlist parse surfaced on concert detail. Any external service (e.g.
  Setlist.fm) requires an explicit authorization note against `CLAUDE.md` § "Network".

**Done when:** airplane mode + a downloaded recording = music plays, and a download
interrupted by a network drop recovers instead of getting stuck.

## Phase 5 — Cover art

The library looks like a record shelf.

- Short visual-design doc (separate file) with a few sketched looks **before** coding the
  generator. Needs the user's visual reference points (open ambiguity / D6).
- Implement the procedural `CoverRenderer` (default approach); render at multiple sizes;
  cache on disk by seed hash.
- Plug into NowPlaying artwork, library thumbnails, concert detail.

**Done when:** every concert has a distinct cover and you'd scroll the library just to
look at it.

## Phase 6 — Polish + TestFlight

Stop tinkering, start using.

- Error states everywhere they matter (IA outage, unsupported format, mid-stream drop).
- Gapless playback within a recording. Settings screen (audio-quality preference, storage
  usage, the static-secret config if used).
- Decide the "two builds" question only if review rejects a downloads-capable build
  (open ambiguity 3) — it's a feature flag, not an architecture.
- TestFlight build for personal install; decide whether to invite anyone (revisits D4
  only if yes).

**Done when:** TapeScrape is the app you reach for instead of whatever you use today.

---

## Not in this roadmap (deliberately)

- Designing the full DB schema up front. Each phase adds only the persistence it needs.
- Defining the full backend API in advance. Endpoints are added as the client needs them.
- Features nobody asked for: social, sharing, recommendations, year-in-review.
- Polishing screens not yet used.
- Anything in the `tape_scrape/05-future-developments` set: global per-track search,
  AI-assisted cutting, user re-cut editing UI, AI cover art, backend audio proxy,
  additional source catalogs, multi-app split, multi-user/sharing. v1 leaves the cheap
  hooks (verbatim files, uncut master, `CoverRenderer`, source-agnostic records,
  zone-shaped library container, `type=track` API) and builds none of them.

## When decisions are needed

| Decision | Needed by | Default if unanswered |
|---|---|---|
| D1 — minimum iOS | resolved | iOS 17 (confirmed) |
| D2b — backend host | Phase 1 (real URL) | local until then; Fly.io/Railway lean |
| D5 — library model | resolved | unified + pinned flag |
| D3 — CloudKit sync | Phase 3 | local-only v1 |
| Library subset depth | Phase 3 | favorites + minimal playlists |
| Setlist source | resolved | IA-description parse only; revisit if insufficient |
| D6 — cover art look | Phase 5 | procedural, after a sketch doc |
| "Two builds" | Phase 6 | one downloads-capable build; revisit on rejection |

If a decision isn't on this list, it doesn't need to be made yet.
