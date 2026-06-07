# PLAN: Flatten `/build` dispatch nesting (fix socket-failure drops)

> PRD: ./2026-06-06-build-socket-fix-PRD.md
> Executor: /build
> Worktree: /Users/woodnt/Code/src/github.com/woodm1979/blueprint-worktrees/build-socket-fix
> Created: 2026-06-06  |  Last touched: 2026-06-06

## Architectural decisions

- **Orchestration that must outlive a whole section lives in the foreground.** A
  subagent that orchestrates is the long-lived streaming connection that the transport
  layer drops. Foreground tool calls do not drop.
- **`/build-step` is the single section-controller, run in its own foreground.** It
  dispatches the implementer + spec reviewer + quality reviewer + remediation as
  separate, short, single-role `Agent` calls. There is no nested section-controller
  subagent. The longest-lived dispatch is a single implementer.
- **Output-signal contract is invariant.** `/build-step` always ends with exactly one
  of `SECTION_COMPLETE`, `ALL_SECTIONS_COMPLETE`, or `BLOCKED: <reason>` as its final
  line. `scripts/afk-build.sh` greps the PLAN and depends on this contract — it must not
  change.
- **In-session `/build` invokes `/build-step` in the foreground** — no wrapper subagent.
  Foreground orchestration is the default and recommended path, not a fallback.
- **Context hygiene comes from minimal structured returns, not subagent isolation.**
  Reviewers fetch their own diffs (diffs never enter the foreground); the implementer
  returns its existing minimal structured report. The per-section residue left in the
  foreground is small.
- **Drops are reconciled, never blind-retried.** Any child dispatch that returns an
  API/socket error or a non-signal result triggers a `git log`/`status` reconcile
  against the PLAN before any re-dispatch.
- **Skill-prose only.** No transport/timeout/HTTP-client code changes. Reuse the
  existing implementer/reviewer/remediation prompt bodies verbatim where possible.

## Conventions

- TDD per section (test → impl → commit) where testable; these are prose skill files,
  so "test" means the structural/grep verification described in each section.
- Minimum one commit per completed section.
- Review checkpoint between sections (spec compliance + code quality).
- Default implementer model: `sonnet`.

---

## Section 1: Flatten `/build-step` to foreground orchestration

**Status:** [x] complete
**Model:** opus
**User stories covered:** 2, 3

### What to build

Rewrite `skills/build-step/SKILL.md` so its own foreground runs the full section
lifecycle, dispatching the implementer + both reviewers + remediation as separate
single-role `Agent` calls. Remove the section-controller subagent layer entirely. Add a
reconcile/resume rule for dropped child dispatches and a foreground-wait discipline rule
to the implementer prompt. Preserve the exact output-signal contract.

### Acceptance criteria

- [x] `skills/build-step/SKILL.md` contains no dispatch of a "section-controller"
      subagent; grep for `section-controller` finds only prose that describes the
      foreground role, not an `Agent`/subagent dispatch of one.
- [x] The lifecycle phases (capture pre-section SHA, dispatch implementer, handle
      implementer status, dispatch spec-compliance reviewer, dispatch code-quality
      reviewer, remediation) are each described as a separate `Agent` dispatch made by
      `/build-step`'s own foreground.
- [x] The implementer, spec-reviewer, quality-reviewer, and remediation prompt bodies
      are preserved (same review rigor: reviewers fetch their own diff; reviewers run on
      `opus`; implementer model comes from the section's `Model:` field).
- [x] The implementer prompt includes a discipline rule: do not start a build/test in a
      background task and end the turn — run builds/tests in the foreground and wait for
      completion before reporting; poll long builds to completion.
- [x] A reconcile/resume rule is present: any child dispatch returning an API/socket
      error or no structured result triggers `git log --oneline <pre_sha>..HEAD` +
      `git status` reconciliation against the acceptance criteria before any
      re-dispatch; never re-dispatch unchanged or blind-retry.
- [x] `/build-step` still ends with exactly one of `SECTION_COMPLETE`,
      `ALL_SECTIONS_COMPLETE`, or `BLOCKED: <reason>` as its final line, and still
      updates + commits the PLAN file on approval (`build: complete Section <N>`).

### Notes for executor

- Source the prompt bodies from the current file's lines ~83–260 (implementer, spec
  reviewer, quality reviewer, remediation). Reuse verbatim; only move them from inside a
  subagent prompt to being dispatched directly by `/build-step`.
- The current Step 3 ("Dispatch section-controller subagent") is the block being
  replaced — its internal Phase 1–6 become `/build-step`'s own phases.
- This section alone fully fixes the afk/sandcastle runner, since afk runs `/build-step`
  as its process foreground (no wrapper subagent in that path).
- Read the skill from the repo source, never the plugin cache (per CLAUDE.md).
- Verification is structural: grep + read-through against the acceptance criteria above.

### Completion log

- Commits: bfb9894
- Tests added: 0 (prose skill file; verified structurally by reading and grepping)
- Deviations from plan: none

---

## Section 2: Run `/build-step` in foreground from `/build`

**Status:** [ ] not started
**Model:** sonnet
**User stories covered:** 1

### What to build

Update `skills/build/SKILL.md` so the orchestrator invokes `blueprint:build-step`
directly in the foreground instead of dispatching it inside a sonnet wrapper subagent.
Invert the framing so foreground orchestration is the default/recommended path and the
"subagent mode preferred" / "no-subagent fallback" language is removed.

### Acceptance criteria

- [ ] `/build` Step 3 invokes the `blueprint:build-step` skill in the foreground; it no
      longer dispatches a subagent whose only job is to run `/build-step`.
- [ ] The loop control (read signal → verify PLAN updated → continue / stop on
      `BLOCKED` / stop on all-complete) is preserved.
- [ ] The "No-subagent fallback mode" section and any "subagent mode is preferred /
      higher quality" framing are removed or rewritten so foreground orchestration is
      the default; grep for "no-subagent fallback" and "subagent mode" finds no stale
      claims that the wrapper subagent is preferred.
- [ ] The skill notes that implementer + reviewers remain fresh-context subagents (so
      output quality is unaffected — only orchestration bookkeeping moved to the
      foreground), and that for very long PLANs the afk/sandcastle process-per-section
      runners are the answer to foreground context accumulation.

### Notes for executor

- Depends on Section 1 (a flattened `/build-step` must already exist to be invoked in
  the foreground).
- The current wrapper-subagent dispatch is at lines ~82–94; the framing to invert is at
  Overview line ~16, the Model selection table, and the "No-subagent fallback mode"
  section (~163–179).
- Keep the worktree-entry logic (Step 1), PLAN-update verification (Step 4), and
  post-completion steps (6a simplify, 6b future considerations, 6c exit worktree)
  unchanged.

### Completion log

<!-- Executor fills in after section completes -->
- Commits:
- Tests added:
- Deviations from plan:

---

## Section 3: Section-sizing guidance + version bump

**Status:** [ ] not started
**Model:** haiku
**User stories covered:** 4

### What to build

Add an advisory section-sizing note to `skills/blueprint/SKILL.md` Step 5 tying section
size to a bounded implementer dispatch, and bump the plugin version in both manifests.

### Acceptance criteria

- [ ] `skills/blueprint/SKILL.md` Step 5 contains an advisory note: size sections so a
      single implementer finishes in a bounded dispatch (tens of minutes, not hours);
      long single-pass sections are the main source of `/build` socket drops; split them.
- [ ] `.claude-plugin/plugin.json` version is bumped from `6.8.5` to `6.9.0`.
- [ ] `.claude-plugin/marketplace.json` version is bumped from `6.8.5` to `6.9.0`.
- [ ] Both version strings match exactly.

### Notes for executor

- The sizing note belongs next to the existing "If a section feels too big… split it"
  guidance (~line 108).
- Mechanical change — no behavioral logic. Just prose + two version strings.

### Completion log

<!-- Executor fills in after section completes -->
- Commits:
- Tests added:
- Deviations from plan:
