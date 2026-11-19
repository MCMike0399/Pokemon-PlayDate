#!/usr/bin/env python3
"""Red's back stands on the player platform until the first send-out.

The Giovanni intro drew his picture and an empty player platform.
images/player/red-pic-back.png is the back sprite. It stays up through
"wants to battle!" and leaves when Charizard's send-out finishes.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class PlayerBackTests(unittest.TestCase):
    def test_red_back_is_drawn_before_the_first_sendout(self):
        scene = (ROOT / "Source/battle/battleScene.lua").read_text()
        field = scene.split("function BattleScene:drawBattleField()", 1)[1].split(
            "function BattleScene:", 1)[0]
        self.assertIn("self:drawPlayerBack()", field)
        self.assertIn("not self.playerIntroDone", field)
        back = scene.split("function BattleScene:drawPlayerBack()", 1)[1].split(
            "function BattleScene:", 1)[0]
        self.assertIn('gfx.image.new("images/player/red-pic-back")', back)
        done = scene.split('elseif request.kind == "sendout" then', 1)[1].split(
            "elseif request.kind", 1)[0]
        self.assertIn("self.playerIntroDone = true", done)
        image = ROOT / "Source/images/player/red-pic-back.png"
        self.assertGreater(image.stat().st_size, 100)


if __name__ == "__main__":
    unittest.main()
