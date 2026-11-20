#!/usr/bin/env python3
"""Brine hits, and it doubles at or below half HP.

The move is a normal special attack plus an onBasePower hook. Listing
that hook as a gap made performMove print "But it failed!" and deal no
damage, including Lapras's Brine into Charizard at 26/171.
tools/notes/lane-e-brine.patch.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class BrineTests(unittest.TestCase):
    def test_brine_is_damage_and_doubles_below_half(self):
        support = (ROOT / "Source/battle/moveSupport.lua").read_text(encoding="utf-8")
        effects = (ROOT / "Source/battle/effects.lua").read_text(encoding="utf-8")
        self.assertIn('MoveSupport.handlers.brine = "standard-damage"', support)
        self.assertNotIn("MoveSupport.gaps.brine", support)
        power = effects.split("function BattleEffects:basePower", 1)[1].split("local ratio=4096", 1)[0]
        self.assertIn('move.name=="BRINE"', power)
        self.assertIn("defender.hp*2<=defender.maxHP", power)
        self.assertIn("power=power*2", power)


if __name__ == "__main__":
    unittest.main()
