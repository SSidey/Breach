---
spec_type: policy
status: active
parent_spec: ../Breach — Reverse Tower Defense Design Spec.md
---

# Scope and Map — Vertical Slice `P-f-F-c`

## Purpose

Defines the vertical slice's map topology and scripted scenario. Every other spec in
this folder implements a system this document assumes exists; none of them introduce
new scope beyond what's described here.

## Map topology

One lane, four nodes, in order:

```
P ── f ── F ── c
```

| Node | Type | Starting state |
|---|---|---|
| `P` — Player Home | origin | Player's spawn/roster point; not capturable |
| `f` — Farm | resource (Food) | Undefended (garrison 0) |
| `F` — Fort | structure | Lightly defended (small garrison) |
| `c` — Core | origin (defender) | Undefended for this slice (Decision 9) |

This is the spec's own worked early map, mapped onto the `P-f-F-c` notation: "one
track, one loosely-defended farm, one lightly-defended fort."

## Scripted scenario (the five beats, per the design spec's worked-map table)

1. **Overrun the farm.** Player marches a starting group of Grem from `P` to `f`. No
   garrison to fight — this is a movement/capture teaching beat. On capture, the
   auto-extraction rule (`specs/03-resource-nodes-and-workers.md`, Decision 2) kicks in:
   the capturing Grem default to Harvesting Food at `f`.
2. **Take the fort.** Once enough Food/Wood has accrued, the player forms a wave
   (`specs/01-simulation-clock-and-commands.md`) large enough to beat `F`'s garrison and
   marches it up the lane. Fort falls → capture-choice fires (Fortify/Dismantle,
   `specs/03-resource-nodes-and-workers.md`); either is legal, Dismantle is the simplest
   path to close the slice.
3. **Messenger flees.** Attacking `F` raises the Core Suspicion meter (Decision 5 /
   `specs/04-suspicion-and-response.md`) via a detection spike; a Messenger Task Force
   spawns from `c` and attempts to flee back toward `c` unless intercepted.
4. **Hero Party incoming.** The messenger reaching `c` (or the spike alone, per the
   Mobilized-tier threshold) pushes suspicion into the Mobilized tier, dispatching a
   Hero Party down the lane from `c`. The player sees narrative log lines, not a raw
   number (Decision 8).
5. **Ravage for a horde.** The player's standing force is not assumed large enough to
   beat the Hero Party outright. The player Ravages `f` (lump-sum Food, node exhausted
   after — spec's Structures section) to fund a horde big enough to win the clash when
   it meets the Hero Party on the lane.

**Closing beat (Decision 9):** once the Hero Party is defeated, any surviving horde that
reaches `c` triggers Victory. No combat resolution is required at `c` itself in this
slice.

**Loss condition:** the player's entire standing force (roster + anything on the lane)
is destroyed before the Hero Party is defeated.

## What this slice deliberately does not include

Per Decisions 4, 6, 7 in the parent spec: no spatial tower placement, no Lair/fusion
(single `UnitDef`: Grem), no Scout/Infiltrator, no Guard/Militia suspicion tiers
(present in the engine as no-op data, per Decision 5).

## Rubric answers (qualitative, spec-baseline)

- `single-noun-phrase`: this document's purpose is "vertical-slice scope" — a single
  noun phrase, no conjunction.
- `ocp-extension-point` / `lsp-contract-scope` / `isp-fit` / `dip-direction`: not
  applicable — this is a `policy` spec introducing map/scenario content, not code or an
  interface.
- `project-agnostic-language`: not applicable — this spec is project-specific by design
  (it's `specs/`, not `AI_First_Development_Kit/`, which stays stack/project-agnostic).

## Structured rubric notes

- `spec-type-declared`: `policy` (no executable behavior of its own; it's consumed by
  the `code`/`hybrid` specs below).
- `tdd-plan-present`: not applicable — no code in this spec.
- `no-drift`: consistent with parent Decisions 1–9; introduces no new decisions of its
  own (it only narrates the scenario those decisions already committed to).
- `commit-classification-plan`: lands as part of the same `docs:` commit as the parent
  spec's Decisions section and this folder's other specs (see PR description).
