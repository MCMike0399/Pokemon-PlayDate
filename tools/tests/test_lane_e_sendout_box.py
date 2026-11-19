"""Send-out keeps the pokered message box.

seafoam-crossing.mp4 shows two wild Seel battles. "A wild SEEL appeared!"
and the start of "Go! CHARIZARD!" use TextBoxBorder and the pixel font.
Once that page is confirmed, the ball animation repaints the same line
with gfx.drawRect and the system font, and the y=170 field rule sits
above the shorter box. "Got away safely!" is a new say(), so the tile
box returns. The confirmed page has to stay on Dialog:draw through the
send-out. tools/notes/lane-e-sendout-box.patch. The source check fails
until that patch is in Source/.
"""

import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-sendout-box.patch"
SCENE = ROOT / "Source/battle/battleScene.lua"
DIALOG = ROOT / "Source/ui/dialog.lua"

class SendoutBoxTests(unittest.TestCase):
    def test_patch_paints_the_settled_page_with_the_tile_font(self):
        patch = PATCH.read_text(encoding="utf-8")
        added = "\n".join(
            line[1:] for line in patch.splitlines()
            if line.startswith("+") and not line.startswith("+++"))
        self.assertIn("function Dialog:drawSettled", added)
        self.assertIn("self.messageDialog:drawSettled", added)
        self.assertNotIn('_wrapped("battle-message"', added)
        completed = subprocess.run(
            ["git", "apply", "--check", str(PATCH)],
            cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        with tempfile.TemporaryDirectory() as tmp:
            tree = Path(tmp)
            for relative in ("Source/ui/dialog.lua", "Source/battle/battleScene.lua"):
                target = tree / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes((ROOT / relative).read_bytes())
            applied = subprocess.run(
                ["patch", "-p1", "-d", str(tree), "-i", str(PATCH)],
                check=False, capture_output=True, text=True)
            self.assertEqual(applied.returncode, 0, applied.stdout + applied.stderr)
            dialog = (tree / "Source/ui/dialog.lua").read_text(encoding="utf-8")
            scene = (tree / "Source/battle/battleScene.lua").read_text(encoding="utf-8")
            settled = dialog.split("function Dialog:drawSettled", 1)[1]
            self.assertIn("self:draw()", settled)
            self.assertNotIn("drawRect", settled)
            self.assertNotIn("getSystemFont", settled)
            self.assertIn("self.isActive = savedActive", settled)
            self.assertIn("GbFont.drawBox(TitleIdle.textBox(0, 12, 18, 4))", dialog)
            self.assertIn('self.messageDialog:drawSettled(self.battle.message or "")', scene)
            self.assertNotIn('_wrapped("battle-message"', scene)

    def test_confirmed_sendout_stays_on_the_textbox(self):
        scene = SCENE.read_text(encoding="utf-8")
        dialog = DIALOG.read_text(encoding="utf-8")
        self.assertTrue(
            "function Dialog:drawSettled" in dialog
            and '_wrapped("battle-message"' not in scene
            and "self.messageDialog:drawSettled" in scene,
            "Apply tools/notes/lane-e-sendout-box.patch so a confirmed send-out stays on the tile text box",
        )


if __name__ == "__main__":
    unittest.main()
