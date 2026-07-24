#!/usr/bin/env bash
# Tests for release discipline — plugin.json and marketplace.json version lockstep (Section 3)
# Run from repo root: bash tests/plugin-version-bump.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_JSON="$REPO_ROOT/.claude-plugin/plugin.json"
MARKETPLACE_JSON="$REPO_ROOT/.claude-plugin/marketplace.json"
. "$REPO_ROOT/tests/helpers.sh"

plugin_version=$(jq -r '.version' "$PLUGIN_JSON")
marketplace_version=$(jq -r '.plugins[0].version' "$MARKETPLACE_JSON")

[[ "$plugin_version" == "$marketplace_version" ]] \
  && pass "plugin.json and marketplace.json versions match ($plugin_version)" \
  || fail "plugin.json ($plugin_version) and marketplace.json ($marketplace_version) versions differ"

# Feature bump must land strictly above the pre-DDR-feature baseline (6.13.1).
baseline="6.13.1"
if [[ "$(printf '%s\n%s\n' "$baseline" "$plugin_version" | sort -V | tail -1)" == "$plugin_version" && "$plugin_version" != "$baseline" ]]; then
  pass "plugin version ($plugin_version) incremented above baseline ($baseline)"
else
  fail "plugin version ($plugin_version) not incremented above baseline ($baseline)"
fi

summarize
