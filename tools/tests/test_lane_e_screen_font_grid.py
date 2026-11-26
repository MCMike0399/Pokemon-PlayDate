"""20 by 13 grid font, the other reading of the screen-font patch.

tools/notes/lane-e-screen-font.patch stays the 16px layout and is not
edited here. tools/notes/lane-e-screen-font-grid.patch is option B:
pokered's one 8x8 font, drawn at the sweep's uniform 12/8 scale inside
the 20 by 13 cell. Borders stay full-cell. Red, the separate menu, and
OPTION/EXIT stay on their approved coordinates.

The live Source tree does not contain B. These checks apply B on a
throwaway worktree.
"""
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GRID = ROOT / "tools/notes/lane-e-screen-font-grid.patch"
HELD = ROOT / "tools/notes/lane-e-screen-font.patch"


def git(*args, cwd=ROOT):
    return subprocess.run(["git", *args], cwd=cwd, check=False, capture_output=True, text=True)


class LaneEScreenFontGridTests(unittest.TestCase):
    def test_grid_patch_applies_and_keeps_the_title_layout(self):
        completed = git("apply", "--check", str(GRID))
        self.assertEqual(completed.returncode, 0, completed.stderr)
        text = GRID.read_text(encoding="utf-8", errors="replace")
        self.assertIn("GbFont.FIT = 12", text)
        self.assertIn("math.floor(y * 8 / GbFont.FIT)", text)
        self.assertIn("math.floor(x * 8 / GbFont.FIT)", text)
        self.assertIn("TitleIdle.ROW - GbFont.FIT", text)
        self.assertIn("function GbFont.drawFitString", text)
        self.assertIn('GbFont.drawFitString(header, 0, 1)', text)
        self.assertIn("hlcoord 2, 5", text)
        self.assertNotIn("MallocPoolSize", text)
        self.assertNotIn("TitleIdle.FONT = 16", text)
        self.assertNotIn("GameOptions.CRANK_ROW = 12", text)
        self.assertNotIn("function TitleIdle.playerRect", text)
        self.assertNotIn("startMenu", text)
        held = HELD.read_text(encoding="utf-8", errors="replace")
        self.assertIn("TitleIdle.FONT = 16", held)
        self.assertNotIn("GbFont.FIT = 12", held)

    def test_live_tree_keeps_the_approved_title_and_not_the_grid_font(self):
        idle = (ROOT / "Source/game/titleIdle.lua").read_text(encoding="utf-8")
        font = (ROOT / "Source/game/gbFont.lua").read_text(encoding="utf-8")
        options = (ROOT / "Source/game/gameOptions.lua").read_text(encoding="utf-8")
        self.assertIn("TitleIdle.COL = 20", idle)
        self.assertIn("TitleIdle.ROW = 13", idle)
        self.assertIn("function TitleIdle.playerRect()", idle)
        self.assertIn('"OPTION"', idle)
        self.assertIn('"EXIT"', idle)
        self.assertIn("GameOptions.CRANK_ROW = 15", options)
        self.assertIn("GameOptions.CANCEL_ROW = 17", options)
        self.assertNotIn("GbFont.FIT = 12", font)
        self.assertNotIn("function GbFont.line", font)
        self.assertNotIn("GbFont.TILE = 16", font)
        held = HELD.read_text(encoding="utf-8", errors="replace")
        self.assertIn("GbFont.line(", held)
        self.assertIn("GbFont.TILE", held)

    def test_applied_grid_uses_one_font_and_does_not_move_red(self):
        path = "/tmp/lane-e-screen-font-grid-check"
        git("worktree", "remove", "--force", path)
        added = git("worktree", "add", "--detach", path, "HEAD")
        self.assertEqual(added.returncode, 0, added.stderr)
        try:
            applied = git("apply", str(GRID), cwd=path)
            self.assertEqual(applied.returncode, 0, applied.stderr)
            root = Path(path)
            font = (root / "Source/game/gbFont.lua").read_text(encoding="utf-8")
            idle = (root / "Source/game/titleIdle.lua").read_text(encoding="utf-8")
            title = (root / "Source/game/titleState.lua").read_text(encoding="utf-8")
            options = (root / "Source/game/optionsState.lua").read_text(encoding="utf-8")
            naming = (root / "Source/game/namingState.lua").read_text(encoding="utf-8")
            game_options = (root / "Source/game/gameOptions.lua").read_text(encoding="utf-8")
            self.assertIn("GbFont.FIT = 12", font)
            self.assertIn("function GbFont.drawBox(box)", font)
            self.assertIn("tileImage(sheetName, index):draw(col * TitleIdle.COL, row * TitleIdle.ROW)", font)
            self.assertIn("GbFont.drawFitString", title)
            self.assertIn("GbFont.drawFitString", options)
            self.assertIn("function TitleIdle.playerRect()", idle)
            self.assertIn("TitleIdle.COL = 20", idle)
            self.assertIn("TitleIdle.ROW = 13", idle)
            self.assertNotIn("TitleIdle.FONT = 16", idle)
            self.assertIn('return {"CONTINUE", "NEW GAME", "OPTION"}', idle)
            self.assertIn('"EXIT"', idle)
            self.assertIn("GameOptions.CRANK_ROW = 15", game_options)
            self.assertIn("GameOptions.CANCEL_ROW = 17", game_options)
            self.assertIn("{origin = 0, labelRow = 1, choiceRow = 3, cols = {1, 7, 14}}", options)
            self.assertIn("GbFont.drawBox(TitleIdle.textBox(0, spec.origin, 18, 3))", options)
            self.assertIn("TitleIdle.continueBox()", title)
            self.assertIn("spec.labelCol, spec.row", title)
            self.assertIn('GbFont.drawFitString(header, 0, 1)', naming)
            self.assertIn("TitleIdle.textBox(0, 4, 18, 9)", naming)
            self.assertIn("5 + (row - 1) * 2", naming)
            draw = title.split("function TitleState:draw()", 1)[1]
            title_art = draw.split('if self.phase == "title"', 1)[1].split("return", 1)[0]
            self.assertIn("self:drawTitleArt()", title_art)
            self.assertNotIn("mainMenuBox", title_art)
        finally:
            git("worktree", "remove", "--force", path)


if __name__ == "__main__":
    unittest.main()
