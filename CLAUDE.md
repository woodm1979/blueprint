# blueprint

**blueprint** is a planning and execution suite for Claude Code (`brainstorm`, `blueprint`, `build`, `tdd`). Plan and architecture artifacts live in `docs/ai-plans/`.

Pairs with [`woodm1979/less-opinionated-superpowers`](https://github.com/woodm1979/less-opinionated-superpowers) for debugging, code review, and git worktree workflows.

## Working on skills

Always read skill files from the repo source (`skills/*/SKILL.md`), never from the plugin cache (`~/.claude/plugins/cache/`). The cache is a snapshot of the last-pushed version and won't reflect local edits.

## Release discipline

Before pushing to GitHub, bump the version in both `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`. Users of the plugin receive updates only when the version string changes.

## PR/MR body drafts

When a feature has a DDR (`docs/ai-plans/<date>-<slug>-DDR.md`), lead the PR/MR body draft with its high-contention entries — whoever reviews it should see the non-obvious forks first, not bury them below routine summary. This is reviewer-agnostic: the note names no specific reviewer or team.
