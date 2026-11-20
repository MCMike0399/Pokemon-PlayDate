#!/usr/bin/env python3
"""Authored Oak's Lab has no Oak, so the parcel cannot be delivered.

Session a7df918d carried Oak's Parcel from the Viridian Mart back through
Route 1. Pallet's door at (12, 11) entered oaks_lab at (6, 10). Standing
at (6, 3), facing up, A did nothing and oaksParcel stayed 1.

pret/pokered af519899 data/maps/objects/OaksLab.asm places OAK at object
(5, 2), STAY DOWN. Source padding 1 makes that (6, 2), the cell this
player was facing. KantoWorld.tryInteract starts
pokered:OAKS_LAB:script:parcel-handoff only when that actor is named OAK,
and EventState then requires findByName("OAK").

The authored zone registers doors and no NPCs. This fails until
tools/notes/lane-e-oaks-lab-oak.patch is applied. Do not apply it here.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAPS = ROOT / "Source/data/maps.lua"


def oaks_lab_block(source):
    start = source.index('zone("oaks_lab"')
    end = source.index('zone("pallet_town"', start)
    return source[start:end]


class OaksLabOakTest(unittest.TestCase):
    def test_authored_lab_has_oak_in_front_of_the_parcel_spot(self):
        block = oaks_lab_block(MAPS.read_text(encoding="utf-8"))
        self.assertIn('name = "OAK"', block, "Apply tools/notes/lane-e-oaks-lab-oak.patch")
        self.assertIn("gridX = 6", block)
        self.assertIn("gridY = 2", block)
        self.assertIn('sprite = "oak"', block)
        self.assertIn('facing = "down"', block)


if __name__ == "__main__":
    unittest.main()
