#!/usr/bin/env bash
# AFK (unattended) build runner: runs build-spec on the host, one frontier
# ticket per iteration, until every ticket of the spec is done.
#
# Prerequisites:
#   - `claude` and `gh` (authenticated) on PATH, and `jq`.
#   - A worktree the repo already provisioned (this script does not create one).
#
# Usage:
#   scripts/afk-build.sh SPEC_NUMBER WORKTREE_DIR
#
# A ticket is done once it is closed, or once a local branch holds build-spec's
# merge commit for it ("Merge #N: ..."). build-spec leaves merged tickets open
# until the PR merges, so the closed state alone can't show progress. Merge
# commits already on the default branch don't count: a ticket reopened after its
# PR landed is built again.
# The frontier is the spec's unfinished sub-issues whose blockers are all done.
# An iteration that finishes no ticket stops the run with a non-zero exit.

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
DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)

# --- Helpers ---

# The default branch's local and remote refs, whichever exist.
default_refs() {
  local ref
  for ref in "$DEFAULT_BRANCH" "origin/$DEFAULT_BRANCH"; do
    if git rev-parse -q --verify "$ref^{commit}" >/dev/null; then echo "$ref"; fi
  done
}

# Ticket numbers merged into a local branch but not yet the default branch, one per line.
merged_tickets() {
  # shellcheck disable=SC2046 # one ref name per word
  git log --all --format=%s --not $(default_refs) | sed -nE 's/^Merge #([0-9]+):.*/\1/p'
}

# Numbers of the tickets in a JSON issue array (on stdin) that are not done.
not_done() {
  jq -r --argjson merged "$(merged_tickets | jq -Rs 'split("\n") | map(select(. != "") | tonumber)')" \
    '.[] | select(.state == "open" and (.number | IN($merged[]) | not)) | .number'
}

# The spec's tickets that are not done, one number per line.
remaining_tickets() {
  gh api --paginate "repos/{owner}/{repo}/issues/$SPEC/sub_issues" | jq -s add | not_done
}

# Succeeds when every blocker of ticket $1 is done. Called from `if`, where
# set -e is off, so a failed lookup exits explicitly rather than reading as "no blockers".
unblocked() {
  local blockers
  if ! blockers=$(gh api --paginate "repos/{owner}/{repo}/issues/$1/dependencies/blocked_by" | jq -s 'add // []'); then
    echo "Error: could not read blockers of #$1." >&2
    exit 1
  fi
  [ -z "$(not_done <<<"$blockers")" ]
}

# --- Main loop ---

while true; do
  remaining=$(remaining_tickets)
  before=$(grep -c . <<<"$remaining" || true)

  if [ "$before" -eq 0 ]; then
    echo "Build complete."
    exit 0
  fi

  next=""
  for n in $remaining; do
    if unblocked "$n"; then next="$n"; break; fi
  done
  if [ -z "$next" ]; then
    echo "Build blocked: $before unfinished ticket(s), none unblocked." >&2
    exit 1
  fi

  echo ""
  echo "--- Iteration: $before unfinished ticket(s); taking #$next ---"
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

  after=$(remaining_tickets | grep -c . || true)

  if [ "$after" -ge "$before" ]; then
    echo ""
    echo "Build blocked: iteration finished no ticket (none closed or merged). Check output above." >&2
    exit 1
  fi
done
