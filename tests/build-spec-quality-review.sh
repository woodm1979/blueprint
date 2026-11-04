#!/usr/bin/env bash
# Tests for skills/build-spec/SKILL.md: per-slice quality reviewer (ticket #28)
# Run from repo root: bash tests/build-spec-quality-review.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$REPO_ROOT/skills/build-spec/SKILL.md"
. "$REPO_ROOT/tests/helpers.sh"

has() { grep -qF -e "$1" "$SKILL"; }
check() { has "$1" && pass "$2" || fail "$2 (missing: $1)"; }

check 'QUALITY REVIEWER PROMPT START' "A quality reviewer prompt exists"
check 'in parallel' "Spec and quality reviewers run in parallel"
check 'high-confidence' "Blocking is limited to high-confidence findings"
check 'LOW-CONFIDENCE' "Low-confidence findings are tagged"
check 'do not block' "Low-confidence findings do not block"
check 'dead code' "Dead code counts as a bug"
check 'incorrect comments' "Incorrect comments count as bugs"
check 'lines the slice wrote' "Taste is limited to lines the slice wrote"
check 'Found along the way' "Found defects are named under 'Found along the way'"
check 'own commit' "Found defects are fixed in their own commit"
check 'receiving-code-review' "Implementer follows receiving-code-review rules"
check 'ask about unclear' "Unclear findings are asked about before fixing"

# Quality reviewer sits inside phase C, before phase D
c=$(grep -n '^### C\.' "$SKILL" | head -1 | cut -d: -f1)
q=$(grep -n 'QUALITY REVIEWER PROMPT START' "$SKILL" | head -1 | cut -d: -f1)
d=$(grep -n '^### D\.' "$SKILL" | head -1 | cut -d: -f1)
if [[ -n "$c" && -n "$q" && -n "$d" && "$c" -lt "$q" && "$q" -lt "$d" ]]; then
  pass "Quality reviewer prompt sits in phase C, before phase D"
else
  fail "Quality reviewer prompt misplaced (C=$c, Q=$q, D=$d)"
fi

summarize
