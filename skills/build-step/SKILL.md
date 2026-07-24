---
name: build-step
description: Execute one PLAN section via subagent chain. Outputs SECTION_COMPLETE or BLOCKED.
---

# /build-step

## Overview

`/build-step` is the atomic section-execution primitive of the blueprint suite. Each invocation:

1. Discovers the PLAN file.
2. Selects the next `[ ] not started` section.
3. Runs the full section lifecycle in the foreground — captures pre-section SHA, dispatches implementer, dispatches both reviewers (spec-compliance + code-quality) in parallel, handles remediation if needed.
4. On approval, updates the PLAN file (status, acceptance criteria boxes, completion log, `Last touched:`) and commits.
5. Outputs exactly one of: `SECTION_COMPLETE`, `ALL_SECTIONS_COMPLETE`, or `BLOCKED: <reason>`.

There is no nested section-controller subagent. `/build-step`'s own foreground is the section controller. The longest-lived child dispatch is a single implementer.

This is the interface consumed by `/build`'s orchestrator and by `scripts/afk-build.sh`.

## Step 1 — Locate and read the PLAN file

In order:

1. If the user `@`-referenced a `-PLAN.md` path, use it.
2. If there's exactly one `docs/ai-plans/*-PLAN.md`, use it.
3. If multiple candidates, `AskUserQuestion` with each + `"Let's discuss"`.
4. If none, tell the user to run `/blueprint` first.

Read the PLAN file end-to-end. Extract:

- The `## Architectural decisions` block (verbatim).
- Every `## Section N:` block.

## Step 2 — Select the next unstarted section

Grep the PLAN file for `**Status:** [ ] not started` (literal). The first match's section is the one to run.

If no match: output exactly `ALL_SECTIONS_COMPLETE` and stop.

## Phase 1 — Capture pre-section SHA

Run `git rev-parse HEAD` and store the result as `pre_sha`. Pass this to reviewers so they can scope their diffs.

## Phase 2 — Dispatch implementer subagent

Determine the implementer model from the section's `Model:` field (default `sonnet`).

Dispatch a general-purpose subagent with the implementer's model. Use this prompt (fill in placeholders from the section content):

---IMPLEMENTER PROMPT START---
You are implementing Section <N>: <Title> of a feature plan.

## Repo root
<absolute-path-to-repo-root>

## Plan file
<absolute-path-to-PLAN.md>

## Architectural decisions (binding — apply to ALL sections of this plan)
<verbatim architectural decisions>

## Section <N>: <Title>

### What to build
<verbatim>

### Acceptance criteria
<verbatim checkbox list>

### Notes for executor
<verbatim>

## Before you begin

If you have questions about requirements, acceptance criteria, approach, or anything unclear — ask them now, before starting work. It is always OK to pause and clarify. Don't guess or make assumptions.

## TDD protocol

Before writing any code, invoke the Skill tool with skill name `blueprint:tdd` to load the full TDD iron-law protocol.

## Discipline

- Follow TDD per `blueprint:tdd`: test first, watch it fail, minimal code to green, commit.
- Produce at least one commit when the section is done. Multiple commits are fine.
- Before finishing, re-read this section's acceptance criteria and verify each one is satisfied.
- Focus on Section <N>. You MAY read the plan file for context (prior sections' completion logs and deviations are useful). You MAY grep the shipped codebase freely — that's the ground truth for interfaces earlier sections built.
- Do NOT pre-build anything for sections that haven't started. Implementing them now is YAGNI. Add only what this section's acceptance criteria require.
- If the plan is ambiguous or a decision isn't captured in the Architectural decisions block, stop and report back — do NOT fill the gap on your own.
- **Foreground-wait discipline:** Do not start a build or test run in a background task and end the turn. Run all builds and tests in the foreground and wait for completion before reporting. If a build or test is long-running, poll it to completion — do not hand it off to the background.

## Code organization

- Follow the file structure defined in the plan.
- Each file should have one clear responsibility.
- If a file you're creating is growing beyond the plan's intent, stop and report DONE_WITH_CONCERNS.
- In existing codebases, follow established patterns visible in the surrounding code.

## When you're in over your head

STOP and escalate when:
- The section requires architectural decisions with multiple valid approaches not resolved by the plan.
- You need to understand code beyond what was provided and can't find clarity.
- You feel genuinely uncertain about whether your approach is correct.
- You've been reading file after file without making progress.

## Before reporting back: self-review

- **Completeness:** Did I satisfy every acceptance criterion? Any edge cases missed?
- **Quality:** Is this my best work? Are names clear? Is code clean?
- **Discipline:** Did I avoid over-building? Did I stay inside this section's scope?
- **Testing:** Do tests verify real behavior (not mock theater)? Did I follow TDD?

Fix issues now before reporting.

## Report back

1. **Status:** `DONE` | `DONE_WITH_CONCERNS` | `BLOCKED` | `NEEDS_CONTEXT`
2. Files created or modified (absolute paths)
3. Commit SHA(s)
4. Test count and whether the project's test runner passes
5. Any deviations from the spec and why
6. Any concerns or specific blocker
---IMPLEMENTER PROMPT END---

## Phase 2a — Handle implementer status

- **DONE:** Proceed to Phase 3.
- **DONE_WITH_CONCERNS:** Read the concerns. Address correctness/scope concerns before review; note observation-only concerns for the final result. Proceed to Phase 3.
- **NEEDS_CONTEXT:** Provide missing context and re-dispatch. If the gap is cross-section, surface it to the user and stop with `BLOCKED: <gap description>`.
- **BLOCKED:** Context problem → re-dispatch with more context; needs more reasoning → re-dispatch with more capable model; section too large or plan wrong → stop with `BLOCKED: <reason>`. Never re-dispatch unchanged.
- **API/socket error or no structured result:** Reconcile before any re-dispatch — run `git log --oneline <pre_sha>..HEAD` and `git status`, compare against the acceptance criteria, determine what was actually completed, then re-dispatch only the remaining work. Never blind-retry an unchanged prompt.

## Phase 3 — Dispatch both reviewers in parallel (opus)

Dispatch **both** reviewer subagents below — spec-compliance and code-quality — in a **single message with two tool calls** so they run concurrently. Both are general-purpose subagents with model `opus`. Do not gate one behind the other; do not run them in sequence.

Collect both results before proceeding to Phase 4.

### Reviewer 1 — spec-compliance

Use this prompt:

---SPEC REVIEWER PROMPT START---
You are a spec-compliance reviewer for Section <N>: <Title>. Flag only deviations from the spec — do NOT suggest improvements beyond it.

## Repo root
<absolute-path>

## Pre-section SHA: <pre_sha>

Fetch the diff yourself before reviewing:
  git log --oneline <pre_sha>..HEAD
  git diff <pre_sha>..HEAD

Read the actual diff. Do not rely on any summary of changes.

## Section <N>: <Title>

### What to build
<verbatim>

### Acceptance criteria
<verbatim>

## Architectural decisions (binding)
<verbatim>

## What the implementer claims they built
<from implementer's report>

## CRITICAL: do not trust the report

Verify by reading the actual diff you fetched. Do not trust the implementer's claims about completeness or correctness.

DO:
- Read the actual code (use the diff you fetched above)
- Compare actual implementation to acceptance criteria line by line
- Check for missing pieces they claimed to implement
- Look for unrequested extras

## Output

For each acceptance criterion, state PASS or FAIL with a one-line justification (cite file:line where useful). Also flag: any EXTRA behavior not requested (over-building), any binding architectural decision violated.

End with exactly one of:
- `APPROVED`
- `NEEDS FIXES` followed by a numbered list of fixes
---SPEC REVIEWER PROMPT END---

### Reviewer 2 — code-quality

Dispatched in the same message as Reviewer 1 (above) — the two run in parallel. Use this prompt:

---QUALITY REVIEWER PROMPT START---
You are a code-quality reviewer for Section <N>: <Title>. A separate reviewer is checking spec compliance in parallel — focus on craft here; don't re-audit spec fit.

## Repo root
<absolute-path>

## Pre-section SHA: <pre_sha>

Fetch the diff yourself:
  git diff <pre_sha>..HEAD

## What to assess

- Is the code idiomatic for the language/framework it's in?
- Are tests meaningful (not mock-verification theater)?
- Any obvious security, concurrency, or correctness pitfalls?
- Is the code appropriately sized for the scope (not under- or over-engineered)?
- Does it follow project conventions visible in the surrounding codebase?
- Does each new file have one clear responsibility with a well-defined interface?
- Did this change create files that are already large, or grow existing files significantly? (Don't flag pre-existing size — focus on what this change contributed.)

## Output

Bullet list of findings. Tag each BLOCKING or SUGGESTION. If none: "No issues found."

End with exactly one of:
- `APPROVED`
- `NEEDS FIXES` followed by a numbered list of BLOCKING fixes
---QUALITY REVIEWER PROMPT END---

## Phase 4 — Remediation (only if a reviewer returns NEEDS FIXES)

If either reviewer returns `NEEDS FIXES`, dispatch a fresh general-purpose subagent (same model as implementer). Pass:
- Section title + "What to build" + acceptance criteria + architectural decisions
- `pre_sha` and repo/plan paths
- The **merged** `NEEDS FIXES` list from both reviewers (dedupe overlapping items)

Instruction: fix the listed items only; do not introduce changes beyond the list; re-run tests; commit.

After remediation, re-dispatch **only the reviewer(s) that returned `NEEDS FIXES`** — in parallel if both did. If both reviewers eventually `APPROVED`, proceed to Phase 5. If the same reviewer rejects twice, stop with `BLOCKED: <reviewer rejection summary>`.

## Phase 5 — Handle approval result

When both reviewers return `APPROVED`, record:
- All commit SHAs since `pre_sha` (from `git log --oneline <pre_sha>..HEAD`)
- Test count from implementer's report
- Any deviations or concerns noted

Proceed to Step 4.

## Step 4 — Update the plan file and DDR

Edit the PLAN file with the Edit tool:

- Flip this section's `**Status:** [ ] not started` → `**Status:** [x] complete`
- Check off every `- [ ]` in the section's acceptance criteria → `- [x]`
- Fill in `### Completion log`:
  - `Commits: <commits from result>`
  - `Tests added: <tests_added from result>`
  - `Deviations from plan: <deviations from result>`
- Bump the `Last touched:` header to today's date

### Append to the DDR

This DDR maintenance is done by **you, the `/build-step` foreground controller** — never the implementer subagent. It happens here, in the same phase where you update the PLAN completion log, using the results the subagents reported.

Derive the DDR path from the PLAN path: replace the trailing `-PLAN.md` with `-DDR.md` in the same `docs/ai-plans/` directory (e.g. `2026-07-23-auth-flow-PLAN.md` → `2026-07-23-auth-flow-DDR.md`). If that file is absent, blueprint seeded no DDR — skip the DDR edits and the `Refs:` line silently.

Make two edits to the DDR with the Edit tool:

1. **Fill `Touches:` on the entries this section landed.** For every existing DDR entry whose decision this section implemented, replace its seeded placeholder `**Touches:** —` with the concrete files/functions the section produced (e.g. `**Touches:** skills/build-step/SKILL.md Step 4; tests/ddr-build-step.sh`). This is the build-time half of the `**Touches:**` field, which blueprint seeded as `—`.

2. **Append a new entry only for a genuine mid-build fork.** Apply the *same non-obvious forks only threshold and signal-to-noise gates as seed-time*: append a new `### DDR-N: <title> · <contention indicator> · <door-type> · <tension-type>` entry (continuing the feature's `DDR-1..N` numbering) only when the section surfaced a genuinely new fork, recorded dissent, or **superseded** a prior decision. On a supersession, also flip the superseded entry's `**Status:**` to `superseded by DDR-N`. Set the new entry's `**Status:** accepted`, and fill `**Decision:**`, `**Tension:**`, `**Rejected:**`, `**If-flipped:**` (falsifiable, or the entry is cut) and `**Touches:**`, then re-rank the progressive-disclosure header. Keep routine deviations out: the ordinary "implemented X a little differently than planned" is **not** a fork — those stay in the PLAN completion log's `Deviations from plan:` line and never graduate to the DDR.

Commit with message `build: complete Section <N> (<Title>)`, adding a `Refs: DDR-N` line naming the entries this section touched or added (comma-separate multiple, e.g. `Refs: DDR-2, DDR-5`):

```
build: complete Section <N> (<Title>)

Refs: DDR-2, DDR-5
```

Omit the `Refs:` line only when the DDR file is absent or the section touched no entries. No attribution trailers.

## Step 5 — Output completion signal

Output exactly `SECTION_COMPLETE` as the final line and stop.

## Model selection

| Role | Default model | Why |
|---|---|---|
| Implementer | from section's `Model:` field; default `sonnet` | Set per the Model selection rules in `/blueprint`; this skill reads the field, never re-decides. |
| Spec-compliance reviewer | `opus` | Rigorous fit-to-spec analysis. |
| Code-quality reviewer | `opus` | Best judgment on craft and subtle pitfalls. |
| Remediation implementer | same as original implementer | Match the section's complexity. |

Reviewers are always `opus` — never downgrade them. The implementer model is fixed at plan time per the Model selection rules in `/blueprint` (default `sonnet`, tie-break upward); this skill does not second-guess or downgrade it to save cost.

## Rationalization table

| Excuse | Reality |
|---|---|
| "Section 4 will need a `Foo.with_bar/2` helper — might as well add it now in Section 2" | That's YAGNI. Implement Section 2's acceptance criteria; stop there. Section 4 gets built when it's Section 4's turn. |
| "The reviewer is just going to approve — I'll skip the dispatch" | Skipping reviewers means skipping the only checkpoint that catches drift. Every section gets both reviewers. |
| "Using opus for reviewers is expensive; sonnet is close enough" | Reviewer quality determines whether the shipped code is trustworthy. Spend the opus tokens. |
| "The implementer asked a question the plan doesn't answer — I'll just answer it inline" | If the answer should apply to future sections too, the PLAN has a gap. Stop, update the plan, commit, re-dispatch. If the answer is current-section-local, answering inline is fine. |
| "Let me batch sections into one subagent to save dispatches" | Sections get review checkpoints individually. One subagent per section is the discipline — not for isolation, but so each gets reviewed before the next begins. |
| "The user said 'run sections 2 and 3' — I'll skip picking next-unstarted and just go by that" | Grep for `[ ] not started` anyway. The user may have misremembered; the plan file is authoritative. |
| "I'll mark the section complete even though the quality reviewer had suggestions" | Only BLOCKING findings block completion. SUGGESTION findings can be noted in the Completion log's "Deviations" line — they don't prevent approval. |
| "The plan is ambiguous on a decision — I'll have the implementer just pick something" | No. The plan is the contract; ambiguity means the contract is incomplete. Pause, clarify with the user, edit the plan, commit, then dispatch. |
| "The implementer reported DONE — the spec reviewer can skim the report instead of reading code" | No. The reviewer verifies by reading code, not by trusting the report. Optimistic reports are a known failure mode. |
| "The implementer returned BLOCKED — I'll just re-dispatch with the same prompt" | Something needs to change. More context, a more capable model, or a smaller scope. Re-dispatching unchanged is just burning tokens. |
| "The child dispatch returned a socket error — I'll just retry the same call" | Never blind-retry. Run `git log --oneline <pre_sha>..HEAD` + `git status` first. Determine what was actually done, then re-dispatch only the remaining work. |
