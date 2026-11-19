#!/usr/bin/env python3
"""The command list waits until the HP bar finishes.

pret/pokered af519899 animates the HP bar inside the move and only then
returns to the battle menu. updateVitals steps maxHP/30 per frame, and
that step runs before the presentation resume that applies the damage.
A neutral hit can return command in that same resume. drawBattleField
then paints FIGHT on the pre-damage number.

On 20261119T212421Z-elite-lorelei.mp4 the Aurora Beam bar reads 153/191
on the sixth drain frame and 119/191 while "It's super effective!" is
still up. FIGHT is drawn after that, because the extra line keeps the
script parked and handleInput already refuses A while the bar is short.
The list itself is not behind that wait.
"""

import math
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCENE = ROOT / "Source/battle/battleScene.lua"
PATCH = ROOT / "tools/notes/lane-e-hp-drain-menu.patch"
START_HP = 191
FINAL_HP = 119
MAX_HP = 191


def field(text):
    start = text.index("function BattleScene:drawBattleField()")
    end = text.index("\nfunction BattleScene:drawMoveSelect()", start)
    return text[start:end]


def command_line(text):
    lines = [line for line in field(text).splitlines() if line.strip().startswith("elseif self.battle:isAwaitingCommand()")]
    if len(lines) != 1:
        raise AssertionError(lines)
    return lines[0]


def shown_after(frames):
    """Same step as BattleScene:updateVitals, then ceil like shownVitals."""
    shown = float(START_HP)
    step = max(1.0, MAX_HP / 30.0)
    for _ in range(frames):
        delta = FINAL_HP - shown
        shown += max(-step, min(step, delta))
    return math.ceil(shown - 1e-9)


class HpDrainMenuTests(unittest.TestCase):
    def test_six_frames_of_this_aurora_beam_still_read_153(self):
        self.assertEqual(shown_after(6), 153)
        self.assertGreater(shown_after(6), FINAL_HP)
        self.assertEqual(shown_after(0), START_HP)
        self.assertEqual(shown_after(30), FINAL_HP)

    def test_the_command_list_is_drawn_without_the_bar_wait(self):
        line = command_line(SCENE.read_text())
        self.assertIn("elseif self.battle:isAwaitingCommand() then", line)
        self.assertNotIn("isVitalsBlocking()", line)
        handle = SCENE.read_text().split("function BattleScene:handleInput()", 1)[1]
        handle = handle.split("function BattleScene:drawBackgroundBase()", 1)[0]
        self.assertLess(handle.index("self:isVitalsBlocking()"), handle.index("self:enter()"))

    @unittest.expectedFailure
    def test_the_command_list_waits_until_the_bar_matches(self):
        line = command_line(SCENE.read_text())
        self.assertIn(
            "elseif self.battle:isAwaitingCommand() and not self:isVitalsBlocking() then",
            line,
        )

    def test_patch_holds_the_list_until_the_bar_matches(self):
        check = subprocess.run(
            ["git", "apply", "--check", str(PATCH)], cwd=ROOT,
            capture_output=True, text=True)
        self.assertEqual(check.returncode, 0, check.stderr)
        output = Path("/tmp/lane-e-hp-drain-menu.lua")
        applied = subprocess.run(
            ["patch", "-o", str(output), str(SCENE), str(PATCH)],
            capture_output=True, text=True)
        self.assertEqual(applied.returncode, 0, applied.stdout + applied.stderr)
        line = command_line(output.read_text())
        self.assertIn(
            "elseif self.battle:isAwaitingCommand() and not self:isVitalsBlocking() then",
            line,
        )
        self.assertNotIn("elseif self.battle:isAwaitingCommand() then", line)


if __name__ == "__main__":
    unittest.main()
