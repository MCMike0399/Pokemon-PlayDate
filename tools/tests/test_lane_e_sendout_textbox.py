"""Send-out keeps the GB text box.

Lane I's tree still blits _wrapped("battle-message") into the heavy
single-border box with the system font ("Go! CHARIZARD!"). This tip
already replaced that blit with Dialog:draw(true), which paints
GbFont.drawBox and the source glyphs. The heavy rect is still filled
first and then covered in the same frame. A regression would put the
system-font blit back.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCENE = ROOT / "Source/battle/battleScene.lua"


class LaneESendoutTextboxTests(unittest.TestCase):
    def test_sendout_page_is_the_gb_dialog_not_the_system_font_blit(self):
        scene = SCENE.read_text()
        self.assertNotIn('_wrapped("battle-message"', scene)
        field = scene.split("function BattleScene:drawBattleField()", 1)[1]
        field = field.split("\nfunction ", 1)[0]
        narration = field.split("self.messageDialog:draw(true)", 1)
        self.assertEqual(len(narration), 2)
        self.assertIn("send-out", narration[0])
        self.assertNotIn("gfx.drawText", narration[0])


if __name__ == "__main__":
    unittest.main()
