# CLAUDE.md

## Purpose

This repository implements **TapeScrape**: a personal, native-iPhone app for browsing,
streaming, downloading, and re-listening to live-music recordings from the Internet
Archive `etree` collection, with a library that feels like a record collection.

It is a **personal-use project first** — the test of any decision is "is this useful to
me on my phone tonight," not "is this impressive." Portfolio value, if any, is a side
effect. Scale is one user, single-digit backend requests/minute. It is explicitly a
*non-AI* project at v1.

Two tiers: a **thin Python/FastAPI backend** that mediates Internet Archive *metadata*,
and a **native Swift/SwiftUI iOS client** that is the whole product experience. The
client moves *audio* directly to and from `archive.org`; the backend never touches audio
bytes.

`set-scrape` (`/Users/Jake/Programs/set-scrape/`) is a paper prototype for the IA logic
and data model only. **Never extend it.** Do not extend `setlist-ai` or `tape_scrape`
either — they are reference inputs, not code to build on.

## Documents and how to use them

- `IDEA.md` — motivation, requirements, and the decision record. The "why."
- `docs/design/` — architecture and behavior intent. `01-INTERNET-ARCHIVE.md` is the
  most load-bearing doc; read it in full before any IA/aggregation/parsing work.
- `docs/development_roadmap.md` — phase sequencing and scope.
- `docs/roadmap_status.md` — current progress, deviations, blockers.
- `workflow/WORKFLOW.md` — the slimmed solo development loop.
- `workflow/CONVENTIONS.md` — shared implementation conventions (grows over time).

Prefer roadmap-conformant implementation over architectural redesign. When a deviation
is warranted, surface it explicitly rather than silently diverging.

**If they conflict:**

1. Design docs win on architecture and behavior intent.
2. Roadmap wins on sequencing and scope.
3. `CONVENTIONS.md` wins on implementation patterns within those bounds.
4. `CLAUDE.md` (this file) overrides anywhere ambiguity remains.

## Core constraints

These bind at implementation time. If satisfying a task seems to require violating one,
the task or the constraint is wrong — stop and surface it.

### Network and external services

- The **client streams and downloads audio directly from `archive.org`**. The backend
  must **never** proxy, fetch, re-serve, or cache audio bytes. This is the single
  hardest rule; violating it means bandwidth bills or a slow app and breaks "IA is the
  source of truth."
- The **backend may call only the Internet Archive** (`advancedsearch.php`, `metadata/`,
  and `download/` URL construction for *passing to the client*, not for fetching). No
  other external service without an explicit authorization note in the relevant packet
  citing this section.
- Any setlist enrichment beyond parsing the IA `description` (e.g. Setlist.fm, the
  SetlistAI corpus) is **not authorized by default** — it requires an explicit decision
  recorded in `docs/design/04-OPEN-QUESTIONS.md` and a packet note.
- All third-party HTTP in the backend goes through one client module with rate limiting,
  caching, and audit logging. No ad-hoc `httpx.get` / `requests.get` in route code.
- The client constructs no `archive.org` URLs by hand — stream/download URLs are opaque
  strings returned by the backend (preserves the future-proxy hook).

### Data integrity

- Preserve IA source lineage: `source`, `taper`, `lineage`, `SourceQuality`, and the
  item `identifier` survive into the model and are visible in the now-playing/info UI.
- The preferred-recording pick is a transparent, **overridable** heuristic
  (`docs/design/02-DATA-MODEL.md` § 4) — never a silent, unexplained winner. A user's
  per-concert override always wins and lives with the library, not the catalog.
- Preserve original taper-cut files **verbatim** on download — no transcode/re-encode.
  Where IA exposes an uncut master, capture it as an alternate target. Treat any future
  user re-cut as a metadata overlay, never a destructive edit.
- Drop iOS-unplayable formats (Ogg Vorbis, Shorten) at parse so they never reach the UI.

### The four hooks are load-bearing

`AudioStorage` protocol, `tapescrape://` URL scheme, tag-first library, repository
pattern (`docs/design/00-ARCHITECTURE.md` § 3). They are Phase-0 work and must be in
place before any code crosses them. Do not bypass them for convenience; do not add
modularity beyond them (over-architecture is the larger risk).

### Sandbox and writes

- Backend writes only to its SQLite database and configured cache directory. Nothing
  else.
- The client reads/writes audio files **only through `AudioStorage`**. Library data
  only through repository protocols.
- No runtime code writes to repository source files, or to `set-scrape` / `tape_scrape`
  / `setlist-ai`. Any new write path requires an explicit packet authorization.

### Audit and logging (kept deliberately light — personal-use scale)

- Log IA calls (URL, cache hit/miss), aggregation runs, and errors through one logging
  module in the backend. Enough to debug a flaky IA, not a compliance system.
- No accounts, no PII, no analytics. Do not build the heavyweight audit/retention
  machinery of a multi-tenant service into a single-user app.

### Auth

- No user auth in v1. The only access gate is an **optional static shared-secret header
  behind a config flag**. No accounts, Sign in with Apple, or JWT in v1. Revisit only if
  the audience widens beyond personal use (`docs/design/04-OPEN-QUESTIONS.md` D4).

### Bash use

- No bash command is ever run concurrently. Ensure a command completes before invoking
  another.

### Testing

- `pytest` with no arguments must **never** make a live Internet Archive call. Tests
  that hit IA are gated behind an explicit marker (e.g. `@pytest.mark.live_ia`) and
  skipped by default; they use recorded fixtures otherwise.
- Swift unit tests do not hit the network or real IA; the catalog API client is stubbed
  with deterministic fixtures.

## Coding preferences

- **Client: Swift/SwiftUI, async-first.** iOS 17 default (`@Observable`,
  `NavigationStack`). Playback logic lives outside view code. Persistence is behind
  repositories — never raw SwiftData/SQLite in feature code.
- **Backend: Python/FastAPI, async-first.** `async def` for any route or function doing
  I/O. SQLite at v1 scale — do not reach for Postgres/Redis.
- Preserve typed interfaces. Pydantic models on the API surface; dataclasses inside
  backend modules; `Codable` structs / typed models on the client. No untyped `dict` or
  raw JSON crossing a layer boundary — parse untrusted IA JSON through a typed model
  first.
- Prefer minimal, local changes over broad refactors. Preserve existing naming and
  module boundaries unless the roadmap requires otherwise.
- If blocked by an ambiguity, stop and present options rather than guessing.

## Workflow protocol

This project uses a **slimmed solo loop**, not a heavyweight multi-role process. See
`workflow/WORKFLOW.md` for the full loop. In brief, for each implementation task:

1. Identify the roadmap phase and the exact bounded deliverable (the packet).
2. Read only: this file, `workflow/CONVENTIONS.md`, the packet, and the packet's
   `Read first` list. Plus `docs/design/01-INTERNET-ARCHIVE.md` for any IA work.
3. Restate the task in 3–6 bullets. Surface ambiguities now, not later.
4. Implement only the scoped change. Honor "Out of scope."
5. Add/update tests per the packet.
6. Write the implementation summary to the packet's summary path.
7. Close the packet's `docs/roadmap_status.md` deliverable-log row from that summary
   (own row only). This is the final step — the task is not done without it.

If a packet is `High-risk: true` or `Auto-proceed: false`, pause for explicit "go" after
restating the plan.

## Definition of done

A task is done only when:

- The scoped deliverable is implemented and honestly usable for what the phase promised.
- Tests pass or are updated per the packet; no test makes a live IA call by default.
- The core constraints above remain satisfied.
- No unrelated files were changed.
- Deviations are documented explicitly in the implementation summary.
- **The packet's `docs/roadmap_status.md` deliverable-log row reflects the summary**
  (status `COMPLETE | PARTIAL | BLOCKED`, deviations, follow-ups), and the summary's
  "Status journal" trailer confirms it. A correct implementation with a stale status row
  is **not done** — the status journal must never lag the code. Scope is the packet's
  own row only; phase status, Blockers, and decision history belong to Review/Plan
  (`workflow/WORKFLOW.md` § "Discipline").

## Preferred task size

One bounded deliverable per packet. Fits: one backend module/endpoint + tests; one
client screen or component + tests; one vertical slice (e.g. concert detail end to end);
one hook installed. Avoid attempting a whole roadmap phase in one pass — if a packet
grows while drafting, split it.
