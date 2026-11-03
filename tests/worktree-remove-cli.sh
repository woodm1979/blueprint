#!/usr/bin/env bash
# Tests for scripts/worktree-remove-cli
# Run from repo root: bash tests/worktree-remove-cli.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/worktree-remove-cli"
. "$REPO_ROOT/tests/helpers.sh"


# --- Test 1: Worktree removed from git worktree list when 'n' answered ---
{
  repo=$(setup_repo_with_worktree "feature-x")

  echo n | (cd "$repo" && bash "$SCRIPT" "feature-x") >/dev/null 2>&1 || true

  if ! git -C "$repo" worktree list 2>/dev/null | grep -q "feature-x"; then
    pass "worktree removed from git worktree list"
  else
    fail "worktree removed from git worktree list (still listed)"
  fi

  cleanup "$repo"
}

# --- Test 2: Worktree directory no longer exists on disk ---
{
  repo=$(setup_repo_with_worktree "feature-y")
  parent="$(dirname "$repo")"
  base="$(basename "$repo")"
  wt_dir="$parent/${base}-worktrees/feature-y"

  echo n | (cd "$repo" && bash "$SCRIPT" "feature-y") >/dev/null 2>&1 || true

  if [[ ! -d "$wt_dir" ]]; then
    pass "worktree directory no longer exists on disk"
  else
    fail "worktree directory no longer exists on disk (still present: $wt_dir)"
  fi

  cleanup "$repo"
}

# --- Test 3: Branch kept when 'n' is answered ---
{
  repo=$(setup_repo_with_worktree "keep-branch")

  echo n | (cd "$repo" && bash "$SCRIPT" "keep-branch") >/dev/null 2>&1 || true

  if git -C "$repo" branch --list "keep-branch" | grep -q "keep-branch"; then
    pass "branch kept when 'n' answered"
  else
    fail "branch kept when 'n' answered (branch was deleted)"
  fi

  cleanup "$repo"
}

# --- Test 4: Branch deleted when 'y' is answered ---
{
  repo=$(setup_repo_with_worktree "delete-branch")

  echo y | (cd "$repo" && bash "$SCRIPT" "delete-branch") >/dev/null 2>&1 || true

  if ! git -C "$repo" branch --list "delete-branch" | grep -q "delete-branch"; then
    pass "branch deleted when 'y' answered"
  else
    fail "branch deleted when 'y' answered (branch still exists)"
  fi

  cleanup "$repo"
}

# --- Test 5: No branch question when the repo's .worktree/remove already deleted it ---
{
  export BLUEPRINT_WORKTREE_TRUST_FILE="$(mktemp)"
  repo=$(mktemp -d)
  git -C "$repo" init -q
  git -C "$repo" config user.email "test@test.com"
  git -C "$repo" config user.name "Test"
  mkdir -p "$repo/.worktree"
  cat > "$repo/.worktree/remove" <<'EOF'
#!/usr/bin/env bash
branch="$(git -C "$1" symbolic-ref --short HEAD)"
common="$(git -C "$1" rev-parse --path-format=absolute --git-common-dir)"
git --git-dir="$common" worktree remove "$1"
git --git-dir="$common" branch -D "$branch"
EOF
  chmod +x "$repo/.worktree/remove"
  git -C "$repo" add .worktree/remove
  git -C "$repo" commit -q -m "repo remove"
  parent="$(dirname "$repo")"; base="$(basename "$repo")"
  mkdir -p "$parent/${base}-worktrees"
  git -C "$repo" worktree add -q -b "repo-owned" "$parent/${base}-worktrees/repo-owned" >/dev/null 2>&1
  bash "$REPO_ROOT/scripts/worktree-trust" allow "$repo/.worktree/remove" >/dev/null 2>&1

  set +e
  output=$(echo y | (cd "$repo" && bash "$SCRIPT" "repo-owned") 2>&1)
  rc=$?
  set -e

  if [[ "$rc" -eq 0 && "$output" != *"Delete branch"* ]]; then
    pass "branch the repo's remove deleted: no question, exit 0"
  else
    fail "branch the repo's remove deleted: no question, exit 0 (rc=$rc, output: $output)"
  fi

  rm -f "$BLUEPRINT_WORKTREE_TRUST_FILE"
  cleanup "$repo"
}

summarize
