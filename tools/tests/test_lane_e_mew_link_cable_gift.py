#!/usr/bin/env python3
"""The Cerulean Cave gift and the static contracts live with the postgame chunk.

Mew is not an object in pokered data/maps/objects/CeruleanCave1F.asm. The
level-5 one-per-save gift is the Miguel-approved deviation. Mewtwo stays
pokered data/maps/objects/CeruleanCaveB1F.asm object 1 and
scripts/CeruleanCaveB1F.asm, level 70 at (27, 13). LINK CABLE is not a
pokered item. The four trade evolutions are pokered
data/pokemon/evos_moves.asm for KADABRA, MACHOKE, GRAVELER, and HAUNTER.
The cave guard hides in pokered scripts/HallOfFame.asm HideObject.

This fails on origin/main and passes once
tools/notes/lane-e-mew-link-cable-gift.patch is applied.
"""

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STORY = ROOT / "Source/data/postgame/story.json"
PLAY = ROOT / "Source/data/postgame/play.json"
CODE = ROOT / "Source/game/postgameStory.lua"


class MewLinkCableGiftTest(unittest.TestCase):
    def test_gift_dispatch_texts_and_static_contracts(self):
        story = json.loads(STORY.read_text(encoding="utf-8"))
        play = json.loads(PLAY.read_text(encoding="utf-8"))
        code = CODE.read_text(encoding="utf-8")
        deviations = story.get("deviations")
        self.assertIsInstance(deviations, dict, "story.json has no gift deviations")
        mew = deviations.get("mew") or {}
        cable = deviations.get("link_cable") or {}
        npc = mew.get("npc") or {}
        self.assertEqual(mew.get("species"), "mew")
        self.assertEqual(mew.get("level"), 5)
        self.assertEqual(mew.get("flag"), "EVENT_GOT_MEW")
        self.assertEqual(mew.get("requires_flag"), "TOGGLE_CERULEAN_CAVE_GUY")
        self.assertEqual(npc.get("id"), "postgame:CERULEAN_CAVE_1F:mew-gift")
        self.assertEqual(npc.get("dispatch_id"), "pokered:CERULEAN_CAVE_1F:script:mew-gift")
        self.assertEqual((npc.get("x"), npc.get("y")), (23, 16))
        self.assertEqual(cable.get("id"), "linkCable")
        self.assertEqual(
            [(row.get("from"), row.get("to")) for row in cable.get("evolves") or []],
            [("kadabra", "alakazam"), ("machoke", "machamp"),
             ("graveler", "golem"), ("haunter", "gengar")])
        for label in ("_PostgameMewGiftText", "_PostgameLinkCableText",
                      "_PostgameGiftNotChampionText", "_PostgameGiftIntroText"):
            self.assertEqual(play["texts"].get(label, {}).get("source"), "miguel-approved-deviation", label)
        for name in ("tryGift", "giveMew", "giveLinkCable", "presentGift", "giftPlan"):
            self.assertIn("function PostgameStory." + name, code)
        self.assertIn("PostgameStaticContracts.run", code)
        self.assertIn('Contracts.register("postgame-statics"', code)
        self.assertIn("pokered:CERULEAN_CAVE_B1F:objects:1", code)


if __name__ == "__main__":
    unittest.main()
