#!/usr/bin/env python3
"""Credits text is drawn in white on the black roll.

The system font is black. kDrawModeCopy leaves those glyphs black, so the
staff lines disappear on the black fill. The debug overlay uses
kDrawModeInverted for the same font on black.
tools/notes/lane-e-credits-text-color.patch.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class CreditsTextColorTests(unittest.TestCase):
    @unittest.expectedFailure
    def test_credits_draw_inverts_the_system_font(self):
        source = (ROOT / "Source/game/eventState.lua").read_text(encoding="utf-8")
        window = source.split('if self.phase=="credits" then', 1)[1]
        window = window.split("gfx.popContext()", 1)[0]
        self.assertIn("gfx.kDrawModeInverted", window)
        self.assertNotIn("gfx.kDrawModeCopy", window)


if __name__ == "__main__":
    unittest.main()
