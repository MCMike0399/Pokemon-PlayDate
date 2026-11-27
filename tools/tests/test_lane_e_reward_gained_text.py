#!/usr/bin/env python3
"""The HUD script-cancelled red is the gained-line needle.

pret/pokered af519899 data/text/text_2.asm _GainedText is
`text " gained"` and then `line "@"`. The battle already says that
break (`gained\\n`). The contract searches `" gained "` with a trailing
space, walks off the end of the script, and the next advance is
`script-cancelled` because BattleScriptPhase:exit marks the coroutine
cancelled. The vitals hold underneath that search is the one the test
already states.
"""

import os
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
POKERED = Path(os.environ["POKERED_REFERENCE_DIR"])
CONTRACT = ROOT / "Source/dev/rewardContracts.lua"
BATTLE = ROOT / "Source/battle/battle.lua"


def between(text, start, stop):
    return text.split(start, 1)[1].split(stop, 1)[0]


class RewardGainedTextTests(unittest.TestCase):
    def test_hud_stops_on_the_pokered_line_break(self):
        text = (POKERED / "data/text/text_2.asm").read_text(encoding="utf-8")
        gained = between(text, "_GainedText::", "_WithExpAllText::")
        points = between(text, "_ExpPointsText::", "_GrewLevelText::")
        self.assertIn('text " gained"', gained)
        self.assertIn('line "@"', gained)
        self.assertNotIn('text " gained "', gained)
        self.assertIn('text " EXP. Points!"', points)
        battle = between(
            BATTLE.read_text(encoding="utf-8"),
            "function Battle:_resolveFaintCheckpoint",
            "\nfunction ",
        )
        self.assertIn('self:say(mon.name .. " gained\\n" .. row.xp .. " EXP. Points!")', battle)
        body = between(
            CONTRACT.read_text(encoding="utf-8"),
            'test("HUD holds before vitals through gained message then releases before grew message"',
            'test("active second member',
        )
        self.assertIn('b.message:find(" gained\\n",1,true)', body)
        self.assertNotIn('b.message:find(" gained ",1,true)', body)
        self.assertIn("eq(level,6)", body)
        self.assertIn("eq(hp,18)", body)
        self.assertIn("eq(maximum,20)", body)
        self.assertIn('eq(b.presentationRequest.kind, "experience")', body)
        self.assertIn('settle(b, scene, " grew to Lv7!")', body)
        self.assertIn("eq(level, 7)", body)
        self.assertIn("eq(hp, 20)", body)
        self.assertIn("eq(maximum, 22)", body)


if __name__ == "__main__":
    unittest.main()
