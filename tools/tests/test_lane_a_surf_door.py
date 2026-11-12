#!/usr/bin/env python3
"""A surf step that lands on the Seafoam water stairs must take the door.

pret/pokered af519899 data/maps/objects/SeafoamIslandsB3F.asm warp_event
20, 17 and 21, 17 go to SEAFOAM_ISLANDS_B4F. Surf movement finishes inside
the fieldStep branch of ExploreSubstate:update, and that branch used to
return before getDoorAt. Those stairs are water, so the only way onto
them is a surf step.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'Source/game/overworldState.lua'


def field_step_region(text):
    start = text.index('    if player.fieldStep then')
    end = text.index('    if Story.check', start)
    return text[start:end]


class SurfDoorTest(unittest.TestCase):
    def test_source_checks_the_door_when_a_surf_step_finishes(self):
        region = field_step_region(SOURCE.read_text())
        self.assertIn('getDoorAt', region)
        self.assertIn('doorWarp', region)
        self.assertLess(region.index('getDoorAt'), region.rindex('return'))


if __name__ == '__main__':
    unittest.main()
