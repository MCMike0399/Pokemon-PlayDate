"""Postgame hooks after the Hall continue lands in Pallet.

A fresh switchZone("kanto_cerulean_city") on ea32b553, 540d5adb and
d010ec62 entered the city at (4, 13). That inflate failure does not
reproduce on those device builds, so the pool stays 16645684 and
switchZone still goes through WorldDeltas.ensureZone.

The Mew gift and Mewtwo talks were unimplemented because postgameStory
ran only while the save zone was still pokered:HALL_OF_FAME. A later
continue already in Pallet, with a recorded Hall team, loads the same
standalone chunk. The boot import stays gone.
"""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
IMPORT = re.compile(r'^[ \t]*import "([^"]+)"', re.M)


def boot_imports():
    pending = ["main"]
    seen = set()
    found = set()
    while pending:
        name = pending.pop()
        if name in seen:
            continue
        seen.add(name)
        path = ROOT / "Source" / (name + ".lua")
        if not path.is_file():
            continue
        for imported in IMPORT.findall(path.read_text(encoding="utf-8")):
            found.add(imported)
            pending.append(imported)
    return found


class LaneEPostgameAfterContinueTests(unittest.TestCase):
    def test_mew_gift_talk_starts_the_gift(self):
        postgame = (ROOT / "Source/game/postgameStory.lua").read_text(encoding="utf-8")
        story = (ROOT / "Source/data/postgame/story.json").read_text(encoding="utf-8")
        world = (ROOT / "Source/game/kantoWorld.lua").read_text(encoding="utf-8")
        hook = world.split("function KantoWorld.tryInteract", 1)[1]
        self.assertIn("function PostgameStory.tryGift", postgame)
        self.assertIn("pokered:CERULEAN_CAVE_1F:script:mew-gift", story)
        self.assertLess(hook.find('worldHook("interact"'), hook.find("unimplemented-source-event"))
        self.assertIn("postgame:CERULEAN_CAVE_1F:mew-gift", story)

    def test_mewtwo_talk_starts_the_battle(self):
        story = (ROOT / "Source/data/postgame/story.json").read_text(encoding="utf-8")
        postgame = (ROOT / "Source/game/postgameStory.lua").read_text(encoding="utf-8")
        saves = (ROOT / "Source/game/saves.lua").read_text(encoding="utf-8")
        self.assertIn("pokered:CERULEAN_CAVE_B1F:objects:1", story)
        self.assertIn("addStatic(data.cave.mewtwo)", postgame)
        window = saves.split("local function loadHallContinue", 1)[1]
        window = window.split("local function continueGame", 1)[0]
        self.assertIn("not hasTeam", window)
        self.assertLess(window.find("not hasTeam"), window.find("file.run"))

    def test_cerulean_city_inflates_in_the_pinned_pool(self):
        zone = (ROOT / "Source/world/zone.lua").read_text(encoding="utf-8")
        body = zone.split("function switchZone(key)", 1)[1].split("\nfunction ", 1)[0]
        self.assertIn("WorldDeltas.ensureZone", body)
        self.assertNotIn("game/postgameStory", boot_imports())
        saves = (ROOT / "Source/game/saves.lua").read_text(encoding="utf-8")
        self.assertNotIn('import "game/postgameStory"', saves)


if __name__ == "__main__":
    unittest.main()
