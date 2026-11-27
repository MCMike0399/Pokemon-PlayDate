#!/usr/bin/env python3
"""Hall of Fame card on the 20 by 13 pixel grid.

pret/pokered af519899 engine/movie/hall_of_fame.asm:

- line 60 hlcoord 2, 13, the HALL OF FAME box
- line 64 hlcoord 4, 15, the caption
- line 97 HoFShowMonOrPlayer
- line 99 hSCY $d0 during the back scroll
- line 101 hSCX $c0, then the front scroll starts at $a0
- line 115 the pic tiles stay at hlcoord 12, 5
- line 134 scroll the back pic left
- line 141 scroll the front pic right
- line 159 HoFDisplayMonInfo
- line 160 hlcoord 0, 2, the info box
- line 167 the name at hlcoord 1, 4
- line 171 PrintLevelCommon at hlcoord 8, 7
- line 175 PrintMonType at hlcoord 3, 9
- line 181 "LEVEL/"
- line 220 the player name at hlcoord 7, 2

tools/notes/lane-e-hall-of-fame-fidelity.patch draws those cells with
GbFont on the shared grid and clips the slide to the 160 by 144 LCD.
The checks fail on the unpatched tree.

test_every_info_and_red_row_keeps_its_own_cell covers the info-box rows
name, LEVEL/, level, TYPE1/, type 1, TYPE2/ and type 2, and the RED card
rows name, PLAY TIME, the time, MONEY, the amount, and both dex lines.
Each glyph's ink has to stay inside its own 20 by 13 cell, and rows on
the same card cannot share a pixel.
"""

import os
import subprocess
import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ASM = Path(os.environ.get("POKERED_REFERENCE_DIR", "/tmp/pokered")) / "engine/movie/hall_of_fame.asm"
LUA = os.environ.get("LUA") or "lua5.4"
COL, ROW = 20, 13

PROBE = r"""
json = {decodeFile = function() return {glyphs = {["é"] = {rows = {"........"}}}} end}
playdate = {graphics = {}}
dofile("Source/game/titleIdle.lua")
dofile("Source/game/sourceText.lua")
dofile("Source/game/endgameStory.lua")
local function cell(col, row)
    local x, y = EndgameStory.hallPixel(col * 8, row * 8)
    io.write(string.format("CELL %d %d %.4f %.4f\n", col, row, x, y))
end
local rows = EndgameStory.hallRows({kind = "pokemon", name = "CHARIZARD", level = 85,
    types = {"FIRE", "FLYING"}})
for _, row in ipairs(rows) do
    io.write(string.format("ROW|%s|%d|%d\n", row.text, row.col, row.row))
    cell(row.col, row.row)
end
local name = EndgameStory.playerHallRows({name = "RED", hours = 0, minutes = 0, money = 1234, seen = 0, owned = 0})
for _, row in ipairs(name) do
    io.write(string.format("PLAYER|%s|%d|%d\n", row.text, row.col, row.row))
end
local lineRow = 13
local page = EndgameStory.playerHallPages({seen = 0, owned = 0})[1].text
for line in (page .. "\n"):gmatch("(.-)\n") do
    if line ~= "" then
        io.write(string.format("DEX|%s|1|%d\n", line, lineRow))
        lineRow = lineRow + 1
    end
end
local box = EndgameStory.hallBoxes()
io.write(string.format("INFO %d %d %d %d\n", box.info.col, box.info.row, box.info.width, box.info.height))
io.write(string.format("CAPTION %d %d %d %d\n", box.caption.col, box.caption.row, box.caption.width, box.caption.height))
cell(0, 2)
local fx, fy = EndgameStory.hallPicOrigin(0xa0, 0x00)
io.write(string.format("FRONT %d %d\n", fx, fy))
local bx, by = EndgameStory.hallPicOrigin(0xc0, 0xd0)
io.write(string.format("BACK %d %d\n", bx, by))
local expanded = SourceText.expand("#MON HALL OF")
io.write("OAK " .. expanded .. "\n")
local seen = {}
local function emitGlyphs(text)
    local index = 1
    while index <= #text do
        local nextIndex = utf8.offset(text, 2, index) or (#text + 1)
        local ch = text:sub(index, nextIndex - 1)
        if ch ~= " " and ch ~= "\n" and not seen[ch] then
            seen[ch] = true
            local sheet, glyph = TitleIdle.glyph(ch)
            io.write("GLYPH|")
            io.write(ch)
            io.write(string.format("|%s|%d\n", sheet, glyph))
        end
        index = nextIndex
    end
end
for _, row in ipairs(rows) do emitGlyphs(row.text) end
for _, row in ipairs(name) do emitGlyphs(row.text) end
emitGlyphs(page)
emitGlyphs("HALL OF FAME")
"""


def run_probe():
    completed = subprocess.run(
        [LUA, "-e", PROBE], cwd=ROOT, check=False, capture_output=True, text=True)
    return completed


def paint(image, sheet_name, index, col, row, sheets):
    sheet = sheets[sheet_name]
    sx = (index % 16) * 8
    sy = (index // 16) * 8
    for y in range(ROW):
        source_y = sy + (y * 8) // ROW
        for x in range(COL):
            source_x = sx + (x * 8) // COL
            if sheet.getpixel((source_x, source_y)) < 128:
                px = col * COL + x
                py = row * ROW + y
                if 0 <= px < image.width and 0 <= py < image.height:
                    image.putpixel((px, py), 0)


def ink_box(image, x0, y0, x1, y1):
    return sum(
        image.getpixel((x, y)) < 128
        for y in range(max(0, y0), min(image.height, y1))
        for x in range(max(0, x0), min(image.width, x1))
    )


class HallOfFameFidelityTests(unittest.TestCase):
    def test_card_cells_match_the_asm_and_do_not_share_ink(self):
        lines = ASM.read_text(encoding="utf-8").splitlines()
        self.assertEqual(lines[59].strip(), "hlcoord 2, 13")
        self.assertEqual(lines[63].strip(), "hlcoord 4, 15")
        self.assertTrue(lines[96].startswith("HoFShowMonOrPlayer"))
        self.assertIn("$d0", lines[98])
        self.assertIn("$c0", lines[100])
        self.assertEqual(lines[114].strip(), "hlcoord 12, 5")
        self.assertIn("scroll back pic left", lines[133])
        self.assertIn("scroll front pic right", lines[140])
        self.assertTrue(lines[158].startswith("HoFDisplayMonInfo"))
        self.assertEqual(lines[159].strip(), "hlcoord 0, 2")
        self.assertEqual(lines[166].strip(), "hlcoord 1, 4")
        self.assertEqual(lines[170].strip(), "hlcoord 8, 7")
        self.assertEqual(lines[174].strip(), "hlcoord 3, 9")
        self.assertIn('"LEVEL/"', lines[180])
        self.assertEqual(lines[219].strip(), "hlcoord 7, 2")

        draw = (ROOT / "Source/game/endgameStory.lua").read_text(encoding="utf-8")
        photo = draw[draw.index("local function drawHallLine"):draw.index("function EndgameStory.drawOverlay")]
        self.assertIn("GbFont.drawString", photo)
        self.assertIn("drawHallLine(row.text, row.col, row.row)", photo)
        self.assertNotIn("getSystemFont", photo)
        self.assertNotIn("drawPokeredText", photo)

        completed = run_probe()
        self.assertEqual(completed.returncode, 0, completed.stderr)
        rows = {}
        cells = {}
        glyphs = {}
        front = back = info = None
        oak = None
        for line in completed.stdout.splitlines():
            if line.startswith("ROW|"):
                text, col, row = line.split("|")[1:]
                rows[text] = (int(col), int(row))
            elif line.startswith("CELL "):
                _, col, row, x, y = line.split()
                cells[(int(col), int(row))] = (float(x), float(y))
            elif line.startswith("PLAYER|"):
                text, col, row = line.split("|")[1:]
                if text == "RED":
                    self.assertEqual((int(col), int(row)), (7, 2))
                if text == "PLAY TIME":
                    self.assertEqual((int(col), int(row)), (1, 6))
                if ":" in text:
                    self.assertEqual((int(col), int(row)), (5, 7))
                    self.assertIn(":", text)
            elif line.startswith("INFO "):
                info = tuple(int(part) for part in line.split()[1:])
            elif line.startswith("FRONT "):
                front = tuple(int(part) for part in line.split()[1:])
            elif line.startswith("BACK "):
                back = tuple(int(part) for part in line.split()[1:])
            elif line.startswith("OAK "):
                oak = line.split(" ", 1)[1]
            elif line.startswith("GLYPH|"):
                _, char, sheet, index = line.split("|")
                glyphs[char] = (sheet, int(index))
        self.assertEqual(info, (0, 2, 12, 11))
        self.assertEqual(rows["CHARIZARD"], (1, 4))
        self.assertEqual(rows["LEVEL/"], (2, 6))
        self.assertEqual(rows["85"], (8, 7))
        self.assertEqual(rows["TYPE1/"], (2, 8))
        self.assertEqual(rows["FIRE"], (3, 9))
        self.assertEqual(rows["TYPE2/"], (2, 10))
        self.assertEqual(rows["FLYING"], (3, 11))
        self.assertEqual(oak, "POKéMON HALL OF")
        # The first front frame is off the right edge. The back frame at
        # hSCX $c0 is not pulled onto the left of the LCD.
        self.assertGreaterEqual(front[0], 160)
        self.assertGreaterEqual(back[0], 160)
        self.assertGreaterEqual(back[1], 0)
        self.assertLess(back[1] + 56, 160)

        top_x, top_y = cells[(0, 2)]
        self.assertEqual((top_x, top_y), (0, 2 * ROW))
        sheets = {
            "font": Image.open(ROOT / "Source/images/title/font/font.png").convert("L"),
            "extra": Image.open(ROOT / "Source/images/title/font/extra.png").convert("L"),
        }
        image = Image.new("L", (400, 240), 255)
        for label, (col, row) in rows.items():
            x, y = cells[(col, row)]
            self.assertEqual((x, y), (col * COL, row * ROW))
            for offset, char in enumerate(label):
                sheet, index = glyphs[char]
                paint(image, sheet, index, col + offset, row, sheets)
        # Neighboring info rows keep their own 13px band.
        bands = {
            "LEVEL/": ink_box(image, 0, 6 * ROW, 400, 7 * ROW),
            "85": ink_box(image, 0, 7 * ROW, 400, 8 * ROW),
            "TYPE1/": ink_box(image, 0, 8 * ROW, 400, 9 * ROW),
            "FIRE": ink_box(image, 0, 9 * ROW, 400, 10 * ROW),
            "TYPE2/": ink_box(image, 0, 10 * ROW, 400, 11 * ROW),
            "FLYING": ink_box(image, 0, 11 * ROW, 400, 12 * ROW),
        }
        for name, count in bands.items():
            self.assertGreater(count, 0, name)
        self.assertEqual(ink_box(image, 8 * COL, 6 * ROW, 10 * COL, 7 * ROW), 0)
        self.assertEqual(ink_box(image, 2 * COL, 7 * ROW, 8 * COL, 8 * ROW), 0)
        self.assertGreater(ink_box(image, 0, 4 * ROW, 12 * COL, 5 * ROW), 0)
        self.assertLess(4 * ROW + ROW, 240)

    def test_every_info_and_red_row_keeps_its_own_cell(self):
        # Each of these is one pokered tile row. At TitleIdle.ROW that is
        # 13px, and a glyph's ink stays inside that band and its own 20px
        # column. Rows may sit on adjacent tiles; they do not share pixels.
        completed = run_probe()
        self.assertEqual(completed.returncode, 0, completed.stderr)
        placed = []
        glyphs = {}
        for line in completed.stdout.splitlines():
            if line.startswith("ROW|") or line.startswith("PLAYER|") or line.startswith("DEX|"):
                kind, text, col, row = line.split("|")
                placed.append({"kind": kind, "text": text, "col": int(col), "row": int(row)})
            elif line.startswith("GLYPH|"):
                _, char, sheet, index = line.split("|")
                glyphs[char] = (sheet, int(index))
        by_text = {row["text"]: row for row in placed}
        expected = {
            "CHARIZARD": (1, 4),
            "LEVEL/": (2, 6),
            "85": (8, 7),
            "TYPE1/": (2, 8),
            "FIRE": (3, 9),
            "TYPE2/": (2, 10),
            "FLYING": (3, 11),
            "RED": (7, 2),
            "PLAY TIME": (1, 6),
            "MONEY": (1, 9),
        }
        for text, cell in expected.items():
            with self.subTest(cell=text):
                self.assertEqual((by_text[text]["col"], by_text[text]["row"]), cell)
        time_row = next(row for row in placed if row["kind"] == "PLAYER" and ":" in row["text"])
        money_row = next(row for row in placed if row["kind"] == "PLAYER" and "¥" in row["text"])
        dex_rows = [row for row in placed if row["kind"] == "DEX"]
        self.assertEqual((time_row["col"], time_row["row"]), (5, 7))
        self.assertEqual((money_row["col"], money_row["row"]), (4, 10))
        self.assertEqual([(row["col"], row["row"]) for row in dex_rows], [(1, 13), (1, 14)])
        info_rows = [by_text[text] for text in (
            "CHARIZARD", "LEVEL/", "85", "TYPE1/", "FIRE", "TYPE2/", "FLYING")]
        red_rows = [by_text["RED"], by_text["PLAY TIME"], time_row, by_text["MONEY"], money_row, *dex_rows]
        checked = info_rows + red_rows
        self.assertEqual(len(info_rows), 7)
        self.assertEqual(len(red_rows), 5 + len(dex_rows))

        source = (ROOT / "Source/game/endgameStory.lua").read_text(encoding="utf-8")
        photo_at = source.find("function EndgameStory.drawPhoto")
        overlay_at = source.find("function EndgameStory.drawOverlay")
        photo = source[photo_at:overlay_at]
        line_at = source.find("local function drawHallLine")
        line_fn = source[line_at:photo_at] if 0 <= line_at < photo_at else ""
        on_grid = (
            "GbFont.drawString" in line_fn
            and "drawHallLine(row.text, row.col, row.row)" in photo
            and "drawHallLine(line, 1, lineRow)" in photo
        )
        sheets = {
            "font": Image.open(ROOT / "Source/images/title/font/font.png").convert("L"),
            "extra": Image.open(ROOT / "Source/images/title/font/extra.png").convert("L"),
        }
        # The mon card and the RED card are separate screens, so a shared
        # tile coordinate across the two lists is not overlapping ink.
        for group in (info_rows, red_rows):
            self.assert_group_ink(group, on_grid, glyphs, sheets)

    def assert_group_ink(self, rows, on_grid, glyphs, sheets):
        owned = {}
        for row in rows:
            pixels = glyph_pixels(row["text"], row["col"], row["row"], on_grid, glyphs, sheets)
            with self.subTest(ink=row["text"]):
                self.assertGreater(len(pixels), 0, row["text"])
                for px, py, char_col in pixels:
                    self.assertEqual(py // ROW, row["row"], row["text"])
                    self.assertEqual(px // COL, char_col, row["text"])
                    self.assertGreaterEqual(py, row["row"] * ROW)
                    self.assertLess(py, (row["row"] + 1) * ROW)
                    self.assertGreaterEqual(px, char_col * COL)
                    self.assertLess(px, (char_col + 1) * COL)
                for px, py, _char_col in pixels:
                    previous = owned.get((px, py))
                    self.assertIsNone(previous, "%s shares a pixel with %s" % (row["text"], previous))
            for px, py, _char_col in pixels:
                owned[(px, py)] = row["text"]


def glyph_pixels(text, col, row, on_grid, glyphs, sheets):
    pixels = []
    cursor = 0
    index = 0
    raw = text.encode("utf-8")
    while index < len(raw):
        code = raw[index]
        if code < 128:
            char = chr(code)
            index += 1
        else:
            width = 2 if code < 224 else 3 if code < 240 else 4
            char = raw[index:index + width].decode("utf-8")
            index += width
        if char != " ":
            sheet_name, glyph = glyphs[char]
            ox = (col + cursor) * COL
            oy = row * ROW
            dw, dh = COL, ROW
            if not on_grid:
                # The unpatched card draws at the shifted 2x Game Boy origin.
                ox = 40 + (col + cursor) * 16
                oy = -48 + row * 16
                dw, dh = 16, 16
            pixels.extend(scaled_ink(sheets[sheet_name], glyph, ox, oy, dw, dh, col + cursor))
        cursor += 1
    return pixels


def scaled_ink(sheet, index, ox, oy, dw, dh, char_col):
    sx = (index % 16) * 8
    sy = (index // 16) * 8
    pixels = []
    for y in range(dh):
        source_y = sy + (y * 8) // dh
        for x in range(dw):
            source_x = sx + (x * 8) // dw
            if sheet.getpixel((source_x, source_y)) < 128:
                pixels.append((ox + x, oy + y, char_col))
    return pixels


if __name__ == "__main__":
    unittest.main()
