#!/usr/bin/env python3
"""Lance's hallway walk is simulated joypad.

WalkToLance_RLEList steps from the warp at (24, 16): 12 up, 12 left,
7 down, 6 left. The second step, (24, 14), is solid in LancesRoom, and
so is most of the rest of that list. pokered plays the list as simulated
joypad, and CollisionCheckOnLand skips those cells. EventState:startMove
only skips them when plan.simulated is set. The entrance plan currently
returns ordinary move steps, so the walk fails with blocked-scripted-move
and the event stays failed. The patch is not applied on this branch.
"""

import json
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-lance-walk.patch"
STORY = ROOT / "Source/game/endgameStory.lua"
ROOM = ROOT / "Source/data/zEndgame/LancesRoom.json"
PLAN = 'return {status = "ready", steps = approachWalk(room, pending.x)}'


def walk_cells():
    room = json.loads(ROOM.read_text())
    collision = room["collision"]
    x, y = 24, 16
    cells = []
    for direction, count in (("up", 12), ("left", 12), ("down", 7), ("left", 6)):
        dx, dy = {"up": (0, -1), "down": (0, 1), "left": (-1, 0), "right": (1, 0)}[direction]
        for _ in range(count):
            x += dx
            y += dy
            cells.append((x, y, collision[y][x]))
    return cells


class LanceWalkTests(unittest.TestCase):
    def test_the_scripted_corridor_is_solid(self):
        cells = walk_cells()
        self.assertEqual(cells[1][:2], (24, 14))
        self.assertEqual(cells[1][2], 1)
        self.assertGreater(sum(1 for _x, _y, solid in cells if solid), 20)
        self.assertEqual(cells[-1][:2], (6, 11))

    def test_live_plan_does_not_simulate_the_walk(self):
        text = STORY.read_text()
        self.assertIn(PLAN, text)
        self.assertNotIn("room.walk then", text)
        self.assertNotIn('if room.walk then', text)

    @unittest.expectedFailure
    def test_unpatched_entrance_marks_the_lance_walk_simulated(self):
        text = STORY.read_text()
        self.assertIn("if room.walk then", text)
        self.assertIn("simulated = true, steps = steps", text)

    def test_patch_simulates_only_the_lance_list(self):
        check = subprocess.run(
            ["git", "apply", "--check", str(PATCH)], cwd=ROOT,
            capture_output=True, text=True)
        self.assertEqual(check.returncode, 0, check.stderr)
        output = Path("/tmp/lane-e-lance-walk.lua")
        applied = subprocess.run(
            ["patch", "-o", str(output), str(STORY), str(PATCH)],
            capture_output=True, text=True)
        self.assertEqual(applied.returncode, 0, applied.stdout + applied.stderr)
        text = output.read_text()
        self.assertIn("if room.walk then", text)
        self.assertIn("simulated = true, steps = steps", text)
        self.assertIn('return {status = "ready", steps = steps}', text)
        self.assertNotIn(PLAN, text)


if __name__ == "__main__":
    unittest.main()
