---
name: build
description: Use when executing sections from a PLAN file produced by /blueprint — dispatches one subagent per section that invokes /build-step, reads the completion signal, and loops until all sections are done. Part of the blueprint suite. For AFK (unattended) use, see scripts/afk-build.sh.
---

# /build

## Overview

Executor of the blueprint suite. Given a `-PLAN.md` file produced by `/blueprint`, this skill runs each `[ ] not started` section in order by dispatching a subagent that invokes `blueprint:build-step`. Each subagent handles the full section lifecycle internally and returns a `SECTION_COMPLETE`, `ALL_SECTIONS_COMPLETE`, or `BLOCKED: <reason>` signal. The orchestrator reads the signal, updates the PLAN file, and continues to the next section.

**AFK use:** For unattended overnight runs, see `scripts/afk-build.sh`. It calls `/build-step` in a fresh Docker sandbox process per section, detects completion by grepping the PLAN file, and announces results via `/usr/bin/say`.

The entire workflow is resumable across sessions: the PLAN file IS the state.

If the Agent tool is unavailable in the current harness, a **no-subagent fallback mode** is provided (see "No-subagent fallback" below). The subagent path is the default and preferred mode — output quality is significantly higher with subagent dispatch.

## REQUIRED BACKGROUND

**Granularity:** `/build` operates at SECTION granularity (an end-to-end tracer-bullet vertical slice). A section's implementer is expected to write multiple commits and produce several files — that's fine. The reviewers still run once per section, not once per commit.

## Precedence

If a repo's `CLAUDE.md`, `AGENTS.md`, or explicit user instructions conflict with this skill, user instructions win. Read those files before dispatching the first section.

## The discipline: focus, not isolation

**The real risk when running sections isn't context pollution — it's future-section overreach.** An implementer who reads ahead is tempted to add hooks, parameters, or abstractions that "might help Section 4 later." That's a YAGNI violation; the reviewer catches some of it, but not all.

The `/build-step` skill enforces this discipline within each section's execution. The orchestrator's job is to run sections in order and stop if blocked.

### Controller hygiene

Subagents dispatched via the `Agent` tool have no access to the controller's conversation history. That's automatic — you don't need to engineer it. Two things the controller should still watch:

1. **Don't embed your own reasoning in the subagent prompt.** Include the repo root and PLAN file path; exclude your commentary on them.
2. **When a prior section deviated, the plan file's completion log already captures that.** The subagent will read it. No need to restate it inline.

If the plan file is incomplete — a section's "What to build" can't actually be implemented from the plan + codebase alone — STOP execution, update the plan, and re-dispatch. Don't paper over plan gaps with private controller context.

## Process

### Step 1 — Locate and read the PLAN file

In order:

1. If the user `@`-referenced a `-PLAN.md` path, use it.
2. If there's exactly one `docs/ai-plans/*-PLAN.md`, use it.
3. If multiple candidates, `AskUserQuestion` with each + `"Let's discuss"`.
4. If none, tell the user to run `/blueprint` first.

Read the PLAN file end-to-end. Extract:

- The `## Architectural decisions` block (verbatim).
- Every `## Section N:` block.
- The `Worktree:` field from the blockquote header (format: `> Worktree: <abs-path>`), if present.

**Worktree entry (if `Worktree:` field is present):**

1. Parse the worktree absolute path from the `> Worktree:` line in the PLAN header.
2. Check if the worktree path exists in `git worktree list` output.
3. If the path is in the worktree list:
   - Call `EnterWorktree path: <abs-path>` to enter the existing worktree.
4. If the path is NOT in the worktree list (worktree was removed but PLAN still references it):
   - Derive the branch name from the worktree path by taking the last path component (e.g., `/path/to/blueprint-worktrees/my-feature` → `my-feature`).
   - Call `EnterWorktree name: <branch>` to auto-recreate the worktree.
5. After entering the worktree, re-derive the PLAN file path as `<worktree-abs-path>/docs/ai-plans/<plan-filename>`.
   - Extract the plan filename from the original path (e.g., `2026-04-23-my-feature-PLAN.md`).
   - Construct the new path: if worktree is at `/path/to/blueprint-worktrees/my-feature`, the PLAN is at `/path/to/blueprint-worktrees/my-feature/docs/ai-plans/2026-04-23-my-feature-PLAN.md`.
   - Verify the file exists at the new path. If not, report an error and fail.

**If no `Worktree:` field is present:** Skip the worktree entry steps entirely and proceed with the PLAN file as-is (backwards-compatible).

Bump `Last touched:` to today's date in the PLAN header and commit that single-line change with message `build: begin execution`.

### Step 2 — Select the next unstarted section

Grep the PLAN file for `**Status:** [ ] not started` (literal). The first match's section is the one to run.

If no match: announce "All sections complete" and stop.

### Step 3 — Dispatch section subagent

Dispatch a **sonnet** subagent with this prompt (fill in the actual repo root and PLAN file path):

```
Use the Skill tool (skill: "blueprint:build-step") to execute the next section. Invoke it immediately without preamble — do not read files, explore the repo, or do anything else first.
Repo root: <absolute-path-to-repo-root>
PLAN file: <absolute-path-to-PLAN.md>
```

**Worktree note:** Subagents dispatched via the `Agent` tool do not inherit `EnterWorktree` context from the orchestrator. If a worktree was entered in Step 1, use the **worktree path** as `Repo root` (not the main repo root) and the worktree's copy of the PLAN file as `PLAN file`. This ensures all git operations in the subagent land on the feature branch.

Use the `Agent` tool with `subagent_type: "general-purpose"`, model `sonnet`, and the prompt above.

### Step 3a — Read the completion signal

Read the final line of the subagent's response for one of:

- `SECTION_COMPLETE` → Proceed to Step 4.
- `ALL_SECTIONS_COMPLETE` → Announce completion (Step 5) and stop.
- `BLOCKED: <reason>` → Surface the reason to the user and stop. Do not update the PLAN file. Wait for user guidance before re-dispatching.

### Step 4 — Verify plan file was updated

`/build-step` updates the PLAN file and commits as part of its own Step 4. Verify the section's `**Status:**` is now `[x] complete` in the PLAN file. If it is not (indicating `/build-step` failed to update), surface the discrepancy to the user and stop.

### Step 4.5 — Context check

Before looping, check current context window usage.

If context is **above 45%**:

1. Do NOT proceed to Step 5.
2. Output exactly (substitute real paths):

   > **Context window above 45% — pausing before the next section.**
   >
   > Run `/clear`, then resume with:
   >
   > ```
   > /build <path-to-PLAN.md>
   > ```
   >
   > `/build` resumes automatically from the next `[ ] not started` section.
   >
   > PRD: `<path-to-PRD.md>`

3. Stop. Do not loop.

If context is **45% or below**: proceed to Step 5 without comment.

### Step 5 — Continue automatically

Go back to Step 2 and select the next `[ ] not started` section.

**Only stop the loop when:**

1. No `[ ] not started` sections remain → announce completion and exit.
2. Subagent returned `BLOCKED: <reason>` → surface to user and wait.
3. The user interrupts the session.

The orchestrator MAY emit a one-sentence summary between sections ("Section 2 complete, moving to Section 3") but this summary NEVER enters the next subagent's prompt.

### Step 6 — Completion announcement

When all sections are complete, announce exactly:

> All sections in `<path-to-PLAN.md>` are complete. PRD: `<path-to-PRD.md>`. Last section committed in `<SHA>`.

### Step 6a — Conditional simplify

After the Step 6 announcement, determine whether the branch contains any non-markdown code changes:

```
git diff --name-only $(git merge-base HEAD main) HEAD
```

If `main` is not a valid ref, retry with `master`.

Filter the resulting file list to exclude any path ending in `.md`.

- If the filtered list is **empty**: skip this step silently (no message, no invocation).
- If the filtered list is **non-empty**: invoke the `simplify` skill via the Skill tool:
  - `skill: "simplify"`
  - `args: "Scope your review to these branch-modified files only: <space-separated file list>"`

### Step 6b — Future considerations generation and handoff

After Step 6a (or after Step 6 if Step 6a was skipped), generate a `## Future Considerations` section and append it to the PRD file.

The `## Future Considerations` section should contain bulleted suggestions based on your knowledge of the completed build: follow-up ideas, edge cases worth revisiting, improvements identified but deemed out of scope. Aim for 3–7 items. If you can think of no meaningful suggestions, still append the section with a single bullet: `- No additional items identified at this time.`

Append the section to the PRD file, then commit **only the PRD file** with message `docs: add future considerations to PRD`.

Print exactly:

> Future considerations written to `<PRD path>`. Run /brainstorm and review the **Future Considerations** section to evaluate next steps.

## No-subagent fallback mode

**When to use:** Only when the Agent tool is unavailable in the current harness (no subagent support). The subagent-driven path above is strictly preferred — quality is significantly higher with fresh-context subagents and independent reviewers. Tell your human partner that `/build` works much better with access to subagents, and if possible switch to a harness that supports them.

**What changes:** The controller (you) invokes `/build-step` sequentially in the single session rather than dispatching it in a subagent. The PLAN state machine and section-level granularity are unchanged — you still run one section at a time, in order, and update the plan file between sections.

**Process in fallback mode:**

1. **Step 1–2 unchanged:** locate the PLAN file, bump `Last touched:`, commit `build: begin execution`, then grep for the next `**Status:** [ ] not started`.
2. **Step 3 (sequential):** Instead of dispatching a subagent, invoke `blueprint:build-step` directly. `/build-step` will run the full section lifecycle and output `SECTION_COMPLETE`, `ALL_SECTIONS_COMPLETE`, or `BLOCKED: <reason>`.
3. **Step 3a–6 unchanged:** read the completion signal and act accordingly.

**Fallback-mode discipline:**

- Never start implementation on `main` / `master` without explicit user consent.
- The two manual checkpoints inside `/build-step` are not optional — they are the only quality gates in this mode.

## Model selection

| Role | Default model | Why |
|---|---|---|
| Section subagent | `sonnet` | Loads `/build-step` and handles the full lifecycle. |

The section-controller, implementer, and reviewer model assignments are governed by `/build-step`.

## Rationalization table

| Excuse | Reality |
|---|---|
| "The reviewer is just going to approve — I'll skip the dispatch" | Every section runs through `/build-step`. No shortcuts. |
| "The user said 'run sections 2 and 3' — I'll skip picking next-unstarted and just go by that" | Grep for `[ ] not started` anyway. The user may have misremembered; the plan file is authoritative. |
| "I'll mark the section complete even though the subagent returned BLOCKED" | If the signal is BLOCKED, surface it to the user. Do not update the PLAN file. |
| "Let me batch sections into one subagent to save dispatches" | One subagent per section is the discipline — each section gets reviewed before the next begins. |
| "The plan is ambiguous on a decision — I'll have the subagent just pick something" | No. The plan is the contract; ambiguity means the contract is incomplete. Pause, clarify with the user, edit the plan, commit, then dispatch. |

## Red flags — STOP

- Next section selected via "user said to" rather than grep for `[ ] not started`
- Plan file not updated after section completes
- Plan-file update not committed before moving to next section
- `Last touched:` not bumped
- Progressing to next section while any acceptance criterion is still `- [ ]`
- Subagent returned `BLOCKED` and orchestrator continues anyway
- Starting implementation on `main` / `master` without explicit user consent
- In no-subagent fallback mode: skipping `/build-step`'s quality gates or marking a section complete without a passing completion signal

## Resumption across sessions

Because the PLAN file IS the state:

- Starting `/build` in a new session works identically to continuing in the same session. The skill reads the PLAN file, greps for the next `[ ] not started`, and runs that section. No in-memory state is required.
- The only reminder the controller needs is the PLAN file path — ideally supplied by the user via `@`-reference.

## When NOT to use

- PLAN file doesn't exist yet → run `/blueprint` first.
- Only small, inline edits are needed (no sections) → just make them.
- The plan uses a different format (not blueprint `-PLAN.md` with the `[ ] not started` / `[x] complete` state machine) → `/build` expects that specific format.
- For AFK unattended runs → use `scripts/afk-build.sh` directly (calls `/build-step` per section in a fresh Docker sandbox process).
