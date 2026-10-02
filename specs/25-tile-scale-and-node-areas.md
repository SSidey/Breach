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

## Round 2: node areas (next)

- `NodeDef.tile` and `NodeDef.footprint`: any connected shape, including the node's own
  tile. No tile is shared by two nodes.
- The designer's Node area tool paints the footprint.
- Plans span the footprint, with each cell on its own tile's ground.

## Notes / open questions

- How the four-times-longer marches feel in play, to be judged in the feel test.
- Subnode painting within a node is the round after.
