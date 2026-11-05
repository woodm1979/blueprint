#!/usr/bin/env bash
# AFK (unattended) build runner: runs build-spec on the host, one frontier
# ticket per iteration, until the spec has no open tickets.
#
# Prerequisites:
#   - `claude` and `gh` (authenticated) on PATH, and `jq`.
#   - A worktree the repo already provisioned (this script does not create one).
#
# Usage:
#   scripts/afk-build.sh SPEC_NUMBER WORKTREE_DIR
#
# The frontier is the spec's open sub-issues whose blockers are all closed.
# An iteration that closes no ticket stops the run with a non-zero exit.

set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: $0 SPEC_NUMBER WORKTREE_DIR" >&2
  exit 2
fi
SPEC="$1"
WORK_DIR="$2"

if [ ! -d "$WORK_DIR" ]; then
  echo "Error: worktree directory not found: $WORK_DIR" >&2
  echo "Provision it with the repo's own worktree script and retry." >&2
  exit 1
fi
cd "$WORK_DIR"

# --- Helpers ---

# Open sub-issues of the spec, as a JSON array.
open_tickets() {
  gh api --paginate "repos/{owner}/{repo}/issues/$SPEC/sub_issues" \
    | jq -s 'add | map(select(.state == "open"))'
}

# --- Main loop ---

while true; do
  open=$(open_tickets)
  before=$(jq 'length' <<<"$open")

  if [ "$before" -eq 0 ]; then
    echo "Build complete."
    exit 0
  fi

  next=$(jq -r '[.[] | select((.issue_dependencies_summary.blocked_by // 0) == 0)] | .[0].number // empty' <<<"$open")
  if [ -z "$next" ]; then
    echo "Build blocked: $before open ticket(s), none unblocked." >&2
    exit 1
  fi

  echo ""
  echo "--- Iteration: $before open ticket(s); taking #$next ---"
  echo ""

  # Streaming output is piped through jq in real time.
  claude \
    --dangerously-skip-permissions \
    --print \
    --output-format stream-json \
    --verbose \
    "/blueprint:build-spec spec #$SPEC, building only ticket #$next" \
    | jq -r --unbuffered 'select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text' \
    || true

  after=$(open_tickets | jq 'length')

  if [ "$after" -ge "$before" ]; then
    echo ""
    echo "Build blocked: iteration closed no ticket. Check output above." >&2
    exit 1
  fi
done
