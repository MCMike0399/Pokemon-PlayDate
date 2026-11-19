#!/usr/bin/env python3
"""Elite Four battle intros have no trainer picture.

story.json names OPP_LORELEI, OPP_BRUNO, OPP_AGATHA, OPP_LANCE, and
OPP_RIVAL3. The matching sheets already exist under
images/title/trainers/, and BattleScene:drawTrainer loads
images/title/trainers/<class> after stripping OPP_. EndgameStory drops
class_source when it builds the trainer rows, so BattleState leaves
trainerClass nil and the enemy platform stays empty through
"LORELEI wants to battle!". The same drop hits the Route 22 rival.
The patch is not applied on this branch.
"""

import json
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-trainer-pic.patch"
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
    def test_sheets_and_lookup_already_match_the_five_classes(self):
        story = json.loads(DATA.read_text())
        found = {row["name"]: row["class_source"] for row in story["elite_four"]}
        found["BLUE"] = story["champion"]["class_source"]
        self.assertEqual(found, EXPECTED)
        for klass in EXPECTED.values():
            sheet = PICS / f"{klass.removeprefix('OPP_')}.png"
            self.assertGreater(sheet.stat().st_size, 100, sheet.name)
        scene = SCENE.read_text()
        self.assertIn('sourceClass:gsub("^OPP_", "")', scene)
        self.assertIn('gfx.image.new("images/title/trainers/" .. class)', scene)
        state = BATTLE.read_text()
        self.assertIn("definition.class_source", state)

    def test_live_rows_drop_the_class(self):
        text = STORY.read_text()
        row = text.split("local function trainerRow(row)", 1)[1].split("local function trainerEvent", 1)[0]
        self.assertNotIn("class_source", row)
        install = text.split("function EndgameStory.install()", 1)[1]
        rival = install.split("trainers[rival.id]", 1)[1].split("local champ", 1)[0]
        champ = install.split("addTrainer({id = champ.id", 1)[1].split("trainers[champ.id]", 1)[0]
        self.assertNotIn("class_source", rival)
        self.assertNotIn("class_source", champ)

    @unittest.expectedFailure
    def test_unpatched_rows_keep_class_source(self):
        text = STORY.read_text()
        row = text.split("local function trainerRow(row)", 1)[1].split("local function trainerEvent", 1)[0]
        self.assertIn("class_source = row.class_source", row)
        install = text.split("function EndgameStory.install()", 1)[1]
        self.assertIn("class_source = rival.class_source", install)
        self.assertIn("class_source = champ.class_source", install)

    def test_patch_copies_class_source_onto_the_rows(self):
        check = subprocess.run(
            ["git", "apply", "--check", str(PATCH)], cwd=ROOT,
            capture_output=True, text=True)
        self.assertEqual(check.returncode, 0, check.stderr)
        output = Path("/tmp/lane-e-trainer-pic.lua")
        applied = subprocess.run(
            ["patch", "-o", str(output), str(STORY), str(PATCH)],
            capture_output=True, text=True)
        self.assertEqual(applied.returncode, 0, applied.stdout + applied.stderr)
        text = output.read_text()
        row = text.split("local function trainerRow(row)", 1)[1].split("local function trainerEvent", 1)[0]
        self.assertIn("class_source = row.class_source", row)
        install = text.split("function EndgameStory.install()", 1)[1]
        self.assertIn("class_source = rival.class_source", install)
        self.assertIn("class_source = champ.class_source", install)


if __name__ == "__main__":
    unittest.main()
