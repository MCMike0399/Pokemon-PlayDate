"""Main-path sounds observe receipts and do not change HP or damage."""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class LaneEAudioMainPathTests(unittest.TestCase):
    def test_menu_save_medicine_catch_and_reorder_leave_receipts(self):
        pause = (ROOT / "Source/game/pauseState.lua").read_text()
        bag = (ROOT / "Source/game/bagState.lua").read_text()
        battle = (ROOT / "Source/battle/battle.lua").read_text()
        party = (ROOT / "Source/game/partyState.lua").read_text()
        self.assertIn("self.game.lastSave = self.lastSave", pause)
        self.assertEqual(bag.count("self.game.lastItemUse = {effect = ItemData.definitions[id].effect,"), 2)
        self.assertIn("self.dexPageAdded = self.enemy.species", battle)
        self.assertIn("self.swapReceipt = {from = from, to = to}", party)

    def test_poison_rating_and_elevators_leave_receipts(self):
        overworld = (ROOT / "Source/game/overworldState.lua").read_text()
        event = (ROOT / "Source/game/eventState.lua").read_text()
        celadon = (ROOT / "Source/game/celadonServicesController.lua").read_text()
        silph = (ROOT / "Source/game/silphStoryController.lua").read_text()
        hideout = (ROOT / "Source/game/rocketHideoutStoryController.lua").read_text()
        self.assertIn("game.lastFieldPoison = {step = game.fieldSteps}", overworld)
        self.assertEqual(overworld.count("noteFieldPoison(game)"), 3)
        self.assertIn("self.game.lastDexRating = {owned = owned}", event)
        self.assertIn('state.game.lastElevator = {place = "celadon", floor = index}', celadon)
        self.assertIn('state.game.lastElevator = {place = "silph", floor = index}', silph)
        self.assertIn('state.game.lastElevator = {place = "hideout", floor = entries[index].floor}', hideout)


if __name__ == "__main__":
    unittest.main()
