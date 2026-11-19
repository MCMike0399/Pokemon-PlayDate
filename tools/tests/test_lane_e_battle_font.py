#!/usr/bin/env python3
"""Battle narration stays in the GB font after the typewriter closes.

Dialog types the intro in the GB font. A then closes that dialog while
battle.message stays set for the trainer exit and the send-out. advance
steps past the last page, so the settled draw uses that last page.
The first paint also syncs the line, because enter sets it before
BattleScene:update.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCENE = ROOT / "Source/battle/battleScene.lua"
DIALOG = ROOT / "Source/ui/dialog.lua"


class BattleFontTests(unittest.TestCase):
    def test_draw_syncs_and_keeps_the_finished_page(self):
        scene = SCENE.read_text()
        draw = scene.split("function BattleScene:draw()", 1)[1].split(
            "function BattleScene:drawBackgroundBase()", 1)[0]
        self.assertIn("self:syncMessage()", draw)
        self.assertIn("self.messageDialog:draw(true)", scene)
        self.assertNotIn('self:_wrapped("battle-message"', scene)
        dialog = DIALOG.read_text()
        self.assertIn("function Dialog:draw(settled)", dialog)
        self.assertIn("line = self.lines[#self.lines]", dialog)
        self.assertIn("if not self.isActive and not (settled and line) then return end", dialog)


if __name__ == "__main__":
    unittest.main()
