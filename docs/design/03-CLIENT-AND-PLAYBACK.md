# 03 — Client & Playback

The iOS client *is* the product. The backend is plumbing; everything the user feels —
discovery, the player, the library, downloads, cover art — lives here. This doc covers
app structure, the four hooks in practice, the playback state machine (where the
predecessor app fails hardest), navigation, and offline-first behavior.

Behavior intent, not a frozen view hierarchy. Each phase builds only the screens it needs
(`development_roadmap.md`); resist designing the whole navigation graph up front.

---

## 1. Platform & stack

- **Swift / SwiftUI, iPhone.** Native chosen over cross-platform: the user has prior
  Swift/AVFoundation experience (Muze), "feels native on my phone" outranks Android
  reach, and the personal-use framing makes one good platform the right call.
- **Minimum iOS: 17** (default; confirm against the user's actual phone —
  `04-OPEN-QUESTIONS.md` D1). iOS 17 buys the `@Observable` macro and the modern
  `NavigationStack` / `.scrollPosition` APIs that materially simplify an app of this
  shape, at zero cost if the phone is already on 17+.
- **Persistence: SwiftData (or a thin SQLite wrapper) behind repositories** — never
  touched directly by feature code (§ 3, hook 4).
- Playback logic lives **outside view code** so an iPad/Mac shell could reuse it later
  (future F6; no v1 work, just hygiene).

## 2. App structure

```
TapeScrapeApp
 ├─ Navigation (URL-scheme-routed; bottom tab bar)
 │   ├─ Home      — dynamic shelves: recently played, favorited-show
 │   │              anniversaries, artists you've engaged with, "more from this run"
 │   ├─ Search    — artist / concert / (scoped) track
 │   └─ Library   — unified, tag-first; dynamic, not a flat list
 ├─ ConcertDetail — recordings best-first; preferred version is tap-to-play;
 │                   "Other versions" secondary; setlist/lineage info
 ├─ NowPlaying    — full-screen: large art, scrubber, queue, source/lineage,
 │                   legible playback state. Mini-player is its entry point.
 ├─ PlaybackCoordinator   (@Observable, @MainActor) — owns ALL playback state
 ├─ DownloadManager       — background URLSession; progress/pause/resume/retry
 ├─ AudioStorage          (protocol; default Documents-backed impl)
 ├─ CoverRenderer         (protocol; procedural impl in Phase 5)
 └─ Repositories          — Library / PlaybackHistory / Download / Catalog(API client)
```

Home and Library must feel **dynamic, not static** — a direct fix for the predecessor
app's flat, playlist-less, outdated-feeling library (`IDEA.md` motivation §8).

## 3. The four hooks, in practice

Installed in Phase 0 before any code crosses them (`00-ARCHITECTURE.md` § 3). Concretely
in the client:

1. **`AudioStorage` protocol.** Default impl writes
   `Documents/Recordings/<identifier>/<file>`. The download manager and the player read
   and write *only* through it. Nothing else knows where audio lives.
2. **URL scheme.** `tapescrape://concert/<id>`, `tapescrape://recording/<identifier>`
   route through the same navigation entry points used by taps. Powers notification /
   Shortcuts deep links now; the cross-app import path later.
3. **Tag-first library.** The Library tab is queries over the tag model
   (`02-DATA-MODEL.md` § 5). "Favorite" is a tag; a playlist is an ordered pair-list with
   a name tag; a smart collection is a saved query. One tag system, not three schemas.
4. **Repository pattern.** `PlaybackCoordinator`, views, and the download manager call
   repository protocols, never SwiftData/SQLite directly.

Do **not** add an App Group, IPC protocol, or plugin system in v1 — over-architecture is
the larger risk (`00-ARCHITECTURE.md` § 3).

## 4. Playback state machine (the part the predecessor app fails)

The predecessor app's worst sins: tracks hang silently, taps misfire to the wrong track,
no full-screen player, no legible state (`IDEA.md` § 01-product-goals motivation 1–5).
The architectural answer is an explicit, single-owner state machine.

- **One `PlaybackCoordinator`**, `@Observable` + `@MainActor`, owns *all* playback
  state. No other type mutates playback. (Muze-validated pattern.)
- **Explicit states, always rendered:** `idle → loading → playing → paused →
  stalled → failed(reason)`. Every state is visible on NowPlaying; `stalled`/`failed`
  carry a **retry affordance** instead of silence.
- **Debounced controls.** Rapid retaps on a slow connection collapse to one transition —
  a single track is never fired multiple times into IA (the misfire bug).
- **`AVPlayer` for both stream and local file** — pick one engine and keep it; the
  source (remote URL vs `AudioStorage` path) is the only difference.
- **Prefer local transparently.** If a recording is pinned/downloaded, the player uses
  the local file with no network fetch, regardless of how playback was initiated.
- **Resilient streaming:** aggressive prefetch/buffering ahead of position;
  retry-with-backoff on first byte; one timeout does not kill the stream
  (`01-INTERNET-ARCHIVE.md` § 3.11).
- **System integration:** `AVAudioSession` background-audio category configured at
  launch; `MPNowPlayingInfoCenter` (metadata + artwork); `MPRemoteCommandCenter`
  (play/pause/skip/scrub from lock screen, Control Center, AirPods); `UIBackgroundModes:
  audio` in `Info.plist`. Interruption/route-change handling (calls, AirPods disconnect)
  is explicitly budgeted hard time — it is the project's #1 known risk.
- **Queue is real:** reorder, play-next, add-to-end; "save queue as playlist" is a
  stretch within the library phase.

## 5. Downloads

- **Background `URLSession`** (`URLSessionConfiguration.background(withIdentifier:)`),
  app-relaunch handling, partial-file recovery — these lifecycle details are the #3 known
  risk; do not underestimate them.
- Concert-level "download" grabs the **preferred recording** automatically; advanced
  users can drill to per-file/format choice.
- Files stored verbatim via `AudioStorage` — **no transcode/re-encode on download**
  (preserves the future re-cut source, F2). Where IA exposes an uncut master, it is a
  selectable alternate download target.
- Downloaded recordings are clearly badged in the Library; the player auto-prefers them.

## 6. Offline-first behavior

- Cached browse/library data renders **immediately** on app open; fresh data refreshes in
  the background; every IA-derived screen has a manual refresh (TTLs are a floor).
- A downloaded recording is the canonical thing in the library — airplane mode + a
  downloaded show must play with no degradation and no stuck state.

## 7. Cover art

Behind a `CoverRenderer` protocol from the start; **procedural/deterministic** impl in
Phase 5 (hash `(artist, date, venue)` → palette + geometry + type; offline, free,
stable). Cloud/Core-ML generation (future F4) can swap the impl without touching anything
else. Cache rendered images on disk keyed by seed hash. A short visual-design doc is
written *before* the generator is coded — don't commit a look in prose first.

## 8. What the client does not do in v1

No accounts/auth, no social/sharing, no cross-catalog (global) track search, no
AI-assisted cutting, no user re-cut editing UI, no iPad/Mac/Watch/CarPlay targets. These
are `05-future-developments` items in the planning set; v1 leaves hooks for the ones we
want open (verbatim files, uncut master, `CoverRenderer`, source-agnostic records) and
builds none of them.
