"""Battle sprites are drawn after their platforms.

Lane E has not applied this yet. tools/notes/lane-e-battle-sprite-order.patch
draws the platforms first, then the enemy and player pictures, so the
sprite covers the platform line. The hunk is the drawBattleField sprite
block and does not touch the HUD or message anchors.
"""
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-battle-sprite-order.patch"


def field_body(source):
    return source.split("function BattleScene:drawBattleField()", 1)[1].split("\nfunction ", 1)[0]


class LaneEBattleSpriteOrderTests(unittest.TestCase):
    def test_sprite_order_patch_applies(self):
        completed = subprocess.run(
            ["git", "apply", "--check", str(PATCH)],
            cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        patch = PATCH.read_text()
        self.assertIn("self:drawPlatforms()", patch)
        self.assertIn("self:drawPresentedPokemon", patch)

    @unittest.expectedFailure
    def test_sprites_cover_the_platform(self):
        field = field_body((ROOT / "Source/battle/battleScene.lua").read_text())
        platform = field.index("self:drawPlatforms()")
        sprite = field.index("self:drawPresentedPokemon")
        self.assertLess(platform, sprite)
        self.assertNotIn("before platforms so platforms overlap", field)


if __name__ == "__main__":
    unittest.main()
