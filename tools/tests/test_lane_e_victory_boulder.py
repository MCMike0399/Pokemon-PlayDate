#!/usr/bin/env python3
"""The Victory Road 2F puzzle boulder must stay visible.

Pokered's VictoryRoad2F object table always places boulder 3 at
(23, 16). That is the boulder pushed west onto the switch at (9, 16).
The 3F hole lands on 2F at (22, 16), a different cell.

EndgameStory hides objects:13 while TOGGLE_VICTORY_ROAD_2F_BOULDER is
true. Entering Route 23, which is the only road into the cave, sets
that toggle. The puzzle boulder never spawns, so the east gate cannot
be opened and the lobby path through the closed 3F boulders is blocked.

The patch removes that visibility rule. It is not applied. The 3F hole
boulder, objects:10, stays tied to its own toggle.
"""

import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STORY = ROOT / 'Source/game/endgameStory.lua'
PATCH = ROOT / 'tools/notes/lane-e-victory-boulder.patch'
HIDE = '["pokered:VICTORY_ROAD_2F:objects:13"]'


class VictoryBoulderTests(unittest.TestCase):
    def test_live_source_hides_the_puzzle_boulder(self):
        text = STORY.read_text()
        self.assertIn(HIDE, text)
        self.assertIn('TOGGLE_VICTORY_ROAD_2F_BOULDER', text)
        self.assertIn('setQuestFlag(data.route23.hide_toggle, true)', text)

    @unittest.expectedFailure
    def test_puzzle_boulder_is_not_hidden_by_the_route_23_toggle(self):
        text = STORY.read_text()
        self.assertNotIn(HIDE, text)

    def test_patch_shows_the_puzzle_boulder_and_leaves_source(self):
        original = STORY.read_text()
        subprocess.run(
            ['git', 'apply', '--check', str(PATCH)],
            cwd=ROOT, check=True,
        )
        patched = Path('/tmp/lane-e-victory-boulder.lua')
        subprocess.run(
            ['patch', '-o', str(patched), str(STORY), str(PATCH)],
            check=True, capture_output=True, text=True,
        )
        body = patched.read_text()
        self.assertNotIn(HIDE, body)
        self.assertIn('["pokered:VICTORY_ROAD_3F:objects:10"]', body)
        self.assertEqual(STORY.read_text(), original)
        self.assertIn(HIDE, original)


if __name__ == '__main__':
    unittest.main()
