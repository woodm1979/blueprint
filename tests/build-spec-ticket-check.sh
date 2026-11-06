#!/usr/bin/env bash
# Tests for skills/build-spec/SKILL.md: read-only ticket-set check before implementers start (ticket #30)
# Run from repo root: bash tests/build-spec-ticket-check.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$REPO_ROOT/skills/build-spec/SKILL.md"
. "$REPO_ROOT/tests/helpers.sh"

skill_contains() { grep -qF -e "$1" "$SKILL"; }

# Ticket-set check section only: from its heading to the next "## " heading.
CHECK="$(awk '/^### Check the ticket set/{f=1;next} /^## /{f=0} f' "$SKILL")"
check_contains() { grep -qF -e "$1" <<<"$CHECK"; }

skill_contains 'Check the ticket set' \
  && pass "Ticket-set check section exists" || fail "Ticket-set check section missing"

check_contains 'blocking cycle' \
  && pass "Blocking cycles are checked" || fail "Blocking-cycle check missing"

check_contains 'name the cycle' \
  && pass "Report names the cycle" || fail "Cycle-naming instruction missing"

check_contains 'user story' \
  && pass "Spec user stories checked for coverage" || fail "User-story coverage check missing"

check_contains 'gap' \
  && pass "Uncovered stories reported as gaps" || fail "Gap reporting missing"

check_contains 'conflict' \
  && pass "Conflicts between tickets checked" || fail "Conflict check missing"

check_contains 'Read-only' \
  && pass "Check is read-only" || fail "Read-only constraint missing"

check_contains 'proceed without prompting' \
  && pass "Clean set proceeds without prompting" || fail "Clean-set proceed instruction missing"

# Placement: after Step 1 heading, before Step 2 (before any worktree/implementer work)
l1=$(grep -n '^## Step 1' "$SKILL" | head -1 | cut -d: -f1 || echo "")
lc=$(grep -nF 'Check the ticket set' "$SKILL" | head -1 | cut -d: -f1 || echo "")
l2=$(grep -n '^## Step 2' "$SKILL" | head -1 | cut -d: -f1 || echo "")
if [[ -n "$l1" && -n "$lc" && -n "$l2" && "$l1" -lt "$lc" && "$lc" -lt "$l2" ]]; then
  pass "Check sits inside Step 1, before Step 2"
else
  fail "Check misplaced (1=$l1, check=$lc, 2=$l2)"
fi

summarize
