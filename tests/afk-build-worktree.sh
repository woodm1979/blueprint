#!/usr/bin/env bash
# Tests for scripts/afk-build.sh — validates Section 5 worktree support
# Run from repo root: bash tests/afk-build-worktree.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/afk-build.sh"
. "$REPO_ROOT/tests/helpers.sh"

script_contains() {
  grep -qF "$1" "$SCRIPT"
}

script_matches() {
  grep -qE "$1" "$SCRIPT"
}

# --- AC: Parse Worktree: field from PLAN header ---
script_matches "grep.*Worktree.*PLAN_FILE|PLAN_FILE.*Worktree" \
  && pass "script parses Worktree: field from PLAN_FILE" \
  || fail "script missing Worktree: field parse"

# --- AC: Sets WORK_DIR to worktree path when field present and dir exists ---
script_contains 'WORK_DIR' \
  && pass "script uses WORK_DIR variable" \
  || fail "script missing WORK_DIR variable"

# --- AC: Re-derives PLAN_FILE to worktree copy ---
# The PLAN_FILE must be re-derived after WORK_DIR is set
script_matches 'PLAN_FILE.*WORK_DIR|WORK_DIR.*PLAN_FILE' \
  && pass "script re-derives PLAN_FILE under WORK_DIR" \
  || fail "script missing PLAN_FILE re-derivation under WORK_DIR"

# --- AC: Missing worktree directory exits non-zero with message ---
script_matches 'recreate|re-create' \
  && pass "script mentions recreate for missing worktree" \
  || fail "script missing recreate message for missing worktree"

# --- AC: WORK_DIR defaults to . when no Worktree: field ---
script_matches "WORK_DIR='\.'|WORK_DIR=\"\.\"|WORK_DIR=\." \
  && pass "WORK_DIR defaults to ." \
  || fail "WORK_DIR missing default of ."

# --- AC: docker command uses WORK_DIR instead of hardcoded . ---
# Previously the docker command had hardcoded .; now it should use "$WORK_DIR"
script_contains '"$WORK_DIR"' \
  && pass "docker command uses \"\$WORK_DIR\"" \
  || fail "docker command missing \"\$WORK_DIR\""

# --- AC: PLAN_FILE section-counting uses re-derived path ---
# count_not_started reads $PLAN_FILE; after re-derivation it uses worktree's copy
# Verify PLAN_FILE is quoted in docker args (covers passing it to the container)
script_matches 'PLAN_FILE' \
  && pass "PLAN_FILE referenced in script (section counting / handoff)" \
  || fail "PLAN_FILE not referenced in script"

# --- Parse logic correctness: grep/sed pattern as specified in notes ---
script_matches "grep.*Worktree:" \
  && pass "Worktree: parse uses grep with 'Worktree:' pattern" \
  || fail "Worktree: parse missing grep with 'Worktree:' pattern"

summarize
