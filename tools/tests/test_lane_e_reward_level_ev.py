#!/usr/bin/env python3
"""Level-up EV identity is a stale fixture, not a stat bug.

pret/pokered af519899 engine/battle/core.asm FaintEnemyPokemon calls
GainExperience before HandleEnemyMonFainted reaches ReplaceFaintedEnemyMon.
experience.asm CalcStats (b = 1, stat exp included) runs before
LearnMoveFromLevelUp, and LearnMoveFromLevelUp yields only when evos_moves
has a move at the new level. Squirtle's list is `db 8, BUBBLE`, so a
level-7 gain has no prompt and the next foe is sent. The contract asked
for that prompt, and for speed 12, at level 7.

The port keeps Gen V EVs and the Gen V stat formula. Pidgey still yields
1 Speed. IV 13 and 4 Speed EVs at level 8 are speed 13. The learning
pause, the enemy identity, and Bubble stay; the fixture moves to level 8.
"""

import os
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
POKERED = Path(os.environ["POKERED_REFERENCE_DIR"])
CONTRACT = ROOT / "Source/dev/rewardContracts.lua"


def between(text, start, stop):
    return text.split(start, 1)[1].split(stop, 1)[0]


class RewardLevelEvTests(unittest.TestCase):
    def test_level_up_learns_bubble_at_eight_and_keeps_the_gen_v_speed(self):
        moves = (POKERED / "data/pokemon/evos_moves.asm").read_text(encoding="utf-8")
        squirtle = between(moves, "SquirtleEvosMoves:", "CharmeleonEvosMoves:")
        self.assertIn("db 8, BUBBLE", squirtle)
        self.assertNotIn("db 7, BUBBLE", squirtle)
        core = (POKERED / "engine/battle/core.asm").read_text(encoding="utf-8")
        faint = between(core, "FaintEnemyPokemon:", "EnemyMonFaintedText:")
        gained = faint.index("callfar GainExperience")
        self.assertLess(gained, faint.index("ret z ; return if no exp all"))
        handle = between(core, "HandleEnemyMonFainted:", "FaintEnemyPokemon:")
        self.assertLess(handle.index("call FaintEnemyPokemon"), handle.index("call ReplaceFaintedEnemyMon"))
        experience = (POKERED / "engine/battle/experience.asm").read_text(encoding="utf-8")
        growth = between(experience, "call CalcStats", "predef LearnMoveFromLevelUp")
        self.assertIn("callfar PrintStatsBox", growth)
        # Gen V: floor((2*43 + 13 + floor(4/4)) * 8 / 100) + 5, nature neutral.
        self.assertEqual(((2 * 43 + 13 + 4 // 4) * 8) // 100 + 5, 13)
        body = between(
            CONTRACT.read_text(encoding="utf-8"),
            'test("level-up recomputes from EV already allocated before next foe and typed learning"',
            'test("emitEnd flushes',
        )
        self.assertIn('Pokemon("squirtle",7,', body)
        self.assertIn("p.xp=p:xpForLevel(8)-1", body)
        self.assertIn("eq(p.level,8)", body)
        self.assertIn("eq(p.evs.spe,4)", body)
        self.assertIn("eq(p.spe,13)", body)
        self.assertIn("eq(p.spe,p:calculatedStats().spe)", body)
        self.assertIn("eq(p.maxHP-p.hp,beforeHP)", body)
        self.assertIn("eq(b.enemy,e1)", body)
        self.assertIn("eq(b:getLearningSnapshot().pending,true)", body)
        self.assertIn('eq(p:hasMove("bubble"),true)', body)
        self.assertIn("eq(b.enemy,e2)", body)
        self.assertNotIn("eq(p.level,7)", body)
        self.assertNotIn("eq(p.spe,12)", body)
        self.assertNotIn("xpForLevel(7)-1", body)


if __name__ == "__main__":
    unittest.main()
