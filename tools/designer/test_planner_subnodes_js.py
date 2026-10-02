"""A node's subnodes in the planner (tools/designer/planner_subnodes.js, spec 26 round 1,
Decision 72), run with Node: default areas clipped to the node and round other zones,
capture cells always in their zone, refusals, removal, and undo across plan and subnodes.
Skipped where Node isn't installed.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent

RUNNER = """
const s = require(process.argv[1]);
const t = require(process.argv[2]);
const out = {};
// One tile, cells 0..63 each way.
const ctx = {inFootprint: (x, y) => x >= 0 && y >= 0 && x < 64 && y < 64};
const subs = [];
out.wellId = s.place(subs, 'WELL', 20, 20, ctx);
const well = subs[0];
out.wellSizes = [well.capture.length, well.zone.length];
out.cornerId = s.place(subs, 'OBJECTIVE', 1, 1, ctx);
out.cornerSizes = [subs[1].capture.length, subs[1].zone.length];  // clipped at the tile edge
out.insideOther = s.place(subs, 'KEEP', 22, 22, ctx);
out.offNode = s.place(subs, 'KEEP', 70, 5, ctx);
out.nearId = s.place(subs, 'ORE_VEIN', 30, 20, ctx);
const vein = subs[2];
out.veinOverlaps = vein.zone.some(c => s.has(well.zone, c[0], c[1]));
out.secondWell = s.place(subs, 'WELL', 50, 50, ctx);
// Painting: a capture cell joins the zone; a zone cell leaving takes its capture cell.
out.paintCapture = s.paint(subs, 'well_1', 'capture', 40, 40, true, ctx);
out.joinedZone = s.has(well.zone, 40, 40);
s.paint(subs, 'well_1', 'zone', 20, 21, false, ctx);
out.trimmed = [s.has(well.zone, 20, 21), s.has(well.capture, 20, 21)];
s.paint(subs, 'well_1', 'zone', 20, 20, false, ctx);
out.markerKept = s.has(well.zone, 20, 20);
out.intoOther = s.paint(subs, 'well_1', 'zone', 30, 20, true, ctx);
out.offTile = s.paint(subs, 'well_1', 'zone', -1, 5, true, ctx);
out.owner = s.owner(subs, 30, 20).id;
// Problems and removal.
const empty = {id: 'objective_9', type: 'OBJECTIVE', at: [60, 60], capture: [], zone: [[60, 60]]};
out.problems = s.problems([empty]);
out.removed = s.remove(subs, 'ore_vein_1') && subs.map(x => x.id);
// Undo covers the plan and the subnodes together.
const node = {plan: t.emptyPlan(), subnodes: [], other: 'kept'};
const h = new t.History(['plan', 'subnodes']);
h.record(node);
s.place(node.subnodes, 'WELL', 10, 10, ctx);
node.plan.solid_cells['10,10,0'] = 'ROCK';
node.other = 'changed';
out.undone = h.undo(node) && [node.subnodes.length, Object.keys(node.plan.solid_cells).length, node.other];
out.redone = h.redo(node) && [node.subnodes.length, node.plan.solid_cells['10,10,0']];
process.stdout.write(JSON.stringify(out));
"""


@unittest.skipIf(shutil.which("node") is None, "Node is not installed")
class PlannerSubnodesJsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        result = subprocess.run(
            ["node", "-e", RUNNER, str(HERE / "planner_subnodes.js"), str(HERE / "planner_tools.js")],
            capture_output=True,
            text=True,
            check=True,
        )
        cls.out = json.loads(result.stdout)

    def test_placing_gives_default_square_areas(self) -> None:
        self.assertEqual(self.out["wellId"], "well_1")
        self.assertEqual(self.out["wellSizes"], [9, 121])

    def test_default_areas_are_clipped_to_the_node(self) -> None:
        self.assertEqual(self.out["cornerId"], "objective_1")
        self.assertEqual(self.out["cornerSizes"], [16, 100])  # the 4x4 fits; the 16x16 is cut to 10x10

    def test_placing_is_refused_inside_another_zone_or_off_the_node(self) -> None:
        self.assertIsNone(self.out["insideOther"])
        self.assertIsNone(self.out["offNode"])

    def test_default_zones_stop_at_another_zone(self) -> None:
        self.assertEqual(self.out["nearId"], "ore_vein_1")
        self.assertFalse(self.out["veinOverlaps"])

    def test_ids_count_per_type(self) -> None:
        self.assertEqual(self.out["secondWell"], "well_2")

    def test_a_capture_cell_joins_the_zone(self) -> None:
        self.assertTrue(self.out["paintCapture"])
        self.assertTrue(self.out["joinedZone"])

    def test_removing_a_zone_cell_takes_its_capture_cell(self) -> None:
        self.assertEqual(self.out["trimmed"], [False, False])
        self.assertTrue(self.out["markerKept"])

    def test_painting_is_refused_in_another_zone_or_off_the_node(self) -> None:
        self.assertFalse(self.out["intoOther"])
        self.assertFalse(self.out["offTile"])
        self.assertEqual(self.out["owner"], "ore_vein_1")

    def test_an_empty_capture_area_is_a_problem(self) -> None:
        self.assertEqual(self.out["problems"], ["subnode 'objective_9': its capture area is empty"])

    def test_remove(self) -> None:
        self.assertEqual(self.out["removed"], ["well_1", "objective_1", "well_2"])

    def test_undo_covers_plan_and_subnodes_only(self) -> None:
        self.assertEqual(self.out["undone"], [0, 0, "changed"])
        self.assertEqual(self.out["redone"], [1, "ROCK"])


if __name__ == "__main__":
    unittest.main()
