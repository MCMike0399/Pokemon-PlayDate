#!/usr/bin/env python3
"""Mart buy list against pokered af519899.

main 247d60a9 draws "POKE MART - BUY" and "A: Choose   B: Back" from
ShopState, and every clerk opens that one overlay. pokered's list
(home/list_menu.asm, engine/menus/text_box.asm DisplayMoneyBox, and
data/text_boxes.asm LIST_MENU_BOX / MONEY_BOX_TEMPLATE) has neither.

This fails until tools/notes/lane-e-mart-list-fidelity.patch is applied.
"""

import os
import shutil
import subprocess
import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
HOST = ROOT / "tools/tests/mart_list_host.lua"
FONT = ROOT / "Source/images/title/font/font.png"
EXTRA = ROOT / "Source/images/title/font/extra.png"


def lua_bin():
    if os.environ.get("LUA"):
        return os.environ["LUA"]
    bundled = "/tmp/lua-5.4.7/src/lua"
    if os.path.isfile(bundled):
        return bundled
    return shutil.which("lua") or bundled
POKERED = Path(os.environ.get("POKERED_REFERENCE_DIR", "/tmp/pokered"))


class MartListFidelityTests(unittest.TestCase):
    def test_every_mart_uses_the_pokered_list_and_money_box(self):
        shop = (ROOT / "Source/game/shopState.lua").read_text()
        self.assertNotIn(" - BUY", shop)
        self.assertNotIn(" - SELL", shop)
        self.assertNotIn("A: Choose   B: Back", shop)
        self.assertIn("drawPokeredList", shop)
        drawers = []
        for path in (ROOT / "Source").rglob("*.lua"):
            text = path.read_text(errors="ignore")
            if 'drawText("POKE MART"' in text or "drawPokeredList" in text:
                drawers.append(path.relative_to(ROOT).as_posix())
        self.assertEqual(drawers, ["Source/game/shopState.lua"])
        boxes = (POKERED / "data/text_boxes.asm").read_text()
        self.assertIn("LIST_MENU_BOX", boxes)
        self.assertIn("MONEY_BOX_TEMPLATE", boxes)
        completed = subprocess.run(
            [lua_bin(), str(HOST), str(ROOT)],
            cwd=ROOT, check=False, text=True, capture_output=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        self.assert_bcd_sources()
        self.assert_glyph_ink_stays_in_its_cell()
        self.assert_money_label_has_no_border_ink()

    def assert_bcd_sources(self):
        # home/print_bcd.asm PrintBCDNumber. Bit 7 set skips leading zeroes.
        # Bit 5 prints the yen immediately before the first nonzero digit.
        # Bits 0-4 are the byte length. LEFT_ALIGN (bit 6) is not set, so a
        # skipped zero leaves a space and the field stays right-aligned.
        bcd = (POKERED / "home/print_bcd.asm").read_text().splitlines()
        self.assertIn("do not print leading zeroes", bcd[4])  # line 5
        self.assertIn("print currency symbol", bcd[8])  # line 9
        self.assertIn("length of BCD number in bytes", bcd[10])  # line 11
        menu = (POKERED / "home/list_menu.asm").read_text().splitlines()
        # PrintListMenuEntries: name at (6, 4), price one row down and five
        # columns right, so the field starts at column 11.
        self.assertIn("hlcoord 6, 4", menu[363])  # line 364
        self.assertIn("SCREEN_WIDTH + 5", menu[420])  # line 421
        self.assertIn("3 | LEADING_ZEROES | MONEY_SIGN", menu[422])  # line 423
        money = (POKERED / "engine/menus/text_box.asm").read_text().splitlines()
        # DisplayMoneyBox prints the same flags at column 12.
        self.assertIn("hlcoord 12, 1", money[139])  # line 140
        self.assertIn("3 | LEADING_ZEROES | MONEY_SIGN", money[141])  # line 142
        boxes = (POKERED / "data/text_boxes.asm").read_text().splitlines()
        self.assertIn("MoneyText", boxes[34])  # line 35
        self.assertIn("13,  0", boxes[34])
        self.assertEqual(boxes[58].strip(), 'db "MONEY@"')  # line 59

    def fit(self):
        font = (ROOT / "Source/game/gbFont.lua").read_text()
        for line in font.splitlines():
            if line.startswith("GbFont.FIT"):
                return int(line.split("=")[1].strip())
        self.fail("GbFont.FIT is missing")

    def scaled(self, image, index, size, columns=16):
        sx = (index % columns) * 8
        sy = (index // columns) * 8
        ink = []
        for y in range(size):
            source_y = sy + (y * 8) // size
            for x in range(size):
                source_x = sx + (x * 8) // size
                if image.getpixel((source_x, source_y)) < 128:
                    ink.append((x, y))
        return ink

    def assert_glyph_ink_stays_in_its_cell(self):
        # The yen tile is charmap $f0, index 0xf0-0x80. It has ink on source
        # row 0, which letters leave empty, so a glyph parked on the top of
        # the cell draws that bar into the name row.
        sheet = Image.open(FONT).convert("L")
        fit = self.fit()
        cell_w, cell_h = 20, 13
        ox = (cell_w - fit) // 2
        oy = cell_h - fit
        yen = self.scaled(sheet, 0xF0 - 0x80, fit)
        letter = self.scaled(sheet, ord("E") - 65, fit)
        self.assertTrue(yen, "yen tile has ink")
        name_row, price_row = 4, 5
        name_bottom = max(oy + y for _, y in letter)
        yen_top = min(oy + y for _, y in yen)
        yen_bottom = max(oy + y for _, y in yen)
        self.assertGreaterEqual(yen_top, 0)
        self.assertLess(yen_bottom, cell_h)
        self.assertLess(name_bottom, cell_h)
        # Absolute rows: the yen's ink starts below the name's ink.
        name_abs = name_row * cell_h + name_bottom
        yen_abs = price_row * cell_h + yen_top
        self.assertGreater(yen_abs, name_abs, "yen ink enters the name row")
        for x, y in yen:
            self.assertGreaterEqual(ox + x, 0)
            self.assertLess(ox + x, cell_w)
            self.assertGreaterEqual(oy + y, 0)
            self.assertLess(oy + y, cell_h)

    def assert_money_label_has_no_border_ink(self):
        # data/text_boxes.asm draws MONEY on the top border. The border tile
        # is "─" (extra sheet 0x7a). Clearing the label span has to remove
        # that dash, including the gaps around each letter.
        extra = Image.open(EXTRA).convert("L")
        font = Image.open(FONT).convert("L")
        fit = self.fit()
        cell_w, cell_h = 20, 13
        ox = (cell_w - fit) // 2
        oy = cell_h - fit
        # tileImage scales 8px into the full 20 by 13 cell, one axis at a time.
        dash = []
        sx = ((0x7A - 0x60) % 16) * 8
        sy = ((0x7A - 0x60) // 16) * 8
        for y in range(cell_h):
            source_y = sy + (y * 8) // cell_h
            for x in range(cell_w):
                source_x = sx + (x * 8) // cell_w
                if extra.getpixel((source_x, source_y)) < 128:
                    dash.append((x, y))
        self.assertTrue(dash, "border dash has ink")
        letters = [self.scaled(font, ord(ch) - 65, fit) for ch in "MONEY"]
        for index, letter in enumerate(letters):
            covered = {(ox + x, oy + y) for x, y in letter}
            leftover = [pixel for pixel in dash if pixel not in covered]
            self.assertTrue(leftover, "letter %s hides the whole dash" % "MONEY"[index])
        shop = (ROOT / "Source/game/shopState.lua").read_text()
        clear_at = shop.find("paint.clears")
        draw_at = shop.find("drawFitString")
        self.assertGreater(clear_at, 0)
        self.assertGreater(draw_at, clear_at, "the label is cleared before the letters")


if __name__ == "__main__":
    unittest.main()
