#!/usr/bin/env bash
# Tests for scripts/worktree-remove
# Run from repo root: bash tests/worktree-remove.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/worktree-remove"
TRUST="$REPO_ROOT/scripts/worktree-trust"
. "$REPO_ROOT/tests/helpers.sh"

# Isolate the trust allowlist so tests never touch the real ~/.local/share store.
export BLUEPRINT_WORKTREE_TRUST_FILE="$(mktemp)"
trap 'rm -f "$BLUEPRINT_WORKTREE_TRUST_FILE"' EXIT


# --- Test 1: Removes existing worktree from git worktree list ---
{
  repo=$(setup_repo_with_worktree "test-remove")
  parent="$(dirname "$repo")"
  base="$(basename "$repo")"
  wt_dir="$parent/${base}-worktrees/test-remove"

  cd "$repo" && bash "$SCRIPT" "$wt_dir" >/dev/null 2>/dev/null

  if ! git -C "$repo" worktree list 2>/dev/null | grep -q "test-remove"; then
    pass "worktree no longer in git worktree list after removal"
  else
    fail "worktree no longer in git worktree list after removal"
  fi

  cleanup "$repo"
}

# --- Test 2: Worktree directory no longer exists on disk ---
{
  repo=$(setup_repo_with_worktree "test-remove-disk")
  parent="$(dirname "$repo")"
  base="$(basename "$repo")"
  wt_dir="$parent/${base}-worktrees/test-remove-disk"

  cd "$repo" && bash "$SCRIPT" "$wt_dir" >/dev/null 2>/dev/null

  if [[ ! -d "$wt_dir" ]]; then
    pass "worktree directory no longer exists on disk"
  else
    fail "worktree directory no longer exists on disk (still present: $wt_dir)"
  fi

  cleanup "$repo"
}

# --- Test 3: Non-existent path exits 0 with stderr message ---
{
  tmp=$(mktemp -d)
  git -C "$tmp" init -q
  git -C "$tmp" config user.email "test@test.com"
  git -C "$tmp" config user.name "Test"
  touch "$tmp/README.md"
  git -C "$tmp" add README.md
  git -C "$tmp" commit -q -m "init"

  nonexistent="$tmp/does-not-exist"
  stderr_out=$(cd "$tmp" && bash "$SCRIPT" "$nonexistent" 2>&1 1>/dev/null)
  exit_code=0
  (cd "$tmp" && bash "$SCRIPT" "$nonexistent" >/dev/null 2>/dev/null) || exit_code=$?

  if [[ "$exit_code" -eq 0 ]]; then
    pass "non-existent path: exits 0"
  else
    fail "non-existent path: exits 0 (got exit code $exit_code)"
  fi

  if [[ -n "$stderr_out" ]]; then
    pass "non-existent path: message to stderr"
  else
    fail "non-existent path: message to stderr (stderr was empty)"
  fi

  rm -rf "$tmp"
}

# --- Test 4: Returns branch name on stdout before removal ---
{
  repo=$(setup_repo_with_worktree "branch-output-test")
  parent="$(dirname "$repo")"
  base="$(basename "$repo")"
  wt_dir="$parent/${base}-worktrees/branch-output-test"

  stdout=$(cd "$repo" && bash "$SCRIPT" "$wt_dir" 2>/dev/null)

  if [[ "$stdout" == "branch-output-test" ]]; then
    pass "branch name returned on stdout"
  else
    fail "branch name returned on stdout (got: '$stdout', expected: 'branch-output-test')"
  fi

  cleanup "$repo"
}

# --- Test 5: Hook script does not exist ---
{
  hook_script="$REPO_ROOT/hooks/worktree-remove.sh"
  if [[ ! -e "$hook_script" ]]; then
    pass "hooks/worktree-remove.sh does not exist"
  else
    fail "hooks/worktree-remove.sh does not exist (file still present)"
  fi
}

# --- Test 6: hooks/hooks.json contains no WorktreeRemove key ---
{
  hooks_json="$REPO_ROOT/hooks/hooks.json"
  if ! grep -q "WorktreeRemove" "$hooks_json"; then
    pass "hooks/hooks.json contains no WorktreeRemove key"
  else
    fail "hooks/hooks.json contains no WorktreeRemove key (still present)"
  fi
}

# --- Test 7: Trusted .worktree/pre_delete runs before removal ---
{
  repo=$(mktemp -d)
  git -C "$repo" init -q
  git -C "$repo" config user.email "test@test.com"
  git -C "$repo" config user.name "Test"
  touch "$repo/README.md"
  mkdir -p "$repo/.worktree"
  # Hook writes evidence into REPO_ROOT, which outlives the removed worktree.
  cat > "$repo/.worktree/pre_delete" <<'EOF'
#!/usr/bin/env bash
echo "torn down" > "$REPO_ROOT/pre-delete-ran"
EOF
  chmod +x "$repo/.worktree/pre_delete"
  git -C "$repo" add README.md .worktree/pre_delete
  git -C "$repo" commit -q -m "init with pre_delete"

  parent="$(dirname "$repo")"; base="$(basename "$repo")"
  wt_dir="$parent/${base}-worktrees/pd-trusted"
  mkdir -p "$parent/${base}-worktrees"
  git -C "$repo" worktree add -q -b "pd-trusted" "$wt_dir" >/dev/null 2>&1

  bash "$TRUST" allow "$wt_dir/.worktree/pre_delete" >/dev/null 2>&1

  cd "$repo" && bash "$SCRIPT" "$wt_dir" >/dev/null 2>/dev/null

  if [[ -f "$repo/pre-delete-ran" ]]; then
    pass "trusted .worktree/pre_delete ran before removal"
  else
    fail "trusted .worktree/pre_delete ran before removal"
  fi
  if [[ ! -d "$wt_dir" ]]; then
    pass "worktree still removed after pre_delete"
  else
    fail "worktree still removed after pre_delete"
  fi

  cleanup "$repo"
}

# --- Test 8: Untrusted .worktree/pre_delete is skipped, removal proceeds ---
{
  repo=$(mktemp -d)
  git -C "$repo" init -q
  git -C "$repo" config user.email "test@test.com"
  git -C "$repo" config user.name "Test"
  touch "$repo/README.md"
  mkdir -p "$repo/.worktree"
  # Distinct content from Test 7 — trust keys on content, so identical bytes
  # would otherwise inherit Test 7's allow.
  cat > "$repo/.worktree/pre_delete" <<'EOF'
#!/usr/bin/env bash
# untrusted variant
echo "untrusted teardown" > "$REPO_ROOT/pre-delete-ran"
EOF
  chmod +x "$repo/.worktree/pre_delete"
  git -C "$repo" add README.md .worktree/pre_delete
  git -C "$repo" commit -q -m "init with untrusted pre_delete"
  # Deliberately not trusted.

  parent="$(dirname "$repo")"; base="$(basename "$repo")"
  wt_dir="$parent/${base}-worktrees/pd-untrusted"
  mkdir -p "$parent/${base}-worktrees"
  git -C "$repo" worktree add -q -b "pd-untrusted" "$wt_dir" >/dev/null 2>&1

  cd "$repo" && bash "$SCRIPT" "$wt_dir" >/dev/null 2>/dev/null

  if [[ ! -f "$repo/pre-delete-ran" ]]; then
    pass "untrusted .worktree/pre_delete is not executed"
  else
    fail "untrusted .worktree/pre_delete is not executed (it ran)"
  fi
  if [[ ! -d "$wt_dir" ]]; then
    pass "removal proceeds despite untrusted pre_delete"
  else
    fail "removal proceeds despite untrusted pre_delete"
  fi

  cleanup "$repo"
}

summarize
