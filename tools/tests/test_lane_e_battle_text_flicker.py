"""The opening iris clips the first battle line.

BlueBot's review of artifacts/lane-h/zapdos-l50-fixture-supplement.mp4
shows the first frames of "A wild ZAPDOS appeared!" cut on a curve through
the lower row. The capture is the battle intro iris, not a later redraw.

Source/battle/battleScene.lua draw() sets the iris with setStencilImage and
calls drawBattleField while that stencil is active. drawBattleField paints
the message fills and the glyphs, then draw() calls clearStencil only after
drawBattleField returns. On the first recorded frame introTimer is 14, so
irisRadius is floor(14/20*260) = 182 at (200, 120). That circle's left edge
is x=23 at y=160 and x=43 at y=212, which is through "appeared" and the
bottom rule. Recording frames 2 through 5 open the circle and the same
glyphs are whole.

"Go! SQUIRTLE!" (recording frame 19) and the FIGHT/BAG menu (frame 67) are
after the iris. Neither frame has black pixels that the next frame drops.
The thick bars under the tile box are the "─" glyph in
Source/images/title/font/extra.png (rows 3 and 5-6 of the 8x8 tile). They
are still there once the box has settled.

Lane E owns battleScene.lua. This test fails until
tools/notes/lane-e-battle-text-flicker.patch is applied. The patch drops
the stencil immediately before the message fills, so the box and the glyphs
are drawn after the circle mask is gone. Sprites and platforms above the
box stay inside the iris.
"""

import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-battle-text-flicker.patch"
SCENE = ROOT / "Source/battle/battleScene.lua"


def message_drops_stencil_before_fill(source):
    field = source.split("function BattleScene:drawBattleField()", 1)[1]
    field = field.split("\nfunction ", 1)[0]
    head, _box = field.split("local boxY = 180", 1)
    font_at = head.rfind("gfx.setFont(gfx.getSystemFont())")
    if font_at < 0:
        return False
    return "gfx.clearStencil()" in head[font_at:]


class LaneEBattleTextFlickerTests(unittest.TestCase):
    def test_patch_applies_on_this_branch(self):
        completed = subprocess.run(
            ["git", "apply", "--check", str(PATCH)],
            cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        patch = PATCH.read_text()
        self.assertIn("gfx.clearStencil()", patch)
        self.assertIn("Source/battle/battleScene.lua", patch)

    def test_patched_tree_draws_the_message_after_the_stencil(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            dest = root / "Source" / "battle"
            dest.mkdir(parents=True)
            (dest / "battleScene.lua").write_text(SCENE.read_text())
            completed = subprocess.run(
                ["patch", "-p1", "-d", str(root), "-i", str(PATCH)],
                check=False, capture_output=True, text=True)
            self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
            patched = (dest / "battleScene.lua").read_text()
        self.assertTrue(message_drops_stencil_before_fill(patched))
        field = patched.split("function BattleScene:drawBattleField()", 1)[1]
        field = field.split("\nfunction ", 1)[0]
        before_fill, _after = field.split("gfx.fillRect(0, boxY, 400, 60)", 1)
        self.assertIn("gfx.clearStencil()", before_fill)

    @unittest.expectedFailure
    def test_live_message_box_is_drawn_under_the_iris(self):
        source = SCENE.read_text()
        self.assertTrue(message_drops_stencil_before_fill(source))


if __name__ == "__main__":
    unittest.main()
