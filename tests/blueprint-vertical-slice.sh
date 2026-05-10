#!/usr/bin/env bash
# Tests for skills/blueprint/SKILL.md — validates Section 2 vertical-slice constraint
# Run from repo root: bash tests/blueprint-vertical-slice.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$REPO_ROOT/skills/blueprint/SKILL.md"
. "$REPO_ROOT/tests/helpers.sh"

# AC1: Step 5 defines vertical slice as thin, demoable, end-to-end through all touched layers
awk '/### Step 5/,/### Step 6/' "$SKILL" | grep -qF 'thin' \
  && pass "Step 5 includes 'thin' in vertical-slice definition" \
  || fail "Step 5 missing 'thin' in vertical-slice definition"

awk '/### Step 5/,/### Step 6/' "$SKILL" | grep -qF 'demoable' \
  && pass "Step 5 includes 'demoable' in vertical-slice definition" \
  || fail "Step 5 missing 'demoable' in vertical-slice definition"

awk '/### Step 5/,/### Step 6/' "$SKILL" | grep -qF 'end-to-end' \
  && pass "Step 5 includes 'end-to-end' in vertical-slice definition" \
  || fail "Step 5 missing 'end-to-end' in vertical-slice definition"

# AC2: Step 5 explicitly names horizontal slices as disallowed with an example
awk '/### Step 5/,/### Step 6/' "$SKILL" | grep -qiE 'disallowed|not allowed|forbidden' \
  && pass "Step 5 explicitly disallows horizontal slices" \
  || fail "Step 5 does not explicitly disallow horizontal slices"

awk '/### Step 5/,/### Step 6/' "$SKILL" | grep -qF 'Phase 1' \
  && pass "Step 5 includes horizontal-slice example (Phase 1 = all schema)" \
  || fail "Step 5 missing horizontal-slice example (Phase 1 = all schema)"

# AC3: Step 7 item 4 includes pass/fail test for demoability without depending on subsequent section
awk '/### Step 7/,/### Step 8/' "$SKILL" | grep -qF 'without depending on a subsequent section' \
  && pass "Step 7 item 4 includes 'without depending on a subsequent section' pass/fail test" \
  || fail "Step 7 item 4 missing 'without depending on a subsequent section' pass/fail test"

# AC4: Red flags list names horizontal slices as a stop condition
awk '/## Red flags/,/## When NOT/' "$SKILL" | grep -qF 'Horizontal slices' \
  && pass "Red flags list names horizontal slices as stop condition" \
  || fail "Red flags list missing horizontal slices as stop condition"

summarize
