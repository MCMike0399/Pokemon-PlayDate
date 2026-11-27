#!/usr/bin/env python3
"""The stats-box `expected true, got false` is Ember's level.

pret/pokered af519899 experience.asm prints GrewLevelText, then
PrintStatsBox, then WaitForTextScrollButtonPress, then
LearnMoveFromLevelUp. Charmander's evos_moves entry is `db 9, EMBER`.
A level-7 gain draws the box and leaves no pending move, so the last
`pending == true` fails. The box itself is already the Gen V split
(SP. ATK and SP. DEF, no SPECIAL). The fixture moves to level 9, which
is the first level that yields Ember, and the wait-before-learning
assertions stay.
"""

import os
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
POKERED = Path(os.environ["POKERED_REFERENCE_DIR"])
CONTRACT = ROOT / "Source/dev/rewardContracts.lua"


def between(text, start, stop):
    return text.split(start, 1)[1].split(stop, 1)[0]


class RewardStatsBoxTests(unittest.TestCase):
    def test_stats_box_waits_and_then_offers_ember_at_level_nine(self):
        moves = (POKERED / "data/pokemon/evos_moves.asm").read_text(encoding="utf-8")
        charmander = between(moves, "CharmanderEvosMoves:", "SquirtleEvosMoves:")
        self.assertIn("db 9, EMBER", charmander)
        self.assertNotIn("db 7, EMBER", charmander)
        experience = (POKERED / "engine/battle/experience.asm").read_text(encoding="utf-8")
        order = between(experience, ".printGrewLevelText", ".nextMon")
        grew = order.index("ld hl, GrewLevelText")
        box = order.index("callfar PrintStatsBox")
        wait = order.index("call WaitForTextScrollButtonPress")
        learn = order.index("predef LearnMoveFromLevelUp")
        self.assertLess(grew, box)
        self.assertLess(box, wait)
        self.assertLess(wait, learn)
        body = between(
            CONTRACT.read_text(encoding="utf-8"),
            'test("level-up stats box follows the grew line and waits before learning"',
            'test("closed or aborted reward owner',
        )
        self.assertIn('Pokemon("charmander",8)', body)
        self.assertIn("p.xp=p:xpForLevel(9)-1", body)
        self.assertIn('settle(b, scene, " grew to Lv9!")', body)
        self.assertIn('b.message:find(" grew to Lv9!", 1, true)', body)
        self.assertIn("eq(b.levelStats, nil)", body)
        self.assertIn("eq(b:getLearningSnapshot().pending, false)", body)
        self.assertIn("eq(b.levelStats.attack, p.atk)", body)
        self.assertIn("eq(b.levelStats.defense, p.def)", body)
        self.assertIn("eq(b.levelStats.speed, p.spe)", body)
        self.assertIn("eq(b.levelStats.spAttack, p.spa)", body)
        self.assertIn("eq(b.levelStats.spDefense, p.spd)", body)
        self.assertIn("eq(b.levelStats.special, nil)", body)
        self.assertIn('eq(lines[3].label, "SP. ATK")', body)
        self.assertIn('eq(lines[4].label, "SP. DEF")', body)
        self.assertIn('eq(lines[5].label, "SPEED")', body)
        self.assertIn("eq(b:getLearningSnapshot().pending, true)", body)
        self.assertNotIn("grew to Lv7!", body)


if __name__ == "__main__":
    unittest.main()
