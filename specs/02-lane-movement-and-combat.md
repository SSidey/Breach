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
- `CombatResolver` — owns resolving a clash when a player horde and an opposing
  blocker occupy the same node at a tick boundary. One concern: *what happens when
  things meet*. Deliberately separate from `LaneSimulation` so a later
  spatial-placement pass (parent spec's Option 2, deferred by Decision 4) can replace
  movement without touching combat math, and so combat's contract-test suite doesn't
  drag in movement's.

**The real algorithm, ported from `reference/breach-prototype.html` (Decision 11),
not invented:**

- A clash is always **horde vs. blocker**. A horde is an ordered list of individual
  units, each with its own `hp`/`dmg` (a marching wave's `UnitDef`-shaped units). A
  blocker is a single pooled-stat entity with one `hp`/`dmg` pair — a fort/garrison
  (`NodeDef.garrison_hp`/`garrison_dmg`) and a Hero Party (`ResponseUnitDef`) are both
  this same shape, so `CombatResolver` doesn't need to know which kind of blocker it's
  facing.
- The horde's total damage output (sum of every unit's `dmg`) is applied to the
  blocker's `hp` **first**, regardless of which side is "attacking" in the fiction —
  a horde marching into a fort and a Hero Party marching into a horde both resolve
  with the horde striking first, because in the source prototype the player's units
  are always the side whose damage is computed and applied first.
- **If that destroys the blocker, the horde takes zero casualties this exchange** —
  the blocker never retaliates once it's already dead.
- **Only if the blocker survives** does it deal its own `dmg` back to the horde. That
  damage is applied to the horde's units **weakest-hp-first, with any overkill
  spilling onto the next-weakest unit** (ported from `killUnitsWithDamage`'s
  sort-then-carry-the-remainder loop) — not a flat subtraction from a summed total.
- If any horde units survive the retaliation, the engagement is a stalemate this
  tick: the blocker holds, the horde doesn't advance, and the same clash resolves
  again next tick (this is what makes "grinding down a fort over several rounds" a
  real multi-tick siege rather than a single roll).
- If the horde is wiped out, it's removed; per the fiction, an undefeated blocker
  that was being approached by a now-destroyed horde continues whatever it was doing
  (a Hero Party pushes on — see `specs/04`'s Task Force lifecycle, not this spec).

**Deliberately not ported:** the prototype's per-kill defender-currency bounty (no
analog in this project's economy) and alarm-meter/messenger-spawn increments on a
surviving blocker (`specs/04`'s `SuspicionSystem` concern, not combat resolution's).
See Decision 11 for the full reasoning.

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

Scenario: A horde destroys a blocker outright and takes no casualties
  Given a horde whose total dmg output is >= a fort's garrison_hp
  When the horde reaches the fort's node
  Then the fort's blocker is destroyed
  And every horde unit survives (the fort never retaliates)
  And the node's ownership flips to the player
  And SimEvents.combat_resolved is emitted with the outcome

Scenario: A horde fails to destroy a blocker and takes weakest-first casualties
  Given a horde of 3 units (hp 4, hp 6, hp 10) whose total dmg does not destroy a
    blocker with garrison_hp = 50
  And the blocker's garrison_dmg is 7
  When combat resolves
  Then the blocker survives
  And the hp-4 unit is destroyed (4 damage) with 3 damage overkill spilling onto the
    hp-6 unit, leaving it at hp 3
  And the hp-10 unit is untouched
  And the node's ownership does not change
  And the horde does not advance this tick

Scenario: Opposing forces meeting mid-lane resolve with the same horde-vs-blocker rule
  Given a player horde and a Hero Party (a blocker) occupy the same lane segment at a
    tick boundary
  When combat resolves
  Then the horde's total damage is applied to the Hero Party first
  And the Hero Party only retaliates (weakest-unit-first) if it survives that hit

Scenario: A wave with zero surviving units after combat cannot continue marching
  Given a horde loses all its units to a blocker's retaliation
  When the next tick advances
  Then there is no surviving wave to move, and no further events reference it
```

## Test-first order

1. `LaneSimulation.advance_positions()` — single unit, no obstruction — red before any
   movement code exists.
2. Node-capture-on-arrival for an undefended node.
3. `CombatResolver.resolve(horde, blocker)` — pure function, tested directly against
   the scenarios above (destroy-outright/no-casualties, survive/weakest-first-spill,
   stalemate/no-advance) before wiring it into `LaneSimulation`.
4. Wire `LaneSimulation` to call `CombatResolver` on horde/blocker occupancy;
   integration test for the defended-fort scenario above.
5. Mid-lane clash (Hero Party vs. player horde) as its own scenario — this is the case
   the vertical slice's closing beat depends on.

## Notes / open questions

- Real unit/blocker numbers (Grem's actual hp/dmg, a Fort's actual garrison stats) are
  still deferred to `specs/06` content-authoring per Decision 6 — this spec fixes the
  mechanism, not the balance figures. `reference/breach-prototype.html` now has real
  starting-point numbers for that later work (its `raider`/`bruiser` units and
  `FORT_D_L1`/`GARRISON_BASIC`/`HERO_HP`/`HERO_DMG` constants) rather than needing to
  be invented then either.
- `CombatResolver` takes plain data (a horde array of `{hp, dmg}`-shaped entries and a
  blocker `{hp, dmg}` dictionary) in and returns an outcome — it does not read
  `LaneSimulation` state directly, so it stays unit-testable without a running lane.
- `NodeDef` gained `garrison_hp`/`garrison_dmg` fields (a fort/garrison's pooled
  blocker stats) alongside its existing `garrison` field — `garrison` remains a
  presence/count check (`> 0` means "defended"), while `garrison_hp`/`garrison_dmg`
  are what `CombatResolver` actually fights against. See
  `specs/07-data-resource-schemas.md`'s updated validation rules.

## Rubric answers (qualitative, spec-baseline)

- `single-noun-phrase`: split at implementation into two files at implementation
  (`sim/lane_simulation.gd` — "lane occupancy", `sim/combat_resolver.gd` — "combat
  resolution") once both exist; described together here because the vertical slice's
  first combat scenario (fort capture) needs both to be meaningful.
- `ocp-extension-point`: a new blocker type (e.g. a future third kind of structure)
  plugs in as long as it's shaped `{hp, dmg}` — no edit to `CombatResolver` itself
  required. A new unit type is the same: any `{hp, dmg}`-shaped entry works as a horde
  member.
- `lsp-contract-scope`: not yet applicable — one `CombatResolver` implementation. If a
  second resolution strategy is ever added (e.g. a spatial-siege variant under Option
  2), both must pass a shared contract test asserting "the horde-vs-blocker strike
  order and weakest-first casualty rule" before either ships.
- `isp-fit`: `CombatResolver`'s public surface is just `resolve(horde, blocker)` —
  1 method.
- `dip-direction`: both are simulation-layer, no presentation dependency; `LaneView`
  (later spec) depends on `SimEvents.combat_resolved`, never calls `CombatResolver`
  directly.

## Structured rubric notes

- `spec-type-declared`: `code`.
- `tdd-plan-present`: see Scenarios and Test-first order above.
- `no-drift`: implements parent Decision 4 (abstracted lane capture, not spatial) and
  now Decision 11 (the real ported combat algorithm) — combat resolves as a single
  clash per shared node/segment, not a siege in the spatial sense, but can span
  multiple ticks as a stalemate repeats.
- `commit-classification-plan`: `feat(sim): add lane movement and combat resolution`.
