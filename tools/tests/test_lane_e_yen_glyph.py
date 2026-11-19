#!/usr/bin/env python3
"""The yen tile is missing, and one money string is not valid UTF-8.

pret/pokered data/text/text_2.asm:869 is `<PLAYER> got ¥@`. The Blaine
prize is that page. Dialog draws it with GbFont, and TitleIdle.glyph has
no ¥ entry, so the tile is the blank space: "RED got  4653 for winning!".
Charmap yen is $f0. font.png stores that tile at index $f0-$80, which is
also sourceText.json tile 112.

Playdate json.decode turns \\u00a5 into the single byte 0xA5. A probe of
`{"t":"got \\u00a5@"}` returned bytes 67 6F 74 20 A5 40 and utf8.len nil.
Source/data/endgame/play.json stores the Giovanni prize that way, so
SourceText.expand crashes the reward event before the Earth Badge dialog
finishes. The same decoder turns \\u00e9 in the Victory Road name into
byte 0xE9. Other dialogue files already store the raw UTF-8 bytes.

Asheville has no U+00A5. Mart, bag, daycare, service, and Hall of Fame
money drawn with gfx.drawText drops the same character. The trainer card
prints MONEY/$. Pay Day already says "Coins scattered everywhere!" on the
hit. The amount page is `<PLAYER> picked up` / `¥@` / the total, and that
page has to use the tile font too.

This test fails until tools/notes/lane-e-yen-glyph.patch is applied.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-yen-glyph.patch"
YEN_TILE = '["¥"] = 0xf0 - 0x80'


def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


class LaneEYenGlyphTests(unittest.TestCase):
    def test_tile_font_maps_the_yen_glyph(self):
        source = read("Source/game/titleIdle.lua")
        self.assertIn(YEN_TILE, source)
        self.assertIn(YEN_TILE, PATCH.read_text(encoding="utf-8"))
        # Unknown glyphs fall through to the extra-font space, which is the
        # blank gap in "RED got  4653 for winning!".
        self.assertIn('return "extra", extra[" "]', source)

    def test_endgame_money_text_stays_utf8(self):
        play = read("Source/data/endgame/play.json")
        story = read("Source/data/endgame/story.json")
        self.assertNotIn("\\u00a5", play)
        self.assertIn("<PLAYER> got ¥@", play)
        self.assertNotIn("\\u00e9", story)
        self.assertIn('"name": "POKéMANIAC"', story)

    def test_money_screens_draw_the_yen_tile(self):
        self.assertIn(
            'GbFont.drawTight("MONEY/¥" .. session:inventory():money(), 32, 72)',
            read("Source/game/pauseState.lua"))
        self.assertIn(
            'GbFont.drawTight("¥" .. self.session:inventory():money(), 246, 27)',
            read("Source/game/kantoServices.lua"))
        self.assertIn(
            'GbFont.drawTight("MONEY  ¥" .. state.session:inventory():money(), 204, 8)',
            read("Source/game/celadonServicesController.lua"))
        self.assertIn(
            'GbFont.drawTight("¥" .. self.session:inventory():money(), 246, 27)',
            read("Source/game/daycareState.lua"))
        self.assertIn(
            'GbFont.drawTight("¥" .. self.game.session:inventory():money(), 286, 8)',
            read("Source/game/bagState.lua"))
        shop = read("Source/game/shopState.lua")
        self.assertIn('right("¥"..self:inventory():money(),382,14)', shop)
        self.assertIn('GbFont.drawTight(text, x - (utf8.len(text) or #text) * 16, y)', shop)
        self.assertIn('GbFont.drawTight(amount..". OK?",20,198)', shop)
        menu = read("Source/ui/menu.lua")
        self.assertIn('if yen then GbFont.drawTight(label, 0, 0) else gfx.drawText(label, 0, 0) end', menu)
        hall = read("Source/game/endgameStory.lua")
        self.assertIn(
            'if row.text:find("¥", 1, true) then GbFont.drawTight(row.text, px, py)',
            hall)
        self.assertIn('parts[#parts + 1] = "¥"', hall)

    def test_pay_day_amount_uses_the_yen_tile(self):
        battle = read("Source/battle/battle.lua")
        self.assertIn('self:say("Coins scattered everywhere!")', battle)
        self.assertIn('self:say(player .. " picked up\\n¥" .. coins .. "!")', battle)


if __name__ == "__main__":
    unittest.main()
