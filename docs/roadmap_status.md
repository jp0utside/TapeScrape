# Roadmap Status

The development journal. Current phase, per-deliverable status, deviations, and
blockers/open decisions. Owned by the manager loop in the slimmed workflow (see
`workflow/WORKFLOW.md`). One to three lines per entry; link to packets/summaries for
detail rather than duplicating.

This is the working surface read at the start of every session to know where things
stand. It is *not* an architecture doc — that's `docs/design/`; not sequencing — that's
`docs/development_roadmap.md`.

---

## Current state

- **Phase:** 1 — One concert, end to end. Starting 2026-05-16.
- **Repo:** Phase 0 complete. Xcode project + four hooks + FastAPI skeleton all live.
- **Next action:** build packet `01-001` (IA client + metadata parsing for one concert).

### Phase 0 packet plan

| Packet | Deliverable | Status |
|---|---|---|
| `00-001-xcode-skeleton` | Xcode project, SwiftUI app target, bottom-tab shell (Home/Search/Library stubs), runs on device | COMPLETE |
| `00-002-four-hooks` | AudioStorage protocol, tapescrape:// URL scheme + router, tag-first library model, repository protocols — trivial defaults only | COMPLETE |
| `00-003-backend-hello` | FastAPI project skeleton, one stub route, local uvicorn, core/ module structure | COMPLETE |
| `00-004-phase1-slice` | Agree the Phase-1 vertical slice (one concert, one screen, one stream) | COMPLETE (decision: GD 1977-05-08 Cornell '77 as fixed test concert; app is artist-agnostic) |

### Phase 1 packet plan

| Packet | Deliverable | Status |
|---|---|---|
| `01-001-ia-metadata` | IA client calls (Advanced Search + Metadata) for one known concert, typed models, response parsing, recorded test fixtures | READY |
| `01-002-concert-endpoint` | `/concerts/{id}` endpoint returning parsed recordings + tracks for the test concert; persistent cache wired | — |
| `01-003-client-playback` | Client screen showing recordings/tracks for the test concert; tap a track → AVPlayer streams from IA | — |

## Phase status

| Phase | Status | Notes |
|---|---|---|
| 0 — Set the stage | COMPLETE | all 4 packets done 2026-05-16; boundary review passed 2026-05-16 (1 blocking follow-up resolved: README updated) |
| 1 — One concert E2E | IN PROGRESS | started 2026-05-16; see Phase 1 packet plan below |
| 2 — Browse/search/player | NOT STARTED | |
| 3 — Library/queue | NOT STARTED | |
| 4 — Downloads/offline | NOT STARTED | |
| 5 — Cover art | NOT STARTED | |
| 6 — Polish/TestFlight | NOT STARTED | |

## Deliverable log

One row per packet. **Status lifecycle is enforced** (`workflow/WORKFLOW.md`
§ "Discipline", `CLAUDE.md` § "Definition of done"):

`READY` (Packet creates) → `IN PROGRESS` (Build, before code) →
`COMPLETE | PARTIAL | BLOCKED` (Build, as its mandatory final step, copied from the
packet summary). A packet is not done until its row here matches its summary.

Scoped writes: **Build edits only its own row.** Phase status, the Blockers section, and
decision history are written by Review/Plan, never by Build. Format:

`| <packet-id> | <status> | <one-line outcome> | summary: <path> | deviations/follow-ups |`

| `00-001-xcode-skeleton` | COMPLETE | Xcode project, SwiftUI app target, three-tab shell (Home/Search/Library stubs) | summary: `workflow/packets/00-001-xcode-skeleton.summary.md` | — |
| `00-002-four-hooks` | COMPLETE | AudioStorage + DocumentsAudioStorage, DeepLinkRouter, Tag/LibraryRepository/PlaybackHistoryRepository stubs, tapescrape:// registered, 9 tests pass | summary: `workflow/packets/00-002-four-hooks.summary.md` | Info.plist properties must live in project.yml (XcodeGen overwrites direct edits); onOpenURL is a View modifier not Scene; test targets need GENERATE_INFOPLIST_FILE |
| `00-003-backend-hello` | COMPLETE | FastAPI app, /health route, core/{config,http_client,logging}.py, 1 test passes | summary: `workflow/packets/00-003-backend-hello.summary.md` | No editable install — pyproject.toml inside backend/ can't declare backend as a package; deps installed directly; run from repo root |

## Phase 0 boundary review (2026-05-16)

**Build checks:** `xcodebuild` BUILD SUCCEEDED (zero warnings), 9 Swift Testing tests
pass, `pytest backend/tests/` 1 test passes. No linter configured yet.

**Cross-file consistency:** No pattern drift — only 3 packets of implementation. Actor
stubs, Swift Testing, and XcodeGen usage are consistent across the two client packets.
No dead code. No layering violations.

**Doc-to-code reconciliation:**

| Issue | Location | Verdict |
|---|---|---|
| README claims "pre-implementation… no Xcode project and no backend code yet" | `README.md` lines 12–17 | 🔴 **Code is right, doc is wrong.** Phase 0 is complete; README must be updated. |
| CONVENTIONS §1 was marked "starter — unverified" | `workflow/CONVENTIONS.md` | Fixed in this review — module boundaries confirmed by shipped code. |
| CONVENTIONS §6 still "starter — unverified" (error handling) | `workflow/CONVENTIONS.md` | Left as-is — no error hierarchy shipped yet (Phase 1+ work). |
| `00-ARCHITECTURE.md` §3 describes the four hooks | `docs/design/00-ARCHITECTURE.md` | Code matches. Routes, protocol shapes, tag model, repository protocols all align. |
| `03-CLIENT-AND-PLAYBACK.md` §2 lists `PlaybackCoordinator`, `DownloadManager`, `CoverRenderer`, `Catalog` repo | `docs/design/03-CLIENT-AND-PLAYBACK.md` | These are future — doc describes intent, not current state. Not a discrepancy (the roadmap doesn't claim they exist yet). |

**Follow-ups:**

| # | Item | Urgency | Notes |
|---|---|---|---|
| F0-1 | Update `README.md` to reflect Phase 0 completion (remove "pre-implementation" language, add "Getting started" with actual build instructions) | 🔴 blocking | README claiming nonexistent state is the explicit anti-pattern from `IDEA.md` |
| F0-2 | `IAClient` rate limiter holds the lock across `asyncio.sleep` + the HTTP call; concurrent callers serialize unnecessarily | 🟡 important | Fine at single-user Phase 1 scale; fix before Phase 2 parallel aggregation |
| F0-3 | Add explicit `Sendable` conformance to `Tag`, `TaggedItem`, `PlayRecord` before enabling strict concurrency | 🟢 optional | Implicitly Sendable now; explicit conformance prevents future warnings |
| F0-4 | `AudioStorage.url(for:file:)` always returns non-nil (constructs path regardless of file existence); callers must check `fileExists` separately | 🟢 optional | Acceptable API shape for download-target use; note for Phase 4 |

## Blockers / open decisions

Mirror of the actionable items in `docs/design/04-OPEN-QUESTIONS.md` — the design doc is
authoritative; this is the at-a-glance tracker.

- ~~**D1 (minimum iOS)**~~ — RESOLVED 2026-05-16: iOS 17.
- ~~**Setlist source**~~ — RESOLVED 2026-05-16: IA-description parse only for v1; revisit
  only if insufficient in use.
- **D2b (backend host)** — user input, by end of Phase 1.
- **D3 (CloudKit vs local)** — user input, by Phase 3. Default local-only.
- **Library subset depth** — user input, by Phase 3. Default favorites + minimal
  playlists.
- **Re-aggregation trigger** — Plan-mode call at the aggregation phase. Default
  on-demand-when-stale.
- **D6 (cover-art look)** — user reference points, by Phase 5.
- **"Two builds"** — user, by Phase 6; only if review rejects a downloads-capable build.

## Decision history

- **2026-05-16** — D2 thin FastAPI backend; D2d scoped track search; D5 unified library;
  D7 Python+FastAPI+SQLite; spec = focused design package; workflow = slimmed solo loop.
  Resolved with the user before the spec was written.
- **2026-05-16 (follow-up)** — D1 confirmed iOS 17 (no older-device requirement);
  setlist source confirmed IA-description-only for v1. Phase 0 fully unblocked. See
  `docs/design/04-OPEN-QUESTIONS.md` § Resolved.
