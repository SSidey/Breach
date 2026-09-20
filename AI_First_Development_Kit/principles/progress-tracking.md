---
doc: principles/progress-tracking
status: active
applies_to: every plan-stage execution and every ad-hoc prompt that changes source
---

# Progress and Regression Tracking

## Why this exists

Not every change that "looks done" is actually forward motion. Without a recorded
trend, drift accumulates silently — a rubric slowly weakens, coverage slowly drops,
warnings slowly pile up, and no single change looks bad enough to block on its own. This
document defines two independent gates that run on every plan-stage execution or ad-hoc
prompt that touches source: a **mechanical gate** (objective, blocking) and a **human
gate** (qualitative, separate, later).

These are deliberately two different mechanisms because they answer two different
questions: *did the numbers get worse* is answerable by a machine; *does this actually
feel like the right direction* is a judgement call that shouldn't be delegated to the
same agent that just made the change.

## Gate 1 — Mechanical trend metrics (hard gate, end of implementation)

Recorded and compared against the pre-change baseline for every execution:

| Metric | Direction that fails |
|---|---|
| Rubric pass count (spec + run rubrics combined) | Decreases |
| Test count | Decreases without an explicit, documented reason (e.g. tests consolidated, not lost) |
| Coverage % (overall and on changed lines) | Drops below the configured threshold — see `principles/tdd-bdd-workflow.md` |
| Lint warning count | Increases |
| File/function line counts vs. context budget | New violation introduced |

**This is a hard gate.** If any metric moves in the failing direction at the end of an
implementation pass, the pass is not complete — a refactor loop is required before the
work is considered done, whether the agent or a human is doing the refactor. This gate
does not require human judgement and should not wait for it.

**Explicitly not blocking mid-implementation.** A metric may legitimately look worse
partway through a multi-step refactor (e.g. line count rises temporarily while splitting
a file). The gate applies at the declared end of the implementation pass, not at every
intermediate commit.

**Recording:** each execution appends a row to the project's progress log (see
`templates/` for the log entry shape) capturing before/after values for each metric, the
plan stage or prompt that produced the change, and pass/fail.

**Recommended mechanism:** a single script (stack-specific, living in `ci/<stack>/`)
that (1) computes the current value of each metric above, (2) reads the previous row of
the project's progress log, (3) compares the two and fails/flags on any regression per
the table above, and (4) appends the new row unconditionally either way — the log is a
record of what happened, not only of passing runs. Keeping this as one script rather
than a manual "eyeball the numbers and update a doc" step is what makes the gate actually
hard rather than aspirational; a step a human or agent can forget to run isn't a gate.

## Gate 2 — Human qualitative review (separate, after implementation)

After the mechanical gate has passed, a human reviews the change and records a
judgement — not a rubric score, a plain verdict: does this feel like real progress, or
does it feel like the codebase got harder to work with even though every number looks
fine?

- This gate is **non-blocking to the mechanical pass** — mechanical passing is not
  contingent on the human verdict, and the human verdict is not contingent on rubric
  numbers alone.
- It **is required before merge** — a change with clean mechanical metrics but no
  recorded human verdict is not yet mergeable.
- The verdict is recorded alongside the mechanical log entry, not as a replacement for
  it.

**Why this is not delegated to an agent grading its own work:** an agent judging whether
its own change was an improvement has an obvious conflict of interest. The mechanical
gate exists precisely so that objective checks don't depend on this judgement at all;
the human gate exists precisely for the part that legitimately requires judgement rather
than pretending a number can capture it. See `principles/agent-workflow.md` for this
same reasoning applied to the other human-only actions in a project (merging, superseding
a Decision).

**Where to record it:** a durable, append-only, project-level log — not only inline in a
proposal's description. A verdict that lives solely inside a closed pull/merge request is
effectively unfindable a month later; a standing file (or equivalent structured store)
that accumulates one entry per change keeps the qualitative history as easy to consult as
the mechanical one. The proposal description can and should *link* to the entry it adds,
but the entry's home is the durable log, not the proposal.

**Optional extension — versioned releases:** a project with discrete, versioned releases
(rather than continuous deployment of every merge) may find it useful to generate a
per-release qualitative-review entry automatically, seeded with that release's Gate 1
metrics, whenever a release is cut — giving the human reviewer a ready-made place to
record their verdict for that specific version rather than reconstructing it from
several merges' worth of entries. This is a pattern to consider, not a requirement; a
project adopting it defines its own release trigger and entry shape as a Decision, since
those specifics are inherently project-specific (this kit does not prescribe a release
cadence or a composite score for it — see "What this document deliberately leaves open"
below).

## What this document deliberately leaves open

Defining a fully objective, code-quality-general "improvement score" beyond the metrics
above is an open problem — this document does not claim to solve it, and does not invent
a synthetic composite score to paper over that gap. The mechanical metrics are reported
individually and reviewed individually; they are not combined into a single number.

This is a stance about Gate 1's per-change regression tracking specifically, not a ban on
composite scores everywhere. A project may define one for a genuinely different purpose
(e.g. a single release-readiness figure for the optional extension above) via a recorded
Decision that states plainly what the score does and doesn't mean and what it's excluded
from — that Decision does not supersede this document, since it isn't answering the same
question this document answers.
