#!/usr/bin/env bash
# Tests for skills/build-step/SKILL.md — validates DDR build-time appends (Section 2)
# Run from repo root: bash tests/ddr-build-step.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$REPO_ROOT/skills/build-step/SKILL.md"
. "$REPO_ROOT/tests/helpers.sh"

skill_contains() {
  grep -qF -e "$1" "$SKILL"
}

# --- AC1: append a new DDR entry for a genuine mid-build fork ----------------

skill_contains 'non-obvious forks' \
  && pass "Same non-obvious-forks-only threshold applied at build time" \
  || fail "Non-obvious-forks-only threshold missing from build-step"

skill_contains 'supersede' \
  && pass "Supersession is a trigger for a new entry" \
  || fail "Supersession trigger missing"

skill_contains 'superseded by DDR-' \
  && pass "Supersession flips the prior entry Status to 'superseded by DDR-N'" \
  || fail "Status supersession flip missing"

# Routine deviations must be steered to the completion log, NOT the DDR.
skill_contains 'routine deviations' \
  && pass "Routine deviations named as a non-fork" \
  || fail "Routine deviations distinction missing"

skill_contains 'never graduate to the DDR' \
  && pass "Routine deviations routed to the completion log, kept out of the DDR" \
  || fail "Completion-log routing for routine deviations missing"

# --- AC2: fill Touches: with the files/functions the section produced -------

skill_contains '**Touches:**' \
  && pass "Touches field referenced in build-step" \
  || fail "Touches field missing from build-step"

skill_contains '**Touches:** —' \
  && pass "Build-step replaces the seeded '—' placeholder in Touches" \
  || fail "Touches placeholder-fill instruction missing"

skill_contains 'files/functions' \
  && pass "Touches filled with the files/functions the section produced" \
  || fail "Touches fill does not mention files/functions"

# --- AC3: Refs: DDR-N line in the section commit ----------------------------

skill_contains 'Refs: DDR-' \
  && pass "Section commit carries a 'Refs: DDR-N' line" \
  || fail "Refs: DDR-N commit line missing"

skill_contains 'DDR file is absent' \
  && pass "Refs line is omitted when the DDR is absent or no entries were touched" \
  || fail "Refs-line omission rule missing"

# --- AC4: append is done by the foreground controller, not the implementer --

skill_contains 'foreground controller' \
  && pass "Append attributed to the /build-step foreground controller" \
  || fail "Controller attribution missing"

grep -qiE 'not the implementer|never the implementer' "$SKILL" \
  && pass "Explicitly not the implementer subagent" \
  || fail "Explicit 'not the implementer' exclusion missing"

# --- DDR path derived from the PLAN path -------------------------------------

skill_contains '-DDR.md' \
  && pass "DDR filename referenced" \
  || fail "DDR filename missing"

skill_contains '-PLAN.md' \
  && pass "DDR path derived from the PLAN path (-PLAN.md -> -DDR.md)" \
  || fail "PLAN->DDR path derivation missing"

# --- Placement: the DDR append + Refs line live in Step 4, before Step 5 ----

line_4=$(grep -n '## Step 4 —' "$SKILL" | head -1 | cut -d: -f1 || echo "")
line_5=$(grep -n '## Step 5 —' "$SKILL" | head -1 | cut -d: -f1 || echo "")
line_touches=$(grep -nF -- '**Touches:**' "$SKILL" | head -1 | cut -d: -f1 || echo "")
line_refs=$(grep -nF -- 'Refs: DDR-' "$SKILL" | head -1 | cut -d: -f1 || echo "")
if [[ -n "$line_4" && -n "$line_5" && -n "$line_touches" && -n "$line_refs" ]] && \
   [[ "$line_4" -lt "$line_touches" && "$line_touches" -lt "$line_5" ]] && \
   [[ "$line_4" -lt "$line_refs" && "$line_refs" -lt "$line_5" ]]; then
  pass "DDR append + Refs line sit inside Step 4, before Step 5"
else
  fail "DDR append/Refs misplaced (4=$line_4, touches=$line_touches, refs=$line_refs, 5=$line_5)"
fi

summarize
