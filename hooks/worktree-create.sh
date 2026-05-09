#!/usr/bin/env bash
set -euo pipefail

command -v jq &>/dev/null || { echo "Error: jq is required but not installed" >&2; exit 1; }

INPUT=$(cat)
CWD=$(jq -r '.cwd' <<< "$INPUT")
NAME=$(jq -r '.name' <<< "$INPUT")

if [[ -z "$NAME" || "$NAME" == "null" ]]; then
  echo "Error: worktree name is missing or null" >&2
  exit 1
fi

REPO_ROOT=$(git -C "$CWD" rev-parse --show-toplevel)
PLUGIN_ROOT="$(dirname "$0")/.."
exec "$PLUGIN_ROOT/scripts/worktree-create" "$REPO_ROOT" "$NAME"
