#!/usr/bin/env bash
# Interactive worktree launcher for herdr (bind as a `type = "pane"` keybinding).
#
# Two-stage fzf flow:
#   1. Pick an existing worktree to OPEN, or "＋ new worktree…" (type a name).
#      Opening reuses `herdr worktree open`, so the worktree shows up as a nested
#      sub-workspace under the repo (same as an already-open worktree). Picking a
#      worktree that's already open just focuses its workspace.
#   2. (new only) Pick the BASE ref: the current pane's HEAD first, then the repo
#      default branch, then the rest of the local branches by commit date (newest
#      first). Type a ref that isn't listed (a tag/sha) to base off that instead.
#
# Creating a new worktree uses blueprint's layout-aware scripts/worktree-create
# (the SAME provisioning the Claude/herdr hooks use), then opens it the same way.
#
# Non-interactive fallback (skips fzf): herdr-new-worktree.sh <branch> [base] [repo-root]
set -euo pipefail

# herdr panes may carry a thin PATH; ensure git/jq/fzf/mise (post_create) resolve.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# The shared creator lives next to this script (herdr-plugin/ sibling of scripts/).
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
WT_CREATE="$SELF_DIR/../scripts/worktree-create"
[ -x "$WT_CREATE" ] || { echo "blueprint scripts/worktree-create not found at $WT_CREATE" >&2; exit 1; }

# Pause before the pane closes so output/errors are readable.
pause() { [ -t 0 ] && read -r -p "Press Enter to close…" _ || true; }
trap 'rc=$?; [ $rc -ne 0 ] && { echo "Failed (exit $rc)." >&2; pause; }; exit $rc' EXIT

BRANCH="${1:-}"
BASE="${2:-}"
REPO_ROOT="${3:-}"

# --- resolve repo context from the current pane's cwd -----------------------
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$REPO_ROOT" ] || { echo "Not inside a git worktree; cd into one (or pass repo-root)." >&2; exit 1; }
fi

# herdr worktree actions reference the repo's PARENT/source workspace, not a
# linked worktree. dirname(git-common-dir) is the container (bare layout) or the
# main repo (standard) — resolvable even when REPO_ROOT is itself a worktree.
SRC="$(dirname "$(git -C "$REPO_ROOT" rev-parse --path-format=absolute --git-common-dir)")"

# Current branch (or short SHA when detached) — the first base pin + default base.
CUR_BRANCH="$(git -C "$REPO_ROOT" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
CUR_REF="${CUR_BRANCH:-$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || true)}"

# Repo default branch (origin/HEAD → e.g. main), with a local fallback scan.
DEF_BRANCH="$(git -C "$SRC" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||' || true)"
if [ -z "$DEF_BRANCH" ]; then
  for b in main master; do
    git -C "$SRC" show-ref --verify --quiet "refs/heads/$b" && { DEF_BRANCH="$b"; break; }
  done
fi

# Run fzf capturing its exit code without tripping `set -e`. fzf exits 0 when a
# row is selected, 1 when the query matched nothing (the query is still printed
# via --print-query — that's the "type a new name" path), and >=130 on Esc/Ctrl-C
# (a genuine abort). Usage: fzf_capture VAR <fzf-args...> ; stdin = the rows.
fzf_capture() {
  local __var="$1"; shift
  local __out __rc
  set +e
  __out="$(fzf "$@")"; __rc=$?
  set -e
  [ "$__rc" -ge 130 ] && { echo "Aborted." >&2; exit 0; }
  printf -v "$__var" '%s' "$__out"
}

# --- stage 1: pick a worktree to open, or start a new one -------------------
if [ -z "$BRANCH" ]; then
  command -v fzf >/dev/null 2>&1 || { echo "fzf not found (brew install fzf); pass a branch name to skip the picker." >&2; exit 1; }

  NEW="＋ new worktree…"
  # Rows are tab-delimited: DISPLAY \t PATH \t OPEN_WORKSPACE_ID. fzf shows only
  # column 1; we recover PATH/OPEN from the selected row. The sentinel has no path.
  rows="$NEW"$'\t'$'\t'
  while IFS=$'\t' read -r wb wp wo; do
    [ -n "$wb" ] || continue
    disp="$wb"; [ -n "$wo" ] && disp="$wb  ● open"
    rows="$rows"$'\n'"$disp"$'\t'"$wp"$'\t'"$wo"
  done < <(herdr worktree list --cwd "$SRC" --json 2>/dev/null \
            | jq -r '.result.worktrees[]
                     | select(.is_bare | not) | select(.branch != null)
                     | [.branch, .path, (.open_workspace_id // "")] | @tsv')

  fzf_capture SEL <<<"$rows" \
    --layout=reverse --border --delimiter=$'\t' --with-nth=1 \
    --prompt='worktree ▸ ' \
    --header='Enter: open the selected worktree · type a new name + Enter: create it' \
    --print-query

  QUERY="$(sed -n 1p <<<"$SEL")"
  CHOSEN="$(sed -n 2p <<<"$SEL")"
  C_DISP="$(cut -f1 <<<"$CHOSEN")"
  C_PATH="$(cut -f2 <<<"$CHOSEN")"
  C_WS="$(cut -f3 <<<"$CHOSEN")"

  # An existing worktree was chosen (not the sentinel, and it carries a path).
  if [ -n "$CHOSEN" ] && [ "$C_DISP" != "$NEW" ] && [ -n "$C_PATH" ]; then
    if [ -n "$C_WS" ]; then
      echo "Already open — focusing workspace $C_WS…" >&2
      herdr workspace focus "$C_WS" >/dev/null
    else
      echo "Opening worktree $C_PATH…" >&2
      herdr worktree open --cwd "$SRC" --path "$C_PATH" --focus >/dev/null
      echo "Done. Opened $C_PATH" >&2
    fi
    exit 0
  fi

  # Otherwise: new worktree. Name = the typed query, or prompt if they picked the
  # sentinel without typing anything.
  BRANCH="$QUERY"
  if [ -z "$BRANCH" ] || [ "$BRANCH" = "$NEW" ]; then
    read -r -p "New worktree branch name: " BRANCH
  fi
  [ -n "$BRANCH" ] || { echo "No branch name given." >&2; exit 1; }

  # --- stage 2: pick the base ref -------------------------------------------
  # Pins first (current HEAD, then default branch — emphasized), then the rest of
  # the local branches newest-first. Each row is DISPLAY<TAB>REF: fzf renders the
  # ANSI-colored DISPLAY (--ansi --with-nth=1) while we recover the CLEAN REF from
  # field 2, so color codes can never leak into the value we hand to git.
  CSI=$'\033['
  C_PIN="${CSI}1;38;5;173m"   # bold terracotta — matches the prompt's branch color
  C_DIM="${CSI}2m"
  C_RST="${CSI}0m"
  base_row() {  # ref, annotation, is_pin  ->  "DISPLAY\tREF"
    local pad; pad="$(printf '%-28s' "$1")"
    if [ "$3" = 1 ]; then printf '%s%s  %s%s\t%s' "$C_PIN" "$pad" "$2" "$C_RST" "$1"
    else                  printf '%s  %s%s%s\t%s' "$pad" "$C_DIM" "$2" "$C_RST" "$1"; fi
  }
  base_rows="$(base_row "$CUR_REF" "(current HEAD)" 1)"
  [ -n "$DEF_BRANCH" ] && [ "$DEF_BRANCH" != "$CUR_REF" ] \
    && base_rows="$base_rows"$'\n'"$(base_row "$DEF_BRANCH" "(default branch)" 1)"
  while IFS=$'\t' read -r rb rd; do
    [ -n "$rb" ] || continue
    [ "$rb" = "$CUR_REF" ] && continue
    [ "$rb" = "$DEF_BRANCH" ] && continue
    base_rows="$base_rows"$'\n'"$(base_row "$rb" "$rd" 0)"
  done < <(git -C "$SRC" for-each-ref --sort=-committerdate \
             --format='%(refname:short)'$'\t''%(committerdate:relative)' refs/heads/)

  fzf_capture BSEL <<<"$base_rows" \
    --ansi --layout=reverse --border --delimiter=$'\t' --with-nth=1 \
    --prompt="base for '$BRANCH' ▸ " \
    --header='Enter: base the new worktree on this ref · type a tag/sha to use it' \
    --print-query
  BQUERY="$(sed -n 1p <<<"$BSEL")"
  BCHOSEN="$(sed -n 2p <<<"$BSEL" | cut -f2)"
  BASE="${BCHOSEN:-$BQUERY}"
  [ -n "$BASE" ] || BASE="$CUR_REF"   # nothing picked/typed → base off current HEAD
fi

# --- create + open ----------------------------------------------------------
echo "Creating worktree '$BRANCH' in $REPO_ROOT (base: ${BASE:-HEAD})…" >&2
WT="$(bash "$WT_CREATE" "$REPO_ROOT" "$BRANCH" "$BASE")"   # stdout = worktree path
echo "Worktree provisioned at: $WT" >&2

echo "Attaching herdr…" >&2
herdr worktree open --cwd "$SRC" --path "$WT" --focus >/dev/null

echo "Done. Opened $WT" >&2
