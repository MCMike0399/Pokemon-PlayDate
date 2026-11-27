"""20 by 13 grid font. Option B is the screen font.

tools/notes/lane-e-screen-font-grid.patch draws pokered's one 8x8 font at
the sweep's uniform 12/8 scale inside the 20 by 13 cell. Borders stay
full-cell. Red, the separate menu, and OPTION/EXIT stay on their approved
coordinates. The 16px patch is retired and is not in the tree.

The live Source tree does not contain the patch. These checks apply it on
a throwaway worktree, then measure the r2 frames with the sweep's per-cell
bounds and ink-overlap predicate.
"""
import subprocess
import unittest
from pathlib import Path

from PIL import Image

import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.tests.lane_e_apply import accepts, forward_check, reverse_check

ROOT = Path(__file__).resolve().parents[2]
GRID = ROOT / "tools/notes/lane-e-screen-font-grid.patch"
FRAMES = ROOT / "artifacts/lane-g/screen-font"
RETIRED_PATCH = ROOT / "tools/notes/lane-e-screen-font.patch"
RETIRED_TEST = ROOT / "tools/tests/test_lane_e_screen_font.py"


def git(*args, cwd=ROOT):
    return subprocess.run(["git", *args], cwd=cwd, check=False, capture_output=True, text=True)


def hits(cell, rects):
    x0, y0, x1, y1 = cell
    for rx0, ry0, rx1, ry1 in rects:
        if x0 < rx1 and rx0 < x1 and y0 < ry1 and ry0 < y1:
            return True
    return False


def glyph_issues(path, skip):
    """The fidelity sweep's per-cell bounds and ink-overlap predicate.

    Text ink is at most 12 by 12 and keeps a pixel of air from the ink in
    the next cell. A full-cell border stroke is not text. skip is the only
    place art that is not this font may be ignored, and each rect is cited
    at the call.
    """
    image = Image.open(path).convert("L")
    cells = {}
    issues = []
    for row in range(240 // 13):
        for col in range(400 // 20):
            x0, y0 = col * 20, row * 13
            if hits((x0, y0, x0 + 20, y0 + 13), skip):
                continue
            minx, maxx, miny, maxy = 20, -1, 13, -1
            row_count = [0] * 13
            for dy in range(13):
                for dx in range(20):
                    if image.getpixel((x0 + dx, y0 + dy)) < 128:
                        minx, maxx = min(minx, dx), max(maxx, dx)
                        miny, maxy = min(miny, dy), max(maxy, dy)
                        row_count[dy] += 1
            if maxx < 0:
                continue
            width, height = maxx - minx + 1, maxy - miny + 1
            if max(row_count) >= 14:
                continue
            if width >= 16 and height <= 8:
                continue
            if height >= 13 and width <= 10:
                continue
            cells[(col, row)] = (minx, maxx, miny, maxy)
            if width > 12 or height > 12:
                issues.append((col, row, width, height))
    for (col, row), box in cells.items():
        right = cells.get((col + 1, row))
        if right is not None and (20 - box[1] - 1) + right[0] < 1:
            issues.append(("h", col, row))
        below = cells.get((col, row + 1))
        if below is not None and (13 - box[3] - 1) + below[2] < 1:
            issues.append(("v", col, row))
    return issues


def cell_bits(path, col, row):
    image = Image.open(path).convert("L")
    x0, y0 = col * 20, row * 13
    return tuple(
        tuple(image.getpixel((x0 + dx, y0 + dy)) < 128 for dx in range(20))
        for dy in range(13)
    )


def cell_ink(path, col, row):
    return sum(bit for row_bits in cell_bits(path, col, row) for bit in row_bits)


class LaneEScreenFontGridTests(unittest.TestCase):
    def test_retired_16px_patch_is_gone(self):
        self.assertFalse(RETIRED_PATCH.exists())
        self.assertFalse(RETIRED_TEST.exists())
        self.assertFalse(GRID.read_text(encoding="utf-8").startswith("TitleIdle.FONT = 16"))

    def test_grid_patch_applies_and_keeps_the_title_layout(self):
        completed = accepts(GRID)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        text = GRID.read_text(encoding="utf-8", errors="replace")
        self.assertIn("GbFont.FIT = 12", text)
        self.assertIn("math.floor(y * 8 / GbFont.FIT)", text)
        self.assertIn("math.floor(x * 8 / GbFont.FIT)", text)
        self.assertIn("TitleIdle.ROW - GbFont.FIT", text)
        self.assertIn("function GbFont.drawFitString", text)
        self.assertIn('GbFont.drawFitString(header, 0, 1)', text)
        self.assertIn("hlcoord 2, 5", text)
        self.assertIn("constants/charmap.asm <PK> is $e1 and <MN> is $e2", text)
        self.assertIn("LoadEDTile copies gfx/font/ED.1bpp", text)
        self.assertIn('letter == "PK" or letter == "MN" or letter == "ED"', text)
        self.assertIn("GbFont.drawFitChar(letter, tileCol, tileRow)", text)
        self.assertNotIn("MallocPoolSize", text)
        self.assertNotIn("TitleIdle.FONT = 16", text)
        self.assertNotIn("GameOptions.CRANK_ROW = 12", text)
        self.assertNotIn("function TitleIdle.playerRect", text)
        self.assertNotIn("startMenu", text)

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
        if "GbFont.FIT = 12" in font:
            self.assertIn("function GbFont.drawFitString", font)
        else:
            self.assertNotIn("GbFont.FIT = 12", font)
            self.assertNotIn("function GbFont.line", font)
            self.assertNotIn("GbFont.TILE = 16", font)
            self.assertNotIn("TitleIdle.FONT = 16", idle)

    def test_applied_grid_uses_one_font_and_does_not_move_red(self):
        path = "/tmp/lane-e-screen-font-grid-check"
        git("worktree", "remove", "--force", path)
        added = git("worktree", "add", "--detach", path, "HEAD")
        self.assertEqual(added.returncode, 0, added.stderr)
        try:
            if forward_check(GRID, path).returncode == 0:
                applied = git("apply", str(GRID), cwd=path)
                self.assertEqual(applied.returncode, 0, applied.stderr)
            else:
                present = reverse_check(GRID, path)
                self.assertEqual(present.returncode, 0, present.stderr)
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
            self.assertIn('letter == "PK" or letter == "MN" or letter == "ED"', naming)
            self.assertIn("GbFont.drawFitChar(letter, tileCol, tileRow)", naming)
            self.assertIn("if char == \"PK\" then return \"font\", 0xe1 - 0x80 end", idle)
            self.assertIn("if char == \"MN\" then return \"font\", 0xe2 - 0x80 end", idle)
            self.assertIn("if char == \"ED\" then return \"ed\", 0 end", idle)
            draw = title.split("function TitleState:draw()", 1)[1]
            title_art = draw.split('if self.phase == "title"', 1)[1].split("return", 1)[0]
            self.assertIn("self:drawTitleArt()", title_art)
            self.assertNotIn("mainMenuBox", title_art)
        finally:
            git("worktree", "remove", "--force", path)

    def test_naming_pk_mn_and_ed_are_one_tile(self):
        # PrintAlphabet writes one byte per cell. <PK> and <MN> are the
        # single tiles $e1 and $e2. ED is the one tile from LoadEDTile.
        # Column 8 is tile column 16 and column 9 is tile column 18, so
        # the skipped column between them is 17. ED is the last cell of
        # the fifth alphabet row, tile (18, 13), beside the border.
        path = FRAMES / "naming-r2.png"
        self.assertEqual(cell_ink(path, 17, 11), 0)
        self.assertGreater(cell_ink(path, 16, 11), 0)
        self.assertGreater(cell_ink(path, 18, 11), 0)
        self.assertEqual(cell_bits(path, 19, 13), cell_bits(path, 19, 5))

    def test_continue_box_overdraws_the_menu_bottom_row(self):
        # engine/menus/main_menu.asm MainMenu, when a save exists:
        #   hlcoord 0, 0
        #   ld b, 6
        #   ld c, 13
        #   call TextBoxBorder
        # home/text.asm TextBoxBorder draws the top row, then b interior
        # rows, then the bottom row. The bottom border is therefore row 7
        # and the right border is column 14.
        # DisplayContinueGameInfo then draws:
        #   hlcoord 4, 7
        #   ld b, 8
        #   ld c, 14
        #   call TextBoxBorder
        # Its top border is that same row 7, from column 4 through column
        # 19, so it replaces the menu's bottom border on columns 4-14.
        # Column 4 row 7 is the continue top-left corner, the same tile as
        # the menu's top-left. Column 14 row 7 is a horizontal stroke, not
        # the menu's right-border corner.
        path = FRAMES / "continue-r2.png"
        self.assertEqual(cell_bits(path, 4, 7), cell_bits(path, 0, 0))
        self.assertEqual(cell_bits(path, 14, 7), cell_bits(path, 1, 7))
        self.assertNotEqual(cell_bits(path, 14, 7), cell_bits(path, 14, 0))
        self.assertNotEqual(cell_bits(path, 0, 7), cell_bits(path, 0, 0))

    def test_glyph_ink_stays_in_its_cell_and_does_not_touch(self):
        # Title art is not the 8x8 font. engine/movie/title.asm places the
        # pokemon logo at hlcoord 2, 1 (six rows) and its last row at
        # hlcoord 2, 7. TitleIdle.LAYOUT.logo draws that bitmap at (8, 4)
        # scaled by 2 (128 by 56 becomes 256 by 112).
        # PrintGameVersionOnTitleScreen says those tiles "are not usual
        # text" and places them at hlcoord 7, 8. LAYOUT.version draws the
        # blue bitmap at (24, 112) scaled by 2 (64 by 8 becomes 128 by 16).
        # LoadTitleMonSprite is hlcoord 5, 10 and a front pic is 7 tiles
        # (TitleIdle.MON_COL / MON_ROW / MON_TILES).
        # DrawPlayerCharacter uses OAM Y $60 X $5a, 7 rows by 5 columns,
        # which is TitleIdle.playerRect (205, 130, 100 by 91).
        # The copyright is .tileScreenCopyrightTiles at hlcoord 2, 17,
        # fifteen tiles, TitleIdle.copyrightRect. Options, naming, and
        # continue are only the grid font and full-cell borders.
        title_art = [
            (8, 4, 264, 116),
            (24, 112, 152, 128),
            (100, 130, 240, 221),
            (205, 130, 305, 221),
            (40, 221, 340, 234),
        ]
        screens = {
            "title-r2.png": title_art,
            "options-r2.png": [],
            "naming-r2.png": [],
            "continue-r2.png": [],
        }
        for name, skip in screens.items():
            self.assertEqual(glyph_issues(FRAMES / name, skip), [], name)


if __name__ == "__main__":
    unittest.main()
