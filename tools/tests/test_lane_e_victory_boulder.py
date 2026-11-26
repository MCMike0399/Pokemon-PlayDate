#!/usr/bin/env python3
"""The Victory Road 2F puzzle boulder stays visible.

Pokered always places boulder 3 at (23, 16). That is the boulder pushed
west onto the switch at (9, 16). The 3F hole lands on 2F at (22, 16).

Route 23 still sets TOGGLE_VICTORY_ROAD_2F_BOULDER, and that flag no
longer hides objects:13. The 3F hole boulder, objects:10, stays tied to
its own toggle.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STORY = ROOT / "Source/game/endgameStory.lua"
HIDE = '["pokered:VICTORY_ROAD_2F:objects:13"]'
HOLE = '["pokered:VICTORY_ROAD_3F:objects:10"]'


def visibility(text):
    start = text.index("local VISIBILITY <const> = {")
    end = text.index("\n}", start)
    return text[start:end]


class VictoryBoulderTests(unittest.TestCase):
    def test_puzzle_boulder_is_not_hidden_by_the_route_23_toggle(self):
        text = STORY.read_text()
        self.assertNotIn(HIDE, visibility(text))
        self.assertIn("TOGGLE_VICTORY_ROAD_2F_BOULDER", text)
        self.assertIn("setQuestFlag(data.route23.hide_toggle, true)", text)
        self.assertIn('"pokered:VICTORY_ROAD_2F:objects:13"', text)

    def test_hole_boulder_stays_on_its_own_toggle(self):
        body = visibility(STORY.read_text())
        self.assertIn(HOLE, body)
        self.assertIn("TOGGLE_VICTORY_ROAD_3F_BOULDER", body)


if __name__ == "__main__":
    unittest.main()
