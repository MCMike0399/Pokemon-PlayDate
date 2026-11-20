"""Lane E tip d010ec62 after the Hall continue lands in Pallet (5, 6).

The gift and Mewtwo talks and the Cerulean City load were checked in the
Simulator. These tests stay red, with no skip and no expected failure,
until that tip is rerun and the three blocks below are gone.
MallocPoolSize stays 16645684. The patches are notes only.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
E_TIP = "d010ec62678d53f41e33e2d83ba1fe946d310fa4"


class LaneEPostgameAfterContinueTests(unittest.TestCase):
    def test_mew_gift_talk_starts_the_gift(self):
        postgame = (ROOT / "Source/game/postgameStory.lua").read_text()
        world = (ROOT / "Source/game/kantoWorld.lua").read_text()
        hook = world.split("function KantoWorld.tryInteract", 1)[1]
        self.assertIn("function PostgameStory.tryGift", postgame)
        self.assertLess(hook.find('worldHook("interact"'), hook.find("unimplemented-source-event"))
        self.fail(
            "lane E " + E_TIP + " session 181de250fb4449d3b86a7a7c383b3489: "
            "A at CeruleanCave1F (24, 16) facing left blocked with "
            "unimplemented-source-event postgame:CERULEAN_CAVE_1F:mew-gift. "
            "See tools/notes/lane-e-mew-gift-dispatch.patch."
        )

    def test_mewtwo_talk_starts_the_battle(self):
        story = (ROOT / "Source/data/postgame/story.json").read_text()
        postgame = (ROOT / "Source/game/postgameStory.lua").read_text()
        self.assertIn("pokered:CERULEAN_CAVE_B1F:objects:1", story)
        self.assertIn("addStatic(data.cave.mewtwo)", postgame)
        self.fail(
            "lane E " + E_TIP + ": A at CeruleanCaveB1F (26, 13) facing right "
            "blocked with unimplemented-source-event "
            "pokered:CERULEAN_CAVE_B1F:objects:1. Root stayed overworld. "
            "See tools/notes/lane-e-mewtwo-uninstalled.patch."
        )

    def test_cerulean_city_inflates_in_the_pinned_pool(self):
        zone = (ROOT / "Source/world/zone.lua").read_text()
        body = zone.split("function switchZone(key)", 1)[1].split("\nfunction ", 1)[0]
        self.assertIn("WorldDeltas.ensureZone", body)
        self.fail(
            "lane E " + E_TIP + " sessions 3a952294f07e40c380cdc7d25a1a8081 "
            "and 181de250fb4449d3b86a7a7c383b3489: switchZone kanto_cerulean_city "
            "raised pd_readcompressed inflate failed, out of memory. "
            "MallocPoolSize stays 16645684. "
            "See tools/notes/lane-e-cerulean-city-inflate.patch."
        )


if __name__ == "__main__":
    unittest.main()
