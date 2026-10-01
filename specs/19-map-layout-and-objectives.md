---
spec_type: hybrid
status: active
parent_spec: ../Breach — Reverse Tower Defense Design Spec.md
---

# Map Layout, Terrain Library and Objectives

## Purpose

The import (specs/16) skips every designer layer that has no schema yet, which is why
saving warns "not imported yet: tiles, roads, terrain_library, feature_library,
loss_criteria, structures, link routes". This item gives every layer except structures
(spec 20) real schema, imports it, and draws it in the map viewer (specs/18):
- the grid; tiles (terrain, feature, bridge/drawbridge, capacity overrides, upgrades)
- roads and link route geometry
- critical assets and loss groups

**One shared terrain library** (the user's choice, Decision 32). Terrain and feature
definitions live in `content/terrain/terrain_library.tres`, generated from the designer's
`content/designer/terrain.json`. Each map's layout *references* that resource rather than
copying it, so editing a terrain in the designer reaches every map without re-saving them.
The library import refuses any edit that would drop a terrain or feature a saved map
still uses, so a library change can never break a map.

## Components

- **Terrain library** (`content/definitions/`):
  - `TerrainDef`:
    - id, display_name, glyph, color, can_be_base, needs_bridge, move_cost
    - blocks_unit_classes, split from the designer's comma list
    - default_stability, default_max_height, default_max_width, default_max_length,
      default_max_depth
  - `TerrainFeatureDef`: id, display_name, glyph, effect_notes.
  - `TerrainLibraryDef`:
    - terrains, features, road_move_multiplier
    - `terrain(id)` and `feature(id)` lookups
    - `validate()`: ids are non-empty and unique; at least one base terrain;
      move_cost >= 0; road_move_multiplier >= 0.
- **Layout** (`content/definitions/`):
  - `BridgeDef`: owning_faction_id, hp, demolishable_by_owner, drawbridge_node_id ("" is
    a plain bridge), raised.
  - `TileDef`:
    - `cell` (col, row), `terrain_id` ("" means the map default), `feature_id`, `bridge`
    - capacity overrides `stability`, `max_height`, `max_width`, `max_depth`, where -1
      means the terrain default; `effective_capacity(library, default_terrain_id)`
    - `upgrade_slots`, `upgrade_ids`
  - `RoadSegmentDef`: a, b (8-neighbour cells).
  - `RouteDef`: node_a_id, node_b_id, cells, cost. This is a link's initial geometry
    (Decision 26).
  - `MapLayoutDef`:
    - cols, rows, cell_size, default_terrain_id
    - `terrain_library`, an external reference to the shared resource
    - tiles, roads, routes; `tile_at(cell)`, `terrain_id_at(cell)`
    - `validate(node_ids)` checks:
      - the grid is > 0
      - every tile is inside the grid, with no duplicates
      - every terrain and feature id is in the library, and the default terrain is a
        base terrain
      - capacity overrides are -1 or ≥ 0, and upgrades fit their slots
      - roads join in-grid 8-neighbours, with no duplicates
      - bridges only sit on `needs_bridge` terrain, and a drawbridge's node exists
      - route cells are contiguous 8-neighbours inside the grid, between real nodes
- **Objectives:**
  - `NodeDef.is_critical_asset`.
  - `LossGroupDef`: faction_id, display_name, rule (ANY/ALL), node_ids.
    `validate(node_ids, faction_ids, critical_ids)` requires at least one node, every
    node to exist and be a critical asset, and the faction to be in the roster. A faction
    is knocked out when any one of its groups triggers.
- **`MapDef`**:
  - gains `layout` (null is allowed, as for the hand-authored `p_f_F_c.tres`) and
    `loss_groups`
  - `validate()` delegates to both
- **Import:**
  - `DesignerLibraryImporter` (terrain.json → `TerrainLibraryDef`, with stable
    sub-resource ids).
    - `in_use_problems(library, maps_src_dir)` scans every saved designer map for the
      terrain and feature ids it uses; any the library lacks are errors that name the
      map.
    - `DesignerLibraryImport.run()` writes `content/terrain/terrain_library.tres`, but
      only when there are no errors.
    - `tools/import_designer_library.gd` is the headless entry point.
  - `DesignerLayoutBuilder` builds the layout from the export and references the loaded
    shared library.
    - Tiles with `terrain_is_base` get `terrain_id` "".
    - Routes come from `links[].route` and `route_cost`, and links with no route get
      none.
    - A terrain or feature missing from the library is an error.
  - The node builder copies `is_critical_asset`, and loss groups are read from
    `loss_criteria`.
  - The "not imported yet" warning now covers structure sections only (spec 20).
- **Server:**
  - `PUT /api/libraries/terrain` also runs the library import and returns its result.
  - Saving a map imports the library first when its `.tres` is missing or older than
    `terrain.json`.
  - `API_VERSION` is now 3.
- **Viewer** (new model fields and draw passes; the existing ones are unchanged):
  - The frame is the full designer grid.
  - Every cell is filled with its terrain colour, with feature glyphs, roads, bridges
    and drawbridges on top.
  - Lanes and edges follow their routes, falling back to straight lines when there's no
    route.
  - Critical assets get a ring.
  - Clicking an empty cell shows its tile details.

## Scenarios (Given/When/Then)

```
Scenario: The terrain library validates its entries
  Given terrains with a duplicate id, or no base terrain, or a negative move cost
  When validate() is called
  Then each problem is an error; the committed library validates clean

Scenario: A tile's capacity falls back to its terrain
  Given FOREST (default stability 2) and a tile on FOREST with stability -1 and max_width 4
  Then effective_capacity is stability 2 and max_width 4

Scenario: Layout validation catches bad geometry and references
  Given a tile outside the grid, a duplicate tile, an unknown terrain or feature,
        a road between non-neighbours, a bridge on fields, a drawbridge for an unknown node,
        or a route with a gap
  When validate(node_ids) is called
  Then each is an error naming the cell or ids

Scenario: Loss groups reference critical assets of rostered factions
  Given a group with no nodes, an unknown node, a non-critical node, or an unknown faction
  Then each is an error; a map with a null layout and no loss groups is still valid

Scenario: The library imports from the designer library
  Given content/designer/terrain.json
  When imported
  Then there is one TerrainDef per terrain and one TerrainFeatureDef per feature, with the
  designer's values, blocks_unit_classes split into ids, and it validates

Scenario: The library import refuses to drop a terrain a map uses
  Given a saved map using FOREST and a library without FOREST
  When in_use_problems is checked
  Then there is an error naming FOREST and that map, and nothing is written

Scenario: A designer map imports its layout and objectives
  Given the designer's full export of the demo map
  When imported
  Then the layout has its grid and default terrain, a tile per explicit cell (terrain, feature,
  bridge, upgrades), the roads, a route per link, p and c are critical assets,
  there are loss groups for player and the_kingdom, and it all validates
  And the warning lists only structure sections

Scenario: An unknown terrain is an import error
  Given a tile whose terrain is not in the shared library
  When imported
  Then errors name the terrain and the cell

Scenario: The viewer draws the layout
  Given a map with a layout
  Then bounds are the whole grid plus one cell, every cell has its terrain colour,
  roads and bridges are listed, a lane step with a route follows the route's cells,
  one without a route is a straight line, markers carry the critical flag,
  and cell_at finds a cell from a point
```

## Test-first order

1. `test_terrain_library_def.gd`
2. `test_tile_def.gd`, `test_map_layout_def.gd`
3. `test_loss_group_def.gd`, then `MapDef` delegation (`test_map_def_layout.gd`)
4. `test_designer_library_importer.gd`
5. The importer (`test_designer_layout_import.gd`), against
   `tests/fixtures/designer/layout_map.designer.json` (a real designer export) and
   `tests/fixtures/designer/terrain.json`.
6. The view model and details (additions to their existing suites).
7. Python: the library import on PUT, and ordering on save.
8. Manual:
   - headless library and map imports
   - windowed viewer screenshots
   - a terrain colour change reaching a map with no re-save

## Notes / open questions

- Upgrade ids stay strings until an upgrade library exists.
- Movement, capacity and bridge rules are data here; no `sim/` code reads them yet
  (milestone 2).
- Faction colour still follows roster order (spec 18's open question).

## Rubric answers (qualitative, spec-baseline)

- `single-noun-phrase`: each new definition file is one noun (`terrain_def.gd`,
  `tile_def.gd`, `map_layout_def.gd`, …).
- `ocp-extension-point`: spec 20's structures add a builder and definitions. The layout
  and library classes don't change.
- `lsp-contract-scope`: not applicable.
- `isp-fit`: each definition exposes `validate` plus at most a couple of lookups.
- `dip-direction`: `content/` only, plus `presentation/` reading it. Nothing in `sim/`.

## Structured rubric notes

- `spec-type-declared`: `hybrid`. Schema and importers use TDD; the tools, the server
  hook and the drawing are glue (smoke tests plus manual checks).
- `tdd-plan-present`: see Scenarios and Test-first order.
- `no-drift`: implements Decision 32.
- `commit-classification-plan`: `docs:` spec; `feat(content):` for the library schema,
  layout schema, objectives, library import and layout import; `feat(tools):` for the
  server; `feat(presentation):` for the viewer layers; `docs:` for Decision 32.
