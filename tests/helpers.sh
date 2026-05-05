#!/usr/bin/env bash
PASS=0
FAIL=0
pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }
summarize() { echo ""; echo "Results: $PASS passed, $FAIL failed"; [[ $FAIL -eq 0 ]]; }

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
