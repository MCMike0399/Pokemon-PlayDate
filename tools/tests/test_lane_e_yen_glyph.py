#!/usr/bin/env python3
"""Charmap yen is tile 112, and the Earth Badge prize stays valid UTF-8.

Playdate json.decode turns \\u00a5 into byte 0xA5. utf8.len rejects that
byte, SourceText.expand aborts, and Giovanni's reward never saves the
badge. The prize and the Victory Road trainer name are stored as UTF-8.
TitleIdle.glyph maps yen to charmap $f0. Money figures that used to go
through gfx.drawText now go through GbFont, which draws that tile.
"""

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
YEN = "¥".encode()
E_ACUTE = "é".encode()


class YenGlyphTests(unittest.TestCase):
    def test_yen_maps_to_charmap_f0_tile_112(self):
        text = (ROOT / "Source/game/titleIdle.lua").read_text()
        self.assertIn('["¥"] = 0xf0 - 0x80', text)
        self.assertEqual(0xF0 - 0x80, 112)

    def test_prize_and_victory_road_name_are_utf8(self):
        play = (ROOT / "Source/data/endgame/play.json").read_bytes()
        story = (ROOT / "Source/data/endgame/story.json").read_bytes()
        self.assertNotIn(b"\\u00a5", play)
        self.assertNotIn(b"\\u00e9", story)
        self.assertIn(b"<PLAYER> got " + YEN + b"@", play)
        self.assertIn(b'"name": "POK' + E_ACUTE + b'MANIAC"', story)
        prize = json.loads(play)["texts"]["_MoneyForWinningText"]["recipe"][0]["text"]
        self.assertEqual(prize, "<PLAYER> got ¥@")
        self.assertEqual(prize.encode(), b"<PLAYER> got \xc2\xa5@")
        names = [
            row["name"]
            for row in json.loads(story)["victory_road"]["trainers"]
            if row.get("map_id") == "pokered:VICTORY_ROAD_2F" and row["name"].startswith("POK")
        ]
        self.assertEqual(names, ["POKéMANIAC"])
        expand = (ROOT / "Source/game/sourceText.lua").read_text()
        self.assertIn('utf8.len(text), "valid UTF-8 source text required"', expand)

    def test_money_figures_draw_with_the_gb_font(self):
        shop = (ROOT / "Source/game/shopState.lua").read_text()
        daycare = (ROOT / "Source/game/daycareState.lua").read_text()
        bicycle = (ROOT / "Source/game/kantoServices.lua").read_text()
        vending = (ROOT / "Source/game/celadonServicesController.lua").read_text()
        hall = (ROOT / "Source/game/endgameStory.lua").read_text()
        menu = (ROOT / "Source/ui/menu.lua").read_text()
        font = (ROOT / "Source/game/gbFont.lua").read_text()
        self.assertIn('GbFont.drawMoneyRight("¥"', shop)
        self.assertNotIn('"$"', shop)
        self.assertIn('GbFont.drawMoneyLine("¥"', daycare)
        self.assertIn('GbFont.drawMoneyLine("¥"', bicycle)
        self.assertIn('GbFont.drawMoneyLine("MONEY  ¥"', vending)
        self.assertIn("GbFont.drawMoneyLine(row.text, px, py)", hall)
        self.assertIn('option:find("¥", 1, true)', menu)
        self.assertIn("GbFont.drawMoneyLine(label, 0, 0)", menu)
        self.assertIn("function GbFont.drawMoneyLine", font)
        self.assertIn("GbFont.drawTight", font)
        for path in ("Source/game/pcState.lua", "Source/game/itemPCState.lua"):
            screen = (ROOT / path).read_text()
            self.assertNotIn("¥", screen)
            self.assertNotIn(":money()", screen)


if __name__ == "__main__":
    unittest.main()
