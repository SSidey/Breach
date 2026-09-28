---
spec_type: hybrid
status: active
parent_spec: ../Breach — Reverse Tower Defense Design Spec.md
---

# NodeDef.hidden_from_faction_ids: per-faction hidden nodes

## Purpose

Secret and secondary objectives need some nodes to be **unknown to some factions** when a
map starts. Examples: a hidden resource cache the player has to scout for, or a secret
enemy base. This ties into the base spec's Scout/fog-of-war concept and Decision 27's
hidden and optional routes. The Lane Tile Designer prototype already sketched it
per node; this adds the real field so the upcoming "Godot renders the designer's
output" work can read it.

`NodeDef` gains `hidden_from_faction_ids: Array[String] = []`: the factions that do
**not** know this node exists at map start. An empty list (the default) means every
faction knows it. The field is **additive and inert**, following the `owning_faction_id`
pattern: authored and validated, not yet read by `sim/` or `presentation/`.

This lands on the still-unmerged PR #26 (the `NodeDef` schema PR), following the
precedent of specs 13 and 14.

**Explicit non-goals:**
- No reveal mechanics: how a hidden node becomes known (scouting, events, captured
  intelligence) is not designed here.
- No `sim/`, `presentation/`, `LaneDef` or content-file changes. `content/maps/p_f_F_c.tres`
  keeps validating unmodified, because the default is empty.
- Hidden *links* are not covered; they belong to the route work that follows Decision 27.

## Components changed

- `NodeDef` (`content/definitions/node_def.gd`): **added**
  `hidden_from_faction_ids: Array[String] = []`. `validate()` rejects empty ids and
  duplicate ids (local checks only).
- `MapDef` (`content/definitions/map_def.gd`): `_validate_node_references()` checks each id
  against the map's faction roster (`_all_faction_ids()`). This is the same split every
  other cross-reference in this schema uses.

## Scenarios (Given/When/Then)

```
Scenario: A node hidden from no one is valid
  Given a NodeDef with default hidden_from_faction_ids
  When validate() is called
  Then it returns no hidden_from_faction_ids errors

Scenario: An empty faction id in hidden_from_faction_ids is invalid
  Given a NodeDef with hidden_from_faction_ids = [""]
  When validate() is called
  Then it returns an error naming hidden_from_faction_ids

Scenario: A duplicate faction id in hidden_from_faction_ids is invalid
  Given a NodeDef with hidden_from_faction_ids = ["the_kingdom", "the_kingdom"]
  When validate() is called
  Then it returns an error naming the duplicate id

Scenario: Hiding a node from an unknown faction is invalid
  Given a MapDef whose roster has "player", and a node hidden from "ghost_faction"
  When MapDef.validate() is called
  Then it returns an error naming "ghost_faction"

Scenario: Hiding a node from a declared faction is valid
  Given a MapDef whose roster has "player" and "the_kingdom", and a node hidden from "the_kingdom"
  When MapDef.validate() is called
  Then it returns an empty array
```

The existing `p_f_F_c` content validation test must stay green.

## Test-first order

1. `NodeDef.validate()`: the empty-id and duplicate-id tests in `test_node_def.gd` (red
   before the field exists), plus the default-valid test.
2. `MapDef.validate()`: the unknown-faction and declared-faction tests in
   `test_map_def_factions.gd`.
3. Add the field and the checks; full suite green.

## Rubric answers (qualitative, spec-baseline)

- `single-noun-phrase`: no new files besides this spec.
- `ocp-extension-point`: a future reveal system reads the field. No change is needed here
  to add reveal rules.
- `lsp-contract-scope`: not applicable. No shared base or interface is involved.
- `isp-fit`: `NodeDef` gains one export. `validate()` is unchanged in signature.
  `MapDef`'s public surface is unchanged.
- `dip-direction`: unchanged. Pure data, no dependency on `sim/` or `presentation/`.

## Structured rubric notes

- `spec-type-declared`: `hybrid`. The schema change is `code` (TDD applies); Decision 28
  is documentation.
- `tdd-plan-present`: see Scenarios and Test-first order above.
- `no-drift`: additive only. It follows `owning_faction_id`'s validation split, and
  Decision 28 records it.
- `commit-classification-plan`: `docs: add spec 15 …`; `feat(content): add
  NodeDef.hidden_from_faction_ids` (schema plus tests); `docs: record Decision 28`;
  `chore:` progress row.
