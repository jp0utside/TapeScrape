# 02 — Data Model

Two data worlds that never talk to each other: the **backend's derived catalog** (IA
items → canonical concerts) and the **client's personal library** (tag-first, on-device).
Keeping them disjoint is deliberate — it is why "backend handles IA, device handles
library" stays a clean split with no sync surface (`00-ARCHITECTURE.md` § 2.2).

Per the loose-spec principle, this describes the *model*, not a frozen schema. Each phase
adds only the tables/fields it needs. Field lists below are the intended shape, not a
migration script.

---

## 1. Derived catalog (backend, SQLite)

IA exposes only *items*. The backend derives the hierarchy the product needs:

```
Concert  (derived; canonical; persisted)
  └── Recording  (≈ one IA item = one taper's recording of the show)
        └── Track   (≈ one audio file in that item)
```

### Concert

- `id` — opaque UUIDv4 or hash of the canonical key. **Never** a pipe-joined string.
- `canonical_artist` / `display_artist` — canonical key for grouping; display name kept
  separately (most common original casing). See `01-INTERNET-ARCHIVE.md` § 5.1.
- `date` — ISO date, or year-only with a `date_precision` of `day | year` (year-only is
  a separate aggregation tier, not a drop). § 01-3.2.
- `canonical_venue` / `display_venue` / `location` — clustered venue key + display; § 01-5.2.
- `recording_ids` — ordered, best-first by `SourceQuality` then completeness.
- `preferred_recording_id` — computed at aggregation time and **stored** (§ 4). The
  client never re-derives this on tap.
- `aggregated_at` — for staleness / re-aggregation on new items.

### Recording

- `identifier` — the IA item identifier (the natural key; opaque, used in audio URLs).
- `concert_id` — parent.
- `source_quality` — enum `SBD | MTX | AUD | FM | UNKNOWN`, parsed from `source` /
  `description` / identifier tokens (§ 01-3.4).
- `taper`, `lineage`, `source` — pass-through free text, for the now-playing/info UI.
- `format_set` — which playable formats exist (after dropping Ogg/Shorten, § 01-3.5).
- `has_uncut_master` + `uncut_master_filename` — captured when IA exposes a single
  whole-show file alongside per-track splits (future-F2 hook; cheap now).
- `downloads` — IA engagement count; preferred-recording tiebreaker.

### Track

- `recording_id` (parent), `index`, `title`, `duration`, `size`.
- `filename` — used to build the opaque stream/download URL.
- `is_marker` — heuristic flag for non-song entries (`Tuning`, `Crowd`, set markers,
  § 01-3.6) so the UI can mute/filter them without deleting data.

Tracks are a **logical layer above files**: the list a user sees is metadata; the audio
files are storage. A future user-cut-tracks overlay (F2) is then just another source of
track metadata, never a destructive edit.

## 2. Backend cache tables

Per `00-ARCHITECTURE.md` § 6. Distinct from the derived catalog:

- `search_cache` — keyed by a hash of the normalized query+page; value = raw IA search
  response; TTL ~30 min.
- `metadata_cache` — keyed by identifier; value = raw IA Metadata response; TTL ~24 h.
- `track_index` — `(identifier, track_index, title, duration)` rows written as a free
  byproduct whenever a Metadata response is parsed. Powers scoped v1 track search and is
  the table a future F1 crawler grows. **Add this in the phase track search lands, not
  before** — but the search endpoint's `type` param accepts `track` from day one so the
  API shape never has to change (`00-ARCHITECTURE.md` § 4).

Aggregated `Concert`/`Recording`/`Track` are **persisted**, not memoized in a process
dict — the explicit fix for `set-scrape`'s dead-schema bug (`01-INTERNET-ARCHIVE.md`
§ 4).

## 3. API surface (grown per phase, not specified up front)

Do not freeze a full API contract now (`IDEA.md` "what we are not doing"). Endpoints are
added as the client needs them. The minimal Phase-1/2 surface:

- `GET /concerts?artist=<name>&page=<n>` → paginated canonical concerts.
- `GET /concerts/{id}` → one concert with its recordings (best-first) and the
  `preferred_recording_id`.
- `GET /recordings/{identifier}` → recording detail incl. tracks and opaque audio URLs.
- `GET /search?type=artist|concert|track&q=<q>` → `track` is scoped in v1 (§ 4 of `00`).

Audio URLs in responses are **opaque strings**; the client never constructs
`archive.org` URLs itself (future-proxy hook).

## 4. Preferred-recording heuristic

Computed once at aggregation, stored on `Concert.preferred_recording_id`:

1. Best `source_quality`: `SBD > MTX > AUD > FM > UNKNOWN`.
2. Tiebreak: completeness — most tracks, then longest total duration.
3. Tiebreak: popularity — IA `downloads` count.

Tap-to-play on a concert plays this recording immediately; "Other versions" is a
secondary affordance, never a gate (this is a core product requirement —
`IDEA.md` § 3.2, the predecessor-app complaint that the version chooser is in the way).
A **user per-concert override is stored client-side and always wins** over the computed
default; the override travels with the library, not the catalog.

## 5. Client personal library (on-device, tag-first)

Owned entirely by the device. Local-only for v1; CloudKit sync is a Phase-3 decision
(`04-OPEN-QUESTIONS.md` D3) with one cheap hook reserved: put library data in a custom
zone-shaped container from day one so a future CloudKit `LibraryZone` / shared zones (F8)
don't require a migration.

### Unified storage with a pinned flag (resolved: D5)

One storage layer, not two. Everything the user engages with can appear in the library;
a `pinned` (downloaded-for-offline) flag is the only stream-vs-offline distinction.
The "record collection" feel is created by **UI** (cover art, curated grid, dynamic
shelves) — not by a separate data path. Technically one player, one storage layer, one
code path.

### Tag-first schema

Favorites, playlists, and smart collections are **not** separate record types. They are:

- **Tag** — `(name, kind)` where `kind ∈ {system, user}`. `favorite` is a system tag.
- **Tagging** — `(tag_id, target)` where `target` is a `(recordingID)` or
  `(recordingID, trackIndex)` or `concertID`.
- **Playlist** — an ordered list of `(recordingID, trackIndex)` plus a name tag.
- **Smart collection** — a stored query over tags/metadata (by artist, year, venue, …).
- **PlaybackHistory** — `(recordingID, trackIndex, playedAt, stoppedPosition)`.
- **DownloadPin** — `(recordingID, status, localPathRef, bytes)`; the *file* lives via
  `AudioStorage`, never a hard path in the DB (`00-ARCHITECTURE.md` § 3 hook 1).
- **ConcertOverride** — `(concertID, preferredRecordingID)`; the § 4 user override.

### Repository access only

Modules see the library through repository protocols (`LibraryRepository`,
`PlaybackHistoryRepository`, `DownloadRepository`, …), never raw SwiftData/SQLite.
Extraction into a sibling player app later changes only the repository implementations
(`00-ARCHITECTURE.md` § 3 hook 4).

## 6. Source-agnosticism (cheap, not premature)

A `Recording` should not *assume* IA in its record type: it has tracks, and a source that
resolves to a stream URL or local path. Don't build a source abstraction layer in v1
(YAGNI), but don't actively hard-couple record types to `archive.org` either — a future
nugs.net / relisten / personal-upload source (F7) should be additive, not a rewrite.
