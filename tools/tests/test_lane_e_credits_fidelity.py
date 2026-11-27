#!/usr/bin/env python3
"""Credits scroll on the shared 20 by 13 pixel grid.

pret/pokered af519899 engine/movie/credits.asm:

- line 17 fills rows 0-3 black
- line 19 fills rows 14-17 black
- line 48 DisplayCreditsMon
- line 64 the pic is drawn at hlcoord 8, 6
- line 67 that tilemap is copied to vBGMap0+$c, so the pic starts at column 20
- line 78 FillMiddleOfScreenWithWhite before the scroll
- line 109 ScrollCreditsMonLeft steps SCX by 8 on the middle band only
- line 167 FillMiddleOfScreenWithWhite
- line 176 the next page clears the middle before placing new text
- line 180 that clear runs again at the start of every screen

The first card stays CredMon at column 6 and BLUE VERSION STAFF at column 1,
fully on the grid. A hold draws no mon, so a pic never rests clipped on the
left. tools/notes/lane-e-credits-fidelity.patch is the note. These checks
fail on the unpatched tree.
"""

import os
import subprocess
import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ASM = Path(os.environ.get("POKERED_REFERENCE_DIR", "/tmp/pokered")) / "engine/movie/credits.asm"
LUA = os.environ.get("LUA") or "lua5.4"
COL, ROW = 20, 13

PROBE = r"""
json = {decodeFile = function() return {glyphs = {["é"] = {rows = {"........"}}}} end}
playdate = {graphics = {}}
dofile("Source/game/titleIdle.lua")
dofile("Source/game/endgameStory.lua")
local function dump(tag, view)
    local cells = EndgameStory.creditsCells(view)
    local mon = cells.mon
    io.write(string.format("VIEW|%s|%d|%d|%s\n", tag, cells.shift, cells.window,
        mon and string.format("%d,%d", mon.col, mon.tiles) or "none"))
    for _, glyph in ipairs(cells.glyphs) do
        io.write(string.format("G|%s|%s|%d|%d\n", tag, glyph.char, glyph.col, glyph.row))
    end
end
dump("staff", {phase = "hold", lines = {"#MON", "BLUE VERSION STAFF"}, mon = "venusaur"})
dump("design0", {phase = "scroll", scroll = 0, lines = {"CHARACTER DESIGN", "KEN SUGIMORI", "ATSUKO NISHIDA"}, mon = "fearow"})
dump("design8", {phase = "scroll", scroll = 8, lines = {"CHARACTER DESIGN", "KEN SUGIMORI", "ATSUKO NISHIDA"}, mon = "fearow"})
dump("rest", {phase = "hold", lines = {"MUSIC", "JUNICHI MASUDA"}, mon = "fearow"})
dump("last", {phase = "scroll", scroll = 27, lines = {"CHARACTER DESIGN"}, mon = "fearow"})
dump("end", {phase = "hold", ending = true})
local bands = EndgameStory.creditsBands()
io.write(string.format("BAND|%d|%d|%d|%d|%d\n", bands.top.y, bands.top.h, bands.middle.y, bands.middle.h, bands.bottom.y))
local sheet, glyph = TitleIdle.glyph("é")
io.write(string.format("ACCENT|%s|%d\n", sheet, glyph))
local early = EndgameStory.creditsScroll(4)
local late = EndgameStory.creditsScroll(12)
io.write(string.format("WIN|%d|%d\n", early.windowGb, late.windowGb))
"""


def glyph_table():
    completed = subprocess.run(
        [LUA, "-e", r"""
dofile("Source/game/titleIdle.lua")
local chars = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789é/"
local index = 1
while index <= #chars do
    local nextIndex, sheet, glyph = TitleIdle.nextTile(chars, index)
    io.write(chars:sub(index, nextIndex - 1), "|", sheet, "|", glyph, "\n")
    index = nextIndex
end
"""],
        cwd=ROOT, check=False, capture_output=True, text=True)
    table = {}
    for line in completed.stdout.splitlines():
        char, sheet, index = line.split("|")
        table[char] = (sheet, int(index))
    return table


def paint(image, sheets, table, char, col, row):
    if col < 0 or col >= 20 or char not in table:
        return
    sheet_name, index = table[char]
    sheet = sheets[sheet_name]
    sx = (index % 16) * 8
    sy = (index // 16) * 8
    for y in range(ROW):
        for x in range(COL):
            if sheet.getpixel((sx + (x * 8) // COL, sy + (y * 8) // ROW)) < 128:
                image.putpixel((col * COL + x, row * ROW + y), 0)


class CreditsFidelityTests(unittest.TestCase):
    def test_scroll_moves_whole_glyphs_and_the_first_card_stays_on_the_grid(self):
        lines = ASM.read_text(encoding="utf-8").splitlines()
        self.assertEqual(lines[16].strip(), "hlcoord 0, 0")
        self.assertEqual(lines[18].strip(), "hlcoord 0, 14")
        self.assertTrue(lines[47].startswith("DisplayCreditsMon"))
        self.assertEqual(lines[63].strip(), "hlcoord 8, 6")
        self.assertIn("vBGMap0 + $c", lines[66])
        self.assertIn("FillMiddleOfScreenWithWhite", lines[77])
        self.assertTrue(lines[108].startswith("ScrollCreditsMonLeft"))
        self.assertTrue(lines[166].startswith("FillMiddleOfScreenWithWhite"))
        self.assertIn(".nextCreditsScreen", lines[175])
        self.assertIn("FillMiddleOfScreenWithWhite", lines[179])

        story = (ROOT / "Source/game/creditsDraw.lua").read_text(encoding="utf-8")
        body = story[story.index("local function drawGlyph"):]
        self.assertIn("GbFont.drawString", body)
        self.assertIn("drawGlyph(gfx, glyph.char, glyph.col, glyph.row, cells.window)", body)
        self.assertNotIn("getSystemFont", body)
        self.assertNotIn("drawPokeredText", body)
        self.assertIn("©'95.'96.'98 Nintendo", story)
        self.assertIn("©'95.'96.'98 Creatures inc.", story)
        self.assertIn("©'95.'96.'98 GAME FREAK inc.", story)
        self.assertIn('"THE END"', story)
        self.assertIn('row:sub(col, col) ~= "."', story)

        completed = subprocess.run(
            [LUA, "-e", PROBE], cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        views = {}
        glyphs = {}
        for line in completed.stdout.splitlines():
            if line.startswith("VIEW|"):
                _, tag, shift, window, mon = line.split("|")
                views[tag] = {"shift": int(shift), "window": int(window), "mon": mon}
            elif line.startswith("G|"):
                _, tag, char, col, row = line.split("|")
                glyphs.setdefault(tag, []).append((char, int(col), int(row)))
            elif line.startswith("BAND|"):
                top_y, top_h, mid_y, mid_h, bot_y = (int(part) for part in line.split("|")[1:])
                self.assertEqual((top_y, top_h, mid_y, mid_h, bot_y), (0, 4 * ROW, 4 * ROW, 10 * ROW, 14 * ROW))
            elif line.startswith("ACCENT|"):
                _, sheet, index = line.split("|")
                self.assertEqual((sheet, int(index)), ("font", 0xBA - 0x80))
            elif line.startswith("WIN|"):
                early, late = (int(part) for part in line.split("|")[1:])
                self.assertEqual(early, 160)
                self.assertEqual(late, 120)

        staff = glyphs["staff"]
        text = "".join(char for char, _, row in staff if row == 6)
        version = "".join(char for char, _, row in staff if row == 8)
        self.assertEqual(text, "POKéMON")
        self.assertEqual(version, "BLUE VERSION STAFF")
        self.assertTrue(all(0 <= col < 20 for _, col, _ in staff))
        self.assertEqual(min(col for _, col, row in staff if row == 8), 1)
        self.assertEqual(views["staff"]["mon"], "none")
        self.assertEqual(views["staff"]["shift"], 0)

        # ScrollCreditsMonLeft moves the text with the mon. The letters do
        # not stay put while a clip eats them from the left.
        self.assertEqual(views["design0"]["mon"], "20,7")
        self.assertEqual(views["design8"]["shift"], 8)
        self.assertEqual(int(views["design8"]["mon"].split(",")[0]), 12)
        self.assertEqual(len(glyphs["design0"]), len(glyphs["design8"]))
        for before, after in zip(glyphs["design0"], glyphs["design8"]):
            self.assertEqual(after[0], before[0])
            self.assertEqual(after[2], before[2])
            self.assertEqual(after[1], before[1] - 8)

        # A page at rest never keeps the previous pic, even partly off screen.
        self.assertEqual(views["rest"]["mon"], "none")
        self.assertLess(int(views["last"]["mon"].split(",")[0]), 0)
        self.assertEqual(views["last"]["shift"], 26)
        ending = "".join(char for char, _, _ in glyphs["end"])
        self.assertEqual(ending, "THE END")
        self.assertTrue(all(col >= 4 for _, col, _ in glyphs["end"]))

        sheets = {
            "font": Image.open(ROOT / "Source/images/title/font/font.png").convert("L"),
            "extra": Image.open(ROOT / "Source/images/title/font/extra.png").convert("L"),
        }
        table = glyph_table()
        card = Image.new("L", (400, 240), 255)
        for char, col, row in staff:
            paint(card, sheets, table, char, col, row)
        self.assertGreater(sum(pixel < 128 for pixel in card.tobytes()), 0)
        # Nothing of the first card is clipped by the left edge, and the
        # staff line's first glyph occupies column 1.
        self.assertGreater(sum(card.getpixel((x, 8 * ROW + 4)) < 128 for x in range(COL, 2 * COL)), 0)
        self.assertEqual(sum(card.getpixel((x, y)) < 128 for y in range(6 * ROW, 7 * ROW) for x in range(COL)), 0)


if __name__ == "__main__":
    unittest.main()
