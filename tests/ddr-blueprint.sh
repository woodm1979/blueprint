#!/usr/bin/env bash
# Tests for skills/blueprint/SKILL.md — validates DDR seeding (Section 1)
# Run from repo root: bash tests/ddr-blueprint.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$REPO_ROOT/skills/blueprint/SKILL.md"
. "$REPO_ROOT/tests/helpers.sh"

skill_contains() {
  grep -qF "$1" "$SKILL"
}

# --- AC1: DDR template exposes every schema field ---------------------------

skill_contains '### DDR template' \
  && pass "DDR file template section present" \
  || fail "DDR file template section missing"

skill_contains '### DDR-N: <title>' \
  && pass "DDR entry heading pattern present" \
  || fail "DDR entry heading pattern missing"

for field in '**Decision:**' '**Tension:**' '**Rejected:**' '**If-flipped:**' '**Touches:**' '**Status:**'; do
  skill_contains "$field" \
    && pass "DDR schema field $field present" \
    || fail "DDR schema field $field missing"
done

skill_contains 'superseded by DDR-' \
  && pass "Status supports supersession (superseded by DDR-M)" \
  || fail "Status supersession missing"

skill_contains 'contention indicator' \
  && pass "Contention indicator documented" \
  || fail "Contention indicator missing"

skill_contains 'door-type' \
  && pass "Door-type tag documented" \
  || fail "Door-type tag missing"

skill_contains 'one-way' && skill_contains 'two-way' \
  && pass "Both door-type values (one-way / two-way) present" \
  || fail "Door-type values missing"

skill_contains 'tension-type' \
  && pass "Tension-type tag documented" \
  || fail "Tension-type tag missing"

# --- AC2: seeding step, DDR path, committed with PRD+PLAN -------------------

skill_contains 'docs/ai-plans/<date>-<slug>-DDR.md' \
  && pass "DDR file path documented" \
  || fail "DDR file path missing"

skill_contains 'Seed the DDR' \
  && pass "Seeding step present" \
  || fail "Seeding step missing"

skill_contains 'brainstorm transcript' \
  && pass "Seeding step mines the brainstorm transcript" \
  || fail "Seeding step does not reference the brainstorm transcript"

skill_contains '(PRD + PLAN + DDR)' \
  && pass "Step 8 commit message includes DDR" \
  || fail "Step 8 commit message does not include DDR"

# --- AC3: threshold + four S/N gates ---------------------------------------

skill_contains 'non-obvious forks' \
  && pass "Non-obvious-forks-only threshold stated" \
  || fail "Non-obvious-forks-only threshold missing"

skill_contains 'Invisible-in-diff' \
  && pass "Gate 1 (invisible-in-diff) present" \
  || fail "Gate 1 (invisible-in-diff) missing"

skill_contains 'Required, falsifiable' \
  && pass "Gate 2 (required, falsifiable If-flipped) present" \
  || fail "Gate 2 (required, falsifiable If-flipped) missing"

skill_contains 'No generic tension-language' \
  && pass "Gate 3 (no generic tension-language) present" \
  || fail "Gate 3 (no generic tension-language) missing"

skill_contains 'Progressive disclosure' \
  && pass "Gate 4 (progressive disclosure) present" \
  || fail "Gate 4 (progressive disclosure) missing"

# --- AC4: Step 7 adversarial-prune item ------------------------------------

skill_contains 'adversarial prune' \
  && pass "Step 7 adversarial-prune item present" \
  || fail "Step 7 adversarial-prune item missing"

# --- AC5: PLAN template documents (see DDR-N) backlink ----------------------

skill_contains '(see DDR-N)' \
  && pass "PLAN template documents (see DDR-N) backlink convention" \
  || fail "PLAN template backlink convention missing"

# --- Step ordering: Seed the DDR after Step 6, before Step 7 & Step 8 -------

line_6=$(grep -n '### Step 6 —' "$SKILL" | head -1 | cut -d: -f1)
line_seed=$(grep -n 'Seed the DDR' "$SKILL" | head -1 | cut -d: -f1)
line_7=$(grep -n '### Step 7 —' "$SKILL" | head -1 | cut -d: -f1)
line_8=$(grep -n '### Step 8 —' "$SKILL" | head -1 | cut -d: -f1)
if [[ -n "$line_6" && -n "$line_seed" && -n "$line_7" && -n "$line_8" ]] && \
   [[ "$line_6" -lt "$line_seed" && "$line_seed" -lt "$line_7" && "$line_7" -lt "$line_8" ]]; then
  pass "DDR seed step ordered after Step 6, before Step 7 and Step 8"
else
  fail "DDR seed step ordering wrong (6=$line_6, seed=$line_seed, 7=$line_7, 8=$line_8)"
fi

# The adversarial-prune item must live inside the Step 7 self-review block.
line_prune=$(grep -n 'adversarial prune' "$SKILL" | head -1 | cut -d: -f1)
if [[ -n "$line_prune" && -n "$line_7" && -n "$line_8" ]] && \
   [[ "$line_7" -lt "$line_prune" && "$line_prune" -lt "$line_8" ]]; then
  pass "Adversarial-prune item sits inside the Step 7 self-review block"
else
  fail "Adversarial-prune item not inside Step 7 (7=$line_7, prune=$line_prune, 8=$line_8)"
fi

summarize
