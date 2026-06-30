#!/usr/bin/env bash
# herdr `worktree.created` event hook.
#
# herdr does its own `git worktree add`, then fires this event. We provision the
# resulting worktree through the EXACT same script the Claude WorktreeCreate hook
# uses — scripts/worktree-create — in provision-only mode (the existing-worktree
# arg makes it skip creation). One code path; a repo's .worktree/post_create is
# the single source of truth either way.
set -euo pipefail

# herdr may spawn us with a thin PATH; ensure jq/git/mise (used by post_create) resolve.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# The plugin ships inside the blueprint repo, so scripts/ is the sibling of the
# plugin dir herdr hands us in $HERDR_PLUGIN_ROOT.
WT_CREATE="$HERDR_PLUGIN_ROOT/../scripts/worktree-create"
[ -x "$WT_CREATE" ] || { echo "blueprint scripts/worktree-create not found at $WT_CREATE" >&2; exit 1; }

json="${HERDR_PLUGIN_EVENT_JSON:-}"
[ -n "$json" ] || { echo "no HERDR_PLUGIN_EVENT_JSON" >&2; exit 1; }

WT="$(printf '%s' "$json"     | jq -r '.data.worktree.path // empty')"
BRANCH="$(printf '%s' "$json" | jq -r '.data.worktree.branch // empty')"
SRC="$(printf '%s' "$json"    | jq -r '.data.workspace.worktree.repo_root // empty')"
[ -n "$WT" ] || { echo "event carried no worktree path" >&2; exit 1; }

# Pick a repo-root that carries the committed worktree config. The source repo
# root works for standard layouts; for a bare container (no checkout at its root)
# the committed .worktreeinclude/.worktree live in the new worktree itself.
if [ -n "$SRC" ] && { [ -f "$SRC/.worktreeinclude" ] || [ -d "$SRC/.worktree" ]; }; then
  REPO_ROOT="$SRC"
else
  REPO_ROOT="$WT"
fi

# Provision in place. ON_FAIL=keep: herdr owns this worktree, never delete it.
if ! WT_PROVISION_ON_FAIL=keep bash "$WT_CREATE" "$REPO_ROOT" "$BRANCH" "" "$WT" >&2; then
  "${HERDR_BIN_PATH:-herdr}" notification show "Worktree provisioning failed" \
    --body "$WT — run scripts/worktree-create by hand to see why" --sound request 2>/dev/null || true
  exit 1
fi
