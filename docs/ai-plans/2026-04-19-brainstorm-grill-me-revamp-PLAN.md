# PLAN: Brainstorm Grill-Me Revamp

> PRD: ./2026-04-19-brainstorm-grill-me-revamp-PRD.md
> Executor: /build
> Created: 2026-04-19  |  Last touched: 2026-04-19

## Architectural decisions

- Both changes are pure prose edits to SKILL.md files — no code, no tests, no schema.
- Section 1 (brainstorm) must be written before Section 2 (blueprint gap-detection), because the gap-detection logic in blueprint is defined relative to what brainstorm no longer guarantees.
- The grill-me loop replaces the entire Step 1 + Step 2 block in brainstorm. The decision summary and artifact gate (Steps 3–4) are unchanged.
- Blueprint's gap-detection lives in Step 1 (context check), after confirming sufficient context exists. It does not add a new step — it extends the existing one.
- "Standard PRD sections" that blueprint should check for: testing approach, out-of-scope, open questions. Problem and solution framing are always present if there's enough context to proceed at all.

## Conventions

- TDD per section (test → impl → commit)
- Minimum one commit per completed section
- Review checkpoint between sections (spec compliance + code quality)
- Default implementer model: `sonnet`

---

## Section 1: Rewrite brainstorm skill as grill-me loop

**Status:** [x] complete
**Model:** sonnet
**User stories covered:** 1, 2, 3

### What to build

Rewrite `skills/brainstorm/SKILL.md` to replace the mandatory codebase recon step and fixed interview sequence with a grill-me-style relentless Q&A loop. Code exploration is triggered on-demand by specific questions, not upfront. The interview terminates when shared understanding is reached or there are no branches left on the decision tree. `AskUserQuestion` rules are relaxed from mandatory to advisory.

### Acceptance criteria

- [x] The skill contains no mandatory codebase recon step — there is no instruction to dispatch an Explore subagent before asking the user anything.
- [x] The skill instructs Claude to ask one question at a time, provide its recommended answer, and include tradeoffs for non-obvious decisions.
- [x] The skill instructs Claude to explore code (targeted: single file or grep) only when a specific question requires it.
- [x] The skill defines a termination condition: stop when shared understanding is reached or no decision branches remain unresolved.
- [x] The `AskUserQuestion` rule is described as advisory ("use when helpful") rather than mandatory for every discrete choice.
- [x] The decision summary and artifact gate (Steps 3–4 in the original) are preserved unchanged.
- [x] Red flags section is updated to remove references to the old mandatory recon and fixed sequence.

### Notes for executor

- The grill-me skill text is: "Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer. Ask the questions one at a time. If a question can be answered by exploring the codebase, explore the codebase instead."
- Preserve the suite context table, precedence rule, and "When NOT to use" section verbatim.
- The tradeoff-table rule (lead with a table before non-obvious decisions) should be kept — the user confirmed they like tradeoffs.
- UX rule 1 (one question per turn) should be kept as non-negotiable.

### Completion log

- Commits: 78e6a9a
- Tests added: none (prose-only skill file)
- Deviations from plan: Steps 3–4 renumbered to 2–3 (natural consequence of removing old Steps 1–2; content preserved verbatim). Quality reviewer noted suggestions: "decision tree" vs "design tree" inconsistency; removal of "don't propose design in turn 1" guardrail; "pad" colloquialism; compressed `targeted` phrasing — all SUGGESTION-level, none BLOCKING.

---

## Section 2: Add gap-detection to blueprint context check

**Status:** [ ] not started
**Model:** sonnet
**User stories covered:** 4

### What to build

Update Step 1 of `skills/blueprint/SKILL.md` to detect which standard PRD sections were not addressed during the brainstorm conversation, then ask one targeted follow-up question per gap before proceeding to write the PRD. The three sections to check are: testing approach, out-of-scope, and open questions.

### Acceptance criteria

- [ ] Step 1 of the blueprint skill, after confirming sufficient context, explicitly checks whether the brainstorm covered: testing approach, out-of-scope, and open questions.
- [ ] For each missing section, the skill instructs Claude to ask one targeted follow-up question (one at a time) before proceeding.
- [ ] If no sections are missing, blueprint proceeds immediately to Step 2 without asking anything.
- [ ] The existing "insufficient context → stop" logic is preserved unchanged.
- [ ] No new step is added — the gap-detection logic is embedded within the existing Step 1.

### Notes for executor

- "Covered" means the brainstorm conversation contains a substantive answer — not just that the topic was mentioned. Use judgment.
- Ask gap questions one at a time (same one-question-per-turn rule that brainstorm uses).
- Do not ask about problem, solution, or user stories — if those are absent, the "insufficient context" stop condition fires instead.

### Completion log

<!-- Executor fills in after section completes -->
- Commits:
- Tests added:
- Deviations from plan:
