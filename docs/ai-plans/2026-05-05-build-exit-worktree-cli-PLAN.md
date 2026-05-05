# PLAN: Build ExitWorktree and Worktree Remove CLI

> PRD: ./2026-05-05-build-exit-worktree-cli-PRD.md
> Executor: /build
> Worktree: `/Users/woodnt/Code/src/github.com/woodm1979/blueprint-worktrees/build-exit-worktree-cli`
> Created: 2026-05-05  |  Last touched: 2026-05-05

## Architectural decisions

- **ExitWorktree placement**: Called after Step 6b (the final PRD commit) and before the printed handoff message. This ensures all commits that belong to the feature branch land before the session returns to main.
- **ExitWorktree conditionality**: Only call `ExitWorktree` when a `Worktree:` field was present in the PLAN (i.e., when `EnterWorktree` was called in Step 1). If no worktree was entered, skip silently — backwards-compat preserved.
- **worktree-remove-cli location**: `scripts/worktree-remove-cli` inside the plugin repo. Calls `scripts/worktree-remove` relative to its own directory (SCRIPT_DIR pattern), not the global `~/.claude/scripts/worktree-remove`. This keeps the plugin self-contained.
- **Sibling path formula**: Same as `scripts/worktree-create` — `$(dirname "$REPO_ROOT")/$(basename "$REPO_ROOT")-worktrees/$BRANCH`.

## Conventions

- TDD per section (test → impl → commit)
- Minimum one commit per completed section
- Review checkpoint between sections (spec compliance + code quality)
- Default implementer model: `sonnet`

---

## Section 1: ExitWorktree in /build + tests

**Status:** [ ] not started
**Model:** sonnet
**User stories covered:** 1

### What to build

Extend `skills/build/SKILL.md` to call `ExitWorktree` after Step 6b. The call is conditional: only when a worktree was entered in Step 1 (i.e., the PLAN had a `Worktree:` field). After `ExitWorktree`, print the existing handoff message so the user sees they are back in the main repo. Add grep assertions to `tests/build-worktree-entry.sh`.

### Acceptance criteria

- [ ] `skills/build/SKILL.md` contains an `ExitWorktree` call in the completion/handoff section
- [ ] The ExitWorktree call is guarded by the presence of a `Worktree:` field (backwards-compat: no ExitWorktree for plans without a worktree)
- [ ] `tests/build-worktree-entry.sh` passes including new assertions for ExitWorktree
- [ ] `bash tests/build-worktree-entry.sh` produces 0 failures

### Notes for executor

- Insert the `ExitWorktree` call after Step 6b's PRD commit but before (or as part of) the Step 6b handoff print. A new Step 6c is acceptable.
- Check the existing Step 1 logic — it sets context about whether a worktree was entered. The ExitWorktree guard should mirror that condition ("if `Worktree:` field was present").
- Grep test form: `skill_contains 'ExitWorktree' && pass "..." || fail "..."`. Add at least two: one asserting ExitWorktree is present, one asserting the backwards-compat guard is documented.

### Completion log

<!-- Executor fills in after section completes -->
- Commits:
- Tests added:
- Deviations from plan:

---

## Section 2: worktree-remove-cli script + hooks test

**Status:** [ ] not started
**Model:** haiku
**User stories covered:** 2

### What to build

Write `scripts/worktree-remove-cli` — a bash script that takes a branch name, computes the sibling worktree path, removes the worktree, and prompts to delete the branch. Add `tests/worktree-remove-cli.sh`. Also add `WorktreeCreate` hooks.json assertions to `tests/worktree-create.sh`.

### Acceptance criteria

- [ ] `scripts/worktree-remove-cli <branch>` removes the worktree at `<parent>/<repo>-worktrees/<branch>` from disk and from `git worktree list`
- [ ] The script prompts "Delete branch '<branch>'? [y/N]"; answering `y` deletes the local branch, `n` keeps it
- [ ] `tests/worktree-remove-cli.sh` passes: worktree removed, branch kept when `n` is passed via stdin
- [ ] `tests/worktree-create.sh` passes with new assertions: `hooks/worktree-create.sh` is executable; `hooks/hooks.json` references `WorktreeCreate` and `worktree-create.sh`
- [ ] `bash tests/worktree-remove-cli.sh` produces 0 failures
- [ ] `bash tests/worktree-create.sh` produces 0 failures

### Notes for executor

- `SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)` — use this to call `$SCRIPT_DIR/worktree-remove` so the script is self-contained within the plugin directory.
- `REPO_ROOT=$(git rev-parse --show-toplevel)` then `WORKTREE_DIR="$(dirname "$REPO_ROOT")/$(basename "$REPO_ROOT")-worktrees/$BRANCH"`.
- Branch deletion: `git branch -d "$BRANCH_NAME"` (safe delete, not force). Print result either way.
- Test pattern: create temp repo, create sibling worktree manually, run the script with `echo n |` piped to stdin to skip branch deletion, assert worktree is gone.
- Hooks assertions to add to `tests/worktree-create.sh` (mirror lines 125–143 of `tests/worktree-remove.sh`):
  - `hooks/worktree-create.sh` is executable
  - `hooks/hooks.json` references `WorktreeCreate` and `worktree-create.sh`

### Completion log

<!-- Executor fills in after section completes -->
- Commits:
- Tests added:
- Deviations from plan:
