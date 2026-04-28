# PLAN: Brainstorm Escape-Hatch UX

> PRD: ./2026-04-28-brainstorm-escape-hatch-ux-PRD.md
> Executor: /build
> Created: 2026-04-28  |  Last touched: 2026-04-28

## Architectural decisions

- Single file modified: `skills/brainstorm/SKILL.md` (repo source, not plugin cache).
- All changes are prose/instruction edits — no code, no schema, no new files.
- Sections are sequential; Section 2 depends on the UX rules structure settled in Section 1.

## Conventions

- TDD per section (test → impl → commit)
- Minimum one commit per completed section
- Review checkpoint between sections (spec compliance + code quality)
- Default implementer model: `sonnet`

---

## Section 1: Fix "Let's discuss" post-selection behavior

**Status:** [ ] not started
**Model:** haiku
**User stories covered:** 1

### What to build

After any "Let's discuss" selection — whether during a Step 1 interview question or at the Step 3 artifact gate — Claude must respond with "What's on your mind?" as plain prose and wait for the user to type freely. `AskUserQuestion` must not be called again until after the user has spoken.

### Acceptance criteria

- [ ] UX rules section contains an explicit rule stating that when "Let's discuss" is selected, Claude responds with "What's on your mind?" and waits before calling `AskUserQuestion` again.
- [ ] Step 1 instructions include the post-"Let's discuss" behavior (ask open question, wait).
- [ ] Step 3 artifact gate instructions replace the vague "discuss inline" wording with the same explicit behavior.
- [ ] Red flags list includes: "About to call `AskUserQuestion` immediately after a 'Let's discuss' selection without first asking an open question → stop."

### Notes for executor

- Read `skills/brainstorm/SKILL.md` from the repo source, not the plugin cache (`~/.claude/plugins/cache/`).
- The artifact gate currently says "If **Let's discuss**, discuss inline, then call `AskUserQuestion` again with the same four options." Replace "discuss inline" with the explicit prompt-and-wait instruction.
- Keep changes surgical — do not touch unrelated UX rules or process steps.

### Completion log

<!-- Executor fills in after section completes -->
- Commits:
- Tests added:
- Deviations from plan:

---

## Section 2: Add "Skip to planning" and prohibit invented options

**Status:** [ ] not started
**Model:** haiku
**User stories covered:** 2, 3

### What to build

Add "Skip to planning" as a second required escape hatch on every Step 1 `AskUserQuestion` call. When selected, Claude jumps to Step 2 (decision summary) and then Step 3 (artifact gate), skipping remaining interview questions. Separately, add a prohibition on inventing options beyond what the spec defines.

### Acceptance criteria

- [ ] UX rules section contains a rule stating that every Step 1 `AskUserQuestion` call MUST include an option whose `label` is exactly `"Skip to planning"`.
- [ ] Step 1 instructions define the behavior when "Skip to planning" is selected: proceed immediately to Step 2 (decision summary), then Step 3 (artifact gate).
- [ ] UX rules section contains a rule prohibiting invented/ad-hoc options not defined in the skill spec.
- [ ] Red flags list includes: "About to add an option not defined in the skill spec (e.g., 'Chat about this', 'Skip interview and plan immediately') → remove it."
- [ ] "Skip to planning" does NOT appear as a required option for the Step 3 artifact gate (it has no meaning there).

### Notes for executor

- "Skip to planning" goes alongside "Let's discuss" as the second required escape hatch — both are literal labels.
- The prohibition on invented options should explicitly name "Chat about this" as an example of a banned ad-hoc option, so future model instances recognize it.
- The artifact gate already has its own fixed options — no changes needed there beyond what Section 1 covered.

### Completion log

<!-- Executor fills in after section completes -->
- Commits:
- Tests added:
- Deviations from plan:
