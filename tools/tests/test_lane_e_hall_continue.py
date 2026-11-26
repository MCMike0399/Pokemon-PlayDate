#!/usr/bin/env python3
"""A Hall continue loads postgameStory while GameSaves already exists.

boot() installs the Pallet wrapper at that load. KantoScenes.install does
not call ensureRuntime, so a normal field boot does not decode the story.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class HallContinueTests(unittest.TestCase):
    def test_field_install_leaves_the_continue_wrap_to_the_hall_load(self):
        source = (ROOT / "Source/game/kantoScenes.lua").read_text(encoding="utf-8")
        window = source.split("function KantoScenes.install()", 1)[1]
        window = window.split("installed = true", 1)[0]
        self.assertNotIn("ensureRuntime", window)
        saves = (ROOT / "Source/game/saves.lua").read_text(encoding="utf-8")
        loader = saves.split("local function loadHallContinue", 1)[1]
        loader = loader.split("local function continueGame", 1)[0]
        self.assertLess(loader.find('zone_id ~= "pokered:HALL_OF_FAME"'), loader.find("file.run"))
        self.assertLess(loader.find("#teams < 1"), loader.find("file.run"))
        self.assertIn('"postgameStory"', loader)


if __name__ == "__main__":
    unittest.main()
