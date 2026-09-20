---
spec_type: code
status: active
parent_spec: ../Breach — Reverse Tower Defense Design Spec.md
---

# Lane Movement and Combat Resolution

## Purpose

Unit marching along the lane graph, node occupancy, and combat resolution when
opposing forces share a node at a tick boundary.

## Components introduced

- `LaneSimulation` — owns node graph state (which units occupy which node/lane
  segment) and per-tick movement. One concern: *where things are*.
- `CombatResolver` — owns resolving a clash when opposing forces occupy the same node
  at a tick boundary. One concern: *what happens when things meet*. Deliberately
  separate from `LaneSimulation` so a later spatial-placement pass (parent spec's
  Option 2, deferred by Decision 4) can replace movement without touching combat math,
  and so combat's contract-test suite doesn't drag in movement's.

## Scenarios (Given/When/Then)

```gherkin
Scenario: A unit advances one lane segment per tick while marching
  Given a Grem at node P with a march order toward f
  When a tick advances
  Then the Grem's lane position moves one segment toward f
  And SimEvents.tick_advanced carries enough state for presentation to interpolate the
    move over the following real-time interval

Scenario: Reaching an undefended node captures it
  Given a Grem arrives at f
  And f's garrison is 0
  When the tick that resolves the arrival completes
  Then f's ownership flips to the player
  And SimEvents.node_captured is emitted for f

Scenario: Reaching a defended node triggers combat before capture
  Given a wave of 5 Grem arrives at F
  And F's garrison is 3 defenders
  When the tick that resolves the arrival completes
  Then CombatResolver resolves the clash using the parent spec's ported combat numbers
  And F's ownership only flips if the attacking force wins
  And SimEvents.combat_resolved is emitted with the outcome

Scenario: Opposing forces meeting mid-lane (not at a node) still resolve as combat
  Given a player horde marching toward c
  And a Hero Party marching toward f on the same lane segment
  When both occupy the same segment at a tick boundary
  Then CombatResolver resolves the clash exactly as it would at a node
  And the loser is removed from the lane

Scenario: A wave with zero surviving units after combat cannot continue marching
  Given a wave of 2 Grem loses a clash and both are destroyed
  When the next tick advances
  Then there is no surviving wave to move, and no further events reference it
```

## Test-first order

1. `LaneSimulation.advance_positions()` — single unit, no obstruction — red before any
   movement code exists.
2. Node-capture-on-arrival for an undefended node.
3. `CombatResolver.resolve(attackers, defenders)` — pure function, tested directly with
   the parent spec's ported numbers before wiring it into `LaneSimulation`.
4. Wire `LaneSimulation` to call `CombatResolver` on same-node/same-segment occupancy;
   integration test for the defended-fort scenario above.
5. Mid-lane clash (Hero Party vs. player horde) as its own scenario — this is the case
   the vertical slice's closing beat depends on.

## Notes / open questions

- Combat numbers (unit hp/dmg) are ported from the HTML prototype as starting defaults,
  per the parent spec's own instruction — not re-derived here. Exact figures live in
  `UnitDef`/`ResponseUnitDef` resources (`specs/06-map-content-p-f-F-c.md`), not
  hardcoded in `CombatResolver`.
- `CombatResolver` takes plain data (unit counts/stats) in and returns an outcome —
  it does not read `LaneSimulation` state directly, so it stays unit-testable without a
  running lane.

## Rubric answers (qualitative, spec-baseline)

- `single-noun-phrase`: split into two files at implementation
  (`sim/lane_simulation.gd` — "lane occupancy", `sim/combat_resolver.gd` — "combat
  resolution") once both exist; described together here because the vertical slice's
  first combat scenario (fort capture) needs both to be meaningful.
- `ocp-extension-point`: a new unit type or a new combat modifier plugs in as new
  `UnitDef`/`ResponseUnitDef` data consumed by the same `CombatResolver.resolve()` — no
  edit to `CombatResolver` itself required per new unit type.
- `lsp-contract-scope`: not yet applicable — one `CombatResolver` implementation. If a
  second resolution strategy is ever added (e.g. a spatial-siege variant under Option
  2), both must pass a shared contract test asserting "loser is removed, ownership
  only flips on attacker win" before either ships.
- `isp-fit`: `CombatResolver`'s public surface is just `resolve(attackers, defenders)`
  — 1 method.
- `dip-direction`: both are simulation-layer, no presentation dependency; `LaneView`
  (later spec) depends on `SimEvents.combat_resolved`, never calls `CombatResolver`
  directly.

## Structured rubric notes

- `spec-type-declared`: `code`.
- `tdd-plan-present`: see Scenarios and Test-first order above.
- `no-drift`: implements parent Decision 4 (abstracted lane capture, not spatial) —
  combat resolves as a single clash per shared node/segment, not a siege.
- `commit-classification-plan`: `feat(sim): add lane movement and combat resolution`.
