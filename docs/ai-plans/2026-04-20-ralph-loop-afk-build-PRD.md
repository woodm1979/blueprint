# PRD: Ralph-loop AFK Build

> Status: draft
> Plan: ./2026-04-20-ralph-loop-afk-build-PLAN.md
> Created: 2026-04-20  |  Last touched: 2026-04-20

## Problem

The `/build` skill runs its orchestrator loop inside a single Claude Code session. With each completed section, the orchestrator's context window grows — section results, PLAN file reads, and conversation history all accumulate. Once the context passes roughly 40% capacity, Claude's output quality degrades meaningfully. For small-to-medium plans this is tolerable, but for large plans (many sections or large PLAN files) it becomes a real problem.

There is also no way to run `/build` unattended. The skill requires a live interactive session; a developer must stay present and watch for completion or blockage. For long-running plans this is impractical.

## Solution

Split `/build` into two skills and add a companion bash script:

- **`/build-step`** — a new atomic skill that executes exactly one `[ ] not started` section from a PLAN file: dispatches the section-controller (implementer + reviewers + remediation), updates the PLAN on completion, and exits with a clear completion signal. Fresh context each time it is invoked.
- **`/build`** — refactored to a thin orchestrator loop that calls `blueprint:build-step` repeatedly until all sections are complete or a section is blocked. Behavior from the user's perspective is unchanged.
- **`scripts/afk-build.sh`** — a static bash script shipped with the plugin. Uses `docker sandbox run claude` to invoke `/build-step` in a new process per iteration, giving truly fresh context and OS-level isolation. Detects completion by checking the PLAN file for remaining `[ ] not started` sections. Announces done or blocked via `/usr/bin/say` and exits with an appropriate exit code.

## User stories

1. As a developer, I want `/build-step` to execute exactly one PLAN section and exit, so it can serve as a building block for automated loops and manual single-step execution.
2. As a developer running a large plan interactively, I want `/build` to behave identically to before (all sections, in order, with 2-stage review), so the refactor is invisible to me.
3. As a developer, I want to run `scripts/afk-build.sh <plan-path>` and walk away, so the entire plan executes unattended in a Docker sandbox without filling my interactive session's context.
4. As a developer returning from an AFK run, I want the terminal to print a clear message and `/usr/bin/say` to announce completion or the blocked reason, so I do not have to watch the terminal.

## Architecture & module sketch

- **`/build-step` skill** — PLAN discovery (same logic as `/build`), next-section selection, section-controller dispatch (implementer → spec reviewer → quality reviewer → optional remediation), PLAN file update, structured completion output (`SECTION_COMPLETE`, `ALL_SECTIONS_COMPLETE`, or `BLOCKED: <reason>`)
- **`/build` skill (refactored)** — thin loop: invokes `blueprint:build-step` via Skill tool each iteration; stops when all sections complete or a BLOCKED signal is received; user-facing behavior unchanged
- **`scripts/afk-build.sh`** — bash loop: `docker sandbox run claude . -- --dangerously-skip-permissions --print --output-format stream-json "invoke blueprint:build-step"`; after each iteration, greps PLAN for remaining `[ ] not started` sections to detect progress; `/usr/bin/say` + exit on done or blocked; requires `ANTHROPIC_API_KEY` in environment (documented)

## Testing approach

- Create a test branch with a small, purpose-built PRD+PLAN (3–4 sections, simple feature)
- Verify `/build-step` marks exactly one section `[x] complete` and leaves the rest untouched
- Verify `/build` runs all sections in sequence with the refactored loop, producing the same end state as the old implementation
- Manually test `scripts/afk-build.sh` against the same test PLAN to verify the Docker loop, completion detection, and say/exit behavior

## Out of scope

- Docker image maintenance — the script uses the pre-built `docker/sandbox-templates:claude-code` image; no Dockerfile is maintained in this repo
- OAuth authentication inside the sandbox — API key (`ANTHROPIC_API_KEY`) is required for AFK runs; keychain/OAuth is unavailable inside Docker containers by design
- Windows and Linux support for `afk-build.sh` — the script uses macOS-specific `/usr/bin/say`; cross-platform support is a future concern
- Alternative loop mechanisms (RemoteTrigger, CronCreate, `/loop` skill) — evaluated and ruled out; none provide fresh-context guarantees without external infrastructure
- Changes to the section-controller subagent prompt format — the implementer/reviewer dispatch logic is unchanged; it moves to `/build-step` verbatim

## Open questions

- [ ] Whether the blueprint plugin is auto-available inside `docker sandbox run claude` or whether the script must pass `--plugin-dir $REPO_ROOT` — to be verified on first implementation run with a valid `ANTHROPIC_API_KEY`
