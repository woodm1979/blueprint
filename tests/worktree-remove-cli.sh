#!/usr/bin/env bash
# Tests for scripts/worktree-remove-cli
# Run from repo root: bash tests/worktree-remove-cli.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/worktree-remove-cli"
. "$REPO_ROOT/tests/helpers.sh"

# Setup: create a temp repo with a sibling worktree
setup_repo_with_worktree() {
  local branch="${1:-test-branch}"
  local dir
  dir=$(mktemp -d)
  git -C "$dir" init -q
  git -C "$dir" config user.email "test@test.com"
  git -C "$dir" config user.name "Test"
  touch "$dir/README.md"
  git -C "$dir" add README.md
  git -C "$dir" commit -q -m "init"

  local parent base wt_dir
  parent="$(dirname "$dir")"
  base="$(basename "$dir")"
  wt_dir="$parent/${base}-worktrees/$branch"
  mkdir -p "$parent/${base}-worktrees"
  git -C "$dir" worktree add -b "$branch" "$wt_dir" >/dev/null 2>&1

  echo "$dir"
}

cleanup() {
  local repo_dir="$1"
  local parent base
  parent="$(dirname "$repo_dir")"
  base="$(basename "$repo_dir")"
  rm -rf "$repo_dir"
  rm -rf "$parent/${base}-worktrees"
}

# --- Test 1: Worktree removed from git worktree list when 'n' answered ---
{
  repo=$(setup_repo_with_worktree "feature-x")

  echo n | bash "$SCRIPT" "feature-x" >/dev/null 2>&1 <<< "" || \
    echo n | (cd "$repo" && bash "$SCRIPT" "feature-x" >/dev/null 2>&1) || true
  # Run with repo as cwd so git rev-parse --show-toplevel returns $repo
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
