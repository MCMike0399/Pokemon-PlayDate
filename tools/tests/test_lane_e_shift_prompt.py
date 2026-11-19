#!/usr/bin/env python3
"""SHIFT shows the question and YES/NO together, in the GB font.

The Giovanni rematch printed "GIOVANNI is about" and then sent the next
Pokémon. finishRound said the whole _TrainerAboutToUseText first, so the
YES/NO box existed only after that page was dismissed, and the scene
drew the prompt with the system font. The question is its own page and
the menu is on that page.

pret/pokered text_2.asm breaks the question before "change #MON?".
The GB box is 18 columns, so that line break keeps the é on screen.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class ShiftPromptTests(unittest.TestCase):
    def test_question_and_menu_are_one_screen(self):
        battle = (ROOT / "Source/battle/battle.lua").read_text()
        finish = battle.split("function Battle:finishRound()", 1)[1].split(
            "function Battle:", 1)[0]
        self.assertIn(
            'self:say(self.trainerName .. " is about to use " .. incoming.name .. "!")',
            finish)
        self.assertIn('text = "Will " .. playerName .. "\\nchange POKéMON?"', finish)
        self.assertNotIn(
            'self:say(self.trainerName .. " is about to use " .. incoming.name\n',
            finish)
        handler = battle.split('elseif kind == "shift" then', 1)[1].split(
            "elseif kind ==", 1)[0]
        self.assertIn("value.text", handler)
        self.assertIn("self.battle.message = value.text", handler)

    def test_shift_prompt_stays_in_the_gb_font(self):
        scene = (ROOT / "Source/battle/battleScene.lua").read_text()
        branch = scene.split("if self.battle.shiftChoice then", 1)[1].split(
            "elseif self.battle:isAwaitingCommand()", 1)[0]
        self.assertIn("self.messageDialog:draw(true)", branch)
        self.assertNotIn('_wrapped("shift-prompt"', branch)
        self.assertIn("self.shiftMenu:draw", branch)


if __name__ == "__main__":
    unittest.main()
