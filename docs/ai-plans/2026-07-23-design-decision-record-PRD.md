# PRD: Design Decision Record (DDR)

> Status: draft
> Plan: ./2026-07-23-design-decision-record-PLAN.md
> Created: 2026-07-23  |  Last touched: 2026-07-23

## Problem

The blueprint suite (`/brainstorm → /blueprint → /build`) ships a PRD, a PLAN, and a large diff — but throws away the *deliberation*. The tensions worked through during brainstorm (every tradeoff table, every fork, every "we chose X over Y"), and the decisions forced mid-build, leave almost no trace. A reviewer, or a future maintainer, receives verdicts without the trial: they can see *what* was built but not *why*, and — most costly — they cannot see the roads not taken, because a rejected alternative leaves no mark in the code at all.

The suite already surfaces some of this in the PRD/PLAN, but the friction points and the tensions that drove decisions are exactly what's missing. Capturing them well is the goal; capturing them *without* burying the signal under obvious, low-value entries is the constraint.

## Solution

Add a third committed artifact — `-DDR.md` (Design Decision Record) — as a sibling to the PRD and PLAN, one consolidated file per feature holding numbered entries `DDR-1..N`. It records *only non-obvious forks* and the tension behind each: the decision, what pulled the other way, the rejected alternative, and a concrete falsifiable consequence of flipping it.

`/blueprint` seeds the DDR by mining the same brainstorm transcript it already reads to write the PRD+PLAN. `/build-step` appends any genuinely new forks, dissent, or supersessions that arise during execution and fills in each entry's code links (`Touches:`). Build commits gain a `Refs: DDR-N` line, turning `git blame` into a "why" record permanently. PLAN's binding `## Architectural decisions` block stays terse for implementers but backlinks each decision to its DDR entry.

High signal-to-noise is enforced by hard gates baked into the entry schema and an adversarial-prune step in blueprint's self-review, so the file stays a record of real tension rather than a changelog of the obvious.

## User stories

1. As a plan author, when I run `/blueprint` after a brainstorm, I want a `-DDR.md` written alongside the PRD+PLAN capturing the non-obvious forks and their tensions, so a reviewer can see *why* the decisions were made.
2. As a plan author, I want PLAN's `## Architectural decisions` block to stay terse and binding for implementers while each decision backlinks `(see DDR-N)`, so binding guidance stays lean but traceable to rationale.
3. As the `/build-step` controller, I want to append genuinely new mid-build forks / dissent / supersessions to the DDR and fill each affected entry's `Touches:` code links, so the record reflects execution reality.
4. As a reviewer reading git history, I want build commits to carry a `Refs: DDR-N` line, so `git blame` reveals the reasoning behind a change.
5. As a reviewer opening the DDR, I want high-contention / one-way-door entries surfaced at the top (progressive disclosure), so I spend review attention proportionally to risk.
6. As a plan author, I want DDR entries kept high-signal — gated by a falsifiable `If-flipped`, no generic tension-language, and the invisible-in-the-diff rule — enforced by an adversarial-prune item in blueprint's self-review, so the file doesn't fill with entries nobody cares about.

## Architecture & module sketch

- **`skills/blueprint/SKILL.md`** — a DDR-seeding step (mine the transcript for non-obvious forks → write `-DDR.md`); the DDR file template + entry schema; the signal-to-noise gate rules; an adversarial-prune item added to the Step 7 self-review; `(see DDR-N)` backlinks in the PLAN template's decisions block.
- **`skills/build-step/SKILL.md`** — controller instructions to append new DDR entries (new fork / dissent / supersession) and to fill each touched entry's `Touches:`; a `Refs: DDR-N` line added to the section commit message.
- **DDR file format** — `docs/ai-plans/<date>-<slug>-DDR.md`: a progressive-disclosure header (high-contention / one-way-door entries first), then entries with `Decision / Tension / Rejected / If-flipped / Touches`, tagged `contention · door-type · tension-type`, with a `Status` that supports `superseded by DDR-M`.
- **`CLAUDE.md`** — a note directing that PR/MR bodies lead with the high-contention DDR entries (reviewer-agnostic; no names).
- **Tests** — `tests/ddr-*.sh` grep-based structural assertions over both SKILL.md files.
- **Release** — version bump in `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json`.

<The DDR is per-feature and per-feature-numbered; there is no global cross-feature DDR registry.>

## Testing approach

- **What makes a good test here:** this repo tests skill/prompt changes with grep-based structural assertions against the SKILL.md source — not runtime behavior. A good test pins a required instruction, template field, or step-ordering invariant so a future edit can't silently drop it.
- **Key behaviors to cover:** blueprint's SKILL.md contains the DDR-seeding step, the DDR template with every schema field (`Decision`, `Tension`, `Rejected`, `If-flipped`, `Touches`, `contention`, door-type, `Status`), the S/N gate rules, and the self-review prune item; build-step's SKILL.md contains the append-DDR instruction, the `Touches:` fill, and the `Refs: DDR-N` commit line; step-ordering invariants hold in both.
- **Prior-art references:** `tests/blueprint-skill.sh` (grep + step-ordering pattern), `tests/brainstorm-skill.sh`, and `tests/helpers.sh` (`pass`/`fail`/`summarize`). Follow these verbatim in style.

## Out of scope

- Auto-generated FAQ (collapses into `Rejected` + `If-flipped`).
- Self-sorting mechanical-vs-judgment commits (tracer-bullet build already slices by feature).
- Inline PR/MR review comments — deferred; a future render target of the `Touches:` links.
- Automated PR/MR body generation inside the skills — handled by a `CLAUDE.md` note, not code.
- Any change to `/brainstorm` or `/grill-me` (the transcript already contains the tension).
- Global, cross-feature DDR numbering or a repo-wide registry.

## Open questions

- [ ] `Refs: DDR-N` is per-feature-scoped, so it is ambiguous repo-wide. Accepted: commits live on the feature branch/worktree, so context disambiguates.
- [ ] Exact format of the auto-derived progressive-disclosure header (ranked list vs. table) — settle during blueprint template authoring.
