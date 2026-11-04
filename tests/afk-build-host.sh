#!/usr/bin/env bash
# Tests for scripts/afk-build.sh: host-only loop over a spec's open-ticket frontier.
# Stubs `gh` and `claude` on PATH; calls neither the real CLI nor GitHub.
# Run from repo root: bash tests/afk-build-host.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/afk-build.sh"
. "$REPO_ROOT/tests/helpers.sh"

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
mkdir -p "$SANDBOX/bin" "$SANDBOX/wt"

# gh stub: serves the sub-issues of spec 24 from $TICKETS (a JSON array in the
# shape of GitHub's sub_issues endpoint) and logs every call to $SANDBOX/gh.log.
cat > "$SANDBOX/bin/gh" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "$SANDBOX/gh.log"
cat "$SANDBOX/tickets.json"
STUB

# claude stub: logs its args and cwd, then runs $CLAUDE_ACTION (test-defined effect).
cat > "$SANDBOX/bin/claude" <<'STUB'
#!/usr/bin/env bash
echo "cwd=$PWD args=$*" >> "$SANDBOX/claude.log"
eval "${CLAUDE_ACTION:-true}"
STUB
chmod +x "$SANDBOX/bin/gh" "$SANDBOX/bin/claude"
# No docker on PATH, ever: a stub that fails loudly if the script calls it.
cat > "$SANDBOX/bin/docker" <<'STUB'
#!/usr/bin/env bash
echo "docker called" >> "$SANDBOX/docker.log"; exit 1
STUB
chmod +x "$SANDBOX/bin/docker"

export SANDBOX
export PATH="$SANDBOX/bin:$PATH"

ticket() { # number state blocked_by
  printf '{"number":%s,"state":"%s","issue_dependencies_summary":{"blocked_by":%s}}' "$1" "$2" "$3"
}
reset() { rm -f "$SANDBOX"/*.log; unset ANTHROPIC_API_KEY || true; }
run() { bash "$SCRIPT" 24 "$SANDBOX/wt" >"$SANDBOX/out.txt" 2>&1; }

# --- No docker dependency in the script ---
grep -qiE 'docker|ANTHROPIC_API_KEY' "$SCRIPT" \
  && fail "script still references docker or ANTHROPIC_API_KEY" \
  || pass "script has no docker / API-key dependency"

# --- No open tickets: ends successfully without invoking claude ---
reset
echo "[$(ticket 33 closed 0)]" > "$SANDBOX/tickets.json"
if run && [ ! -e "$SANDBOX/claude.log" ]; then
  pass "no open tickets: exits 0 without running claude"
else
  fail "no open tickets: should exit 0 without running claude"
fi
[ ! -e "$SANDBOX/docker.log" ] && pass "docker never called" || fail "docker was called"

# --- Each iteration closes the frontier ticket; run ends when none are open ---
reset
echo "[$(ticket 30 open 0),$(ticket 31 open 1)]" > "$SANDBOX/tickets.json"
# Closing the ticket named in the prompt, then unblocking the rest.
export CLAUDE_ACTION='
  n=$(grep -oE "#[0-9]+" <<<"$*" | tail -1 | tr -d "#")
  jq --argjson n "$n" "map(if .number==\$n then .state=\"closed\" else . end)
    | map(.issue_dependencies_summary.blocked_by = 0)" "$SANDBOX/tickets.json" > "$SANDBOX/t.tmp"
  mv "$SANDBOX/t.tmp" "$SANDBOX/tickets.json"'
if run; then pass "run completes when all tickets close"; else fail "run should complete: $(cat "$SANDBOX/out.txt")"; fi
[ "$(wc -l < "$SANDBOX/claude.log")" -eq 2 ] \
  && pass "one claude run per ticket (2 tickets)" || fail "expected 2 claude runs"
head -1 "$SANDBOX/claude.log" | grep -q '#30' \
  && pass "first iteration takes unblocked ticket #30" || fail "first iteration should take #30"
sed -n 2p "$SANDBOX/claude.log" | grep -q '#31' \
  && pass "second iteration takes #31 once unblocked" || fail "second iteration should take #31"
grep -q 'build-spec' "$SANDBOX/claude.log" \
  && pass "claude is asked to run build-spec" || fail "claude not asked for build-spec"
grep -qF "cwd=$SANDBOX/wt " "$SANDBOX/claude.log" \
  && pass "claude runs in the provisioned worktree on the host" || fail "claude not run in worktree"
grep -q -- '--dangerously-skip-permissions' "$SANDBOX/claude.log" \
  && pass "claude runs unattended (skip-permissions)" || fail "missing --dangerously-skip-permissions"

# --- Blocked tickets are not taken ---
reset
unset CLAUDE_ACTION
echo "[$(ticket 30 open 1),$(ticket 31 open 1)]" > "$SANDBOX/tickets.json"
if run; then fail "all-blocked frontier should stop the run non-zero"; else pass "empty frontier with open tickets stops non-zero"; fi
[ ! -e "$SANDBOX/claude.log" ] && pass "blocked tickets are never started" || fail "blocked ticket was started"

# --- An iteration that closes no ticket stops the run ---
reset
echo "[$(ticket 30 open 0),$(ticket 31 open 0)]" > "$SANDBOX/tickets.json"
export CLAUDE_ACTION=true
if run; then fail "no-progress iteration should exit non-zero"; else pass "no-progress iteration exits non-zero"; fi
[ "$(wc -l < "$SANDBOX/claude.log")" -eq 1 ] \
  && pass "stops after the first no-progress iteration" || fail "should not loop after no progress"

# --- Argument handling ---
reset
if bash "$SCRIPT" >/dev/null 2>&1; then fail "missing spec arg should fail"; else pass "missing spec arg exits non-zero"; fi
if bash "$SCRIPT" 24 "$SANDBOX/nope" >/dev/null 2>&1; then fail "missing worktree should fail"; else pass "missing worktree dir exits non-zero"; fi

summarize
