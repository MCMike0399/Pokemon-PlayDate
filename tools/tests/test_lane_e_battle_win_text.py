#!/usr/bin/env python3
"""A KO still prints the short faint line, and a wild win invents a page.

pret/pokered af519899 data/text/text_2.asm _EnemyMonFaintedText is
text "Enemy @" / text_ram wEnemyMonNick / line "fainted!". The box is
"Enemy <NICK>" and then "fainted!". Wild and trainer foes share that
page. _PlayerMonFaintedText is only the player's nick, then "fainted!".

A wild win returns to the map after the EXP and level-up text. pokered
has no "You won the battle!" string. A trainer win is TrainerDefeatedText,
the end-battle pages, and _MoneyForWinningText.

Source/battle/battle.lua says "<NAME> fainted!" for both sides and, when
the foe is wild, sets "You won the battle!" after the EXP text. This
test fails until tools/notes/lane-e-battle-win-text.patch is applied.
"""

import os
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
POKERED = Path(os.environ["POKERED_REFERENCE_DIR"]) / "data/text/text_2.asm"
BATTLE = ROOT / "Source/battle/battle.lua"
STATE = ROOT / "Source/game/battleState.lua"
PATCH = ROOT / "tools/notes/lane-e-battle-win-text.patch"

ENEMY_SAY = 'self:say("Enemy " .. pokemon.name .. "\\nfainted!")'
PLAYER_SAY = 'self:say(pokemon.name .. " fainted!")'
DEFEAT = 'self:say(playerName .. " defeated " .. self.trainerName .. "!")'
PRIZE = "self:say(self.prizeLine)"


def script_between(asm, start, stop):
    return asm.split(start, 1)[1].split(stop, 1)[0]


def faint_body(battle):
    return battle.split("function Battle:_registerFaints", 1)[1].split(
        "function Battle:_resolveFaintCheckpoint", 1)[0]


def victory_body(battle):
    return battle.split("function Battle:_resolveFaintCheckpoint", 1)[1].split(
        "\nfunction ", 1)[0]


class BattleWinTextTest(unittest.TestCase):
    def test_pokered_pages_and_the_patch_keep_the_line_break(self):
        text = POKERED.read_text(encoding="utf-8")
        enemy = script_between(text, "_EnemyMonFaintedText::", "_MoneyForWinningText::")
        player = script_between(text, "_PlayerMonFaintedText::", "_UseNextMonText::")
        defeated = script_between(text, "_TrainerDefeatedText::", "_PlayerMonFaintedText::")
        prize = script_between(text, "_MoneyForWinningText::", "_TrainerDefeatedText::")
        self.assertIn('text "Enemy @"', enemy)
        self.assertIn("text_ram wEnemyMonNick", enemy)
        self.assertIn('line "fainted!"', enemy)
        self.assertLess(enemy.index('text "Enemy @"'), enemy.index("text_ram wEnemyMonNick"))
        self.assertLess(enemy.index("text_ram wEnemyMonNick"), enemy.index('line "fainted!"'))
        self.assertNotIn("Enemy", player)
        self.assertIn("text_ram wBattleMonNick", player)
        self.assertIn('line "fainted!"', player)
        self.assertNotIn("You won the battle!", text)
        self.assertIn('text "<PLAYER> defeated"', defeated)
        self.assertIn('line "for winning!"', prize)
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn(ENEMY_SAY, patch)
        self.assertIn(PLAYER_SAY, patch)
        self.assertIn('-            self.message = "You won the battle!"', patch)
        self.assertNotIn('+            self.message = "You won the battle!"', patch)
        self.assertIn('if side == "enemy" then', patch)

    def test_enemy_faint_is_enemy_nick_then_fainted_for_wild_and_trainer(self):
        faint = faint_body(BATTLE.read_text(encoding="utf-8"))
        self.assertIn(
            ENEMY_SAY,
            faint,
            "Say Enemy, the nick, then fainted! for a wild or trainer foe. "
            "Apply tools/notes/lane-e-battle-win-text.patch",
        )
        self.assertLess(faint.index('if side == "enemy" then'), faint.index(ENEMY_SAY))
        self.assertLess(faint.index(ENEMY_SAY), faint.index(PLAYER_SAY))
        self.assertEqual(faint.count('self:say(pokemon.name .. " fainted!")'), 1)

    def test_wild_win_drops_the_invented_page_and_trainer_win_keeps_pokered(self):
        battle = BATTLE.read_text(encoding="utf-8")
        done = victory_body(battle)
        self.assertNotIn(
            "You won the battle!",
            battle,
            "pokered has no such page. A wild win returns after EXP and "
            "level-up text. Apply tools/notes/lane-e-battle-win-text.patch",
        )
        self.assertIn(DEFEAT, done)
        self.assertIn(PRIZE, done)
        self.assertLess(done.index(DEFEAT), done.index(PRIZE))
        self.assertLess(done.index(PRIZE), done.index('return "victory"'))
        self.assertIn("if self.trainerName then", done)
        # A wild faint says the EXP line, then the level-up line, and the
        # trainer pages never run. The tail after that if returns victory
        # with no extra say, and the field state changes straight back.
        self.assertLess(done.index('gained\\n'), done.index("if self.trainerName then"))
        self.assertLess(done.index("grew to Lv"), done.index("if self.trainerName then"))
        after_trainer = done.split("if self.trainerName then", 1)[1]
        trainer_block = after_trainer.split("\n        end\n", 1)[0]
        # The old wild page was the else of this if: self.message = "You won the battle!".
        self.assertNotIn("\n        else\n", trainer_block)
        self.assertNotIn("You won the battle!", trainer_block)
        wild = after_trainer.split("\n        end\n", 1)[1].split('return "victory"', 1)[0]
        self.assertIn("A wild win has no extra page", wild)
        self.assertNotIn("self:say", wild)
        self.assertNotIn("self.message", wild)
        self.assertNotIn("You won the battle!", wild)
        ended = battle.split("function BattleEndedPhase:enter", 1)[1].split("\nfunction ", 1)[0]
        self.assertNotIn("self.battle.message", ended)
        self.assertNotIn(":say(", ended)
        finish = STATE.read_text(encoding="utf-8").split("function BattleState:finish", 1)[1].split("\nfunction ", 1)[0]
        self.assertNotIn("You won the battle!", finish)
        arm = finish.split("A final recoil victory", 1)[1].split("\n    end", 1)[0]
        self.assertIn('self.machine:change("overworld")', arm)
        self.assertNotIn(":say(", arm)
        self.assertNotIn("push(", arm)
        self.assertNotIn("You won", arm)


if __name__ == "__main__":
    unittest.main()
