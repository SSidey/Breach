---
doc: principles/rules-over-cases
status: active
applies_to: every design decision and every simulation or rules-engine source file
---

# Rules over Cases

## Why this exists

A system's behaviour comes from its rules. Two habits quietly break that. One is
answering each observed problem with its own special case: a list of exceptions that no
one can reason about as a whole, and that misses the next case it didn't name. The
other is letting the order in which things were created or listed settle what happens:
an advantage nobody chose, which shows up as a bias in outcomes long after the code
that caused it is forgotten. Both have cost this kit's first project repeated rework, so
they are written down here and checked on every decision.

## The two principles

### 1. A general rule over special cases

When behaviour needs to change, change or add the general rule that covers the case,
not an exception for the case. Express it as priorities, quantities and conditions that
apply to everything of its kind ("the most urgent manoeuvre wins, checked every tick"),
not as a list of situations ("if halted after a turn, do X; if narrowing, do Y").

A special case is allowed only for a **reason given by the human owner of the design**,
recorded with the Decision that introduces it (who gave it, and why the general rule
can't serve). An agent never introduces one on its own judgement; it proposes the
general rule, and asks if it believes a special case is needed.

**Test:** For each new branch on a situation, can it be stated as an instance of a rule
that would also decide situations nobody has listed? If not, is the owner's reason for
it recorded?

### 2. Identity and order never decide outcomes

An identifier names a thing - to look it up, to refer to it, to log it. It never ranks
it. Identifiers are handed out in creation order, so any comparison, sort, arithmetic or
tie-break on them hands an edge to whatever was created first or last. The same goes
for **list order** when a list is in creation order: keeping the first of equals is the
same fault in another form.

- Resolve things that happen together together: decide everything from the same
  snapshot, then apply.
- Break ties by what things are and where they stand; a tie that remains goes to a
  seeded random draw, which is fair over many runs. An identifier may salt such a draw
  (it gives each thing its own stream), but never order it.
- Verify, don't assume: run a symmetric scenario both ways round (each side created
  first) over many seeds; the results must agree within noise.

**Test:** Would any outcome change if the same things were created, or listed, in the
opposite order?

## Where this is checked

- **At design time:** `rubrics/spec-baseline.rubrics.md`'s `general-over-special` and
  `order-independent` rows, answered in the specification or Decision.
- **At run time:** `rubrics/run-baseline.rubrics.md`'s `order-independent-simulation`
  row: a stack-specific static check for identifiers used to rank, plus the
  swapped-order trial, which is the only check that sees list-order ties.
