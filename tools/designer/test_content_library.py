"""content_library.py and GET /api/registry (Decision 128): trait targets follow the tags'
agreement narrowed by "only", and usage finds the content files using each id."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from content_library import read_registry, targets  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
TAGS = {
    "behaviour": {"id": "behaviour", "targets": ["unit", "leader"]},
    "combat": {"id": "combat", "targets": ["unit", "weapon"]},
    "physical": {"id": "physical", "targets": ["unit", "material"]},
}
UNIT_TRES = """[gd_resource type="Resource" format=3]

[resource]
id = "grem"
tags = Array[String](["grem", "small"])
traits = {
"cunning": 1,
"hardened": 2
}
"""


class TargetsTest(unittest.TestCase):
    def test_a_trait_sits_where_its_tags_agree(self):
        self.assertEqual(targets({"tags": ["behaviour"]}, TAGS), ["unit", "leader"])
        self.assertEqual(targets({"tags": ["combat", "physical"]}, TAGS), ["unit"])

    def test_only_narrows_the_targets(self):
        self.assertEqual(targets({"tags": ["combat"], "only": ["weapon"]}, TAGS), ["weapon"])

    def test_an_untagged_trait_sits_nowhere(self):
        self.assertEqual(targets({"tags": []}, TAGS), [])


class ReadRegistryTest(unittest.TestCase):
    def test_given_a_temp_repo_then_kinds_targets_and_usage_are_read(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            registry = root / "content" / "registry"
            registry.mkdir(parents=True)
            (registry / "tags.json").write_text(json.dumps({"tags": list(TAGS.values())}))
            traits = [{"id": "cunning", "tags": ["behaviour"]}, {"id": "flows", "tags": []}]
            (registry / "traits.json").write_text(json.dumps({"traits": traits}))
            (root / "content" / "units").mkdir()
            (root / "content" / "units" / "grem.tres").write_text(UNIT_TRES)
            (root / "content" / "designer").mkdir()
            terrain = {"water": {"traits": {"flows": 1}}}
            (root / "content" / "designer" / "terrain.json").write_text(json.dumps(terrain))

            got = read_registry(root)

        self.assertEqual(got["statuses"], [])
        self.assertEqual(got["traits"][0]["targets"], ["unit", "leader"])
        self.assertEqual(got["usage"]["cunning"], ["content/units/grem.tres"])
        self.assertEqual(got["usage"]["hardened"], ["content/units/grem.tres"])
        self.assertEqual(got["usage"]["small"], ["content/units/grem.tres"])
        self.assertEqual(got["usage"]["flows"], ["content/designer/terrain.json"])

    def test_the_repo_registry_reads_with_known_targets_and_usage(self):
        got = read_registry(REPO)
        by_id = {t["id"]: t for t in got["traits"]}
        self.assertEqual(by_id["cunning"]["targets"], ["unit", "leader"])
        self.assertEqual(by_id["siege"]["targets"], ["weapon"])
        self.assertIn("content/weapons/brute_fists.tres", got["usage"]["siege"])


if __name__ == "__main__":
    unittest.main()
