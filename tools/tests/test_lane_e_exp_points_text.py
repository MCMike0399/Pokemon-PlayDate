#!/usr/bin/env python3
"""The EXP page is still the short sentence, not pokered's two lines.

pret/pokered af519899 data/text/text_2.asm prints _GainedText and then
_ExpPointsText in one box. The first line is "<NAME> gained". The next
line is "<N> EXP. Points!". The amount is the battle's award. This port
uses Gen V yields, so N stays row.xp. Only the words move.

Source/battle/battle.lua says "<NAME> gained N EXP!" on one line.
Source/dev/growthContracts.lua requires "gained 95 EXP!". That lock is
the short sentence, so the patch moves it to "CHARMANDER gained" / "95
EXP. Points!" and keeps the level-6 total of 230. The reward HUD literal
moves with it. This test fails until
tools/notes/lane-e-exp-points-text.patch is applied.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
POKERED = Path("/tmp/pokered/data/text/text_2.asm")
BATTLE = ROOT / "Source/battle/battle.lua"
GROWTH = ROOT / "Source/dev/growthContracts.lua"
HUD = ROOT / "tools/harness/reward_hud.py"
PATCH = ROOT / "tools/notes/lane-e-exp-points-text.patch"

SAY = 'self:say(mon.name .. " gained\\n" .. row.xp .. " EXP. Points!")'
CONTRACT = 'CHARMANDER gained\\n95 EXP. Points!'
HUD_LINE = "CHARMANDER gained\\n68 EXP. Points!"


def script_between(asm, start, stop):
    return asm.split(start, 1)[1].split(stop, 1)[0]


class ExpPointsTextTest(unittest.TestCase):
    def test_pokered_page_is_two_lines_and_the_award_stays(self):
        text = POKERED.read_text(encoding="utf-8")
        gained = script_between(text, "_GainedText::", "_WithExpAllText::")
        points = script_between(text, "_ExpPointsText::", "_GrewLevelText::")
        self.assertIn("text_ram wNameBuffer", gained)
        self.assertIn('text " gained"', gained)
        self.assertIn('line "@"', gained)
        self.assertIn("text_decimal wExpAmountGained, 2, 4", points)
        self.assertIn('text " EXP. Points!"', points)
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn(SAY, patch)
        self.assertIn(CONTRACT, patch)
        self.assertIn(HUD_LINE, patch)
        self.assertIn("equal(p.xp,230)", patch)
        removed = [
            line[1:]
            for line in patch.splitlines()
            if line.startswith("-") and not line.startswith("---")
        ]
        self.assertFalse(any("calcExpGain" in line or "battleAward" in line for line in removed))
        self.assertIn("row.xp", SAY)

    def test_exp_page_matches_gained_text_and_exp_points_text(self):
        battle = BATTLE.read_text(encoding="utf-8")
        growth = GROWTH.read_text(encoding="utf-8")
        hud = HUD.read_text(encoding="utf-8")
        body = battle.split("function Battle:_resolveFaintCheckpoint", 1)[1].split("\nfunction ", 1)[0]
        self.assertIn(
            SAY,
            body,
            "Say the pokered EXP page: the name and gained, then the amount "
            "and EXP. Points! Apply tools/notes/lane-e-exp-points-text.patch",
        )
        self.assertIn(CONTRACT, growth)
        self.assertNotIn("gained 95 EXP!", growth)
        self.assertIn("equal(p.xp,230)", growth)
        self.assertIn(HUD_LINE, hud)


if __name__ == "__main__":
    unittest.main()
