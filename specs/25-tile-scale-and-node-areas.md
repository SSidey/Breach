# Spec 25: Tile scale and node areas

Decision 68. A tile is 64 × 64 cells, and a node is a painted area of tiles of any shape.

## Purpose

The planner's example structures (spec 24 round 4) showed that a 16 × 16 tile, about
27 m across, is cramped:
- The user's reference watch tower (24 × 24 × 30 ft) is 4 × 4 cells and 5 levels high.
- A small castle with towers that size at its front needs about 48 × 48 cells, with ground
  in front for an attack.
- Base and farm on P-f-F-c were about 110 m apart.

With 64-cell tiles a tile is about 109 m across. Most structures fit one tile, and large
ones cover a painted area of tiles.

## Round 1: the scale

- `MapLayoutDef.CELLS_PER_TILE := 64` is the ground code's one scale constant: the surface
  interpolation between tile centres and the channels drawn through them. The surface's
  quarters per column (`/ 16.0`) are a different thing and stay.
- **The formation sim keeps speeds per cell** (the user: "let's see how it pans out"):
  - a rank is exactly one cell (1/64 of a tile)
  - melee reach is about 1.1 cells
  - travel is 8 cells a second (0.125 tiles a second)

  So marches over the same map take about four times as long.
- **Swaps:** a grem swap is 7 ticks, a whole cell crowded (0.625 s). A brute's stays 9.
- **The squad layer** draws units a quarter the size, and the camera zooms to 160× to
  inspect them.
- **Tests:** the ground tests keep their slopes and channels at the new scale, a test pins
  the tile size, and `test_formation_scale.gd` pins the formation scale in cells.

## Round 2: node areas

- **`NodeDef.tile` and `NodeDef.footprint`.**
  - A footprint is any connected shape of map tiles that includes the node's own tile;
    an empty footprint means just that tile.
  - `MapDef` refuses two nodes sharing a tile.
  - A node with no tile (hand-built maps, or imports before Decision 68) covers none, so
    older maps still validate.
- **The designer's Node area tool:** select a node, then click or drag tiles to add or
  remove them. It refuses a tile another node owns, a gap that would split the area, and
  removing the node's own tile. Covered tiles are outlined on the map. The export carries
  `footprint`, and the importer reads it.
- **Plans span the footprint.**
  - Cells are measured from the node's own tile, so they go negative up and left of it.
  - The planner's grid covers the footprint's bounding box. Tiles off the footprint are
    shaded and refused, and tile edges are drawn.
  - Each cell takes its own tile's ground: bearing (load paths now take bearing per
    column, in the game and the designer, and the shared cases include two terrains),
    dig depth and strata.
- **Zoom** (−/+ or Ctrl+wheel, 4 to 24 px a cell) and a scrolling grid.
- **Older plans** drawn on 16-cell tiles are recentred (+24, +24) when the designer opens
  them (`tile_cells` records the scale). The Godot importer takes plans as the designer
  writes them.
- **Examples rebuilt for 64-cell tiles,** each naming its ground:
  - **Farmer's house (fields):** a timber house with a shed and a fenced yard.
  - **Watch tower (rocky ground):** the user's 24 × 24 × 30 ft tower, 4 × 4 cells and 5
    levels, with 4/8 rock walls for three levels and timber above.
  - **Palisade fort (fields):** 32 × 32, with gate towers, corner towers and a barracks.
  - **Castle (rocky ground):** 48 × 48 inside a water-filled moat with a causeway. It has
    a rock curtain wall, two 8 × 8 gate towers, an 8 × 8 keep and a hall.
  - A test checks that each stands on its ground, and that the stone ones would sink on
    fields.
- **What tuning the castle showed:**
  - Timber storeys carrying an 8 × 8 floor and roof need 3/8 walls.
  - Floors over 3 cells from a wall exceed timber's span; that's why the keep is 8 × 8.
  - Rock door posts carry the lintel's load, so on rocky ground (64 per column) towers
    keep rock to the lower two or three levels.

## Notes / open questions

- How the four-times-longer marches feel in play, to be judged in the feel test.
- Subnode painting within a node is the round after.
