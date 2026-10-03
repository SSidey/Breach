"""The structure planner's editing rules (tools/designer/planner_tools.js, spec 24 round 3,
Decision 67), run with Node: edge picking that keeps to one line, flush walls that grow
into the cell drawn from, digs that must connect, fills, rooms, and undo. Skipped where
Node isn't installed.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent

RUNNER = """
const t = require(process.argv[1]);
const out = {};
out.north = t.nearestEdge(2.5, 3.05);
out.south = t.nearestEdge(2.5, 3.95);
out.east = t.nearestEdge(2.97, 3.5);
out.locked = t.edgeOnLine(5.5, 4.6, {axis: 'h', index: 4, before: true});
out.southFace = t.face(2, 3, 0, 'south');
const p = t.emptyPlan();
out.digTop = t.canDig(p, 1, 1, -1, 4);
out.digPocket = t.canDig(p, 1, 1, -2, 4);
p.dug.push([1, 1, -1]);
out.digBelowHole = t.canDig(p, 1, 1, -2, 4);
out.digTooDeep = t.canDig(p, 1, 1, -5, 4);
out.digAboveGround = t.canDig(p, 1, 1, 0, 4);
t.fill(p, 1, 1, -1, 'WATER');
out.waterFill = p.fills['1,1,-1'];
t.fill(p, 1, 1, -1, 'GROUND');
out.restored = {dug: p.dug.length, fills: Object.keys(p.fills).length};
const room = t.emptyPlan();
t.addRoom(room, {x0: 0, y0: 0, x1: 3, y1: 2}, 0, {height: 2,
  wall: {material: 'TIMBER', thickness: 1}, floor: {on: true, material: 'TIMBER', thickness: 2},
  ceiling: {on: true, material: 'TIMBER', thickness: 8}});
out.roomFaces = room.faces.length;
out.roomSouthWall = room.faces.find(f => f.x === 0 && f.y === 3 && f.level === 0 && f.side === 'north');
out.roomCeilings = room.faces.filter(f => f.side === 'floor' && f.level === 2).length;
const h = new t.History();
const plan = t.emptyPlan();
h.record(plan);
plan.solid_cells['0,0,0'] = 'ROCK';
out.undone = h.undo(plan) && Object.keys(plan.solid_cells).length;
out.redone = h.redo(plan) && plan.solid_cells['0,0,0'];
const solid = t.emptyPlan();
t.addRoom(solid, {x0: 2, y0: 2, x1: 2, y1: 2}, 0, {height: 1, wall: {material: 'TIMBER', thickness: 1},
  floor: {on: true, material: 'TIMBER', thickness: 1}, ceiling: {on: true, material: 'TIMBER', thickness: 1}});
t.setSolid(solid, 2, 2, 0, 'ROCK');
out.solidFaces = solid.faces.map(f => f.level + ':' + f.side);
out.solidCell = solid.solid_cells['2,2,0'];
const ring = t.emptyPlan();
t.perimeterWalls(ring, {x0: 1, y0: 1, x1: 3, y1: 2}, 0, 'TIMBER', 1);
out.ringWalls = ring.faces.length;
out.areaCells = t.cellsOf({x0: 3, y0: 1, x1: 1, y1: 2}).length;
const legacy = t.normalise({solid_cells: {'2,3,0': 'ROCK'}, faces: [{x: 1, y: 1, level: 0, side: 'north', material: 'TIMBER', thickness: 1}], dug: [[4, 4, -1]], fills: {}, loads: {}});
out.legacy = {cells: Object.keys(legacy.solid_cells), face: [legacy.faces[0].x, legacy.faces[0].y], dug: legacy.dug[0], scale: legacy.tile_cells};
out.again = Object.keys(t.normalise(legacy).solid_cells);
out.leftEdge = t.nearestEdge(-60.5, 3.02, {x0: -64, y0: 0, x1: 63, y1: 63});
out.clamped = t.nearestEdge(-80, 3.5, {x0: -64, y0: 0, x1: 63, y1: 63});
process.stdout.write(JSON.stringify(out));
"""


@unittest.skipIf(shutil.which("node") is None, "Node is not installed")
class PlannerToolsJsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        result = subprocess.run(
            ["node", "-e", RUNNER, str(HERE / "planner_tools.js")],
            capture_output=True,
            text=True,
            check=True,
        )
        cls.out = json.loads(result.stdout)

    def test_the_nearest_grid_line_picks_the_edge(self) -> None:
        self.assertEqual(self.out["north"]["side"], "north")
        self.assertEqual((self.out["south"]["side"], self.out["south"]["index"]), ("south", 4))
        self.assertEqual(self.out["east"]["side"], "east")

    def test_a_stroke_keeps_to_its_line_and_side(self) -> None:
        self.assertEqual(self.out["locked"], {"x": 5, "y": 3, "side": "south"})

    def test_a_south_wall_grows_back_into_the_cell_it_was_drawn_from(self) -> None:
        face = self.out["southFace"]
        self.assertEqual((face["x"], face["y"], face["side"]), (2, 4, "north"))
        self.assertTrue(face["into_neighbour"])

    def test_digs_must_connect_to_the_surface_or_a_dug_cell(self) -> None:
        self.assertTrue(self.out["digTop"])
        self.assertFalse(self.out["digPocket"])
        self.assertTrue(self.out["digBelowHole"])
        self.assertFalse(self.out["digTooDeep"])
        self.assertFalse(self.out["digAboveGround"])

    def test_filling_with_ground_undoes_the_dig(self) -> None:
        self.assertEqual(self.out["waterFill"], "WATER")
        self.assertEqual(self.out["restored"], {"dug": 0, "fills": 0})

    def test_a_room_adds_flush_walls_a_floor_and_a_ceiling(self) -> None:
        self.assertEqual(self.out["roomFaces"], 28 + 12 + 12)  # 14 walls x 2 levels, floor, roof
        self.assertTrue(self.out["roomSouthWall"]["into_neighbour"])
        self.assertEqual(self.out["roomCeilings"], 12)

    def test_a_solid_cell_replaces_the_walls_and_floor_in_it(self) -> None:
        self.assertEqual(self.out["solidCell"], "ROCK")
        self.assertEqual(self.out["solidFaces"], ["1:floor"])  # only the roof above it stays

    def test_an_area_has_its_cells_and_a_ring_of_walls(self) -> None:
        self.assertEqual(self.out["ringWalls"], 10)  # 3 x 2: 2 x 3 + 2 x 2 edges
        self.assertEqual(self.out["areaCells"], 6)

    def test_a_plan_from_sixteen_cell_tiles_moves_to_the_middle_once(self) -> None:
        self.assertEqual(self.out["legacy"]["cells"], ["26,27,0"])
        self.assertEqual(self.out["legacy"]["face"], [25, 25])
        self.assertEqual(self.out["legacy"]["dug"], [28, 28, -1])
        self.assertEqual(self.out["legacy"]["scale"], 64)
        self.assertEqual(self.out["again"], ["26,27,0"])

    def test_edges_are_picked_within_the_footprints_bounds(self) -> None:
        self.assertEqual((self.out["leftEdge"]["x"], self.out["leftEdge"]["side"]), (-61, "north"))
        self.assertEqual(self.out["clamped"]["x"], -64)

    def test_undo_and_redo(self) -> None:
        self.assertEqual(self.out["undone"], 0)
        self.assertEqual(self.out["redone"], "ROCK")


if __name__ == "__main__":
    unittest.main()
