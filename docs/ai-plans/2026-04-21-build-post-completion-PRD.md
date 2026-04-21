# PRD: Build skill post-completion enhancements

> Status: draft
> Plan: ./2026-04-21-build-post-completion-PLAN.md
> Created: 2026-04-21  |  Last touched: 2026-04-21

## Problem

After `/build` finishes all sections, developers are left without automated code quality review or any capture of follow-up ideas. The session context — knowledge of what was built, what tradeoffs were made, and what questions surfaced — is warm at that moment but immediately starts to fade. Developers must manually remember to invoke `/simplify` on freshly written code, and they must manually document any future work ideas before they're forgotten.

Running `/simplify` on an entire codebase after a build is risky: it may touch code unrelated to the current feature, violating the surgical development discipline that the rest of the suite enforces. And "thinking of what to do next" without structured capture means good ideas get lost between sessions.

## Solution

Two new steps are added to `/build` immediately after all sections are confirmed complete:

**Step 1 — Conditional simplify.** The orchestrator checks whether the current branch contains any non-markdown code changes (via `git diff --name-only` against the base branch). If code files exist in the diff, it invokes `/simplify`, explicitly passing the list of changed files as args so that the simplification is scoped to only what the build touched. If only markdown files changed, the step is skipped silently.

**Step 2 — Future considerations.** The orchestrator generates a `## Future Considerations` section based on its knowledge of the completed build: things left undone, ideas that surfaced but were out of scope, edge cases worth revisiting. This section is appended to the PRD, committed, and followed by a handoff message pointing the developer to `/brainstorm` for evaluation.

## User stories

1. As a developer using `/build`, I want code quality to be reviewed automatically after all sections complete, so I don't have to remember to run `/simplify` separately.
2. As a developer, I want simplification scoped to only the files changed in the current branch, so unrelated existing code is never touched.
3. As a developer, I want markdown-only builds to skip the simplify step automatically, so useless invocations don't waste time.
4. As a developer, I want potential follow-up work captured in the PRD while build context is warm, so good ideas aren't lost between sessions.
5. As a developer, I want a clear handoff message after future considerations are written, so I know exactly what command to run next.

## Architecture & module sketch

- **`skills/build/SKILL.md`** — the only file modified. Two new steps are inserted after the existing Step 6 (completion announcement): Step 6a (conditional simplify) and Step 6b (future considerations).
- **`/simplify` invocation** — called via the Skill tool with `args` set to the list of branch-changed non-markdown files. This constrains the simplifier's scope without requiring any changes to the simplify skill itself.
- **PRD append** — the orchestrator locates the PRD (already referenced in the existing Step 6 completion message), appends the `## Future Considerations` section via file edit, and commits with message `docs: add future considerations to PRD`.

## Testing approach

- Manual invocation: run `/build` against a PLAN where all sections are already marked complete; verify Step 6a and 6b execute in order.
- Edge case: create a branch with only `.md` file changes; verify Step 6a is skipped.
- Edge case: create a branch with mixed `.md` and code changes; verify Step 6a invokes `/simplify` with the code files only.
- Verify the `## Future Considerations` section appears in the PRD after `/build` completes.
- Verify the handoff message is printed with the correct PRD path.

## Out of scope

- No changes to `/build-step`, `/brainstorm`, `/blueprint`, `/tdd`, or any other skill.
- No automated tests for skill behavior.
- No changes to how sections are built or reviewed.

## Open questions

- [ ] How to determine the base branch for git diff (implementation detail; executor should use `git merge-base HEAD main` or the current tracking remote — handle both `main` and `master`).
