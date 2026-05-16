# 01 — Internet Archive Integration

**The most load-bearing document in the package.** Concert aggregation is the hard part
of the product, and almost all of its difficulty comes from the messiness of IA's data,
not the code that consumes it. This is distilled from the `set-scrape` predecessor's real
implementation and the `tape_scrape/02` research. Read it in full before touching any IA
call, parser, or aggregation code.

Predecessor reference paths point into `/Users/Jake/Programs/set-scrape/`. Use them to
read the original code and decide what to keep, change, or discard. Do **not** extend
that codebase — it is a paper prototype.

---

## 1. What `etree` is

`etree` is IA's collection of live music recordings, primarily from taping-friendly bands
(Grateful Dead, Phish, Allman Brothers, the jam-band long tail). Individual *tapers*
record and upload shows.

The structural fact everything else follows from:

> **There is no "concert" entity in the Internet Archive.** There are only *items*. Each
> item is one recording of one show by one taper, with a unique identifier string like
> `gd1977-05-08.sbd.miller.20453.flac16`.

Every "concert" in TapeScrape is a **derived** entity built by grouping IA items that
appear to document the same show. **The grouping logic *is* the feature.** A single show
may have 0 items (never taped/uploaded), 1 (common), 2–5 (popular bands; different
tapers/sources), or 10+ (famous shows like GD 1977-05-08).

## 2. The two IA APIs (both public, unauthenticated)

### 2.1 Advanced Search

```
GET https://archive.org/advancedsearch.php
      ?q=<lucene-style-query>
      &fl[]=identifier&fl[]=title&fl[]=date&fl[]=creator&fl[]=...
      &sort[]=date+desc
      &rows=50&page=1&output=json
```

Predecessor: `backend/browse_service/main.py:137–250`. Returns matching items with the
fields requested in `fl[]`. **Critically: search results do NOT include the file list.**
Item-level metadata only.

Useful query fragments:

- `collection:etree` — restrict to live music.
- `AND NOT collection:stream_only` — exclude the streaming-restricted duplicate
  sub-collection. `set-scrape` excludes it by default; keep doing so.
- `creator:"Grateful Dead"` — artist filter (IA's artist field is `creator`).
- `date:[1977-05-01 TO 1977-05-31]` — date filter.
- Sort: omit the `sort[]` param entirely for relevance order; otherwise
  `sort[0]=date+desc` etc. (predecessor `main.py:194–209`).

### 2.2 Metadata

```
GET https://archive.org/metadata/<identifier>
```

Predecessor: `backend/browse_service/main.py:252–297`. Returns *everything* about one
item, including the **complete file list** — the only way to get track listings, formats,
durations, and file URLs. Shape:

```jsonc
{
  "metadata": {
    "identifier": "gd1977-05-08.sbd.miller.20453.flac16",
    "title": "Grateful Dead Live at Barton Hall on 1977-05-08",
    "creator": "Grateful Dead",
    "date": "1977-05-08",
    "venue": "Barton Hall",      // often absent in search; more often present here
    "coverage": "Ithaca, NY",    // ditto
    "source": "SBD > Master Reel > DAT > CD > EAC > FLAC",
    "taper": "Jack Miller",
    "lineage": "...",
    "description": "free-form HTML/text"
  },
  "files": [
    { "name": "gd77-05-08d1t01.flac", "format": "Flac",
      "length": "9:43", "size": "37200000", "title": "Promised Land" }
  ]
}
```

Derived URLs the client needs:

```
Stream / download:  https://archive.org/download/<identifier>/<filename>
Item page (web):    https://archive.org/details/<identifier>
```

The client treats these as **opaque strings returned by the backend**, not hand-built
(keeps the future-proxy hook, `00-ARCHITECTURE.md` § 7).

## 3. Where the metadata is unreliable

Roughly in the order it bites you.

1. **Venue is not a real search field.** Advanced Search does not reliably return
   `venue`/`coverage` even when requested in `fl[]`; they exist on the Metadata response.
   `set-scrape` parses venue/city from the **title** with regex
   (`main.py:425–471`). The core pattern:
   `r"(?:Live\s+)?at\s+(.+?)(?:\s+on\s+\d{4}-\d{2}-\d{2}|\s*$)"`, then split on the first
   comma into venue/location, with a description-scan fallback for venue-suffix keywords
   (`Amphitheater|Theater|Arena|Stadium|Center|Hall|Club|Bar|Resort|Festival`). Many
   items still end up `venue = None`. **TapeScrape: don't rely on title parsing alone;
   cross-reference the Metadata API for a *sample* of items per candidate concert (not
   all — cost), where structured `venue`/`coverage` are more often populated.**
2. **Dates are inconsistent.** `"1977-05-08"`, `"1977"`, `"1977-05-08T00:00:00Z"`,
   `""`/missing, or a range `"1977-05-08 to 1977-05-10"`. `set-scrape` handles only
   year-only vs. full and silently drops the rest (`main.py:415–423`). **TapeScrape:
   keep year-only items as a separate aggregation tier (e.g. "Phish 1997" fallback
   group), not a silent drop.**
3. **Artist names are inconsistent.** `creator` is freeform per uploader: "Grateful
   Dead" / "The Grateful Dead" / "Grateful Dead, The"; "Phish" / "phish"; "Bob Weir &
   Ratdog" / "...and Ratdog" / "RatDog". `set-scrape` groups by literal `creator` — a
   real bug. **TapeScrape: canonicalize** (see § 5).
4. **Source/quality is unstructured.** SBD/AUD/MTX/FM lives in free-text `source`,
   `description`, or the identifier (`gd1977-05-08.sbd.miller...`). `set-scrape` does no
   classification. **TapeScrape: parse into a `SourceQuality` enum** (regex + identifier
   token scan) and use it to order recordings within a concert.
5. **Formats are a shortlist.** `set-scrape` filters to
   `["VBR MP3", "Flac", "Ogg Vorbis", "WAVE"]` (`main.py:475`). On `etree` you also see
   `MP3`, `FLAC`/`24bit Flac`, `Shorten` (`.shn`). **iOS/AVFoundation plays MP3, AAC,
   ALAC, FLAC natively but NOT Ogg Vorbis or Shorten.** Drop unsupported formats at the
   parse stage so they never reach the UI (most items have at least one MP3 or FLAC).
   Server-side transcoding is out of v1 scope.
6. **Track titles are messy.** Real names, filename nonsense (`gd77-05-08d1t01`), or
   set markers as "tracks" (`Set I`, `Tuning`, `Crowd`, `Encore Break`). De-emphasize
   (filter or visually mute) obvious non-song markers so the list reads like a setlist.
7. **`numFound` is approximate past page ~100** for very common queries. Fine per-artist;
   if pagination of a huge artist looks broken, window by date instead of deep paging.
8. **No "shows for an artist" endpoint.** Closest is `creator:"X"` sorted by date — you
   get *recordings* and group them yourself.
9. **No track-level search.** Advanced Search indexes item fields only; track titles live
   in the per-item file list (Metadata API). You cannot ask IA "every show with Scarlet
   Begonias." This is the single strongest argument for a backend and the basis for the
   scoped-v1 / future-F1 decision (`00-ARCHITECTURE.md` § 4).
10. **Track boundaries are wherever the taper cut them.** Mid-song tape-flip cuts
    (sometimes `// cut //` / `/]` in the title, often not), bad split points across
    segues, applause/tuning attached to the wrong track, multiple songs in one file.
    Some uploaders include a single uncut master file alongside per-track splits; many
    don't; there is no consistent signal — infer from file sizes/names. **Design
    implication: preserve original taper-cut files verbatim; where an uncut master
    exists, capture it as an alternate download target; treat user re-cuts (future F2)
    as a metadata overlay, never destructive edits.** Cheap in v1, expensive to retrofit.
11. **Streaming is intermittently flaky** — IA infra, not a metadata problem. Mitigate on
    the client: aggressive prefetch, retry-with-backoff on first byte (don't kill the
    stream after one timeout), prefer a local copy transparently when pinned.
12. **`description` is freeform HTML and a goldmine** — taper notes, lineage, exact venue
    when the title is cryptic, sometimes a real setlist. Ignore for v1 aggregation; it is
    high-value for later setlist extraction and "show notes" UI.

## 4. How `set-scrape` aggregated, and where it failed

Pipeline: Browse Service queries Advanced Search, parses items, caches 30 min
(`main.py`). Aggregation Service groups into concerts, votes a venue, paginates,
memoizes 5 min in a **process-local dict** (`aggregation_service/main.py`).

Three failure modes to fix, not repeat:

- **Concert key is `f"{artist}|{date}"`** (`aggregation_service/main.py:58`). Festival
  days collapse (same artist, two venues, one day → merged, smaller venue erased via
  majority vote). Artist-name variants split into separate concerts. Pipe characters in
  the key break URL routing.
- **Venue by raw majority vote** (`main.py:103–118`) with **unnormalized strings** —
  "Madison Square Garden" vs "MSG" vs "MSG, NYC" are three candidates; a typo'd version
  with two votes can beat three correctly-spelled-but-split votes.
- **Persistence is wrong.** `AggregatedConcert`/`ConcertRecording` tables exist in
  `shared/database_models.py` but are **never written to** — aggregation is in-memory
  only, vanishes on restart, and forces a leaky `per_page * 3` over-fetch
  (`aggregation_service/main.py:243`) that makes pagination inconsistent.

The two-tier cache *pattern* (30-min SQLite + 5-min in-memory) is sound and kept; the
*persistence* of aggregated concerts is the part to do properly this time.

## 5. The TapeScrape aggregation algorithm

Defaults, not commandments — expect to tune them against real data, which is exactly why
aggregation is server-side.

1. **Canonical artist key.** Lowercase; strip leading `the `, trailing `, the`; collapse
   `&`/`and`/` + `; strip punctuation; collapse whitespace. Plus a hand-curated alias map
   for high-traffic exceptions (`jgb` → `jerry garcia band`). Keep the most common
   original casing as the display name, separately.
2. **Canonical venue key.** Cluster venue strings before voting — token-set / Levenshtein
   similarity (~0.85 threshold) plus an append-only alias map. This is what fixes both
   the festival-day collapse and venue-vote corruption.
3. **Concert key = `(canonical_artist, date, canonical_venue)`.** Two shows by one artist
   on one day at two venues are two concerts. Year-only dates form a separate tier.
4. **Concert IDs are opaque** — UUIDv4 or a hash of the canonical key. Never put pipes or
   freeform text in URL paths.
5. **Persist concerts** to SQLite. Re-aggregate per artist when new items appear.
   Paginate *concerts*, not recordings.
6. **Parse `SourceQuality`** (SBD > MTX > AUD > FM > unknown) and order recordings within
   a concert by it.
7. **Drop unsupported formats** (Ogg Vorbis, Shorten) at parse so they never surface.
8. **Cross-reference Metadata for venue/city** on a *sample* of items per candidate
   concert when search lacks it — not every item; cache aggressively.
9. **Year-only dates → separate aggregation tier**, not a silent drop.
10. **Preferred recording per concert, computed at aggregation time and stored:** best
    `SourceQuality` first → completeness (most tracks, longest total duration) →
    popularity (`downloads` count) as tiebreaker. The client plays this on tap without
    re-deciding. A user's per-concert override always wins over the computed default.
11. **Capture an uncut master file** where IA exposes one alongside per-track splits;
    expose it as an alternate download target (future F2 hook, cheap now).
12. **Build per-track search incrementally.** Index track titles for any item opened in
    detail (free byproduct of Metadata calls). A future per-followed-artist background
    crawl fills the rest. No full `etree` crawl in v1.

## 6. Predecessor file/line index

| What | Path (`/Users/Jake/Programs/set-scrape/`) | Lines |
|---|---|---|
| IA Advanced Search call | `backend/browse_service/main.py` | 137–250 |
| Per-item parse + venue regex | `backend/browse_service/main.py` | 402–510 |
| IA Metadata call | `backend/browse_service/main.py` | 252–297 |
| Audio format filter | `backend/browse_service/main.py` | 475 |
| Concert key extraction | `backend/aggregation_service/main.py` | 58–72 |
| Grouping + venue majority vote | `backend/aggregation_service/main.py` | 73–172 |
| In-memory aggregation cache | `backend/aggregation_service/main.py` | 27, 174–186, 433–445 |
| Dead persisted-concert schema | `shared/database_models.py` | `AggregatedConcert`, `ConcertRecording` |
