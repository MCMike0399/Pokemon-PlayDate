#!/usr/bin/env python3
"""B4F Surf must ask the Seafoam current controller.

pret/pokered af519899 engine/overworld/field_move_messages.asm
IsSurfingAllowed denies Surf only on SEAFOAM_ISLANDS_B4F at (7, 11), and
only while the two SEAFOAM4 boulder flags are still clear. Every other
B4F tile, and all of B3F, may board Surf. B3F's forced Surf is the
arrival at (18, 7) and (19, 7), not this deny.

Source/game/context.lua errors for the whole B4F map before that
predicate can answer. CoastStory.currentTooFast is the predicate.
context.lua is shared, so the wiring is
tools/notes/lane-a-seafoam-current.patch. This test fails until that
patch is in the shared file.
"""

import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'Source/game/context.lua'
PATCH = ROOT / 'tools/notes/lane-a-seafoam-current.patch'


def restrictions(text):
    start = text.index('function GameContext:fieldTravelRestrictions')
    end = text.index('function GameContext:commitFieldTravel', start)
    return text[start:end]


class SeafoamCurrentTest(unittest.TestCase):
    def test_patch_applies(self):
        subprocess.run(
            ['git', 'apply', '--check', str(PATCH)],
            cwd=ROOT, check=True,
        )

    def test_source_asks_the_seafoam_controller(self):
        region = restrictions(SOURCE.read_text())
        self.assertIn('CoastStory.currentTooFast', region)
        self.assertNotIn('Seafoam field current controller is not installed', region)


if __name__ == '__main__':
    unittest.main()
