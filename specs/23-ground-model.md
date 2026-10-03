---
spec_type: hybrid
status: active
parent_spec: ../Breach — Reverse Tower Defense Design Spec.md
---

# Ground Model

## Purpose

Decisions 53, 54, 56 and 57 replace the side-on capacity trio (stability, max height,
max width) with a ground that can be dug, built on and brought down:
- **materials**, each with a dig and climb difficulty, a weight, a span and whether it
  is loose
- per terrain: a **bearing**, a foundation maximum, a **dig depth**, a water table and
  **strata** bands
- per tile: an **elevation**, with the surface running through partial cells, and a map
  **ceiling** (Decision 56)

This spec puts that data into the designer, the import and Godot, and adds the
sim-side surface model. Strata generation, digging, support and collapse come later and
build on it.

The side-on structure editor still uses the old trio until the plan editor (Decision
52) replaces it, so those fields stay, labelled legacy.

## Round 1: materials and strata (Decisions 53, 54, 57)

- **Content:**
  - `content/designer/terrain.json` gains a `materials` list (Soil, Peat, Sand, Gravel,
    Clay, Rock, Ore), and every terrain gains `bearing`, `foundation_max`, `dig_depth`,
    `water_table` (`{min, max}` cells below the surface, or null) and `strata`
    (`[{material, min, max}]`, surface first).
  - Placeholder values, to tune: fields bear 4 (foundations to 8), dig 32, water 12–24,
    strata soil 2–4, clay 4–8, rock; a mountain bears 8 with rock below a thin soil.
- **Godot:**
  - New `MaterialDef` and `StratumDef`.
  - `TerrainDef` gains the ground fields; `TerrainLibraryDef` gains `materials`,
    `material(id)`, and ground validation: foundations can't lower bearing, a water table
    has both bounds or neither, and strata name known materials with min ≤ max.
  - `DesignerLibraryImporter` reads them; a terrain saved before the ground model has no
    water table or strata. Re-imports stay byte-identical (stable sub-resource ids).
  - The map viewer's tile details show the ground and strata.
- **Designer:**
  - The Terrain view gains a **Materials** list and inspector, and a **Ground** section
    on each terrain with a strata editor (material, least and most cells per band; add
    and remove bands).
  - Existing libraries migrate: seeded terrains get their ground, and custom ones (such
    as Hilly) a generic ground. A material in use by strata can't be removed.

```
Scenario: A terrain's strata name known materials
  Given a library with Soil and Rock
  When a terrain's strata name Soil, Rock and Magma
  Then validation reports "stratum of unknown material 'Magma'"

Scenario: Foundations can't lower bearing
  Given a terrain bearing 4
  When its foundation maximum is 2
  Then validation reports it

Scenario: The ground imports from the designer
  Given terrain.json with materials and a desert's ground
  Then the desert has bearing 3, foundations to 6, dig 32, water 20-32, strata Sand, Rock
  And a terrain saved before the ground model has no water table and no strata

Scenario: The viewer shows a tile's ground
  Given a fields tile
  Then its details read "ground: bearing 4 (foundations 8) · dig 32 · water 12-24"
  And "strata: Soil, Clay, Rock"
```

## Round 2: elevation and the surface (Decision 56)

- **Data:**
  - `TileDef.elevation` (cells; -1 = the terrain's default), `TerrainDef.default_elevation`
    and `MapLayoutDef.ceiling` (default 64), with `MapLayoutDef.elevation_at(cell)`.
  - Seeded heights, stylised and placeholder: swamp, water and ravine 0, fields and desert
    2, forest 3, Hilly 4, rocky 6, snow 8. A mountain is 64, the default ceiling, so it
    is capped and blocks flight (Decision 60).
  - The import reads `elevation_override` per tile, `ceiling` per map and
    `default_elevation` per terrain.
- **`GroundSurface`** (`sim/ground/ground_surface.gd`, pure):
  - It interpolates each cell column's surface between tile centres, staying level
    beyond the outermost ones.
  - The surface cell is the highest cell holding any ground. Its shape is the four corner
    heights in quarters (NW, NE, SE, SW).
  - `dig_fraction` is the part of that cell left to dig.
  - `is_cliff` is a step of more than one cell between neighbouring columns.
  - `is_capped` is ground at or above the ceiling.
- **Designer:**
  - Each terrain has a default elevation (in the Ground section).
  - Each tile has an elevation override, with a warning at or above the ceiling.
  - The map has a Ceiling field in the toolbar.
  - A ▲ badge shows on tiles whose height differs from the base terrain's, and is
    filled when the tile is capped.
- **Viewer:** the tile details show the elevation and flag it at the ceiling. Shading the
  board waits for the 3D ground.

```
Scenario: A slope runs through partial cells
  Given two tiles at elevations 0 and 4 (a quarter of a cell per cell)
  Then the column 8 cells in has its surface cell at level 0, shaped [0, 1, 1, 0]
  And digging it removes an eighth of a cell

Scenario: Flat ground has full surface cells just below its height
  Given tiles at elevation 4
  Then each column's surface cell is level 3, full

Scenario: Cliffs and the ceiling
  Given tiles at 0 and 48
  Then neighbouring columns between them are cliffs; at 0 and 16 they are not
  And a tile at 80 under a ceiling of 64 is capped

Scenario: A tile's elevation overrides its terrain's
  Given Hilly at default elevation 8 and one tile set to 20
  Then elevation_at gives 8 and 20
```

A scripted browser run set a tile on the demo map to 70. It showed the ceiling warning,
a filled ▲70 badge, and `elevation: 70` in the saved draft. Badges appear only on the
six tiles whose height differs from the base terrain's (water 0, forest 3, mountain 48 at the time; 64 since Decision 60).

## Round 3 (next): relief and carved channels (Decision 59)

- `TerrainDef` gains relief amplitude and scale; maps gain a seed and carved features
  (a path, width, depth and water level).
- `GroundSurface` adds seeded relief and carving to the tile height.
- The designer gains relief per terrain, the seed (lock and re-roll), and a channel tool
  for rivers, ditches and moats.

## Round 4: liquids, traits and heat (Decisions 62-64)

Built before round 3, because it changes round 1's data.
- **Liquids are materials that flow** (Decision 64). Water has flows 3 at 15°. Lava has
  flows 1 and glows 1 at 1200°. There is no separate liquid library.
- **Liquid bodies:** `TerrainDef.water_table` becomes `liquids`, a list of
  `LiquidBodyDef` (a flowing material, a depth range, a chance, a surface chance). Seeds:
  - fields: water 12–24
  - rocky: water 16–32, lava 32–48 at 20%
  - mountain: lava 24–48 at 35%, reaching the surface 5% of the time
  - desert: water at 30%
  - swamp: water 0–2, at the surface half the time
- **Rated traits (Decision 64)** meet in ability-and-demand pairs: dig_difficulty
  against burrower, climb_difficulty against climber, glows against light_blind or
  darksight.
  - `MaterialDef` carries `traits` (name → level), with `trait_level(id)` and
    `is_liquid()`, plus a `temperature`.
  - Its dig and climb difficulty fields become traits.
- **Heat (Decision 63):** `heat_transitions` (`HeatTransitionDef`: above or below a
  temperature, becomes another material or gains a trait). Seeded transitions:
  - peat gains burning above 250
  - timber (a new material, for walls) gains burning above 300
  - rock becomes lava above 1100
  - lava becomes rock below 700
- **Migration:** a saved water table, loose flag, difficulty field or separate liquid
  list all import and migrate.
- **Lava vent** joins the natural features.
- **Validation:** liquid bodies name a known material that flows, with chances from 0
  to 1. A transition becomes a known material, or gains a trait.
- **Designer:**
  - Materials list their traits with levels and their temperature, and flowing ones
    read "A liquid (flows N)".
  - Each material has a traits editor (name and level) and a heat editor.
  - Each terrain's Ground section has a liquid-bodies editor offering flowing
    materials.
- **Viewer:** tile details list a terrain's liquid bodies ("liquids: Water 12-24").

```
Scenario: A transition reads as its rule
  Given rock with "above 1100: becomes LAVA" and timber with "above 300: gains burning"
  Then each validates, and lava's "below 700: becomes ROCK" does too

Scenario: Liquid bodies are checked
  Given a mountain with a body of Mercury, a body of Rock, or a surface chance of 1.5
  Then validation reports the unknown material, that Rock doesn't flow, or the chance

Scenario: Traits have levels
  Given lava with flows 1 and glows 2
  Then it is a liquid, glows at 2, and has darksight 0

Scenario: An old water table migrates
  Given a terrain saved with water_table {min 12, max 24}
  Then it imports as a water body 12-24, chance 1
```

A scripted browser run showed Lava as a material (flows 1, glows 1, 1200°), with
"below 700°: becomes Rock" and its bodies under Rocky and Mountain. The repo library
migrated: no water tables or separate liquids left.

## Test-first order

1. `tests/content/definitions/test_terrain_ground.gd`
2. `tests/content/import/test_designer_ground_import.gd`
3. `tests/presentation/test_map_details.gd` (the ground lines, and elevation)
4. Round 4: `tests/content/definitions/test_terrain_liquids.gd`, and the liquid and migration
   cases in `test_designer_ground_import.gd`
5. `tests/content/definitions/test_map_elevation.gd`, `tests/sim/ground/test_ground_surface.gd`,
   `tests/content/import/test_designer_elevation_import.gd` (round 2)
6. Designer: scripted browser runs of the Terrain view (materials, ground, strata) and
   the Lanes view (elevation, ceiling).
7. Manual: the user tunes the placeholder values in the designer.

## Notes / open questions

- Strata are ranges until generation picks thicknesses from the map's seed (Decision 54).
- Dig depth is in cells now; the legacy "default dig depth (basements)" stays with the
  side-on editor.
- Ore veins and wells shaping strata (Decision 54) come with generation.

## Rubric answers (qualitative, spec-baseline)

- `single-noun-phrase`: `material_def.gd` (a material), `stratum_def.gd` (a band of
  strata), `ground_surface.gd` (the ground's surface),
  `liquid_body_def.gd` (a body of liquid), `heat_transition_def.gd` (a heat transition); `liquid_def.gd` was folded into materials.
- `ocp-extension-point`: a new material or terrain is data in `terrain.json`.
- `lsp-contract-scope`: not applicable.
- `isp-fit`: `TerrainLibraryDef` adds one lookup, `material(id)`.
- `dip-direction`: `content/` definitions; `sim/ground/` and `presentation/` read them.

## Structured rubric notes

- `spec-type-declared`: `hybrid` (schema and tooling).
- `tdd-plan-present`: see Scenarios and Test-first order.
- `no-drift`: implements Decisions 53, 54 and 57's data, and Decision 56 in round 2.
- `commit-classification-plan`: `docs:` this spec; `feat:` the schema, import, viewer
  and designer; `chore:` the Gate 1 row.
