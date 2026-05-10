# PRD: Blueprint Skill Hardening

> Status: draft
> Plan: ./2026-05-09-blueprint-skill-hardening-PLAN.md
> Created: 2026-05-09  |  Last touched: 2026-05-09

## Problem

The `/brainstorm` skill anchors on a solution shape before the problem space is fully explored. The grill-me loop instructs Claude to provide a recommended answer alongside each question, which causes premature convergence — the user ends up reacting to a proposed solution rather than describing the problem. This leads to plan gaps that surface only during `/build`, costing roughly one in four sessions a replanning round.

The `/blueprint` skill has no explicit constraint on PLAN section shape. Sections tend to emerge as horizontal layers — all schema first, then all API, then all UI — rather than thin vertical slices that cut end-to-end through every layer. This conflicts with a TDD-first execution model: a test written against a horizontal layer can't be run until the adjacent layer is also in place, which breaks the red-green-refactor cycle.

On long-running codebases, domain context must be re-established from scratch at the start of every session. There is no persistent glossary; the same terms get explained repeatedly, consuming tokens and occasionally drifting in meaning between sessions.

## Solution

Three targeted rule additions to `skills/brainstorm/SKILL.md` and `skills/blueprint/SKILL.md`:

1. **Problem-first sequencing in `/brainstorm`** — add a sequencing rule that problem questions must be exhausted before any solution shape is proposed. The current instruction to "provide your recommended answer" is moved to a later phase, after the problem is fully mapped.

2. **Vertical-slice constraint in `/blueprint`** — add an explicit rule that each PLAN section must be a thin, demoable end-to-end behavior that cuts through all layers the feature touches (schema → API → UI → tests). Horizontal slices (one section = one layer) are explicitly disallowed.

3. **Low-friction `CONTEXT.md` awareness** — `/brainstorm` reads `CONTEXT.md` if one exists in the repo root before starting the grill-me loop, using it to challenge fuzzy or conflicting terms. `/blueprint` offers to update or create `CONTEXT.md` at Step 10 (handoff), capturing domain terms surfaced during the session.

## User stories

1. As a developer running `/brainstorm`, I want the skill to fully explore the problem space before proposing solutions, so my PLAN files don't have gaps that surface during `/build`.
2. As a developer writing a PLAN with `/blueprint`, I want each section to be a vertical slice, so every `/build` section is a thin, demoable, TDD-amenable end-to-end behavior.
3. As a developer on a long-running codebase, I want `/brainstorm` to auto-read `CONTEXT.md` at session start, so domain terms don't need to be re-explained each session.
4. As a developer completing a `/blueprint`, I want to be offered a `CONTEXT.md` update, so new domain terms encountered during brainstorming are captured persistently.

## Architecture & module sketch

- **`skills/brainstorm/SKILL.md`** — add a sequencing rule in the grill-me loop: problem questions first, solution proposals deferred; add a pre-interview step to read `CONTEXT.md` if present
- **`skills/blueprint/SKILL.md`** — add a vertical-slice constraint to Step 5 (section breakdown) and Step 7 (self-review vertical-slice check); add a `CONTEXT.md` update offer to Step 10 (handoff)

No new files, no new modules. Both changes are additive edits to existing SKILL.md files.

## Testing approach

- Manual: run `/brainstorm` on a real feature and verify that solution proposals are withheld until problem questions are exhausted
- Manual: run `/blueprint` on a real feature and verify that the generated PLAN sections are vertical slices (not layer-by-layer)
- Manual: place a `CONTEXT.md` in a test repo and verify `/brainstorm` reads and references it at session start
- Manual: complete a `/blueprint` run and verify the CONTEXT.md update offer appears at handoff

## Out of scope

- `/build` skill — no changes to execution orchestration
- `less-opinionated-superpowers` — no changes to that plugin
- TDD enforcement at `/build` execution time — deferred to future work
- New CONTEXT.md tooling, schemas, or validation — read/write of existing markdown only

## Open questions

- [ ] TDD enforcement at `/build` time: once section shape is fixed, should `/build-step` be instructed to default to red-green-refactor per section?

## Future Considerations

- **TDD enforcement in `/build-step`**: Now that section shape is locked to vertical slices, `/build-step` could explicitly require a failing test before any implementation begins. The current skill encourages TDD but doesn't enforce it; a hard gate would close the gap.
- **CONTEXT.md format guidance**: The current spec says "plain markdown (key terms + definitions)" with no schema. A lightweight convention (e.g., `## Term\n<definition>`) would make it easier for both Claude and humans to read and extend the glossary consistently.
- **Automated CONTEXT.md conflict detection**: When `/brainstorm` reads CONTEXT.md, it currently uses it only to challenge fuzzy terms during the grill-me loop. A future step could detect outright contradictions between a user's new framing and an existing glossary entry and surface them explicitly.
- **Section demoability enforcement in `/blueprint`**: The vertical-slice constraint is stated in the SKILL.md but enforced only via Step 7 self-review. An explicit `AskUserQuestion` checkpoint — "Can each of these sections be demoed independently?" — would make the gate interactive rather than advisory.
- **CONTEXT.md decay handling**: Glossary entries can go stale as a codebase evolves. A future `/blueprint` or `/brainstorm` step could flag entries that conflict with the current problem framing and offer to archive or revise them.
- **Multi-repo CONTEXT.md**: The current spec anchors CONTEXT.md to the repo root. For monorepos or multi-repo setups, per-package glossaries and a root-level aggregate may be worth specifying.
