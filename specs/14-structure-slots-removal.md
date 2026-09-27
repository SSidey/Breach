---
spec_type: hybrid
status: active
parent_spec: ../Breach — Reverse Tower Defense Design Spec.md
---

# Remove NodeDef.structure_slots (superseded by the tile capacity model)

## Purpose

`NodeDef.structure_slots: int` was added as metadata for a future spatial-placement
pass (Decision 4), described as a *count* of discrete buildable foundations at a
location. Nothing ever consumed it: no `sim/` code, no converter, no test, and no
authored `.tres` content reads or sets it (confirmed by search before writing this
spec).

Iterating on the Lane Tile Designer prototype produced a better model for how much can
be built on a tile (see the design spec's "Future direction: layered tile model"):
- A tile carries **stability** (a total segment budget), **max height** and **max
  width**.
- A structure is a **side-view profile of segments**, each of which can hold a room.

The user decided that this model **supersedes** `structure_slots` (Decision 25), and
that the unused field should be **removed now** rather than kept as a misleading
placeholder until the replacement schema exists.

This revises the still-unmerged PR #26 (node schema rounds 3–4). It follows spec 13's
precedent of correcting unreviewed schema work while no consumers exist.

**Explicit non-goals:**
- This spec does **not** add the replacement capacity/segment schema to Godot. That
  arrives with the spatial-placement pass (Decision 4's Option 2), which will need a
  tile/grid representation `MapDef` doesn't have today.
- No change to `sim/`, `presentation/`, `LaneDef`, `MapDef` or any content file.
- The prototype's "routing waypoint" concept, previously `structure_slots == 0`, becomes
  a prototype-only `WAYPOINT` node type. It is recorded as a *candidate* `NodeType`
  value, not added here.

## Components changed

- `NodeDef` (`content/definitions/node_def.gd`): **removed** `structure_slots: int`
  and its doc comment. No validation referenced it, so `validate()` is unchanged.

## Scenarios (Given/When/Then)

```
Scenario: NodeDef no longer exposes structure_slots
  Given a new NodeDef
  When its properties are inspected
  Then it has no "structure_slots" property

Scenario: The existing p_f_F_c map still validates cleanly unmodified
  Given content/maps/p_f_F_c.tres loaded as-is
  When MapDef.validate() is called
  Then it returns an empty array
```

The second scenario is already covered by the existing `MapDef` content test suite and
must stay green.

## Test-first order

1. Add `test_structure_slots_is_removed` to `tests/content/definitions/test_node_def.gd`.
   It is red while the field still exists.
2. Delete the field from `node_def.gd`. The new test goes green, and the full suite stays
   green (including the `p_f_F_c` content validation).

## Notes / open questions

- The replacement schema's shape (per-tile vs per-node capacity, whether a node's
  structure lives on `NodeDef` or a new `StructureDef`) is open in the design spec's
  layered-tile section.
- Decision 26 (routes: authored links as intended topology, pathfound geometry) is
  recorded alongside this spec but changes no Godot code. `MapEdgeDef` is unchanged.

## Rubric answers (qualitative, spec-baseline)

- `single-noun-phrase`: no new files besides this spec. `node_def.gd` stays "node
  definition".
- `ocp-extension-point`: not applicable. This removes an unused field and adds no
  extension point.
- `lsp-contract-scope`: not applicable. No shared base or interface is involved.
- `isp-fit`: `NodeDef`'s public surface shrinks by one unused export. `validate()` is
  unchanged.
- `dip-direction`: unchanged. `NodeDef` stays pure data.

## Structured rubric notes

- `spec-type-declared`: `hybrid`. The schema change is `code` (TDD applies); the
  Decisions are documentation.
- `tdd-plan-present`: see Scenarios and Test-first order above.
- `no-drift`: revises `specs/07`/`specs/09`/`specs/12`'s mentions of the field with
  pointers here. Decision 25 records the supersession, and Decision 26 the route model.
- `commit-classification-plan`: `docs: add spec 14 for structure_slots removal`;
  `feat(content)!: remove unused NodeDef.structure_slots` (schema, TDD; breaking in form
  only, since nothing consumed it); `docs: record Decisions 25 and 26`. Three commits.
