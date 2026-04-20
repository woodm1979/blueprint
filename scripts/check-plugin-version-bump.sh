#!/usr/bin/env bash
# Blocks git push when skills/ changed but plugin version not bumped vs origin/main.

input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // ""')

# Only run for git push commands
if ! echo "$cmd" | grep -qE 'git push'; then
  exit 0
fi

# Can't check without a reachable origin/main
if ! git rev-parse origin/main >/dev/null 2>&1; then
  exit 0
fi

# Allow if no skills/ files changed in unpushed commits
skills_changed=$(git diff --name-only origin/main..HEAD -- 'skills/' 2>/dev/null | wc -l | tr -d ' ')
if [ "$skills_changed" -eq 0 ]; then
  exit 0
fi

# Allow if plugin version already differs from origin/main (version was bumped)
local_version=$(jq -r '.version' .claude-plugin/plugin.json 2>/dev/null || echo "")
remote_version=$(git show origin/main:.claude-plugin/plugin.json 2>/dev/null | jq -r '.version' 2>/dev/null || echo "")

if [ -z "$local_version" ] || [ -z "$remote_version" ] || [ "$local_version" != "$remote_version" ]; then
  exit 0
fi

# Block: skills/ changed but version not bumped
printf '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "Plugin version not bumped. skills/ files changed since origin/main but .claude-plugin/plugin.json is still %s — bump version in both .claude-plugin/plugin.json and .claude-plugin/marketplace.json before pushing."}}\n' "$local_version"
