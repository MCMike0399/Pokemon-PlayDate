"""Hall of Fame credits fidelity against pokered af519899.

BlueBot accepted the name box and the '#' to POKé mapping. These checks
are the four reds on the 57499214 frames. They fail until
tools/notes/lane-e-hof-credits-fidelity.patch is applied.

1. Whole-string advances stay on the system font. A per-glyph draw drops
   the space and the colon.
2. é is font.png char $BA from the font generator, one 8px cell, the same
   height as the other lowercase letters.
3. Rows 0-3 and 14-17 are black. The middle is white and the text is black.
4. The credits mon is a black silhouette. The window hides the text that
   would wrap in on the right.
"""

import json
import os
import subprocess
import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-hof-credits-fidelity.patch"
SHADES = ROOT / "Source/data/endgame/creditsMonShades.json"
POKERED = Path(os.environ.get("POKERED", "/tmp/pokered"))
LUA = os.environ.get("LUA") or "/tmp/lua-5.4.7/src/lua"

FONT = r"""
local function measure(self, text)
    if #text <= 1 then return 0 end
    return #text * 5
end
local font = {
    getTextWidth = measure,
    getHeight = function() return 16 end,
    getLeading = function() return 0 end,
}
"""

PROBE = FONT + r"""
json = {decodeFile = function() return {glyphs = {["é"] = {rows = {"..##...."}}}} end}
playdate = {graphics = {}}
dofile("Source/game/endgameStory.lua")
local glyphs = {}
for code = 32, 126 do
    local char = string.char(code)
    glyphs[#glyphs + 1] = char
end
glyphs[#glyphs + 1] = "é"
local function sandwich(char)
    return font:getTextWidth("X" .. (char == "é" and "e" or char) .. "X") - font:getTextWidth("XX")
end
for _, char in ipairs(glyphs) do
    local got = EndgameStory.glyphAdvance(font, char)
    local expected = sandwich(char)
    assert(got == expected, char .. " advance " .. tostring(got) .. " != " .. tostring(expected))
end
assert(EndgameStory.glyphAdvance(font, ":") > 0)
assert(EndgameStory.textWidth(font, "You still have") == font:getTextWidth("You still have"))
assert(EndgameStory.textWidth(font, "PLAY TIME") == font:getTextWidth("PLAY TIME"))
assert(EndgameStory.textWidth(font, "0:00") == font:getTextWidth("0:00"))
assert(EndgameStory.textWidth(font, "#MON") == font:getTextWidth("POKEMON"))
local caption = EndgameStory.creditsCaption({lines = {"#MON", "BLUE VERSION STAFF"}, mon = "venusaur"})
assert(caption == "POKéMON\nBLUE VERSION STAFF", caption)
assert(not caption:find("venusaur", 1, true))
local bands = EndgameStory.creditsBands()
assert(bands.top.y == 0 and bands.top.h == 16, "top")
assert(bands.middle.y == 16 and bands.middle.h == 160, "middle")
assert(bands.bottom.y == 176 and bands.bottom.h == 64, "bottom")
assert(bands.text == "black")
local early = EndgameStory.creditsScroll(4)
assert(early.windowGb == 160 and early.dx == -64, "early window")
local late = EndgameStory.creditsScroll(12)
assert(late.windowGb == 120, late.windowGb)
local place = EndgameStory.creditsMonPlace(0)
assert(place.gbX == 64 and place.gbY == 48)
local staff = EndgameStory.creditsLine("#MON", 1, "text")
assert(staff.col == 6 and staff.row == 6, "mon line")
local notice = EndgameStory.creditsLine("©'95.'96.'98 Nintendo", 1, "copyright")
assert(notice.col == 2 and notice.row == 7, "copyright line")
assert(EndgameStory.accentCell() == 8)
io.write("fidelity-ok")
"""


def _pad(image):
    """LoadUncompressedSpriteData centers the pic in the 7x7 tile box."""
    width, height = image.size
    tiles_wide, tiles_high = width // 8, height // 8
    origin_x = ((8 - tiles_wide) // 2) * 8
    origin_y = (7 - tiles_high) * 8
    canvas = Image.new("RGB", (56, 56), (255, 255, 255))
    canvas.paste(image.convert("RGB"), (origin_x, origin_y))
    return canvas


def _shade(pixel):
    red = pixel[0]
    if red > 200:
        return "."
    if red > 140:
        return "1"
    if red > 40:
        return "2"
    return "#"


class HallOfFameCreditsFidelityTests(unittest.TestCase):
    def test_player_name_box_matches_hof_display_player_stats(self):
        asm = (POKERED / "engine/movie/hall_of_fame.asm").read_text()
        body = asm.split("HoFDisplayPlayerStats:", 1)[1].split("HoFPrintTextAndDelay:", 1)[0]
        self.assertIn("hlcoord 5, 0", body)
        self.assertIn("ld b, 2", body)
        self.assertIn("ld c, 9", body)
        self.assertIn("hlcoord 7, 2", body)
        completed = subprocess.run(
            [LUA, "-e", r"""
json = {decodeFile = function() return {} end}
playdate = {graphics = {}}
dofile("Source/game/endgameStory.lua")
local box = EndgameStory.hallBoxes().playerName
local _, top = EndgameStory.hallPixel(box.col * 8, box.row * 8)
local name = EndgameStory.playerHallRows({name = "RED"})[1]
local _, nameY = EndgameStory.hallPixel(name.col * 8, name.row * 8)
local _, asmY = EndgameStory.hallPixel(7 * 8, 2 * 8)
io.write(box.col, " ", box.row, " ", box.width, " ", box.height, " ", top, " ", name.col, " ", name.row, " ", nameY, " ", asmY)
"""],
            cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        col, row, width, height, top, name_col, name_row, name_y, asm_y = completed.stdout.split()
        self.assertEqual((col, row, width, height), ("5", "0", "11", "4"))
        self.assertEqual(top, "-48")
        self.assertEqual((name_col, asm_y), ("7", "-16"))
        self.assertEqual(name_row, "3")
        self.assertGreaterEqual(int(name_y), 0)

    def test_glyph_advances_match_the_font_and_the_colon_renders(self):
        mapping = subprocess.run(
            [LUA, "-e", r"""
json = {decodeFile = function() return {} end}
playdate = {graphics = {}}
dofile("Source/game/titleIdle.lua")
local chars = {" ", ":", "0", "A", "e", "é", "©"}
for _, char in ipairs(chars) do
    local sheet, glyph = TitleIdle.glyph(char)
    io.write(char, "=", sheet or "", ":", tostring(glyph), "\n")
end
"""],
            cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertEqual(mapping.returncode, 0, mapping.stderr)
        before = mapping.stdout
        patch = PATCH.read_text()
        self.assertNotIn("Source/game/titleIdle.lua", patch)
        self.assertNotIn("Source/game/gbFont.lua", patch)
        self.assertNotIn("Source/data/sourceText.json", patch)
        completed = subprocess.run(
            [LUA, "-e", PROBE], cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        self.assertIn("fidelity-ok", completed.stdout)
        after = subprocess.run(
            [LUA, "-e", r"""
json = {decodeFile = function() return {} end}
playdate = {graphics = {}}
dofile("Source/game/titleIdle.lua")
local chars = {" ", ":", "0", "A", "e", "é", "©"}
for _, char in ipairs(chars) do
    local sheet, glyph = TitleIdle.glyph(char)
    io.write(char, "=", sheet or "", ":", tostring(glyph), "\n")
end
"""],
            cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertEqual(after.stdout, before)

    def test_accent_is_the_generator_lowercase_cell(self):
        from tools.generate_source_text import build
        rows = build()["glyphs"]["é"]["rows"]
        self.assertEqual(len(rows), 8)
        self.assertTrue(all(len(row) == 8 for row in rows))
        story = (ROOT / "Source/game/endgameStory.lua").read_text()
        self.assertTrue("function EndgameStory.accentCell" in story, "accentCell is missing, so é is not the 8px generator cell")
        self.assertTrue("data/sourceText.json" in story, "é rows are not loaded from the font generator pin")
        self.assertNotIn("accentERows", story)
        self.assertNotIn("(col - 1) * 2", story)
        completed = subprocess.run(
            [LUA, "-e", r"""
json = {decodeFile = function(path)
    assert(path == "data/sourceText.json", path)
    return {glyphs = {["é"] = {rows = {"FROM-GENERATOR"}}}}
end}
playdate = {graphics = {}}
dofile("Source/game/endgameStory.lua")
assert(EndgameStory.accentCell() == 8)
io.write(EndgameStory.accentRows()[1])
"""],
            cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertEqual(completed.stdout, "FROM-GENERATOR")
        pinned = json.loads((ROOT / "Source/data/sourceText.json").read_text())["glyphs"]["é"]["rows"]
        self.assertEqual(pinned, rows)

    def test_credits_bands_are_black_and_the_text_is_black(self):
        draw = (ROOT / "Source/game/eventState.lua").read_text()
        start = draw.index("local view = CreditsPlayer.view(self.credits)")
        block = draw[start:draw.index("gfx.popContext()", start)]
        self.assertIn("EndgameStory.drawCredits", block)
        self.assertNotIn("kDrawModeFillWhite", block)
        story = (ROOT / "Source/game/endgameStory.lua").read_text()
        body = story[story.index("function EndgameStory.drawCredits("):]
        self.assertIn("kColorBlack", body)
        self.assertNotIn("kDrawModeFillWhite", body)
        completed = subprocess.run(
            [LUA, "-e", PROBE], cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)

    def test_credits_mon_is_a_silhouette_and_the_window_hides_the_text(self):
        story = (ROOT / "Source/game/endgameStory.lua").read_text()
        self.assertTrue("function EndgameStory.drawCreditsMon" in story, "drawCreditsMon is missing, so the credits pic is not a silhouette")
        image = story.index("function EndgameStory.drawCreditsMon")
        body = story[image:story.index("function EndgameStory.drawCredits(", image)]
        self.assertNotIn("Shade.LIGHT", body)
        self.assertNotIn("Shade.DARK", body)
        self.assertIn('row:sub(col, col) ~= "."', body)
        self.assertIn("windowX", body)
        draw = (ROOT / "Source/game/eventState.lua").read_text()
        start = draw.index("local view = CreditsPlayer.view(self.credits)")
        block = draw[start:draw.index("gfx.popContext()", start)]
        self.assertNotIn(".. view.mon", block)
        self.assertTrue(SHADES.is_file(), "credits mon shade grids are missing")
        grids = json.loads(SHADES.read_text())
        self.assertEqual(grids["source_revision"], "af519899719f0754965776faac0e836a3b906e6d")
        for species in ("venusaur", "fearow", "parasect", "abra"):
            source = _pad(Image.open(POKERED / "gfx/pokemon/front" / f"{species}.png"))
            rows = grids["mons"][species]
            self.assertEqual(len(rows), 56, species)
            for y in (0, 8, 27, 55):
                expected = "".join(_shade(source.getpixel((x, y))) for x in range(56))
                self.assertEqual(rows[y], expected, f"{species} row {y}")
        completed = subprocess.run(
            [LUA, "-e", PROBE], cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)

    def test_patch_is_the_unapplied_fix(self):
        patch = PATCH.read_text()
        self.assertIn("drawCredits", patch)
        self.assertIn("accentCell", patch)
        self.assertIn("windowGb", patch)
        self.assertNotIn("Shade.set(Shade.LIGHT)", patch)


if __name__ == "__main__":
    unittest.main()
