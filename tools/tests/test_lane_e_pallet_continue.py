"""A pre-cutover save must still offer CONTINUE.

Sequence 208 stores Fly's visited list as pallet_town and a two-tile
oaks_lab delta. FieldTravel.normalize only allows pokered:PALLET_TOWN.
Dropping oaks_lab makes GameSession reject the world
("world validator discarded unsupported data") because every saved key
must survive validation. The retired record stays in the normalized
payload and is not applied. Title inspect then has no candidate until
both changes land, so the menu is NEW GAME and OPTION.
Fixed-facing STAY actors in that save are still in a delay phase.
WorldMotionData.normalize publishes them on the object tile, and the
session accepts that only when SourceActors.settled proves the pose.
The migration is tools/notes/lane-e-pallet-continue.patch. This test fails
until that patch is in the shared files. The save bytes stay unchanged.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TRAVEL = ROOT / "Source/domain/fieldTravel.lua"
WORLD = ROOT / "Source/world/zone.lua"
ACTORS = ROOT / "Source/world/sourceActors.lua"
SESSION = ROOT / "Source/domain/gameSession.lua"
PATCH = ROOT / "tools/notes/lane-e-pallet-continue.patch"


class PalletContinueTests(unittest.TestCase):
    def test_old_fly_key_maps_onto_the_imported_town(self):
        source = TRAVEL.read_text(encoding="utf-8")
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn('pallet_town = "pokered:PALLET_TOWN"', patch)
        normalize = source.split("function FieldTravel.normalize", 1)[1].split("\nfunction", 1)[0]
        self.assertIn(
            'pallet_town = "pokered:PALLET_TOWN"',
            normalize,
            "Map the authored Fly key onto pokered:PALLET_TOWN. "
            "Apply tools/notes/lane-e-pallet-continue.patch",
        )

    def test_retired_lab_deltas_stay_in_the_normalized_payload(self):
        source = WORLD.read_text(encoding="utf-8")
        prepare = source.split("local function prepareWorld", 1)[1].split("\nfunction WorldDeltas", 1)[0]
        retired = prepare.split("retiredAuthored", 1)[1].split("elseif", 1)[0]
        self.assertIn("oaks_lab", prepare)
        self.assertIn("pallet_town", prepare)
        self.assertIn("reds_house_2f", prepare)
        self.assertIn("normalized[#normalized + 1]", retired)

    def test_stay_delay_can_settle_on_the_object_tile(self):
        actors = ACTORS.read_text(encoding="utf-8")
        session = SESSION.read_text(encoding="utf-8")
        self.assertIn("function SourceActors.settled(saved, world, location)", actors)
        self.assertIn("actor rewrite requires an independent settle proof", session)
        self.assertIn("settledActors=SourceActors.settled", (ROOT / "Source/game/context.lua").read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
