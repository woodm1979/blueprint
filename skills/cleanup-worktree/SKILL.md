---
name: cleanup-worktree
description: Remove a feature worktree after merge with uncommitted/unpushed safety checks.
---

# /cleanup-worktree

## Overview

Safely removes a feature worktree after its branch has been merged. Given a PLAN file path, this skill:

1. Resolves the `Worktree:` field from the PLAN header.
2. Runs three sanity checks in order — uncommitted changes, unpushed commits, unmerged branch.
3. On confirmation, runs `"$CLAUDE_PLUGIN_ROOT/scripts/worktree-remove" "$WORKTREE_DIR"` (which runs any trusted `.worktree/pre_delete` teardown, unlocks, removes, and prunes).

## Process

### Step 1 — Accept input

The user provides a PLAN file path as an argument (e.g., `/cleanup-worktree path/to/PLAN.md`). If no path is given, check for exactly one `docs/ai-plans/*-PLAN.md` in the current repo; if ambiguous, ask the user.

### Step 2 — Resolve Worktree: field

Read the PLAN file. Extract the `> Worktree: <abs-path>` line from the blockquote header.

- If no `Worktree:` field is present: exit with a clear error message — "This PLAN has no Worktree: field. Nothing to clean up."
- If the `Worktree:` path does not exist on disk: print "Worktree directory does not exist — nothing to remove." and exit cleanly (exit 0).

Store the resolved path as `WORKTREE_DIR`.

### Step 3 — Determine default branch

Run:

```
git symbolic-ref refs/remotes/origin/HEAD | sed 's|refs/remotes/origin/||'
```

If this fails or returns empty, fall back to `main`.

Store as `DEFAULT_BRANCH`.

### Step 4 — Sanity check 1: Uncommitted changes

Run `git status --porcelain` inside the worktree (using `-C "$WORKTREE_DIR"` or equivalent).

If the output is non-empty:
- Print the list of uncommitted files.
- Print: "Worktree has uncommitted changes. Commit or stash them before cleaning up."
- **Stop. Do not remove the worktree.**

### Step 5 — Sanity check 2: Unpushed commits

Run `git log @{u}..HEAD` inside the worktree.

If the output is non-empty:
- Count the commits: `git log @{u}..HEAD --oneline | wc -l`
- Print: "Worktree has N unpushed commit(s). Push before cleaning up."
- **Stop. Do not remove the worktree.**

If the upstream is not set (the command fails), treat this as unpushed — warn the user and stop.

### Step 6 — Sanity check 3: Unmerged branch

Determine the feature branch name by running `git -C "$WORKTREE_DIR" symbolic-ref --short HEAD`.

Check if the branch is merged into the default branch:

```
git branch --merged <DEFAULT_BRANCH> | grep -qw <FEATURE_BRANCH>
```

If the feature branch is **not** in the merged list:
- Print: "Branch '<feature-branch>' has not been merged into '<default-branch>'."
- Ask for explicit confirmation: "Type 'yes' to remove anyway, or anything else to cancel."
- If the user does not type `yes` (case-insensitive): **stop without removing.**

### Step 7 — Remove worktree

Run the plugin's remove script, which runs any trusted `.worktree/pre_delete` teardown hook, defensively unlocks, then removes and prunes:

```
"$CLAUDE_PLUGIN_ROOT/scripts/worktree-remove" "$WORKTREE_DIR"
```

### Step 8 — Confirm

Print: "Worktree at '$WORKTREE_DIR' removed."

## Edge cases

- **Multiple PLANs:** If the repo has multiple PLAN files and no path was given, ask the user to specify one.
- **Detached HEAD in worktree:** If `symbolic-ref` fails (detached HEAD), report the worktree is in detached HEAD state and ask the user to inspect it manually before retrying.
- **No remote upstream:** If `@{u}` is unset, warn "No upstream tracking branch — cannot verify unpushed commits. Treat as unpushed." and stop.
