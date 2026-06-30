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

The worktree lifecycle is split into three orthogonal concerns, each with a sensible default and a clear override point. Layout (standard vs **bare** repo) is detected once, up front, and every concern is correct for both.

### Concern 1 — Creation (path convention)

The path is tool-owned; you don't override it with a script. The default depends on layout:

- **Standard repo:** `<parent-dir>/<repo-name>-worktrees/<feature-slug>` — e.g. a repo at `/home/user/myapp` puts `feature-auth` at `/home/user/myapp-worktrees/feature-auth`.
- **Bare repo** (a `.bare` git dir with sibling worktrees): `<container>/<slug>` alongside `.bare`, where `slug` lowercases the branch and maps anything outside `[a-z0-9_]` to `_` (`Feature-Auth` → `feature_auth`). The branch name itself is preserved.

The final worktree path is printed as the **last stdout line** (all progress goes to stderr).

### How it works

1. `/blueprint` writes `> Worktree: <abs-path>` into the PLAN header, commits it, then calls `EnterWorktree` to create the worktree.
2. `/build` reads the `Worktree:` field and enters the worktree before executing any sections. All commits land on the feature branch.
3. `afk-build.sh` also reads the field and passes the worktree directory to docker as the project root.

### Concern 2 — File-bringing (`.worktreeinclude`)

A repo-root **`.worktreeinclude`** (gitignore-style, one path per line) lists gitignored/shared files to bring into each new worktree. When present, it is authoritative.

- An unmarked line is **copied** (the portable default).
- A line prefixed with **`&`** is **symlinked** to the canonical source instead.
- Blank lines and `#` comments are ignored.
- Source is the repo root in a standard layout, the **container** in a bare layout.

```
# .worktreeinclude
.env                       # copied
&graphdb.license           # symlinked to the canonical copy
&.claude/settings.local.json
```

If no `.worktreeinclude` exists, the hook falls back to its historical behavior: copy gitignored `.env*` files and symlink untracked `.claude/` files.

### Concern 3 — Setup & teardown hooks (trust-gated)

Repo-shipped lifecycle scripts under `.worktree/` own setup/teardown when present. Each receives two env vars and runs with its cwd set to the worktree:

- `WORKTREE_DIR` — absolute path to the worktree
- `REPO_ROOT` — absolute path to the main repo

| Hook | When | Effect |
|------|------|--------|
| `.worktree/post_create` | after a worktree is created | owns setup entirely — language auto-detection (Node/Python/Elixir/…) is skipped |
| `.worktree/pre_delete` | before a worktree is removed | teardown (e.g. drop per-worktree databases) |

**Trust model (direnv-style).** A repo-shipped script that executes code is inert until you allow it. Trust is keyed by **content hash**, so editing the script re-locks it until re-allowed:

```
"$CLAUDE_PLUGIN_ROOT/scripts/worktree-trust" allow .worktree/post_create
```

`worktree-trust` also supports `deny`, `check`, and `list`. Until a hook is trusted it is skipped with a warning; creation/removal still proceed. (The allowlist lives at `${XDG_DATA_HOME:-~/.local/share}/blueprint/trusted-hooks`.)

> **Note:** `.worktree/post_create` replaces the older `.worktree-setup` / `.claude/worktree-setup.sh` override, which is no longer consulted.

### herdr integration (optional)

If you use [herdr](https://herdr.dev) as your terminal multiplexer, the `herdr-plugin/`
directory wires herdr-created worktrees into this *same* `scripts/worktree-create`
pipeline — one code path whether Claude or herdr makes the worktree.

> **Not using herdr? Ignore this section.** Nothing in `herdr-plugin/` is referenced by
> the Claude plugin (`.claude-plugin/`, `hooks/`, `skills/`), so installing blueprint never
> loads or runs it. It activates only if *you* link it (`herdr plugin link`) or bind a key.

Two parts:

- **`herdr-new-worktree.sh`** — creates a worktree the blueprint way (layout-aware
  path + full provisioning) then attaches herdr to it via `herdr worktree open`. Bind
  it to a `type = "pane"` keybinding in `~/.config/herdr/config.toml`:
  ```toml
  [[keys.command]]
  key = "prefix+ctrl+w"
  type = "pane"
  command = "/bin/bash /path/to/blueprint/herdr-plugin/herdr-new-worktree.sh"
  ```
- **`herdr-plugin.toml`** (event hook) — fallback for worktrees made via herdr's own
  native UI (which land at `~/.herdr/worktrees/<repo>/<branch>`): the `worktree.created`
  event re-runs provisioning on them in place. Enable with `herdr plugin link <path>/herdr-plugin`.

`scripts/worktree-create` accepts an optional 4th arg (an already-created worktree dir);
when given it skips `git worktree add` and only provisions — that's how the herdr paths
reuse it. `WT_PROVISION_ON_FAIL=keep` leaves a worktree in place on setup failure
(herdr owns it) instead of the default `remove`.

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
