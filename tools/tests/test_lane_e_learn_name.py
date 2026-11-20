#!/usr/bin/env python3
"""The learn box shows the move name.

pokered's cont after "trying to learn" scrolls that row up and prints
the move on the second line of the battle text box. The box is two
rows, so painting the prompt from the top shows "CHARIZARD is / trying
to learn" and clips the name. tools/notes/lane-e-learn-name.patch.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class LearnNameTests(unittest.TestCase):
    def test_ask_box_scrolls_to_the_move_name(self):
        source = (ROOT / "Source/game/learningState.lua").read_text(encoding="utf-8")
        self.assertIn("function LearningState:visiblePrompt()", source)
        window = source.split("function LearningState:visiblePrompt()", 1)[1].split("function ", 1)[0]
        self.assertIn("trying to learn", window)
        draw = source.split("function LearningState:draw()", 1)[1]
        ask = draw.split('self.phase ~= "idle"', 1)[1].split("end", 1)[0]
        self.assertIn("visiblePrompt", ask)
        self.assertNotIn("battleText(self.prompt, 270)", ask)


if __name__ == "__main__":
    unittest.main()
