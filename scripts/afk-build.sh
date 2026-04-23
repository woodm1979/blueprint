#!/usr/bin/env bash
# AFK (unattended) build runner for the blueprint suite.
#
# Prerequisites:
#   - ANTHROPIC_API_KEY must be set in the environment.
#     OAuth/keychain is unavailable inside Docker containers; the key must
#     be provided explicitly.
#   - `docker` must be installed and `docker sandbox` must be available.
#     This script uses the pre-built docker/sandbox-templates:claude-code image;
#     no Dockerfile is required.
#
# Usage:
#   scripts/afk-build.sh [PLAN_FILE]
#
#   PLAN_FILE — optional path to a *-PLAN.md file. If omitted, the script
#   auto-discovers a single docs/ai-plans/*-PLAN.md candidate. If multiple
#   candidates exist, it exits with an error.

set -euo pipefail

# --- Prereq checks ---

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "Error: ANTHROPIC_API_KEY is not set. Export it before running this script." >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker not found. Install Docker and ensure it is in PATH." >&2
  exit 1
fi

if ! docker sandbox --help >/dev/null 2>&1; then
  echo "Error: docker sandbox is not available. Ensure the docker sandbox plugin is installed." >&2
  exit 1
fi

# --- Locate PLAN file ---

if [ -n "${1:-}" ]; then
  PLAN_FILE="$1"
  if [ ! -f "$PLAN_FILE" ]; then
    echo "Error: PLAN file not found: $PLAN_FILE" >&2
    exit 1
  fi
else
  # Auto-discover: single docs/ai-plans/*-PLAN.md candidate
  REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
  candidates=("$REPO_ROOT"/docs/ai-plans/*-PLAN.md)
  # Filter to actual files (glob may expand to literal string if no match)
  real_candidates=()
  for f in "${candidates[@]}"; do
    [ -f "$f" ] && real_candidates+=("$f")
  done
  count="${#real_candidates[@]}"
  if [ "$count" -eq 0 ]; then
    echo "Error: No *-PLAN.md found in docs/ai-plans/. Run /blueprint first." >&2
    exit 1
  elif [ "$count" -gt 1 ]; then
    echo "Error: Multiple PLAN files found. Specify one as \$1:" >&2
    for f in "${real_candidates[@]}"; do
      echo "  $f" >&2
    done
    exit 1
  fi
  PLAN_FILE="${real_candidates[0]}"
fi

echo "Using PLAN file: $PLAN_FILE"

# --- Parse Worktree: field from PLAN header ---

WORK_DIR="."
WORKTREE_PATH=$(grep "^> Worktree:" "$PLAN_FILE" | sed 's/^> Worktree: *//' || true)

if [ -n "$WORKTREE_PATH" ]; then
  if [ ! -d "$WORKTREE_PATH" ]; then
    echo "Error: Worktree directory not found: $WORKTREE_PATH" >&2
    echo "recreate the worktree (e.g. via EnterWorktree name: <branch>) and retry." >&2
    exit 1
  fi
  WORK_DIR="$WORKTREE_PATH"
  PLAN_FILENAME="$(basename "$PLAN_FILE")"
  PLAN_FILE="$WORK_DIR/docs/ai-plans/$PLAN_FILENAME"
  if [[ ! -f "$PLAN_FILE" ]]; then
    echo "Error: PLAN file not found in worktree: $PLAN_FILE" >&2
    exit 1
  fi
  echo "Using worktree: $WORK_DIR"
  echo "Using PLAN file (worktree copy): $PLAN_FILE"
fi

# --- Helpers ---

count_not_started() {
  grep -c '\[ \] not started' "$PLAN_FILE" 2>/dev/null || echo 0
}

# --- Main loop ---

while true; do
  before=$(count_not_started)

  if [ "$before" -eq 0 ]; then
    echo "Build complete."
    /usr/bin/say "Build complete"
    exit 0
  fi

  echo ""
  echo "--- Iteration: $before section(s) remaining ---"
  echo ""

  # Run one build-step iteration in a fresh Docker sandbox process.
  # Streaming output is piped through jq in real time; full JSON is saved for debugging.
  docker sandbox run claude "$WORK_DIR" -- \
    --dangerously-skip-permissions \
    --print \
    --output-format stream-json \
    "invoke blueprint:build-step" \
    | tee /tmp/afk-build-last.json \
    | jq -r --unbuffered 'select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text' \
    || true

  after=$(count_not_started)

  if [ "$after" -eq 0 ]; then
    echo ""
    echo "Build complete."
    /usr/bin/say "Build complete"
    exit 0
  fi

  if [ "$after" -ge "$before" ]; then
    echo ""
    echo "Build blocked. Check terminal output above for reason."
    /usr/bin/say "Build blocked"
    exit 1
  fi

  # Progress made, sections remain — continue loop
done
