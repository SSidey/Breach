---
spec_type: hybrid
status: active
parent_spec: ../Breach — Reverse Tower Defense Design Spec.md
---

# FactionDef, GarrisonUnitDef, Base Ownership, Inexhaustible Flag

## Purpose

Revises part of `specs/12-node-schema-round-3.md` before it ever merged (PR #26 is
still open — no consumers exist yet, so this is a correction to unreviewed work, not a
breaking change to shipped content). Two things in round 3 turned out wrong on
reflection:

1. **`can_sortie`, `patrol_route`, `delivery_target_id`, and `garrison_faction` are
   unit/squad properties, not structure properties.** The combat addendum already
   models a Structure and its Garrison as separate Combatants with independent stats.
   This project also already has a **deliberate precedent against premature
   unification** — `ResponseUnitDef`'s own doc comment: "Deliberately independent of
   UnitDef... a Task Force response unit is not a kind-of player unit in any
   substitutable sense." Fully doing "a structure is just an immobile unit" properly
   means adopting the combat addendum's whole Combatant/Encounter model, which would
   also subsume `UnitDef`/`ResponseUnitDef` and every `sim/` consumer of them — a
   large, separate, future item. This spec does the smaller, honest version: a
   minimal `GarrisonUnitDef` holding just the four affiliation/behavior fields,
   explicitly documented as a deliberate stand-in, not the full unification.
2. **Faction needs to be author-definable content, not a closed enum.** A closed
   `FactionId` enum (`PLAYER`/`ENEMY`) can't express a map-authored faction like a
   stub "The Kingdom." Enums are for closed, code-level categories (`NodeType`'s own
   convention); factions are content, like units and maps already are.

**Explicit non-goal — confirmed by re-reading the actually-consumed code:**
`NodeDef.garrison`/`garrison_hp`/`garrison_dmg` are **not** round-3 additions — they
predate this session (Decision 11) and are read live by `sim/lane_simulation.gd`'s
`_init()` today. Restructuring those into per-unit stats would be real
behavior-affecting surgery on the running simulation, outside this project's
established "schema-only, zero `sim/` change" discipline for this line of work. They
are unchanged by this spec. `GarrisonUnitDef` here holds only affiliation/behavior
fields — not combat stats.

**Also explicit — these four fields are each unit's *baseline standing order*, not a
fixed property.** A future Command & Control system (messenger-delivered orders,
interceptable, tiered by delivery assurance — captured in the execution plan, not
designed here) is expected to let these change at runtime. This spec only authors the
starting state.

## Components introduced

- `FactionDef` (new, `content/definitions/faction_def.gd`, `class_name FactionDef
  extends Resource`) — `id: String`, `display_name: String`. `validate()`: `id`
  non-empty. Real content: `content/factions/player.tres` (id `"player"`) and
  `content/factions/the_kingdom.tres` (id `"the_kingdom"`, display name "The
  Kingdom") — the first two instances, "The Kingdom" as the requested stub faction
  hostile to the player.
- `FactionRelationDef` (`content/definitions/faction_relation_def.gd`) — **revised**:
  the closed `FactionId` enum and `faction_a`/`faction_b` enum fields are replaced
  with `faction_a_id: String`/`faction_b_id: String`, referencing `FactionDef.id`
  values. `Stance` enum (`HOSTILE`/`NEUTRAL`/`ALLIED`) is unchanged — a fixed small
  set of relationship *kinds* is genuinely different from open-ended faction
  *identity*. `validate()`: both ids non-empty, `faction_a_id != faction_b_id`.
  Existence-of-referenced-faction and duplicate-pair checks move to
  `MapDef.validate()` (same split every other cross-reference in this schema uses).
- `GarrisonUnitDef` (new, `content/definitions/garrison_unit_def.gd`, `class_name
  GarrisonUnitDef extends Resource`) — `faction_id: String`, `can_sortie: bool =
  false`, `patrol_route: Array[String] = []`, `delivery_target_id: String = ""`.
  `validate()`: `faction_id` non-empty. Id-existence checks for `patrol_route`/
  `delivery_target_id`/`faction_id` happen in `MapDef.validate()`, walking each
  node's `garrison_units`.
- `NodeDef` (`content/definitions/node_def.gd`) — **removed**: `can_sortie`,
  `patrol_route`, `delivery_target_id`, `garrison_faction` (moved into
  `GarrisonUnitDef`). **Unchanged**: `garrison`, `garrison_hp`, `garrison_dmg`.
  **Added**: `garrison_units: Array[GarrisonUnitDef] = []` (`validate()`: non-empty
  requires `garrison > 0`, delegates each entry); `owning_faction_id: String = ""`
  (which faction controls this node — meaningful for `ORIGIN`-type "base" nodes, not
  hard-gated to that type; cross-referenced against the map's faction roster in
  `MapDef.validate()`); `is_inexhaustible: bool = true` (fixes `total_reserves`'s
  `0`-means-unlimited overload from round 3 — defaults `true` so
  `content/maps/p_f_F_c.tres`'s unmodified content keeps its current
  effectively-unlimited behavior with no content edit needed; `total_reserves`
  becomes the real finite pool size once `is_inexhaustible == false`).
- `MapDef` (`content/definitions/map_def.gd`) — gains `factions: Array[FactionDef] =
  []` (the map's faction roster, including the player's own entry — "player" is
  authoring convention, not a hardcoded value, matching how `sim/`'s existing
  ownership strings already work). New private helper `_all_faction_ids() ->
  Dictionary` (mirrors `_all_node_ids()`). `_validate_faction_relations()` extended:
  delegate + existence-check both ids against `_all_faction_ids()` + duplicate-pair
  detection (reusing `_validate_edges()`'s canonical-key pattern).
  `_validate_node_references()` extended: walk each node's `garrison_units` for
  `patrol_route`/`delivery_target_id`/`faction_id` existence, plus each node's own
  `owning_faction_id`.

**Documented, explicit tension (not resolved here):** `owning_faction_id` and
`LaneDef.player_home_index` are now two independent ways to identify "the player's
base" on the same node. Recorded as a known near-duplication for whichever future
item first needs faction-based ownership logic in `sim/` to reconcile.

## Scenarios (Given/When/Then)

```gherkin
Scenario: A valid FactionDef has no errors
  Given a FactionDef with id "the_kingdom" and display_name "The Kingdom"
  When validate() is called
  Then it returns an empty array

Scenario: A FactionDef with an empty id is invalid
  Given a FactionDef with id ""
  When validate() is called
  Then it returns a non-empty array naming "id"

Scenario: A valid FactionRelationDef has no errors
  Given a FactionRelationDef with faction_a_id "player", faction_b_id "the_kingdom",
    stance HOSTILE
  When validate() is called
  Then it returns an empty array

Scenario: A FactionRelationDef cannot relate a faction to itself
  Given a FactionRelationDef with faction_a_id "player" and faction_b_id "player"
  When validate() is called
  Then it returns a non-empty array

Scenario: A valid GarrisonUnitDef has no errors
  Given a GarrisonUnitDef with faction_id "the_kingdom"
  When validate() is called
  Then it returns an empty array

Scenario: A GarrisonUnitDef with an empty faction_id is invalid
  Given a GarrisonUnitDef with faction_id ""
  When validate() is called
  Then it returns a non-empty array naming "faction_id"

Scenario: Non-empty garrison_units without a garrison is invalid
  Given a NodeDef with garrison = 0 and one GarrisonUnitDef in garrison_units
  When validate() is called
  Then it returns a non-empty array naming "garrison_units"

Scenario: A garrison_units entry's patrol_route referencing a nonexistent node id is invalid
  Given a MapDef with a garrisoned node whose garrison_units[0].patrol_route
    includes "ghost"
  When validate() is called
  Then it returns a non-empty array naming "ghost"

Scenario: A garrison_units entry's faction_id referencing a nonexistent faction is invalid
  Given a MapDef with a garrisoned node whose garrison_units[0].faction_id is
    "ghost_faction" and no matching entry in factions
  When validate() is called
  Then it returns a non-empty array naming "ghost_faction"

Scenario: A node's owning_faction_id referencing a nonexistent faction is invalid
  Given a MapDef with a node whose owning_faction_id is "ghost_faction" and no
    matching entry in factions
  When validate() is called
  Then it returns a non-empty array naming "ghost_faction"

Scenario: A duplicate faction_relations pair, either order, is invalid
  Given a MapDef with two faction_relations, one (player, the_kingdom) and one
    (the_kingdom, player)
  When validate() is called
  Then it returns a non-empty array naming a duplicate

Scenario: The existing p_f_F_c map still validates cleanly unmodified
  Given content/maps/p_f_F_c.tres loaded as-is (no new fields authored)
  When MapDef.validate() is called
  Then it returns an empty array
```

## Test-first order

1. `FactionDef.validate()` (new) — red before the file exists.
2. `FactionRelationDef.validate()` rewritten for string ids — red once the enum
   fields are removed from the test fixtures.
3. `GarrisonUnitDef.validate()` (new) — red before the file exists.
4. `NodeDef.validate()`: remove the four fields' checks (existing round-3 tests for
   them become invalid and must be rewritten against `GarrisonUnitDef` instead), add
   `garrison_units`/`is_inexhaustible` checks.
5. `MapDef.validate()`: `_all_faction_ids()`, extended
   `_validate_faction_relations()`/`_validate_node_references()` — existing round-3
   `MapDef` tests for patrol/delivery/faction scenarios are rewritten to nest through
   `garrison_units`.
6. Manual/scripted check that `content/maps/p_f_F_c.tres` still loads and
   `validate()`s cleanly with zero authored changes.

## Notes / open questions

- The Command & Control / messenger-delivered-orders idea (why `GarrisonUnitDef`'s
  fields are a *baseline* order, not a fixed property) is captured in full in the
  execution plan for this item, not designed here — it's a large, separate future
  system.
- The larger economy/replenishment/calendar redesign (natural + skill-based
  replenishment, a standing-crop cap distinct from the reserve cap, neglect-decay,
  season/time-of-day) is tracked as an open design question in the base design spec,
  not designed here.
- This item does not touch `LaneDef`, `main.gd`, or any `sim/`/`presentation/` file.

## Rubric answers (qualitative, spec-baseline)

- `single-noun-phrase`: `faction_def.gd` ("faction definition"), `garrison_unit_def.gd`
  ("garrison unit definition") — each one noun phrase.
- `ocp-extension-point`: a future third faction is new `.tres` content (a new
  `FactionDef` instance) — no code change. A future new assignment role is a new
  field on `GarrisonUnitDef` — no change to `NodeDef`/`MapDef`.
- `lsp-contract-scope`: not applicable — no shared base/interface introduced.
- `isp-fit`: `FactionDef`/`GarrisonUnitDef` each expose `@export` fields plus
  `validate()` — 1 method. `MapDef`'s public surface is unchanged.
- `dip-direction`: both new classes are pure data with no dependency on `sim/`/
  `presentation/`, matching every other schema class.

## Structured rubric notes

- `spec-type-declared`: `hybrid` — all schema/validation logic is `code` (TDD
  applies).
- `tdd-plan-present`: see Scenarios and Test-first order above.
- `no-drift`: revises `specs/12` before it ever merged, in direct response to
  concrete user feedback from using the tile-designer prototype; records Decision 24
  as explicitly superseding Decision 23's placement of the four fields.
- `commit-classification-plan`: `feat(content): add FactionDef as author-definable
  faction content` (schema, TDD); `feat(content): add GarrisonUnitDef, move
  affiliation/behavior fields off NodeDef` (schema, TDD, includes the
  `FactionRelationDef` enum-to-string-id revision since both touch faction
  representation); `feat(content): add owning_faction_id and is_inexhaustible to
  NodeDef` (schema, TDD); `feat(content): add faction/garrison-unit content stubs`
  (player.tres, the_kingdom.tres); `docs: record Decision 24 and the Command & Control
  idea` — five commits, spanning several schema pieces, a revision to already-landed
  round-3 work, new content, and documentation, per the type-vs-diff test in
  `templates/commit-message.md`.
