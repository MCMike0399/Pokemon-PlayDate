#!/usr/bin/env python3
"""A surf step that lands on stairs must take the door.

Source/game/overworldState.lua returns at the end of the fieldStep
branch before getDoorAt. Surf movement sets player.fieldStep in
Source/world/player.lua, so the step that finishes is the same frame
the door would have been checked.

Sequence 87 landed on Seafoam B3F (20, 17) facing down, still surfing.
That tile is warps:6 to B4F. Stepping off and back onto it in sequence
88 stayed on B3F. The water stairs are not walkable, so the only way
onto them is a surf step, and that step never warps.

overworldState.lua is shared. The fix is
tools/notes/lane-a-surf-door.patch. This test fails until that patch
is in the shared file.
"""

import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'Source/game/overworldState.lua'
PATCH = ROOT / 'tools/notes/lane-a-surf-door.patch'


def field_step_region(text):
    start = text.index('    if player.fieldStep then')
    end = text.index('    if Story.check', start)
    return text[start:end]


class SurfDoorTest(unittest.TestCase):
    def test_patch_applies(self):
        subprocess.run(
            ['git', 'apply', '--check', str(PATCH)],
            cwd=ROOT, check=True,
        )

    def test_source_checks_the_door_when_a_surf_step_finishes(self):
        region = field_step_region(SOURCE.read_text())
        self.assertIn('getDoorAt', region)


if __name__ == '__main__':
    unittest.main()
