#!/usr/bin/env python3
"""A beaten Elite Four room opens its north door without leaving.

applyRoom runs when the map is entered. That pass closes the north
warps while the beat flag is still false. Winning sets the flag and
does not re-enter the map, so the door stays closed and the next room
is unreachable. tools/notes/lane-e-elite-door.patch.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class EliteDoorTests(unittest.TestCase):
    def test_beaten_room_reopens_its_exit(self):
        source = (ROOT / "Source/game/endgameStory.lua").read_text(encoding="utf-8")
        check = source.split("function EndgameStory.check(game)", 1)[1].split(
            "local function trainerRow", 1)[0]
        self.assertIn(
            "elseif room.exit_block and not armed[room.flag] then",
            check,
            "beaten Elite Four room never reopens its north door",
        )
        branch = check.split("elseif room.exit_block and not armed[room.flag] then", 1)[1]
        self.assertIn("EndgameStory.applyRoom(game)", branch.split("end", 1)[0])


if __name__ == "__main__":
    unittest.main()
