#!/usr/bin/env python3
"""The battle intro redraws one line in two fonts.

Dialog types "LORELEI wants to battle!" in the GB font. A then closes
that dialog while battle.message stays set for the trainer exit and the
send-out. drawBattleField falls through to _wrapped, which paints the
same sentence with the system font: one proportional line, about
14px tall, instead of the 20px GB tiles. On
20261119T204111Z-elite-lorelei.mp4 the GB page holds through the iris
and the swap is still on screen about a second later, for the rest of
the trainer exit. The first paint can also take that path, because
enter sets the line before BattleScene:update syncs it. The patch is
not applied on this branch.
"""

import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-battle-font.patch"
SCENE = ROOT / "Source/battle/battleScene.lua"
DIALOG = ROOT / "Source/ui/dialog.lua"


class BattleFontTests(unittest.TestCase):
    def test_live_narration_falls_back_to_the_system_font(self):
        scene = SCENE.read_text()
        self.assertIn('self:_wrapped("battle-message", message, 374, 44)', scene)
        draw = scene.split("function BattleScene:draw()", 1)[1].split("function BattleScene:drawBackgroundBase()", 1)[0]
        self.assertNotIn("self:syncMessage()", draw)
        dialog = DIALOG.read_text()
        self.assertIn("function Dialog:draw()\n    if not self.isActive then return end", dialog)

    @unittest.expectedFailure
    def test_unpatched_scene_keeps_the_finished_page_in_the_gb_font(self):
        scene = SCENE.read_text()
        self.assertIn("self.messageDialog:draw(true)", scene)
        self.assertNotIn('self:_wrapped("battle-message"', scene)
        dialog = DIALOG.read_text()
        self.assertIn("function Dialog:draw(settled)", dialog)

    def test_patch_draws_the_settled_page_with_the_dialog_font(self):
        check = subprocess.run(
            ["git", "apply", "--check", str(PATCH)], cwd=ROOT,
            capture_output=True, text=True)
        self.assertEqual(check.returncode, 0, check.stderr)
        text = PATCH.read_text()
        scene_patch = Path("/tmp/lane-e-battle-font-scene.patch")
        dialog_patch = Path("/tmp/lane-e-battle-font-dialog.patch")
        scene_patch.write_text(text.split("--- a/Source/ui/dialog.lua", 1)[0])
        dialog_patch.write_text("--- a/Source/ui/dialog.lua" + text.split("--- a/Source/ui/dialog.lua", 1)[1])
        scene_out = Path("/tmp/lane-e-battle-font-scene.lua")
        dialog_out = Path("/tmp/lane-e-battle-font-dialog.lua")
        scene = subprocess.run(
            ["patch", "-o", str(scene_out), str(SCENE), str(scene_patch)],
            capture_output=True, text=True)
        self.assertEqual(scene.returncode, 0, scene.stdout + scene.stderr)
        dialog = subprocess.run(
            ["patch", "-o", str(dialog_out), str(DIALOG), str(dialog_patch)],
            capture_output=True, text=True)
        self.assertEqual(dialog.returncode, 0, dialog.stdout + dialog.stderr)
        scene_text = scene_out.read_text()
        draw = scene_text.split("function BattleScene:draw()", 1)[1].split("function BattleScene:drawBackgroundBase()", 1)[0]
        self.assertIn("self:syncMessage()", draw)
        self.assertIn("self.messageDialog:draw(true)", scene_text)
        self.assertNotIn('self:_wrapped("battle-message"', scene_text)
        self.assertIn("function Dialog:draw(settled)", dialog_out.read_text())


if __name__ == "__main__":
    unittest.main()
