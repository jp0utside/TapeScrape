# Task Packet: <short title>

**Packet ID:** <phase>-<nnn>-<slug>
**Phase:** <phase number>
**Created:** <ISO date>
**Status:** READY
**Auto-proceed:** true
**High-risk:** false

## Goal

<1–3 sentences. What does "done" mean for this packet?>

## Acceptance criteria

- [ ] <testable criterion>
- [ ] <testable criterion>
- [ ] <testable criterion>

## Read first

> Calibrate this list to packet complexity. Build reads exactly these files plus the always-read floor (CLAUDE.md, CONVENTIONS.md, this packet). Add `docs/design/01-INTERNET-ARCHIVE.md` for any IA/aggregation/parsing work. See `workflow/WORKFLOW.md` § "Packet" for guidance.

- <path> — <why this is needed for the task>
- <path> — <why>

## Files expected to change

- <path> — <nature of change>
- <path> — <nature of change>

## Interface sketch (optional but recommended for non-trivial packets)

> When the packet introduces a new interface, dataclass, API route, or schema, sketch it here in code-block form. Reduces the chance of structural disagreement at review time.

```
# Example (Python backend)
class ConcertAggregator:
    def aggregate(self, items: list[ArchiveItem]) -> list[Concert]: ...

# Example (Swift client)
protocol AudioStorage {
    func url(for identifier: String, file: String) -> URL
    func store(_ data: Data, identifier: String, file: String) throws
}
```

## Constraints to preserve

- See `workflow/CONVENTIONS.md` (always applicable)
- See `CLAUDE.md` § "Core constraints" (always applicable)
- <packet-specific constraint, if any>

## Tests

- REQUIRED | OPTIONAL | NONE
- If required: <what to add or update, with target test file paths>

## Known ambiguities / open questions

> Mandatory section. If none, write "none" explicitly.

- <item, or "none">

## Out of scope

> Mandatory section. Be specific. Vague entries produce drift.

- <explicit non-goal>
- <explicit non-goal>

## Summary output path

`workflow/packets/<packet-id>.summary.md`
