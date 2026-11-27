#!/usr/bin/env python3
"""The bench script-cancelled red is the same gained needle, then Bubble.

pret/pokered af519899 _GainedText breaks after " gained". The contract
searches "SQUIRTLE gained " and advances until BattleScriptPhase returns
script-cancelled. Under that, the hold is real: party order narrates
Squirtle first, and Charmander's vitals stay on the pre-level snapshot
until that row is acknowledged.

Squirtle learns Bubble at level 8 (`db 8, BUBBLE`), not at 7, so the
learning yield the test already requires has to be a level-8 gain.
Charmander stays on the level-7 page with no Ember. experience.asm
calls LearnMoveFromLevelUp only after the stats box, and only a real
move suspends the script before the next party row.
"""

import os
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
POKERED = Path(os.environ["POKERED_REFERENCE_DIR"])
CONTRACT = ROOT / "Source/dev/rewardContracts.lua"


def between(text, start, stop):
    return text.split(start, 1)[1].split(stop, 1)[0]


class RewardBenchHoldTests(unittest.TestCase):
    def test_bench_hold_survives_squirtles_level_eight_bubble(self):
        moves = (POKERED / "data/pokemon/evos_moves.asm").read_text(encoding="utf-8")
        squirtle = between(moves, "SquirtleEvosMoves:", "CharmeleonEvosMoves:")
        charmander = between(moves, "CharmanderEvosMoves:", "SquirtleEvosMoves:")
        self.assertIn("db 8, BUBBLE", squirtle)
        self.assertIn("db 9, EMBER", charmander)
        text = (POKERED / "data/text/text_2.asm").read_text(encoding="utf-8")
        gained = between(text, "_GainedText::", "_WithExpAllText::")
        self.assertIn('text " gained"', gained)
        self.assertIn('line "@"', gained)
        experience = (POKERED / "engine/battle/experience.asm").read_text(encoding="utf-8")
        after_box = between(experience, "callfar PrintStatsBox", ".nextMon")
        self.assertIn("predef LearnMoveFromLevelUp", after_box)
        body = between(
            CONTRACT.read_text(encoding="utf-8"),
            'test("active second member stays held while first bench member narrates and learns"',
            'test("closed or stale presentation receipt',
        )
        self.assertIn('Pokemon("squirtle",7)', body)
        self.assertIn('Pokemon("charmander",6)', body)
        self.assertIn("p.xp=p:xpForLevel(8)-1", body)
        self.assertIn("q.xp=q:xpForLevel(7)-1", body)
        self.assertIn('b.message:find("SQUIRTLE gained\\n",1,true)', body)
        self.assertNotIn('b.message:find("SQUIRTLE gained ",1,true)', body)
        self.assertIn("eq(p.level,8)", body)
        self.assertIn("eq(q.level,7)", body)
        self.assertIn("eq(level,6)", body)
        self.assertIn("eq(hp,20)", body)
        self.assertIn("eq(maximum,20)", body)
        self.assertIn("eq(b.levelStats.speed, p.spe)", body)
        self.assertIn("eq(b:getLearningSnapshot().pending,true)", body)
        self.assertIn("b:takeLearningRequest()", body)
        self.assertIn('b.message:find("CHARMANDER gained\\n",1,true)', body)
        self.assertNotIn('b.message:find("CHARMANDER gained ",1,true)', body)
        self.assertIn("eq(select(1,b:presentationVitals(q)),6)", body)
        self.assertIn("eq(select(1,b:presentationVitals(q)),7)", body)
        self.assertIn("eq(party:active(),q)", body)


if __name__ == "__main__":
    unittest.main()
