# PLAN: Worktree-per-feature Parallel Isolation

> PRD: ./2026-04-23-worktree-per-feature-PRD.md
> Executor: /build
> Created: 2026-04-23  |  Last touched: 2026-04-23

## Architectural decisions

- **Worktree location**: `$(dirname $REPO_ROOT)/$(basename $REPO_ROOT)-worktrees/<slug>` — outside the repo, no `.gitignore` needed.
- **`Worktree:` line placement**: Determined and written into the PLAN *before* the Step 8 commit, so the worktree (created after) inherits the line from the committed state. `/build` always reads its own `Worktree:` path from the PLAN it is executing.
- **Hook ownership**: The plugin ships and owns the `WorktreeCreate` and `WorktreeRemove` hooks. Users who have existing hooks in `~/.claude/settings.json` must remove them after installing the plugin.
- **Override script contract**: If `.claude/worktree-setup.sh` exists in the repo root, the hook runs it exclusively — auto-detection is skipped entirely. The script receives `WORKTREE_DIR` and `REPO_ROOT` as env vars.
- **No PLAN annotation on cleanup**: Stale `Worktree:` paths in PLANs are accepted as normal. `/cleanup-worktree` removes the directory but does not edit the PLAN.
- **Backwards compatibility**: All three executors (`/build`, `afk-build.sh`, `/cleanup-worktree`) treat a missing `Worktree:` field as "no worktree" and proceed with existing behavior.

## Conventions

- TDD per section (test → impl → commit)
- Minimum one commit per completed section
- Review checkpoint between sections (spec compliance + code quality)
- Default implementer model: `sonnet`

---

## Section 1: WorktreeCreate hook + script

**Status:** [x] complete
**Model:** sonnet
**User stories covered:** 2, 6, 7

### What to build

Ship `hooks/worktree-create.sh` and `scripts/worktree-create` in the plugin. The hook fires on `WorktreeCreate` events (triggered by `EnterWorktree name: <slug>`). It creates the worktree at `<parent>/<repo>-worktrees/<name>`, installs dependencies for the detected language stack, symlinks gitignored env files and untracked `.claude/` config files into the worktree. If `.claude/worktree-setup.sh` exists in the repo, it runs that script exclusively instead of auto-detection.

### Acceptance criteria

- [x] After `EnterWorktree name: test-feature` fires, `git worktree list` shows a new worktree on branch `test-feature` at `<parent>/<repo>-worktrees/test-feature`
- [x] For a Node repo: `node_modules/` exists in the new worktree (hard-linked from repo) and the appropriate package manager install has been run
- [x] For a Python repo with `uv`: `.venv/` exists in the worktree and packages match `pyproject.toml`
- [x] Gitignored `.env*` files in the repo root are symlinked into the worktree root
- [x] Untracked `.claude/` files (settings, hooks, etc.) are symlinked into the worktree's `.claude/`
- [x] When `.claude/worktree-setup.sh` exists: only that script runs; no auto-detection side effects are present
- [x] When the branch already exists (e.g. after auto-recreate): worktree checks it out rather than attempting `git worktree add -b`
- [x] Script progress messages go to stderr; only the final worktree path is written to stdout
- [x] Hook script is executable and referenced correctly from `hooks/hooks.json`

### Notes for executor

- Base this on the user's existing `~/.claude/scripts/worktree-create` but change the path formula from `$REPO_ROOT/.claude/worktrees/$BRANCH` to `$(dirname "$REPO_ROOT")/$(basename "$REPO_ROOT")-worktrees/$BRANCH`.
- Remove the `.gitignore` step entirely — worktrees are outside the repo.
- The override script receives two env vars: `WORKTREE_DIR` and `REPO_ROOT`. Document this contract in a comment.
- `hooks/hooks.json` format for plugins differs from `settings.json` — wrap in `{"hooks": {...}}`.
- Hard-linking (`cp -Rl`) only works within the same filesystem. If source and target are on different volumes, fall back to a regular `cp -r` with a warning.

### Completion log

- Commits: a01a481
- Tests added: 10
- Deviations from plan: none

---

## Section 2: WorktreeRemove hook + script

**Status:** [ ] not started
**Model:** haiku
**User stories covered:** 5

### What to build

Ship `hooks/worktree-remove.sh` and `scripts/worktree-remove` in the plugin. The hook fires on `WorktreeRemove` events. It removes the worktree directory and prunes stale refs. This is the removal counterpart to Section 1 and is used by `/cleanup-worktree` (Section 6).

### Acceptance criteria

- [ ] After the hook fires on an existing worktree path, `git worktree list` no longer shows that worktree
- [ ] The worktree directory no longer exists on disk
- [ ] When called with a path that does not exist, exits 0 with a message to stderr — no error
- [ ] Returns the branch name (from `git symbolic-ref --short HEAD`) on stdout before removal
- [ ] Hook script is executable and referenced correctly from `hooks/hooks.json`

### Notes for executor

- Base this on the user's existing `~/.claude/scripts/worktree-remove` — it is already correct. Ship it as `scripts/worktree-remove` within the plugin and wire the hook.
- Do not delete the branch itself — only remove the worktree checkout. Branch deletion is the user's decision.

### Completion log

<!-- Executor fills in after section completes -->
- Commits:
- Tests added:
- Deviations from plan:

---

## Section 3: `/blueprint` worktree embedding (Step 6.5 + Step 8.5)

**Status:** [ ] not started
**Model:** sonnet
**User stories covered:** 2

### What to build

Add two new steps to `skills/blueprint/SKILL.md`:

**Step 6.5** (between Step 6 "Write PLAN" and Step 7 "Self-review"): Determine the feature slug from the PLAN filename. Sanitize it (replace `/` with `-`). Check if the branch/worktree already exists; if so, append a counter suffix (`-2`, `-3`, …) until a free name is found. If a worktree directory already exists at the target path, pause and ask the user: reuse as-is, delete+recreate, or abort. Write `Worktree: <abs-path>` into the PLAN header block before the Step 8 commit.

**Step 8.5** (between Step 8 "Commit" and Step 9 "GitHub issue"): Call `EnterWorktree name: <slug>` to trigger the `WorktreeCreate` hook. The worktree inherits the committed PLAN (with `Worktree:` already embedded). Update the Step 10 handoff message to show the worktree path first.

Also update the **PLAN template** in the skill to include `> Worktree: <absolute-path-to-worktree>` in the header block.

### Acceptance criteria

- [ ] After `/blueprint` completes, the committed PLAN header contains `Worktree: <abs-path>` pointing to the correct directory
- [ ] The worktree directory exists at `<parent>/<repo>-worktrees/<slug>` and `git worktree list` shows it on the feature branch
- [ ] A slug containing `/` (e.g. `feature/auth`) is sanitized to `feature-auth` in the branch and path
- [ ] If the branch `my-feature` already exists, the new worktree uses branch `my-feature-2` (and path `…-worktrees/my-feature-2`)
- [ ] If a worktree directory already exists at the computed path, the user is prompted to choose: reuse, delete+recreate, or abort — and the chosen action is executed correctly
- [ ] The Step 10 handoff message shows the worktree path on its own line before the `/build` command

### Notes for executor

- The `Worktree:` line must be in the PLAN *before* the Step 8 commit so the worktree inherits it. Step 6.5 writes it; Step 8 commits it; Step 8.5 creates the worktree.
- `EnterWorktree name: <slug>` triggers the `WorktreeCreate` hook (Section 1). The hook outputs the final worktree path to stdout — capture it to confirm.
- Slug derivation: the PLAN filename is `<date>-<slug>-PLAN.md`; extract the slug as the middle portion between the first `-` group (date) and `-PLAN.md`.

### Completion log

<!-- Executor fills in after section completes -->
- Commits:
- Tests added:
- Deviations from plan:

---

## Section 4: `/build` worktree entry

**Status:** [ ] not started
**Model:** sonnet
**User stories covered:** 1, 3

### What to build

Extend Step 1 of `skills/build/SKILL.md` to read the `Worktree:` field from the PLAN header after parsing it. If the field is present and the directory exists, call `EnterWorktree path: <abs-path>` to enter the existing worktree. If the field is present but the directory is missing, auto-recreate via `EnterWorktree name: <branch>`. After entering, re-derive the PLAN file path as `<worktree-abs-path>/docs/ai-plans/<plan-filename>`. If no `Worktree:` field is present, proceed as before (backwards-compatible).

### Acceptance criteria

- [ ] Running `/build` against a PLAN with a valid `Worktree:` path causes all git commits during the session to land on the feature branch, not on the branch of the invoking window
- [ ] `git branch` checked inside the build session shows the feature branch
- [ ] When the worktree directory is missing, `EnterWorktree name: <branch>` is called and the build resumes in the recreated worktree
- [ ] Running `/build` against a PLAN with no `Worktree:` field completes without error and operates in the main repo (backwards-compatible)
- [ ] Two simultaneous `/build` runs on different PLANs (each with their own `Worktree:`) make commits on separate branches with no cross-contamination

### Notes for executor

- The `Worktree:` line format is `> Worktree: <abs-path>` (within the blockquote header). Parse it with the same pattern used for other header fields.
- `EnterWorktree path:` (existing worktree) vs `EnterWorktree name:` (create/recreate) may behave differently — consult the tool schema before implementing. The open question in the PRD applies here.
- After `EnterWorktree`, all subsequent `Edit`, `Read`, and `Bash` tool calls are automatically scoped to the worktree. No path prefixing is needed.
- Branch name for auto-recreate: derive from the `Worktree:` path by taking the last path component.

### Completion log

<!-- Executor fills in after section completes -->
- Commits:
- Tests added:
- Deviations from plan:

---

## Section 5: `afk-build.sh` worktree support

**Status:** [ ] not started
**Model:** haiku
**User stories covered:** 1, 4

### What to build

After `afk-build.sh` locates the PLAN file, parse the `Worktree:` line from the header. If found and the directory exists, set `WORK_DIR` to that path and re-derive `PLAN_FILE` to the worktree's copy (`<worktree-abs-path>/docs/ai-plans/<plan-filename>`). If found but directory is missing, print a repair message and exit non-zero. Pass `WORK_DIR` to `docker sandbox run` instead of the hardcoded `.`. If no `Worktree:` field, `WORK_DIR` defaults to `.` — current behavior preserved.

### Acceptance criteria

- [ ] Running `afk-build.sh path/to/PLAN.md` for a PLAN with a `Worktree:` field causes docker to be invoked with the worktree directory as the project root, not `.`
- [ ] Section-state reads (checkbox counting) use the worktree's copy of the PLAN, not the main repo's copy
- [ ] With a `Worktree:` field pointing to a missing directory, the script exits non-zero with a message telling the user to recreate the worktree
- [ ] Running `afk-build.sh` against a PLAN with no `Worktree:` field behaves identically to current behavior

### Notes for executor

- Parse pattern: `grep '^> Worktree:' "$PLAN_FILE" | sed 's/^> Worktree: *//'`
- The `PLAN_FILE` re-derivation must happen after `WORK_DIR` is set, so subsequent section-counting reads the right file.
- Path quoting: `WORK_DIR` may contain spaces if the user's home directory does — always quote it in the docker command.

### Completion log

<!-- Executor fills in after section completes -->
- Commits:
- Tests added:
- Deviations from plan:

---

## Section 6: `/cleanup-worktree` skill

**Status:** [ ] not started
**Model:** sonnet
**User stories covered:** 5

### What to build

Write `skills/cleanup-worktree/SKILL.md`. The skill accepts a PLAN file path, resolves the `Worktree:` field, runs three sanity checks in order, then triggers worktree removal:

1. **Uncommitted changes** — run `git status --porcelain` in the worktree. If any output, block and report the files.
2. **Unpushed commits** — run `git log @{u}..HEAD` in the worktree. If any commits, block and report count.
3. **Unmerged branch** — check if the feature branch is reachable from `main` (or the repo's default branch). If not, warn and ask for explicit confirmation before proceeding.

On confirmation, trigger `WorktreeRemove` for the worktree path (which fires the Section 2 hook).

### Acceptance criteria

- [ ] Running `/cleanup-worktree path/to/PLAN.md` with uncommitted changes in the worktree prints the dirty files and exits without removing the worktree
- [ ] Running with unpushed commits prints the commit count and exits without removing the worktree
- [ ] Running with an unmerged branch prints a warning and requires the user to type a confirmation before proceeding
- [ ] After a successful run, `git worktree list` no longer shows the removed worktree and the directory is gone from disk
- [ ] Running against a PLAN with no `Worktree:` field exits with a clear error message
- [ ] Running against a PLAN whose `Worktree:` path does not exist on disk exits cleanly (nothing to remove)

### Notes for executor

- Determining the default branch: `git symbolic-ref refs/remotes/origin/HEAD | sed 's|refs/remotes/origin/||'`. Fall back to `main` if the remote HEAD ref is unset.
- Unmerged check: `git branch --merged <default-branch> | grep -qw <feature-branch>`. If the feature branch is NOT in the list, it's unmerged.
- The `WorktreeRemove` tool (or equivalent) triggers the hook from Section 2. If the tool is not available, fall back to calling `scripts/worktree-remove` directly via Bash.

### Completion log

<!-- Executor fills in after section completes -->
- Commits:
- Tests added:
- Deviations from plan:

---

## Section 7: Plugin packaging and migration guide

**Status:** [ ] not started
**Model:** haiku
**User stories covered:** 1, 2, 3, 4, 5, 6, 7

### What to build

Wire everything together as a shippable plugin update:

- `hooks/hooks.json` — add `WorktreeCreate` → `worktree-create.sh` and `WorktreeRemove` → `worktree-remove.sh` entries.
- `README.md` — add a "Worktree isolation" section explaining the feature, the path convention, and how to use `/cleanup-worktree`.
- **Migration guide** — document that users with an existing `WorktreeCreate` or `WorktreeRemove` hook in `~/.claude/settings.json` must remove those entries after installing the plugin to avoid duplicate execution.
- Bump version in `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`.

### Acceptance criteria

- [ ] `hooks/hooks.json` correctly references `worktree-create.sh` and `worktree-remove.sh` using the plugin-relative path format
- [ ] Installing the plugin in a fresh environment (no pre-existing hooks) produces a working end-to-end worktree flow without any manual configuration
- [ ] The README "Worktree isolation" section explains: the path convention, the override script contract, the migration step, and how to run `/cleanup-worktree`
- [ ] `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` both reflect a bumped version string

### Notes for executor

- Plugin hook format wraps entries: `{"hooks": {"WorktreeCreate": [...]}}` — different from `settings.json` direct format.
- The migration step is documentation only — do not attempt to modify the user's `~/.claude/settings.json` programmatically.
- Version bump follows the existing pattern in the repo (semver minor bump for a new feature).

### Completion log

<!-- Executor fills in after section completes -->
- Commits:
- Tests added:
- Deviations from plan:
