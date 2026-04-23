#!/usr/bin/env bash
# Tests for skills/cleanup-worktree/SKILL.md — validates Section 6 structural requirements
# Run from repo root: bash tests/cleanup-worktree-skill.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$REPO_ROOT/skills/cleanup-worktree/SKILL.md"
. "$REPO_ROOT/tests/helpers.sh"

skill_contains() {
  grep -qF "$1" "$SKILL"
}

skill_matches() {
  grep -qE "$1" "$SKILL"
}

# AC: Running /cleanup-worktree with uncommitted changes blocks and reports dirty files
skill_contains 'git status --porcelain' \
  && pass "Skill checks for uncommitted changes via git status --porcelain" \
  || fail "Skill missing uncommitted-changes check (git status --porcelain)"

skill_contains 'uncommitted' || skill_contains 'dirty' \
  && pass "Skill reports uncommitted changes" \
  || fail "Skill missing uncommitted changes report language"

# AC: Running with unpushed commits prints commit count and exits without removing
skill_matches 'git log.*@{u}' || skill_contains 'git log @{u}..HEAD' \
  && pass "Skill checks for unpushed commits via git log @{u}..HEAD" \
  || fail "Skill missing unpushed-commits check (git log @{u}..HEAD)"

skill_contains 'unpushed' \
  && pass "Skill reports unpushed commits" \
  || fail "Skill missing unpushed commits report language"

# AC: Unmerged branch: warns and requires explicit confirmation before proceeding
skill_contains 'git branch --merged' \
  && pass "Skill checks if branch is merged via git branch --merged" \
  || fail "Skill missing unmerged branch check (git branch --merged)"

skill_contains 'confirmation' || skill_contains 'confirm' \
  && pass "Skill requires confirmation for unmerged branch" \
  || fail "Skill missing confirmation requirement for unmerged branch"

# AC: After successful run, WorktreeRemove is triggered (or scripts/worktree-remove fallback)
skill_contains 'WorktreeRemove' || skill_contains 'worktree-remove' \
  && pass "Skill triggers WorktreeRemove or scripts/worktree-remove" \
  || fail "Skill missing WorktreeRemove / worktree-remove trigger"

# AC: Running against a PLAN with no Worktree: field exits with clear error
skill_contains 'Worktree:' \
  && pass "Skill handles missing Worktree: field" \
  || fail "Skill missing Worktree: field handling"

# AC: Running against a PLAN whose Worktree: path does not exist on disk exits cleanly
skill_contains 'does not exist' || skill_contains 'not exist' || skill_contains 'missing' \
  && pass "Skill handles missing worktree directory gracefully" \
  || fail "Skill missing handling for non-existent worktree path"

# AC: Default branch detection
skill_contains 'git symbolic-ref refs/remotes/origin/HEAD' \
  && pass "Skill determines default branch via git symbolic-ref" \
  || fail "Skill missing default branch detection"

skill_contains 'main' \
  && pass "Skill falls back to 'main' as default branch" \
  || fail "Skill missing 'main' fallback for default branch"

# AC: Sanity checks run in order: check 1 (uncommitted) before check 2 (unpushed) before check 3 (unmerged)
# Identify by section headers: "Sanity check 1", "Sanity check 2", "Sanity check 3"
line_check1=$(grep -n 'Sanity check 1' "$SKILL" | head -1 | cut -d: -f1)
line_check2=$(grep -n 'Sanity check 2' "$SKILL" | head -1 | cut -d: -f1)
line_check3=$(grep -n 'Sanity check 3' "$SKILL" | head -1 | cut -d: -f1)
if [[ -n "$line_check1" && -n "$line_check2" && -n "$line_check3" ]] && \
   [[ "$line_check1" -lt "$line_check2" && "$line_check2" -lt "$line_check3" ]]; then
  pass "Sanity checks are ordered: uncommitted → unpushed → unmerged"
else
  fail "Sanity checks ordering wrong (check1=$line_check1, check2=$line_check2, check3=$line_check3)"
fi

summarize
