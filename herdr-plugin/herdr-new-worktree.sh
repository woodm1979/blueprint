#!/usr/bin/env bash
# Create a worktree the *blueprint* way (your layout-aware path + full
# provisioning), then attach herdr to it — instead of letting herdr create it at
# its own ~/.herdr/worktrees/<repo>/<branch> location.
#
# Bind to a herdr keybinding as a `type = "pane"` command for interactive use, or
# call directly with args: herdr-new-worktree.sh [branch] [base] [repo-root]
set -euo pipefail

# herdr panes may carry a thin PATH; ensure git/jq/mise (used by post_create) resolve.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# The shared creator lives next to this script (herdr-plugin/ sibling of scripts/).
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
WT_CREATE="$SELF_DIR/../scripts/worktree-create"
[ -x "$WT_CREATE" ] || { echo "blueprint scripts/worktree-create not found at $WT_CREATE" >&2; exit 1; }

# Pause before the pane closes so output/errors are readable.
pause() { [ -t 0 ] && read -r -p "Press Enter to close…" _ || true; }
trap 'rc=$?; [ $rc -ne 0 ] && { echo "Failed (exit $rc)." >&2; pause; }; exit $rc' EXIT

BRANCH="${1:-}"
BASE="${2:-}"
REPO_ROOT="${3:-}"

# Resolve the repo from the current worktree when not passed in.
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$REPO_ROOT" ] || { echo "Not inside a git worktree; cd into one (or pass repo-root)." >&2; exit 1; }
fi

# Prompt interactively if no branch was given.
if [ -z "$BRANCH" ]; then
  read -r -p "New worktree branch name: " BRANCH
  [ -n "$BRANCH" ] || { echo "No branch name given." >&2; exit 1; }
  read -r -p "Base ref (blank = current HEAD): " BASE
fi

echo "Creating worktree '$BRANCH' in $REPO_ROOT (blueprint layout)…" >&2
WT="$(bash "$WT_CREATE" "$REPO_ROOT" "$BRANCH" "$BASE")"   # stdout = worktree path
echo "Worktree provisioned at: $WT" >&2

echo "Attaching herdr…" >&2
# herdr requires worktree actions to reference the repo's PARENT workspace, not a
# linked worktree. dirname(git-common-dir) is the container (bare layout) or the
# main repo (standard) — resolvable even when REPO_ROOT is itself a worktree.
PARENT_REPO="$(dirname "$(git -C "$REPO_ROOT" rev-parse --path-format=absolute --git-common-dir)")"
herdr worktree open --cwd "$PARENT_REPO" --path "$WT" --focus >/dev/null

echo "Done. Opened $WT" >&2
