# Spec 26: Subnodes

Decision 72. A node's subnodes are its objectives. Each has a painted capture area and
zone of influence. One side holding them all controls the node; otherwise the node is
contested.

## Purpose

A node is a painted area of tiles (Decision 68), so holding a node should mean holding
what's in it. Subnodes split that into objectives, each with two areas:
- **a capture area**, where units must stand to take it
- **a zone of influence**, which its holder then controls: building, benefit, and any
  building inside it

Cells outside every zone follow the node's status. When the node is contested, those
cells belong to nobody.

## Round 1: subnodes as data, painted in the planner

- **`SubnodeDef`** (`content/definitions/subnode_def.gd`):

  | Field | What it holds |
  |-------|---------------|
  | `id` | unique within its node |
  | `subnode_type` | `WELL`, `ORE_VEIN`, `KEEP` or `OBJECTIVE` (painted from scratch) |
  | `at` | the marker cell |
  | `capture_cells` | the capture area |
  | `zone_cells` | the zone of influence |

  - Cells are columns in the node's local cells, the frame plans use (Decision 68), and a
    subnode covers every level of its columns.
  - `validate()` checks the subnode on its own:
    - an id
    - a known type
    - a capture area that isn't empty
    - every capture cell, and the marker, inside the zone
- **`NodeDef.subnodes`.** A node with a tile also checks its subnodes together, through
  `SubnodeDef.validate_in_node`:
  - ids are unique
  - every zone cell lies on one of the node's tiles (a cell's tile is the node's own tile
    plus whole tiles of 64 cells, so negative cells fall on tiles up and left)
  - no cell is in two zones
- **Import:** the designer export's node `subnodes` (cells as `[x, y]` pairs) become
  `SubnodeDef`s.
- **The planner's Subnodes tool** (`planner_subnodes.js` holds the rules; `planner.js`
  and `planner_draw.js` hold the panel and drawing):
  - **Place:** click a cell to place a subnode of the chosen type, with default square
    areas:

    | Type | Capture | Zone |
    |------|---------|------|
    | Well | 3 × 3 | 11 × 11 |
    | Ore vein | 4 × 4 | 12 × 12 |
    | Keep | 6 × 6 | 20 × 20 |
    | Objective | 4 × 4 | 16 × 16 |

    The defaults are clipped to the node's tiles and stop at other zones. Placing is
    refused inside another zone.
  - **Capture area and Zone:** paint either one for the chosen subnode, freehand or as a
    rectangle, so a zone can sit off to one side.
    - A capture cell joins the zone too.
    - Removing a zone cell takes its capture cell with it.
    - The marker's cell stays in the zone.
    - Cells off the node or in another zone are refused.
  - **Remove:** click inside a subnode's zone to remove that subnode.
  - **Drawing:** subnodes are drawn on every level:
    - zones tinted in their type's colour
    - capture areas stronger
    - the marker labelled with its id
    - the chosen subnode outlined

    They're fainter while another tool is in use.
  - **Undo and redo** cover subnodes as well as the plan, through `History(['plan',
    'subnodes'])`. Clear plan and Load example leave subnodes alone.
  - **Export:** the export carries `subnodes` per node and warns about a subnode with an
    empty capture area.

## Notes / open questions

- **Capture and control aren't simulated yet**: holding a capture area with no enemy
  present, and the node's controlled or contested status. They come when structures and
  nodes reach the sim.
- **Subnodes come from placements later**: a placed well or ore vein will bring its
  subnode, once those are placed in cells. Until then a subnode is placed by type.
- **Levels:** a subnode covers whole columns. An objective on one level only (a cellar, a
  tower top) is open.
- **A key-objective flag** may come later. For now every subnode is required for control.
