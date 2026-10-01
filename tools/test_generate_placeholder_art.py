"""Tests for generate_placeholder_art.py (specs/18-map-viewer.md)."""

from __future__ import annotations

import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_placeholder_art import SHAPES, write_all  # noqa: E402

# Every file assets/placeholder/map/map_art_set.tres references.
EXPECTED = {"origin", "resource", "fort", "neutral", "waypoint", "hidden_badge", "critical_badge"}


class PlaceholderArtTest(unittest.TestCase):
    def test_writes_one_well_formed_svg_per_art_slot(self):
        with tempfile.TemporaryDirectory() as tmp:
            written = write_all(Path(tmp))
            self.assertEqual({p.stem for p in written}, EXPECTED)
            for path in written:
                root = ET.parse(path).getroot()
                self.assertTrue(root.tag.endswith("svg"), path)
                self.assertEqual(root.get("viewBox"), "0 0 64 64")

    def test_the_art_set_references_every_generated_file(self):
        art_set = Path(__file__).resolve().parents[1] / "assets/placeholder/map/map_art_set.tres"
        text = art_set.read_text(encoding="utf-8")
        for name in SHAPES:
            self.assertIn(f"res://assets/placeholder/map/{name}.svg", text)


if __name__ == "__main__":
    unittest.main()
