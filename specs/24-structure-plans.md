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
1. the data and the solver
2. the designer's planner, an isometric view, diagnostic views, and import into Godot
3. retiring the side-on editor and its legacy capacity fields
4. collapse in play: creaking, rubble, and the overlay in the game

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

## Round 2: the planner, isometric view and diagnostics

The user wanted "something tangible", an isometric view, and diagnostic views ("instead of
terrain colour, show load v bearing: overload black, high load red, yellow, green").
- **One rule, two implementations:**
  - `tools/designer/load_paths.js` is the designer's copy of `LoadPaths`, line for line.
  - The shared cases in `tests/fixtures/structure/load_cases.json` (9, including the
    round-1 scenarios) run against both: `tests/sim/structure/test_load_cases.gd` and
    `tools/designer/test_load_paths_js.py` (Node).
- **The planner** (`tools/designer/planner.js`): a **Plan** tab beside Structure in the
  Lanes view, for the selected node.
  - A level picker, from 3 below ground to level 7.
  - Tools: solid cell, face wall (it snaps to the nearest edge), floor or roof, dig, load,
    erase. Material, thickness in eighths, and load units as needed.
  - Drag to paint.
  - The top-down grid shows the current level.
  - The **isometric view** shows everything up to the current level (a cutaway), fitted
    to the structure: shaded boxes on the tile's ground, with dug pits.
  - **View: Material or Load v capacity.** Load colours each element green below 50% of
    capacity, yellow below 80%, red up to full, and black when failing (over capacity,
    unsupported, or on overloaded ground). A summary counts what fails.
- **Map diagnostics:** a **Show** select in the toolbar colours tiles by elevation,
  bearing, or structure load (the worst load in a tile's plan, black if anything fails)
  instead of by terrain.
- **Import:** a node's `plan` is exported with it, and `DesignerPlanBuilder` makes it
  `NodeDef.plan` in Godot.

```
Scenario: The designer and the game agree on every shared case
  Given the shared load cases
  Then LoadPaths and load_paths.js give the same failures and loads

Scenario: A plan imports with its node
  Given a node with a plan of a rock cell, a south wall, a roof, a dug cell and a load
  Then NodeDef.plan holds them, with the south wall stored as the next cell's north
```

A scripted browser run on the demo map's fort:
1. It drew a 3 × 2 timber room two levels high with an 8/8 roof, and a two-cell rock
   tower three levels high.
2. In the Load view, a ballista (40) on the roof turned the walls under it red and
   black, while the roof itself held.
3. The tower showed black at its base: three levels of rock overload fields ground
   (bearing 4, so 32 per column) without foundations.
4. The map's Show: Structure load marked the fort's tile black.

## Round 3: editing that behaves, flush walls, fills and rooms (Decision 67)

From the user's first hands-on pass over the planner:
- **Walls sit flush.** A face wall's side is on the cell edge and its thickness grows into
  the cell it was drawn from (`StructureFaceDef.into_neighbour`). Alt-click flips a wall.
  Older plans keep their own cell.
- **Placing walls:**
  - Walls snap to the nearest grid line, and the edge is highlighted before you click.
  - A drag keeps to its first line and side, so a straight run never picks up
    perpendicular strays.
- **Digging and filling:**
  - Digs must connect: open to the surface, or beside a dug cell.
  - A **Fill** tool fills a dug cell with any material. Water or lava make a moat or a
    cistern; "Ground" undoes the dig. Erase also undoes digs.
  - For support, a solid fill is ground again and a liquid fill is not
    (`StructurePlanDef.fills`). The shared load cases gain three fill cases.
- **Every level:** a stepper (▲▼, PageUp and PageDown) from the tile's dig depth to the
  ceiling over its ground. Fields reach −32.
- **Below ground**, the isometric view cuts away to the level. It shows the terrain's
  typical strata as blocks, digs carved out, and fills in their material, with liquids
  see-through.
- **Undo and redo**, one step per stroke, room or clear (Ctrl+Z, Ctrl+Shift+Z or Ctrl+Y).
- **Clear level** and **Clear plan**, each confirmed with a second click.
- **Strokes end** when the button is released anywhere, so returning to the plan never
  paints.
- **The Room tool:** drag out a rectangle and set the height and the material and
  thickness of the walls, floor and ceiling. **Apply** adds them all as one undo step.
- The old side-on Structure tab is hidden, and the Map hint's garbled text is repaired.
- **The code is split:** `planner_tools.js` holds the editing rules (tested with Node in
  `test_planner_tools_js.py`), `planner_draw.js` the drawing, and `planner.js` the
  panel. A server test checks every script the page loads is served.

A browser run checked each of these:
1. A drifting drag along a grid line placed 7 walls on one line.
2. A press followed by a buttonless move painted nothing more.
3. Undo and redo each stepped one stroke.
4. A 4 × 3 room, two levels high, added 52 faces, and one undo removed them.
5. A dig at −2 was refused until −1 above it was dug.
6. A water fill and a backfill both applied.
7. Alt-click flipped a wall, and PageUp moved up a level.

It also found, and the fix removed, one bug: focusing the planner scrolled the page, so
walls landed two rows below the cursor.

Still to come: openings and furnishing elements (doors, slits, bunks, emplacements;
Decision 55), and per-tile seeded strata in the planner, which for now shows the
terrain's typical column.

## Round 4: areas, solid overrides and example structures

From the user's second pass over the planner:
- **Draw: Freehand or Area** for every tool except Room. An area gets walls round its
  edge (flush inside) or the tool in every cell; Erase clears every cell and the walls on
  its edges.
- **A solid cell replaces the thinner pieces in it** (its edge walls and its floor at that
  level), so it becomes a solid cell only.
- **Examples** (`planner_examples.js`), loaded from the Examples menu with a
  second-click confirm (undoable). Each is built with the same editing rules as hand
  edits, fits one tile, and stands on fields. `test_planner_examples_js.py` checks both
  under the game's load paths.
  - **Farmer's house:** a 5 × 4 timber house with a roof, a shed, and a fenced yard with
    a gate.
  - **Watch tower:** four storeys on a 4 × 4 footprint, rock below and timber above.
    Rock all the way up sinks on fields; on rocky ground it could stand.
  - **Palisade fort:** a 14 × 14 timber palisade two storeys high with a two-wide gate,
    four corner towers and a barracks.
  - **Small castle:** a water-filled moat round the tile with a causeway, a rock curtain
    wall, two gate towers, a three-storey keep and a timber hall.
- **What tuning the examples showed:**
  - Fields bear 32 load units per column, so rock walls more than about two storeys high
    sink. A door's lintel loads the walls beside it, and a 1/8 timber wall can't carry a
    roof next to a door.
  - Real builders face the same choices (stone below, timber above; build on rock), so
    the rule reads true.
  - **A castle is cramped on one tile** (16 cells is about 27 m). That raises the
    question of nodes larger than a tile, which is open with the user.

## Test-first order

1. `tests/content/definitions/test_structure_plan_def.gd`
2. `tests/sim/structure/test_load_paths.gd`
3. The material strength import (`test_designer_ground_import.gd`)
4. Round 2: `tests/sim/structure/test_load_cases.gd`, `tools/designer/test_load_paths_js.py`,
   `tests/content/import/test_designer_plan_import.gd`, and a scripted browser run.
5. Manual: the user draws plans in the designer.

## Notes / open questions

- Loads split equally between supports; a weighted split (by stiffness) can come
  later.
- Openings (doors, slits) in face walls, furnishing elements and their weights (Decision
  55), and fire weakening timber come with later rounds.
- Physical quantities are discrete: load units in eighths (Decision 65) and heat as a
  level 0-10 (Decision 66). Loads stay additive integers rather than coarse bands.

## Rubric answers (qualitative, spec-baseline)

- `single-noun-phrase`: `structure_face_def.gd` (a face), `structure_plan_def.gd` (a
  plan), `load_paths.gd` (load paths), `structure_supports.gd` (what holds each element),
  `designer_plan_builder.gd` (plan import), `planner.js` (the planner), `load_paths.js`
  (the designer's load paths).
- `ocp-extension-point`: a new material is data; a new element kind adds a support rule
  in `structure_supports.gd`.
- `lsp-contract-scope`: `load_paths.js` is a second implementation of `LoadPaths`;
  both pass the shared cases in `tests/fixtures/structure/load_cases.json` unmodified.
- `isp-fit`: `LoadPaths` exposes `solve` and `settle`.
- `dip-direction`: `sim/structure/` reads `content/` definitions only.

## Structured rubric notes

- `spec-type-declared`: `hybrid`.
- `tdd-plan-present`: see Scenarios and Test-first order.
- `no-drift`: implements Decisions 61 and 65; walls as cells or faces per Decision 61.
- `commit-classification-plan`: `docs:` Decision 65 and this spec; `feat:` the plan,
  solver and strength; `chore:` the Gate 1 row.
