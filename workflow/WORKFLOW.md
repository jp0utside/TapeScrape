# TapeScrape Workflow

A **slimmed solo loop** for building TapeScrape. This replaces the heavyweight four-role
package (Orchestrator / Manager / Implementer / Reviewer with strict cross-session
document ownership) that was copied from a previous multi-developer project. TapeScrape
is one person plus Claude building a personal-use app whose own planning docs warn
against over-speccing — the ceremony cost more than it bought here.

What's kept is the part that actually prevented drift in the predecessor (`set-scrape`,
which shipped a README describing features that didn't exist): **bounded packets, an
explicit out-of-scope discipline, a written summary per packet, and a phase-boundary
reconciliation that updates the docs to match the code.** What's dropped: per-role
cold-start prompts, the document-ownership matrix, mandatory fresh sessions per packet,
and outline-promotion protocol.

## Files

- `CLAUDE.md` (repo root) — universal rules; read every session.
- `workflow/WORKFLOW.md` — this file; the loop.
- `workflow/CONVENTIONS.md` — implementation conventions; grows at phase boundaries.
- `workflow/PACKET_TEMPLATE.md` — copy per bounded deliverable.
- `workflow/SUMMARY_TEMPLATE.md` — copy per completed packet.
- `workflow/packets/` — packets and their summaries (`<phase>-<nnn>-<slug>.md` /
  `.summary.md`). Created when work starts.
- `docs/development_roadmap.md` — phase sequencing/scope.
- `docs/roadmap_status.md` — the journal: current state, deviations, blockers.
- `docs/design/04-OPEN-QUESTIONS.md` — the decision log.

## The loop

Four modes, not four people. The same session can move between them; the labels just
name what you're doing. Most days you are in **Build**.

### 1. Plan (phase boundaries, or when the spec drifts)

When a phase is about to start, or the user says the project has drifted:

- Read the last phase's outcome in `docs/roadmap_status.md` and any review.
- Decide whether `docs/design/*` or `docs/development_roadmap.md` need updating *before*
  the next phase. Propose spec/roadmap edits in chat before writing — design wording is
  load-bearing.
- Resolve / defer / sharpen entries in `docs/design/04-OPEN-QUESTIONS.md`. Preserve
  history: append "Decision <date>" / "Deferred to Phase X", don't overwrite.
- Stop and ask the user for anything needing a value/preference judgment (cost, devices,
  legal posture). Never guess these.

### 2. Packet (start of each bounded deliverable)

- Pick the next bounded deliverable from the active phase (or a follow-up the last
  review flagged). State which.
- Write `workflow/packets/<phase>-<nnn>-<slug>.md` from `PACKET_TEMPLATE.md`.
  `<phase>` is two-digit; for fix work on a just-finished phase use `<phase>.5`.
- Scope it tight: target ~3–5 files. Mandatory "Out of scope" and "Known ambiguities"
  sections, specific, never vague. If it grows while drafting, split it.
- Calibrate the `Read first` list to complexity (a few files for trivial; design-section
  anchors for architecturally significant). Always-read floor is `CLAUDE.md`,
  `CONVENTIONS.md`, the packet itself — don't relist those. Add
  `docs/design/01-INTERNET-ARCHIVE.md` for any IA/aggregation/parsing work.
- Add the packet's row to the `docs/roadmap_status.md` deliverable log, status
  `READY`. This opens the packet's status lifecycle:
  `READY → IN PROGRESS → COMPLETE | PARTIAL | BLOCKED`.

### 3. Build (the bulk of the work)

- Read the always-read floor + the packet's `Read first` list, exactly.
- Restate the task in 3–6 bullets; surface ambiguity now. If `Auto-proceed: false` or
  `High-risk: true`, wait for explicit "go."
- Once cleared to proceed, set this packet's `docs/roadmap_status.md` row to
  `IN PROGRESS` before writing code. (Own row only — same scope rule as the close-out.)
- Implement the smallest change satisfying the acceptance criteria. Honor "Out of
  scope" — don't refactor adjacent code or fix unrelated bugs; note them in the summary
  instead.
- If a file outside "Files expected to change" needs editing, or the `Read first` list
  is insufficient, **stop and surface it** — the packet missed something. Don't silently
  expand scope.
- Add/update tests per the packet. No test makes a live IA call by default
  (`CLAUDE.md` § Testing).
- Write the summary to the packet's summary path using `SUMMARY_TEMPLATE.md`: acceptance
  criteria ✓/!/✗ with one-line evidence, files changed, tests + result, deviations,
  out-of-scope discoveries.
- **Close the packet's status row — mandatory final step, not skippable.** Transition
  this packet's row in `docs/roadmap_status.md` from `IN PROGRESS` to
  `COMPLETE | PARTIAL | BLOCKED`, copying the result, deviations, and follow-ups
  *verbatim from the summary you just wrote* (not editorialized — the summary is the
  shipped truth, so this keeps status in lockstep with code, never ahead of it).
  **Scope of this write is exactly this packet's own row.** Build does not touch
  phase-level status, the Blockers/Open-decisions section, decision history, or any
  other packet's row — those belong to Review/Plan. The packet is **not done** until
  this row matches the summary (`CLAUDE.md` § "Definition of done").

### 4. Review (phase boundary)

When a phase is code-complete:

- Read all packets/summaries for the phase and the source they touched. Run any
  linters / type checkers / `pytest` (default markers) / `swift build` available.
- Check cross-file consistency: repeated patterns wanting a shared abstraction, pattern
  drift, layering violations, dead code, inconsistent error handling, naming drift.
  Cite specific files/lines — no vague observations.
- **Reconcile docs to code.** Update `CONVENTIONS.md` for patterns that appeared in ≥2
  packets (never speculatively). Flag where `docs/design/*` no longer matches the code:
  if the code is right, propose the design edit; if the code is wrong, it's a follow-up
  packet. Flag any doc (incl. `README.md`) claiming a feature the code doesn't have —
  this is the specific failure mode that sank the predecessor.
- Record follow-ups in `docs/roadmap_status.md` with an urgency flag:
  🔴 blocking (fix before next phase) / 🟡 important (debt if deferred) / 🟢 optional.
- Update `docs/roadmap_status.md`: mark the phase, log deviations, list follow-ups.

## Discipline that survives the slimming

These are non-negotiable even though the roles are gone — they are what kept (or failed
to keep) the predecessor honest:

- **One bounded deliverable per packet.** No "implement Phase 2" packets.
- **Out-of-scope is mandatory and specific.** Vague entries produce drift.
- **A summary exists for every packet**, structured, not narrative.
- **`roadmap_status.md` is updated at every lifecycle transition — enforced, not
  optional.** The status journal must never lag the code. Hard rule: **a packet is not
  done until its deliverable-log row reflects its summary** (mirrored in `CLAUDE.md`
  § "Definition of done" and recorded in the summary's "Status journal" trailer so it is
  auditable). The scoped-write contract:

  | Doc | Plan | Packet | Build | Review |
  |---|---|---|---|---|
  | `docs/design/*`, `development_roadmap.md` | ✅ writes | — | — | proposes only |
  | `roadmap_status.md` — deliverable-log row | — | creates `READY` | ✅ own row → `IN PROGRESS` then `COMPLETE/PARTIAL/BLOCKED` from summary | per-phase reconcile |
  | `roadmap_status.md` — phase status / Blockers / decision history | sets blockers/decisions | — | ❌ never | ✅ writes |
  | `CONVENTIONS.md` | — | — | — | ✅ writes |
  | `CLAUDE.md` | — | — | — | only on explicit user direction |

- **Docs never lead code.** Don't write a README/spec describing unbuilt behavior. At
  every phase boundary, reconcile docs *down* to what actually shipped.
- **Stop and ask** on: ambiguous requirements, two source docs conflicting beyond
  `CLAUDE.md`'s precedence, a value/preference decision, or evidence a phase shouldn't
  be marked complete.

## Prompts (no per-role cold-starts needed)

- **Start a phase:** "Plan Phase N: read roadmap_status + the design package, tell me
  what's drifted, what needs deciding, and the first packet you'd write."
- **Next packet:** "Write the next packet for Phase N." → review it → "Build it."
- **Review a packet:** "Review <packet-id> against its packet and update
  roadmap_status."
- **Close a phase:** "Phase N is code-complete — do the phase review: reconcile docs,
  formalize conventions, flag follow-ups with urgency."
- **Workflow audit:** "Audit this workflow — is anything here costing more than it
  buys?" (this doc is allowed to change on that prompt, with user sign-off.)
