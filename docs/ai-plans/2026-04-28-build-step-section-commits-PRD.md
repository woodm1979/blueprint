# PRD: build-step Section Progress Commits

> Status: draft
> Plan: ./2026-04-28-build-step-section-commits-PLAN.md
> Created: 2026-04-28  |  Last touched: 2026-04-28

## Problem

When `/build` runs a plan, each section produces a variable number of commits. The current design commits PLAN file changes only at the end of a section — after both reviewers approve. There is no commit marking when a section began, and nothing in the git history signals that a section was actively in-progress. In practice this produces a commit pattern where multiple PLAN-only commits can appear near each other, making the history harder to navigate for human reviewers.

Additionally, because the only tracked PLAN states are `[ ] not started` and `[x] complete`, a crashed or interrupted build session cannot cleanly identify a section that was partially started. The `/build` orchestrator and `afk-build.sh` both use "count of not-started sections" as their progress signal, which becomes inaccurate if a crash leaves a section in a partially-started state.

## Solution

Add a pre-section commit to `/build-step`: before dispatching the section-controller, mark the section `[-] in progress` in the PLAN and commit `build: begin Section N (<Title>)`. This creates a clean, consistent 3-commit pattern per section:

1. `build: begin Section N (<Title>)` — PLAN marks section in-progress
2. Code commits from TDD cycle (1 or more)
3. `build: complete Section N (<Title>)` — PLAN marks section complete, acceptance criteria checked, completion log filled

The `[-] in progress` status also serves as crash-recovery state. If a session is interrupted after the pre-section commit, `/build-step` detects the in-progress section and resumes it without re-doing the pre-commit. The `/build` orchestrator and `afk-build.sh` are updated to recognize `[-] in progress` as incomplete.

## User stories

1. As a developer reviewing git history, I see a `build: begin Section N` commit that tells me exactly when each section's work started.
2. As a developer reviewing a commit, I see the acceptance criteria checked off in the final `build: complete Section N` commit, giving me concrete context for what the code change was expected to deliver.
3. As a developer resuming an interrupted build, `/build` correctly identifies and resumes a `[-] in progress` section rather than skipping it or declaring premature completion.
4. As a developer using `afk-build.sh`, a crash between the pre-section commit and completion does not cause the script to declare the build complete or blocked prematurely.

## Architecture & module sketch

- **`skills/build-step/SKILL.md`** — Step 2 updated to check `[-] in progress` first (crash recovery). New step inserted between select and dispatch: marks section `[-] in progress`, bumps `Last touched:`, commits. Step 4 updated to flip `[-] in progress` → `[x] complete`.
- **`skills/build/SKILL.md`** — Step 2 (section selection) updated to check for `[-] in progress` before `[ ] not started`, so a crashed section is resumed rather than skipped.
- **`scripts/afk-build.sh`** — `count_not_started()` replaced with `count_incomplete()` that counts both `[ ] not started` and `[-] in progress` sections. The "blocked" guard updated so it does not fire while any section is `[-] in progress`.

## Testing approach

Trust the skill text and script logic.

## Out of scope

- Changes to `/brainstorm`, `/blueprint`, or `/tdd` skills
- Changes to the `build: begin execution` commit in `/build` Step 1
- A `Started:` date field in PLAN files (git commit timestamp is sufficient)
- Changes to post-section commit content or timing

## Open questions

- (none)
