# PLAN: Blueprint Skill Hardening

> PRD: ./2026-05-09-blueprint-skill-hardening-PRD.md
> Executor: /build
> Worktree: /Users/woodnt/Code/src/github.com/woodm1979/blueprint-worktrees/blueprint-skill-hardening
> Created: 2026-05-09  |  Last touched: 2026-05-09 (Section 1 complete)

## Architectural decisions

- All changes are additive edits to `skills/brainstorm/SKILL.md` and `skills/blueprint/SKILL.md` — no new files, no new modules
- `CONTEXT.md` integration assumes a file at the repo root; no path configuration needed
- The vertical-slice constraint is enforced via two locations in `/blueprint`: Step 5 (section proposal) and Step 7 (self-review checklist item 4, which already exists but is strengthened)
- Problem-first sequencing in `/brainstorm` defers solution proposals to after the grill-me loop, not eliminates them

## Conventions

- TDD per section (test → impl → commit)
- Minimum one commit per completed section
- Review checkpoint between sections (spec compliance + code quality)
- Default implementer model: `sonnet`

---

## Section 1: Brainstorm problem-first sequencing

**Status:** [x] complete
**Model:** haiku
**User stories covered:** 1

### What to build

Edit `skills/brainstorm/SKILL.md` to add a sequencing rule in the grill-me loop: problem questions must be exhausted before any solution shape is proposed. The existing instruction to "provide your recommended answer with brief reasoning" is moved or qualified so it applies only after the problem branch is fully resolved.

### Acceptance criteria

- [x] Running `/brainstorm` on a feature with multiple unexplored problem branches does not receive a solution proposal until all major problem questions have been asked and answered
- [x] The grill-me loop still surfaces a recommended answer for each question — it is deferred, not removed
- [x] The red flag list in SKILL.md includes a check for "solution proposed before problem questions exhausted"

### Notes for executor

- The key change is sequencing, not elimination: recommended answers still appear, just later
- Check the "Red flags — STOP and restart the message" section; add a new red flag for premature solution proposals
- Read the existing grill-me loop spec carefully before editing — the change should feel like a natural tightening, not a rewrite

### Completion log

- Commits: 956a9c7ea4d8a10b23a7fac79cb6a86c5f59ca00
- Tests added: 4
- Deviations from plan: none

---

## Section 2: Blueprint vertical-slice constraint

**Status:** [ ] not started
**Model:** sonnet
**User stories covered:** 2

### What to build

Edit `skills/blueprint/SKILL.md` to add an explicit vertical-slice constraint: each PLAN section must be a thin, demoable end-to-end behavior that cuts through all layers the feature touches (schema → API → UI → tests). Horizontal slices (one section = one layer) are explicitly disallowed. Wire this into Step 5 (section proposal criteria) and strengthen the existing Step 7 vertical-slice check.

### Acceptance criteria

- [ ] Step 5 in SKILL.md includes an explicit statement that sections must be vertical slices and defines what that means (thin, demoable, end-to-end through all touched layers)
- [ ] Step 5 explicitly names horizontal slices as a disallowed shape with an example (e.g., "Phase 1 = all schema, Phase 2 = all API" is wrong)
- [ ] Step 7's vertical-slice checklist item is strengthened to include a pass/fail test: "Is each section demoable on its own without depending on a subsequent section?"
- [ ] The "Red flags — STOP" list in SKILL.md names horizontal slices as a stop condition

### Notes for executor

- Step 7 checklist item 4 already mentions vertical-slice check — strengthen rather than duplicate
- The PLAN template's Section example should remain as-is; the constraint is in the instructions, not the template
- Cross-reference the coaching note in Step 5 ("Writing acceptance criteria — coaching note") since vertical slices and external acceptance criteria are related disciplines

### Completion log

<!-- Executor fills in after section completes -->
- Commits:
- Tests added:
- Deviations from plan:

---

## Section 3: CONTEXT.md integration

**Status:** [ ] not started
**Model:** sonnet
**User stories covered:** 3, 4

### What to build

Add CONTEXT.md awareness to both skills. In `skills/brainstorm/SKILL.md`: add a pre-interview step that reads `CONTEXT.md` from the repo root if it exists, using it to challenge fuzzy or conflicting terms during the grill-me loop. In `skills/blueprint/SKILL.md`: add a CONTEXT.md update offer to Step 10 (handoff), so new domain terms surfaced during the session can be captured.

### Acceptance criteria

- [ ] `/brainstorm` SKILL.md includes a pre-interview step (before Step 1) that reads `CONTEXT.md` if present; if absent, the step is skipped silently with no user-facing message
- [ ] The pre-interview step instructs Claude to use the glossary to challenge fuzzy terms during the grill-me loop (not to recite the glossary to the user)
- [ ] `/blueprint` Step 10 (handoff) includes an `AskUserQuestion` offering to update or create `CONTEXT.md` with domain terms surfaced during the session
- [ ] The CONTEXT.md offer in `/blueprint` is non-blocking: if the user declines, handoff proceeds normally
- [ ] Both SKILL.md files note that CONTEXT.md lives at the repo root (no path configuration)

### Notes for executor

- Keep the pre-interview step lightweight — it should not add perceptible overhead when CONTEXT.md doesn't exist
- The `/blueprint` CONTEXT.md offer should come AFTER the handoff message (or as a final step before it) — don't block the `/build` handoff on a CONTEXT.md decision
- CONTEXT.md format is plain markdown (key terms + definitions); no schema validation needed

### Completion log

<!-- Executor fills in after section completes -->
- Commits:
- Tests added:
- Deviations from plan:
