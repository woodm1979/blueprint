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

# The durable invariant is lockstep between the two files. "Bump before push" is
# enforced separately by the git-push hook (scripts/check-plugin-version-bump.sh),
# so no static version floor is asserted here — a hardcoded baseline would be
# trivially true forever after this release and give false confidence.

summarize
