"""Trainer portraits stay flat 1-bit.

Mon front sprites match tools/generate_battle_art.py's threshold
(value >= 128 is white, no dither). They are not the Bayer 31.25%/68.75%
overworld shading. The five Elite Four and Champion portraits are the
same threshold, nearest-neighbor doubled. Leave them flat. The patch is
tools/notes/lane-e-trainer-portrait-flat.patch.
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
PATCH = ROOT / "tools/notes/lane-e-trainer-portrait-flat.patch"
FRONTS = {
    "mr-mime": "mr.mime",
    "nidoran-f": "nidoranf",
    "nidoran-m": "nidoranm",
}
PORTRAITS = {
    "LORELEI": "lorelei",
    "BRUNO": "bruno",
    "AGATHA": "agatha",
    "LANCE": "lance",
    "RIVAL3": "rival3",
}


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, check=False, capture_output=True, text=True)


def threshold(image):
    return image.point(lambda value: 255 if value >= 128 else 0, "1")


def pixels(image):
    return list(image.convert("1").get_flattened_data())


class TrainerPortraitFlatTests(unittest.TestCase):
    def test_patch_applies_without_rewriting_pngs(self):
        text = PATCH.read_text()
        self.assertIn("flat 1-bit", text)
        self.assertNotIn("diff --git a/Source/images/", text)
        self.assertNotIn("MallocPoolSize", text)
        checked = accepts(PATCH)
        self.assertEqual(checked.returncode, 0, checked.stderr)

    def test_mon_fronts_and_portraits_match_the_flat_threshold(self):
        reference = os.environ.get("POKERED_REFERENCE_DIR")
        if not reference:
            raise RuntimeError("explicit pinned POKERED_REFERENCE_DIR required; no skipped checks")
        root = Path(reference)
        fronts = sorted((ROOT / "Source/images/pokemon").glob("*-front.png"))
        self.assertEqual(len(fronts), 151)
        for path in fronts:
            species = path.name[: -len("-front.png")]
            source_name = FRONTS.get(species, species)
            original = Image.open(root / "gfx/pokemon/front" / (source_name + ".png"))
            actual = Image.open(path)
            self.assertEqual(actual.mode, "1", path.name)
            self.assertEqual(pixels(threshold(original)), pixels(actual), path.name)
        for label, source_name in PORTRAITS.items():
            original = Image.open(root / "gfx/trainers" / (source_name + ".png"))
            doubled = threshold(original).resize((original.width * 2, original.height * 2), Image.Resampling.NEAREST)
            actual = Image.open(ROOT / "Source/images/title/trainers" / (label + ".png"))
            self.assertEqual(actual.mode, "1", label)
            self.assertEqual(actual.size, (112, 112), label)
            self.assertEqual(pixels(doubled), pixels(actual), label)

    def test_draw_says_portraits_stay_flat(self):
        scene = (ROOT / "Source/battle/battleScene.lua").read_text()
        draw = scene.split("function BattleScene:drawTrainer()", 1)[1].split("local sourceClass", 1)[0]
        self.assertIn("Mon front sprites are flat 1-bit", draw)
        self.assertIn("31.25%/68.75%", draw)


if __name__ == "__main__":
    unittest.main()
