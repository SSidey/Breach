---
spec_type: hybrid
status: active
parent_spec: ../Breach — Reverse Tower Defense Design Spec.md
---

# Node Graph Data Model: Position, Identity, and Per-Lane Node Arrays

## Purpose

Phase 4, item 2 of the map/campaign expansion plan. Gives `NodeDef` real identity
(`id`) and rendering position (`position`), adds a `NEUTRAL` node type, and replaces
`MapDef.nodes: Array[NodeDef]` (one implicit global lane) with `MapDef.lanes:
Array[LaneDef]` (each an explicitly ordered node sequence) — the "connection graph"
for a track-based design, consistent with the parent spec's own "lanes as tracks, not
an open grid" preference (validated by early open-grid prototype playtesting). This is
the hybrid split: schema/validation/`LaneSimulation`'s constructor change is
tooling-half (TDD applies); `content/maps/p_f_F_c.tres`'s re-authoring is policy-half
(no test plan, same as `specs/06`'s own precedent).

Nothing renders `position` yet — that's Phase 4 item 3. This item is deliberately
invisible to the player; it exists purely to unblock item 3 and beyond.

## Components introduced

- `NodeDef` (`content/definitions/node_def.gd`) — gains `id: String` (stable
  authoring identifier; needed once array index is no longer globally unique once
  lanes exist) and `position: Vector2` (rendering-only; `sim/` logic must never read
  it — same "authored but currently unconsumed by sim" precedent as the existing
  unused `structure_slots` field). `NodeType` enum gains `NEUTRAL`, appended
  (never inserted — `.tres` files store the raw ordinal, and inserting would
  silently reinterpret existing content). `validate()` gains an `id`-non-empty
  check.
- `LaneDef` (new, `content/definitions/lane_def.gd`) — `id: String`, `nodes:
  Array[NodeDef]` (array order is the lane's path/connection sequence — adjacent
  indices are connected; this is the explicit per-lane graph, without building a
  general edge-list graph the design doc's own "tracks not a grid" note doesn't
  want), `player_home_index: int` (which node in *this lane's* array is the
  player's origin — needed because both `P` and `c` are `NodeType.ORIGIN` today, so
  node type alone can't disambiguate "my home" from "the far end of the lane").
  `validate()`: `nodes.size() >= 2`, `player_home_index` in range, delegates to each
  node's `validate()`.
- `MapDef` (`content/definitions/map_def.gd`) — `nodes: Array[NodeDef]` replaced by
  `lanes: Array[LaneDef]`. `validate()`: `lanes.size() >= 1`, delegates to each
  `LaneDef.validate()`. `tick_duration_seconds`/`suspicion_tier_thresholds`/
  `suspicion_decay_per_tick` stay map-global, unchanged.
- `LaneSimulation` (`sim/lane_simulation.gd`) — `_init(map: MapDef)` simplifies to
  `_init(nodes: Array[NodeDef])`. It already only ever did `for node in map.nodes`,
  so this drops its dependency on the authoring-format Resource shape entirely,
  leaving it genuinely "one lane's simulation" per its own docstring — and means it
  never has to change again when `MapDef`'s shape changes further (e.g. a future
  second map). Callers become `LaneSimulation.new(MAP.lanes[0].nodes)`.
- `content/maps/p_f_F_c.tres` — re-authored: its 5 nodes move into one `LaneDef`
  under `lanes[0]`, `player_home_index = 0` (node `P`), and gain real `position`
  values (a simple horizontal line is sufficient — nothing renders them yet).

## Scenarios (Given/When/Then)

```gherkin
Scenario: A NodeDef with a non-empty id is valid
  Given a NodeDef with id = "farm"
  When validate() is called
  Then no error names "id"

Scenario: A NodeDef with an empty id is invalid
  Given a NodeDef with id = ""
  When validate() is called
  Then it returns a non-empty array naming "id"

Scenario: A NEUTRAL NodeDef requires no type-specific fields
  Given a NodeDef with node_type = NEUTRAL
  When validate() is called
  Then it returns an empty array (NEUTRAL has no resource/garrison/fort
    requirements, same as ORIGIN today)

Scenario: A LaneDef with fewer than 2 nodes is invalid
  Given a LaneDef with a single NodeDef in nodes
  When validate() is called
  Then it returns a non-empty array naming "nodes"

Scenario: A LaneDef with player_home_index out of range is invalid
  Given a LaneDef with 3 nodes and player_home_index = 5
  When validate() is called
  Then it returns a non-empty array naming "player_home_index"

Scenario: A LaneDef aggregates its nodes' own validation errors
  Given a LaneDef containing one invalid NodeDef (negative garrison)
  When validate() is called
  Then the returned array includes that NodeDef's validation message

Scenario: A MapDef with zero lanes is invalid
  Given a MapDef with an empty lanes array
  When validate() is called
  Then it returns a non-empty array naming "lanes"

Scenario: A MapDef aggregates its lanes' own validation errors
  Given a MapDef containing one invalid LaneDef
  When validate() is called
  Then the returned array includes that LaneDef's validation message

Scenario: LaneSimulation constructed from a raw node array behaves identically
  Given an Array[NodeDef] (not a MapDef)
  When LaneSimulation.new(nodes) constructs a lane
  Then wave arrival, capture, and combat resolve exactly as before this item
```

## Test-first order

1. `NodeDef.validate()`'s new `id` check — red before the field/check exists.
2. `NodeDef.NodeType.NEUTRAL` — a NEUTRAL node validates with no extra
   requirements, red before the enum value exists.
3. `LaneDef.validate()` — size, `player_home_index` range, then aggregation of
   child `NodeDef` errors — new file, red before it exists.
4. `MapDef.validate()` — retargeted from `nodes` to `lanes`: zero-lanes check,
   aggregation of child `LaneDef` errors.
5. `LaneSimulation`'s constructor signature change — every existing scenario in
   `specs/02`'s own test suite re-verified against the new `_init(nodes)` shape
   (a refactor, not new behavior — the existing test suite is the safety net).

## Notes / open questions

- `position: Vector2` and `id: String` are rendering/authoring metadata only —
  `sim/` never reads either. Movement and combat mechanics stay purely index-based,
  unchanged from Decision 4. A short Decision (19) makes this explicit ahead of
  Phase 4 item 3 actually consuming `position` for rendering, to preempt any future
  temptation to let a node's visual position double as a gameplay input (distance,
  speed, adjacency-by-proximity).
- `NEUTRAL` is authored here as a real enum value with no validation requirements of
  its own (same shape as `ORIGIN`), but nothing yet *assigns* it to a node in
  `content/maps/p_f_F_c.tres` — this map's nodes keep their existing types. Content
  authoring a genuinely neutral node is a later item's job (Phase 4 item 5's
  generalized win/loss work already anticipates it).
- `player_home_index` resolves a real ambiguity `specs/00`'s map already had: both
  `P` and `c` are `NodeType.ORIGIN` (per `specs/07`'s schema), so nothing before this
  item could answer "which ORIGIN node is the player's home" except by hardcoded
  index knowledge living in `main.gd` (`const P := 0`). `LaneDef.player_home_index`
  makes that a data fact instead — not yet consumed by any `sim/` logic this item
  (main.gd's own `P`/`CORE` constants are unchanged), but the field a future
  generalized win/loss system (Phase 4 item 5) will need.
- **OCP touched-file footprint, anticipated by the plan itself:** this migration
  touches `node_def.gd`, `map_def.gd`, `lane_simulation.gd`, `main.gd`, plus
  `test_node_def.gd`, `test_map_def.gd`, `test_lane_simulation.gd`, and
  `test_vertical_slice_win_condition.gd` (its own `_map()` fixture builds a
  `MapDef` directly) — 8 pre-existing `.gd` files, landing exactly at the current
  `ocp.max_touched_files_per_new_case` ceiling (Decision 18) rather than exceeding
  it, confirming the plan's own advance estimate.

## Rubric answers (qualitative, spec-baseline)

- `single-noun-phrase`: `node_def.gd` ("node definition"), `lane_def.gd` ("lane
  definition" — new), `map_def.gd` ("map definition"), each one noun phrase.
  Described together because they're one small, interdependent schema batch
  (mirrors `specs/07`'s own "authored and reviewed as one small batch" reasoning).
- `ocp-extension-point`: a future second lane, or a future map with more nodes, is
  new `.tres` content against the existing `LaneDef`/`MapDef` shape — no code
  change. A future node type is a new enum value plus its own `validate()` branch,
  same pattern `NodeType` already follows.
- `lsp-contract-scope`: not applicable — no shared base/interface introduced.
- `isp-fit`: `LaneDef`'s public surface is its `@export` fields plus `validate()` —
  1 method, matching every other schema class's shape (`specs/07`). `LaneSimulation`
  loses no methods and gains none — only its constructor's parameter type changes,
  which the ISP method-count check doesn't count (`_init` is excluded).
- `dip-direction`: pure data classes (`NodeDef`, `LaneDef`, `MapDef`) with no
  dependency on `sim/` or `presentation/` in either direction, unchanged.
  `LaneSimulation` depends on `NodeDef` only (dropping its `MapDef` dependency
  entirely) — a strictly narrower dependency surface than before.

## Structured rubric notes

- `spec-type-declared`: `hybrid` — schema/validation/`LaneSimulation`'s constructor
  change is `code` (TDD applies); `content/maps/p_f_F_c.tres`'s re-authoring is
  policy (no test plan), matching `specs/06`'s own precedent.
- `tdd-plan-present`: see Scenarios and Test-first order above, for the tooling
  half.
- `no-drift`: implements the "Phase 4 item 2" scope from the map/campaign expansion
  plan; introduces Decision 19 (`position`/`id` are rendering-only) as a new,
  non-contradicting decision.
- `commit-classification-plan`: `feat(content): add id/position to NodeDef, add
  NEUTRAL type` (schema); `feat(content): add LaneDef, replace MapDef.nodes with
  MapDef.lanes` (schema); `refactor(sim): LaneSimulation takes a raw node array
  instead of MapDef` (behavior-preserving, existing suite as safety net); `feat:
  wire main.gd to the new lanes shape` (composition root); `feat(content): re-author
  p_f_F_c map data as a LaneDef with real positions` (policy, no test plan) — five
  commits, since the diff genuinely spans schema additions, a refactor, and content
  re-authoring, per the type-vs-diff test in `templates/commit-message.md`.
