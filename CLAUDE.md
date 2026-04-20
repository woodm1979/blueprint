# blueprint

**blueprint** is a planning and execution suite for Claude Code (`brainstorm`, `blueprint`, `build`, `tdd`). Plan and architecture artifacts live in `docs/ai-plans/`.

Pairs with [`woodm1979/less-opinionated-superpowers`](https://github.com/woodm1979/less-opinionated-superpowers) for debugging, code review, and git worktree workflows.

## Release discipline

Before pushing to GitHub, bump the version in both `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`. Users of the plugin receive updates only when the version string changes.
