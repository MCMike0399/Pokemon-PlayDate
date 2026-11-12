#!/usr/bin/env python3
"""Lane A: a finished Strength push reads the npc, not the script token.

Play from Seafoam Islands 1F crashed in FieldTravelState:update:

    game/fieldTravelState.lua:185: attempt to perform arithmetic on a nil value (field 'gridX')

beginBoulderPush returns the token from NPCMotion:claimScript. That token is
an empty table, and updateBoulderPush releases it before returning true.
The landing cell is options.npc.gridX after the push pose.

The fix is tools/notes/lane-a-boulder-push.patch. It does not belong in this
branch: fieldTravelState.lua is shared. This test fails until that patch is
in the shared file.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'Source/game/fieldTravelState.lua'


def push_completion(source):
    update = source.split('function FieldTravelState:update()', 1)[1]
    update = update.split('\nfunction ', 1)[0]
    return update.split('if self.phase == "push"', 1)[1].split('elseif self.phase == "moving"', 1)[0]


class BoulderPushGridTest(unittest.TestCase):
    def test_completion_reads_the_pushed_npc(self):
        source = SOURCE.read_text()
        completion = push_completion(source)
        self.assertTrue(
            'self.pushNpc = options.npc' in source,
            'Remember options.npc. The script token has no grid. '
            'Apply tools/notes/lane-a-boulder-push.patch',
        )
        self.assertTrue(
            'local npc = self.boulder' not in completion,
            'self.boulder is the script token. Reading token.gridX crashed the Seafoam push. '
            'Apply tools/notes/lane-a-boulder-push.patch',
        )
        landed = completion.split('boulderLanded', 1)[1].split(')', 1)[0]
        self.assertNotIn('self.boulder', landed)
        self.assertIn('npc.gridX', landed)
        self.assertIn('npc.gridX', completion.split('boulderLanded', 1)[0])


if __name__ == '__main__':
    unittest.main()
