# CONVENTIONS.md

Shared implementation conventions for TapeScrape. Read alongside `CLAUDE.md` and the
packet on every Build.

This is a **living, deliberately thin document.** Conventions are formalized here only
after a pattern has appeared in **two or more packets** — never speculatively (that is
the single rule that kept the predecessor's conventions doc from becoming fiction). It is
updated only in Review mode (`workflow/WORKFLOW.md`), at phase boundaries, to match
shipped code. If you discover a broadly-applicable pattern mid-Build, note it in the
packet summary's "Notes" — don't add it here yourself.

The sections below are the **starter**, aligned with `docs/design/`. Expect most to be
refined or replaced once real code exists. Where a section says _(starter — unverified)_
it has not yet been confirmed against shipped code.

---

## 1. Module boundaries

Two codebases. Boundaries follow `docs/design/00-ARCHITECTURE.md`.

**Backend (Python/FastAPI):**

| Layer | May import from |
|---|---|
| `core/` (config, logging, the one HTTP client) | stdlib + Pydantic |
| `models/` (Pydantic API + dataclasses) | core |
| `ia/` (Advanced Search + Metadata clients, parsing) | core, models |
| `aggregation/` (canonicalization, grouping, preferred pick) | core, models, ia |
| `api/` (FastAPI routes) | all of the above |

Circular imports are forbidden. `core/config` and `core/logging` are exempt (any layer).

**Client (Swift/SwiftUI):** feature code never touches SwiftData/SQLite directly — only
repository protocols. Audio I/O only through `AudioStorage`. Playback state only through
`PlaybackCoordinator`. Views never construct `archive.org` URLs.

## 2. Network access

- Backend calls **only the Internet Archive**, through the single `core` HTTP client
  (rate-limited, cached, logged). No ad-hoc `httpx`/`requests` in route or parsing code.
  Any other external host requires an explicit authorization note in the packet citing
  `CLAUDE.md` § "Network and external services."
- Backend **never** fetches/proxies/caches audio bytes. It returns opaque audio URLs.
- Client streams/downloads audio directly from `archive.org`; treats stream/download
  URLs as opaque strings from the backend.

## 3. The four hooks

`AudioStorage` protocol, `tapescrape://` URL scheme + routing, tag-first library,
repository pattern (`docs/design/00-ARCHITECTURE.md` § 3,
`03-CLIENT-AND-PLAYBACK.md` § 3). Installed Phase 0. Do not bypass; do not add
modularity beyond them.

## 4. Typed boundaries

- Backend API request/response: Pydantic models in `models/`. Internal cross-module
  structures: dataclasses (`frozen=True` where mutation isn't needed). Untrusted IA JSON
  is parsed through a typed model before use — never pass raw `dict` across a layer.
- Client: `Codable` structs / typed models for the catalog API; no untyped JSON or
  dictionaries across module boundaries.

## 5. Async

- FastAPI route handlers and any I/O function: `async def`.
- Client: structured concurrency (`async`/`await`); playback/download lifecycle off the
  view layer.

## 6. Error handling _(starter — unverified)_

- Backend: a typed exception root (e.g. `TapeScrapeError`) with intended subtypes for IA
  unavailability, rate-limiting, and not-found. API routes map known types to HTTP
  statuses with structured bodies. The concrete hierarchy is formalized here once it has
  shipped in ≥2 packets, not before.
- Client: playback distinguishes `stalled`/`failed(reason)` and always renders a retry
  affordance — never a silent hang (`docs/design/03-CLIENT-AND-PLAYBACK.md` § 4).

## 7. Testing

- `pytest` with no arguments **never** makes a live IA call. Live-IA tests are marked
  (e.g. `@pytest.mark.live_ia`) and skipped by default; otherwise use recorded fixtures.
- IA fixtures (real Advanced Search / Metadata JSON for known items, e.g. GD
  1977-05-08) live under the backend test tree and are loaded by a small helper. Capture
  fixtures from real responses; do not hand-fabricate IA shapes.
- Swift unit tests don't hit the network; the catalog API client is stubbed
  deterministically.
- Test file mirrors source: `ia/search.py` → `tests/ia/test_search.py`;
  `Foo.swift` → `FooTests.swift`.

## 8. Configuration

- Backend config via one settings module (env-var driven, prefixed `TAPESCRAPE_`). No
  hardcoded hosts, TTLs, or the optional static secret in feature code.
- Client config (backend base URL, audio-quality preference) in one place, not scattered
  literals.

---

## 9. XcodeGen as source of truth

`project.yml` is the canonical definition for the Xcode project. Info.plist properties
(URL schemes, orientations, launch screen) are declared in `project.yml → info.properties`,
not edited directly in `Info.plist`. Running `xcodegen generate` regenerates the
`.xcodeproj` and overwrites direct edits. Test targets use `GENERATE_INFOPLIST_FILE: YES`.

_Appeared in: 00-001-xcode-skeleton (`project.yml`), 00-002-four-hooks (URL scheme
registration, test target Info.plist fix)._

## 10. Swift Testing framework

Unit tests use Swift Testing (`import Testing`, `@Test`, `#expect`, `#require`) — not
XCTest. Test structs (not classes), no inheritance.

_Appeared in: 00-002-four-hooks (`AudioStorageTests.swift`, `DeepLinkRouterTests.swift`)._

## 11. Actor-based in-memory stubs

Repository protocol stubs use Swift `actor` for thread-safe state without manual locking.
Replace with persistence-backed implementations in later phases; the async protocol
signatures accommodate both.

_Appeared in: 00-002-four-hooks (`InMemoryLibraryRepository`, `InMemoryPlaybackHistoryRepository`)._

---

_New sections are added by Review at phase boundaries, citing the packets and file paths
where the pattern appeared. Do not add conventions speculatively._
