"""Battle HUDs use the pokered tile font. Lane E has not applied this yet.

tools/notes/lane-e-battle-hud.patch replaces the system-font name, the
"HP" label, and the rectangle bar with GbFont.drawBattleHud. Lv is $6E,
HP is $71, the left cap is $62, and the battle right cap is $6D after
LoadHudTilePatterns. The hunk stays above the lines lane H's
lane-e-battle-text-flicker.patch anchors, and it does not touch the
dialog-font message hunk, so either patch can apply first.
"""
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-battle-hud.patch"
DIALOG = ROOT / "tools/notes/lane-e-dialog-font.patch"


class LaneEBattleHudTests(unittest.TestCase):
    def test_battle_hud_patch_applies(self):
        completed = subprocess.run(
            ["git", "apply", "--check", str(PATCH)],
            cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        completed = subprocess.run(
            ["git", "apply", "--check", str(DIALOG)],
            cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        patch = PATCH.read_text()
        self.assertIn("GbFont.drawBattleHud", patch)
        self.assertIn("$6E", patch)
        self.assertIn("$71", patch)
        self.assertIn("$62", patch)
        self.assertIn("$6d", patch)

    @unittest.expectedFailure
    def test_battle_hud_uses_the_tile_font(self):
        battle = (ROOT / "Source/battle/battleScene.lua").read_text()
        self.assertIn('GbFont.drawBattleHud("enemy"', battle)
        self.assertIn('GbFont.drawBattleHud("player"', battle)
        self.assertNotIn('_text("enemy-name"', battle)
        self.assertNotIn('_text("player-hp-num"', battle)


if __name__ == "__main__":
    unittest.main()
