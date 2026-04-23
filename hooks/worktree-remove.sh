#!/usr/bin/env bash
set -euo pipefail

command -v jq &>/dev/null || { echo "Error: jq is required but not installed" >&2; exit 1; }

INPUT=$(cat)
WORKTREE_PATH=$(jq -r '.path' <<< "$INPUT")

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$SCRIPT_DIR/scripts/worktree-remove" "$WORKTREE_PATH"
