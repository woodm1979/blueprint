#!/usr/bin/env bash
# Tests for skills/build-spec/SKILL.md Step 5: end-of-branch zoom-out pass (ticket #29)
# Run from repo root: bash tests/build-spec-end-review.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$REPO_ROOT/skills/build-spec/SKILL.md"
. "$REPO_ROOT/tests/helpers.sh"

# Step 5 body only: from its heading to the next "## " heading.
STEP5="$(awk '/^## Step 5:/{f=1;next} /^## /{f=0} f' "$SKILL")"
step5_contains() { grep -qF -e "$1" <<<"$STEP5"; }

step5_contains '/fit-review' \
  && pass "Runs the repo's /fit-review when it has one" \
  || fail "/fit-review not named in Step 5"

step5_contains 'built-in zoom-out' \
  && pass "Falls back to a built-in zoom-out review without /fit-review" \
  || fail "Built-in zoom-out fallback missing"

step5_contains 'ZOOM-OUT REVIEWER PROMPT START' \
  && pass "Built-in zoom-out reviewer has a prompt" \
  || fail "Zoom-out reviewer prompt missing"

step5_contains 'mattpocock-skills:code-review' \
  && pass "Bug review runs over the full branch" \
  || fail "Bug review missing from Step 5"

step5_contains 'merge-base' \
  && pass "Review range is the full integration branch (from merge-base)" \
  || fail "Full-branch review range missing"

step5_contains 'found-defect rule' \
  && pass "Pre-existing problems go through the found-defect rule" \
  || fail "Found-defect routing missing"

step5_contains "branch's own" \
  && pass "Fit fixes limited to the branch's own code" \
  || fail "Own-code scoping missing"

step5_contains 'single implementer' \
  && pass "One implementer fixes the fit problems" \
  || fail "Single-implementer fix missing"

# Step 5's fixer: obvious pre-existing fixes made by the same implementer, and the phase A prompt is adapted
step5_contains 'also makes the obvious pre-existing fixes, each in its own commit' \
  && pass "Step 5 implementer makes obvious pre-existing fixes, each in its own commit" \
  || fail "Step 5 must name who makes the obvious pre-existing fixes"

step5_contains 'fix branch' \
  && pass "Step 5 says how to fill the phase A prompt (fix branch off the integration tip)" \
  || fail "Step 5 must say how to fill the phase A prompt"

summarize
