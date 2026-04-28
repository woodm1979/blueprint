# PRD: Brainstorm Escape-Hatch UX

> Status: draft
> Plan: ./2026-04-28-brainstorm-escape-hatch-ux-PLAN.md
> Created: 2026-04-28  |  Last touched: 2026-04-28

## Problem

When a user selects "Let's discuss" during a `/brainstorm` interview question, Claude immediately asks the next structured question without giving the user any opportunity to speak. The escape hatch exists to let the user redirect or explain something that doesn't fit the predefined options — but the post-selection behavior defeats that purpose entirely.

A second escape hatch, "Skip to planning", has been appearing in some brainstorm sessions as an ad-hoc option not defined in the skill spec. Because it is undocumented, its behavior is inconsistent: sometimes present, sometimes absent, with no guaranteed behavior when selected.

The result is a skill that feels unresponsive. Users trying to redirect the conversation find "Let's discuss" does nothing useful, and users wanting to exit the interview early have no reliable path to do so.

## Solution

Formalize both escape hatches in `skills/brainstorm/SKILL.md` with explicit, documented post-selection behavior:

1. **"Let's discuss"** — after selection anywhere in the skill (Step 1 interview questions or Step 3 artifact gate), Claude responds with "What's on your mind?" as plain prose and waits for the user to type freely. Claude does not call `AskUserQuestion` again until after the user has spoken.

2. **"Skip to planning"** — a required option on every Step 1 `AskUserQuestion` call, from question 1 onward. When selected, Claude jumps immediately to Step 2 (decision summary) and then Step 3 (artifact gate), skipping any remaining interview questions.

Additionally, the skill prohibits Claude from inventing options beyond those explicitly defined in the spec. Ad-hoc additions like "Chat about this" are banned by name as a red flag.

## User stories

1. As a user, when I select "Let's discuss" during an interview question, I receive an open prompt ("What's on your mind?") and can type freely before the next question is asked.
2. As a user, I can exit the interview at any time by selecting "Skip to planning", which takes me directly to the decision summary and artifact gate.
3. As a user, I only see options that are explicitly defined in the skill spec — no surprise, redundant, or ad-hoc options appear.

## Architecture & module sketch

- **`skills/brainstorm/SKILL.md`** — sole file modified. Changes touch: UX rules section (add "Skip to planning" requirement, add prohibition on invented options, clarify "Let's discuss" post-selection behavior), Step 1 instructions (add "Skip to planning" to required options, add post-"Let's discuss" behavior), Step 3 artifact gate (add same post-"Let's discuss" behavior), and Red flags list (add invented-option detection).

No other files in the suite require changes.

## Testing approach

- Manual smoke test: invoke `/brainstorm` in a test repo and exercise each escape hatch.
- Key behaviors to verify:
  - "Let's discuss" at a Step 1 question → "What's on your mind?" prompt appears, no immediate follow-up question.
  - "Let's discuss" at the artifact gate → same prompt, then gate re-asks after user speaks.
  - "Skip to planning" at any Step 1 question → decision summary appears, then artifact gate, no more interview questions.
  - No "Chat about this" or other invented options appear in any `AskUserQuestion` call.

## Out of scope

- Changes to `/blueprint`, `/build`, `/tdd`, or `/grill-me` skills.
- Changes to how `AskUserQuestion` renders the built-in "Other" (free-text) option — that is tool behavior outside this skill's control.
- Adding escape hatches to the artifact gate beyond "Let's discuss" (e.g., "Skip to planning" has no meaning there).

## Open questions

- (none)
