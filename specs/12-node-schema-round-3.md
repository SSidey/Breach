---
spec_type: hybrid
status: active
parent_spec: ../Breach — Reverse Tower Defense Design Spec.md
---

# Node Schema Round 3: Resource Typing, Assignment Roles, Faction, Reward

## Purpose

Using the Lane Tile Designer prototype (a standalone HTML mockup, not part of this
repo) surfaced four real gaps between what an author would want to configure and what
`NodeDef` can actually represent: resource nodes are Food-only with no finite
quantity; a garrison is a single pooled count with no role beyond "present"; ownership
is a bare, ad-hoc `String` with no faction/relationship concept; and there is no way
to attach a capture reward to a location. This item adds all four as **additive,
inert schema** — the same "schema now, consumption later" discipline already used for
`NodeDef.position` (Decision 19) and `MapDef.edges` (Decision 22).

**Explicit scope boundary — nothing below changes `sim/` or `core/` behavior:**
- No real reserve-depletion logic in `sim/economy_system.gd` or
  `sim/capture_resolution.gd`. `total_reserves` is authored, not consumed.
- No patrol/sortie/delivery movement or AI logic anywhere in `sim/`.
- No migration of `sim/`'s existing `String`-based ownership (`"player"`,
  `"defender"` in `sim/lane_simulation.gd`, `sim/task_force_dispatch.gd`) to the new
  `FactionRelationDef.FactionId` enum. That migration touches multiple `sim/` files
  and their tests and is separate, future work for whenever something actually
  consumes factions.
- No unlock system consumes `capture_reward`.

**Also explicitly deferred, raised by the user and confirmed out of scope:**
configurable unit library + squads (ties to true per-unit faction assignment, since
`garrison_faction` below only covers the common single-affiliation case); treasure
"unlockables" beyond the plain `capture_reward` string field.

## Components introduced

- `NodeDef` (`content/definitions/node_def.gd`) gains, **all additive — no existing
  field renamed or removed**, so `sim/capture_resolution.gd`'s existing
  `node.yield_food_per_tick`/`node.ravage_yield_food` reads are untouched:
  - `resource_type: enum {FOOD, WOOD, STONE, METAL, CRYSTAL} = FOOD` — matches
    `EconomySystem._pools`'s existing five keys. Defaults to `FOOD` so
    `content/maps/p_f_F_c.tres`'s one Farm needs no changes. Authored, not yet read
    by `sim/` — same status as `structure_slots` today.
  - `total_reserves: int = 0` (`0` = unlimited, preserving today's unlimited-harvest
    behavior by default). `validate()`: `>= 0`. **Documented intended future
    semantics (comment only):** once consumed, reserves should only deplete from
    yield *above* `decay_floor_food` — the floor stays an eternally-renewable
    baseline, leaving room for a future "maintained by skilled units" mechanic
    without another schema change.
  - `patrol_route: Array[String] = []` — ordered node ids a garrisoned defender
    patrols between. Empty = static only (unchanged default behavior).
    `validate()`: non-empty requires `garrison > 0`. Cross-referenced against the
    map's real node ids at `MapDef` level (a single node can't validate id
    references against nodes it can't see).
  - `can_sortie: bool = false` — matches the combat addendum's already-drafted
    sortie concept. `validate()`: `true` requires `garrison > 0`.
  - `delivery_target_id: String = ""` — which node a `RESOURCE` node's future
    worker-delivery route targets, per the addendum's Worker-as-Combatant section.
    Cross-referenced at `MapDef` level, same as `patrol_route`.
  - `garrison_faction: FactionRelationDef.FactionId =
    FactionRelationDef.FactionId.ENEMY` — the garrison's single default
    affiliation. Only meaningful with `garrison > 0`. **Documented limitation:**
    `garrison` is a pooled count, not a list of individual units, so this cannot
    express per-unit mixed affiliation (e.g. a prisoner inside an enemy structure) —
    that needs the pooled-garrison → individual-unit-list redesign, deferred
    alongside the squads/unit-library extension.
  - `capture_reward: String = ""` — free-text/id placeholder for what unlocks on
    capture. No validation beyond the default (empty = none); no unlock system
    consumes it yet.

  Static defense itself needs **no schema change** — confirmed `garrison`/
  `garrison_hp`/`garrison_dmg` are not type-gated in `validate()` today, so any
  structure already supports a garrison; the Lane Tile Designer prototype's UI was
  the only thing restricting the panel to FORT.

- `FactionRelationDef` (new, `content/definitions/faction_relation_def.gd`,
  `class_name FactionRelationDef extends Resource`) — nested `enum FactionId {
  PLAYER, ENEMY }` (append-only, same convention as `NodeDef.NodeType`).
  `faction_a: FactionId`, `faction_b: FactionId`, `stance: enum { HOSTILE, NEUTRAL,
  ALLIED }`. `validate()`: `faction_a != faction_b` (no self-relation).

- `MapDef` (`content/definitions/map_def.gd`) gains `faction_relations:
  Array[FactionRelationDef] = []` (additive, defaults empty). **Refactored, not just
  extended:** `validate()`'s body was already 38 lines (near this project's 40-line
  function-length ceiling) before this item. Split into small private-helper
  delegates (`_validate_suspicion_thresholds()`, `_validate_lanes()`,
  `_validate_edges(node_ids)`, `_validate_node_references(node_ids)`,
  `_validate_faction_relations()`), with `validate()` itself becoming a short
  orchestrator that calls each and concatenates results — keeps every function
  comfortably under budget as this schema keeps growing, and matches this project's
  own precedent of extracting private helpers rather than letting one function grow
  unbounded.

## Scenarios (Given/When/Then)

```gherkin
Scenario: A RESOURCE node defaults to FOOD with unlimited reserves
  Given a NodeDef with node_type RESOURCE and no resource_type/total_reserves set
  When validate() is called
  Then resource_type is FOOD and total_reserves is 0
  And no error names "total_reserves"

Scenario: Negative total_reserves is invalid
  Given a NodeDef with total_reserves = -1
  When validate() is called
  Then it returns a non-empty array naming "total_reserves"

Scenario: A non-empty patrol_route without a garrison is invalid
  Given a NodeDef with garrison = 0 and patrol_route = ["a", "b"]
  When validate() is called
  Then it returns a non-empty array naming "patrol_route"

Scenario: can_sortie without a garrison is invalid
  Given a NodeDef with garrison = 0 and can_sortie = true
  When validate() is called
  Then it returns a non-empty array naming "can_sortie"

Scenario: A MapDef with a patrol_route referencing a nonexistent node id is invalid
  Given a MapDef with one lane and a node whose patrol_route includes "ghost"
  When validate() is called
  Then it returns a non-empty array naming "ghost"

Scenario: A MapDef with a delivery_target_id referencing a nonexistent node is invalid
  Given a MapDef with a RESOURCE node whose delivery_target_id is "ghost"
  When validate() is called
  Then it returns a non-empty array naming "ghost"

Scenario: A FactionRelationDef cannot relate a faction to itself
  Given a FactionRelationDef with faction_a = PLAYER and faction_b = PLAYER
  When validate() is called
  Then it returns a non-empty array

Scenario: A valid FactionRelationDef has no errors
  Given a FactionRelationDef with faction_a = PLAYER, faction_b = ENEMY, stance =
    HOSTILE
  When validate() is called
  Then it returns an empty array

Scenario: The existing p_f_F_c map still validates cleanly unmodified
  Given content/maps/p_f_F_c.tres loaded as-is (no new fields authored)
  When MapDef.validate() is called
  Then it returns an empty array
```

## Test-first order

1. `NodeDef`'s new fields' own `validate()` rules (`total_reserves`, `patrol_route`/
   `can_sortie` garrison requirements) — red before the fields/checks exist.
2. `FactionRelationDef.validate()` (new file) — red before it exists.
3. `MapDef`'s cross-reference checks for `patrol_route`, `delivery_target_id`, and
   `faction_relations` delegation — red before `_validate_node_references()`/
   `_validate_faction_relations()` exist. Existing `MapDef` tests (lanes, edges,
   suspicion thresholds) must stay green through the `validate()` refactor —
   confirms the helper extraction is behavior-preserving.
4. Manual/scripted check that `content/maps/p_f_F_c.tres` still loads and
   `validate()`s cleanly with zero authored changes (defaults preserve it).

## Notes / open questions

- `resource_type`'s enum values (`WOOD`, `STONE`, `METAL`, `CRYSTAL`) are authored
  ahead of any node actually using them (only `FOOD` is exercised by the current
  map) — same "authored ahead of content" precedent as `NodeType.NEUTRAL`.
  `sim/capture_resolution.gd`'s `_economy.add("food", ...)` stays hardcoded; a real
  generic-resource consumer is future work, not this item.
- `garrison_faction`'s single-affiliation limitation (documented above) is the
  concrete reason true per-unit/squad affiliation is deferred, not merely "not asked
  for yet."
- This item does not touch `LaneDef`, `main.gd`, or any `sim/`/`presentation/` file.

## Rubric answers (qualitative, spec-baseline)

- `single-noun-phrase`: `faction_relation_def.gd` ("faction relation definition") —
  one noun phrase. `node_def.gd`/`map_def.gd` extended, not renamed — same concern
  each already had.
- `ocp-extension-point`: a future resource-type consumer reads `resource_type`/
  `total_reserves` without a schema change. A future third faction is a new
  `FactionId` enum value (appended) plus new `FactionRelationDef` content — no code
  change to `FactionRelationDef` itself.
- `lsp-contract-scope`: not applicable — no shared base/interface introduced.
- `isp-fit`: `FactionRelationDef`'s public surface is its `@export` fields plus
  `validate()` — 1 method. `MapDef`'s public surface is unchanged (`validate()`
  still the only public method; the new private helpers aren't part of the public
  contract).
- `dip-direction`: `FactionRelationDef` is a pure data class with no dependency on
  `sim/`/`presentation/`, matching every other schema class.

## Structured rubric notes

- `spec-type-declared`: `hybrid` — all schema/validation logic is `code` (TDD
  applies); there is no policy/engine-glue half in this item (unlike `specs/10`/
  `specs/11`, nothing here touches authoring-tool scene classes).
- `tdd-plan-present`: see Scenarios and Test-first order above.
- `no-drift`: introduced this session as a direct follow-on from Lane Tile Designer
  prototype feedback; records Decision 23 as additive, non-contradicting groundwork,
  explicit about every deferred behavior.
- `commit-classification-plan`: `feat(content): add resource typing and reserves to
  NodeDef` (schema, TDD); `feat(content): add patrol/sortie/delivery assignment
  fields to NodeDef` (schema, TDD); `feat(content): add FactionRelationDef and
  garrison_faction` (schema, TDD); `refactor(content): split MapDef.validate() into
  per-concern private helpers` (behavior-preserving, existing tests as safety net,
  needed to add the new cross-reference checks under the function-length ceiling);
  `feat(content): add capture_reward to NodeDef` (schema, trivial); `docs: record
  Decision 23` — six commits, since the diff spans several independent schema
  additions plus one behavior-preserving refactor, per the type-vs-diff test in
  `templates/commit-message.md`.
