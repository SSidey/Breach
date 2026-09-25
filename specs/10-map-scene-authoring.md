---
spec_type: hybrid
status: active
parent_spec: ../Breach — Reverse Tower Defense Design Spec.md
---

# Map Scene Authoring Tool

## Purpose

Replaces hand-editing `content/maps/*.tres` as raw text (sub_resource blocks, `Vector2`
literals typed by hand, no visual feedback) with authoring a map as a `.tscn` scene in
Godot's 2D viewport — drag-and-drop node placement, undo/redo, and snapping all free
from the engine — then converting that scene tree into the existing `MapDef`/
`LaneDef`/`NodeDef` shape with one editor button. `content/maps/*.tres` stays the only
thing `main.gd` ever loads; this tool is purely additive authoring tooling and touches
no `sim/`/`presentation/` file. This is the hybrid split: the converter
(`MapSceneConverter`) is tooling-half (TDD applies); the `.tscn` scene shape and the
export-button UX are policy-half (no test plan beyond a construction smoke test, same
as `specs/09`'s own precedent for engine-glue).

**Explicit supersession:** the parent design spec's "Map structure and campaign
progression" section states "Build 2–3 hand-authored maps before any map-creator
tooling — prove the campaign feel first, generalize into a tool second." Only one map
(`p_f_F_c`) exists today. Decision 21 (below) records that the user explicitly chose to
build this tool now rather than defer it, superseding that guidance in spirit — the
original sentence is left untouched (append-only), with a forward-pointer note added
beside it.

## Components introduced

- `MapNodeMarker` (new, `content/authoring/map_node_marker.gd`, `class_name
  MapNodeMarker extends Marker2D`) — `@export var node_def: NodeDef` (the real domain
  resource, edited inline via the Inspector's expandable resource sub-editor; avoids
  duplicating `NodeDef`'s schema onto the marker), `@export var player_home: bool =
  false` (authoring-only topology flag — which node is home is a lane-level fact, not
  a `NodeDef` field). No `@tool` needed: a non-tool script's `@export var node_def:
  NodeDef` still renders as an expandable Inspector editor at edit time, and
  `Marker2D`'s native gizmo works regardless. No dedicated test — pure data holder,
  same precedent as not testing `NodeDef`/`LaneDef` construction itself.
- `MapLaneRoot` (new, `content/authoring/map_lane_root.gd`, `class_name MapLaneRoot
  extends Node2D`) — `@export var lane_id: String`. Children, in child order, are
  `MapNodeMarker`s; child order is the lane's path order, mirroring `LaneDef.nodes`'
  own "array order is the path" convention. No `@tool`, no dedicated test.
- `MapSceneConverter` (new, `content/authoring/map_scene_converter.gd`, `class_name
  MapSceneConverter`, no `@tool`) — pure static functions operating on a plain node
  tree, independently testable via a detached tree built with `.new()`/`add_child()`
  (no running SceneTree required, no `@tool`/editor dependency):
  `static func build_map_def(scene_root: Node2D) -> MapSceneConversionResult`, where
  `MapSceneConversionResult` (nested `class`, `extends RefCounted`) has `map_def:
  MapDef` and `errors: PackedStringArray`. Walks `scene_root`'s children as lanes (each
  a `MapLaneRoot`) and each lane's children as nodes (each a `MapNodeMarker`), in child
  order. For each marker: **`node_def.duplicate()`** before stamping `.position` and
  inserting into the built `LaneDef.nodes` — without this, saving the resulting
  `MapDef` with `ResourceSaver` could serialize the shared `NodeDef` instance as an
  `ext_resource` pointing back into the source `.tscn` instead of an inline
  `sub_resource`, silently creating a runtime dependency from the checked-in `.tres`
  back onto `content/maps_src/*.tscn`. Finds the single marker with `player_home ==
  true` per lane to set `LaneDef.player_home_index`; zero or multiple such markers
  appends an error to `errors` instead of throwing (GDScript has no exceptions).
  Scoped to topology only (`lanes`) — map-global scalar fields
  (`tick_duration_seconds` etc.) are the caller's job.
- `MapSceneRoot` (new, `content/authoring/map_scene_root.gd`, `class_name
  MapSceneRoot extends Node2D`, `@tool`) — `@export var tick_duration_seconds: float`,
  `@export var suspicion_tier_thresholds: Array[int]`, `@export var
  suspicion_decay_per_tick: int`, `@export var output_tres_path: String`. Children, in
  order, are `MapLaneRoot`s. `@export_tool_button("Export to .tres") var export_now:
  Callable = _on_export_pressed` — calls `MapSceneConverter.build_map_def(self)`,
  merges the scalar fields into the returned `MapDef`, runs the existing
  `MapDef.validate()`, and on success calls `ResourceSaver.save(map_def,
  output_tres_path)`; on any validation/conversion error, `push_error()`s each message
  and does not save. This is the first project-authored `@tool` script in the repo
  (only the gdUnit4 addon has its own). Engine-glue-only, same disclosed-limitation
  convention as `LaneView` — a construction smoke test only (`auto_free(MapSceneRoot
  .new())` constructs cleanly), the button/save path itself verified by manual
  playtest.
- `content/maps_src/p_f_F_c.tscn` (new) — the first authored scene, recreating the
  current map's topology/values, used to prove the round trip. Policy content, no test
  plan, same precedent as `content/maps/p_f_F_c.tres`'s own re-authoring in `specs/09`.

## Scenarios (Given/When/Then)

```gherkin
Scenario: A single lane with markers in child order converts to a matching LaneDef
  Given a MapLaneRoot with lane_id "main" and three MapNodeMarkers as children,
    each holding a distinct NodeDef and one marked player_home = true
  When MapSceneConverter.build_map_def(scene_root) is called with that lane as the
    only child of scene_root
  Then the resulting MapDef has exactly one LaneDef with id "main", nodes in the
    same order as the marker children, and player_home_index pointing at the
    marker that had player_home = true

Scenario: A marker's position is stamped onto its NodeDef without mutating the source
  Given a MapNodeMarker at position (128, 64) holding a NodeDef with position
    Vector2.ZERO
  When build_map_def converts it
  Then the NodeDef inside the resulting LaneDef has position (128, 64)
  And the original marker's own node_def.position is still Vector2.ZERO

Scenario: A lane with no player_home marker reports an error
  Given a MapLaneRoot whose MapNodeMarker children all have player_home = false
  When build_map_def converts it
  Then the result's errors is non-empty and names "player_home"
  And no exception is raised

Scenario: A lane with more than one player_home marker reports an error
  Given a MapLaneRoot with two MapNodeMarker children both marked player_home = true
  When build_map_def converts it
  Then the result's errors is non-empty and names "player_home"

Scenario: Multiple lanes convert in scene_root child order
  Given a scene_root with two MapLaneRoot children, each with one valid player_home
    marker
  When build_map_def converts it
  Then the resulting MapDef.lanes has two entries in the same order as the
    MapLaneRoot children
```

## Test-first order

1. Single-lane, in-order conversion with a valid `player_home` marker — red before
   `MapSceneConverter`/`MapSceneConversionResult` exist.
2. Position stamped via `duplicate()`, source marker's `node_def` left untouched.
3. Zero `player_home` markers → error naming `"player_home"`, no exception.
4. Multiple `player_home` markers → error naming `"player_home"`.
5. Multiple lanes preserve `scene_root` child order in `MapDef.lanes`.
6. `MapSceneRoot` construction smoke test (`auto_free(MapSceneRoot.new())`
   constructs without error) — the only coverage for the `@tool` file itself; the
   export-button/save path is manual-playtest-only, same convention as `LaneView`.

## Notes / open questions

- **Relationship to Phase 4 item 3 (placeholder visual map rendering, not yet built):**
  investigated and found little to share. `LaneView` will draw *interpolated moving
  units* between tick boundaries; this tool only needs to show *static* node placement
  at authoring time, for which `Marker2D`'s native gizmo plus the Scene tree dock
  (renaming markers to their `id`) is sufficient. No shared module is introduced; an
  optional lane-connection-line `_draw()` on `MapLaneRoot` (a single `draw_line()` per
  adjacent pair) is left as a future nice-to-have, not built here.
- Scene-tree node names (an author renaming a marker to `"p"`, `"f"`, `"F"`, ...) and
  `NodeDef.id` are two independent strings kept in sync manually by the author — no
  automated check ties them together in this item. A `_get_configuration_warnings()`
  on `MapNodeMarker` is a plausible later addition, not built now.
- `output_tres_path` is a plain exported string, not resolved/validated against the
  filesystem before saving — if it's wrong, `ResourceSaver.save()` simply fails or
  writes somewhere unexpected, caught by the round-trip verification step (diffing the
  regenerated `.tres` against the previous one) rather than by any code in this item.
- This item does not touch `main.gd`, `node_def.gd`, `lane_def.gd`, or `map_def.gd` at
  all — confirmed zero-touch to any pre-existing `.gd` file, so it sits outside the OCP
  shotgun-surgery gate regardless of its budget.

## Rubric answers (qualitative, spec-baseline)

- `single-noun-phrase`: `map_node_marker.gd` ("map node marker"), `map_lane_root.gd`
  ("map lane root"), `map_scene_converter.gd` ("map scene converter"),
  `map_scene_root.gd` ("map scene root") — each one noun phrase, one concern.
  Described together because they're one small, interdependent authoring-tool batch
  (mirrors `specs/09`'s own "authored and reviewed as one small batch" reasoning).
- `ocp-extension-point`: a future second map is a new `.tscn` scene authored against
  the existing `MapNodeMarker`/`MapLaneRoot`/`MapSceneRoot` shape — no code change. A
  future map-level scalar field is a new `@export` on `MapSceneRoot` plus its own
  merge line in `_on_export_pressed()`, same pattern as the existing scalar exports.
- `lsp-contract-scope`: not applicable — no shared base/interface introduced beyond
  Godot's own `Marker2D`/`Node2D`, used as-is with no overridden virtual contracts.
- `isp-fit`: `MapSceneConverter`'s public surface is one static method,
  `build_map_def`. `MapSceneRoot`'s public surface is its `@export` fields plus the
  one button-bound method. `MapNodeMarker`/`MapLaneRoot` expose only `@export` fields,
  no methods. All well under any ISP ceiling.
- `dip-direction`: `MapSceneConverter` depends on `NodeDef`/`LaneDef`/`MapDef` (the
  existing domain schema) and on the authoring-only `MapLaneRoot`/`MapNodeMarker`
  types — no dependency in the other direction; `sim/`/`presentation/` have no
  knowledge of anything under `content/authoring/`.

## Structured rubric notes

- `spec-type-declared`: `hybrid` — `MapSceneConverter`'s conversion logic is `code`
  (TDD applies); the `.tscn` scene shape, `MapSceneRoot`'s button/save UX, and
  `content/maps_src/p_f_F_c.tscn`'s content are policy (no test plan beyond the
  construction smoke test), matching `specs/09`'s own precedent for engine-glue.
- `tdd-plan-present`: see Scenarios and Test-first order above, for the tooling half.
- `no-drift`: not a plan item from the existing Phase 4 sequencing — introduced this
  session as a direct, explicit request, with the "2–3 hand-authored maps before
  tooling" supersession recorded as Decision 21 rather than silently ignored.
- `commit-classification-plan`: `feat(content): add MapSceneConverter for
  scene-to-MapDef conversion` (schema/logic, TDD); `feat(content): add MapNodeMarker,
  MapLaneRoot, MapSceneRoot authoring scene classes` (new authoring-tool surface);
  `feat(content): author p_f_F_c.tscn and regenerate p_f_F_c.tres via the export
  tool` (policy, no test plan); `docs: record Decision 21 (map scene authoring tool
  supersedes tooling-timing guidance)` — four commits, since the diff spans new
  tested logic, new engine-glue classes, and content re-authoring, per the
  type-vs-diff test in `templates/commit-message.md`.
