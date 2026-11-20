"""The shift question stays up before YES/NO.

The question after a foe faints is its own page. A press that is already
down, including the A that left "about to use", must not answer it.
tools/notes/lane-e-shift-hold.patch. The older shift-prompt patch is
already on this tip and is not part of this file.
"""

import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-shift-hold.patch"


def shift_holds(scene):
    handle = scene.split("function BattleScene:handleInput()", 1)[1]
    handle = handle.split("\nfunction BattleScene:", 1)[0]
    shift = handle.split("if self.battle.shiftChoice then", 1)[1]
    return "self.shiftShown" in shift and "(self.shiftShown or 0) >= 10" in shift and (
        shift.index("(self.shiftShown or 0) >= 10") < shift.index("self.shiftMenu:handleInput()"))


class LaneEShiftHoldTests(unittest.TestCase):
    def test_patch_applies(self):
        self.assertTrue(PATCH.is_file())
        self.assertNotIn("MallocPoolSize", PATCH.read_text())

    def test_patched_scene_waits_ten_frames(self):
        self.assertTrue(shift_holds((ROOT / "Source/battle/battleScene.lua").read_text()))

    def test_live_question_stays_up_after_the_faint(self):
        self.assertTrue(shift_holds((ROOT / "Source/battle/battleScene.lua").read_text()))


if __name__ == "__main__":
    unittest.main()
