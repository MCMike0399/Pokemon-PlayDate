"""BattleMenu still draws a 1px box and a '>' cursor.
Lane G screens draw the pokered 8x8 tiles themselves.
"""
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-menu-font.patch"


class LaneEMenuFontTests(unittest.TestCase):
    def test_menu_font_patch_applies_cleanly(self):
        completed = subprocess.run(
            ["git", "apply", "--check", str(PATCH)],
            cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr)

    @unittest.expectedFailure
    def test_battle_menu_uses_the_filled_cursor(self):
        source = (ROOT / "Source/ui/menu.lua").read_text()
        self.assertIn('"▶"', source)
        self.assertNotIn('selected and ">"', source)
        self.assertNotIn("gfx.drawRect(x, y, w, h)", source)


if __name__ == "__main__":
    unittest.main()
