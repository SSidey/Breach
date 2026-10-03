"""The planner's example structures (tools/designer/planner_examples.js, spec 24 round 4):
each fits one 16 x 16 tile and stands on fields (bearing 4) under the shared load paths
(load_paths.js, the game's rule). Run with Node; skipped where Node isn't installed.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
TERRAIN = HERE.parent.parent / "content" / "designer" / "terrain.json"

RUNNER = """
require(process.argv[1]);
const examples = require(process.argv[2]);
const paths = require(process.argv[3]);
const library = JSON.parse(require('fs').readFileSync(process.argv[4], 'utf8'));
const materials = {};
library.materials.forEach(m => { materials[m.id] = {weight: m.weight, strength: m.strength, span: m.span,
  flows: (m.traits || {}).flows || 0}; });
const out = examples.map(e => {
  const plan = e.build();
  const xs = [], ys = [];
  Object.keys(plan.solid_cells).forEach(k => { const p = k.split(',').map(Number); xs.push(p[0]); ys.push(p[1]); });
  plan.faces.forEach(f => { xs.push(f.x); ys.push(f.y); });
  plan.dug.forEach(d => { xs.push(d[0]); ys.push(d[1]); });
  return {id: e.id, failed: paths.solve(plan, materials, 4).failed, faces: plan.faces.length,
    minXY: Math.min(...xs, ...ys), maxXY: Math.max(...xs, ...ys),
    levels: Math.max(...plan.faces.map(f => f.level))};
});
process.stdout.write(JSON.stringify(out));
"""


@unittest.skipIf(shutil.which("node") is None, "Node is not installed")
class PlannerExamplesJsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        result = subprocess.run(
            [
                "node", "-e", RUNNER,
                str(HERE / "planner_tools.js"), str(HERE / "planner_examples.js"),
                str(HERE / "load_paths.js"), str(TERRAIN),
            ],
            capture_output=True,
            text=True,
            check=True,
        )
        cls.examples = {e["id"]: e for e in json.loads(result.stdout)}

    def test_there_are_four_examples(self) -> None:
        self.assertEqual(sorted(self.examples), ["castle", "farmhouse", "fort", "tower"])

    def test_every_example_stands_on_fields(self) -> None:
        for example_id, example in self.examples.items():
            with self.subTest(example_id):
                self.assertEqual(example["failed"], [])

    def test_every_example_fits_one_tile(self) -> None:
        for example_id, example in self.examples.items():
            with self.subTest(example_id):
                self.assertGreaterEqual(example["minXY"], 0)
                self.assertLessEqual(example["maxXY"], 16)  # a north/west face may sit on edge 16


if __name__ == "__main__":
    unittest.main()
