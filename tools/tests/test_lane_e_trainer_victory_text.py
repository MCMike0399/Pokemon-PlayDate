#!/usr/bin/env python3
"""A trainer win leaves the battle before the defeat line is read.

pret/pokered af519899 engine/battle/core.asm TrainerBattleVictory prints
TrainerDefeatedText ("<PLAYER> defeated <TRAINER>!") and waits, then
PrintEndBattleText, then MoneyForWinningText, and only then returns to the
map. The Surge log in /tmp/lane-i-charmander-7/leg-26 shows the waited page
"CHARMELEON gained 1205 EXP!" (00582), then "You defeated LT.SURGE!" as
battle.message for two snapshots (00588, 00589), then the overworld script
_VermilionGymLTSurgeReceivedThunderBadgeText (00590) and, after that,
_MoneyForWinningText (00597). The badge-info and TM pages stay on the map,
which matches VermilionGymLTSurgeReceiveTM24Script.

Battle:_resolveFaintCheckpoint assigns that defeat sentence and returns
"victory". BattleEndedPhase then calls emitEnd once A has been held for 12
frames, so the battle root drops on the EXP page. The end text and the
prize are SourceEvents.trainer dialogs after that receipt. Lane B's
f0dd27db keeps the prize text as UTF-8 for the Playdate JSON decoder. It
does not change this order. This test fails until
tools/notes/lane-e-trainer-victory-text.patch is in the shared file.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BATTLE = ROOT / "Source/battle/battle.lua"
PATCH = ROOT / "tools/notes/lane-e-trainer-victory-text.patch"


class TrainerVictoryTextTest(unittest.TestCase):
    def test_trainer_win_says_the_defeat_line_before_returning(self):
        source = BATTLE.read_text(encoding="utf-8")
        patch = PATCH.read_text(encoding="utf-8")
        body = source.split("function Battle:_resolveFaintCheckpoint", 1)[1].split("\nfunction ", 1)[0]
        self.assertIn('self:say(playerName .. " defeated " .. self.trainerName .. "!")', patch)
        self.assertIn(
            'self:say(playerName .. " defeated " .. self.trainerName .. "!")',
            body,
            "Say the pokered defeat line and wait before returning victory. "
            "Apply tools/notes/lane-e-trainer-victory-text.patch",
        )
        self.assertLess(
            body.index('self:say(playerName .. " defeated "'),
            body.index('return "victory"'),
        )


if __name__ == "__main__":
    unittest.main()
