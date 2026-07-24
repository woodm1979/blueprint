# PLAN: Design Decision Record (DDR)

> PRD: ./2026-07-23-design-decision-record-PRD.md
> Executor: /build
> Created: 2026-07-23  |  Last touched: 2026-07-23

## Architectural decisions

<Durable, cross-section decisions. Each links to its rationale in the feature's own DDR once built (`see DDR-N`).>

- **New artifact `docs/ai-plans/<date>-<slug>-DDR.md`** — sibling to PRD+PLAN, one consolidated file per feature, entries numbered `DDR-1..N`. Per-feature numbering only; no global registry.
- **Entry schema** — a `### DDR-N: <title>` heading carrying a contention indicator, a door-type tag (`one-way`/`two-way`), and a tension-type tag; then labelled fields `**Status:**` (supports `superseded by DDR-M`), `**Decision:**`, `**Tension:**`, `**Rejected:**`, `**If-flipped:**`, `**Touches:**`.
- **Progressive-disclosure header** — top of the DDR file ranks high-contention / one-way-door entries first; low-signal entries sit below.
- **Signal-to-noise gates (hard rules)** — (1) record only what's invisible in the diff; (2) `If-flipped` is required and falsifiable, else the entry is cut; (3) no generic tension-language — name specific alternatives + consequence; (4) progressive disclosure.
- **Entry threshold** — non-obvious forks only: at seed-time, a decision that warranted a tradeoff table / `AskUserQuestion` fork; at build-time, a genuinely new fork or a supersession. Obvious choices and routine deviations never become entries.
- **Linked, not merged** — PLAN's `## Architectural decisions` block stays terse + binding for implementers; each decision backlinks `(see DDR-N)`. The DDR owns the "why."
- **Blueprint seeds, build-step appends** — `/blueprint` writes the DDR from the brainstorm transcript; `/build-step`'s foreground controller appends mid-build entries and fills `Touches:`.
- **Commit refs** — build section commits carry a `Refs: DDR-N` line.
- **Edit skill source only** — modify `skills/*/SKILL.md`, never the plugin cache.
- **Tests are grep-based structural assertions** over the SKILL.md source, following `tests/blueprint-skill.sh` + `tests/helpers.sh`.
- **Release discipline** — bump `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` in lockstep before push.

## Conventions

- TDD per section (test → impl → commit)
- Minimum one commit per completed section
- Review checkpoint between sections (spec compliance + code quality)
- Default implementer model: `sonnet` (per-section overrides follow the Model selection rules in `/blueprint`)

---

## Section 1: Blueprint seeds the gated DDR + cross-links PLAN

**Status:** [x] complete
**Model:** opus
**User stories covered:** 1, 2, 5, 6

### What to build

Edit `skills/blueprint/SKILL.md` so that, from an existing brainstorm conversation, `/blueprint` also writes a high-signal `docs/ai-plans/<date>-<slug>-DDR.md` alongside the PRD+PLAN: add the DDR file template + entry schema, a seeding step that mines the transcript for non-obvious forks, the four S/N gate rules, an adversarial-prune item in the Step 7 self-review, and `(see DDR-N)` backlinks in the PLAN template's architectural-decisions block. Add `tests/ddr-blueprint.sh`.

### Acceptance criteria

- [x] `skills/blueprint/SKILL.md` contains a DDR file template exposing every schema field: `Decision`, `Tension`, `Rejected`, `If-flipped`, `Touches`, a contention indicator, a door-type tag, and `Status` with supersession.
- [x] SKILL.md contains a step instructing that a `docs/ai-plans/<date>-<slug>-DDR.md` be written, seeded from the brainstorm transcript, and committed together with the PRD+PLAN.
- [x] SKILL.md states the non-obvious-forks-only threshold and all four S/N gates (invisible-in-diff, required-falsifiable If-flipped, no-generic-tension-language, progressive-disclosure header).
- [x] The Step 7 self-review list contains an adversarial-prune item that challenges each DDR entry as possible padding.
- [x] The PLAN template's `## Architectural decisions` section documents the `(see DDR-N)` backlink convention.
- [x] `tests/ddr-blueprint.sh` exists, sources `tests/helpers.sh`, asserts all of the above with `pass`/`fail`, ends with `summarize`, and exits 0 when run `bash tests/ddr-blueprint.sh`.

### Notes for executor

- Read the skill source at `skills/blueprint/SKILL.md` — NOT the plugin cache under `~/.claude/plugins/cache/`.
- Mirror the style of `tests/blueprint-skill.sh` and `tests/helpers.sh` exactly (`skill_contains` grep helper, step-ordering checks where relevant).
- The DDR is seeded after the PRD+PLAN are drafted; update the Step 8 commit message to include the DDR (e.g. `Blueprint: <feature name> (PRD + PLAN + DDR)`).
- The entry schema you write here is the interface Section 2 consumes — keep field names stable.
- Progressive-disclosure header = a ranked list of high-contention / one-way-door entries at the top of the DDR file.

### Completion log

- Commits: `b5ee659` (implement), `f1d949a` (remediate coherence)
- Tests added: `tests/ddr-blueprint.sh` (26 grep/ordering assertions, exit 0)
- Deviations from plan: Seeding step named **Step 6.7** (not 6.5) to avoid colliding with an unrelated pre-existing `tests/blueprint-skill.sh` reference; the test greps the phrase `Seed the DDR`, so numbering isn't load-bearing. Post-review coherence remediation fixed a self-introduced "two files" vs "three artifacts" contradiction, re-framed Gate 4 (progressive disclosure) as an ordering directive rather than a per-candidate cut-gate, and replaced a dead `#ddr-N` anchor in the template example with a plain ranked list. Deferred cosmetic nit: contention labels (`high`/`contested`/`uncontested`) aren't a perfectly parallel ordinal triple. NOTE: `tests/blueprint-skill.sh` fails on a **pre-existing** `Step 6.5 is missing` assertion, unrelated to this change (verified absent at pre_sha) — flagged for separate fix.

---

## Section 2: build-step appends to the DDR + Refs in commits

**Status:** [x] complete
**Model:** opus
**User stories covered:** 3, 4

### What to build

Edit `skills/build-step/SKILL.md` so the foreground controller, during a section, appends genuinely new forks / dissent / supersessions to the feature's DDR file (same threshold as seed-time), fills each touched entry's `Touches:` with the files/functions the section produced, and adds a `Refs: DDR-N` line to the section commit message. Add `tests/ddr-build-step.sh`.

### Acceptance criteria

- [x] `skills/build-step/SKILL.md` instructs the controller to append a new DDR entry when a genuinely new fork / dissent / supersession arises mid-build, applying the non-obvious-forks-only threshold (routine deviations stay in the completion log, not the DDR).
- [x] SKILL.md instructs filling each touched DDR entry's `Touches:` field with the files/functions the section produced.
- [x] SKILL.md's section-commit step (Step 4 / the `build: complete Section N` commit) includes a `Refs: DDR-N` line for the related entries.
- [x] SKILL.md makes clear the append is done by the `/build-step` foreground controller, not the implementer subagent.
- [x] `tests/ddr-build-step.sh` exists, sources `tests/helpers.sh`, asserts the above, ends with `summarize`, and exits 0.

### Notes for executor

- Read `skills/build-step/SKILL.md` source, not the cache.
- The DDR file path is derived from the PLAN path (`*-PLAN.md` → `*-DDR.md`) in the same `docs/ai-plans/` directory.
- Appending happens where the controller already updates the PLAN completion log (Step 4) — same actor, same phase.
- Do NOT route routine deviations into the DDR; they belong in the completion log. Only genuine forks / supersessions graduate.
- Keep the `Refs: DDR-N` line compatible with the existing commit message `build: complete Section <N> (<Title>)`.

### Completion log

- Commits: `6fa51df` (implement), `960ed13` (remediate)
- Tests added: `tests/ddr-build-step.sh` (15 grep/ordering assertions, exit 0)
- Deviations from plan: DDR-append wired into build-step's existing Step 4 (renamed "Update the plan file and DDR"), keeping the controller-only actor and the routine-deviation-stays-in-completion-log boundary explicit. `Refs: DDR-N` rendered as a commit-body trailer (compatible with the existing `build: complete Section <N>` subject). Post-review remediation added the missing `Status: accepted` clause for newly appended entries (matching Section 1's required-field schema) and retargeted two decorative test assertions from pre-existing strings to Section-2-only strings. Same pre-existing `tests/blueprint-skill.sh` `Step 6.5` failure remains (unrelated).

---

## Section 3: CLAUDE.md PR-body note + plugin version bump

**Status:** [ ] not started
**Model:** sonnet
**User stories covered:** — (release + docs)

### What to build

Add a reviewer-agnostic note to `CLAUDE.md` directing that PR/MR body drafts lead with the DDR's high-contention entries, and bump the plugin version in `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` in lockstep.

### Acceptance criteria

- [ ] `CLAUDE.md` contains a note instructing that PR/MR body drafts lead with the DDR's high-contention entries, naming no specific reviewer.
- [ ] `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` both carry the same version string, incremented above `6.13.1` (suggested `6.14.0` for a feature).
- [ ] `bash scripts/check-plugin-version-bump.sh` passes (or, if it takes no such role, the two version strings are verified equal and incremented).
- [ ] The full suite still passes: every `bash tests/*.sh` exits 0.

### Notes for executor

- The two version files must stay in lockstep — see the repo `CLAUDE.md` release discipline.
- A new feature warrants a minor bump (`6.13.1` → `6.14.0`); confirm against the repo's existing versioning cadence before finalizing.
- The CLAUDE.md note is reviewer-agnostic — encode no person's name.

### Completion log

<!-- Executor fills in after section completes -->
- Commits:
- Tests added:
- Deviations from plan:
