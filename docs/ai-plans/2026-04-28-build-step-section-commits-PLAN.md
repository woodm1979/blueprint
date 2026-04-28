# PLAN: build-step Section Progress Commits

> PRD: ./2026-04-28-build-step-section-commits-PRD.md
> Executor: /build
> Created: 2026-04-28  |  Last touched: 2026-04-28

## Architectural decisions

- Three PLAN section statuses: `[ ] not started`, `[-] in progress`, `[x] complete`.
- Pre-section commit message format: `build: begin Section N (<Title>)`.
- Post-section commit message format: `build: complete Section N (<Title>)` (unchanged).
- Crash recovery priority: check `[-] in progress` before `[ ] not started` in all section-selection logic (`/build-step` Step 2, `/build` Step 2, `afk-build.sh` loop guard).
- Version bump required in `plugin.json` and `marketplace.json` before pushing (current: 6.5.0 → target: 6.6.0).

## Conventions

- TDD per section (test → impl → commit)
- Minimum one commit per completed section
- Review checkpoint between sections (spec compliance + code quality)
- Default implementer model: `sonnet`

---

## Section 1: Pre-section commit and in-progress status in /build-step

**Status:** [ ] not started
**Model:** sonnet
**User stories covered:** 1, 2, 3

### What to build

Modify `skills/build-step/SKILL.md`:

1. **Step 2 (select):** Before grepping for `[ ] not started`, first grep for `**Status:** [-] in progress`. If found, that section is selected for resumption — skip the pre-section commit and go straight to section-controller dispatch (Step 3). If not found, proceed with the existing `[ ] not started` grep. If neither matches, output `ALL_SECTIONS_COMPLETE`.

2. **New Step 2a (pre-section commit):** Only reached for `[ ] not started` sections (not during crash recovery). Flip the section's `**Status:** [ ] not started` → `**Status:** [-] in progress`, bump `Last touched:` in the PLAN header, and commit with message `build: begin Section N (<Title>)`.

3. **Step 4 (completion):** Flip `**Status:** [-] in progress` → `**Status:** [x] complete` (not `[ ] not started`).

### Acceptance criteria

- [ ] When `/build-step` starts a `[ ] not started` section, it emits a `build: begin Section N (<Title>)` commit with `**Status:** [-] in progress` before any code work begins.
- [ ] When a section is already `[-] in progress` at scan time, the pre-section commit (Step 2a) is skipped and execution resumes directly at section-controller dispatch.
- [ ] Step 2 checks `[-] in progress` before `[ ] not started`, so an in-progress section takes priority over a fresh one.
- [ ] Step 4 replaces `[-] in progress` with `[x] complete` (the old `[ ] not started` → `[x] complete` wording is gone).

### Notes for executor

- Read `skills/build-step/SKILL.md` end-to-end before editing. The pre-section step should sit logically between Step 2 and Step 3. Renumber or label it Step 2a.
- The pre-section commit must also bump `Last touched:` in the PLAN header.
- Grep literals must match the PLAN format exactly: `**Status:** [ ] not started` and `**Status:** [-] in progress`.

### Completion log

<!-- Executor fills in after section completes -->
- Commits:
- Tests added:
- Deviations from plan:

---

## Section 2: Crash recovery in /build and afk-build.sh

**Status:** [ ] not started
**Model:** haiku
**User stories covered:** 3, 4

### What to build

Modify `skills/build/SKILL.md` and `scripts/afk-build.sh` so that `[-] in progress` sections are treated as incomplete, not absent.

**`skills/build/SKILL.md` Step 2:** Check for `**Status:** [-] in progress` before `**Status:** [ ] not started`. If an in-progress section is found, dispatch it to `/build-step` (which will skip the pre-section commit via crash recovery). If only not-started sections exist, proceed as today. If neither exists, announce "All sections complete."

**`scripts/afk-build.sh`:** Replace `count_not_started()` with `count_incomplete()` that greps for both `[ ] not started` and `[-] in progress`. Update both call sites (`before` and `after` assignments). Update the "blocked" guard so it does not fire while any section is `[-] in progress` — only fire when `after >= before` AND no section is `[-] in progress`.

### Acceptance criteria

- [ ] `/build` Step 2 selects a `[-] in progress` section before any `[ ] not started` section (confirmed by reading the updated skill text).
- [ ] `/build` does not announce "All sections complete" while any section is `[-] in progress`.
- [ ] `afk-build.sh` `count_incomplete()` greps for both `\[ \] not started` and `\[-\] in progress` patterns in the PLAN file.
- [ ] `afk-build.sh` does not exit 0 ("Build complete") while any section is `[ ] not started` or `[-] in progress`.
- [ ] `afk-build.sh` does not exit 1 ("Build blocked") when a `[-] in progress` section exists — it continues the loop to allow resumption.

### Notes for executor

- In `afk-build.sh`, grep patterns must exactly match the PLAN format. Test: `grep -c '\[ \] not started'` and `grep -c '\[-\] in progress'`.
- The "blocked" guard change: add a check for in-progress count before declaring blocked. If `in_progress > 0`, continue the loop even if `after >= before`.
- After completing this section, bump the plugin version: edit `"version"` in `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` from `6.5.0` to `6.6.0`. Include the version bump in your final commit for this section.

### Completion log

<!-- Executor fills in after section completes -->
- Commits:
- Tests added:
- Deviations from plan:
