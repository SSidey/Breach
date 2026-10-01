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

## Round 3: painting to the direction of travel (Decision 43)

From painting waves in round 2:
- **`WavePainter`** faces the direction of travel: the front rank is the right-hand
  column and formation columns run top to bottom (4 wide × 8 tall).
  - Pressing an empty cell paints with the brush, pressing a filled one erases it; a drag
    keeps doing whichever the press started. Right click still erases.
- **No per-lane share.** The pool records what each lane has painted. A lane may paint
  into its own cells plus any free slot, so erasing in one lane frees slots for the other
  at once. The pool −/+ and `trim_to`-on-share-change are gone from the scene.
- **One brush** for both lanes, with hotkeys **1** grem, **2** brute, **E** erase.
- **Player presets** (`WavePresets`, `WavePresetStore`):
  - "Save shape" stores the lane's shape as "Preset N"; the game ships none.
  - "Apply" puts a saved preset on any lane, front-first, dropping what no longer fits
    the lane's width or the slots it can reach.
  - Presets are kept in `user://formation_presets.json` between sessions.
- `WaveTemplate` pulls an overhanging footprint back inside the grid (a brute clicked on
  the last column lands one column in) and reports whether a cell is occupied;
  `WavePresets.line` replaces `default_line`.

A scripted run with real painter clicks, one per frame:
1. Two clicks on lane k's line erased two grems and freed 2 slots.
2. Lane c was cleared, then painted as a brute at the front centre, grems behind it and
   one on the flank, using the freed slots (c 7 · k 1 · free 0).
3. That shape was saved as Preset 1 and applied to lane k, which kept only what its one
   slot and 4-wide lane allow: a single grem.

## Round 4: reinforcement and kept progress (Decision 44)

From playing round 3:
- **Reinforcements join a fight from the back** (`FormationContact`).
  - A wave that reaches a friendly squad in combat stops at its back rank and joins it as
    rear ranks, which step up as the front falls. It never engages the enemy on its own.
  - A wave reaching a friendly squad that isn't fighting queues behind it; squads never
    pass through their own side.
  - A wider reinforcement centres on the same line, and its outer columns step up to
    extend the front.
- **Build progress is kept per unit type.** A partial send or a reshape no longer resets
  the unit underway.

A scripted run against a durable militia line showed it working:
1. A five-grem wave locked with the militia.
2. A second wave of three, sent part-built, arrived behind it and joined as a rear rank:
   8 units, ranks `[0,0,0,0,0,1,1,1]`, still 5 fighters.

## Round 5a: the domain builds (Decision 45)

Production moves from the lane to the domain:
- **`DomainProduction`** holds builders as a count per unit type. Each builds one unit at
  a time at the unit's new `UnitDef.build_seconds` (grem 2, brute 4, militia 5), so two
  grem builders build two grems at once.
  - A build claims a lane, by lane and type, when it starts, under the player's
    **sharing rule**: a lane first (priority), or round robin.
  - With nothing wanted it builds into the **domain reserve**, up to a cap of 6.
  - The reserve fills matching places in any lane at once. Banked units, and builds whose
    place vanished, may exceed the cap.
- **`FormationProduction`** is now just the lane's wave: it fills, folds, sends, and
  announces when full. Its leftovers bank into the domain.
- **`FormationBattle`** owns the lanes, both domains and the pool, and the scene is glue
  over it. The kingdom has its own domain: 2 militia builders, round robin, no reserve.
- **HUD:** builder −/+ rows showing each build's progress and lane, a "Share units"
  picker, and the reserve shown as n/cap. The painter fills each place a builder is
  working toward.

A scripted run under round robin:
1. The 2 grem builders filled lanes c and k in turn. The brute builder, with no brute
   wanted, built into the reserve.
2. Clearing both templates banked their grems. The builds under way finished into the
   reserve (8, over the cap of 6), and then no new builds started.

## Round 5b: positions, the spitter and re-forming (Decision 46)

- **Preferred positions.** `UnitDef.preferred_position` (front, mid or back) and
  `position_priority` set a unit's claim to a forward place: brute front 2, grem front
  1, militia front 1, spitter back 1.
- **Re-forming** (`FormationShuffle`).
  - After a wave joins a fight, a unit with a stronger claim steps forward one rank past
    the one-deep units directly ahead in its columns. Those units take its back row.
  - A swap takes one rank at the slowest involved unit's speed: 0.6 s for grems, 0.9 s
    with a brute. Terrain factor is 1 for now.
  - Until a swap completes the passed units keep their places and keep fighting, so the
    front is never given up. A death cancels the swap.
  - Units' route distances include swap progress, so the view slides them.
- **The spitter** (`grem_spitter`) is the first ranged unit: hp 12, dmg 4, range 5
  ranks, built in 3 s.
  - It strikes the nearest enemy in range from anywhere in its squad, moving or
    fighting, with no flank bonus, and emits `spat`.
  - In the front rank of an engaged squad it fights as melee.
- **Presets** key units by kind (grem, brute, spitter); older light/heavy presets still
  load.
- **HUD:**
  - Brush 3 paints a spitter, and there is a spitter builder.
  - The painter colours places by band: amber front, teal back.
  - The squad layer marks ranged units with a dot and draws each spit as a line.

A scripted run against a durable militia line:
1. A brute and two spitters joined a 3-grem fight.
2. The brute swapped past the two grems in its columns over about 0.9 s and now leads.
3. The spitters stayed in the back rank, spitting at the militia front.

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
