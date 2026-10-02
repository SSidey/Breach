"""The designer's load_paths.js against the shared load-path cases (spec 24, round 2).

The same cases (tests/fixtures/structure/load_cases.json) run against Godot's LoadPaths
in tests/sim/structure/test_load_cases.gd, so the designer's live overlay and the game
apply one rule. Runs the JS with Node; skipped where Node isn't installed.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
CASES = REPO / "tests" / "fixtures" / "structure" / "load_cases.json"

RUNNER = """
const paths = require(process.argv[1]);
const fixture = JSON.parse(require('fs').readFileSync(process.argv[2], 'utf8'));
const materials = {};
fixture.materials.forEach(m => { materials[m.id] = m; });
const out = fixture.cases.map(c => {
  const r = paths.solve(c.plan, materials, c.bearing);
  return { name: c.name, failed: r.failed, loads: r.loads,
           settled: c.settled ? paths.settle(c.plan, materials, c.bearing) : null };
});
process.stdout.write(JSON.stringify(out));
"""


@unittest.skipIf(shutil.which("node") is None, "Node is not installed")
class LoadPathsJsTest(unittest.TestCase):
    def test_every_shared_case_holds(self) -> None:
        result = subprocess.run(
            ["node", "-e", RUNNER, str(HERE / "load_paths.js"), str(CASES)],
            capture_output=True,
            text=True,
            check=True,
        )
        actual = {entry["name"]: entry for entry in json.loads(result.stdout)}
        for case in json.loads(CASES.read_text())["cases"]:
            with self.subTest(case["name"]):
                got = actual[case["name"]]
                self.assertEqual(got["failed"], case["failed"])
                for key, units in case.get("loads", {}).items():
                    self.assertEqual(got["loads"][key], units)
                if "settled" in case:
                    self.assertEqual(got["settled"], case["settled"])


if __name__ == "__main__":
    unittest.main()
