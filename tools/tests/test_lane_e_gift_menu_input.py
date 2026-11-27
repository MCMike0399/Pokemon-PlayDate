#!/usr/bin/env python3
"""The Cerulean Cave gift menu has to take A.

Mew is not an object in pokered data/maps/objects/CeruleanCave1F.asm
(af519899). PostgameStory.presentGift shows MEW and LINK CABLE on the
event menu. EventState only feeds that menu during heal-confirm, so the
talk stays on the event and the gift flag never flips. MallocPoolSize
stays 16645684. No skip.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def function_body(text, name):
    start = text.split("function " + name, 1)[1]
    return start.split("\nfunction ", 1)[0]


class GiftMenuInputTests(unittest.TestCase):
    def test_event_menu_takes_buttons_outside_heal_confirm(self):
        text = (ROOT / "Source/game/eventState.lua").read_text(encoding="utf-8")
        story = (ROOT / "Source/game/postgameStory.lua").read_text(encoding="utf-8")
        self.assertIn('state.menu:show({"MEW", "LINK CABLE"}', story)
        handle = function_body(text, "EventState:handleInput()")
        draw = function_body(text, "EventState:draw()")
        self.assertIn("self.menu:handleInput()", handle)
        self.assertIn('self.phase~="heal-confirm"', handle)
        self.assertIn("self.menu:draw", draw)
        self.assertGreater(draw.count("self.menu:draw"), 1)


if __name__ == "__main__":
    unittest.main()
