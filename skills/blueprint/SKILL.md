---
name: blueprint
description: Use when you want both a PRD and a PLAN as persistent committed artifacts in docs/ai-plans/. Part of the blueprint suite. Reads prior /brainstorm conversation context; writes PRD.md + PLAN.md. Handles both new features and extensions. Pairs with /build (executor).
---

# /blueprint

## Overview

File-creation skill of the blueprint suite. Reads the current conversation (typically from a prior `/brainstorm` session) and writes two committed artifacts under `docs/ai-plans/`:

- **PRD** — the product requirements document: problem, solution, user stories, architecture sketch, testing approach, out-of-scope, open questions.
- **PLAN** — the implementation plan: architectural decisions + a series of tracer-bullet vertical-slice sections, each with acceptance criteria, implementer-model guidance, and an empty completion log.

After the two files are written, committed, and self-reviewed, hand off to `/build` for section-by-section execution with fresh-context subagents.

This skill handles both new features and extensions to existing PRD+PLAN pairs.

## Suite context

| Skill | Role |
|---|---|
| `/brainstorm` | Intake — structured interview, decision summary, artifact gate |
| `/blueprint` (this skill) | File-creation — writes PRD.md + PLAN.md from brainstorm context |
| `/build` | Executor — runs each section in a fresh subagent with 2-stage review |

## Embedded principles

- **Self-review checklist** — spec coverage, placeholder scan, type consistency (see Step 7).
- **Vertical-slice sections** — each section cuts end-to-end through every layer (schema → API → UI → tests), not horizontal layers.
- **Acceptance-criteria externality** — criteria must be observable from outside the module, not internal implementation details.

## Precedence

If a repo's `CLAUDE.md`, `AGENTS.md`, or explicit user instructions conflict with this skill, user instructions win. Read those files before starting.

## UX rules (non-negotiable)

1. **One question per turn.** Never bundle questions.
2. **Use `AskUserQuestion` for any decision with 2–4 known discrete options.**
3. **Every `AskUserQuestion` call MUST include an option whose `label` is exactly `"Let's discuss"`.**
4. **Lead with a tradeoff table before any non-obvious decision.**

## Process

### Step 1 — Context check

Scan the conversation for brainstorm output: problem statement, solution framing, user stories, architecture sketch, testing approach, out-of-scope, open questions.

If the conversation has insufficient context to write a meaningful PRD — **stop**. Tell the user:

> "There isn't enough context here to write a PRD. Run `/brainstorm` first, then invoke `/blueprint` from that conversation."

Do not continue.

**Gap detection (only reached if context is sufficient).** After confirming there is enough context to proceed, check whether each of the following three sections was substantively addressed in the brainstorm conversation — not merely mentioned, but answered with enough detail to write that PRD section:

1. **Testing approach** — what makes a good test here, key behaviors to cover, patterns to follow.
2. **Out-of-scope** — explicit statements about what is not being built.
3. **Open questions** — unresolved decisions or unknowns that should be tracked.

For each section that is missing (no substantive answer found), ask one targeted follow-up question before proceeding. Ask questions **one at a time** — do not bundle them. Wait for the user's answer before checking the next gap or moving to Step 2.

If all three sections are covered, proceed immediately to Step 2 without asking anything.

### Step 2 — New vs extend detection

Scan `docs/ai-plans/` for existing `*-PRD.md` + `*-PLAN.md` pairs. Does any pair match the feature being discussed?

- **No match** → new path. Continue to Step 3.
- **Match found** → extension path. Load the existing pair. Apply append discipline throughout:
  - Bump `Last touched:` in both files.
  - Append new sections to the PLAN (starting from next available section number).
  - Never fork into new files.
  - Jump to Step 5 (skip Steps 3–4).

### Step 3 — Extract & confirm PRD outline

Derive the PRD outline from the conversation context. Present it to the user for review. Iterate until approved. Keep it tight — problem, solution, user stories, architecture sketch, testing approach, out-of-scope, open questions.

### Step 4 — Write PRD

Derive a slug from the feature name (lowercase, hyphenated, ≤ 5 words). Target path: `docs/ai-plans/<today's-ISO-date>-<slug>-PRD.md`.

**Before writing**, check whether `docs/ai-plans/` appears in any `.gitignore` in the repo (including parent repos). If it does, `AskUserQuestion`:

> Question: "`docs/ai-plans/` is in `.gitignore`. The PRD+PLAN are supposed to be committed artifacts — they're the plan's authoritative state. How should I proceed?"
>
> Options:
> - `Un-ignore — remove the line from .gitignore so these files can be committed` (Recommended)
> - `Write anyway as untracked — you'll handle committing manually`
> - `Let's discuss`

Wait for a decision before writing.

If `docs/ai-plans/` doesn't exist, create it. Write the PRD using the template in **File formats** below.

### Step 5 — Section breakdown (tracer-bullet vertical slices)

Present a proposed list of sections. Each section is one vertical slice that cuts end-to-end through every layer the feature touches (schema → API → UI → tests) — NOT a horizontal layer.

For each section in the proposal, show:

- **Title** — short imperative noun phrase.
- **User stories covered** — which story numbers from the PRD.
- **Suggested `Model:`** — `haiku` if mechanical (1–2 files, clear spec), `sonnet` if integration/judgment, `opus` if architectural. Default when in doubt: `sonnet`.

Iterate with the user until the breakdown is approved. If a section feels too big ("two features smooshed"), split it. If two sections are tiny and trivially related, merge them.

**Writing acceptance criteria — coaching note.** Strong criteria let the executor loop independently. Write criteria that are testable from the outside: observable behaviors, not internal implementation choices. "User can log in with email+password and receives a session cookie" is a criterion. "Uses bcrypt for password hashing" is not. Good criteria survive refactoring; implementation-detail criteria don't.

### Step 6 — Write / update PLAN

**Before writing (new and extension both):** Determine the worktree path.

1. Derive the slug: the middle portion of the PLAN filename between the ISO date and `-PLAN.md`. Example: `2026-04-23-auth-flow-PLAN.md` → `auth-flow`. Sanitize: replace every `/` with `-`.
2. Check whether a branch named `<slug>` already exists (`git branch --list <slug>`). If it does, append `-2`, `-3`, … until a free name is found. This is the **worktree name**.
3. Compute the **worktree path**: `$(dirname "$REPO_ROOT")/$(basename "$REPO_ROOT")-worktrees/<worktree-name>`.
4. Call `AskUserQuestion`:
   > Question: "I'll create a worktree for this feature at `<worktree-path>` (branch `<worktree-name>`). How should I proceed?"
   >
   > Options:
   > - `Proceed — create worktree at the path above`
   > - `Use a different name — I'll provide the branch/directory name`
   > - `Skip worktree — build in the main repo`
   >
   > Wait for the user's choice.
   - **Proceed** → use the computed path.
   - **Use a different name** → ask for the new name, re-sanitize, re-check for branch conflicts, recompute path.
   - **Skip worktree** → omit the `Worktree:` line from the PLAN; skip Step 8.5.

   If the worktree directory already exists on disk, also offer:
   > - `Reuse as-is — enter the existing worktree without recreating it`
   > - `Delete and recreate — remove the directory and create a fresh worktree`
   > - `Abort — stop here`
   >
   > If **Abort**, stop.

**New:** Write to `docs/ai-plans/<today's-ISO-date>-<slug>-PLAN.md` using the template in **File formats** below. Include:

- Header with cross-reference to the PRD and the confirmed `Worktree:` path (omit if skipped).
- `## Architectural decisions` section (distilled from conversation context).
- `## Conventions` section (TDD per section, one commit minimum, 2-stage review, default model `sonnet`).
- One `## Section N: <Title>` block per approved section, each with `Status: [ ] not started`, `Model:` field, "What to build", acceptance criteria checkboxes, notes for executor, empty completion log.

**Extension:** Append new sections starting from next available section number. Bump `Last touched:` in the PLAN header. Re-run the worktree confirmation above; if the PLAN already has a `Worktree:` line, show that path as the default option.

Apply the acceptance-criteria coaching note from Step 5 to every section.

### Step 7 — Self-review pass

This is a checklist YOU run yourself — not a subagent dispatch. Scan both files with fresh eyes:

1. **Spec coverage.** Walk each user story in the PRD. Can you point to a section in PLAN that delivers it? List any gaps; add sections inline if missing.
2. **Placeholder scan.** Any `TBD`, `TODO`, `implement later`, `fill in details`, "add appropriate error handling", "similar to Section N"? Fix them.
3. **Type consistency.** Do module names, route paths, schema shapes referenced in later sections match what you set in earlier sections and in the PRD architecture sketch? Inconsistencies are bugs.
4. **Vertical-slice check.** Is each section demoable on its own, or are you describing horizontal layers (all-schema-first, then all-API, then all-UI)? If horizontal, restructure into verticals.
5. **Model coherence.** Is the `Model:` field appropriate to each section's complexity? An `opus` section that's just "rename a function" or a `haiku` section that's "design a new auth boundary" is a smell.
6. **Acceptance-criteria externality.** Are criteria observable from the outside, or do they bake in internal implementation choices? Rewrite any that aren't externally testable.
7. **(Extension only) Append-not-fork.** Confirm no new files were created when extending.

Fix any issues inline. No need to re-review — just fix and move on.

### Step 8 — Commit

Commit both files in a single commit.

- **New:** `Blueprint: <feature name> (PRD + PLAN)`
- **Extension:** `Blueprint: extend <feature name> (+Section N+1...)`

Do not include attribution trailers.

### Step 8.5 — Create worktree

Call `EnterWorktree name: <worktree-name>` (using the name confirmed in Step 6). This triggers the `WorktreeCreate` hook, which creates the worktree directory, checks out the feature branch, installs dependencies, and symlinks env/config files. Capture the worktree path echoed to stdout by the hook to confirm it matches what was written into the PLAN.

If the user chose **Reuse as-is** in Step 6, call `EnterWorktree path: <worktree-path>` instead.

If `EnterWorktree` is unavailable in the current harness, warn the user:

> "`EnterWorktree` is not available — the worktree has not been created. Run `scripts/worktree-create <worktree-name>` from the repo root to create it manually before running `/build`."

Then skip to Step 9.

### Step 9 — Optional GitHub issue

After the commit, call `AskUserQuestion`:

> Question: "Also create a GitHub issue with the PRD content? (PRD+PLAN are already committed either way.)"
>
> Options:
> - `Yes, create a GitHub issue` — file a GitHub issue using the PRD content as its body.
> - `No, just proceed to build` — default; skip to handoff.
> - `Let's discuss`

If **Yes**, build the issue body from the committed PRD using the template in **File formats → GitHub issue PRD template** below. Use `gh issue create`. Title: the feature name. Report the issue URL back to the user. Then proceed to Step 10.

### Step 10 — Handoff

End with exactly this message (substitute the real file paths):

> **REQUIRED NEXT SKILL:** Run `/build` with the PLAN file below. Each section will run in a fresh subagent with 2-stage review.
>
> Worktree: `<absolute-path-to-worktree>`
>
> ```
> /build docs/ai-plans/<date>-<slug>-PLAN.md
> ```
>
> PRD: `docs/ai-plans/<date>-<slug>-PRD.md`

The fenced block is the exact command the user can copy-paste after a `/clear`. The worktree path line tells the user which directory the build will operate in. The PRD line lets them reference the requirements doc in the new session. Do not invoke `/build` yourself.

## File formats

### PRD template

```markdown
# PRD: <Feature Name>

> Status: draft
> Plan: ./<date>-<slug>-PLAN.md
> Created: <YYYY-MM-DD>  |  Last touched: <YYYY-MM-DD>

## Problem

<1–3 paragraphs, user's perspective, open prose>

## Solution

<1–3 paragraphs, user's perspective, open prose>

## User stories

1. As <actor>, I want <feature>, so <benefit>
2. ...

## Architecture & module sketch

- **Module A** — responsibility, interface
- **Module B** — ...

<Durable decisions only. No file paths. No code.>

## Testing approach

- What makes a good test here
- Key behaviors to cover
- Prior-art references (existing test files, fixtures, patterns to follow)

## Out of scope

- ...

## Open questions

- [ ] <anything unresolved after intake>
```

### PLAN template

```markdown
# PLAN: <Feature Name>

> PRD: ./<date>-<slug>-PRD.md
> Executor: /build
> Worktree: <absolute-path-to-worktree>
> Created: <YYYY-MM-DD>  |  Last touched: <YYYY-MM-DD>

## Architectural decisions

<Durable decisions that apply across sections — routes, schema, key models, auth approach, third-party boundaries. Derived from the PRD's module sketch + any detail added during section breakdown.>

## Conventions

- TDD per section (test → impl → commit)
- Minimum one commit per completed section
- Review checkpoint between sections (spec compliance + code quality)
- Default implementer model: `sonnet`

---

## Section 1: <Title>

**Status:** [ ] not started
**Model:** sonnet
**User stories covered:** 1, 3

### What to build

<1–3 sentences describing the end-to-end vertical slice.>

### Acceptance criteria

- [ ] <testable behavior 1 — externally observable>
- [ ] <testable behavior 2 — externally observable>
- [ ] <testable behavior 3 — externally observable>

### Notes for executor

- <gotchas, pointers to related code, non-obvious constraints>

### Completion log

<!-- Executor fills in after section completes -->
- Commits:
- Tests added:
- Deviations from plan:

---

## Section 2: <Title>

<...same structure...>
```

Use literal backtick-bounded status checkboxes (`[ ]` and `[x]`) — `/build` greps for these to find the next unstarted section.

### GitHub issue PRD template

Used at Step 9. The issue body is derived from the committed PRD and PLAN — do not re-interview the user.

```markdown
## Problem Statement

<From PRD's "## Problem" section>

## Solution

<From PRD's "## Solution" section>

## User Stories

<Numbered list, copied from PRD's "## User stories">

## Implementation Decisions

<Derived from PLAN's "## Architectural decisions" section. Include:>

- The modules that will be built/modified
- The interfaces of those modules
- Architectural decisions
- Schema changes
- API contracts

Do NOT include specific file paths or code snippets.

## Testing Decisions

<From PRD's "## Testing approach">

## Out of Scope

<From PRD's "## Out of scope">

## Further Notes

<Link back to committed PRD+PLAN paths.>
```

## Rationalization table

| Excuse | Reality |
|---|---|
| "This feature is too simple for a full PRD + plan" | Simple features still benefit from a PRD+PLAN — it's 15 minutes of context, not an afternoon. If it's truly trivial, the PRD is short; the format doesn't scale with feature size. |
| "The user wants to move fast, so I'll skip the review" | Moving fast WITH a plan is faster than re-doing work without one. |
| "I'll merge PRD and PLAN into one file" | No. Two files, two purposes. The PRD is the what (stable); the PLAN is the how (evolves per section). `/build` greps PLAN for status. |
| "I'll commit after /build finishes" | Commit AFTER writing PRD+PLAN, BEFORE `/build` runs. The plan is the contract; it must exist in history before execution. |
| "Acceptance criteria about implementation details are fine — they're specific" | Specific ≠ testable. "Uses bcrypt" is specific but not externally observable. If a reviewer can't verify it from outside the module, it's the wrong kind of criterion. |
| "The user already asked for a GitHub issue, I'll skip the PRD+PLAN" | No. PRD+PLAN are always primary and always written. The GitHub issue is additive. |
| "There's no brainstorm context but I can infer enough" | Stop. Tell the user to run `/brainstorm` first. Inferring is not the same as confirmed shared understanding. |

## Red flags — STOP

- Proceeding without sufficient brainstorm context in the conversation
- More than one `?` in a single user-facing message
- `AskUserQuestion` without a `"Let's discuss"` option
- Writing a PRD to a filename other than `docs/ai-plans/<date>-<slug>-PRD.md`
- Writing a PLAN without per-section `Status:` and `Model:` fields
- Horizontal slices (Phase 1 = all schema, Phase 2 = all API) instead of vertical slices
- Acceptance criteria that describe internal implementation choices instead of externally observable behaviors
- Skipping the self-review pass
- Skipping the commit
- Filing a GitHub issue BEFORE committing PRD+PLAN
- Handoff message that doesn't say `/build`
- Creating new files when extending (append-not-fork)

## When NOT to use

- User wants to explore a problem first → use `/brainstorm` then come back.
- Task is a one-line bugfix or chore → just fix it.
- User wants to execute an existing PLAN → use `/build`.
