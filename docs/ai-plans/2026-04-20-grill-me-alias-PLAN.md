# PLAN: grill-me Skill Alias

> PRD: ./2026-04-20-grill-me-alias-PRD.md
> Executor: /build
> Created: 2026-04-20  |  Last touched: 2026-04-20

## Architectural decisions

- `skills/grill-me/SKILL.md` is a thin redirect — minimal frontmatter plus a single instruction to read `../brainstorm/SKILL.md` and follow it exactly.
- Path uses `../brainstorm/SKILL.md` (relative), not an absolute path, so it holds across plugin version bumps.
- No changes to `skills/brainstorm/SKILL.md` or any other file.

## Conventions

- TDD per section (test → impl → commit)
- Minimum one commit per completed section
- Review checkpoint between sections (spec compliance + code quality)
- Default implementer model: `sonnet`

---

## Section 1: Add grill-me redirect skill

**Status:** [x] complete
**Model:** haiku
**User stories covered:** 1

### What to build

Create `skills/grill-me/SKILL.md` with a `name: grill-me` frontmatter block, a description that identifies it as a brainstorm alias, and a redirect body that instructs Claude to read `../brainstorm/SKILL.md` and follow those instructions exactly.

### Acceptance criteria

- [x] `skills/grill-me/SKILL.md` exists in the repo.
- [x] The file's frontmatter has `name: grill-me` and a description that mentions it is an alias for `/brainstorm`.
- [x] The file body instructs Claude to read `../brainstorm/SKILL.md` (relative path) and follow those instructions.
- [x] Invoking `/grill-me` in a Claude Code session runs the brainstorm interview loop (relentless Q&A through the artifact gate).
- [x] Plugin version is bumped in `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`.

### Notes for executor

- The redirect instruction must be explicit enough for Claude to act on it — something like: "Read the file at `../brainstorm/SKILL.md` relative to this skill's base directory, then follow those instructions exactly as if you had been invoked as `/brainstorm`."
- The base directory of the skill is surfaced in the Claude Code context as `Base directory for this skill:` — Claude can construct the absolute path from that plus the relative reference.
- Version bump is required per CLAUDE.md release discipline before the commit lands.

### Completion log

- Commits: 8b79597
- Tests added: 0
- Deviations from plan: none

---
