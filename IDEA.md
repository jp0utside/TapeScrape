# IA Live Music App — IDEAS.md

> **Purpose of this document.** This file is the seed for a new project: a mobile-first app to browse, stream, download, and play back live music recordings from the Internet Archive (specifically the etree and Live Music Archive collections). It captures _why_ the project exists, _what_ it needs to do, _what decisions have already been made_ in prior conversations, and a _medium-altitude development plan_. It is not a spec — it is the input to writing a spec.

---

## 1. Motivation

The Internet Archive's web UI for live music is functional but actively painful on mobile:

- Discovery is keyword-driven and assumes you already know what you're looking for.
- The browse / collection pages do not adapt well to a phone — small touch targets, dense metadata tables, side-scrolling links to track lists.
- There is no concept of a "concert" as a first-class object. Every show is N+ separate recordings (different tapers, different sources) and the UI presents them flat.
- Streaming works but the player is a basic HTML5 audio element with no queue, no background playback, no offline mode, no track-level navigation polish.
- Downloads require knowing which format you want (FLAC vs MP3 vs Ogg vs SHN), navigating to the item page, and tapping individual file links.
- No library / "things I've listened to or saved" persistence beyond browser history.

Existing third-party solutions (mobile Archive apps, generic etree browsers) are either abandoned, desktop-only, or stop short of the full browse → stream → download → library loop.

**Personal use is the primary goal.** This is something I want to actually use. It is not the job-search flagship project (that role is reserved for the AI/RAG work). Decisions throughout this document should be made on the axis of "is this useful to me on my phone tonight?" not "is this impressive to a hiring manager?" — though the project may still produce portfolio value as a side effect.

---

## 2. Scope at a Glance

**In-scope (MVP):**

- Browse the Internet Archive etree / Live Music Archive collections from a mobile app.
- Aggregate raw IA "items" into the concept of a "concert" (one artist, one date, possibly one venue) with N recordings underneath.
- Stream individual recordings or tracks with a real player (queue, background audio, lock-screen controls).
- Download recordings or full concerts for offline listening.
- A local library: history, downloads, "saved" / starred concerts and recordings.

**In-scope (post-MVP, eventual):**

- App Store / TestFlight distribution for personal use across my own devices (and friends who want it).
- Cross-platform: iOS first, Android second. Web a distant maybe.
- Lightweight "now playing" recommendations and discovery surfaces.

**Out of scope (explicitly):**

- Replacing the Internet Archive. The app is a client; IA stays the source of truth.
- Hosting or mirroring IA audio files. Streaming is always from IA (with a local download cache for offline use).
- User accounts, social features, sharing, comments. Personal-use-first means no multi-user complexity.
- AI / LLM features at MVP. This is intentionally a _non-AI_ project — the goal is a great IA client, not another RAG demo. (See §10 for where AI could come back later as an enhancement.)
- Replacing Setlist.fm. SetlistAI handles the setlist-Q&A use case; this app is about listening to the actual audio.

---

## 3. Personal Requirements (What I Actually Want)

These are mine, not negotiable, and the design should bend to satisfy them:

1. **The home screen should feel like a music app, not a search engine.** Open the app → see recent concerts, recently played, things I've saved. Search is a path, not the front door.
2. **A concert is a first-class object.** When I tap a concert, I see the concert (artist, date, venue, setlist if available) — _then_ I choose which recording to listen to. The "which taper / which source" decision is one tap deep, not the front door.
3. **Streaming must just work.** Tap → audio plays in <2 seconds → continues when I lock my phone or switch apps → lock-screen controls work → bluetooth / AirPods controls work.
4. **Downloads must be obvious.** A download button at the concert level grabs the best available source automatically. Advanced users can drill into per-file format choice. Downloaded shows are clearly marked in the UI and available offline with no degradation.
5. **A library tab.** Everything I've downloaded, played, or saved is here. Sortable, searchable, organized by artist and date.
6. **No login.** Personal-use app. Persistent local state, no accounts, no cloud sync at MVP.
7. **Offline-first behavior where possible.** Cached browse data shows immediately on app open; fresh data loads in the background. Downloaded audio is the canonical thing in the library.
8. **Phone-first ergonomics.** Big touch targets. Thumb-reachable controls. Bottom-tab navigation. No tiny links.
9. **Setlist data when available.** If a setlist exists (from IA's metadata, Setlist.fm, or my own SetlistAI corpus), surface it on the concert page with track-by-track alignment where possible. This is a nice-to-have, not a blocker.
10. **It has to be fast.** No spinners longer than ~1.5s on a warm cache. The IA site's slowness on mobile is half of what makes it unusable.

---

## 4. What Already Exists — and What's Wrong With It

A previous project (`SetScrape`) attempted a version of this. Honest assessment from the dossier:

**What SetScrape got right and can be reused conceptually:**

- Pulling from the IA Advanced Search API with caching is the correct approach (vs. trying to mirror the collection).
- Aggregating IA items into "concerts" by `artist|YYYY-MM-DD` is a workable heuristic.
- Tiered caching (persistent + in-memory) for the aggregation results is the right pattern.
- Concert-level vs. recording-level distinction is the right data model.
- Venue extraction from IA title strings via regex with fallbacks (description scan, keyword matching) is a real piece of work worth carrying forward.

**What SetScrape got wrong and should not be repeated:**

- **Four microservices for a solo project was overkill.** A single FastAPI app or even a serverless function set is the right level of complexity. The microservices added inter-service HTTP, auth-forwarding bugs, duplicated CORS config, and a SQLite single-writer lock that prevented the alleged scaling benefits. Build it as a monolith first.
- **Documentation drift.** SetScrape's README claimed WebSocket download progress and offline playback that didn't exist in code. Don't write docs ahead of code on this project.
- **Dead schema.** `AggregatedConcert` and `ConcertRecording` tables existed but were never written to (aggregation was in-memory only). Either persist concerts or don't have the schema.
- **Auth complexity for a no-auth use case.** JWT, bcrypt, in-memory SessionManager — all for a single-user personal app. Skip.
- **iOS-only with a hardcoded `localhost` API base URL.** The mobile app needs to talk to a deployed backend, not localhost. Design for a real deployed backend from day one (even if "deployed" is just a small VPS or a serverless endpoint).
- **No audio playback was ever built.** Downloads worked, playback didn't. This time, playback is core, not afterthought.

**Verdict:** Treat SetScrape as a paper prototype for the data model and IA-integration logic. Do not extend the existing codebase. Start fresh.

---

## 5. Key Decisions Already Made (From Prior Conversations)

These were established in prior chats and should be preserved unless explicitly revisited:

1. **This project is on the slower track.** The job-search flagship is the county RAG work (chat-jpt v3) and SetlistAI v2. This IA app is the _personal-use_ project that may earn portfolio value but is not optimized for it.
2. **App Store deployment is acceptable as a personal-use goal.** It is _not_ acceptable as a portfolio shortcut — App Store presence reads as "this person ships mobile apps," not "this person does AI engineering," and the apprentice-level yak-shaving (Apple Developer account, provisioning, screenshots, app review, privacy nutrition labels) is weeks of work that doesn't move the job-search needle. So: ship it to the App Store / TestFlight for personal use, but don't make App Store readiness a milestone gate.
3. **The "music ecosystem" framing (Muze + Tagify + SetScrape unified) was rejected.** Reasons: (a) the unification story is too complicated to explain in 90 seconds; (b) none of the three component apps was individually strong enough to anchor a unified product; (c) it conflates "I want this for me" with "this is my job-search artifact." This new project replaces the SetScrape leg of that triad and stands alone. Muze and Tagify continue on their own tracks if at all.
4. **AI is not an MVP feature.** The temptation to bolt LLMs onto everything is real; resist it here. The IA app's value is a great listening experience. AI can come back later (§10) as a specific feature with a specific job to do.
5. **Setlist data integration is desirable but not the core loop.** The audio is the product. Setlists enrich the audio. Don't let setlist-correlation work block streaming/library work.
6. **Personal use first, then friends, then strangers.** Don't design for scale you don't have. SQLite + a single backend is fine. Don't reach for Postgres, Redis, Pinecone, or anything else until the single-machine version has been used daily for a month.

---

## 6. Architecture (Medium-Altitude)

A two-tier system: **backend** that mediates IA, **client** that's a mobile app.

### 6.1 Backend

**One service, not four.** Python + FastAPI, single deployable. SQLite for persistence (local file) at MVP; revisit only if the data outgrows it (it won't, for a personal-use app).

Responsibilities:

- IA Advanced Search proxy with caching (the cache is the whole point — IA is slow and rate-limited; we hit it once and serve N clients from cache).
- Concert aggregation: group IA items by `artist|YYYY-MM-DD`, determine venue by majority vote, extract metadata from titles and descriptions.
- Metadata pass-through for individual items (track listings, available formats, file sizes).
- Optional: setlist correlation (look up Setlist.fm or local setlist data for a given artist/date and attach to the concert payload).
- No auth. No users. No sessions. The backend is single-tenant.

What the backend does _not_ do:

- Serve audio. Audio URLs are passed through from IA; the client streams directly from `archive.org`. This is critical — proxying audio would mean either huge bandwidth bills or a very slow app, and would violate the "IA is the source of truth" principle.
- Manage downloads. Downloads are a client concern; the backend just tells the client which URLs to fetch.
- Persist user library state. Library lives on the device (until/unless cross-device sync is added later).

**Deployment.** Small VPS or a serverless function set (Cloudflare Workers, Fly.io, Railway, Vercel — pick one with cheap or free tier for low traffic). Single environment to start. No staging.

**Caching strategy.** Two tiers as in SetScrape:

- Persistent (SQLite) cache for IA search results, item metadata. TTLs of ~30 min for searches, ~24 h for item metadata (item metadata is essentially immutable once a recording is uploaded).
- In-memory cache for aggregated concert results (the CPU-intensive grouping/venue-vote pass). 5-min TTL.

**Concert ID format.** Use a URL-safe ID, not the pipe-separated `artist|date` SetScrape used. Either base64-encode it or just hash it. Don't repeat that bug.

### 6.2 Client

**Mobile-first.** iOS at MVP using either Swift/SwiftUI (native) or React Native / Flutter (cross-platform).

**Stack decision — preliminary, to be revisited in §7:**

- **Swift / SwiftUI** if the goal is "best-feeling iOS app, eventual TestFlight distribution, willingness to skip Android initially." I have prior Swift experience from Muze.
- **React Native** or **Flutter** if cross-platform from day one matters more. Tagify already used Flutter; SetScrape's client was React Native. Lessons from both should inform the choice.
- **Lean toward Swift/SwiftUI** because Muze already proved the platform out for me, the audio playback story on iOS (AVFoundation + MPNowPlayingInfoCenter + MPRemoteCommandCenter) is well-understood from that project, and "feels native on my phone" matters more than "runs on Android too" given the personal-use framing.

Core client responsibilities:

- All UI: tabs, navigation, list rendering, player UI.
- Audio playback (streaming + downloaded files) with background playback, lock-screen controls, AirPods controls.
- Download manager: progress, pause/resume, cancel, retry on failure, queue management.
- Local library: SQLite or Core Data / SwiftData. Tracks history, saved concerts, downloaded files, playback state.
- Offline-first behavior: cached browse data shows on app open, fresh fetched in background.

**Audio playback specifically.** This is where SetScrape failed and Muze succeeded. Use the Muze-validated pattern:

- Single `PlaybackCoordinator` as `@MainActor ObservableObject`, owns all playback state.
- `AVPlayer` for streaming, `AVAudioPlayer` or `AVPlayer` for local files — pick one and stick with it.
- Configure `AVAudioSession` for background audio category from app launch.
- Wire up `MPNowPlayingInfoCenter` with current track metadata and artwork.
- Wire up `MPRemoteCommandCenter` for play/pause/skip/scrub from lock screen and AirPods.
- Background audio capability declared in `Info.plist`.

### 6.3 Library / Local Storage

On-device, SQLite (via SwiftData or a wrapper). Tables / models, at minimum:

- `Concert` — id, artist, date, venue, location, source IDs, last seen.
- `Recording` — id, concert_id, taper/source info, format, file URLs.
- `Track` — id, recording_id, title, position, duration, length.
- `Download` — id, recording_id (or track_id), local file path, status, size, downloaded_at.
- `PlayHistory` — recording_id, track_id, played_at, position-when-stopped.
- `SavedConcert` — concert_id, saved_at, optional notes.

Library state is canonical on-device. The backend never sees it.

### 6.4 Setlist Correlation (Optional Enrichment)

When a concert is loaded, attempt to attach a setlist from:

1. The IA item description (often pasted by tapers; parsing is fragile but worthwhile).
2. Setlist.fm API (if I have credentials handy; rate-limited).
3. The SetlistAI corpus if it covers the artist (Grateful Dead, Phish, Dead & Co. at minimum).

If found, render on the concert page. Track-level alignment ("which audio track is which song") is a nice-to-have for v2; at v1, just display the setlist text alongside the audio track list.

---

## 7. Open Questions (To Resolve Before Coding)

These are real decisions, not idle musings. Each should get a one-line answer before the project starts.

1. **Native iOS (Swift/SwiftUI) vs. cross-platform (React Native / Flutter)?** Preliminary answer: native iOS. Confirm before committing.
2. **Where does the backend live?** Fly.io / Railway / Cloudflare Workers / a small VPS? Preliminary answer: Fly.io or Railway for a regular Python service.
3. **What's the audio format priority order for "best source"?** When auto-selecting a download or stream URL, which format wins? Preliminary: FLAC → VBR MP3 → 320kbps MP3 → Ogg → SHN. (FLAC is large but lossless and IA always has it for etree; MP3 derivatives are smaller for streaming.)
4. **Streaming format.** Do we stream FLAC directly (large bandwidth, perfect quality) or MP3 derivatives (small bandwidth, lossy)? Preliminary: stream MP3 derivatives by default, allow FLAC streaming over WiFi as a toggle.
5. **Concert canonicalization.** When the same show has 12 different recordings, what's the "default" one we offer first? Preliminary: most recent upload, tied broken by source quality (SBD > MTX > AUD), tied broken by file count completeness.
6. **Setlist source priority.** Where do setlists come from? Preliminary: IA description first (fast, free), then Setlist.fm (rate-limited), then SetlistAI corpus if applicable.
7. **What artists to cover at MVP?** Preliminary: don't restrict — let the user search any band in the etree collection. Pre-cache a small set (Grateful Dead, Phish, Dead & Co.) for fast home-screen population.
8. **Distribution.** TestFlight for personal use? Open beta? App Store? Preliminary: TestFlight first, App Store much later.

---

## 8. Phased Development Plan

Each phase produces something usable. Don't start phase N+1 until phase N is honestly usable on a real device.

### Phase 0 — Foundation (1–2 weekends)

- Spin up a single FastAPI app with one endpoint: `/concerts?artist=...` that hits IA Advanced Search, groups results into concerts, returns JSON.
- Set up the iOS project skeleton: tabs (Home, Search, Library), navigation, a stub for each screen.
- Wire the client to the backend with a simple API client.
- Deploy the backend somewhere with a real URL (Fly.io, Railway, etc.).
- **Done when:** I can open the app, search for "Grateful Dead," see a list of concerts.

### Phase 1 — Streaming (1–2 weekends)

- Concert detail screen: show recordings list, pick one, see track listing.
- Player screen: track metadata, play/pause, seek, queue.
- `AVPlayer`-based streaming from IA URLs.
- Background audio: `AVAudioSession`, `Info.plist` capability, `MPNowPlayingInfoCenter`, `MPRemoteCommandCenter`.
- **Done when:** I can tap a track, hear audio, lock my phone, and keep listening with lock-screen controls.

### Phase 2 — Library and Persistence (1 weekend)

- SwiftData (or Core Data) models for Concert, Recording, Track, PlayHistory, SavedConcert.
- Library tab populated by history and saved items.
- "Save concert" action on the concert detail screen.
- Recently-played list on the home screen.
- **Done when:** I can save a concert, close the app, reopen, and find it in my library.

### Phase 3 — Downloads (1–2 weekends)

- Background download manager (`URLSession` background configuration).
- Download progress UI on concert detail and a downloads list.
- Downloaded recordings clearly marked in library.
- Player automatically prefers local file when available, falls back to streaming.
- **Done when:** I can download a full concert, go offline (airplane mode), and play it back.

### Phase 4 — Polish / Setlists / Caching (1 weekend)

- Setlist correlation (IA description parsing, optional Setlist.fm pass-through).
- Home-screen offline-first: show cached data immediately, refresh in background.
- Search history, recent searches.
- Empty states, error states, retry flows.
- Artwork: pull from IA item if present, else fall back to a default per-artist image.
- **Done when:** It feels like a real app, not a demo.

### Phase 5 — Distribution (1–2 weekends, much later)

- TestFlight build, personal device install.
- Privacy nutrition labels, screenshots, app icon, App Store metadata.
- Public TestFlight or App Store submission.
- **Done when:** It's on my phone permanently, replacing whatever I currently use for IA listening.

**Total estimated time to Phase 4:** ~6–10 weekends of focused work, assuming the job-search work has priority during weekdays.

---

## 9. Known Risks and Hard Parts

In rough order of how much they'll hurt:

1. **Background audio + interruptions.** Getting AVAudioSession right (handling phone calls, AirPods disconnects, route changes, other apps grabbing audio) is fiddly. Budget extra time. Muze's `PlaybackCoordinator` is a useful reference.
2. **IA title parsing.** IA titles are unstructured strings written by hundreds of different tapers. Venue/location extraction is regex-and-prayers. SetScrape's regex layer is salvageable but expect to iterate.
3. **Download manager edge cases.** Background downloads on iOS have specific lifecycle requirements (`URLSession` background config, app-relaunch handling, partial-file recovery). Don't underestimate this.
4. **The "best recording" auto-pick.** Choosing which of 12 recordings to default to is the kind of heuristic that will be wrong sometimes. Make the choice transparent and easily overridable.
5. **Audio format negotiation.** IA exposes multiple formats per recording; not all formats exist for all recordings; some are derivatives that take a while to generate on first request. Build for failure modes.
6. **Caching invalidation.** Persistent cache means stale data. Pick TTLs that err short. Add a manual refresh on every screen that shows IA data.
7. **App Store review.** If I do submit, expect at least one rejection cycle. The IA TOS / copyright story is straightforward (etree recordings are taper-tradeable per band policy), but Apple may want documentation.

---

## 10. Where AI Could Plausibly Come Back

Reiterating: AI is not an MVP feature. But if the app exists and works, here are the spots where AI features would add real value:

1. **Natural-language concert search.** "Grateful Dead shows in California 1977" → structured query → IA results. This is a SetlistAI-shaped problem and the SetlistAI corpus could power it.
2. **Track identification on bad metadata.** Many tapers label tracks as "Track 01," "Track 02," etc. An LLM or audio-fingerprint pass could correlate to the setlist and fix labels.
3. **"More like this" recommendations.** Embed setlists, find similar shows. Useful for surfacing the long tail.
4. **Setlist alignment to audio.** Given a setlist and a track list with durations, infer which audio track is which song. This is mostly heuristic (durations + position) but an LLM could disambiguate edge cases.
5. **Setlist data extraction from IA descriptions.** Parsing free-text descriptions for setlists is brittle with regex but tractable with an LLM. Cheap, high-value.

None of these block the core listening experience. All of them are post-MVP enhancements.

---

## 11. What This Document Is and Isn't

This file is:

- A **motivation statement** for the project.
- A **requirements list** for what the app must do for personal use to be successful.
- A **decision record** of choices already made in conversation (e.g., not microservices, not unified ecosystem, not AI-first).
- A **medium-altitude development plan** with phased milestones.

This file is not:

- A spec. The spec gets written in the new project once the open questions in §7 are answered.
- A commitment to ship by a specific date.
- A portfolio document. If the project produces portfolio value, that's a bonus, not a goal.

---

## 12. Next Steps to Bootstrap the New Project

When starting the new project repo, the first three things to do:

1. Copy this file into the new repo as `IDEAS.md`. Keep it as a living document — update it as decisions get made or revisited.
2. Answer the §7 open questions and record the answers in a new `DECISIONS.md` (or as a section in `IDEAS.md` titled "Resolved Decisions").
3. Write a thin `SPEC.md` covering the Phase 0 deliverable only: backend endpoint signature, client screens, data models. Don't spec phases 1–5 yet.

Then start Phase 0.

---

## 13. Resolved Decisions (pointer)

Step 12.2 above is done — but the decision log lives in **one canonical place**, not
duplicated here (a second copy is a drift vector; see
`workflow/WORKFLOW.md` § "Discipline that survives the slimming"):

> **`docs/design/04-OPEN-QUESTIONS.md`** — resolved decisions (D1–D8), what's deferred to
> which phase, and the ambiguities still needing user input.

Step 12.3's "thin SPEC.md" is superseded by the focused design package in `docs/design/`
plus `docs/development_roadmap.md` (Phase 0 scope is its own section there).

Decisions resolved with the user 2026-05-16, ahead of writing the spec:

- **Backend (§7 Q2 / D2):** thin Python+FastAPI backend — IA aggregation + caching only;
  no audio proxying.
- **Per-track search (D2d):** scoped to opened recordings in v1; global crawl is future.
- **Library model (D5):** unified storage + pinned flag; record-shelf feel via UI.
- **Backend stack (§7 Q7 / D7):** Python + FastAPI + SQLite.
- **Spec format:** focused design package (not a single SPEC.md, not the full
  tape_scrape-style set).
- **Workflow:** slimmed solo loop (the copied four-role package was collapsed).

Still defaulted-but-confirmable or deferred (iOS minimum, backend host, CloudKit sync,
cover-art look, setlist source, App Store "two builds") are tracked with their owners and
deadlines in `docs/design/04-OPEN-QUESTIONS.md`. This `IDEA.md` remains the living
*motivation* doc; it is not the decision log.
