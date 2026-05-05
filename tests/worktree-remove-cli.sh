#!/usr/bin/env bash
# Tests for scripts/worktree-remove-cli
# Run from repo root: bash tests/worktree-remove-cli.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/worktree-remove-cli"
. "$REPO_ROOT/tests/helpers.sh"


# --- Test 1: Worktree removed from git worktree list when 'n' answered ---
{
  repo=$(setup_repo_with_worktree "feature-x")

  echo n | (cd "$repo" && bash "$SCRIPT" "feature-x") >/dev/null 2>&1 || true

  if ! git -C "$repo" worktree list 2>/dev/null | grep -q "feature-x"; then
    pass "worktree removed from git worktree list"
  else
    fail "worktree removed from git worktree list (still listed)"
  fi

  cleanup "$repo"
}

# --- Test 2: Worktree directory no longer exists on disk ---
{
  repo=$(setup_repo_with_worktree "feature-y")
  parent="$(dirname "$repo")"
  base="$(basename "$repo")"
  wt_dir="$parent/${base}-worktrees/feature-y"

  echo n | (cd "$repo" && bash "$SCRIPT" "feature-y") >/dev/null 2>&1 || true

  if [[ ! -d "$wt_dir" ]]; then
    pass "worktree directory no longer exists on disk"
  else
    fail "worktree directory no longer exists on disk (still present: $wt_dir)"
  fi

  cleanup "$repo"
}

# --- Test 3: Branch kept when 'n' is answered ---
{
  repo=$(setup_repo_with_worktree "keep-branch")

  echo n | (cd "$repo" && bash "$SCRIPT" "keep-branch") >/dev/null 2>&1 || true

  if git -C "$repo" branch --list "keep-branch" | grep -q "keep-branch"; then
    pass "branch kept when 'n' answered"
  else
    fail "branch kept when 'n' answered (branch was deleted)"
  fi

  cleanup "$repo"
}

# --- Test 4: Branch deleted when 'y' is answered ---
{
  repo=$(setup_repo_with_worktree "delete-branch")

  echo y | (cd "$repo" && bash "$SCRIPT" "delete-branch") >/dev/null 2>&1 || true

  if ! git -C "$repo" branch --list "delete-branch" | grep -q "delete-branch"; then
    pass "branch deleted when 'y' answered"
  else
    fail "branch deleted when 'y' answered (branch still exists)"
  fi

  cleanup "$repo"
}

summarize
