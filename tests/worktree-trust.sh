#!/usr/bin/env bash
# Tests for scripts/worktree-trust (content-hash allowlist)
# Run from repo root: bash tests/worktree-trust.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRUST="$REPO_ROOT/scripts/worktree-trust"
. "$REPO_ROOT/tests/helpers.sh"

export BLUEPRINT_WORKTREE_TRUST_FILE="$(mktemp)"
: > "$BLUEPRINT_WORKTREE_TRUST_FILE"
trap 'rm -f "$BLUEPRINT_WORKTREE_TRUST_FILE"' EXIT

mkfile() { local f; f=$(mktemp); printf '%s' "$1" > "$f"; echo "$f"; }

# --- Test 1: check is non-zero for an unknown file ---
{
  f=$(mkfile "echo hi")
  if bash "$TRUST" check "$f" >/dev/null 2>&1; then
    fail "check returns non-zero before allow"
  else
    pass "check returns non-zero before allow"
  fi
  rm -f "$f"
}

# --- Test 2: allow then check passes ---
{
  f=$(mkfile "echo hi")
  bash "$TRUST" allow "$f" >/dev/null 2>&1
  if bash "$TRUST" check "$f" >/dev/null 2>&1; then
    pass "check passes after allow"
  else
    fail "check passes after allow"
  fi
  rm -f "$f"
}

# --- Test 3: changing content re-locks (re-prompt on change) ---
{
  f=$(mkfile "echo hi")
  bash "$TRUST" allow "$f" >/dev/null 2>&1
  printf '%s' "echo CHANGED" > "$f"
  if bash "$TRUST" check "$f" >/dev/null 2>&1; then
    fail "check is non-zero again after content changes"
  else
    pass "check is non-zero again after content changes"
  fi
  rm -f "$f"
}

# --- Test 4: deny removes trust ---
{
  f=$(mkfile "echo hi")
  bash "$TRUST" allow "$f" >/dev/null 2>&1
  bash "$TRUST" deny "$f" >/dev/null 2>&1
  if bash "$TRUST" check "$f" >/dev/null 2>&1; then
    fail "check is non-zero after deny"
  else
    pass "check is non-zero after deny"
  fi
  rm -f "$f"
}

# --- Test 5: identical content is trusted regardless of path ---
{
  f1=$(mkfile "echo same")
  f2=$(mkfile "echo same")
  bash "$TRUST" allow "$f1" >/dev/null 2>&1
  if bash "$TRUST" check "$f2" >/dev/null 2>&1; then
    pass "trust keys on content, not path (byte-identical file is trusted)"
  else
    fail "trust keys on content, not path (byte-identical file is trusted)"
  fi
  rm -f "$f1" "$f2"
}

summarize
