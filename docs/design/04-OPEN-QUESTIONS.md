# 04 — Open Questions & Decision Log

Tracks the `tape_scrape/03-open-design-decisions.md` decisions (D1–D8) plus ambiguities
surfaced while writing this package. A question is well-formed when it names the decision,
the options, what's resolved, and — if open — what's missing and who owns it.

This is the **orchestrator's working surface** in the slimmed workflow. Resolve, defer,
or sharpen entries here as phases progress; preserve history (append, don't overwrite).

---

## Resolved (decided with the user, 2026-05-16)

| ID | Decision | Resolution | Where it lives |
|---|---|---|---|
| **D2** | Backend: none / thin / indexed | **Thin Python+FastAPI backend** — IA aggregation + caching only. No audio proxying. | `00-ARCHITECTURE.md` § 1–2 |
| **D2d** | Per-track search in v1 | **Scoped:** index tracks of opened recordings only; global crawl is future F1; `type=track` in the API from day one. | `00` § 4 |
| **D5** | Library model | **Unified storage + pinned flag**; record-shelf feel via UI. | `02-DATA-MODEL.md` § 5 |
| **D7** | Backend stack | **Python + FastAPI + SQLite.** | `00` § 5 |
| **D1** | Minimum iOS | **iOS 17** (confirmed by user 2026-05-16). Buys `@Observable` + modern `NavigationStack`/scroll APIs. No older-device requirement. | `03-CLIENT-AND-PLAYBACK.md` § 1 |
| — | Setlist source (v1) | **IA `description` parse only.** No external service (Setlist.fm / SetlistAI corpus) in v1; revisit only if IA-description proves insufficient in use. | roadmap Phase 4 |
| — | Spec format | **Focused design package** + `development_roadmap.md` + `roadmap_status.md`. | this package |
| — | Workflow weight | **Slimmed solo loop**, not the full four-role machine. | `workflow/WORKFLOW.md` |

## Resolved with a default (low-stakes; confirm if convenient, otherwise these stand)

These don't fork the architecture, so the design proceeds on the default rather than
blocking. Override anytime.

- **D4 — Auth: no user auth in v1.** Backend is single-tenant, single-digit RPM. An
  **optional static shared-secret header behind a config flag** is the only access gate
  (cheap "keep honest people honest" for a public host). No accounts, no Sign in with
  Apple, no JWT in v1 — that removes the App Store account-deletion rule and the
  password-storage surface entirely. *Revisit only if* the audience widens beyond
  personal use. Owner: user, only if scope changes.
- **D6 — Cover art: procedural in v1**, behind `CoverRenderer`. A short visual-design
  doc precedes the generator (Phase 5). *Needs from user (by Phase 5):* any visual
  reference points (apps, album-cover styles) to anchor the aesthetic. Owner: user, by
  Phase 5.
- **D8 — Modularity: exactly the four hooks**, nothing more (`00` § 3). Settled by the
  ecosystem analysis; no further action.

## Deferred to a later phase (correctly not decided yet)

- **D2b — Backend host (Fly.io vs Railway vs small VPS vs home box + Tailscale).**
  Local `uvicorn` is enough for Phases 0–1. Decide when the client first needs a real URL
  off the home network (Phase 1 end). Inputs that decide it: do you have an always-on
  machine already; how often you use the app on cellular vs. home Wi-Fi; willingness to
  pay ~$0–10/mo. Owner: user, at Phase 1 boundary.
  **Decision 2026-05-17 (user):** *consciously deferred* — stay on local `uvicorn`
  through Phase 2. Phase 2 (browse/search/player) is fully developable and testable on
  home Wi-Fi; no host is needed for the phase to be usable as the roadmap promises. The
  host pick itself remains open with a concrete **revisit trigger: the first time the app
  needs to be reachable off home Wi-Fi** (cellular / away from home). This is the
  Phase-1-boundary decision the roadmap asked for — the decision is "not yet, and here is
  exactly when." No backend code depends on it.
- **D3 — CloudKit sync vs local-only.** v1 is **local-only**; the only v1 cost paid now
  is a custom-zone-shaped library container so a future `LibraryZone`/shared zones (F8)
  need no migration. Decide at Phase 3 (library). Inputs: how many Apple devices run it;
  whether "wipe phone and restore library" matters; OK with the "must be signed into
  iCloud" constraint. Owner: user, at Phase 3 boundary.

## Open ambiguities surfaced writing this package (need user input before the noted phase)

1. **Library organization depth for v1 (Phase 3).** `IDEA.md`/goals list favorites,
   playlists, smart collections, tags, and notes as all appealing; v1 needs at least
   favorites. Which subset is *essential* for the first usable library vs. deferrable?
   The tag-first model supports all of them, so this is a scope/sequencing call, not an
   architecture one. *Owner: user, at Phase 3.* Default if unanswered: favorites +
   minimal playlists, defer smart collections/notes.
2. **Setlist enrichment source — RESOLVED 2026-05-16: IA `description` parse only for
   v1.** No external service (Setlist.fm API, SetlistAI corpus) in v1. v1 stays IA-only,
   preserving the zero-extra-network-surface posture of `CLAUDE.md` § "Network and
   external services." Revisit *only if* IA-description parsing proves insufficient in
   actual use — adding a source then is additive (a new enrichment provider behind the
   same concert-detail surface), not a rewrite. Track-level setlist↔audio alignment
   remains explicitly future regardless of source.
3. **"Two builds" App Store strategy.** `tape_scrape/06` floats a streaming-only listed
   build + a downloads-capable unlisted build. Recommendation stands: don't pre-commit;
   keep it a feature-flag, decide at the TestFlight/submission phase if review rejects a
   downloads-capable build. *Owner: user, at Phase 6.* No v1 work beyond clean feature-
   flag hygiene.
4. **Re-aggregation trigger — RESOLVED 2026-05-17: on-demand-when-stale.** Concerts are
   persisted and re-aggregated "when new items appear." Decision (orchestrator, user-
   confirmed): when an artist is browsed, re-aggregate iff the persisted aggregation for
   that artist is older than a configurable TTL; otherwise serve persisted concerts.
   Simplest for single-user scale; no background scheduler, no extra infra. Manual /
   periodic mechanisms remain additive behind the same persisted-concert model if ever
   needed. Original framing kept for history: options were on-demand-when-stale (chosen),
   periodic per-followed-artist job, manual.

## How to use this doc

- Move a question to **Resolved** with the resolution and the artifact that resolved it
  (user decision, phase finding) when it's decided.
- Add questions surfaced by a phase; sharpen vague ones as evidence accumulates.
- An entry that needs a *value/preference judgment* (cost ceiling, legal posture, which
  devices) is the user's to answer — surface it, never guess it.
