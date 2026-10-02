---
spec_type: hybrid
status: active
parent_spec: ../Breach — Reverse Tower Defense Design Spec.md
---

# Structure Plans

## Purpose

Decisions 52, 53, 55, 57, 61 and 65 replace the side-on structure profile with a
**plan**: cells over a site, in levels above and below ground. A plan holds:
- **solid cells** of a material (cell walls, keeps, fill)
- **faces** between cells: **face walls** with a material and a thickness in eighths, and
  **floors** under a cell (a roof is the floor of the cell above the top level)
- cells **dug** out of the ground
- extra **loads** resting in a cell (a ballista, stores)

Every element carries its weight down a **load path** to the ground (Decision 61). Where
the load exceeds an element's capacity, or nothing holds it within its span, it fails.

This spec builds the plan and the load paths in rounds:
1. the data and the solver (this round)
2. the designer's plan editor, replacing the side-on editor and its legacy capacity
   fields
3. collapse in play: creaking, rubble, and the overlay

## Round 1: plans and load paths (Decisions 61, 65)

- **`MaterialDef.strength`:** the load an eighth of a cell carries (placeholders: timber 6,
  rock 20). The designer edits it.
- **`StructureFaceDef`:** a cell (x, y, level), a side (north, west or floor), a material,
  and a thickness in eighths. South and east faces are stored as the neighbour's north
  and west.
- **`StructurePlanDef`:** solid cells (cell → material), faces, dug cells, and loads
  (cell → load units).
- **`LoadPaths`** (`sim/structure/`, pure) solves a plan over a ground bearing:
  - **Elements** are each solid cell and face. A face weighs weight × thickness and
    carries strength × thickness. A solid cell weighs weight × 8 and carries
    strength × 8.
  - **Direct support:**
    - A solid cell rests on the solid cell beneath it, the floor under it, or (just
      above ground) on the ground, unless that ground is dug.
    - A face wall rests on the same face a level below, on a solid cell beneath either
      side, or on the ground at level 0, unless both sides are dug.
    - A floor rests on the solid cell beneath it, the face walls along its edges a
      level down, or the ground at level 0.
  - **Bridging:** an element with no direct support hangs from directly supported
    elements of its own kind, within its material's span. That kind is the next face
    along the run of a wall, the next floor, or the next solid cell. With none in reach,
    it **fails**.
  - **Loads** flow top-down. Each element passes its weight plus what rests on it,
    split equally, to its supports. A load in a cell rests on that cell's floor, or the
    solid cell beneath it, or the ground.
  - An element **fails** when its load exceeds its capacity. Elements standing on a
    ground column fail together when the column's load exceeds bearing × 8.
  - **`settle`** removes failed elements and solves again until nothing more fails,
    which is the collapse cascade.

```
Scenario: A timber wall with no floor stands
  Given a 3-long timber face wall, 2 levels high, on fields
  Then nothing fails

Scenario: A wall bridges a dug gap beneath it
  Given the same wall with the ground dug out under its middle
  Then the middle bridges to its neighbours within timber's span, and nothing fails

Scenario: A loaded roof brings its wall down
  Given a timber room roofed in timber
  Then it stands, but with a ballista on the roof the walls under it fail

Scenario: A floor beyond its span falls
  Given a floor with no wall or cell beneath it within span
  Then it fails

Scenario: The ground's bearing limits a stone tower
  Given a stone tower over one column of ground
  Then it stands up to the bearing, and one level more makes it fail

Scenario: Failure cascades
  Given a wall standing on a floor that fails
  Then settle removes the floor, then the wall
```

## Test-first order

1. `tests/content/definitions/test_structure_plan_def.gd`
2. `tests/sim/structure/test_load_paths.gd`
3. The material strength import (`test_designer_ground_import.gd`)
4. Manual (round 2): the user draws plans in the designer.

## Notes / open questions

- Loads split equally between supports; a weighted split (by stiffness) can come
  later.
- Openings (doors, slits) in face walls, furnishing elements and their weights (Decision
  55), and fire weakening timber come with later rounds.
- Physical quantities are discrete: load units in eighths (Decision 65) and heat as a
  level 0-10 (Decision 66). Loads stay additive integers rather than coarse bands.

## Rubric answers (qualitative, spec-baseline)

- `single-noun-phrase`: `structure_face_def.gd` (a face), `structure_plan_def.gd` (a
  plan), `load_paths.gd` (load paths), `structure_supports.gd` (what holds each element).
- `ocp-extension-point`: a new material is data; a new element kind adds a support rule
  in `structure_supports.gd`.
- `lsp-contract-scope`: not applicable.
- `isp-fit`: `LoadPaths` exposes `solve` and `settle`.
- `dip-direction`: `sim/structure/` reads `content/` definitions only.

## Structured rubric notes

- `spec-type-declared`: `hybrid`.
- `tdd-plan-present`: see Scenarios and Test-first order.
- `no-drift`: implements Decisions 61 and 65; walls as cells or faces per Decision 61.
- `commit-classification-plan`: `docs:` Decision 65 and this spec; `feat:` the plan,
  solver and strength; `chore:` the Gate 1 row.
