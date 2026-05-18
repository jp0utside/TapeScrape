# 00 — System Architecture

## 1. Shape

Two tiers. A **thin backend** that mediates the Internet Archive, and a **native iOS
client** that is the whole product experience.

```
┌─────────────────────────┐         ┌──────────────────────────┐
│  iOS app (Swift/SwiftUI) │         │  Backend (Python/FastAPI) │
│                          │  JSON   │                          │
│  • all UI & navigation   │ ──────▶ │  • IA Advanced Search     │
│  • playback state machine│         │    proxy + cache          │
│  • download manager      │         │  • concert aggregation    │
│  • local library (tag-   │         │    (canonical, persisted) │
│    first, repository)    │ ◀────── │  • metadata pass-through  │
│  • cover art renderer    │  concerts│  • per-track search       │
└───────────┬──────────────┘         │    (scoped, see §4)       │
            │                        └──────────────────────────┘
            │ audio bytes (stream or download)
            ▼
   ┌───────────────────┐
   │  archive.org       │   ← client streams/downloads audio DIRECTLY.
   │  /download/<id>/.. │     The backend never touches audio bytes.
   └───────────────────┘
```

This is the single most important architectural fact, and it is a hard constraint:
**the backend mediates *metadata*; the client moves *audio* directly to and from
`archive.org`.** Proxying audio would mean either large bandwidth bills or a slow app,
and it violates "IA stays the source of truth." See `CLAUDE.md` § "Core constraints".

## 2. Why a backend at all (resolved: thin backend)

A no-backend design is viable for personal use — the client could hit IA directly and
aggregate on-device. We chose a **thin backend** anyway, for three concrete reasons:

1. **Aggregation is iterable without an App Store / TestFlight cycle.** The grouping and
   canonicalization heuristics (`01-INTERNET-ARCHIVE.md` § 4–5) *will* be wrong on real
   data and need tuning. Server-side, a fix is a deploy; client-side, it is an app update.
2. **A shared cache makes cold queries fast.** IA is slow and rate-limited. One cache,
   warmed once, serves every client session.
3. **It keeps the per-track-search door open** without a client-side index (see § 4).

The lean is still "as little backend as possible." Everything that *can* live on the
device does: playback, the library, downloads, cover art.

### 2.1 What the backend does

- Proxy IA **Advanced Search** with persistent caching (TTL ~30 min).
- Proxy IA **Metadata** for individual items with persistent caching (TTL ~24 h —
  item metadata is effectively immutable once uploaded).
- Run **concert aggregation** server-side and **persist canonical concerts** (this is the
  thing `set-scrape` got wrong by keeping aggregation in an in-memory dict). Re-aggregate
  per artist when new items appear.
- Compute and store the **preferred recording** per concert (`02-DATA-MODEL.md` § 4).
- Expose a search endpoint whose `type` parameter accepts `artist | concert | track`
  even though `track` is scoped in v1 (§ 4) — the shape must not foreclose F1.

### 2.2 What the backend does NOT do

- **Serve, proxy, or cache audio bytes.** Ever. Stream/download URLs are opaque strings
  the client resolves directly against `archive.org`.
- **Manage downloads.** The backend tells the client *which* URLs exist; fetching,
  progress, pause/resume, and storage are client concerns.
- **Persist user library state.** Favorites, playlists, history, tags, download pins
  live on the device. The backend is single-tenant and stores no personal data.
- **Authenticate users** in v1. See `04-OPEN-QUESTIONS.md` D4. An optional static shared
  secret is the only access gate, behind a config flag.

## 3. The four forward-compatibility hooks (Phase 0, non-negotiable)

`IDEA.md` and `tape_scrape/06` identify four seams that are a few hours each to install
now and expensive to retrofit. They are **Phase 0 work**, in place before any code
crosses them. They are passive — they shape how code is organized, not what gets built.

1. **`AudioStorage` protocol.** All audio read/write/eviction/usage goes through one
   protocol with a single default implementation writing to
   `Documents/Recordings/<identifier>/<file>`. Only that implementation knows the path.
   A future companion-player app can implement it against an App Group container.
2. **URL scheme from day one.** Register `tapescrape://` and route
   `tapescrape://concert/<id>` and `tapescrape://recording/<identifier>` through the same
   in-app navigation. Useful immediately for deep links; later the cross-app import path.
3. **Tag-first library model.** Favorites, playlists, smart collections are all *tags +
   queries over tags*, not bespoke per-feature schemas. "Favorite" is a tag. A playlist
   is an ordered list of `(recordingID, trackIndex)` with a name tag. A smart collection
   is a saved query. Matches the user's Tagify approach; makes the library portable.
4. **Repository pattern around the library DB.** Modules touch the library only through
   repository protocols (`LibraryRepository`, `PlaybackHistoryRepository`, …), never raw
   SwiftData/SQLite. A future extraction into a sibling app changes only the repo impl.

What v1 must **not** do (over-architecture is the bigger risk than under-architecture):
no inter-process protocol, no plugin system for sources/players, no App Group entitlement
"just in case," nothing beyond these four hooks.

## 4. Per-track search (resolved: scoped in v1)

The user's named pain point — "find every show with Scarlet Begonias" — is real but
collides with an IA limitation: **IA's Advanced Search does not index track titles**
(`01-INTERNET-ARCHIVE.md` § 3.9). Global track search requires a server-side index built
by crawling the Metadata API across a meaningful slice of `etree`.

v1 decision: **defer the global index (future work F1); ship scoped track search.**
v1 track search queries the persisted aggregation — a JOIN across `tracks`, `recordings`,
and `concerts` — scoped to artists that have been aggregated. The search endpoint's `type`
parameter already accepts `track`; a future backend crawler grows the coverage without an
API-shape change.

## 5. Backend stack & deployment (resolved)

- **Stack: Python + FastAPI.** Path of least resistance — the `set-scrape` precedent and
  user familiarity. The novelty in TapeScrape is the Swift app and the aggregation
  heuristics, not the backend language. (`04-OPEN-QUESTIONS.md` D7.)
- **Persistence: SQLite** (a local file) for the cache and canonical concerts. Single-
  user scale is single-digit requests/minute; do not reach for Postgres/Redis until the
  single-machine version has been used daily for a month. (`IDEA.md` § 5.6.)
- **Deployment: local `uvicorn` for Phases 0–1; a cheap always-on host (Fly.io or
  Railway) once the client needs a real URL off the home network.** Single environment,
  no staging. The exact host is a Phase-1 decision (`04-OPEN-QUESTIONS.md` D2b).
- **All third-party HTTP goes through one client module** with rate limiting, caching,
  and audit logging — no ad-hoc `httpx.get` in route code (`CLAUDE.md`, CONVENTIONS § 2).

## 6. Caching strategy

Two tiers, the one pattern worth carrying forward verbatim from `set-scrape`:

| Tier | Holds | TTL | Notes |
|---|---|---|---|
| Persistent (SQLite) | IA search results | ~30 min | err short; stale browse data is the cost of caching |
| Persistent (SQLite) | IA item metadata | ~24 h | effectively immutable once uploaded |
| Persistent (SQLite) | canonical aggregated concerts | re-aggregate on new items | **persisted, not memoized** — `set-scrape`'s key bug |
| In-memory | hot aggregation working set | ~5 min | the CPU-bound grouping/vote pass |

Every client screen that shows IA-derived data must offer a manual refresh — TTLs are a
floor, not a guarantee of freshness.

## 7. Failure posture

IA streaming is intermittently flaky even on good connections
(`01-INTERNET-ARCHIVE.md` § 3.11). The architecture's answer is on the client:
aggressive prefetch/buffering, retry-with-backoff on first byte, and **prefer a local
download transparently whenever one exists**. A backend audio proxy (future F5) is
explicitly out of v1 scope; the client treats stream URLs as opaque so a proxy could
replace them later without a client change.
