#!/usr/bin/env python3
"""A trainer wipe prints the pokered blackout page and leaves the map script.

pret/pokered af519899 text/text_2.asm _PlayerBlackedOutText2 is the loss
page for every fight except the lab rival. Route22Rival2AfterBattleScript
returns to the default script on LOST_BATTLE, so Blue's "Hahaha!" line must
not resume after the checkpoint warp.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class BlackoutTests(unittest.TestCase):
    def test_defeat_page_is_the_pokered_blackout_text(self):
        battle = (ROOT / "Source/battle/battle.lua").read_text()
        branch = battle.split("if not playerTeamAlive then", 1)[1].split(
            'return "defeat"', 1)[0]
        self.assertIn('playerName .. " is out of\\nuseable POKéMON!\\n\\n"', branch)
        self.assertIn('playerName .. " blacked\\nout!"', branch)
        self.assertIn('intro.stage == "rival_fight"', branch)

    def test_blackout_does_not_resume_the_rival_script(self):
        state = (ROOT / "Source/game/battleState.lua").read_text()
        lost = state.split("if not receipt.won then", 1)[1].split(
            "if receipt.initial_lab", 1)[0]
        self.assertLess(lost.index("if blackout then return end"), lost.index("descriptor.lost"))


if __name__ == "__main__":
    unittest.main()
