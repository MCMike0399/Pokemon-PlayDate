"""The ▼ continue prompt is pokered tile (18, 16).

home/text.asm:214 PromptText does ldcoord_a 18, 16.
home/joypad2.asm:71 HandleDownArrowBlinkTiming blinks that same tile.

Dialog already draws the arrow at that tile. The battle fight page has to
be a prompt or the tile stays empty. The after frames are the patched
sheet in artifacts/lane-g/e4-after/. The patch is
tools/notes/lane-e-continue-prompt.patch.
"""

import os
import re
import subprocess
import unittest
from pathlib import Path

import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.tests.lane_e_apply import accepts

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-continue-prompt.patch"
AFTER = ROOT / "artifacts/lane-g/e4-after"
COL = 20
ROW = 13
NAMES = ("lorelei", "bruno", "agatha", "lance", "champion")


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, check=False, capture_output=True, text=True)


def cell_ink(path, col, row):
    image = Image.open(path).convert("L")
    self_box = image.crop((col * COL, row * ROW, (col + 1) * COL, (row + 1) * ROW))
    return sum(1 for value in self_box.get_flattened_data() if value < 128)


class ContinuePromptTests(unittest.TestCase):
    def test_patch_applies_and_cites_prompt_text(self):
        text = PATCH.read_text()
        self.assertIn("ldcoord_a 18, 16", text)
        self.assertIn("home/text.asm:214", text)
        self.assertIn("home/joypad2.asm:71", text)
        self.assertNotIn("MallocPoolSize", text)
        reference = os.environ.get("POKERED_REFERENCE_DIR")
        if not reference:
            raise RuntimeError("explicit pinned POKERED_REFERENCE_DIR required; no skipped checks")
        root = Path(reference)
        text_asm = (root / "home/text.asm").read_text().splitlines()
        joypad = (root / "home/joypad2.asm").read_text().splitlines()
        self.assertEqual(text_asm[213], "\tldcoord_a 18, 16")
        self.assertEqual(joypad[70], "\thlcoord 18, 16")
        checked = accepts(PATCH)
        self.assertEqual(checked.returncode, 0, checked.stderr)

    def test_dialog_draws_the_arrow_at_tile_18_16(self):
        dialog = (ROOT / "Source/ui/dialog.lua").read_text()
        found = re.findall(r'GbFont\.drawChar\("▼", (\d+), (\d+)\)', dialog)
        self.assertEqual(found, [("18", "16")])

    def test_prompt_citation_is_in_the_live_dialog(self):
        dialog = (ROOT / "Source/ui/dialog.lua").read_text()
        self.assertIn("ldcoord_a 18, 16", dialog)
        self.assertIn("home/joypad2.asm:71", dialog)

    def test_after_frames_keep_the_arrow_at_tile_18_16(self):
        for name in NAMES:
            for kind in ("intro", "pic"):
                path = AFTER / f"{name}-{kind}.png"
                image = Image.open(path)
                self.assertEqual(image.size, (400, 240), path.name)
                self.assertGreater(cell_ink(path, 18, 16), 20, path.name)
                self.assertEqual(cell_ink(path, 17, 16), 0, path.name)


if __name__ == "__main__":
    unittest.main()
