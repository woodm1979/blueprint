#!/usr/bin/env bash
# Tests for skills/blueprint/SKILL.md — validates Section 3 structural requirements
# Run from repo root: bash tests/blueprint-skill.sh
set -euo pipefail

SKILL="/Users/woodnt/Code/src/github.com/woodm1979/blueprint/skills/blueprint/SKILL.md"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

skill_contains() {
  grep -qF "$1" "$SKILL"
}

# AC: After /blueprint completes, the committed PLAN header contains Worktree: <abs-path>
skill_contains '> Worktree: <absolute-path-to-worktree>' \
  && pass "PLAN template contains Worktree: header line" \
  || fail "PLAN template missing Worktree: header line"

# AC: Step 6.5 exists and writes Worktree: before the Step 8 commit
skill_contains 'Step 6.5' \
  && pass "Step 6.5 is present" \
  || fail "Step 6.5 is missing"

skill_contains '> Executor: /build' \
  && pass "PLAN template has Executor: /build line" \
  || fail "PLAN template missing Executor: /build line"

# AC: Slug sanitization (/ → -)
skill_contains "replace every" \
  && pass "Slug sanitization instruction present" \
  || fail "Slug sanitization instruction missing"

# AC: Collision avoidance — counter suffix
skill_contains 'append \`-2\`' || skill_contains "append \`-2\`" || grep -qF 'append `-2`' "$SKILL" \
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

# Step ordering: 6.5 must appear after Step 6 and before Step 7
line_6=$(grep -n '### Step 6 —' "$SKILL" | head -1 | cut -d: -f1)
line_65=$(grep -n '### Step 6.5' "$SKILL" | head -1 | cut -d: -f1)
line_7=$(grep -n '### Step 7 —' "$SKILL" | head -1 | cut -d: -f1)
if [[ -n "$line_6" && -n "$line_65" && -n "$line_7" ]] && \
   [[ "$line_6" -lt "$line_65" && "$line_65" -lt "$line_7" ]]; then
  pass "Step 6.5 is ordered between Step 6 and Step 7"
else
  fail "Step 6.5 ordering is wrong (6=$line_6, 6.5=$line_65, 7=$line_7)"
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

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
