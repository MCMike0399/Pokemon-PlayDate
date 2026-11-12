#!/usr/bin/env python3
"""The Strength push reports the script token's grid.

pret/pokered af519899 TryPushingBoulder moves the sprite in front of the
player. SeafoamIslands1F_Script then calls CheckBoulderCoords on that
sprite. NPCMotion:claimScript returns an empty token, and _pose writes the
landing cell onto the npc before updateBoulderPush releases the token.
FieldTravelState:update keeps the token in self.boulder and subtracts
entry.padding from token.gridX.

That arithmetic is the crash from sequence 65 at Seafoam Islands 1F
(24, 8), the second press into the boulder at (26, 7):

    game/fieldTravelState.lua:185: attempt to perform arithmetic on a nil value (field 'gridX')

The fix remembers options.npc and still evaluates npc.gridX. A nil guard
around that subtraction would hide the missing sprite. fieldTravelState.lua
is shared, so the fix is tools/notes/lane-a-boulder-push.patch. This test
fails until that patch is in the shared file.
"""

import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'Source/game/fieldTravelState.lua'
PATCH = ROOT / 'tools/notes/lane-a-boulder-push.patch'

TOKEN_CRASH = r'''
local token = {}
local ok, err = pcall(function()
  local npc = token
  return npc.gridX - 0
end)
assert(ok == false, "the script token should have no grid")
assert(tostring(err):find("gridX", 1, true), tostring(err))
print("token-grid-crash")
'''


def lua_binary():
    for name in ('lua5.4', 'lua'):
        found = shutil.which(name)
        if found:
            return found
    raise AssertionError('Lua 5.4 is required')


def push_completion(source):
    update = source.split('function FieldTravelState:update()', 1)[1]
    update = update.split('\nfunction ', 1)[0]
    return update.split('if self.phase == "push"', 1)[1].split('elseif self.phase == "moving"', 1)[0]


class BoulderPushGridTest(unittest.TestCase):
    def test_script_token_grid_is_nil(self):
        host = Path('/tmp/lane_b_boulder_token.lua')
        host.write_text(TOKEN_CRASH)
        completed = subprocess.run(
            [lua_binary(), str(host)], check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn('token-grid-crash', completed.stdout)

    def test_completion_reads_the_pushed_sprite(self):
        source = SOURCE.read_text()
        completion = push_completion(source)
        patch = PATCH.read_text()
        self.assertNotIn(
            'npc.gridX and',
            patch,
            'The patch must still evaluate the landing grid, not skip it.',
        )
        self.assertIn('npc.gridX - entry.padding', patch)
        self.assertTrue(
            'self.pushNpc = options.npc' in source,
            'Remember the sprite from openPush. The script token has no grid. '
            'Apply tools/notes/lane-a-boulder-push.patch',
        )
        self.assertTrue(
            'local npc = self.pushNpc' in completion,
            'CheckBoulderCoords reads the boulder sprite, not the script token. '
            'Apply tools/notes/lane-a-boulder-push.patch',
        )
        self.assertIn('npc.gridX - entry.padding', completion)


if __name__ == '__main__':
    unittest.main()
