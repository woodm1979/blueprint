#!/usr/bin/env bash
# Tests for scripts/worktree-create
# Run from repo root: bash tests/worktree-create.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/worktree-create"
TRUST="$REPO_ROOT/scripts/worktree-trust"
. "$REPO_ROOT/tests/helpers.sh"

# Isolate the trust allowlist so tests never touch the real ~/.local/share store.
export BLUEPRINT_WORKTREE_TRUST_FILE="$(mktemp)"
trap 'rm -f "$BLUEPRINT_WORKTREE_TRUST_FILE"' EXIT

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

# --- Test 3: Copies gitignored .env* files into the worktree ---
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

  if [[ -f "$wt/.env" && ! -L "$wt/.env" && "$(cat "$wt/.env")" == "secret" ]]; then
    pass ".env copied into worktree (isolated, not symlinked)"
  else
    fail ".env copied into worktree (isolated, not symlinked)"
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

# --- Test 5: Trusted .worktree/post_create owns setup, runs inside worktree ---
{
  repo=$(setup_repo)
  mkdir -p "$repo/.worktree"
  cat > "$repo/.worktree/post_create" <<'EOF'
#!/usr/bin/env bash
echo "ran in $PWD with REPO_ROOT=$REPO_ROOT" > setup-ran
EOF
  chmod +x "$repo/.worktree/post_create"
  git -C "$repo" add .worktree/post_create
  git -C "$repo" commit -q -m "add post_create override"

  # Trust it (direnv-style content-hash allow).
  bash "$TRUST" allow "$repo/.worktree/post_create" >/dev/null 2>&1

  parent="$(dirname "$repo")"
  base="$(basename "$repo")"
  wt="$parent/${base}-worktrees/postcreate-test"

  bash "$SCRIPT" "$repo" "postcreate-test" >/dev/null 2>&1

  if [[ -f "$wt/setup-ran" ]] && grep -q "REPO_ROOT=$repo" "$wt/setup-ran"; then
    pass "trusted .worktree/post_create ran inside worktree with REPO_ROOT set"
  else
    fail "trusted .worktree/post_create ran inside worktree with REPO_ROOT set"
  fi

  cleanup "$repo"
}

# --- Test 5b: Untrusted .worktree/post_create is skipped (not run) ---
{
  repo=$(setup_repo)
  mkdir -p "$repo/.worktree"
  cat > "$repo/.worktree/post_create" <<'EOF'
#!/usr/bin/env bash
echo "ran" > setup-ran
EOF
  chmod +x "$repo/.worktree/post_create"
  git -C "$repo" add .worktree/post_create
  git -C "$repo" commit -q -m "add untrusted post_create"
  # Deliberately do NOT trust it.

  parent="$(dirname "$repo")"
  base="$(basename "$repo")"
  wt="$parent/${base}-worktrees/untrusted-test"

  stderr_output=$(bash "$SCRIPT" "$repo" "untrusted-test" 2>&1 1>/dev/null)

  if [[ ! -f "$wt/setup-ran" ]]; then
    pass "untrusted .worktree/post_create is not executed"
  else
    fail "untrusted .worktree/post_create is not executed (it ran)"
  fi

  if grep -q "untrusted" <<< "$stderr_output"; then
    pass "untrusted post_create prints a warning to stderr"
  else
    fail "untrusted post_create prints a warning to stderr"
  fi

  cleanup "$repo"
}

# --- Test 5d: A failing trusted post_create aborts and removes the worktree ---
{
  repo=$(setup_repo)
  mkdir -p "$repo/.worktree"
  cat > "$repo/.worktree/post_create" <<'EOF'
#!/usr/bin/env bash
exit 7
EOF
  chmod +x "$repo/.worktree/post_create"
  git -C "$repo" add .worktree/post_create
  git -C "$repo" commit -q -m "add failing post_create"
  bash "$TRUST" allow "$repo/.worktree/post_create" >/dev/null 2>&1

  parent="$(dirname "$repo")"; base="$(basename "$repo")"
  wt="$parent/${base}-worktrees/fail-test"

  if bash "$SCRIPT" "$repo" "fail-test" >/dev/null 2>&1; then
    fail "failing post_create makes worktree-create exit non-zero"
  else
    pass "failing post_create makes worktree-create exit non-zero"
  fi

  if [[ ! -d "$wt" ]]; then
    pass "failing post_create triggers cleanup (worktree removed)"
  else
    fail "failing post_create triggers cleanup (worktree removed)"
  fi

  cleanup "$repo"
}

# --- Test 5c: .worktreeinclude brings files (copy default, & = symlink) ---
{
  repo=$(setup_repo)
  echo -e ".env\nshared.txt" >> "$repo/.gitignore"
  echo "secret" > "$repo/.env"
  echo "shared" > "$repo/shared.txt"
  printf '.env\n&shared.txt\n# a comment\n\n' > "$repo/.worktreeinclude"
  git -C "$repo" add .gitignore .worktreeinclude
  git -C "$repo" commit -q -m "add worktreeinclude"

  parent="$(dirname "$repo")"
  base="$(basename "$repo")"
  wt="$parent/${base}-worktrees/include-test"

  bash "$SCRIPT" "$repo" "include-test" >/dev/null 2>&1

  if [[ -f "$wt/.env" && ! -L "$wt/.env" && "$(cat "$wt/.env")" == "secret" ]]; then
    pass ".worktreeinclude copies an unmarked entry"
  else
    fail ".worktreeinclude copies an unmarked entry"
  fi

  if [[ -L "$wt/shared.txt" && "$(cat "$wt/shared.txt")" == "shared" ]]; then
    pass ".worktreeinclude symlinks an &-marked entry"
  else
    fail ".worktreeinclude symlinks an &-marked entry"
  fi

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

# --- Test 12: Bare layout — worktree lands as a slugged sibling of .bare ---
{
  src=$(setup_repo)
  container=$(mktemp -d)
  git clone -q --bare "$src" "$container/.bare"
  # Establish a primary checkout worktree inside the container.
  git -C "$container/.bare" worktree add -q "$container/main" >/dev/null 2>&1

  # REPO_ROOT is the in-container worktree (mimics how the hook resolves it).
  bash "$SCRIPT" "$container/main" "Feature-Auth" >/dev/null 2>&1

  # Slug lowercases and maps non-[a-z0-9_] to _: "Feature-Auth" -> "feature_auth".
  expected_wt="$container/feature_auth"
  if [[ -d "$expected_wt" ]] && git -C "$container/.bare" worktree list | grep -q "$expected_wt"; then
    pass "bare layout: worktree created at <container>/<slug>"
  else
    fail "bare layout: worktree created at <container>/<slug> (expected $expected_wt)"
  fi

  # The branch name itself is preserved (not slugged).
  if git -C "$expected_wt" symbolic-ref --short HEAD 2>/dev/null | grep -qx "Feature-Auth"; then
    pass "bare layout: branch name preserved (only dir is slugged)"
  else
    fail "bare layout: branch name preserved (only dir is slugged)"
  fi

  rm -rf "$src" "$container"
}

# --- Test 13: README documents the new conventions, not the stale override ---
{
  readme="$REPO_ROOT/README.md"
  if grep -q '\.worktree/post_create' "$readme" && grep -q '\.worktreeinclude' "$readme"; then
    pass "README documents .worktree/post_create and .worktreeinclude"
  else
    fail "README documents .worktree/post_create and .worktreeinclude"
  fi
  # The code no longer consults the stale name; the README must not present it
  # as the active override (a Note explaining the rename is allowed).
  if grep -qE '`?\.worktree-setup`? exists|runs `\.claude/worktree-setup\.sh`' "$readme"; then
    fail "README still presents the stale .worktree-setup override as active"
  else
    pass "README does not present the stale override as active"
  fi
  # Code drift: scripts/worktree-create must reference the new hook name only.
  if grep -q 'worktree-setup' "$SCRIPT"; then
    fail "scripts/worktree-create still references .worktree-setup"
  else
    pass "scripts/worktree-create references only .worktree/post_create"
  fi
}

summarize
