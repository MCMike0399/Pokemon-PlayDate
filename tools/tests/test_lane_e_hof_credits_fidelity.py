"""Hall of Fame credits fidelity against pokered af519899.

engine/movie/credits.asm scrolls the next CreditsMons front pic. It does
not print the species name. constants/charmap.asm maps '#' to POKé, and
the é tile is gfx/font/font.png tile 58. DisplayCreditsMon starts that
pic at hlcoord 8, 6 and ScrollCreditsMonLeft steps one tile left.

HoFDisplayPlayerStats draws the name box with TextBoxBorder at hlcoord
5, 0, b=2, c=9, and the name at hlcoord 7, 2. The hall view puts that
top row at Playdate y=-48, so a border that appears to start at y=0 is
the clip. These checks fail until
tools/notes/lane-e-hof-credits-fidelity.patch is applied.
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

PROBE = r"""
json = {decodeFile = function() return {} end}
playdate = {graphics = {}}
dofile("Source/game/endgameStory.lua")
assert(EndgameStory.expandPokeredText("#MON") == "POKéMON", EndgameStory.expandPokeredText("#MON"))
assert(EndgameStory.expandPokeredText("your #DEX") == "your POKéDEX")
local caption = EndgameStory.creditsCaption({
    lines = {"#MON", "BLUE VERSION STAFF"}, mon = "venusaur",
})
assert(caption == "POKéMON\nBLUE VERSION STAFF", caption)
assert(not caption:find("venusaur", 1, true))
local notice = EndgameStory.creditsCaption({lines = {}, mon = "parasect", copyright = true})
assert(notice:find("GAME FREAK inc.", 1, true), notice)
assert(not notice:find("parasect", 1, true))
assert(EndgameStory.creditsCaption({ending = true, mon = "parasect"}) == "THE END")
local place = EndgameStory.creditsMonPlace(0)
assert(place.gbX == 64 and place.gbY == 48, tostring(place.gbX))
assert(place.x == 168 and place.y == 48, tostring(place.x) .. "," .. tostring(place.y))
local moved = EndgameStory.creditsMonPlace(4)
assert(moved.gbX == 32 and moved.x == 104, tostring(moved.gbX))
io.write(table.concat(EndgameStory.accentERows, "\n"))
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
        # Row 2 is above the clip. The drawn row stays on the first visible line.
        self.assertEqual(name_row, "3")
        self.assertGreaterEqual(int(name_y), 0)

    def test_credits_text_is_poke_and_not_the_species_name(self):
        completed = subprocess.run(
            [LUA, "-e", PROBE], cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        glyph = json.loads((ROOT / "Source/data/sourceText.json").read_text())["glyphs"]["é"]["rows"]
        self.assertEqual(completed.stdout, "\n".join(glyph))

    def test_credits_draw_scrolls_a_shaded_front_sprite(self):
        draw = (ROOT / "Source/game/eventState.lua").read_text()
        start = draw.index("local view = CreditsPlayer.view(self.credits)")
        block = draw[start:draw.index("gfx.popContext()", start)]
        self.assertIn("EndgameStory.creditsCaption", block)
        self.assertIn("EndgameStory.drawCreditsMon", block)
        self.assertNotIn(".. view.mon", block)
        story = (ROOT / "Source/game/endgameStory.lua").read_text()
        image = story.index("function EndgameStory.creditsMonImage")
        body = story[image:story.index("function EndgameStory.drawCreditsMon", image)]
        self.assertIn("Shade.set(Shade.LIGHT)", body)
        self.assertIn("Shade.set(Shade.DARK)", body)
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

    def test_patch_is_the_unapplied_fix(self):
        patch = PATCH.read_text()
        self.assertIn("creditsCaption", patch)
        self.assertIn("Shade.LIGHT", patch)
        self.assertIn("POKé", patch)
        self.assertIn("creditsMonShades.json", patch)


if __name__ == "__main__":
    unittest.main()
