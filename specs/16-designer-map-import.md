---
spec_type: hybrid
status: active
parent_spec: ../Breach — Reverse Tower Defense Design Spec.md
---

# Designer Map Import (JSON → MapDef)

## Purpose

The Lane Tile Designer (a standalone HTML prototype) is now the primary way maps are
authored, but nothing in Godot reads its output. This is the first of four items that
get designer maps rendered in Godot (milestone 1: a map viewer; see Decision 29 once
recorded). It imports the designer's **Export JSON** into a `MapDef`. It covers every
part of the export that already has real schema:
- nodes, including garrison units and `hidden_from_faction_ids`
- factions and relations
- links, as lanes plus `MapEdgeDef`s

Prototype-only layers (tiles, roads, route geometry, structures, loss groups) are
reported as "not imported yet" and follow in specs 17 and 19.

**Why JSON → `.tres`, not via `.tscn`** (the user asked): `.tres` resources are what the
game loads. Converting through an authoring scene would need a scene-node twin for every
designer layer, plus conversion both ways. `content/authoring/`'s `.tscn` path stays as
it is for hand-placed maps; it isn't extended.

**Workflow:** in the designer, Export → Copy JSON, then save the text as
`content/maps_src/<name>.designer.json`. Import it with the editor button or headlessly,
producing `content/maps/<name>.tres`. An artifact can't write files, so copy-paste is the
ceiling.

## Components

- **`DesignerMapImporter`** (new, `content/import/designer_map_importer.gd`): pure
  static, with no `@tool` and no SceneTree dependency, the same shape as
  `MapSceneConverter`.
  - `import_map(data: Dictionary) -> DesignerMapImportResult`, with fields `map_def`,
    `errors` and `warnings`.
  - `import_file(json_path: String)` reads and parses the file, then calls
    `import_map`.
  - **Envelope:** `format == "breach-designer-map"` and `format_version == 1` are
    required; anything else is an error. The designer adds both to its export in this
    item.
  - **Nodes → `NodeDef`:**
    - `id`, `node_type` (ORIGIN/RESOURCE/FORT/NEUTRAL/WAYPOINT) and
      `owning_faction_id`.
    - `hidden_from_faction_ids`.
    - `position` = the centre of the node's grid cell. `cell_size` comes from the
      export, defaulting to 64 px.
    - Each `fields` key that names a real `NodeDef` property is copied. `resource_type`
      is converted from its name. Unknown keys become **warnings**, not errors.
    - `garrison` = number of `garrison_units`.
    - Each unit becomes a `GarrisonUnitDef`. An empty unit `faction_id` falls back to
      the node's owner, and if both are empty that's a contextual error.
  - **Factions → `FactionDef`:** `id` and `display_name`. The designer's stub profile
    fields are ignored.
  - **Relations → `FactionRelationDef`**, with the stance converted from its name.
  - **Lane derivation from links** (the user's rule: links already define routes and
    approach directions):
    1. **Home** = the first player-owned critical asset, else the first player-owned
       ORIGIN node. None → error.
    2. **Targets** = every other node that is a critical asset or an ORIGIN and isn't
       owned by the player.
    3. Each target gets **one lane**: the fewest-link path from home over the links
       (breadth-first, with ties broken by link order). Lane id `to_<target>`,
       `player_home_index = 0`. No path → error naming the target.
    4. Every link that isn't a consecutive pair in some lane becomes a **`MapEdgeDef`**.
       Links are the single source of topology.
    5. Nodes on no lane go to **`MapDef.off_lane_nodes`**, so nothing is dropped.
    - Shared nodes, such as the home, are the same `NodeDef` instance in each lane.
  - **Map scalars:** the designer has none, so the importer uses `p_f_F_c`'s values
    (`tick_duration_seconds` 1.5, thresholds [20, 45, 70, 90], decay 2) unless the JSON
    has a `sim` object with those keys.
  - **Prototype-only sections** (`tiles`, `roads`, `terrain_library`,
    `feature_library`, `loss_criteria`, per-node `structure`, link `route`) → one
    warning listing what isn't imported yet.
- **`MapDef.off_lane_nodes: Array[NodeDef] = []`** (new, additive): nodes that exist on
  the map but aren't on any lane path, e.g. side objectives, secret caches and branch
  waypoints.
  - They are included in `_all_node_ids()`, so edges may reference them.
  - Each is validated with `NodeDef.validate()`.
  - They go through the same faction cross-reference checks as lane nodes.
  - The default is empty, so `p_f_F_c.tres` is unchanged.
- **`NodeDef.NodeType.WAYPOINT`** (appended, never inserted, per the ordinal rule):
  Decision 25's candidate, now real. It is a routing point with no type-specific
  validation. `sim/capture_resolution.gd` only branches on RESOURCE/FORT, so it's
  unaffected.
- **`DesignerMapImport`** (new, `content/import/designer_map_import.gd`, a `@tool`
  Resource): `json_path` and `output_tres_path`, plus `@export_tool_button("Import")`.
  - It imports, prints warnings, runs `MapDef.validate()`, and `ResourceSaver.save`s
    only when there are no errors.
  - It is engine glue with a construction smoke test only, the same convention as
    `MapSceneRoot`.
- **`tools/import_designer_map.gd`** (new, `extends SceneTree`): the headless entry point.
  Run it as `godot --headless --script res://tools/import_designer_map.gd -- <json>
  <out.tres>`. It exits non-zero on errors.
- **Designer:** the export gains `format`, `format_version: 1` and `cell_size`, and
  `WAYPOINT` is no longer labelled prototype-only.

## Scenarios (Given/When/Then)

```
Scenario: A waypoint node validates with no type-specific fields
  Given a NodeDef with node_type WAYPOINT and an id
  When validate() is called
  Then it returns no errors (and WAYPOINT is the last NodeType ordinal)

Scenario: An edge may reference an off-lane node
  Given a valid MapDef with one lane and an off-lane node "cache", and an edge lane-node <-> "cache"
  When validate() is called
  Then it returns no errors

Scenario: Off-lane nodes are validated and cross-referenced
  Given an off-lane RESOURCE node with no yield, or owned by an unknown faction
  When MapDef.validate() is called
  Then it returns errors naming the problem

Scenario: Importing the demo map derives lanes from links
  Given the designer demo export (home p; targets c; links p-f, f-F, F-c, p-s2, s2-w1, w1-F)
  When import_map is called
  Then there is one lane p,f,F,c with player_home_index 0
  And the links p-s2, s2-w1, w1-F become edges
  And s2 and w1 are off-lane nodes
  And the result validates with no errors

Scenario: Positions come from grid cells
  Given a node at row 2, col 1 and cell_size 64
  When imported
  Then its position is (96, 160)

Scenario: Hidden status, garrison units and factions carry over
  Given a node hidden from "kingdom" with two garrison units, one with no faction_id
  When imported
  Then hidden_from_faction_ids is ["kingdom"], garrison is 2, and the faction-less unit takes the node owner's faction

Scenario: No player home is an error
  Given an export with no player-owned critical or origin node
  When imported
  Then errors mention the missing player home

Scenario: An unreachable target is an error but the node is kept
  Given an enemy origin with no link path from home
  When imported
  Then errors name that target, and the node is in off_lane_nodes

Scenario: Unknown node fields and prototype-only sections are warnings
  Given a node field "mystery" and a tiles section
  When imported
  Then warnings mention "mystery" and "tiles", and errors are unaffected

Scenario: A wrong format or version is rejected
  Given format_version 2 (or a missing format)
  When imported
  Then errors mention the format
```

## Test-first order

1. `NodeType.WAYPOINT` (`test_node_def.gd`).
2. `MapDef.off_lane_nodes` validation (`test_map_def_off_lane.gd`, new, which keeps
   `test_map_def.gd` under the file-size gate).
3. The importer, scenario by scenario (`tests/content/import/test_designer_map_importer.gd`),
   against fixtures in `tests/fixtures/designer/`.
4. Construction smoke test for `DesignerMapImport`.
5. Manual: import the designer's live demo export headlessly, validate the result, and
   re-import to confirm it's identical.

## Notes / open questions

- Choosing the home when there are several player-owned critical assets: this item
  takes the first. Multiple player homes interact with the loss-groups work in spec 17.
- Units still need `sim/` generalisation before an imported map is playable
  (milestone 2). `main.gd` keeps loading `p_f_F_c`.

## Rubric answers (qualitative, spec-baseline)

- `single-noun-phrase`: `designer_map_importer.gd` ("designer map importer"),
  `designer_map_import.gd` ("designer map import" settings/button),
  `import_designer_map.gd` (tool script).
- `ocp-extension-point`: specs 17 and 19 extend the importer with new private builders
  for layout and structures. The result type and entry points don't change.
- `lsp-contract-scope`: not applicable. No shared base or interface is involved.
- `isp-fit`: the importer exposes two public static functions. `MapDef` gains one
  export; `NodeDef` gains one enum value.
- `dip-direction`: `content/` only. It never references `sim/` or `presentation/`.

## Structured rubric notes

- `spec-type-declared`: `hybrid`. The importer and schema are code (TDD applies); the
  button and headless script are engine glue (smoke test plus manual check).
- `tdd-plan-present`: see Scenarios and Test-first order above.
- `no-drift`: realises Decision 25's WAYPOINT candidate. The additive
  `off_lane_nodes` stops imports from dropping nodes. Decision 29 records the pipeline.
- `commit-classification-plan`:
  - `docs:` spec 16
  - `feat(content):` WAYPOINT node type
  - `feat(content):` MapDef.off_lane_nodes
  - `feat(content):` designer map importer (+ fixtures)
  - `feat(content):` import button + headless tool
  - `docs:` Decision 29
  - `chore:` progress row
