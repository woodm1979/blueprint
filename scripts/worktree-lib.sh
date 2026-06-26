#!/usr/bin/env bash
# Shared helpers for the worktree lifecycle scripts (create / remove / trust).
# Sourced, not executed — defines functions only and never sets shell options
# (the sourcing script owns `set -euo pipefail`).

# Per-user allowlist of trusted hook contents. Keyed by content hash only — a
# committed hook is byte-identical across every worktree, so a path key would
# never match an ephemeral worktree dir. Override for tests / isolation.
WORKTREE_TRUST_STORE="${BLUEPRINT_WORKTREE_TRUST_FILE:-${XDG_DATA_HOME:-$HOME/.local/share}/blueprint/trusted-hooks}"

# Layout detection (once, up front). Sets WT_LAYOUT (bare|standard) and, for
# bare, WT_CONTAINER (the dir holding .bare + sibling worktrees).
detect_layout() {
  local repo_root="$1" common_dir
  common_dir="$(git -C "$repo_root" rev-parse --path-format=absolute --git-common-dir)"
  if [[ "$(basename "$common_dir")" == ".bare" ]]; then
    WT_LAYOUT=bare
    WT_CONTAINER="$(dirname "$common_dir")"
  else
    WT_LAYOUT=standard
    WT_CONTAINER=""
  fi
}

# Canonical worktree-dir slug: lowercase; anything outside [a-z0-9_] -> _.
slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_]/_/g'
}

# Content hash of a file (sha256), used as the trust key.
hook_hash() {
  if command -v sha256sum &>/dev/null; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# Is this hook file's current content trusted? 0 = yes, 1 = no.
trust_check() {
  local file="$1" h
  [[ -f "$WORKTREE_TRUST_STORE" ]] || return 1
  h="$(hook_hash "$file")"
  grep -qxF "$h" "$WORKTREE_TRUST_STORE"
}

# Record this file's current content as trusted.
trust_allow() {
  local file="$1" h
  h="$(hook_hash "$file")"
  mkdir -p "$(dirname "$WORKTREE_TRUST_STORE")"
  touch "$WORKTREE_TRUST_STORE"
  grep -qxF "$h" "$WORKTREE_TRUST_STORE" || echo "$h" >> "$WORKTREE_TRUST_STORE"
}

# Drop this file's current content from the allowlist.
trust_deny() {
  local file="$1" h tmp
  [[ -f "$WORKTREE_TRUST_STORE" ]] || return 0
  h="$(hook_hash "$file")"
  tmp="$(mktemp)"
  grep -vxF "$h" "$WORKTREE_TRUST_STORE" > "$tmp" || true
  mv "$tmp" "$WORKTREE_TRUST_STORE"
}

# Run a repo-shipped lifecycle hook ($2) if present and trusted. The hook owns
# its phase entirely; it receives WORKTREE_DIR + REPO_ROOT and runs with cwd set
# to the worktree. Untrusted/absent is non-fatal — prints how to allow.
# Usage: run_trusted_hook <worktree-dir> <hook-file> <repo-root> <phase-label>
# Returns 0 if it ran, 1 if it was absent or skipped.
run_trusted_hook() {
  local wt_dir="$1" hook_file="$2" repo_root="$3" label="$4"
  [[ -f "$hook_file" ]] || return 1
  if trust_check "$hook_file"; then
    echo "Running $label ($hook_file)..." >&2
    (cd "$wt_dir" && WORKTREE_DIR="$wt_dir" REPO_ROOT="$repo_root" bash "$hook_file" >&2)
    return 0
  fi
  echo "Warning: $hook_file is untrusted — skipping $label." >&2
  echo "         Review it, then trust it with:" >&2
  echo "           \"\$CLAUDE_PLUGIN_ROOT/scripts/worktree-trust\" allow \"$hook_file\"" >&2
  return 1
}
