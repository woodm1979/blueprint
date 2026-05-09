# PRD: Worktree Hook Hardening

> Status: draft
> Plan: ./2026-05-09-worktree-hook-hardening-PLAN.md
> Created: 2026-05-09  |  Last touched: 2026-05-09

## Problem

The `worktree-create.sh` hook uses a `cd`-based trick to locate the repo root from the script's own path, rather than reading the working directory from the event payload. This is fragile and violates the global rule against redundant `cd` usage. It also does not validate the `NAME` field from the payload — an empty or `"null"` value silently propagates to `scripts/worktree-create`, which may produce confusing failures downstream.

`hooks/worktree-remove.sh` and its `WorktreeRemove` entry in `hooks/hooks.json` are dead code: `WorktreeRemove` is not a real Claude Code event and will never fire. The companion skill `cleanup-worktree/SKILL.md` still documents Step 7 as if `WorktreeRemove` will trigger that hook, misleading both users and future AI executors.

A stale debug worktree (`test-things`) was left on disk and in the git worktree list during earlier development.

## Solution

Four targeted changes:

1. Rewrite `hooks/worktree-create.sh` to read `.cwd` from the stdin JSON payload and derive the repo root via `git -C "$CWD" rev-parse --show-toplevel`. Exit with a clear error if `NAME` is empty or the string `"null"`.
2. Delete `hooks/worktree-remove.sh` and remove the `WorktreeRemove` block from `hooks/hooks.json`.
3. Update `skills/cleanup-worktree/SKILL.md` Step 7 to run `git worktree remove --force "$WORKTREE_DIR" && git worktree prune` directly, removing all reference to the nonexistent `WorktreeRemove` event.
4. Remove the `test-things` worktree from disk and delete the `test-things` branch from git.

## User stories

1. As a plugin user, when `EnterWorktree` fires, the hook resolves the repo root from `.cwd` in the event payload so it works correctly regardless of the shell's current working directory.
2. As a plugin user, if `WorktreeCreate` fires with an empty or `"null"` NAME, the hook immediately exits non-zero with a human-readable error rather than silently proceeding.
3. As a plugin user, running `/cleanup-worktree` removes the worktree using direct git commands without attempting to call a nonexistent `WorktreeRemove` hook.
4. As a developer maintaining the plugin, `hooks.json` and the script files contain no dead code referencing `WorktreeRemove`.

## Architecture & module sketch

- **`hooks/worktree-create.sh`** — reads `.name` and `.cwd` from stdin JSON; validates NAME; derives REPO_ROOT via `git -C "$CWD"`; delegates to `scripts/worktree-create "$REPO_ROOT" "$NAME"`
- **`hooks/hooks.json`** — retains `WorktreeCreate` entry only; `WorktreeRemove` block removed
- **`hooks/worktree-remove.sh`** — deleted
- **`skills/cleanup-worktree/SKILL.md`** — Step 7 updated to use `git worktree remove --force` + `git worktree prune` directly

## Testing approach

- Subagent verifies `EnterWorktree` with a valid name creates the worktree at the expected path.
- Subagent verifies that passing an empty or `"null"` name causes the hook to exit non-zero with an error message.
- `hooks.json` is inspected to confirm `WorktreeRemove` is absent.
- `skills/cleanup-worktree/SKILL.md` is inspected to confirm no reference to `WorktreeRemove` remains.

## Out of scope

- Internals of `scripts/worktree-create` (not modified)
- Other hooks or scripts
- `payload-probe` and `build-exit-worktree-cli` worktrees

## Open questions

- [x] Should `test-things` branch be deleted from git? → Yes.
