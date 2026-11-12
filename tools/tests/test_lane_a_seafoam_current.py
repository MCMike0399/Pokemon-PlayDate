#!/usr/bin/env python3
"""B4F Surf must ask the Seafoam current controller.

pret/pokered af519899 engine/overworld/field_move_messages.asm
IsSurfingAllowed denies Surf only on SEAFOAM_ISLANDS_B4F at (7, 11), and
only while the two SEAFOAM4 boulder flags are still clear. dbmapcoord
stores y then x, so that pair is x=7, y=11. Every other B4F tile, and
all of B3F, may board Surf. B3F's forced Surf is the arrival at (18, 7)
and (19, 7), not this deny.

The shared context.lua calls CoastStory.currentTooFast. The note patch is
the exact edit, checked in reverse once it is in the file.
"""

import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'Source/game/context.lua'
STORY = ROOT / 'Source/game/coastStory.lua'
PATCH = ROOT / 'tools/notes/lane-a-seafoam-current.patch'


def restrictions(text):
    start = text.index('function GameContext:fieldTravelRestrictions')
    end = text.index('function GameContext:commitFieldTravel', start)
    return text[start:end]


class SeafoamCurrentTest(unittest.TestCase):
    def test_patch_is_the_applied_edit(self):
        subprocess.run(
            ['git', 'apply', '--reverse', '--check', str(PATCH)],
            cwd=ROOT, check=True,
        )

    def test_source_asks_the_seafoam_controller(self):
        region = restrictions(SOURCE.read_text())
        self.assertIn('CoastStory.currentTooFast', region)
        self.assertNotIn('Seafoam field current controller is not installed', region)
        self.assertIn('import "game/coastStory"', SOURCE.read_text())

    def test_predicate_matches_is_surfing_allowed(self):
        lua = shutil.which('lua5.4') or shutil.which('lua')
        self.assertIsNotNone(lua)
        script = r'''
dofile(arg[0])
local function denied(map, x, y, flags)
  return CoastStory.currentTooFast(map, x, y, flags) == true
end
assert(denied("pokered:SEAFOAM_ISLANDS_B4F", 7, 11, {}))
assert(denied("pokered:SEAFOAM_ISLANDS_B4F", 7, 11, {
  EVENT_SEAFOAM4_BOULDER1_DOWN_HOLE = true,
}))
assert(not denied("pokered:SEAFOAM_ISLANDS_B4F", 7, 11, {
  EVENT_SEAFOAM4_BOULDER1_DOWN_HOLE = true,
  EVENT_SEAFOAM4_BOULDER2_DOWN_HOLE = true,
}))
assert(not denied("pokered:SEAFOAM_ISLANDS_B4F", 7, 3, {}))
assert(not denied("pokered:SEAFOAM_ISLANDS_B4F", 11, 7, {}))
assert(not denied("pokered:SEAFOAM_ISLANDS_B3F", 18, 7, {}))
assert(not denied("pokered:SEAFOAM_ISLANDS_B3F", 7, 11, {}))
'''
        subprocess.run([lua, '-e', script, str(STORY)], cwd=ROOT, check=True)


if __name__ == '__main__':
    unittest.main()
