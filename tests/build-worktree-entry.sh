#!/usr/bin/env bash
# Tests for skills/build/SKILL.md — validates Section 4 worktree entry requirements
# Run from repo root: bash tests/build-worktree-entry.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$REPO_ROOT/skills/build/SKILL.md"
. "$REPO_ROOT/tests/helpers.sh"

skill_contains() {
  grep -qF "$1" "$SKILL"
}

skill_matches() {
  grep -qE "$1" "$SKILL"
}

# AC: Step 1 reads Worktree: field from PLAN header after parsing it
skill_contains 'Worktree:' \
  && pass "Step 1 mentions Worktree: field" \
  || fail "Step 1 missing Worktree: field handling"

# AC: If field present and directory exists, call EnterWorktree path:
skill_contains 'EnterWorktree path:' \
  && pass "Step 1 calls EnterWorktree path: for existing worktree" \
  || fail "Step 1 missing EnterWorktree path: call"

# AC: If field present but directory missing, auto-recreate via EnterWorktree name:
skill_contains 'EnterWorktree name:' \
  && pass "Step 1 calls EnterWorktree name: for missing worktree" \
  || fail "Step 1 missing EnterWorktree name: call for auto-recreate"

# AC: After entering, re-derive PLAN file path
skill_matches '<worktree.*path>.*docs/ai-plans' \
  && pass "Step 1 re-derives PLAN file path in worktree" \
  || fail "Step 1 missing PLAN file path re-derivation"

# AC: If no Worktree: field, proceed as before (backwards-compatible)
skill_contains 'no \`Worktree:\`' || skill_contains 'no Worktree:' || skill_contains 'If no' \
  && pass "Step 1 handles missing Worktree: field (backwards compat)" \
  || fail "Step 1 missing backwards compatibility handling"

# AC: Branch name derivation from path (last component)
skill_matches 'last.*component' || skill_matches 'basename' || skill_contains 'path component' \
  && pass "Step 1 derives branch name from worktree path" \
  || fail "Step 1 missing branch name derivation logic"

# AC: Parse Worktree: line from blockquote header (> Worktree: <abs-path>)
skill_matches '> Worktree:.*<' || skill_contains '`> Worktree:`' \
  && pass "Step 1 documents Worktree: line format in blockquote" \
  || fail "Step 1 missing Worktree: line format documentation"

# AC: Check worktree existence before calling EnterWorktree
skill_contains 'git worktree list' || skill_contains 'exists' \
  && pass "Step 1 checks worktree existence" \
  || fail "Step 1 missing worktree existence check"

summarize
