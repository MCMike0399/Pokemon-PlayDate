#!/usr/bin/env python3
"""Re-entering the Indigo lobby clears the Elite Four trainer bits.

A blackout returns to the last Center. The next lobby entry resets
EVENT_BEAT_*_ROOM_TRAINER_0, which is the pokered rematch. The battle
plan keys off trainerFlags, and those stayed true, so Lorelei's after
text played and no fight started. tools/notes/lane-e-indigo-reset.patch.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class IndigoResetTests(unittest.TestCase):
    def test_lobby_reset_clears_trainer_bits(self):
        source = (ROOT / "Source/game/endgameStory.lua").read_text(encoding="utf-8")
        reset = source.split(
            'zone.stableID == "pokered:INDIGO_PLATEAU_LOBBY" and game.session:questFlag(STARTED_ELITE_FOUR)',
            1,
        )[1].split("for _, switch in ipairs", 1)[0]
        self.assertIn(
            "setTrainerDefeated(room.id, false)",
            reset,
            "lobby reset clears the quest flags and leaves the trainer bits set",
        )
        self.assertIn("data.elite_four", reset)


if __name__ == "__main__":
    unittest.main()
