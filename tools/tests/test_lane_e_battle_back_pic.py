"""The player back pic is gfx/player/redb.png, thresholded like mon backs.

tools/generate_battle_art.py:113 maps value >= 128 to white and does not
dither. The Old Man back pic (gfx/battle/oldmanb.png) uses that same rule
in the Viridian catch tutorial. The live draw still describes redb as an
overworld frame and keeps a second scaled bitmap. The patch is
tools/notes/lane-e-battle-back-pic.patch.
"""

import os
import subprocess
import unittest
from pathlib import Path

import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.tests.lane_e_apply import accepts

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-battle-back-pic.patch"


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, check=False, capture_output=True, text=True)


def threshold(image):
    return image.point(lambda value: 255 if value >= 128 else 0, "1")


class BattleBackPicTests(unittest.TestCase):
    def test_patch_applies(self):
        text = PATCH.read_text()
        self.assertIn("gfx/player/redb.png", text)
        self.assertIn("gfx/battle/oldmanb.png", text)
        self.assertIn("value >= 128", text)
        self.assertNotIn("MallocPoolSize", text)
        checked = accepts(PATCH)
        self.assertEqual(checked.returncode, 0, checked.stderr)

    def test_red_back_file_is_the_redb_threshold(self):
        reference = os.environ.get("POKERED_REFERENCE_DIR")
        if not reference:
            raise RuntimeError("explicit pinned POKERED_REFERENCE_DIR required; no skipped checks")
        original = Image.open(Path(reference) / "gfx/player/redb.png")
        self.assertEqual(original.mode, "L")
        self.assertEqual(original.size, (32, 32))
        actual = Image.open(ROOT / "Source/images/player/red-pic-back.png")
        self.assertEqual(actual.mode, "1")
        self.assertEqual(actual.size, (32, 32))
        self.assertEqual(list(threshold(original).get_flattened_data()), list(actual.get_flattened_data()))
        manifest = (ROOT / "tools/references/battle-art.json").read_text()
        self.assertNotIn("red-pic-back", manifest)

    def test_draw_uses_the_redb_pic_without_a_second_bitmap(self):
        scene = (ROOT / "Source/battle/battleScene.lua").read_text()
        back = scene.split("function BattleScene:drawPlayerBack()", 1)[1].split("function BattleScene:", 1)[0]
        self.assertIn("gfx/player/redb.png", back)
        self.assertIn("value >= 128", back)
        self.assertNotIn("overworld frame", back)
        self.assertNotIn("gfx.image.new(sw, sh)", back)
        self.assertIn("self.playerBackImage:drawScaled(x, y, scale)", back)

    def test_oldman_back_uses_the_mon_back_threshold(self):
        source = (ROOT / "Source/game/tutorialDemo.lua").read_text()
        self.assertIn("function TutorialDemoArt.flatBack", source)
        image = source.split("function TutorialDemoArt.image", 1)[1].split("\nfunction ", 1)[0]
        self.assertIn('name == "oldmanBack"', image)
        self.assertLess(image.index("oldmanBack"), image.index("TileFactory.renderGrid"))
        flat = source.split("function TutorialDemoArt.flatBack", 1)[1].split("\nfunction ", 1)[0]
        self.assertIn("gfx/battle/oldmanb.png", flat)
        self.assertIn('ch == "2" or ch == "#"', flat)
        scenes = (ROOT / "Source/data/tutorialEscort/scenes.json").read_text()
        self.assertIn("gfx/battle/oldmanb.png", scenes)


if __name__ == "__main__":
    unittest.main()
