#!/usr/bin/env python3
"""Hyper Beam still forces a recharge after it KOs.

Gyarados KOed Weepinbell with Hyper Beam. Charizard came in and used
Slash, and Gyarados used Hydro Pump on the next turn. Gen V sets the
recharge receipt whenever the user is still up. The current guard also
requires the defender to be alive, which is the Gen 1 skip. The next
turn is the existing receipt: it says the user must recharge and spends
no PP. tools/notes/lane-e-hyper-beam-recharge.patch.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class HyperBeamRechargeTests(unittest.TestCase):
    def test_hyper_beam_ko_forces_the_next_recharge(self):
        source = (ROOT / "Source/battle/battle.lua").read_text(encoding="utf-8")
        window = source.split("if move.recharge", 1)[1].split("selfDestruct", 1)[0]
        self.assertIn("attacker:isAlive()", window)
        self.assertNotIn("defender:isAlive()", window)
        turn = source.split("if turn.recharge then", 1)[1].split("end", 1)[0]
        self.assertIn("must recharge!", turn)
        self.assertIn("recharge=nil", turn)


if __name__ == "__main__":
    unittest.main()
