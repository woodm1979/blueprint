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
mkdir -p "$SANDBOX/bin"

# gh stub: serves spec 24's sub-issues from $SANDBOX/tickets.json and ticket N's
# blockers from $SANDBOX/blockers-N.json (default: none). Logs every call.
cat > "$SANDBOX/bin/gh" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "$SANDBOX/gh.log"
case "$*" in
  *"/sub_issues"*) cat "$SANDBOX/tickets.json" ;;
  *"/dependencies/blocked_by"*)
    n=$(grep -oE 'issues/[0-9]+/dependencies' <<<"$*" | grep -oE '[0-9]+')
    cat "$SANDBOX/blockers-$n.json" 2>/dev/null || echo '[]' ;;
  *) echo "unexpected gh call: $*" >&2; exit 1 ;;
esac
STUB

# claude stub: logs its args and cwd, then runs $CLAUDE_ACTION (test-defined effect).
cat > "$SANDBOX/bin/claude" <<'STUB'
#!/usr/bin/env bash
echo "cwd=$PWD prompt=${!#} args=$*" >> "$SANDBOX/claude.log"
eval "${CLAUDE_ACTION:-true}"
STUB
# No docker on PATH, ever: a stub that fails loudly if the script calls it.
cat > "$SANDBOX/bin/docker" <<'STUB'
#!/usr/bin/env bash
echo "docker called" >> "$SANDBOX/docker.log"; exit 1
STUB
chmod +x "$SANDBOX/bin/gh" "$SANDBOX/bin/claude" "$SANDBOX/bin/docker"

export SANDBOX
export PATH="$SANDBOX/bin:$PATH"

ticket() { # number state
  printf '{"number":%s,"state":"%s"}' "$1" "$2"
}
# Fresh worktree: a git repo with one commit, so `git log --all` has history to search.
reset() {
  rm -f "$SANDBOX"/*.log "$SANDBOX"/blockers-*.json
  if [ -d "$SANDBOX/wt" ]; then rm -r "$SANDBOX/wt"; fi
  git init -q "$SANDBOX/wt"
  git -C "$SANDBOX/wt" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
  unset ANTHROPIC_API_KEY CLAUDE_ACTION || true
}
merge_commit() { # number: record build-spec's merge commit for ticket N
  git -C "$SANDBOX/wt" -c user.name=t -c user.email=t@t commit -q --allow-empty -m "Merge #$1: title"
}
export -f merge_commit
run() { bash "$SCRIPT" 24 "$SANDBOX/wt" >"$SANDBOX/out.txt" 2>&1; }
# The ticket number a claude prompt asked for (its last #N).
PROMPT_TICKET='n=$(grep -oE "#[0-9]+" <<<"$*" | tail -1 | tr -d "#")'

# --- No docker dependency in the script ---
grep -qiE 'docker|ANTHROPIC_API_KEY' "$SCRIPT" \
  && fail "script still references docker or ANTHROPIC_API_KEY" \
  || pass "script has no docker / API-key dependency"

# --- No open tickets: ends successfully without invoking claude ---
reset
echo "[$(ticket 33 closed)]" > "$SANDBOX/tickets.json"
if run && [ ! -e "$SANDBOX/claude.log" ]; then
  pass "no open tickets: exits 0 without running claude"
else
  fail "no open tickets: should exit 0 without running claude"
fi
[ ! -e "$SANDBOX/docker.log" ] && pass "docker never called" || fail "docker was called"

# --- build-spec merges tickets but leaves them open: merge commits count as done ---
reset
echo "[$(ticket 30 open),$(ticket 31 open)]" > "$SANDBOX/tickets.json"
echo "[$(ticket 30 open)]" > "$SANDBOX/blockers-31.json"
export CLAUDE_ACTION="$PROMPT_TICKET; merge_commit \$n"
if run; then pass "run completes when every ticket has a merge commit"; else fail "run should complete: $(cat "$SANDBOX/out.txt")"; fi
[ "$(wc -l < "$SANDBOX/claude.log")" -eq 2 ] \
  && pass "one claude run per ticket (2 tickets)" || fail "expected 2 claude runs, got $(wc -l < "$SANDBOX/claude.log")"
head -1 "$SANDBOX/claude.log" | grep -q '#30' \
  && pass "first iteration takes unblocked ticket #30" || fail "first iteration should take #30"
sed -n 2p "$SANDBOX/claude.log" | grep -q '#31' \
  && pass "second iteration takes #31 once its open blocker #30 has merged" || fail "second iteration should take #31"
[ "$(grep -c 'prompt=/blueprint:build-spec ' "$SANDBOX/claude.log")" -eq 2 ] \
  && pass "claude prompt starts with the /blueprint:build-spec slash command" || fail "claude not asked for build-spec"
grep -qF "cwd=$SANDBOX/wt " "$SANDBOX/claude.log" \
  && pass "claude runs in the provisioned worktree on the host" || fail "claude not run in worktree"
grep -q -- '--dangerously-skip-permissions' "$SANDBOX/claude.log" \
  && pass "claude runs unattended (skip-permissions)" || fail "missing --dangerously-skip-permissions"
grep -q 'sub_issues' "$SANDBOX/gh.log" && ! grep 'sub_issues' "$SANDBOX/gh.log" | grep -qv 'issues/24/sub_issues' \
  && pass "every sub_issues call targets spec 24" || fail "sub_issues called for a spec other than 24"

# --- Closing a ticket also counts as done ---
reset
echo "[$(ticket 30 open)]" > "$SANDBOX/tickets.json"
export CLAUDE_ACTION='jq "map(.state=\"closed\")" "$SANDBOX/tickets.json" > "$SANDBOX/t.tmp"; mv "$SANDBOX/t.tmp" "$SANDBOX/tickets.json"'
if run && [ "$(wc -l < "$SANDBOX/claude.log")" -eq 1 ]; then pass "a closed ticket counts as done"; else fail "closed ticket should end the run"; fi

# --- A ticket merged before the run is skipped; Merge #3 does not count for #30 ---
reset
echo "[$(ticket 30 open),$(ticket 3 open)]" > "$SANDBOX/tickets.json"
merge_commit 30
export CLAUDE_ACTION="$PROMPT_TICKET; merge_commit \$n"
run || true
[ "$(wc -l < "$SANDBOX/claude.log")" -eq 1 ] && grep -q '#3$' "$SANDBOX/claude.log" \
  && pass "already-merged #30 is skipped; only #3 runs" || fail "expected one run, for #3: $(cat "$SANDBOX/claude.log" 2>/dev/null)"

# --- Blocked tickets are not taken ---
reset
echo "[$(ticket 30 open),$(ticket 31 open)]" > "$SANDBOX/tickets.json"
echo "[$(ticket 31 open)]" > "$SANDBOX/blockers-30.json"
echo "[$(ticket 30 open)]" > "$SANDBOX/blockers-31.json"
if run; then fail "all-blocked frontier should stop the run non-zero"; else pass "empty frontier with open tickets stops non-zero"; fi
[ ! -e "$SANDBOX/claude.log" ] && pass "blocked tickets are never started" || fail "blocked ticket was started"

# --- An iteration that neither merges nor closes a ticket stops the run ---
reset
echo "[$(ticket 30 open),$(ticket 31 open)]" > "$SANDBOX/tickets.json"
export CLAUDE_ACTION=true
if run; then fail "no-progress iteration should exit non-zero"; else pass "no-progress iteration exits non-zero"; fi
[ "$(wc -l < "$SANDBOX/claude.log")" -eq 1 ] \
  && pass "stops after the first no-progress iteration" || fail "should not loop after no progress"

# --- Argument handling ---
reset
if bash "$SCRIPT" >/dev/null 2>&1; then fail "missing spec arg should fail"; else pass "missing spec arg exits non-zero"; fi
if bash "$SCRIPT" 24 "$SANDBOX/nope" >/dev/null 2>&1; then fail "missing worktree should fail"; else pass "missing worktree dir exits non-zero"; fi

summarize
