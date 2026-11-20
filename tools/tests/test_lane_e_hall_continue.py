#!/usr/bin/env python3
"""A Hall of Fame continue must retry the Pallet relocation after boot.

postgameStory.boot() calls installContinue when the file loads. On the
simulator that load is already cached before KantoScenes.install, and the
continue wrapper is not installed. Continue of sequence 417 stayed in
pokered:HALL_OF_FAME (5, 2) instead of Pallet Town (5, 6) facing down.
tools/notes/lane-e-hall-continue.patch.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class HallContinueTests(unittest.TestCase):
    def test_scene_install_retries_the_postgame_continue_wrap(self):
        source = (ROOT / "Source/game/kantoScenes.lua").read_text(encoding="utf-8")
        window = source.split("function KantoScenes.install()", 1)[1]
        window = window.split("installed = true", 1)[0]
        self.assertIn("PostgameStory.ensureRuntime()", window)


if __name__ == "__main__":
    unittest.main()
