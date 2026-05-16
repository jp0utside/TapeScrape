# TapeScrape Design Package

The architecture and behavior spec for TapeScrape: a personal, native-iPhone app for
browsing, streaming, downloading, and re-listening to live-music recordings from the
Internet Archive `etree` collection.

This package is **deliberately focused, not exhaustive.** The motivating documents
(`IDEA.md` at the repo root, and the `tape_scrape/` planning set referenced there)
explicitly warn against writing detailed schemas and API contracts before the first
vertical slice ships. These docs capture architecture and behavior *intent* and the
hard-won Internet Archive knowledge — not a frozen blueprint. Each phase adds only the
persistence and API surface it needs.

## Documents

| File | Owns | Read it for |
|---|---|---|
| `00-ARCHITECTURE.md` | system shape | the two-tier split, what the backend does and refuses to do, the four forward-compatibility hooks, deployment, caching |
| `01-INTERNET-ARCHIVE.md` | IA integration | how IA actually behaves, where its metadata lies, the concert-aggregation algorithm. **The most load-bearing doc — concert aggregation is the product's hard part.** |
| `02-DATA-MODEL.md` | data | the derived concert/recording/track model, canonicalization, the preferred-recording heuristic, backend cache schema, the tag-first client library |
| `03-CLIENT-AND-PLAYBACK.md` | client | Swift app structure, the playback state machine, navigation, offline-first behavior, the four hooks in detail |
| `04-OPEN-QUESTIONS.md` | decisions | resolved decisions (D1–D7), what's deferred to which phase, and the ambiguities still needing user input |

## Reading order

New to the project: `IDEA.md` → this README → `00` → `01` → `02` → `03` → `04`.

`01-INTERNET-ARCHIVE.md` is distilled from the `set-scrape` predecessor's real
implementation (file/line references preserved) and the `tape_scrape/02` research. If you
touch aggregation, parsing, or any IA call, read it first and in full.

## Precedence

When documents conflict, `CLAUDE.md` § "If they conflict" governs. In short: design docs
win on architecture and behavior intent; the roadmap wins on sequencing and scope;
`workflow/CONVENTIONS.md` wins on implementation patterns within those bounds; `CLAUDE.md`
breaks remaining ties.

## Status

This package is the **v1 design**, written 2026-05-16 from `IDEA.md` and the
`tape_scrape/` planning set, with the architecture-forking decisions resolved with the
user (see `04-OPEN-QUESTIONS.md` § "Resolved"). It supersedes nothing — there is no prior
TapeScrape spec; `set-scrape` is treated strictly as a paper prototype for the data model
and IA logic, never extended.
