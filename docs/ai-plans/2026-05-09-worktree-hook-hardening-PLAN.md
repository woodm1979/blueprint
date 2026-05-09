# PLAN: Worktree Hook Hardening

> PRD: ./2026-05-09-worktree-hook-hardening-PRD.md
> Executor: /build
> Worktree: /Users/woodnt/Code/src/github.com/woodm1979/blueprint-worktrees/worktree-hook-hardening
> Created: 2026-05-09  |  Last touched: 2026-05-09

## Architectural decisions

- Hook scripts read all context from the stdin JSON payload; no shell path tricks for locating the repo root.
- Repo root is derived via `git -C "$CWD" rev-parse --show-toplevel` where `$CWD` comes from `.cwd` in the payload.
- `WorktreeRemove` is not a real Claude Code event; the hook, its registration, and all skill references to it are removed rather than kept as fallback.
- `scripts/worktree-create` interface is unchanged — the hook passes `REPO_ROOT` and `NAME` as positional args.

## Conventions

- TDD per section (test → impl → commit)
- Minimum one commit per completed section
- Review checkpoint between sections (spec compliance + code quality)
- Default implementer model: `sonnet`

---

## Section 1: Harden worktree-create hook

**Status:** [x] complete
**Model:** haiku
**User stories covered:** 1, 2

### What to build

Rewrite `hooks/worktree-create.sh` to read `.cwd` and `.name` from the stdin JSON payload. Derive `REPO_ROOT` via `git -C "$CWD" rev-parse --show-toplevel`. Exit non-zero with an error message if `NAME` is empty or the string `"null"`.

### Acceptance criteria

- [x] Hook reads `.cwd` from the event payload JSON (not from `${BASH_SOURCE[0]}`).
- [x] Hook reads `.name` from the event payload JSON.
- [x] Hook exits non-zero and prints an error if `NAME` is empty or the string `"null"`.
- [x] Hook passes `REPO_ROOT` (derived from `git -C "$CWD"`) and `NAME` to `scripts/worktree-create`.
- [x] No `cd`, `pushd`, or `BASH_SOURCE`-based path tricks remain in the script.

### Notes for executor

- Current script uses `cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd` to find the plugin root. Replace this with `git -C "$CWD" rev-parse --show-toplevel`.
- The payload schema from Claude Code's `WorktreeCreate` event includes `.name` (the worktree name) and `.cwd` (the directory where Claude Code is running, i.e. the repo root).
- Check for `NAME == ""` and `NAME == "null"` separately; `jq -r` outputs the string `null` when the JSON value is `null`.

### Completion log

- Commits: 16ef449157d0f4d4a68af4ee980a4453460bfa01
- Tests added: 5 (17 total, all passing)
- Deviations from plan: scripts/worktree-create updated to accept REPO_ROOT as arg1, NAME as arg2 (was single-arg); all internal git calls updated to use git -C "$REPO_ROOT"

---

## Section 2: Remove WorktreeRemove dead code

**Status:** [ ] not started
**Model:** haiku
**User stories covered:** 3, 4

### What to build

Delete `hooks/worktree-remove.sh`. Remove the `WorktreeRemove` block from `hooks/hooks.json`. Update `skills/cleanup-worktree/SKILL.md` Step 7 to use `git worktree remove --force "$WORKTREE_DIR" && git worktree prune` directly, with no reference to `WorktreeRemove`.

### Acceptance criteria

- [ ] `hooks/worktree-remove.sh` no longer exists in the repo.
- [ ] `hooks/hooks.json` contains no `WorktreeRemove` key.
- [ ] `skills/cleanup-worktree/SKILL.md` Step 7 uses `git worktree remove --force "$WORKTREE_DIR" && git worktree prune` directly.
- [ ] `skills/cleanup-worktree/SKILL.md` contains no reference to `WorktreeRemove` anywhere.

### Notes for executor

- `hooks/hooks.json` must remain valid JSON after removing the `WorktreeRemove` block.
- The SKILL.md update is prose only — no new code paths or logic, just replace the two-sentence Step 7 description with the direct git commands.
- The fallback sentence ("If `WorktreeRemove` is not available... fall back to `scripts/worktree-remove`") is also dead — remove it.

### Completion log

<!-- Executor fills in after section completes -->
- Commits:
- Tests added:
- Deviations from plan:

---

## Section 3: Clean up test-things worktree

**Status:** [ ] not started
**Model:** haiku
**User stories covered:** —

### What to build

Remove the stale `test-things` worktree from disk and delete the `test-things` branch from git.

### Acceptance criteria

- [ ] `git worktree list` no longer shows an entry for `test-things`.
- [ ] The directory `/Users/woodnt/Code/src/github.com/woodm1979/blueprint-worktrees/test-things` does not exist on disk.
- [ ] `git branch --list test-things` returns nothing.

### Notes for executor

- Run `git worktree remove --force /Users/woodnt/Code/src/github.com/woodm1979/blueprint-worktrees/test-things` then `git branch -D test-things`.
- If the worktree directory is already gone (e.g. manually deleted), skip straight to `git worktree prune && git branch -D test-things`.

### Completion log

<!-- Executor fills in after section completes -->
- Commits:
- Tests added:
- Deviations from plan:
