#!/usr/bin/env python3
"""Lance's hallway walk is simulated joypad.

WalkToLance_RLEList steps from the warp at (24, 16): 12 up, 12 left,
7 down, 6 left. The second step, (24, 14), is solid in LancesRoom, and
so is most of the rest of that list. pokered plays the list as simulated
joypad, and CollisionCheckOnLand skips those cells. The entrance plan
sets plan.simulated for a room that has that walk list. Lorelei, Bruno
and Agatha keep walk_in and an ordinary move plan.
"""

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STORY = ROOT / "Source/game/endgameStory.lua"
EVENTS = ROOT / "Source/game/eventState.lua"
ROOM = ROOT / "Source/data/zEndgame/LancesRoom.json"


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

    def test_lance_walk_is_simulated_and_the_other_rooms_stay_ordinary(self):
        text = STORY.read_text()
        self.assertIn("if room.walk then", text)
        self.assertIn("simulated = true, steps = steps", text)
        self.assertIn('return {status = "ready", steps = steps}', text)
        self.assertNotIn(
            'return {status = "ready", steps = approachWalk(room, pending.x)}', text)

    def test_simulated_joypad_skips_solid_cells_and_still_rejects_off_map(self):
        text = EVENTS.read_text()
        self.assertIn("local simulated = self.plan and self.plan.simulated", text)
        self.assertIn("if simulated and offMap then", text)
        self.assertIn("DEBUG_FLAGS.noclip = true", text)


if __name__ == "__main__":
    unittest.main()
