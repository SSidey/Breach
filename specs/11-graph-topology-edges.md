---
spec_type: hybrid
status: active
parent_spec: ../Breach — Reverse Tower Defense Design Spec.md
---

# Graph Topology: Explicit Extra Edges for Branching Lanes

## Purpose

Today `LaneDef.nodes: Array[NodeDef]` is a flat ordered array where adjacency is
*implicit* in array order — a node can only ever have exactly one predecessor and one
successor within its own lane, per `specs/09-node-graph-and-lanes.md`'s "array order
IS the path" convention. There is no way for a node to have more than one neighbor.
The user wants branching topology to be representable — two lanes sharing a player
base, or (eventually) a unit with more than one valid route home. This item adds a
sparse, explicit, additive extra-edges concept: `MapEdgeDef`/`MapDef.edges`. A map's
full adjacency graph becomes **the union of (a) each `LaneDef`'s own implied path
edges (consecutive array entries, unchanged) and (b) `MapDef.edges`' explicit extra
connections.**

This is the hybrid split, mirroring `specs/09`/`specs/10`'s own precedent:
`MapEdgeDef`/`MapDef.edges`/validation and the converter's edge-building logic are
tooling-half (TDD applies); `MapEdgeMarker` itself is policy/engine-glue, an untested
data holder like `MapNodeMarker`/`MapLaneRoot`.

**Explicit scope boundary:** this item is schema-only. It changes zero lines in
`sim/lane_simulation.gd`, `sim/task_force_dispatch.gd`, or any other `sim/` file —
`LaneSimulation`'s movement stays a bare int position + `+1`/`-1` direction, unchanged.
The new edge data is inert until a future, separate item designs how a unit actually
chooses a path when more than one exists (route-choice/retreat-AI). This item only
makes branching *representable* in the data.

**Relationship to the base spec's "tracks not a grid" line:** the base design spec's
"What's already validated" list states "Lanes as tracks, not an open grid... [validated
by] early open-grid prototype playtesting" — an unnumbered bullet, not a formal
Decision, whose recorded reason is a readability/feel judgment from early HTML/JS
prototyping ("read as dots and boxes"), not a technical constraint (confirmed: no
other detail about that prototype survives anywhere in the repo). This item is a
deliberate, explicit refinement of that line, not a silent contradiction: it stays
sparse and opt-in (a map author explicitly places an edge marker to create a junction)
rather than becoming a general open grid where any node can connect to any other.
Recorded as Decision 22.

**Relationship to `breach-addendum-unified-combat.md`:** that file (repo root,
tracked as part of this item — confirmed by the user to be real prior design content,
not scratch) already sketches a "Retreat: a general capability" mechanic — any mobile
combatant retreats to the *nearest* friendly Structure, interceptable en route. That
mechanic is the eventual consumer of the graph this item introduces (routing needs
real adjacency to mean anything). Building that AI is explicitly out of scope here.

## Components introduced

- `MapEdgeDef` (new, `content/definitions/map_edge_def.gd`, `class_name MapEdgeDef
  extends Resource`) — `node_a_id: String = ""`, `node_b_id: String = ""` (not
  `from`/`to`: edges are undirected at the topology layer — naming them directionally
  would mislead a future route-choice implementer into thinking direction is already
  decided). `validate() -> PackedStringArray`: both non-empty, `node_a_id !=
  node_b_id` (no self-loop). Existence-of-referenced-node and duplicate-pair checks
  need the full node/edge set, so those live in `MapDef.validate()` instead — same
  delegation split `LaneDef`/`MapDef` already use for their own children.
- `MapDef` (`content/definitions/map_def.gd`) — gains `edges: Array[MapEdgeDef] = []`
  (defaults empty — zero behavior change for any map that doesn't use it, including
  today's `p_f_F_c`). `validate()` gains, via a new private helper `_all_node_ids()
  -> Dictionary` (keeps `validate()`'s body comfortably under this project's 40-line
  function-length ceiling): delegate each edge's own `validate()`, then check both
  ids exist among all lanes' node ids, then check for duplicate pairs (unordered —
  `(a, b)` and `(b, a)` are the same edge).
- `MapEdgeMarker` (new, `content/authoring/map_edge_marker.gd`, `class_name
  MapEdgeMarker extends Node`, no `@tool`) — `@export var node_a: MapNodeMarker`,
  `@export var node_b: MapNodeMarker`. Godot 4's typed Node-reference export gives a
  drag-and-drop scene-tree picker in the Inspector; serializes to `.tscn` as a
  scene-relative `NodePath` and resolves eagerly on `PackedScene.instantiate()` (works
  under the headless load path the converter's real export uses, not just in a
  running editor). Placed as a sibling of `MapLaneRoot` nodes directly under
  `MapSceneRoot`. No dedicated test — pure data holder, same precedent as
  `MapNodeMarker`/`MapLaneRoot`.
- `MapSceneConverter.build_map_def` (`content/authoring/map_scene_converter.gd`) —
  **required fix, not just an addition**: today it does `for lane_root in
  scene_root.get_children(): _build_lane_def(lane_root)`, treating every child as a
  `MapLaneRoot` unconditionally. Adding `MapEdgeMarker` as a sibling would crash that
  loop. Becomes a type-filtered dispatch: `if child is MapLaneRoot: ... elif child is
  MapEdgeMarker: ...`. New `_build_edge_def(marker: MapEdgeMarker) ->
  _EdgeConversionResult`: if `node_a`/`node_b` (or their `.node_def`) is null, appends
  an error to the result instead of crashing — same "errors in the result, never a
  thrown exception" idiom `_build_lane_def` already uses. No duplicate-before-insert
  concern here (unlike `NodeDef`): `MapEdgeDef` only ever stores plain id strings,
  never a `NodeDef`/marker object reference, so the `ResourceSaver`-writes-a-
  shared-resource-as-`ext_resource` problem that motivated `.duplicate()` for nodes
  doesn't apply to edges.

## Scenarios (Given/When/Then)

```gherkin
Scenario: A well-formed edge is valid
  Given a MapEdgeDef with node_a_id "p" and node_b_id "f"
  When validate() is called
  Then no error names "node_a_id" or "node_b_id"

Scenario: An edge with an empty id is invalid
  Given a MapEdgeDef with node_a_id "" and node_b_id "f"
  When validate() is called
  Then it returns a non-empty array naming "node_a_id"

Scenario: A self-loop edge is invalid
  Given a MapEdgeDef with node_a_id "p" and node_b_id "p"
  When validate() is called
  Then it returns a non-empty array naming a self-loop

Scenario: A MapDef with an edge referencing a nonexistent node id is invalid
  Given a MapDef with one lane containing nodes "p"/"f" and one edge
    referencing node_a_id "p", node_b_id "ghost"
  When validate() is called
  Then it returns a non-empty array naming "ghost"

Scenario: A MapDef with a duplicate edge (either order) is invalid
  Given a MapDef with two edges, one ("p", "f") and one ("f", "p")
  When validate() is called
  Then it returns a non-empty array naming a duplicate

Scenario: A MapDef with a valid edge across two different lanes has no errors
  Given a MapDef with two lanes each containing a node marked player_home,
    plus one edge connecting one node from each lane
  When validate() is called
  Then it returns an empty array

Scenario: The converter builds one MapEdgeDef per MapEdgeMarker
  Given a scene root with one MapLaneRoot (two node markers) and one
    MapEdgeMarker referencing two of those node markers
  When MapSceneConverter.build_map_def(scene_root) is called
  Then the resulting MapDef has exactly one edge with node_a_id/node_b_id
    matching the two referenced markers' NodeDef ids

Scenario: An edge marker missing a node reference reports an error, not a crash
  Given a MapEdgeMarker with node_a set and node_b left null
  When build_map_def converts the scene containing it
  Then the result's errors is non-empty and no exception is raised

Scenario: Lane-only scenes still convert correctly (regression, type-filter fix)
  Given a scene root with only MapLaneRoot children, no MapEdgeMarker
  When build_map_def converts it
  Then the resulting MapDef has the expected lanes and an empty edges array
```

## Test-first order

1. `MapEdgeDef.validate()` — non-empty ids, self-loop rejection — red before the file
   exists.
2. `MapDef.edges` + `validate()`'s nonexistent-node-id and duplicate-pair checks
   (via the new `_all_node_ids()` helper) — red before the field/logic exists.
3. `MapSceneConverter`'s edge-building path, including the missing-reference error
   case and the lane-only regression scenario (confirms the type-filter fix doesn't
   break existing single-lane maps) — red before `MapEdgeMarker`/the dispatch fix
   exist.

## Notes / open questions

- **Out of scope, deferred:** route-choice/pathfinding logic (which edge a unit takes
  when more than one exists), retreat-AI (per `breach-addendum-unified-combat.md`),
  and any change to `LaneSimulation`'s movement representation. This item's job ends
  at "the data can represent a junction."
- Edges are undirected by design — `node_a_id`/`node_b_id` carry no implied direction.
  A future movement/route-choice item decides how directionality (if any) factors in.
- This item does not touch `LaneDef`, `NodeDef`, `main.gd`, or any `sim/`/
  `presentation/` file.

## Rubric answers (qualitative, spec-baseline)

- `single-noun-phrase`: `map_edge_def.gd` ("map edge definition"), `map_edge_marker.gd`
  ("map edge marker") — each one noun phrase, one concern.
- `ocp-extension-point`: a future map with junctions is new `.tscn` content (more
  `MapEdgeMarker`s) against the existing shape — no code change. A future map without
  any junctions needs zero edges — the empty-default keeps it a pure extension.
- `lsp-contract-scope`: not applicable — no shared base/interface introduced.
- `isp-fit`: `MapEdgeDef`'s public surface is its two `@export` fields plus
  `validate()` — 1 method, matching every other schema class's shape. `MapDef` gains
  one field and its `validate()` grows internally (via a new private helper, not a
  new public method) — still 1 public method.
- `dip-direction`: `MapEdgeDef` is a pure data class with no dependency on `sim/` or
  `presentation/`, unchanged direction. `MapSceneConverter` depends on the new
  authoring types the same way it already depends on `MapLaneRoot`/`MapNodeMarker`.

## Structured rubric notes

- `spec-type-declared`: `hybrid` — schema/validation/converter logic is `code` (TDD
  applies); `MapEdgeMarker` itself is policy/engine-glue, matching `specs/10`'s own
  precedent for its sibling authoring types.
- `tdd-plan-present`: see Scenarios and Test-first order above.
- `no-drift`: introduced this session as a direct, explicit follow-on request after
  the map scene authoring tool (PR #24) shipped; records Decision 22 as a refinement
  of the base spec's "tracks not a grid" line rather than silently contradicting it.
- `commit-classification-plan`: `feat(content): add MapEdgeDef and MapDef.edges for
  explicit extra connections` (schema, TDD); `feat(content): add MapEdgeMarker and
  wire edge conversion into MapSceneConverter` (authoring surface + required
  type-filter bugfix, TDD for the converter half); `docs: record Decision 22 (graph
  topology refines "tracks not a grid") and track breach-addendum-unified-combat.md`
  — three commits, since the diff spans a schema addition, an authoring-tool
  extension with an accompanying bugfix, and documentation/tracking, per the
  type-vs-diff test in `templates/commit-message.md`.
