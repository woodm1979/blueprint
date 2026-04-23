#!/usr/bin/env bash
set -euo pipefail

command -v jq &>/dev/null || { echo "Error: jq is required but not installed" >&2; exit 1; }

INPUT=$(cat)
read -r CWD NAME < <(jq -r '[.cwd, .name] | @tsv' <<< "$INPUT")

REPO_ROOT=$(git -C "$CWD" rev-parse --show-toplevel)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$SCRIPT_DIR/scripts/worktree-create" "$NAME"
