# PLAN: Ralph-loop AFK Build

> PRD: ./2026-04-20-ralph-loop-afk-build-PRD.md
> Executor: /build
> Created: 2026-04-20  |  Last touched: 2026-04-20

## Architectural decisions

- **`/build-step` is the atomic section-execution primitive.** It contains the full section lifecycle: PLAN discovery, next-section selection, section-controller dispatch (implementer → spec reviewer → quality reviewer → optional remediation), PLAN file update, and completion output. Nothing else owns this logic.
- **`/build` dispatches a subagent per section that follows `blueprint:build-step`.** The inline section-controller template (the `---IMPLEMENTER PROMPT START---` block and surrounding phase instructions) is removed from `/build` and replaced with a short subagent prompt: "Invoke `blueprint:build-step` to execute the next section." The subagent loads the skill and handles the full lifecycle. `/build`'s orchestrator only reads the final completion signal.
- **Completion interface:** `/build-step` always ends by outputting exactly one of: `SECTION_COMPLETE`, `ALL_SECTIONS_COMPLETE`, or `BLOCKED: <reason>`. This is the interface consumed by both `/build`'s orchestrator and the bash script.
- **AFK loop:** `scripts/afk-build.sh` calls `docker sandbox run claude . -- --dangerously-skip-permissions --print --output-format stream-json "invoke blueprint:build-step"` once per iteration. Each call is a fresh `claude` process — fresh context guaranteed. OS isolation is provided by the Docker sandbox.
- **Completion detection in the bash script:** After each iteration, the script greps the PLAN file for remaining `[ ] not started` sections. If the count drops, the section completed. If unchanged, the run made no progress (blocked or failed).
- **No Dockerfile.** The pre-built `docker/sandbox-templates:claude-code` image is used. The script pulls it on first use via `docker sandbox run`.
- **Auth:** `ANTHROPIC_API_KEY` must be set in the environment. OAuth/keychain is unavailable inside Docker containers.
- **`/usr/bin/say` for audio notification.** macOS-only. Script announces completion or blocked reason.

## Conventions

- TDD per section (test → impl → commit)
- Minimum one commit per completed section
- Review checkpoint between sections (spec compliance + code quality)
- Default implementer model: `sonnet`

---

## Section 1: Implement `/build-step` skill

**Status:** [x] complete
**Model:** sonnet
**User stories covered:** 1

### What to build

Create `skills/build-step/SKILL.md`. This skill contains the full section-execution lifecycle currently inline in `/build`: PLAN discovery, next `[ ] not started` section selection, section-controller subagent dispatch (implementer + spec reviewer + quality reviewer + optional remediation), PLAN file update, and structured completion output.

### Acceptance criteria

- [x] `skills/build-step/SKILL.md` exists with valid skill frontmatter (`name`, `description`)
- [x] Invoking `/build-step` on a PLAN with multiple `[ ] not started` sections marks exactly one section `[x] complete`, checks off its acceptance criteria, fills in the completion log, and commits — leaving all other sections untouched
- [x] `/build-step` performs PLAN discovery using the same logic as `/build` (user `@`-ref → single candidate → AskUserQuestion for multiple → tell user to run `/blueprint` for none)
- [x] `/build-step` dispatches the full section-controller → implementer → spec reviewer → quality reviewer subagent chain with the same model assignments as the current `/build` (section-controller: `sonnet`; reviewers: `opus`)
- [x] On success, `/build-step` outputs exactly `SECTION_COMPLETE` as its final line
- [x] If no `[ ] not started` sections remain when invoked, `/build-step` outputs exactly `ALL_SECTIONS_COMPLETE` and stops
- [x] If the section-controller returns `BLOCKED` or `NEEDS_USER_INPUT`, `/build-step` surfaces the blocker and outputs `BLOCKED: <reason>` as its final line

### Notes for executor

- The section-controller template prompt (everything between `### Step 3 — Dispatch section-controller subagent` and `### Step 3a` in the current `skills/build/SKILL.md`, including all phase instructions through Phase 6) should move verbatim into `/build-step`. Do not rewrite it — move it.
- The model selection table and rationalization table from `/build` belong in `/build-step` (they govern section execution, not the orchestrator loop).
- The `===RESULT===` block format currently used between section-controller and orchestrator is replaced by the simpler `SECTION_COMPLETE` / `ALL_SECTIONS_COMPLETE` / `BLOCKED: <reason>` interface. The section-controller subagent (dispatched by `/build-step`) still uses `===RESULT===` internally; `/build-step` reads it and translates to the simple output format.

### Completion log

- Commits: 28c8489
- Tests added: 0
- Deviations from plan: none

---

## Section 2: Refactor `/build` to call `/build-step`

**Status:** [ ] not started
**Model:** sonnet
**User stories covered:** 2

### What to build

Slim `skills/build/SKILL.md` down to a thin orchestrator loop. Replace the inline section-controller template with a subagent dispatch that instructs the subagent to invoke `blueprint:build-step`. Read the `SECTION_COMPLETE` / `ALL_SECTIONS_COMPLETE` / `BLOCKED` completion signal. Add a note pointing AFK users to `scripts/afk-build.sh`.

### Acceptance criteria

- [ ] `skills/build/SKILL.md` no longer contains the inline section-controller template (the `---IMPLEMENTER PROMPT START---` / Phase 1–6 block)
- [ ] `/build`'s section dispatch step now reads: dispatch a `sonnet` subagent with prompt "Invoke `blueprint:build-step` to execute the next section. Repo root: `<path>`. PLAN file: `<path>`."
- [ ] `/build`'s orchestrator loop reads the subagent's `SECTION_COMPLETE` / `ALL_SECTIONS_COMPLETE` / `BLOCKED: <reason>` output and acts accordingly (continue / announce completion / surface blocker)
- [ ] Running `/build` on a multi-section PLAN still results in all sections completing in order, with PLAN file updates and commits between each
- [ ] `/build`'s description or overview section mentions `scripts/afk-build.sh` for AFK use
- [ ] The no-subagent fallback section in `/build` is updated to reference `/build-step` for the sequential implementation step

### Notes for executor

- The step numbering in `/build` may shift after removing the section-controller template. Renumber consistently.
- The "Red flags — STOP" list in `/build` should be reviewed: any red flags that now belong in `/build-step` (they govern section execution) should move there. Red flags about the orchestrator loop stay in `/build`.
- The `## Resumption across sessions` section in `/build` is unaffected — keep it.
- Test by running `/build` against the same small test PLAN used to verify `/build-step` in Section 1.

### Completion log

<!-- Executor fills in after section completes -->
- Commits:
- Tests added:
- Deviations from plan:

---

## Section 3: Add `scripts/afk-build.sh`

**Status:** [ ] not started
**Model:** haiku
**User stories covered:** 3, 4

### What to build

Write `scripts/afk-build.sh`, a static executable bash script. It loops `docker sandbox run claude` invocations, each calling `/build-step` in a fresh process. Detects completion by grepping the PLAN file. Announces done or blocked via `/usr/bin/say` and exits with an appropriate code.

### Acceptance criteria

- [ ] `scripts/afk-build.sh` exists and is executable (`chmod +x`)
- [ ] Script exits with a clear error message (exit 1) if `ANTHROPIC_API_KEY` is not set
- [ ] Script exits with a clear error message (exit 1) if `docker` is not found or `docker sandbox` is unavailable
- [ ] Script accepts an optional PLAN file path as `$1`; if omitted, auto-discovers using the same logic as `/build` (single `docs/ai-plans/*-PLAN.md` candidate, else error)
- [ ] Each iteration runs: `docker sandbox run claude . -- --dangerously-skip-permissions --print --output-format stream-json "invoke blueprint:build-step"` with streaming output piped through `jq` to the terminal in real time
- [ ] After each iteration, the script counts `[ ] not started` sections in the PLAN file before and after to detect progress
- [ ] If progress was made and sections remain, the loop continues
- [ ] If no `[ ] not started` sections remain: prints `"Build complete."`, runs `/usr/bin/say "Build complete"`, exits 0
- [ ] If count is unchanged after an iteration (no progress): prints `"Build blocked. Check terminal output above for reason."`, runs `/usr/bin/say "Build blocked"`, exits 1
- [ ] A comment block at the top of the script documents the `ANTHROPIC_API_KEY` prereq and the `docker sandbox` requirement

### Notes for executor

- The `jq` filter for real-time streaming should follow Matt Pocock's pattern: `jq -r --unbuffered 'select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text'`
- The sandbox name should be stable per workspace so subsequent runs reuse the same sandbox rather than creating a new one each time. Use `docker sandbox run claude .` (no explicit name) and let docker sandbox handle naming.
- Use `tee /tmp/afk-build-last.json` to save the last iteration's full JSON output for debugging.

### Completion log

<!-- Executor fills in after section completes -->
- Commits:
- Tests added:
- Deviations from plan:
