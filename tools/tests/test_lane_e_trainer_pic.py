#!/usr/bin/env python3
"""Elite Four and Champion battle intros keep the pokered trainer class.

scripts/LoreleisRoom.asm and the other three rooms store the opponent
class on the object. scripts/ChampionsRoom.asm loads OPP_RIVAL3.
scripts/Route22.asm loads OPP_RIVAL2 for the second fight. Those
class_source fields are already in story.json. The live rows copy them
so BattleState can load images/title/trainers/<class>.
"""

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STORY = ROOT / "Source/game/endgameStory.lua"
DATA = ROOT / "Source/data/endgame/story.json"
PICS = ROOT / "Source/images/title/trainers"
BATTLE = ROOT / "Source/game/battleState.lua"
SCENE = ROOT / "Source/battle/battleScene.lua"

EXPECTED = {
    "LORELEI": "OPP_LORELEI",
    "BRUNO": "OPP_BRUNO",
    "AGATHA": "OPP_AGATHA",
    "LANCE": "OPP_LANCE",
    "BLUE": "OPP_RIVAL3",
}


class TrainerPicTests(unittest.TestCase):
    def test_story_classes_match_the_five_pictures(self):
        story = json.loads(DATA.read_text())
        found = {row["name"]: row["class_source"] for row in story["elite_four"]}
        found["BLUE"] = story["champion"]["class_source"]
        self.assertEqual(found, EXPECTED)
        self.assertEqual(story["route22_rival"]["class_source"], "OPP_RIVAL2")
        for klass in list(EXPECTED.values()) + ["OPP_RIVAL2"]:
            sheet = PICS / f"{klass.removeprefix('OPP_')}.png"
            self.assertGreater(sheet.stat().st_size, 100, sheet.name)

    def test_live_rows_keep_class_source(self):
        text = STORY.read_text()
        row = text.split("local function trainerRow(row)", 1)[1].split("local function trainerEvent", 1)[0]
        self.assertIn("class_source = row.class_source", row)
        install = text.split("function EndgameStory.install()", 1)[1]
        self.assertIn("class_source = rival.class_source", install)
        self.assertIn("class_source = champ.class_source", install)
        scene = SCENE.read_text()
        self.assertIn('sourceClass:gsub("^OPP_", "")', scene)
        self.assertIn('gfx.image.new("images/title/trainers/" .. class)', scene)
        state = BATTLE.read_text()
        self.assertIn("definition.class_source", state)


if __name__ == "__main__":
    unittest.main()
