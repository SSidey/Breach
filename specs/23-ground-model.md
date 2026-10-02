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

Next, on its own stacked branch:
- `TileDef.elevation` (cells; -1 = the terrain's default), `TerrainDef.default_elevation`
  and the map's `ceiling` (default 64).
- A sim-side ground surface: each cell column's surface height interpolated from tile
  elevations, the surface cell's corner heights in quarters, the fraction left to dig, and
  cliffs (a step over one cell).
- The designer paints elevation; the viewer shades it.

## Test-first order

1. `tests/content/definitions/test_terrain_ground.gd`
2. `tests/content/import/test_designer_ground_import.gd`
3. `tests/presentation/test_map_details.gd` (the ground lines)
4. Designer: a scripted browser run of the Terrain view (materials, ground, strata).
5. Manual: the user tunes the placeholder values in the designer.

## Notes / open questions

- Strata are ranges until generation picks thicknesses from the map's seed (Decision 54).
- Dig depth is in cells now; the legacy "default dig depth (basements)" stays with the
  side-on editor.
- Ore veins and wells shaping strata (Decision 54) come with generation.

## Rubric answers (qualitative, spec-baseline)

- `single-noun-phrase`: `material_def.gd` (a material), `stratum_def.gd` (a band of
  strata).
- `ocp-extension-point`: a new material or terrain is data in `terrain.json`.
- `lsp-contract-scope`: not applicable.
- `isp-fit`: `TerrainLibraryDef` adds one lookup, `material(id)`.
- `dip-direction`: `content/` definitions only; `presentation/` reads them.

## Structured rubric notes

- `spec-type-declared`: `hybrid` (schema and tooling).
- `tdd-plan-present`: see Scenarios and Test-first order.
- `no-drift`: implements Decisions 53, 54 and 57's data; Decision 56 in round 2.
- `commit-classification-plan`: `docs:` this spec; `feat:` the schema, import, viewer
  and designer; `chore:` the Gate 1 row.
