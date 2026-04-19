# PRD: Brainstorm Grill-Me Revamp

> Status: draft
> Plan: ./2026-04-19-brainstorm-grill-me-revamp-PLAN.md
> Created: 2026-04-19  |  Last touched: 2026-04-19

## Problem

The current `/brainstorm` skill is too formulaic. It mandates codebase recon as the very first step — even when the user wants to discuss a problem with no code involved, or when the relevant code is a single file. The fixed interview sequence (problem → solution → user stories → architecture → testing → out-of-scope) creates a form-filling feel rather than a conversation, and the skill doesn't push hard enough: it moves through sections mechanically rather than exhausting each decision branch before moving on.

The result is that users feel like they're being processed, not heard. The skill also does more work than necessary upfront (full recon dispatch) when a targeted grep or file read triggered by a specific question would suffice.

## Solution

Replace the fixed-sequence interview with a grill-me-style relentless Q&A. The new brainstorm:

- Asks one question at a time, provides a recommended answer with tradeoffs for non-obvious decisions, and doesn't move on until the branch is resolved.
- Explores code only when a specific question requires it — targeted (single file, a grep) rather than broad upfront recon.
- Terminates when shared understanding is reached or there are no branches left on the decision tree.
- Relaxes the `AskUserQuestion` rules (use it when helpful, not mandatory for every discrete choice).

Structured completeness (testing approach, out-of-scope, open questions) moves to `/blueprint`, which detects gaps in the brainstorm conversation and asks targeted follow-up questions before writing the PRD.

## User stories

1. As a `/brainstorm` user, I want the interview to feel like a natural conversation so I stay engaged rather than filling out a form.
2. As a `/brainstorm` user, I want code exploration to happen only when a question actually requires it, so I don't wait for a full recon when it's irrelevant.
3. As a `/brainstorm` user, I want the interview to keep probing until every decision branch is resolved, so I arrive at `/blueprint` with genuine shared understanding.
4. As a `/blueprint` user, I want it to detect gaps left by the brainstorm and ask targeted follow-ups before writing, so the PRD is complete without requiring a perfect brainstorm.

## Architecture & module sketch

- **`skills/brainstorm/SKILL.md`** — full rewrite: remove mandatory recon step, replace fixed interview sequence with grill-me loop, update UX rules (relax `AskUserQuestion` mandate), update termination condition, update red flags.
- **`skills/blueprint/SKILL.md`** — targeted update to Step 1 (context check): after confirming sufficient context exists, identify which standard PRD sections (testing approach, out-of-scope, open questions) were not addressed in the brainstorm, and ask one targeted follow-up per gap before proceeding.

## Testing approach

- Manual smoke test: invoke `/brainstorm` on a sample feature and verify no upfront recon fires, the interview questions relentlessly, and it stops only when the decision tree is exhausted.
- Manual smoke test: invoke `/blueprint` after a brainstorm that intentionally omitted testing strategy; verify it surfaces that gap with a targeted question before writing.
- No automated tests — both artifacts are LLM skill files, not code.

## Out of scope

- Auto-invoking `/blueprint` from the brainstorm artifact gate (deferred; user will handle separately).
- Changes to `/build` or `/tdd` skills.
- Changes to the artifact gate options or decision summary format in brainstorm.

## Open questions

- None.
