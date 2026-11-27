"""The enemy platform and sprite sit 6px higher.

Lane E has not applied this yet. tools/notes/lane-e-enemy-platform-shift.patch
raises the enemy platform so its bottom line is y=87, and raises the enemy
picture with it. The player HUD stays at y=96, which leaves eight white
pixels between them.
"""
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-enemy-platform-shift.patch"


class LaneEEnemyPlatformShiftTests(unittest.TestCase):
    def test_platform_shift_patch_applies(self):
        completed = subprocess.run(
            ["git", "apply", "--check", str(PATCH)],
            cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        patch = PATCH.read_text()
        self.assertIn("drawLine(268, 87, 390, 87)", patch)
        self.assertIn('if side == "enemy" then y = y - 6 end', patch)

    @unittest.expectedFailure
    def test_enemy_platform_clears_the_player_hud(self):
        source = (ROOT / "Source/battle/battleScene.lua").read_text()
        self.assertIn("drawLine(268, 87, 390, 87)", source)
        self.assertNotIn("drawLine(268, 93, 390, 93)", source)
        self.assertIn('if side == "enemy" then y = y - 6 end', source)


if __name__ == "__main__":
    unittest.main()
