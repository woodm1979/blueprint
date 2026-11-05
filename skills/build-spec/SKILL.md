---
name: build-spec
description: "Build a spec's tickets on one integration branch, verifying and reviewing each slice before it merges. Blueprint's variant of mattpocock-skills' implement-spec."
disable-model-invocation: true
---

# /build-spec

You have been given a spec: an issue whose child tickets (from `/to-tickets`) say how to build it. Build the whole spec on one **integration branch**, with each ticket resolved the way the issue tracker closes work.

This is Pocock's `implement-spec` with one change: **no slice merges until you have verified it yourself and a spec reviewer and a quality reviewer have approved it.** Errors caught per slice don't compound into later slices.

The issue tracker is described in `docs/agents/issue-tracker.md`. If it's missing, tell the user to run `/setup-matt-pocock-skills` and stop.

## Terms

- **Ticket ref**: how the tracker names a ticket or spec: `#123` on GitHub/GitLab, the file path on a local-markdown tracker. Use refs wherever this skill says "ticket" or "spec" in a prompt.
- **Ticket graph**: the tickets and their blocking links. A ticket is **unblocked** once every blocker has merged into the integration branch. The **frontier** is every unmerged, unblocked ticket.
- **Slice**: one ticket's work, on its own branch in its own worktree.
- **Base SHA**: the integration-branch commit a slice is rebased onto. The slice's diff is always `<base>..<slice-branch>`.
- **Context pointers**: ticket refs, the base SHA, branch names and worktree paths. Pass these to subagents instead of pasting content they can fetch, and never pass the session history or another agent's narrative.

## Step 1: Read the ticket graph

Read the spec and every child ticket, with comments, through the tracker doc. Record each ticket's blockers. Work out the frontier.

Find the repo's test command (CLAUDE.md, AGENTS.md, README, CI config). If there's none you can trust, ask the user once.

Find how the repo creates worktrees. If its docs name a script for it, use that script for every worktree below; otherwise use `git worktree add` in a sibling directory of the repo.

### Check the ticket set

Before any worktree or implementer exists, check the tickets as a set. Read-only: edit no ticket, spec or file. Look for:

- **Blocking cycle**: follow the blocking links; any loop (A blocks B blocks A, or longer) is a blocking cycle that can never become unblocked.
- **Gap**: a spec user story that no ticket's acceptance criteria cover.
- **Conflict**: two tickets that require incompatible things, or that both own the same change.

If you find any, stop the run and report them: for a cycle, name the cycle (`#A -> #B -> #A`); for a gap, quote the uncovered user story; for a conflict, name both tickets and what clashes. Start no worktree or subagent. If the set is clean, proceed without prompting.

## Step 2: (optional) Explore

If the tickets need codebase or external exploration, run one exploration subagent first. It saves markdown notes to a directory outside the repo; pass that path to every later subagent.

## Step 3: Create the integration branch

Branch from the repo's default branch, named after the spec, and check it out in **its own worktree**. Do all merges there. Never switch the user's checkout.

If the tracker closes work through PRs/MRs, open a **draft** after the first slice merges (a branch with no commits ahead can't open one), marked as closing the spec and its tickets.

## Step 4: Run each frontier ticket through the slice loop

Run slices concurrently: one per frontier ticket, each implementer dispatched in the background (inside, it runs its own commands in the foreground). Within a slice, the phases run in order and each waits for the one before. When a slice merges, recompute the frontier and start the newly unblocked tickets.

Never skip a phase, and never merge a slice that hasn't passed phases B and C on its current base.

### A. Implement

Create the slice's worktree on a new branch off the integration-branch tip; record that tip as the base SHA. Dispatch a fresh implementer subagent (model `sonnet` unless the ticket needs more) with this prompt:

---IMPLEMENTER PROMPT START---
Implement ticket <ticket ref> of spec <spec ref>. Read both through the issue tracker described in `<repo>/docs/agents/issue-tracker.md`; the ticket's acceptance criteria are your contract.

Worktree: <absolute path>. Branch: <slice-branch>. Base SHA: <base>. Integration branch: <integration-branch>. Exploration notes: <path or "none">.
<Only when sent back: "This slice was sent back. Fix this, then re-check every acceptance criterion:" followed by the findings or failing output, verbatim.>

- Confirm `git merge-base HEAD <integration-branch>` is <base> before starting.
- Call the Skill tool with `mattpocock-skills:tdd` to build the ticket test-first. Where it says to confirm something with the user, decide yourself and list the decision in your report; nobody is there to ask.
- Build only this ticket. If the ticket is ambiguous about **what** to build, stop and report; don't guess.
- When fixing review findings, follow the `receiving-code-review` rules: check each one against the code first. If a finding is wrong, report it instead of fixing it; if it is unclear, ask about unclear findings (report them as a question) before fixing. Fix only the listed items.
- A defect you find in code this slice didn't write (a bug, dead code, an incorrect comment) is fixed only if the fix is obvious, and then in its own commit, separate from the slice's feature commits; list it in your report under "Found along the way". Anything less obvious goes in the report as a concern.
- Run builds and tests in the foreground to completion.
- Commit your work on <slice-branch>. Don't merge anything into any other branch.

Report: status (`DONE` | `DONE_WITH_CONCERNS` | `BLOCKED` | `NEEDS_CONTEXT`), commit SHAs, the test command you ran and its result, decisions you made yourself, and any concerns.
---IMPLEMENTER PROMPT END---

On `NEEDS_CONTEXT` or `BLOCKED`, change something before re-dispatching: add context, use a stronger model, or stop and ask the user. Never re-dispatch an unchanged prompt. If the subagent dies without a report, check `git log <base>..<slice-branch>` and `git status` in the worktree first, then dispatch only the remaining work.

### B. Verify the slice yourself

Don't trust the implementer's report. In the slice's worktree:

1. `git log --oneline <base>..<slice-branch>`: at least one commit, and a clean worktree.
2. `git diff --stat <base>..<slice-branch>`, then read the diff: it stays inside this ticket's scope. A missing acceptance criterion you notice here is not a phase B failure; note it for phase C.
3. Run the test command yourself, fresh. It must pass.

If check 1 or 3 fails, or the diff strays into another ticket, send the slice back: a fresh implementer with the phase A prompt plus what you saw (the failing test output, verbatim). After two send-backs from phase B, stop the slice (see **Stopping a slice**).

Phase B only proves the tests pass. Whether they can fail is phase C's job.

### C. Spec and quality review

Dispatch a fresh spec reviewer and a fresh quality reviewer (both model `opus`) every time, in a single message so they run in parallel, with context pointers only. Neither waits for the other. Spec reviewer first:

---SPEC REVIEWER PROMPT START---
You are a spec reviewer for ticket <ticket ref> of spec <spec ref>. Read both through the issue tracker described in `<repo>/docs/agents/issue-tracker.md`.

Worktree: <absolute path>. Review exactly this range: `git diff <base>..<slice-branch>`. Read the actual code; you have no implementer report to trust.

Flag only deviations from the ticket, the spec and the repo's binding decisions. Don't suggest improvements beyond them.

1. For each acceptance criterion: PASS or FAIL, with one line of evidence (`file:line`, or the test that shows it). A criterion backed by a test passes only if that test can fail: break the code it covers, in your head or in a scratch copy, and check the suite would go red.
2. Anything the slice built that the ticket didn't ask for.
3. Anything that contradicts the spec's Implementation Decisions.
4. Binding decisions. Read `<repo>/docs/agents/domain.md` and follow it to wherever this repo keeps its binding decisions; use no other location. A binding decision is one the repo records as binding. A change that contradicts a binding decision is a blocking finding that cites the decision (its file and heading or line); never suggest working around it. A descriptive record (a decision recorded in another ticket or spec, or an MR's Deliberate section) is not a finding, even if the change goes against it. If the doc names no binding decisions, say so and move on.
<Only on a re-review: "Findings from the previous review, now claimed fixed:" followed by that list. Mark each FIXED or STILL OPEN.>

End with exactly one of:
- `APPROVED`
- `NEEDS FIXES`, then a numbered list of the fixes.
---SPEC REVIEWER PROMPT END---

Quality reviewer, dispatched alongside it:

---QUALITY REVIEWER PROMPT START---
You are a quality reviewer for ticket <ticket ref> of spec <spec ref>. A separate reviewer is checking spec fit in parallel; don't re-audit it. Read the ticket through the issue tracker described in `<repo>/docs/agents/issue-tracker.md` for context.

Worktree: <absolute path>. Review exactly this range: `git diff <base>..<slice-branch>`. Read the actual code; you have no implementer report to trust.

Tag every finding with a class and a confidence:

- **BUG** (anywhere in the diff, and in code the diff touches or passes): correctness, security and concurrency defects; tests that can't fail; dead code; incorrect comments. Dead code and incorrect comments are bugs.
- **TASTE** (idiom, naming, wording, sizing, convention): raise only on lines the slice wrote, i.e. added lines in the diff. Never raise taste on code or comments the slice only passed, however awkward.
- **HIGH-CONFIDENCE** means you can point to the line and say what goes wrong. Anything you are unsure of is **LOW-CONFIDENCE**.

Only high-confidence BUG findings, high-confidence TASTE findings on lines the slice wrote, and contradictions of a binding decision (below) are blocking. Report low-confidence findings too, tagged LOW-CONFIDENCE; they do not block.

Binding decisions: read `<repo>/docs/agents/domain.md` and follow it to wherever this repo keeps its binding decisions; use no other location. A binding decision is one the repo records as binding. A change that contradicts a binding decision is a blocking finding that cites the decision (its file and heading or line); never suggest working around it. A descriptive record (a decision recorded in another ticket or spec, or an MR's Deliberate section) is not a finding, even if the change goes against it. If the doc names no binding decisions, say so and move on.

For each defect in code the slice did not write, say so, so it can be fixed in its own commit.
<Only on a re-review: "Findings from the previous review, now claimed fixed:" followed by that list. Mark each FIXED or STILL OPEN.>

End with exactly one of:
- `APPROVED` (low-confidence findings may be listed above it)
- `NEEDS FIXES`, then a numbered list of the blocking fixes only.
---QUALITY REVIEWER PROMPT END---

A slice passes phase C only when both reviewers approve.

### D. Remediate

On `NEEDS FIXES` from either reviewer, send the slice back: a fresh implementer with the phase A prompt plus the merged numbered fix list (deduplicated). Then repeat phase B, then re-run phase C with both reviewers, attaching the previous findings.

A fix for a defect in code the slice didn't write lands in its own commit. Collect these across the slice for the PR/MR description's "Found along the way" section.

Stop the slice if a re-review marks any finding STILL OPEN, or after three review rounds. New findings that a fix uncovered don't stop the slice on their own.

### E. Merge

1. If the integration branch has moved since the base SHA, rebase the slice onto the new tip and record the new base SHA. Repeat phase B. If the rebase hit conflicts, repeat phase C as well.
2. If the tracker lives in git (local markdown), close the ticket as the tracker doc says, as a commit **on the slice branch**. If the doc doesn't say how for implementation tickets, set its status line to `resolved` and tick the acceptance criteria the slice met.
3. In the integration worktree: `git merge --no-ff <slice-branch> -m "Merge <ticket ref>: <ticket title>"`, so each slice stays one self-contained merge commit.
4. If the tracker is remote, comment on the ticket with the merge commit SHA. If it closes tickets through the PR/MR, leave the ticket open; otherwise close it as the tracker doc says.
5. Remove the slice's worktree, then delete its branch from the integration worktree (`git -C <integration worktree> branch -d <slice-branch>`; from any other checkout `-d` refuses it as unmerged).

### Stopping a slice

Leave its branch and worktree unmerged. Record the open findings on the ticket: a comment on a remote tracker, or a note in the report for a local one. Continue with frontier tickets that don't depend on it, and report it to the user at the end.

### Binding decisions

A **binding decision** is a recorded decision the repo has promoted to a standing pattern; where they live is the repo's call (`docs/agents/domain.md` says where to look). Before a slice's implementer starts, and when a reviewer or implementer reports a conflict, check whether the slice's change would reverse one. If so, stop the slice, don't work around it, and propose a ticket for the reversal to the user. Reversing a binding decision is its own ticket, never a side effect of another.

## Step 5: Review the whole branch

When every ticket has merged, review the whole integration branch, `git diff <merge-base>..HEAD` where `<merge-base>` is the merge-base of the integration branch and the default branch. Run both reviews:

1. **Zoom-out review.** If the repo has a `/fit-review` (a command or skill in the repo, or named in CLAUDE.md/AGENTS.md), call it over that range. Otherwise dispatch one fresh reviewer subagent (model `opus`) as the built-in zoom-out review:

---ZOOM-OUT REVIEWER PROMPT START---
You are doing the end-of-branch zoom-out review of spec <spec ref>. Worktree: <integration worktree>. Review exactly this range: `git diff <merge-base>..HEAD`. Context pointers only; you have no implementer reports.

Slices each passed review alone; you look for what only shows across slices. Is it the change the spec needed, in the module and layer it belongs in, done the way neighbouring code does the same job? Look for fragmentation, duplicated helpers, inconsistent naming or patterns between slices, and code in the wrong place.

For each finding, say whether it is in the branch's own code (lines this range added) or pre-existing code the range merely touches or sits beside. Report findings only; don't edit.

End with exactly one of: `CLEAN`, or `FINDINGS` and a numbered list.
---ZOOM-OUT REVIEWER PROMPT END---

2. **Bug review.** Call the Skill tool with `mattpocock-skills:code-review` over the same range.

Then route the findings:

- **Fit problems and defects (bugs, spec misses, violations of a documented standard) in the branch's own code:** send a single implementer subagent (the phase A prompt, with the findings as the send-back text) to fix them, and only them.
- **Pre-existing problems:** go through the found-defect rule: an obvious fix goes in its own commit and is named in the PR/MR's "Found along the way"; anything needing a decision goes in the report, unfixed.
- **Judgement calls and open questions:** into the report for the user, unfixed.

Then run the test command yourself once more.

### Promote decisions

Then run the promotion pass. Decisions are descriptive by default: they stay in the spec issue and the PR/MR's Deliberate section. List the decisions made during this run (from tickets, reports and findings) that look made on purpose to set a pattern; leave out offhand choices. If there are none, say so and move on.

For each listed decision, the agent asks the user whether to promote it to binding, giving the decision and why it looks pattern-setting. Write a promotion only after the user confirms it, in the place the repo keeps binding decisions (find it through `docs/agents/domain.md`; don't assume `docs/adr/`). If it's unclear where, ask. Unconfirmed or unanswered decisions stay descriptive.

## Step 6: Finish

1. Push the integration branch, and leave the PR/MR as a draft; the user marks it ready. Update the PR/MR description to list the defects collected in phase D under "Found along the way".
2. Remove the integration worktree.
3. Report: the integration branch, the PR/MR link, each ticket with its merge commit, the defects found along the way, any stopped slice with its open findings, step 5's unfixed judgement calls and questions, and the decisions proposed for promotion with the user's answers.

## Rationalizations

| Excuse | Reality |
|---|---|
| "The implementer reported all tests pass, so I'll skip running them." | Phase B exists because implementer reports are optimistic. Run them yourself. |
| "This slice is tiny; review would take longer than it did." | Small slices are where unrequested extras hide. Every slice gets phase C. |
| "I'll give the reviewer the implementer's summary to save it time." | The reviewer reads the diff, not a story about it. Pass pointers only. |
| "Two slices are both done; I'll merge them together." | Each slice merges alone, after phases B and C on its own current base. |
| "I'll merge in the main checkout; it's quicker." | The user's checkout isn't yours. Merge in the integration worktree. |
