#!/usr/bin/env python3
"""A normal boot must not run postgameStory.

9abf8f7c adds a literal import in kantoScenes.lua. pdc compiles that file
into main.pdz and runs the chunk when kantoScenes loads, which is every
boot, including a continue that is not a Hall of Fame save. The chunk
calls PostgameStory.boot(). ensureRuntime then decodes
data/postgame/story.json and SourceEvents.registerEventSource retains the
event copy. On the host that boot keeps 81.7 KiB after a full collection.
The chunk with boot() removed keeps 37.1 KiB. The story file is 20,873
bytes and decodes to 42.1 KiB of tables. The variable call in
lateKantoStory.lua was already on ea32b553 and does not run the chunk.

Contract shards that copy a screen then fail with "not enough memory" or
copyImage out of memory. The runner writes contracts-<suite>:

- contracts-kanto-scenes
- contracts-field-moves
- contracts-grass-cut
- contracts-source-encounters

tools/notes/lane-e-hall-continue-lazy.patch loads the standalone pdz from
Continue only when the save is in the Hall and has a recorded team.
"""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
IMPORT = re.compile(r'^[ \t]*import "([^"]+)"', re.M)
MODULE = "game/postgameStory"


def source_file(name):
    path = ROOT / "Source" / (name + ".lua")
    return path if path.is_file() else None


def boot_imports():
    pending = ["main"]
    seen = set()
    found = set()
    while pending:
        name = pending.pop()
        if name in seen:
            continue
        seen.add(name)
        path = source_file(name)
        if path is None:
            continue
        text = path.read_text(encoding="utf-8")
        for imported in IMPORT.findall(text):
            found.add(imported)
            pending.append(imported)
    return found


class HallContinueMemoryTests(unittest.TestCase):
    def test_normal_boot_does_not_import_postgame_story(self):
        found = boot_imports()
        self.assertNotIn(
            MODULE, found,
            "kantoScenes imports postgameStory into main.pdz; boot retains the story table")

    def test_only_a_hall_save_loads_the_module(self):
        self.assertNotIn(MODULE, boot_imports())
        saves = (ROOT / "Source/game/saves.lua").read_text(encoding="utf-8")
        if "loadHallContinue" not in saves:
            # This tree never runs the chunk. A continue that is not
            # post-HoF does not decode the story.
            self.assertNotIn('import "game/postgameStory"', saves)
            return
        window = saves.split("local function loadHallContinue", 1)[1]
        window = window.split("local function continueGame", 1)[0]
        hall = window.find('zone_id ~= "pokered:HALL_OF_FAME"')
        teams = window.find("#teams < 1")
        run = window.find("file.run")
        self.assertGreaterEqual(hall, 0)
        self.assertGreaterEqual(teams, 0)
        self.assertGreater(run, hall)
        self.assertGreater(run, teams)
        call = saves.split("local loaded, why = loadHallContinue", 1)[1]
        call = call.split("installSession", 1)[0]
        self.assertIn("loaded == false", call)


if __name__ == "__main__":
    unittest.main()
