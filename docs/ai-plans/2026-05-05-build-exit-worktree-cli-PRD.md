# PRD: Build ExitWorktree and Worktree Remove CLI

> Status: draft
> Plan: ./2026-05-05-build-exit-worktree-cli-PLAN.md
> Created: 2026-05-05  |  Last touched: 2026-05-05

## Problem

The blueprint worktree lifecycle has two gaps after the prior worktree-per-feature implementation (completed April 2026):

1. `/build` enters a worktree via `EnterWorktree` but never exits. After all sections complete, the session context remains "inside" the feature branch. A developer who runs `/build` in their main repo window is stuck in the worktree context until they manually restart — there is no clean handoff back to the main repo.

2. Worktree cleanup requires Claude. There is no terminal-based CLI script in the plugin for developers who want to remove a worktree without opening a Claude session. The `/cleanup-worktree` skill covers the Claude-assisted path; nothing covers the manual path.

As a minor gap: `hooks/hooks.json` declares both `WorktreeCreate` and `WorktreeRemove`, but only `WorktreeRemove` has a corresponding assertion test in the test suite. `WorktreeCreate` has no hooks.json smoke test, making it easy to accidentally break the hook wiring without a test catching it.

## Solution

Three targeted additions that close the remaining lifecycle gaps:

1. Add `ExitWorktree` to `/build` after Step 6b (after the final PRD commit). The skill announces completion, exits the worktree, and prints the handoff message so the user is back in the main repo context before the session ends.

2. Add `scripts/worktree-remove-cli` to the plugin — a one-shot bash script that takes a branch name, computes the sibling worktree path, removes the worktree via `scripts/worktree-remove`, and prompts the developer to optionally delete the branch.

3. Add a `WorktreeCreate` hooks.json assertion to `tests/worktree-create.sh`, mirroring the equivalent test already in `tests/worktree-remove.sh`.

## User stories

1. As a developer, when `/build` completes all sections, I want my Claude session to return to the main repo context so I can do PR work without manually switching worktrees.
2. As a developer, I want to remove a worktree from the terminal using a script in the plugin, without needing a Claude session.

## Architecture & module sketch

- **`skills/build/SKILL.md`** — Add `ExitWorktree` call after Step 6b. Call it after the final PRD commit, before printing the handoff message. If no worktree was entered (no `Worktree:` field in the PLAN), skip `ExitWorktree`.
- **`scripts/worktree-remove-cli`** — New bash script. Takes `<branch-name>` as its only argument. Derives `WORKTREE_DIR` using the same sibling formula as `scripts/worktree-create`: `$(dirname "$REPO_ROOT")/$(basename "$REPO_ROOT")-worktrees/$BRANCH`. Calls `scripts/worktree-remove "$WORKTREE_DIR"` (relative to the script's own directory), captures the returned branch name, and prompts the user to optionally delete the branch.
- **`tests/build-worktree-entry.sh`** — Add grep assertions verifying `ExitWorktree` appears in the build skill's completion steps.
- **`tests/worktree-create.sh`** — Add hooks.json assertions for `WorktreeCreate`, mirroring tests/worktree-remove.sh lines 125–143.

## Testing approach

- `tests/build-worktree-entry.sh`: grep `skills/build/SKILL.md` for `ExitWorktree`. Assert it appears, and assert it is conditional on a `Worktree:` field being present (backwards-compat check).
- `tests/worktree-create.sh`: assert `hooks/worktree-create.sh` is executable; assert `hooks/hooks.json` references `WorktreeCreate` and `worktree-create.sh`.
- `tests/worktree-remove-cli.sh` (new): create a temp repo + sibling worktree; run the script with the branch name; assert worktree directory is gone; assert `git worktree list` no longer shows it. Branch-deletion prompt is interactive — skip it in the test by passing `n` via stdin.

## Out of scope

- Auto cleanup on session end (rejected during brainstorm — too risky for unmerged work)
- Changes to `scripts/worktree-create` (sibling path already implemented)
- Changes to `scripts/worktree-remove` (already correct)
- Updating `~/.claude/scripts/worktree-create` or `~/.claude/scripts/worktree-remove-cli` (global user scripts, not plugin-owned)
- Any changes to `/cleanup-worktree` skill (already complete and correct)

## Open questions

- [ ] Does `ExitWorktree` need to be called conditionally only if `EnterWorktree` was called earlier, or is it safe to call unconditionally (no-op if not in a worktree)?

## Future Considerations

- **`worktree-remove-cli` force-delete option**: Currently uses `git branch -d` (safe delete), which refuses to delete an unmerged branch. A `-f` / `--force` flag could be added for cases where the developer deliberately wants to discard unmerged work. Deferred because safe-delete is the right default.
- **Branch-push before removal**: A common workflow step is to push the feature branch before removing the worktree (so the branch isn't lost on cleanup). `worktree-remove-cli` could optionally run `git push -u origin <branch>` before removing the worktree. This was out of scope but would round out the handoff flow.
- **`/build` ExitWorktree signal to user**: The current Step 6c exits the worktree but the printed message is the same handoff line as before. A clearer "Exiting worktree — returning to main repo" line before the handoff message would make the context switch explicit for users who may be confused about where they are.
- **Automated test for ExitWorktree timing**: The current `tests/build-worktree-entry.sh` checks that `ExitWorktree` is present in the skill text, but does not verify it appears *after* Step 6b and *before* the handoff print. A positional grep (e.g., checking line order) would prevent regressions where the call moves to the wrong step.
- **`worktree-remove-cli` tab-completion**: The script could be registered as a git alias or have a shell completion stub so developers can tab-complete branch names. Currently requires the user to know the exact branch name.
- **hooks.json linting in CI**: The `WorktreeCreate`/`WorktreeRemove` hooks.json smoke tests are currently only run manually. Adding them to a lightweight CI check (e.g., a GitHub Actions step) would catch hook-wiring regressions before they reach users.
