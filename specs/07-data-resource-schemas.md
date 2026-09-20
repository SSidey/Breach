---
spec_type: code
status: active
parent_spec: ../Breach — Reverse Tower Defense Design Spec.md
---

# Data Resource Schemas: `UnitDef`, `NodeDef`, `ResponseUnitDef`, `MapDef`

## Purpose

The four `Resource` (`.tres`)-backed schema classes that every other spec in this folder
references but none formally define: `UnitDef`, `NodeDef`, `ResponseUnitDef`, `MapDef`.
This spec covers the class definitions and their thin, structural validation only — no
simulation behavior, and no populated map content (that's
`specs/06-map-content-p-f-F-c.md`'s job, once these schemas exist to author against).

This is Phase 3, item 1 of the vertical-slice execution plan: every later simulation
spec (clock/commands, movement/combat, resources, suspicion) is implemented against
these shapes, so they need to exist and be validated first.

## Components introduced

- `UnitDef` (`content/definitions/unit_def.gd`) — `cost_food: int`, `hp: int`,
  `dmg: int`, `speed: float`. Used for Grem (Decision 6: the only `UnitDef` this slice
  authors).
- `NodeDef` (`content/definitions/node_def.gd`) — `node_type: NodeType` (enum:
  `ORIGIN`, `RESOURCE`, `FORT`), `garrison: int`, and resource-node-only fields
  (`yield_food_per_tick: int`, `decay_interval_ticks: int`, `decay_floor_food: int`) that
  are only required when `node_type == RESOURCE`. Also carries a `structure_slots: int`
  field per Decision 4 (unused this slice, kept for the future Option 2 pass).
  **Added in Phase 3 item 4** (`specs/02-lane-movement-and-combat.md`, Decision 11):
  `garrison_hp: int`, `garrison_dmg: int` — the pooled blocker stats
  `CombatResolver` actually fights against, required whenever `garrison > 0`.
  `garrison` stays a presence/count check ("is this node defended at all");
  `garrison_hp`/`garrison_dmg` are the real combat numbers, kept separate since a
  count and a stat block answer different questions and nothing needs them conflated.
- `ResponseUnitDef` (`content/definitions/response_unit_def.gd`) — its own independent
  fields, coincidentally similar in shape to `UnitDef` (`hp`, `dmg`, `speed`) plus
  `purpose: String` (e.g. `"respond"`, per the parent spec's Task Force model). Neither
  inherits from nor embeds `UnitDef` — a Task Force response unit is not a kind-of
  player unit in any substitutable sense (no shared contract between them, dispatched by
  an entirely different system), so the field-shape similarity is coincidental, not a
  relationship worth modeling.
- `MapDef` (`content/definitions/map_def.gd`) — `nodes: Array[NodeDef]` (lane order),
  `tick_duration_seconds: float`, `suspicion_tier_thresholds: Array[int]` (4 ascending
  values for Wary/Alarmed/Mobilized/Full Alert per the parent spec's Decision 5), and
  `suspicion_decay_per_tick: int`.

Each class exposes `func validate() -> PackedStringArray` returning one message per
structural problem found (empty array = valid) — deliberately not a hard `assert`,
since a spec-authoring pass (Phase 3 item 11) needs to see every problem at once rather
than stopping at the first one.

## Scenarios (Given/When/Then)

```gherkin
Scenario: A UnitDef with all non-negative fields is valid
  Given a UnitDef with cost_food = 5, hp = 10, dmg = 2, speed = 1.0
  When validate() is called
  Then it returns an empty array

Scenario: A UnitDef with a negative field is invalid
  Given a UnitDef with hp = -1
  When validate() is called
  Then it returns a non-empty array containing a message naming "hp"

Scenario: A RESOURCE NodeDef without yield data is invalid
  Given a NodeDef with node_type = RESOURCE and yield_food_per_tick = 0
  When validate() is called
  Then it returns a non-empty array naming "yield_food_per_tick"

Scenario: A garrisoned NodeDef without blocker stats is invalid
  Given a NodeDef with garrison = 3 and garrison_hp = 0
  When validate() is called
  Then it returns a non-empty array naming "garrison_hp"

Scenario: An ungarrisoned NodeDef does not require blocker stats
  Given a NodeDef with garrison = 0 and garrison_hp = 0
  When validate() is called
  Then it returns an empty array (blocker stats are not applicable with no garrison)

Scenario: An ORIGIN NodeDef does not require resource fields
  Given a NodeDef with node_type = ORIGIN and yield_food_per_tick = 0
  When validate() is called
  Then it returns an empty array (resource fields are not applicable to ORIGIN)

Scenario: A MapDef with fewer than 2 nodes is invalid
  Given a MapDef with a single NodeDef in `nodes`
  When validate() is called
  Then it returns a non-empty array naming "nodes"

Scenario: A MapDef with non-ascending suspicion thresholds is invalid
  Given a MapDef with suspicion_tier_thresholds = [50, 30, 70, 90]
  When validate() is called
  Then it returns a non-empty array naming "suspicion_tier_thresholds"

Scenario: A MapDef aggregates its nodes' own validation errors
  Given a MapDef containing one invalid NodeDef (negative garrison)
  When validate() is called
  Then the returned array includes that NodeDef's validation message
```

## Test-first order

1. `UnitDef.validate()` — non-negative field checks, red before the class exists.
2. `NodeDef.validate()` — type-conditional resource-field checks, plus (added item 4)
   garrison-conditional blocker-stat checks.
3. `ResponseUnitDef.validate()` — reuses the same non-negative checks via its embedded
   `UnitDef`-shaped fields (composition, not a shared contract — see `lsp-contract-scope`
   below for why this isn't a contract-test situation).
4. `MapDef.validate()` — structural checks (node count, ascending thresholds), then
   aggregation of child `NodeDef` errors.

## Notes / open questions

- Exact numeric values (Grem's actual cost/hp/dmg, the Farm's actual yield) are not
  decided here — this spec only defines the shape and its structural validity rules.
  Real values are authored in `specs/06-map-content-p-f-F-c.md` once this schema exists.
- `structure_slots` on `NodeDef` is present but unvalidated in this pass (no rule yet
  for what a valid slot count is, since nothing consumes it until a future Option 2
  pass per Decision 4) — deliberately not over-specified ahead of need.

## Rubric answers (qualitative, spec-baseline)

- `single-noun-phrase`: split at implementation into four files, one class each
  (`unit_def.gd`, `node_def.gd`, `response_unit_def.gd`, `map_def.gd`) — each one's
  purpose is its own single noun phrase ("unit definition", "node definition", etc.).
  Described together in one spec because they're authored and reviewed as one small,
  interdependent batch (Phase 3 item 1), not because they're one concern.
- `ocp-extension-point`: a new field requirement (e.g. a future Metal-yield field) is an
  addition to the relevant class and its `validate()` body — no other file touches this
  change, since nothing else duplicates these schemas.
- `lsp-contract-scope`: `ResponseUnitDef` and `UnitDef` are structurally similar but
  deliberately *not* a shared base/subclass pair — a Hero Party is not substitutable
  for a Grem anywhere in the codebase (they're dispatched by entirely different
  systems: `TaskForceDispatch` vs. `CommandQueue`). No contract test is introduced here;
  if a real shared contract emerges later (e.g. both need to satisfy a `Combatant`
  interface `CombatResolver` consumes), that's a new decision, not implied by today's
  field-shape similarity alone.
- `isp-fit`: each class's public surface is its `@export` fields plus one `validate()`
  method — 1 method each, well under the 7-method threshold.
- `dip-direction`: pure data classes with no dependency on `sim/` or `presentation/` in
  either direction — every other layer depends on these, not the reverse.

## Structured rubric notes

- `spec-type-declared`: `code`.
- `tdd-plan-present`: see Scenarios and Test-first order above.
- `no-drift`: implements the field shapes already referenced by name in
  `specs/01`–`06` and Decisions 4–6; introduces no new decisions of its own.
- `commit-classification-plan`: `feat(content): add data resource schemas`.
