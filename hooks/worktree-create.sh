#!/usr/bin/env bash
set -euo pipefail

command -v jq &>/dev/null || { echo "Error: jq is required but not installed" >&2; exit 1; }

INPUT=$(cat)
CWD=$(jq -r '.cwd' <<< "$INPUT")
NAME=$(jq -r '.name' <<< "$INPUT")

# jq -r emits the string "null" for JSON null
if [[ -z "$NAME" || "$NAME" == "null" ]]; then
  echo "Error: worktree name is missing or null" >&2
  exit 1
fi

# Happy path: cwd is a standard repo or already inside a worktree.
if ! REPO_ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null); then
  # cwd resolved to a bare repo (bare-container layout) — --show-toplevel is fatal there.
  # Operate from an existing checked-out worktree: worktree-create reads REPO_ROOT's
  # files to provision and bases the new branch off REPO_ROOT's HEAD. Prefer the
  # default-branch checkout so new worktrees branch off it (e.g. main).
  COMMON_DIR=$(git -C "$CWD" rev-parse --path-format=absolute --git-common-dir)
  DEFAULT_BRANCH=$(git -C "$COMMON_DIR" symbolic-ref --short HEAD 2>/dev/null || true)
  REPO_ROOT=$(git -C "$COMMON_DIR" worktree list --porcelain | awk \
    -v want="refs/heads/$DEFAULT_BRANCH" '
      /^worktree /{wt=substr($0,10)}
      /^bare$/{wt=""}
      /^branch /{ if(wt!="" && first=="") first=wt; if($2==want){print wt; found=1; exit} }
      END{ if(!found && first!="") print first }')
  if [[ -z "$REPO_ROOT" ]]; then
    echo "Error: bare repo has no checked-out worktree to operate from" >&2
    exit 1
  fi
fi
PLUGIN_ROOT="$(dirname "$0")/.."
exec "$PLUGIN_ROOT/scripts/worktree-create" "$REPO_ROOT" "$NAME"
