# PRD: Flatten `/build` dispatch nesting (fix socket-failure drops)

> Status: draft
> Plan: ./2026-06-06-build-socket-fix-PLAN.md
> Created: 2026-06-06  |  Last touched: 2026-06-06

## Problem

Running `/build` over long PLANs intermittently fails with `API Error: The socket
connection was closed unexpectedly`. The failures cluster on long-running subagent
dispatches (tens of minutes to 2+ hours); short subagents and foreground tool calls
never drop.

The cause is structural. One section currently stacks two orchestrating subagent
dispatches that each stay open across the *entire* section lifecycle: `/build`
dispatches a subagent that runs `/build-step`, which in turn dispatches a
section-controller subagent that runs the implementer + both reviewers + remediation
serially. Both wrapper dispatches are long-lived streaming connections — exactly what
the transport layer kills. The section-controller dispatches its children separately,
but its own connection is held open the whole time, waiting.

The external afk runner does not dodge this: `scripts/afk-build.sh` runs `/build-step`
per Docker process, but `/build-step` still spawns the section-controller subagent
inside each process. The vulnerable nesting lives *inside* a section, so a
process-per-section boundary doesn't help.

A second, distinct failure mode: an implementer started a background compile/test and
ended its turn on "I'll wait for the notification" — no clean completion signal, though
work had partially landed.

## Solution

Move the orchestration that must stay alive across a whole section into the
**foreground**. A subagent that orchestrates *is* the long-lived connection that drops.

Flatten `/build-step` so its own foreground runs the section lifecycle, dispatching the
implementer + each reviewer + remediation as separate, short, single-role subagent
calls — no section-controller subagent. In-session `/build` then invokes `/build-step`
directly in the foreground (no wrapper subagent). The output-signal contract is
unchanged, so afk-build.sh is fixed for free with no script edit.

Add a reconcile/resume rule so a dropped child dispatch is inspected against git + PLAN
state rather than blind-retried, a foreground-wait discipline rule to the implementer
prompt (fixes the background-and-end-turn mode), and advisory section-sizing guidance to
`/blueprint` so implementer dispatches stay short.

## User stories

1. As a builder, I want to run `/build` on a long multi-section PLAN without socket
   drops killing the run, so I can build unattended-ish without babysitting drops.
2. As a builder whose child dispatch *does* drop, I want the orchestrator to reconcile
   against git + PLAN state and never blind-retry, so partially-landed work isn't lost
   or duplicated.
3. As someone running the afk/sandcastle process-per-section runner, I want the same
   socket fix with no change to my script, so unattended runs stop dropping mid-section.
4. As a plan author, I want guidance that keeps each section's implementer dispatch
   short, so I reduce drop frequency at the source.

## Architecture & module sketch

- **`/build-step` skill** — becomes the foreground section-controller. Inlines the
  lifecycle phases (capture pre-SHA → implementer → status handling → spec reviewer →
  quality reviewer → remediation) that previously lived inside the section-controller
  subagent prompt. Each phase is a separate `Agent` dispatch. Owns the reconcile/resume
  rule and the implementer foreground-wait discipline rule. Preserves the
  `SECTION_COMPLETE` / `ALL_SECTIONS_COMPLETE` / `BLOCKED` output contract.
- **`/build` skill** — foreground loop invokes `/build-step` directly (no wrapper
  subagent). Framing inverts: foreground orchestration is the default/recommended path;
  the old "subagent mode preferred" / "no-subagent fallback" language is removed.
- **`/blueprint` skill** — Step 5 gains an advisory note tying section size to bounded
  implementer dispatch length.
- **Plugin manifests** — version bump in both `.claude-plugin/plugin.json` and
  `.claude-plugin/marketplace.json`.

## Testing approach

These are prose skill files, not executable code — verification is structural review
plus a live run.

- **Structural review** of `/build-step`: no `section-controller` subagent dispatch
  remains; implementer + both reviewers + remediation are each separate `Agent` calls;
  the output-signal contract (`SECTION_COMPLETE` / `ALL_SECTIONS_COMPLETE` / `BLOCKED`)
  is intact so afk-build.sh works unchanged.
- **Cross-reference grep** for stale references ("section-controller", "no-subagent
  fallback", "subagent mode preferred") across both skills.
- **Live smoke test**: run `/build` against a small 2–3 section PLAN. Confirm each
  section completes, the PLAN flips to `[x] complete` with commits, and the longest
  single dispatch is the implementer (reviewers return quickly as separate calls).
- **Recovery check** (best-effort): on a dropped child, confirm the foreground
  reconciles via `git log`/`status` against the PLAN rather than blind-retrying.

## Out of scope

- No change to `scripts/afk-build.sh` (it benefits automatically via the signal
  contract).
- Not deprecating or removing in-session `/build` — both runners stay supported.
- No parallel/concurrent section execution.
- No programmatic transport, timeout, or HTTP-client changes — this is a skill-prose
  restructure only.

## Open questions

- [ ] None — resolved during brainstorm.

## Future Considerations

- **End-to-end live smoke test.** The structural verification passed, but the PRD's
  testing approach #3 (run `/build` on a fresh 2–3 section PLAN and confirm the longest
  single dispatch is the implementer) has not been executed against the flattened
  skills. Worth doing before relying on the fix in anger.
- **Headless/afk confirmation.** afk-build.sh benefits for free via the unchanged signal
  contract, but an actual unattended Docker run should confirm the flattened `/build-step`
  behaves correctly headless.
- **Cross-suite prose audit.** Now that `/build-step` is foreground-orchestrated, sweep
  the rest of the suite (README, CLAUDE.md, other skills) for stale references to the old
  nested wrapper-subagent / section-controller flow.
- **Scripted reconcile helper.** The reconcile/resume rule is prose-only and relies on
  model discipline. A small git+PLAN state-diff helper the orchestrator can call would
  make recovery deterministic and testable.
- **Residual implementer-length risk.** Even flattened, a single oversized section's
  implementer can run long enough to drop. Sizing guidance is advisory; consider a
  warning when a section's scope looks oversized at plan time.
- **Distinct commit messages in `/build-step`.** The impl commit and the PLAN-update
  commit can share the `build: complete Section N` message (seen on Section 3). Using
  distinct messages (e.g. `chore:`/`docs:` for the PLAN update) would keep history
  readable.
