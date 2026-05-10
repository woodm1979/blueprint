#!/usr/bin/env bash
# Tests for skills/brainstorm/SKILL.md — validates Section 1 structural requirements
# Run from repo root: bash tests/brainstorm-skill.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$REPO_ROOT/skills/brainstorm/SKILL.md"
. "$REPO_ROOT/tests/helpers.sh"

# AC1/AC2: Problem-first sequencing — recommended answer deferred until problem questions exhausted
grep -qF 'problem questions' "$SKILL" \
  && pass "SKILL.md references problem questions sequencing" \
  || fail "SKILL.md missing problem questions sequencing"

# AC2: Recommended answer is still present (deferred, not removed)
grep -qF 'recommended answer' "$SKILL" \
  && pass "SKILL.md still includes recommended answer instruction" \
  || fail "SKILL.md missing recommended answer instruction (should be deferred, not removed)"

# AC3: Red flag list includes premature solution proposal check
grep -qF 'solution proposed before problem' "$SKILL" \
  && pass "Red flag list includes premature solution proposal check" \
  || fail "Red flag list missing premature solution proposal check"

# AC1: The sequencing rule is in the grill-me loop (Step 1 section)
awk '/### Step 1/,/### Step 2/' "$SKILL" | grep -qF 'problem' \
  && pass "Sequencing rule appears in Step 1 grill-me loop" \
  || fail "Sequencing rule not found in Step 1 grill-me loop"

summarize
