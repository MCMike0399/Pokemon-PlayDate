"""GYM tileset tones from Miguel's approved Celadon mockup C.

The stand-ins are per tileset. Shade.LIGHT stays the global Bayer pair.
Source grids are unchanged. This fails on the live tree until
tools/notes/lane-e-gym-terrain-tones.patch is applied.
"""

import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-gym-terrain-tones.patch"


def apply_patch(root):
    for rel in ("tools/generate_terrain_atlases.py", "tools/terrain_atlases/pixels.py"):
        dest = root / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text((ROOT / rel).read_text())
    (root / "Source/data").mkdir(parents=True)
    return subprocess.run(
        ["patch", "-p1", "-d", str(root), "-i", str(PATCH)],
        check=False, capture_output=True, text=True)


class LaneEGymTerrainTests(unittest.TestCase):
    def test_patch_applies_and_does_not_retune_global_shade(self):
        patch = PATCH.read_text()
        self.assertIn("Source/data/terrainToneOverrides.json", patch)
        self.assertIn('"GYM"', patch)
        self.assertIn("approved-by-miguel-2026-11-19", patch)
        self.assertNotIn("shade.lua", patch)
        self.assertNotIn("Shade.LIGHT", patch)
        self.assertNotIn("MallocPoolSize", patch)

    def test_patched_tree_overrides_only_the_gym_tileset(self):
        overrides = (ROOT / "Source/data/terrainToneOverrides.json").read_text()
        pixels = (ROOT / "tools/terrain_atlases/pixels.py").read_text()
        generator = (ROOT / "tools/generate_terrain_atlases.py").read_text()
        self.assertIn('"GYM"', overrides)
        self.assertNotIn('"OVERWORLD"', overrides)
        self.assertIn("def bit(", pixels)
        self.assertIn("tones is None", pixels)
        self.assertIn("quadrant_tones", generator)

    def test_live_gym_tiles_use_the_mockup_tones(self):
        self.assertTrue((ROOT / "Source/data/terrainToneOverrides.json").is_file())
        pixels = (ROOT / "tools/terrain_atlases/pixels.py").read_text()
        self.assertIn("def bit(", pixels)


if __name__ == "__main__":
    unittest.main()
