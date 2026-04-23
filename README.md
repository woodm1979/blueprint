# blueprint

Planning and execution suite for Claude Code. Provides a PRD+PLAN artifact workflow for persistent, resumable multi-section plans.

Pairs with [`woodm1979/less-opinionated-superpowers`](https://github.com/woodm1979/less-opinionated-superpowers) for full workflow coverage (TDD, debugging, code review, git worktrees, etc.).

## Installation

### Local (from this repo)

```bash
claude plugin marketplace add ./
claude plugin install blueprint
```

### From GitHub

```bash
claude plugin marketplace add woodm1979/blueprint
claude plugin install blueprint
```

## Skill Catalog

| Skill | Description |
|-------|-------------|
| `blueprint:brainstorm` | Structured interview → decision summary → artifact gate. Primary entry point. No files written. |
| `blueprint:blueprint` | Reads brainstorm context → writes and commits PRD.md + PLAN.md. Handles new features and extensions. |
| `blueprint:build` | Executes sections from a PLAN file — runs one section at a time with per-section subagents and 2-stage review. |
| `blueprint:tdd` | Red-green-refactor TDD loop. Required by `build`. |

## Workflow

```
/brainstorm  →  shared understanding
/blueprint   →  PRD.md + PLAN.md artifacts committed
/build       →  execute one section at a time
```

## Worktree isolation

`/blueprint` and `/build` support per-feature git worktrees so parallel builds never interfere with each other.

### Path convention

Worktrees are created outside the repo:

```
<parent-dir>/<repo-name>-worktrees/<feature-slug>
```

For example, if your repo is at `/home/user/myapp`, the worktree for `feature-auth` lands at `/home/user/myapp-worktrees/feature-auth`.

### How it works

1. `/blueprint` writes `> Worktree: <abs-path>` into the PLAN header, commits it, then calls `EnterWorktree` to create the worktree.
2. `/build` reads the `Worktree:` field and enters the worktree before executing any sections. All commits land on the feature branch.
3. `afk-build.sh` also reads the field and passes the worktree directory to docker as the project root.

### Override script

If `.claude/worktree-setup.sh` exists in the repo root, the `WorktreeCreate` hook runs it exclusively — auto-detection (Node/Python/Elixir/etc.) is skipped entirely. The script receives two env vars:

- `WORKTREE_DIR` — absolute path to the new worktree
- `REPO_ROOT` — absolute path to the main repo

### Cleanup

After a feature branch is merged, remove its worktree with:

```
/cleanup-worktree path/to/feature-PLAN.md
```

The skill checks for uncommitted changes, unpushed commits, and whether the branch is merged before removing anything.

### Migration (existing hook users)

If you have a `WorktreeCreate` or `WorktreeRemove` entry in `~/.claude/settings.json` from a previous manual setup, **remove those entries after installing the plugin**. The plugin ships its own hooks; having both causes duplicate execution.

## License

MIT — see LICENSE file.
