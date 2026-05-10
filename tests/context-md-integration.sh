#!/usr/bin/env bash
# Tests for Section 3: CONTEXT.md integration
# Validates changes to both brainstorm/SKILL.md and blueprint/SKILL.md
# Run from repo root: bash tests/context-md-integration.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRAINSTORM="$REPO_ROOT/skills/brainstorm/SKILL.md"
BLUEPRINT="$REPO_ROOT/skills/blueprint/SKILL.md"
. "$REPO_ROOT/tests/helpers.sh"

# AC1: /brainstorm SKILL.md includes a pre-interview step that reads CONTEXT.md if present
grep -qF 'CONTEXT.md' "$BRAINSTORM" \
  && pass "brainstorm SKILL.md references CONTEXT.md" \
  || fail "brainstorm SKILL.md missing CONTEXT.md reference"

# AC1: The pre-interview step comes before Step 1
awk 'NR==1,/### Step 1/' "$BRAINSTORM" | grep -qF 'CONTEXT.md' \
  && pass "brainstorm CONTEXT.md step appears before Step 1" \
  || fail "brainstorm CONTEXT.md step not found before Step 1"

# AC1: If absent, step is skipped silently — instruction says "if present" or "if exists"
grep -qiE 'CONTEXT\.md.*(if (it )?exists|if present|when present)' "$BRAINSTORM" \
  && pass "brainstorm SKILL.md notes CONTEXT.md step is skipped when absent" \
  || fail "brainstorm SKILL.md missing note that step is skipped when CONTEXT.md absent"

# AC2: The pre-interview step instructs Claude to use glossary to challenge fuzzy terms (not recite)
grep -qiE 'challenge|challenge fuzzy|fuzzy term' "$BRAINSTORM" \
  && pass "brainstorm SKILL.md instructs challenging fuzzy terms from glossary" \
  || fail "brainstorm SKILL.md missing instruction to challenge fuzzy terms"

# AC2: Not reciting the glossary to the user
grep -qiE 'not (to )?recite|do not recite' "$BRAINSTORM" \
  && pass "brainstorm SKILL.md explicitly says not to recite glossary to user" \
  || fail "brainstorm SKILL.md missing 'not to recite' instruction"

# AC3: /blueprint Step 10 includes AskUserQuestion offering to update/create CONTEXT.md
awk '/### Step 10/,/## File formats/' "$BLUEPRINT" | grep -qF 'CONTEXT.md' \
  && pass "blueprint Step 10 references CONTEXT.md" \
  || fail "blueprint Step 10 missing CONTEXT.md reference"

# AC4: The offer is non-blocking — if declined, handoff proceeds normally
awk '/### Step 10/,/## File formats/' "$BLUEPRINT" | grep -qiE 'declin|skip|proceed|non-blocking' \
  && pass "blueprint Step 10 CONTEXT.md offer is non-blocking" \
  || fail "blueprint Step 10 CONTEXT.md offer not marked as non-blocking"

# AC5: Both SKILL.md files note CONTEXT.md lives at repo root
grep -qiE 'repo root|at the root' "$BRAINSTORM" \
  && pass "brainstorm SKILL.md notes CONTEXT.md lives at repo root" \
  || fail "brainstorm SKILL.md missing note that CONTEXT.md lives at repo root"

grep -qiE 'repo root|at the root' "$BLUEPRINT" \
  && pass "blueprint SKILL.md notes CONTEXT.md lives at repo root" \
  || fail "blueprint SKILL.md missing note that CONTEXT.md lives at repo root"

summarize
