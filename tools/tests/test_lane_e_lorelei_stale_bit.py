#!/usr/bin/env python3
"""Lorelei's room has to clear a stale trainer bit before the door locks.

Seq 305 has EVENT_BEAT_LORELEIS_ROOM_TRAINER_0 false and the trainer bit
true. Entry locks the south door, her after-text plays, and the lobby
reset never runs. tools/notes/lane-e-lorelei-stale-bit.patch.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class LoreleiStaleBitTests(unittest.TestCase):
    def test_room_entry_clears_unbeaten_trainer_bit(self):
        source = (ROOT / "Source/game/endgameStory.lua").read_text(encoding="utf-8")
        room = source.split('zone.stableID == "pokered:LORELEIS_ROOM"', 1)[1].split("elseif", 1)[0]
        self.assertIn("EVENT_BEAT_LORELEIS_ROOM_TRAINER_0", room)
        self.assertIn(
            'setTrainerDefeated("pokered:LORELEIS_ROOM:objects:1", false)',
            room,
        )


if __name__ == "__main__":
    unittest.main()
