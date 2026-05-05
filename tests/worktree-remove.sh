#!/usr/bin/env bash
# Tests for scripts/worktree-remove
# Run from repo root: bash tests/worktree-remove.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/worktree-remove"
. "$REPO_ROOT/tests/helpers.sh"


# --- Test 1: Removes existing worktree from git worktree list ---
{
  repo=$(setup_repo_with_worktree "test-remove")
  parent="$(dirname "$repo")"
  base="$(basename "$repo")"
  wt_dir="$parent/${base}-worktrees/test-remove"

  cd "$repo" && bash "$SCRIPT" "$wt_dir" >/dev/null 2>/dev/null

  if ! git -C "$repo" worktree list 2>/dev/null | grep -q "test-remove"; then
    pass "worktree no longer in git worktree list after removal"
  else
    fail "worktree no longer in git worktree list after removal"
  fi

  cleanup "$repo"
}

# --- Test 2: Worktree directory no longer exists on disk ---
{
  repo=$(setup_repo_with_worktree "test-remove-disk")
  parent="$(dirname "$repo")"
  base="$(basename "$repo")"
  wt_dir="$parent/${base}-worktrees/test-remove-disk"

  cd "$repo" && bash "$SCRIPT" "$wt_dir" >/dev/null 2>/dev/null

  if [[ ! -d "$wt_dir" ]]; then
    pass "worktree directory no longer exists on disk"
  else
    fail "worktree directory no longer exists on disk (still present: $wt_dir)"
  fi

  cleanup "$repo"
}

# --- Test 3: Non-existent path exits 0 with stderr message ---
{
  tmp=$(mktemp -d)
  git -C "$tmp" init -q
  git -C "$tmp" config user.email "test@test.com"
  git -C "$tmp" config user.name "Test"
  touch "$tmp/README.md"
  git -C "$tmp" add README.md
  git -C "$tmp" commit -q -m "init"

  nonexistent="$tmp/does-not-exist"
  stderr_out=$(cd "$tmp" && bash "$SCRIPT" "$nonexistent" 2>&1 1>/dev/null)
  exit_code=0
  (cd "$tmp" && bash "$SCRIPT" "$nonexistent" >/dev/null 2>/dev/null) || exit_code=$?

  if [[ "$exit_code" -eq 0 ]]; then
    pass "non-existent path: exits 0"
  else
    fail "non-existent path: exits 0 (got exit code $exit_code)"
  fi

  if [[ -n "$stderr_out" ]]; then
    pass "non-existent path: message to stderr"
  else
    fail "non-existent path: message to stderr (stderr was empty)"
  fi

  rm -rf "$tmp"
}

# --- Test 4: Returns branch name on stdout before removal ---
{
  repo=$(setup_repo_with_worktree "branch-output-test")
  parent="$(dirname "$repo")"
  base="$(basename "$repo")"
  wt_dir="$parent/${base}-worktrees/branch-output-test"

  stdout=$(cd "$repo" && bash "$SCRIPT" "$wt_dir" 2>/dev/null)

  if [[ "$stdout" == "branch-output-test" ]]; then
    pass "branch name returned on stdout"
  else
    fail "branch name returned on stdout (got: '$stdout', expected: 'branch-output-test')"
  fi

  cleanup "$repo"
}

# --- Test 5: Hook script is executable ---
{
  hook_script="$REPO_ROOT/hooks/worktree-remove.sh"
  if [[ -x "$hook_script" ]]; then
    pass "hooks/worktree-remove.sh is executable"
  else
    fail "hooks/worktree-remove.sh is executable (not found or not executable)"
  fi
}

# --- Test 6: hooks/hooks.json references WorktreeRemove ---
{
  hooks_json="$REPO_ROOT/hooks/hooks.json"
  if grep -q "WorktreeRemove" "$hooks_json" && grep -q "worktree-remove.sh" "$hooks_json"; then
    pass "hooks/hooks.json references WorktreeRemove -> worktree-remove.sh"
  else
    fail "hooks/hooks.json references WorktreeRemove -> worktree-remove.sh"
  fi
}

summarize
