---
spec_type: hybrid
status: active
parent_spec: ../Breach — Reverse Tower Defense Design Spec.md
---

# Formation Feel Test

## Purpose

The first real-time feel test (spec 21) showed that the model plays, but a wave just
piled onto one enemy. Decisions 40 and 41 replace that with formations:
- Units have **footprints**, written depth × width.
- Each lane has a **formation grid**, frontline width × ranks, with a lane width of at
  most 8.
- Only the **front rank** fights, and the unit behind **steps up**.
- A wider line **wraps onto the flanks**.
- The player's unlocked **slots are one pool**, split across lanes; a change applies to
  each lane's **next** wave.

This second feel test puts all of that on screen, on a two-lane map, so the user can
judge frontline width, flanking and pool splitting before the real simulation is
designed. The spec 21 scene stays playable, and its classes are unchanged. The squad
model is built alongside them in `sim/skirmish/formation/`.

## Components

- **Content:**
  - `content/maps_src/skirmish_two_lanes.designer.json` (and its `.tres`): P at
    (1, 2), with lanes to the kingdom origins c at (10, 0) and k at (10, 4).
  - `content/units/grem_brute.tres`: hp 60, dmg 10, speed 0.7, footprint 2×2.
  - **`UnitDef.footprint_depth` / `footprint_width`** are new fields, defaulting to 1
    (additive schema). The existing units stay 1×1. The designer has no unit view yet,
    so there's nothing to sync.
- **`sim/skirmish/formation/`** (pure RefCounted, deterministic):
  - **`SkirmishFormation`**: a width × ranks grid holding `slots` usable cells.
    - The ranks are ceil(slots / width), and the last rank may be partial.
    - `place(depth, width, prefer_centre)` fills the front rank first, left to right.
    - `can_fit`, and `clamp_width(requested, lane_width, slots)` (the width is capped by
      the lane, the global maximum of 8, and the slots).
  - **`SkirmishSlotPool`**: a total, split across lanes. Each lane is capped at
    width × 4 ranks, and assignments are clamped to what's free.
  - **`SkirmishSquad`**: a wave in the field.
    - Each unit sits at the squad's front distance, minus its rank × `RANK_DEPTH`.
    - It moves as a block at its slowest unit's speed, and takes wave-level orders.
    - `fighters()` is the foremost living unit in each column. `compact()` steps units
      up after deaths.
    - Lateral spans are centred on the lane, and mirrored for the side facing the other
      way.
  - **`FormationSimulation`**: one lane's squads.
    - Each tick runs orders → engage → move → combat → deaths and step-up.
    - Each fighter strikes the enemy fighter it **overlaps laterally**. If none overlap
      (its line is wider), it **wraps** onto the nearest enemy end fighter as a flank
      attack, dealing ×`FLANK_BONUS` (1.5).
    - A unit struck by several foes takes every blow but strikes back at only one.
  - **`FormationProduction`**: one lane's wave build.
    - It snapshots its slots and width when a wave **starts** building, so a pool
      change applies to the next wave.
    - It fills per a composition preset: Grems; Brute front + grems; Brutes.
    - It emits `wave_full` when the next unit won't fit, and sends the wave as one
      squad, manually or automatically.
- **`presentation/skirmish/formation/`**:
  - `formation_skirmish.tscn` / **`FormationSkirmishScene`** has two lanes and one
    clock.
  - **`SkirmishSquadLayer`** draws footprint-sized units offset across the route (using
    `SkirmishRoute.normal_at`), with flank-hit flashes and squad selection.
  - The HUD has:
    - the slot pool, shown as −/+ per lane
    - per-lane width, composition, a wave preview and Send wave (S / Shift+S)
    - auto departure
    - pause on full (Send resumes the game)
    - kingdom squads
    - A/H/R orders for the selected squad
    - an event log

## Scenarios (Given/When/Then)

```
Scenario: A formation lays out footprints front-first
  Given width 4 and 8 slots (2 ranks)
  When a 2x2 brute is placed preferring the centre, then grems
  Then the brute takes ranks 0-1, columns 1-2, and grems fill the remaining 4 cells
  And the formation is full when no free 1x1 cell remains

Scenario: The slot pool splits across lanes
  Given 8 slots and lanes capped at 20 and 16
  When lane c asks for 6 while lane k holds 3
  Then lane c gets 5 (only 5 are free) and the total never exceeds 8

Scenario: Front rank fights; the rank behind steps up
  Given a 1-wide squad of two grems meeting a militia
  Then only the front grem fights; when it dies the second steps up and fights

Scenario: A wider line wraps onto the flanks
  Given a 5-wide grem line meeting a 3-wide militia line
  Then the three overlapping grems fight frontally and the two outer grems strike the end
  militia as flank hits for 1.5x damage

Scenario: A pool change applies to the next wave
  Given lane c building a 5-slot wave
  When its assignment drops to 3
  Then the current wave still fills 5, and the next wave is built for 3

Scenario: The spec 21 duel still holds
  Given a 1-grem squad and a 1-militia squad
  Then the militia wins on 2 hp, 3 s after engaging, and runs replay identically
```

## Test-first order

1. `tests/sim/skirmish/formation/test_skirmish_formation.gd`
2. `tests/sim/skirmish/formation/test_skirmish_slot_pool.gd`
3. `tests/sim/skirmish/formation/test_skirmish_squad.gd`
4. `tests/sim/skirmish/formation/test_formation_simulation.gd`
5. `tests/sim/skirmish/formation/test_formation_production.gd`
6. `tests/presentation/skirmish/test_skirmish_route.gd` (`normal_at`)
7. Scene smoke tests (`tests/presentation/skirmish/test_formation_skirmish_scene.gd`)
8. Manual: the user plays it and reports on frontline width, flanking, step-up and pool
   splitting.

## Outcome

**Playtest 1 (2026-10-01), the user's verdict:**
1. **Wide versus deep is a real choice.** That came through the flanking, and through
   watching grems die alongside a brute that tanked two enemies for far longer.
2. **Flanking wasn't noticeable on the board.** It should be evident in the detail view
   (Inspector Viewport), where units would visibly move round the flank.
3. **Step-up wasn't visible either.** Ranks are 0.3 cells apart, so it's a shuffle; it
   also belongs in the detail view.
4. **The pool and wave-building controls were hard to read and clunky.** Adjusting
   width meant waiting for the current wave to fill its old shape. "Brute front +
   grems" put a grem beside the brute when the brute was expected to lead.
   - The fix is **Decision 42**: paint the wave template per lane; a change takes
     effect immediately, built units fold in, and leftovers are banked in a reserve.
   - The oversized debug units should later stay within their tile (fine for now).

## Round 2: wave painter (Decision 42)

Playtest 1's clunky controls are replaced:
- **`WaveTemplate`** (`sim/skirmish/formation/wave_template.gd`): a lane's wave, painted
  unit by unit into a grid up to the lane's width by 4 ranks.
  - The painted units *are* the shape.
  - `paint` replaces whatever it overlaps and never exceeds the lane's pool share;
    `erase` removes a unit.
  - `ordered` gives the front-first order; `trim_to` removes from the back.
  - `layout` normalises columns for spawning; `default_line` is the starting template.
- **`FormationProduction`** now builds toward the template. `set_template` applies at
  once:
  - built units **fold** into matching places, front-first
  - leftovers are **banked** in the lane's reserve, which fills matching places
    instantly before anything new is built
- **`FormationLane`** holds one lane's simulation, production, template and brush, and
  the kingdom's line. Painting and pool changes go through it.
- **`WavePainter`**, in the HUD:
  - an 8×4 grid with the front at the top and columns past the lane's width shaded
  - template outlines, built units filled, and the unit being built filling with its
    progress
  - left click or drag paints with the lane's brush (Grem 1×1, Brute 2×2, Erase), and
    right click erases
  - a readout: cells used/share, built, reserve
- The pool's −/+ now takes effect at once: a lane that loses slots is trimmed from the
  back, and its displaced units are banked.
- Width −/+, the composition presets and `SkirmishFormation` are removed.

A scripted run showed each step:
1. A brute painted at the front centre, with two grems behind it, leads the wave.
2. Repainting mid-build as a five-grem line folded the built grem in and banked the
   brute (reserve 1).
3. After sending, painting a brute again filled it instantly from the reserve.

## Notes / open questions

- Orders are per wave. Pulling back a single unit is left out for now.
- Brute build time is twice a grem's in the test; real costs come with the economy.
- Flanking uses the bonus only. Morale and directional effects wait for the Encounter
  model.

## Rubric answers (qualitative, spec-baseline)

- `single-noun-phrase`: `skirmish_formation.gd`, `skirmish_slot_pool.gd`,
  `skirmish_squad.gd`, `formation_simulation.gd`, `formation_production.gd`,
  `skirmish_squad_layer.gd`, `formation_skirmish_scene.gd`.
- `ocp-extension-point`: a new composition preset is one enum value plus its fill
  order; a new footprint is data.
- `lsp-contract-scope`: not applicable.
- `isp-fit`: the simulation exposes spawn_squad, order, step and accessors.
- `dip-direction`: `sim/` is RefCounted only and reads `content/`; `presentation/` reads
  `sim/`.

## Structured rubric notes

- `spec-type-declared`: `hybrid`. The sim uses TDD; the scene is glue with smoke tests
  and a manual check.
- `tdd-plan-present`: see Scenarios and Test-first order.
- `no-drift`: implements Decisions 40 and 41 as a feel test.
- `commit-classification-plan`:
  - `docs:` spec 22
  - `feat(content):` footprints, the brute and the two-lane map
  - `feat(sim):` formation, pool, squad, simulation and production
  - `feat(presentation):` the formation scene
