---
name: build-step
description: Atomic section-execution primitive for the blueprint suite. Discovers the PLAN file, selects the next unstarted section, dispatches the full section-controller → implementer → spec reviewer → quality reviewer subagent chain, updates the PLAN file, and outputs SECTION_COMPLETE, ALL_SECTIONS_COMPLETE, or BLOCKED: <reason>.
---

# /build-step

## Overview

`/build-step` is the atomic section-execution primitive of the blueprint suite. Each invocation:

1. Discovers the PLAN file.
2. Selects the next `[ ] not started` section.
3. Dispatches a **section-controller** subagent that runs the full section lifecycle internally — implementer dispatch, both reviews, optional remediation — and returns a minimal structured result.
4. On approval, updates the PLAN file (status, acceptance criteria boxes, completion log, `Last touched:`) and commits.
5. Outputs exactly one of: `SECTION_COMPLETE`, `ALL_SECTIONS_COMPLETE`, or `BLOCKED: <reason>`.

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

## Step 3 — Dispatch section-controller subagent

Dispatch a **section-controller** subagent (model: `sonnet`) that runs the full section lifecycle internally — implementer dispatch, both reviews, optional remediation — and returns a minimal structured result. Diffs and subagent responses never enter the orchestrator's context.

Construct the section-controller prompt from EXACTLY the template below:

```
You are a section-controller. You will orchestrate the full implementation lifecycle for Section <N>: <Title>. Dispatch an implementer subagent, run spec-compliance and code-quality reviews, handle remediation if needed, and return a structured result to the orchestrator. All workflow detail — diffs, subagent responses — stays in your context, not the orchestrator's.

**CRITICAL: Use the Agent tool directly for every subagent dispatch. Do NOT use Bash, shell scripts, heredocs, or file I/O to construct or pass prompts. Pass the prompt text directly as a string to the Agent tool.**

## Repo root
<absolute-path-to-repo-root>

## Plan file
<absolute-path-to-PLAN.md>

## Architectural decisions (binding — apply to ALL sections)
<verbatim copy of the plan's "## Architectural decisions" block>

## Section <N>: <Title>

### What to build
<verbatim copy>

### Acceptance criteria
<verbatim copy of the checkbox list>

### Notes for executor
<verbatim copy>

---

## Phase 1 — Capture pre-section SHA

Run `git rev-parse HEAD` and store the result as `pre_sha`. Pass this to reviewers so they can scope their diffs.

## Phase 2 — Dispatch implementer subagent

Determine the implementer model from the section's `Model:` field (default `sonnet`).

Dispatch a general-purpose subagent with the implementer's model. Use this prompt (fill in placeholders from the section content above):

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
- **NEEDS_CONTEXT:** Provide missing context and re-dispatch. If the gap is cross-section, return `status: NEEDS_USER_INPUT` with the gap described.
- **BLOCKED:** Context problem → re-dispatch with more context; needs more reasoning → re-dispatch with more capable model; section too large or plan wrong → return `status: BLOCKED`. Never re-dispatch unchanged.

## Phase 3 — Dispatch spec-compliance reviewer (opus)

Dispatch a general-purpose subagent with model `opus`. Use this prompt:

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

## Phase 4 — Dispatch code-quality reviewer (opus)

Only if Phase 3 returned `APPROVED`.

Dispatch a general-purpose subagent with model `opus`. Use this prompt:

---QUALITY REVIEWER PROMPT START---
You are a code-quality reviewer for Section <N>: <Title>. A separate reviewer has already verified spec compliance — focus on craft.

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

## Phase 5 — Remediation (only if a reviewer returns NEEDS FIXES)

Dispatch a fresh general-purpose subagent (same model as implementer). Pass:
- Section title + "What to build" + acceptance criteria + architectural decisions
- `pre_sha` and repo/plan paths
- The specific `NEEDS FIXES` list

Instruction: fix the listed items only; do not introduce changes beyond the list; re-run tests; commit.

Re-dispatch the rejecting reviewer after remediation. If both reviewers eventually `APPROVED`, proceed to Phase 6. If the same reviewer rejects twice, return `status: BLOCKED`.

## Phase 6 — Return structured result

Your final response to the orchestrator MUST consist ONLY of this block. Do not add preamble, explanation, or prose before or after it.

If approved:

===RESULT===
status: APPROVED
section: <N>
title: <Title>
commits: <sha1> <sha2> ...
tests_added: <count>
deviations: <none | one-line description>
concerns: <none | one-line description>
===END===

If blocked or requiring user intervention:

===RESULT===
status: BLOCKED | NEEDS_USER_INPUT
section: <N>
title: <Title>
blocker: <one-line description>
===END===
```

Use the `Agent` tool with `subagent_type: "general-purpose"`, model `sonnet`, and the prompt above.

## Step 3a — Handle section-controller result

Read the `===RESULT===` block from the section-controller's response.

- **APPROVED:** Proceed to Step 4.
- **BLOCKED / NEEDS_USER_INPUT:** Surface the `blocker` line to the user, then output `BLOCKED: <blocker>` as the final line and stop. Do not update the PLAN file.

## Step 4 — Update the plan file

Edit the PLAN file with the Edit tool:

- Flip this section's `**Status:** [ ] not started` → `**Status:** [x] complete`
- Check off every `- [ ]` in the section's acceptance criteria → `- [x]`
- Fill in `### Completion log`:
  - `Commits: <commits from result>`
  - `Tests added: <tests_added from result>`
  - `Deviations from plan: <deviations from result>`
- Bump the `Last touched:` header to today's date

Commit with message `build: complete Section <N> (<Title>)`. No attribution trailers.

## Step 5 — Output completion signal

Output exactly `SECTION_COMPLETE` as the final line and stop.

## Model selection

| Role | Default model | Why |
|---|---|---|
| Section-controller | `sonnet` | Orchestration: dispatches sub-agents, parses structured results. |
| Implementer | from section's `Model:` field; default `sonnet` | Section complexity varies; plan-author picks. |
| Spec-compliance reviewer | `opus` | Rigorous fit-to-spec analysis. |
| Code-quality reviewer | `opus` | Best judgment on craft and subtle pitfalls. |
| Remediation implementer | same as original implementer | Match the section's complexity. |

Use the least powerful model that can handle each role to conserve cost and increase speed — but do not downgrade reviewers below `opus`.

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
