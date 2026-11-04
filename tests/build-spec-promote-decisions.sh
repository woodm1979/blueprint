#!/usr/bin/env bash
# Tests for skills/build-spec/SKILL.md: promoting decisions to binding (ticket #32)
# Run from repo root: bash tests/build-spec-promote-decisions.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$REPO_ROOT/skills/build-spec/SKILL.md"
. "$REPO_ROOT/tests/helpers.sh"

section() { awk -v h="$1" 'index($0,h)==1{f=1;next} /^##/{f=0} f' "$SKILL"; }
PROMOTE="$(section '### Promote decisions')"
BINDING="$(section '### Binding decisions')"
has() { grep -qF -e "$2" <<<"$1"; }

[[ -n "$PROMOTE" ]] && pass "Promotion section exists" || fail "'### Promote decisions' section missing"
[[ -n "$BINDING" ]] && pass "Binding-decisions guard section exists" || fail "'### Binding decisions' section missing"

has "$PROMOTE" 'set a pattern' \
  && pass "Proposes decisions made on purpose to set a pattern" || fail "Pattern-setting criterion missing"
has "$PROMOTE" 'offhand' \
  && pass "Offhand choices stay descriptive" || fail "Offhand exclusion missing"
has "$PROMOTE" 'asks the user' \
  && pass "Asks the user per decision" || fail "User confirmation request missing"
has "$PROMOTE" 'only after the user confirms' \
  && pass "Nothing written before confirmation" || fail "Confirm-before-write rule missing"
has "$PROMOTE" 'docs/agents/domain.md' \
  && pass "Finds the binding-decision location via domain.md" || fail "domain.md pointer missing"

has "$BINDING" 'reverse' \
  && pass "Guard covers reversing a binding decision" || fail "Reversal guard missing"
has "$BINDING" 'propose a ticket' \
  && pass "Reversal stops and proposes a ticket" || fail "Ticket proposal missing"

# Step 6 report mentions the promotion proposals; Step 5 hands off to the promote section.
STEP5="$(awk '/^## Step 5:/{f=1;next} /^## /{f=0} f' "$SKILL")"
has "$STEP5" 'Promote decisions' \
  && pass "Step 5 runs the promotion pass" || fail "Step 5 does not reference promotion pass"
