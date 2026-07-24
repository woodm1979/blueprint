# CONTEXT — glossary

Domain terms used across the blueprint suite. `/brainstorm` reads this to challenge fuzzy or conflicting usage.

## Design Decision Record (DDR)

- **DDR** — Design Decision Record. A committed sibling to the PRD+PLAN (`docs/ai-plans/<date>-<slug>-DDR.md`), one consolidated file per feature holding numbered entries `DDR-1..N`. It records the *deliberation* behind non-obvious choices — the "why" that the diff can't show — so a reviewer or future maintainer sees the tensions, not just the verdicts. Broader than a classic architecture-only ADR: it captures any non-obvious fork, not just architectural ones.
- **Non-obvious fork** — the threshold for a DDR entry. A decision qualifies iff it warranted a tradeoff table / `AskUserQuestion` fork at seed-time, or a genuinely new fork/supersession arose at build-time. Obvious or dominant choices, and routine deviations, never become entries.
- **Contention** — a per-entry tag for how contested a decision was, used to rank entries in the progressive-disclosure header.
- **One-way / two-way door** — a per-entry tag for cost-of-reversal (Bezos framing). One-way doors are hard to undo and deserve reviewer scrutiny; two-way doors are cheap to reverse.
- **Invisible-in-the-diff** — the core signal-to-noise rule: record only what leaves no trace in the code (roads not taken, non-local reasons). If reading the hunk already explains the choice, it's not DDR-worthy.
- **If-flipped** — a required, falsifiable DDR field naming the concrete failure mode of the rejected alternative. If no concrete consequence can be written, the decision wasn't contentious and the entry is cut.
- **Progressive disclosure** — the DDR file surfaces high-contention / one-way-door entries at the top; lower-signal entries sit below the fold.
- **Seed vs append** — `/blueprint` *seeds* the DDR from the brainstorm transcript; `/build-step`'s foreground controller *appends* mid-build forks/dissent/supersessions and fills each entry's `Touches:` (the files/functions the decision produced).
- **Linked, not merged** — the PLAN's binding `## Architectural decisions` block stays terse for implementers; each decision backlinks `(see DDR-N)` to its rationale in the DDR.
