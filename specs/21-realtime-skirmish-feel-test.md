---
spec_type: hybrid
status: active
parent_spec: ../Breach — Reverse Tower Defense Design Spec.md
---

# Real-time Skirmish Feel Test

## Purpose

Decision 38 moves Breach from tower-defence turns to **real-time with pause**. The
simulation runs live on short, deterministic ticks. The player can pause at any moment,
or give orders live, and an order takes effect on the next tick. Before the real
simulation is reworked around this, this item is a **feel test**: the smallest playable
slice that shows whether the model plays well.

It answers:
- How long should a tick be?
- Does intervening mid-fight feel responsive?
- Is the order latency acceptable?
- Does pausing when a wave is full (Decision 39) help or get in the way?

It does **not** cover economy, structures, suspicion, multiple lanes or real unit
rosters. The P-f-F-c slice (`main.tscn`, `sim/lane_simulation.gd`) is untouched, and so
is its `SimulationClock`.

The map is P-c. The player's origin P is at one end of a single lane and the kingdom's
origin c is at the other. The kingdom's fort is immune, so units that reach it simply
arrive. Both sides field melee units. The player's lane builds waves, and the kingdom
spawns units.

## Components

- **Content:**
  - `content/maps_src/skirmish_p_c.designer.json`: a designer map with a 12×3 grid, P at
    (1, 1) and c at (10, 1), and one link with a straight route and a road. It's imported
    to `content/maps/skirmish_p_c.tres`.
  - `content/units/kingdom_militia.tres`: a melee `UnitDef` (hp 24, dmg 5, speed 0.8).
    The player uses `grem.tres`.
- **`sim/skirmish/`** (pure RefCounted, headless, deterministic):
  - **`SkirmishClock`**: a fixed-step accumulator. `advance(delta)` returns how many
    ticks are due, carrying the remainder and capping catch-up. It has
    pause/resume/speed, and a tick of 0.25 s.
  - **`SkirmishUnit`**: stats from a `UnitDef`, distance along the route (cells, from
    P's end), order (ADVANCE/HOLD/RETREAT), state (MOVING/HOLDING/FIGHTING/ARRIVED/
    DEAD), target, and attack cooldown.
  - **`SkirmishSimulation`**: `spawn`, `order` (queued until the next tick) and `step()`.
    Each step runs in a fixed, documented order: orders, then engagement, movement,
    combat and deaths. It returns the step's events.
  - **`SkirmishProduction`**: one lane's build order.
    - It builds one unit every `build_ticks` up to `wave_size`, emits `wave_full` once,
      and waits.
    - The departure mode is MANUAL (`send()`) or AUTO_WHEN_FULL.
    - `send()` spawns the group at P and restarts building.
- **`presentation/skirmish/`** (engine glue with smoke tests):
  - **`SkirmishScene`** (`skirmish.tscn`): the P-c map drawn by the existing `MapView`
    (a debug board; the real board is 3D later, per Decision 36), `SkirmishUnitLayer`, a
    camera and the HUD.
    - It reacts to `wave_full` by pausing when the option is **Pause**. It always shows
      a notification.
  - **`SkirmishUnitLayer`**: units drawn at their interpolated distance, placed along
    the route polyline (`SkirmishRoute.point_at`), with faction colour, an HP bar, a
    mark while fighting, and a selection ring.
  - **HUD:**
    - pause (Space) and speed ×1/×2/×4
    - wave progress, **Send wave**, the departure mode, and **On wave full:
      Pause / Notify**
    - spawn a kingdom unit, and kingdom auto-spawn
    - select (click / Tab) and **Advance / Hold / Retreat** (A/H/R)
    - a readout and an event log

## Scenarios (Given/When/Then)

```
Scenario: The clock carries leftover time
  Given a 0.25 s tick
  When 0.3 s passes twice
  Then 2 ticks are due in total (not 1 and 1 with the remainder lost)
  And while paused no ticks are due, and speed ×2 doubles the ticks due

Scenario: Units advance and meet
  Given a grem spawned at P's end and a militia at c's end of a 9-cell route
  When the simulation steps
  Then each moves speed × 0.25 cells per tick toward the other
  And when they come within melee reach they engage and stop

Scenario: Melee is deterministic
  Given the same spawns
  When stepped until one dies
  Then the same unit dies on the same tick every run, and the event logs match

Scenario: Orders take effect on the next tick
  Given two engaged units
  When the player orders the grem to Retreat
  Then on the next step it disengages and walks back toward P, and the militia advances
  And a Hold order stops movement but a holding unit still fights when engaged

Scenario: The kingdom fort is immune
  Given a grem that reaches c's end
  Then it is ARRIVED, stops, and nothing is damaged

Scenario: A lane builds a wave
  Given wave size 3 and 8 ticks per unit, manual departure
  When 24 ticks pass
  Then wave_full is emitted once, building stops, and nothing departs until send()
  And with auto departure the wave departs on the tick it fills

Scenario: Pause on wave full is a player option
  Given the scene's option is Pause
  When wave_full arrives
  Then the clock pauses and "wave ready" is shown; with Notify it keeps running
```

## Test-first order

1. `tests/sim/skirmish/test_skirmish_clock.gd`
2. `tests/sim/skirmish/test_skirmish_simulation.gd`
3. `tests/sim/skirmish/test_skirmish_production.gd`
4. `tests/presentation/skirmish/test_skirmish_route.gd` (distance → point along the
   route)
5. Scene smoke tests (`tests/presentation/skirmish/test_skirmish_scene.gd`): it
   instantiates, the wave-full option pauses or doesn't, and the unit layer constructs.
6. Manual: the user plays it and reports on the tick length, responsiveness and
   readability. The outcome is recorded below.

## Outcome

**Playtest 1 (2026-09-30), the user's feedback and what changed:**

1. **Travel at ×1 felt too fast.** Movement is now `UnitDef.speed × TRAVEL_SCALE`
   (0.5) cells per second, which halves it. The unit data is unchanged, so the scale can
   be retuned in one place.
2. **A little lag before an order took effect.** The tick is now **0.1 s** (from
   0.25 s). All timings are now in seconds, not ticks: attack interval 1 s, build time
   2 s per unit, departure stagger 0.5 s, kingdom auto-spawn 10 s. Changing the tick
   length doesn't change the pace.
3. **Pausing on a full wave helped, but unpausing and then sending felt clunky.** After
   a wave-full pause, **Send wave** (button or **S**) now sends *and* resumes in one
   action. A pause the player chose themselves stays paused.
4. **The frontline needs aligning** (the user's direction, to be designed):
   - Units get a **grid footprint**: 1×1 for a grem or a person, 2×1 for cavalry, 2×2
     for a brute, 4×4 for large creatures, 8×8 at most (a dragon).
   - A lane has a **configurable frontline size**, and a wave is a **formation laid
     out** on it. This matches the user's original intent of, for example, a 3×1 wave
     with more slots unlocked over time.
   - The player could set a wide frontline rather than a single file entering the
     fight.
   - To be settled before the feel test is extended, and recorded as a Decision.

## Notes / open questions

- No randomness in v1. Hit chance, morale and rout come with the real Encounter model
  (the combat addendum).
- One route and one lane. Multiple lanes, junctions and the unit-AI priority stack are
  later.
- **Crowding (superseded by Decision 40 and `specs/22-formation-feel-test.md`):** every unit that reaches a fight joins it. A wave of three
  piles onto one militia, and there is no front line with others queuing behind. The
  view fans stacked units out sideways so a wave reads as a group; the rules are
  unchanged. Whether only the front unit, or a limited frontage, can fight is a rules
  question for the user after playing.

## Rubric answers (qualitative, spec-baseline)

- `single-noun-phrase`: `skirmish_clock.gd`, `skirmish_unit.gd`,
  `skirmish_simulation.gd`, `skirmish_production.gd`, `skirmish_route.gd`,
  `skirmish_unit_layer.gd`, `skirmish_scene.gd`.
- `ocp-extension-point`: new orders are new enum values handled in one step phase. The
  real sim replaces this module rather than editing it.
- `lsp-contract-scope`: not applicable.
- `isp-fit`: the simulation exposes spawn, order, step and read accessors.
- `dip-direction`: `sim/skirmish/` is RefCounted only and reads `content/` definitions.
  `presentation/skirmish/` reads `sim/`, never the reverse.

## Structured rubric notes

- `spec-type-declared`: `hybrid`. The sim uses TDD; the scene is glue with smoke tests
  and a manual check.
- `tdd-plan-present`: see Scenarios and Test-first order.
- `no-drift`: implements Decisions 38 and 39 as a throwaway-scoped feel test.
- `commit-classification-plan`: `docs:` spec and Decision 39; `feat(sim):` for the
  clock, the simulation and production; `feat(content):` for the map and militia;
  `feat(presentation):` for the scene.
