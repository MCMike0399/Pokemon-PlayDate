"""16px screen font that used to live in Source/.

Lane E has not applied this yet. tools/notes/lane-e-screen-font.patch is
the source change. These checks fail on the live tree and pass once that
patch is applied. The dex list stays on the 20 by 13 cell.
"""
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-screen-font.patch"


class LaneEScreenFontTests(unittest.TestCase):
    def test_patch_applies(self):
        completed = subprocess.run(
            ["git", "apply", "--check", str(PATCH)],
            cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        text = PATCH.read_text(encoding="utf-8", errors="replace")
        self.assertIn("diff --git a/Source/game/titleIdle.lua", text)
        self.assertIn("diff --git a/Source/game/gameOptions.lua", text)
        self.assertIn("diff --git a/Source/game/optionsState.lua", text)
        self.assertIn("diff --git a/Source/game/namingState.lua", text)
        self.assertIn("diff --git a/Source/game/titleState.lua", text)
        self.assertIn("diff --git a/Source/images/title/font/hud.png", text)
        self.assertIn("TitleIdle.FONT = 16", text)
        self.assertIn("function TitleIdle.messageBox", text)
        self.assertIn("function TitleIdle.battleHud", text)
        self.assertNotIn("MallocPoolSize", text)

    def test_title_text_uses_the_16px_cell(self):
        idle = (ROOT / "Source/game/titleIdle.lua").read_text(encoding="utf-8")
        self.assertIn("TitleIdle.FONT = 16", idle)
        self.assertIn("function TitleIdle.fontRect(col, row, cols, rows)", idle)
        self.assertIn("function TitleIdle.messageBox(compact)", idle)
        self.assertIn("function TitleIdle.commandBoxes()", idle)
        self.assertIn("function TitleIdle.battleHud(side, info)", idle)
        self.assertIn("hudVertical", idle)
        self.assertTrue((ROOT / "Source/images/title/font/hud.png").is_file())

    def test_options_rows_fit_the_16px_cell(self):
        options = (ROOT / "Source/game/gameOptions.lua").read_text(encoding="utf-8")
        state = (ROOT / "Source/game/optionsState.lua").read_text(encoding="utf-8")
        self.assertIn("GameOptions.CRANK_ROW = 12", options)
        self.assertIn("GameOptions.CANCEL_ROW = 14", options)
        self.assertIn("TitleIdle.fontRect(1, GameOptions.CRANK_ROW, 18, 1)", options)
        self.assertIn("TitleIdle.textBox(0, 8, 18, 2)", options)
        self.assertIn("{origin = 0, labelRow = 1, choiceRow = 2, cols = {1, 7, 14}}", state)
        self.assertIn("GbFont.drawBox(TitleIdle.textBox(0, spec.origin, 18, 2))", state)

    def test_naming_and_continue_use_the_screen_font(self):
        naming = (ROOT / "Source/game/namingState.lua").read_text(encoding="utf-8")
        title = (ROOT / "Source/game/titleState.lua").read_text(encoding="utf-8")
        self.assertIn("TitleIdle.messageBox()", naming)
        self.assertIn("GbFont.line(GbFont.clip(line, box.columns), box.textX, rows[offset + 1])", naming)
        self.assertIn("tile = GbFont.TILE", naming)
        self.assertIn("GbFont.line(cell.label, cell.labelRect.x, cell.labelRect.y)", title)
        self.assertIn("GbFont.line(cell.value, cell.valueRect.x, cell.valueRect.y)", title)


if __name__ == "__main__":
    unittest.main()
