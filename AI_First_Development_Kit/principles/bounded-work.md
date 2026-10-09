---
doc: principles/bounded-work
status: active
applies_to: every simulation or rules-engine source file that runs per tick, and every design of such a system
---

# Bounded Work

## Why this exists

A simulation that is fine at forty units can be unusable at four thousand. The cause is
almost never the language. It is work that grows faster than the world: a pass that
compares every thing with every other thing, a search with no edge, a check repeated
every tick on things that haven't changed. Each looks harmless when written and turns
into the whole tick's cost later. In this kit's first project, uncapped searches cost
pathing most of its speed, and five such passes cost a mass battle most of its tick:
one of them cubic, hidden in an array erased from inside a loop. So the rule is
written down here, checked on every design, and measured in CI.

## The two principles

### 1. Every per-tick query is local and bounded

What a thing looks at each tick is limited by distance or by count, never by the size
of the world.

- Find neighbours through a spatial index (a grid of cells, or a sorted structure), with
  a fixed radius or a fixed number of rings. Never scan every unit, body or squad for
  each unit.
- Searches have an edge: a planner stops at what is seen, a look-ahead at its distance,
  a ring search at its last ring. The edge is a tuned number, not "until found".
- Work that is the same for a whole group is done once for the group, not once per
  member (a squad's discipline, pace or leadership; a seeded draw used as a sort key).
- Hidden costs count: `erase`, `has`, `find`, `duplicate`, `filter` and `map` on an
  array are each a scan. Inside a loop over the same things they make it quadratic.
  Use a dictionary as a set, or mark things in a packed array.
- Comparing all pairs is allowed only where the count is bounded by design (the squads
  in one engagement, the slots of one unit), with that bound written beside it.

**Test:** If the battle doubles, does this pass at most double, or n log n at worst?
What bounds each loop: a radius, a count, or the size of the world?

### 2. Work follows change

A thing whose state hasn't changed doesn't need checking again. Where most of the world
stands still most of the time, let what changes say so, and check only what it touches.

- When something changes, it records the change (an event, or an entry on a work list):
  a tile dug out queues the tiles it supports; a unit falling queues its group to be
  checked for a split; a squad moving marks its cells dirty.
- Each tick handles only its work list, in a deterministic order (the list is ordered by
  position or seeded draw, never by when entries were added if that is creation order).
- The same records serve the log: what changed and why is kept for replay, debugging and
  analysis, instead of being reconstructed by scanning.
- Correctness first: whatever can change a checked result must queue the check. If that
  can't be made exact, keep the full check and bound it by Principle 1.

**Test:** Does this pass look at things that cannot have changed since it last looked?
If it skipped them, what would have to queue them, and does it?

## Where this is checked

- **At design time:** `rubrics/spec-baseline.rubrics.md`'s `bounded-work` row,
  answered in the specification or Decision.
- **At run time:** `rubrics/run-baseline.rubrics.md`'s `bounded-scaling` row: the
  stack's scaling check doubles the battle and fails a doubling that costs more than the
  limit (Breach: `tools/scaling_check.gd`, run in CI).
- **When a pass is slow:** time it phase by phase (Breach: `tools/tick_phases.gd`), then
  read it for unbounded loops and hidden scans before porting it to faster code. A port
  of a quadratic pass is a faster quadratic pass.
