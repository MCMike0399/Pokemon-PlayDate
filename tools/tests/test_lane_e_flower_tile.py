"""Static flower tile $03 is the resting flower, not the tileset PNG.

home/vcopy.asm UpdateMovingBgTiles .flower overwrites vTileset tile $03
with flower1/2/3. flower1 is the resting phase. The live decoder still
keeps the static PNG until tools/notes/lane-e-flower-tile-03.patch lands.
"""

import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-flower-tile-03.patch"
DECODER = ROOT / "tools/generate_kanto_maps.py"


def flower_substitution(source):
    return "TILEANIM_WATER_FLOWER" in source and "flower/flower1.png" in source and "tiles[0x03]" in source


class LaneEFlowerTileTests(unittest.TestCase):
    def test_patch_applies(self):
        completed = subprocess.run(
            ["git", "apply", "--check", str(PATCH)],
            cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        patch = PATCH.read_text()
        self.assertIn("home/vcopy.asm", patch)
        self.assertIn("flower/flower1.png", patch)
        self.assertNotIn("MallocPoolSize", patch)

    def test_patched_decoder_replaces_tile_03(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            dest = root / "tools"
            dest.mkdir()
            (dest / "generate_kanto_maps.py").write_text(DECODER.read_text())
            completed = subprocess.run(
                ["patch", "-p1", "-d", str(root), "-i", str(PATCH)],
                check=False, capture_output=True, text=True)
            self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
            patched = (dest / "generate_kanto_maps.py").read_text()
        self.assertTrue(flower_substitution(patched))

    @unittest.expectedFailure
    def test_live_decoder_uses_the_resting_flower(self):
        self.assertTrue(flower_substitution(DECODER.read_text()))


if __name__ == "__main__":
    unittest.main()
