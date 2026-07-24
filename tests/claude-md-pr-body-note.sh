#!/usr/bin/env bash
# Tests for Section 3: CLAUDE.md PR-body note (DDR high-contention entries lead the draft)
# Run from repo root: bash tests/claude-md-pr-body-note.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_MD="$REPO_ROOT/CLAUDE.md"
. "$REPO_ROOT/tests/helpers.sh"

# AC: CLAUDE.md instructs PR/MR body drafts to lead with the DDR's high-contention entries
grep -qiE 'PR/MR body' "$CLAUDE_MD" \
  && pass "CLAUDE.md references PR/MR body drafts" \
  || fail "CLAUDE.md missing PR/MR body reference"

grep -qi 'high-contention' "$CLAUDE_MD" \
  && pass "CLAUDE.md references DDR high-contention entries" \
  || fail "CLAUDE.md missing high-contention reference"

grep -qi 'DDR' "$CLAUDE_MD" \
  && pass "CLAUDE.md references the DDR" \
  || fail "CLAUDE.md missing DDR reference"

# AC: the note names no specific reviewer (reviewer-agnostic)
grep -qiE 'reviewer[- ]?agnostic|no (specific )?reviewer' "$CLAUDE_MD" \
  && pass "CLAUDE.md note is documented as reviewer-agnostic" \
  || fail "CLAUDE.md note missing explicit reviewer-agnostic framing"

summarize
