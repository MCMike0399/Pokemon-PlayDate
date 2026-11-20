#!/usr/bin/env python3
"""Red's battle back uses the same 80px slot as a Pokémon back sprite.

gfx/player/redb.png is 32x32. Drawing it at that size puts an overworld-sized
figure on the player platform through "wants to battle!".
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class PlayerBackScaleTests(unittest.TestCase):
    def test_red_back_fills_the_player_slot(self):
        scene = (ROOT / "Source/battle/battleScene.lua").read_text()
        back = scene.split("function BattleScene:drawPlayerBack()", 1)[1].split(
            "function BattleScene:", 1)[0]
        self.assertIn("local size = 80", back)
        self.assertIn("drawScaled(0, 0, scale)", back)
        self.assertIn("70 + size - sh", back)


if __name__ == "__main__":
    unittest.main()
