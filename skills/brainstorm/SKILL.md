---
name: brainstorm
description: Open-ended exploration and Q&A about a feature or problem. No artifacts produced. Primary entry point for the blueprint suite — leads into /blueprint for committed artifacts.
---

# /brainstorm

## Overview

Primary intake skill of the blueprint suite. Interviews the user through a relentless Q&A loop, reaches shared understanding, then asks what to do with it. Produces no artifacts itself — artifacts come from `/blueprint`.

## Suite context

| Skill | Role |
|---|---|
| `/brainstorm` (this skill) | Intake — structured interview, decision summary, artifact gate |
| `/blueprint` | File-creation — writes PRD.md + PLAN.md from brainstorm context |
| `/build` | Executor — runs each section in a fresh subagent with 2-stage review |

## Plan-mode compatibility

This skill is compatible with Claude Code's plan mode. Steps 1–3 use only `AskUserQuestion` (permitted in plan mode) and produce no files or commits.

**Critical sequencing:** Do NOT call `ExitPlanMode` until after Step 3 (Artifact gate) `AskUserQuestion` has been answered. The artifact gate is the final required question of this skill — treating the end of Step 2 as "done planning" and calling `ExitPlanMode` early is a bug.

After the artifact gate is answered:
- If **Write new PRD + PLAN** or **Extend**: tell the user "Run `/blueprint` now — it will read this conversation and write the plan files." Then call `ExitPlanMode`.
- If **No files**: call `ExitPlanMode` immediately.
- If **Let's discuss**: ask "What's on your mind?" and wait for the user's reply, then re-ask the artifact gate before calling `ExitPlanMode`.

## UX rules (non-negotiable)

These rules apply to EVERY user-facing message during intake. Violating any of them means the skill has been violated.

1. **One question per turn.** If a topic needs multiple questions, split them into multiple turns. Never bundle.
2. **Use `AskUserQuestion` when helpful for decisions with 2–4 known discrete options.** It is an advisory tool — not required for every choice. Never hand-roll a numbered list of choices in prose when `AskUserQuestion` would fit better.
3. **Every `AskUserQuestion` call MUST include an option whose `label` is exactly `"Let's discuss"`.** This is the escape hatch when the primary options don't fit. The label is literal — not "Something else", not "Other", not "None of these". Exactly `"Let's discuss"`.
4. **When "Let's discuss" is selected, respond with "What's on your mind?" as plain prose and wait for the user to type freely. Do NOT call `AskUserQuestion` again until after the user has responded.**
5. **Lead with a tradeoff table before any non-obvious decision.** A decision is "non-obvious" if a competent engineer could reasonably pick more than one option. The table precedes the `AskUserQuestion` call and uses the format:

   | Option | Pro | Con | When it fits |
   |---|---|---|---|

   Heuristic: **if you can write the table in under a minute, write it.** The only legitimate reason to skip is when one option is clearly dominant (and in that case, just make the decision and move on — don't ask).

6. **Use open prose (not multiple-choice) for problem framing and user stories.** These are exploratory by nature; structure emerges from dialogue.

### Red flags — STOP and restart the message

- About to send a message with 2+ question marks in it → split.
- About to send a numbered list of A/B/C options in prose → switch to `AskUserQuestion`.
- About to send an `AskUserQuestion` call without a `"Let's discuss"` option → add it.
- About to call `AskUserQuestion` immediately after a "Let's discuss" selection without first asking an open question → stop.
- About to announce a design before asking the user anything → back up.

## Process

### Step 1 — Grill-me loop

Interview the user relentlessly about every aspect of the feature or problem until shared understanding is reached. Walk down each branch of the decision tree, resolving dependencies between decisions one-by-one.

**For each question:**
- Provide your recommended answer with brief reasoning.
- If the decision is non-obvious, lead with a tradeoff table (per UX rule 5) before asking.
- If answering the question requires codebase knowledge, explore the codebase first (targeted: single file or `grep`) — then ask. Do not do a broad upfront recon pass; explore only when a specific question demands it.
- If the user selects **"Let's discuss"**, respond with "What's on your mind?" as plain prose and wait for their reply before calling `AskUserQuestion` again.

**Termination condition:** Stop asking questions when shared understanding is reached — that is, when all significant decision branches on the design tree have been resolved and no unresolved dependencies remain. Do not pad the interview with questions whose answers are already clear from context.

### Step 2 — Decision summary

Give a 3–5 bullet summary of the key decisions reached during the interview. Keep it tight — one line per decision.

### Step 3 — Artifact gate

Call `AskUserQuestion`:

> Question: "What should we do with this?"
>
> Options:
> - `Write new PRD + PLAN` — Invoke `/blueprint` to write fresh `docs/ai-plans/<date>-<slug>-PRD.md` + `PLAN.md` from this conversation.
> - `Extend existing PRD + PLAN` — Invoke `/blueprint`; it will detect the matching pair and append new sections.
> - `No files — end here` — The summary above is the output. Nothing is written or committed.
> - `Let's discuss` — Ask an open question, hear the user out, then re-ask.

If the user chooses **Write new PRD + PLAN** or **Extend existing PRD + PLAN**, tell the user: "Run `/blueprint` now — it will read this conversation's context and handle writing or extending the plan files."

If **No files — end here**, end cleanly. The decision summary is the output.

If **Let's discuss**, respond with "What's on your mind?" as plain prose and wait for the user to reply. Do NOT call `AskUserQuestion` again until after the user has responded. Then call `AskUserQuestion` again with the same four options.

## Precedence

If a repo's `CLAUDE.md`, `AGENTS.md`, or explicit user instructions conflict with this skill, user instructions win. Read those files before starting the interview.

## Red flags — STOP

- More than one `?` in a single user-facing message
- Inline numbered options instead of `AskUserQuestion`
- `AskUserQuestion` without a `"Let's discuss"` option
- Architecture decision asked without a preceding 2-3-approach tradeoff table
- Broad codebase recon before asking the user anything
- Writing any file, making any commit, or creating any GitHub issue

## When NOT to use

- User wants to skip interview and write plan files directly → use `/blueprint` with the feature described inline.
- Task is a one-line bugfix or chore → just fix it.
- User wants to execute an existing PLAN file → use `/build`.
