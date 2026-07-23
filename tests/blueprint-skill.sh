#!/usr/bin/env bash
# Tests for skills/blueprint/SKILL.md — validates Section 3 structural requirements
# Run from repo root: bash tests/blueprint-skill.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$REPO_ROOT/skills/blueprint/SKILL.md"
. "$REPO_ROOT/tests/helpers.sh"

skill_contains() {
  grep -qF "$1" "$SKILL"
}

# AC: After /blueprint completes, the committed PLAN header contains Worktree: <abs-path>
skill_contains '> Worktree: <absolute-path-to-worktree>' \
  && pass "PLAN template contains Worktree: header line" \
  || fail "PLAN template missing Worktree: header line"

# AC: Step 6 determines/writes the Worktree: path before the Step 8 commit
skill_contains 'Determine the worktree path' \
  && pass "Step 6 determines the worktree path" \
  || fail "Step 6 worktree-path determination is missing"

skill_contains '> Executor: /build' \
  && pass "PLAN template has Executor: /build line" \
  || fail "PLAN template missing Executor: /build line"

# AC: Slug sanitization (/ → -)
skill_contains "replace every" \
  && pass "Slug sanitization instruction present" \
  || fail "Slug sanitization instruction missing"

# AC: Collision avoidance — counter suffix (snake_case: _2, _3, …)
skill_contains 'append `_2`' \
  && pass "Counter suffix collision avoidance present" \
  || fail "Counter suffix collision avoidance missing"

# AC: Worktree directory exists prompt
skill_contains 'Reuse as-is' \
  && pass "Existing worktree prompt with Reuse option present" \
  || fail "Existing worktree prompt missing"

skill_contains 'Delete and recreate' \
  && pass "Existing worktree prompt with Delete option present" \
  || fail "Existing worktree prompt Delete option missing"

# AC: Step 8.5 exists and calls EnterWorktree
skill_contains 'Step 8.5' \
  && pass "Step 8.5 is present" \
  || fail "Step 8.5 is missing"

skill_contains 'EnterWorktree name:' \
  && pass "Step 8.5 calls EnterWorktree name:" \
  || fail "Step 8.5 missing EnterWorktree name: call"

# AC: Step 10 handoff shows worktree path
skill_contains 'Worktree: `<absolute-path-to-worktree>`' \
  && pass "Step 10 handoff shows worktree path" \
  || fail "Step 10 handoff missing worktree path"

# Step ordering: the worktree path must be determined (Step 6) before the Step 8 commit
line_6=$(grep -n '### Step 6 —' "$SKILL" | head -1 | cut -d: -f1)
line_wt=$(grep -n 'Determine the worktree path' "$SKILL" | head -1 | cut -d: -f1)
line_8commit=$(grep -n '### Step 8 —' "$SKILL" | head -1 | cut -d: -f1)
if [[ -n "$line_6" && -n "$line_wt" && -n "$line_8commit" ]] && \
   [[ "$line_6" -le "$line_wt" && "$line_wt" -lt "$line_8commit" ]]; then
  pass "Worktree path is determined in Step 6, before the Step 8 commit"
else
  fail "Worktree-path ordering is wrong (6=$line_6, wt=$line_wt, 8=$line_8commit)"
fi

# Step ordering: 8.5 must appear after Step 8 and before Step 9
line_8=$(grep -n '### Step 8 —' "$SKILL" | head -1 | cut -d: -f1)
line_85=$(grep -n '### Step 8.5' "$SKILL" | head -1 | cut -d: -f1)
line_9=$(grep -n '### Step 9 —' "$SKILL" | head -1 | cut -d: -f1)
if [[ -n "$line_8" && -n "$line_85" && -n "$line_9" ]] && \
   [[ "$line_8" -lt "$line_85" && "$line_85" -lt "$line_9" ]]; then
  pass "Step 8.5 is ordered between Step 8 and Step 9"
else
  fail "Step 8.5 ordering is wrong (8=$line_8, 8.5=$line_85, 9=$line_9)"
fi

summarize
