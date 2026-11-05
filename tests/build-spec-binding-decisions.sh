#!/usr/bin/env bash
# Tests for skills/build-spec/SKILL.md: per-slice reviewers check binding decisions (ticket #31)
# Run from repo root: bash tests/build-spec-binding-decisions.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$REPO_ROOT/skills/build-spec/SKILL.md"
. "$REPO_ROOT/tests/helpers.sh"

prompt() { awk -v s="---$1 REVIEWER PROMPT START---" -v e="---$1 REVIEWER PROMPT END---" \
  '$0==s{f=1;next} $0==e{f=0} f' "$SKILL"; }

for who in SPEC QUALITY; do
  p=$(prompt "$who")
  [[ -n "$p" ]] || { fail "$who reviewer prompt not found"; continue; }

  # AC1: found through the domain doc, not a hard-coded path
  if grep -qF 'docs/agents/domain.md' <<<"$p" && grep -qF 'binding decisions' <<<"$p" \
     && grep -qF 'use no other location' <<<"$p" \
     && ! grep -qF 'docs/adr' <<<"$p" && ! grep -qF 'CONTRIBUTING' <<<"$p"; then
    pass "$who reviewer finds binding decisions through docs/agents/domain.md, no hard-coded location"
  else
    fail "$who reviewer must find binding decisions through docs/agents/domain.md only"
  fi

  # AC2: contradiction is a blocking finding citing the decision
  if grep -qF 'contradicts a binding decision' <<<"$p" && grep -qF 'is a blocking finding that cites the decision' <<<"$p" \
     && { [[ $who == SPEC ]] || grep -qF 'contradictions of a binding decision (below) are blocking' <<<"$p"; }; then
    pass "$who reviewer raises a blocking finding citing a contradicted binding decision"
  else
    fail "$who reviewer must raise a blocking finding citing a contradicted binding decision"
  fi

  # AC3: descriptive records do not block
  if grep -qF 'is not a finding, even if the change goes against it' <<<"$p" \
     && grep -qF 'a decision recorded in another ticket or spec, or an MR' <<<"$p"; then
    pass "$who reviewer does not raise descriptive records (ticket, MR Deliberate)"
  else
    fail "$who reviewer must say descriptive records are not a finding"
  fi
done

summarize
