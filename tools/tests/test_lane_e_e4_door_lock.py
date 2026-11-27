#!/usr/bin/env python3
"""A beaten Elite Four room still blocks the south door.

pret/pokered af519899 scripts/LoreleisRoom.asm LoreleisRoomDefaultScript
stands on LoreleiEntranceCoords and does not check EVENT_BEAT. A coord
index below 3, and index 3 or 4 once EVENT_AUTOWALKED_INTO_LORELEIS_ROOM
is set, prints Don't run away and forces one step up.
LoreleiShowOrHideExitBlock only replaces the north block at (0, 2).
Bruno and Agatha use the same entrance test. Sequence 259 was already
inside Lorelei's room. The walker stepped south through source (5, 10)
and (5, 11) and the warp to the lobby fired, because the beat flag
skips that script. tools/notes/lane-e-e4-door-lock.patch.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class E4DoorLockTests(unittest.TestCase):
    def test_beaten_room_still_blocks_the_south_door(self):
        source = (ROOT / "Source/game/endgameStory.lua").read_text(encoding="utf-8")
        action = source.split("function EndgameStory.entranceAction", 1)[1].split(
            "function EndgameStory.besideTrainer", 1)[0]
        beaten = action.split("if flags[room.flag] then", 1)[1].split("end", 1)[0]
        self.assertIn('return "dont-run"', beaten)
        loop = source.split("for _, room in ipairs(data.elite_four) do", 1)[1].split(
            "return false", 1)[0]
        self.assertIn("south door stays shut after the win", loop)
        self.assertNotIn("elseif not game.session:questFlag(room.flag) then", loop)


if __name__ == "__main__":
    unittest.main()
