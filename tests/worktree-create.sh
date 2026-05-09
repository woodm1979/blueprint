#!/usr/bin/env bash
# Tests for scripts/worktree-create
# Run from repo root: bash tests/worktree-create.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/worktree-create"
. "$REPO_ROOT/tests/helpers.sh"

# Setup: create a temp "repo" to act as our test subject
setup_repo() {
  local dir
  dir=$(mktemp -d)
  git -C "$dir" init -q
  git -C "$dir" config user.email "test@test.com"
  git -C "$dir" config user.name "Test"
  touch "$dir/README.md"
  git -C "$dir" add README.md
  git -C "$dir" commit -q -m "init"
  echo "$dir"
}

cleanup() {
  local repo_dir="$1"
  local parent
  parent="$(dirname "$repo_dir")"
  local basename
  basename="$(basename "$repo_dir")"
  rm -rf "$repo_dir"
  rm -rf "$parent/${basename}-worktrees"
}

# --- Test 1: Creates worktree at correct path ---
{
  repo=$(setup_repo)
  parent="$(dirname "$repo")"
  base="$(basename "$repo")"
  expected_wt="$parent/${base}-worktrees/test-feature"

  stdout=$(bash "$SCRIPT" "$repo" "test-feature" 2>/dev/null)
  # macOS: mktemp may return /var/... but git resolves to /private/var/...
  real_expected=$(cd "$expected_wt" && pwd -P 2>/dev/null || echo "$expected_wt")
  real_stdout=$(cd "$stdout" && pwd -P 2>/dev/null || echo "$stdout")

  if [[ "$real_stdout" == "$real_expected" ]]; then
    pass "worktree path printed to stdout"
  else
    fail "worktree path printed to stdout (got: $real_stdout, expected: $real_expected)"
  fi

  if git -C "$repo" worktree list | grep -q "$expected_wt"; then
    pass "git worktree list shows new worktree"
  else
    fail "git worktree list shows new worktree"
  fi

  if git -C "$repo" worktree list | grep -q "test-feature"; then
    pass "worktree is on branch test-feature"
  else
    fail "worktree is on branch test-feature"
  fi

  # Progress messages go to stderr, not stdout
  stderr_output=$(bash "$SCRIPT" "$repo" "test-feature2" 2>&1 1>/dev/null)
  if [[ -n "$stderr_output" ]]; then
    pass "progress messages go to stderr"
  else
    fail "progress messages go to stderr (stderr was empty)"
  fi

  cleanup "$repo"
}

# --- Test 2: Branch already exists — checks out, does not create new ---
{
  repo=$(setup_repo)
  parent="$(dirname "$repo")"
  base="$(basename "$repo")"
  existing_wt="$parent/${base}-worktrees/existing-branch"

  # Pre-create branch
  git -C "$repo" checkout -q -b "existing-branch"
  git -C "$repo" checkout -q main 2>/dev/null || git -C "$repo" checkout -q master 2>/dev/null

  bash "$SCRIPT" "$repo" "existing-branch" >/dev/null 2>&1

  if git -C "$repo" worktree list | grep -q "$existing_wt"; then
    pass "existing branch: worktree created successfully"
  else
    fail "existing branch: worktree created successfully"
  fi

  cleanup "$repo"
}

# --- Test 3: Symlinks gitignored .env* files ---
{
  repo=$(setup_repo)
  echo ".env" >> "$repo/.gitignore"
  echo "secret" > "$repo/.env"
  git -C "$repo" add .gitignore
  git -C "$repo" commit -q -m "add gitignore"

  parent="$(dirname "$repo")"
  base="$(basename "$repo")"
  wt="$parent/${base}-worktrees/env-test"

  bash "$SCRIPT" "$repo" "env-test" >/dev/null 2>&1

  if [[ -L "$wt/.env" ]]; then
    pass ".env symlinked into worktree"
  else
    fail ".env symlinked into worktree"
  fi

  cleanup "$repo"
}

# --- Test 4: Symlinks untracked .claude/ files ---
{
  repo=$(setup_repo)
  mkdir -p "$repo/.claude"
  echo "settings" > "$repo/.claude/settings.json"
  # .claude/ is not tracked by git

  parent="$(dirname "$repo")"
  base="$(basename "$repo")"
  wt="$parent/${base}-worktrees/claude-test"

  bash "$SCRIPT" "$repo" "claude-test" >/dev/null 2>&1

  if [[ -L "$wt/.claude/settings.json" ]]; then
    pass ".claude/settings.json symlinked into worktree"
  else
    fail ".claude/settings.json symlinked into worktree"
  fi

  cleanup "$repo"
}

# --- Test 5: Override script runs exclusively ---
{
  repo=$(setup_repo)
  mkdir -p "$repo/.claude"
  override_log=$(mktemp)
  cat > "$repo/.claude/worktree-setup.sh" <<'EOF'
#!/usr/bin/env bash
echo "override ran: WORKTREE_DIR=$WORKTREE_DIR REPO_ROOT=$REPO_ROOT" >> "$OVERRIDE_LOG"
EOF
  chmod +x "$repo/.claude/worktree-setup.sh"

  # Also put a .env to verify auto-detection does NOT symlink it
  echo ".env" >> "$repo/.gitignore"
  echo "secret" > "$repo/.env"
  git -C "$repo" add .gitignore
  git -C "$repo" commit -q -m "add gitignore"

  parent="$(dirname "$repo")"
  base="$(basename "$repo")"
  wt="$parent/${base}-worktrees/override-test"

  OVERRIDE_LOG="$override_log" bash "$SCRIPT" "$repo" "override-test" >/dev/null 2>&1

  if grep -q "override ran:" "$override_log" 2>/dev/null; then
    pass "override script ran"
  else
    fail "override script ran"
  fi

  if grep -q "WORKTREE_DIR=" "$override_log" && grep -q "REPO_ROOT=" "$override_log"; then
    pass "override script received WORKTREE_DIR and REPO_ROOT env vars"
  else
    fail "override script received WORKTREE_DIR and REPO_ROOT env vars"
  fi

  # .env should NOT be symlinked (no auto-detection)
  if [[ ! -L "$wt/.env" ]]; then
    pass "override script: no auto-detection side effects (.env not symlinked)"
  else
    fail "override script: no auto-detection side effects (.env not symlinked)"
  fi

  rm -f "$override_log"
  cleanup "$repo"
}

# --- Test 6: Hook script is executable ---
{
  hook_script="$REPO_ROOT/hooks/worktree-create.sh"
  if [[ -x "$hook_script" ]]; then
    pass "hooks/worktree-create.sh is executable"
  else
    fail "hooks/worktree-create.sh is executable (not found or not executable)"
  fi
}

# --- Test 7: hooks/hooks.json references WorktreeCreate ---
{
  hooks_json="$REPO_ROOT/hooks/hooks.json"
  if grep -q "WorktreeCreate" "$hooks_json" && grep -q "worktree-create.sh" "$hooks_json"; then
    pass "hooks/hooks.json references WorktreeCreate -> worktree-create.sh"
  else
    fail "hooks/hooks.json references WorktreeCreate -> worktree-create.sh"
  fi
}

# --- Test 8: Hook reads .cwd and .name from stdin JSON payload ---
{
  repo=$(setup_repo)
  hook_script="$REPO_ROOT/hooks/worktree-create.sh"

  # Create a minimal fake repo that has scripts/worktree-create as a spy
  # We can't override $REPO_ROOT/scripts/worktree-create (it's the real plugin),
  # so instead verify end-to-end: the hook, given a valid payload, creates a worktree.
  parent="$(dirname "$repo")"
  base="$(basename "$repo")"
  expected_wt="$parent/${base}-worktrees/my-feature"

  payload="{\"cwd\": \"$repo\", \"name\": \"my-feature\"}"
  echo "$payload" | bash "$hook_script" >/dev/null 2>&1

  if git -C "$repo" worktree list | grep -q "my-feature"; then
    pass "hook reads .name from stdin JSON payload"
  else
    fail "hook reads .name from stdin JSON payload"
  fi

  if [[ -d "$expected_wt" ]]; then
    pass "hook derives REPO_ROOT and passes it to worktree-create"
  else
    fail "hook derives REPO_ROOT and passes it to worktree-create"
  fi

  cleanup "$repo"
}

# --- Test 9: Hook exits non-zero when NAME is empty ---
{
  repo=$(setup_repo)
  hook_script="$REPO_ROOT/hooks/worktree-create.sh"
  payload="{\"cwd\": \"$repo\", \"name\": \"\"}"
  if echo "$payload" | bash "$hook_script" >/dev/null 2>&1; then
    fail "hook exits non-zero when NAME is empty"
  else
    pass "hook exits non-zero when NAME is empty"
  fi
  cleanup "$repo"
}

# --- Test 10: Hook exits non-zero when NAME is the string "null" ---
{
  repo=$(setup_repo)
  hook_script="$REPO_ROOT/hooks/worktree-create.sh"
  payload="{\"cwd\": \"$repo\", \"name\": null}"
  if echo "$payload" | bash "$hook_script" >/dev/null 2>&1; then
    fail "hook exits non-zero when NAME is JSON null (jq -r outputs string 'null')"
  else
    pass "hook exits non-zero when NAME is JSON null (jq -r outputs string 'null')"
  fi
  cleanup "$repo"
}

# --- Test 11: Hook script contains no BASH_SOURCE, cd, or pushd tricks ---
{
  hook_script="$REPO_ROOT/hooks/worktree-create.sh"
  if grep -q 'BASH_SOURCE\|pushd\|cd ' "$hook_script"; then
    fail "hook script contains no BASH_SOURCE/cd/pushd tricks"
  else
    pass "hook script contains no BASH_SOURCE/cd/pushd tricks"
  fi
}

summarize
