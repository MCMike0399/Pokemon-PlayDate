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

import json
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'Source/game/fieldTravelState.lua'
PATCH = ROOT / 'tools/notes/lane-a-boulder-push.patch'
POKERED = Path('/home/ubuntu/Developer/Pokemon-PlayDate-env/pokered')
SEAFOAM = ROOT / 'Source/data/zCoast/SeafoamIslands1F.json'

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

# Sequence 65 stands on (26, 8) facing up into object 2 at (26, 7).
# TryPushingBoulder moves that sprite one cell. The script token stays empty.
SEAFOAM_PUSH = r'''
local root = arg[1]
function Class(name)
    local cls = {}
    cls.__index = cls
    setmetatable(cls, {__call = function(_, ...)
        local obj = setmetatable({}, cls)
        if obj.init then obj:init(...) end
        return obj
    end})
    _G[name] = cls
    return cls
end
TILE_SIZE = 32
local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, item in pairs(value) do out[key] = copy(item) end
    return out
end
Party = { _primitive = copy }
WorldDeltas = { export = function() return {} end }
WorldMotionData = {
    initial = function(spec)
        return {id=spec.id, x=spec.x, y=spec.y, facing=spec.facing, phase="static",
            origin_x=spec.x, origin_y=spec.y, target_x=spec.x, target_y=spec.y,
            tick=0, delay_raw=0, delay_left=0}
    end,
    normalize = function(payload) return payload end,
}
SourceActors = {
    describe = function()
        return {
            revision = "af519899",
            width = 30,
            protected = {},
            actors = {{
                id = "pokered:SEAFOAM_ISLANDS_1F:objects:2",
                role = "boulder",
                x = 26, y = 7, facing = "down",
                faces = {down = true},
            }},
            canStand = function() return true end,
            canStep = function(_, _, _, x, y) return x == 26 and y == 6 end,
            canPush = function(_, _, _, x, y, tx, ty)
                return x == 26 and y == 7 and tx == 26 and ty == 6
            end,
        }
    end,
}
dofile(root .. "/Source/world/npcMotion.lua")
local boulder = {
    gridX = 26, gridY = 7, facing = "down", isMoving = false,
    images = {down = "boulder"},
    def = {source_event_id = "pokered:SEAFOAM_ISLANDS_1F:objects:2"},
    moveTo = function(self, x, y) self.x, self.y = x, y end,
    setImage = function(self, image) self.image = image end,
    setFacing = function(self, facing) self.facing = facing end,
}
local player = {gridX = 26, gridY = 8, facing = "up", isMoving = false}
local zone = {stableID = "pokered:SEAFOAM_ISLANDS_1F", width = 30, height = 18}
currentZone = zone
local session = {flags = function() return {} end}
local game = {session = session, player = player}
local motion = NPCMotion({npcs = {boulder}, getNPCAt = function() return nil end})
motion:attach(game, zone, {actors = {{
    id = boulder.def.source_event_id, x = 26, y = 7, facing = "down",
}}}, false)
local owner = {game = game, session = session, zone = zone, epoch = 1}
function owner:valid() return true end
function owner:isTop() return true end
local token, problem = motion:beginBoulderPush(boulder, "up", owner)
assert(type(token) == "table" and next(token) == nil, problem or "claimScript token was not empty")
for tick = 1, 7 do
    local complete, reason = motion:updateBoulderPush(token)
    assert(complete == false and reason == "moving", tostring(reason))
    assert(boulder.gridX == 26 and boulder.gridY == 7)
end
local complete, reason = motion:updateBoulderPush(token)
assert(complete == true and reason == "complete", tostring(reason))
assert(boulder.gridX == 26 and boulder.gridY == 6)
assert(token.gridX == nil)
print("seafoam-one-tile")
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

    def test_sequence_65_boulder_moves_one_tile(self):
        objects = (POKERED / 'data/maps/objects/SeafoamIslands1F.asm').read_text()
        script = (POKERED / 'scripts/SeafoamIslands1F.asm').read_text()
        self.assertIn('object_event 26,  7, SPRITE_BOULDER', objects)
        self.assertIn('dbmapcoord 17,  6', script)
        self.assertIn('dbmapcoord 24,  6', script)
        self.assertNotIn('dbmapcoord 26,  6', script)
        installed = json.loads(SEAFOAM.read_text())
        boulder = next(obj for obj in installed['events']['objects']
                       if obj['id'] == 'pokered:SEAFOAM_ISLANDS_1F:objects:2')
        self.assertEqual((boulder['x'], boulder['y'], boulder['sprite']), (26, 7, 'SPRITE_BOULDER'))
        self.assertEqual(installed['collision'][8][27], 0)
        self.assertEqual(installed['collision'][7][27], 0)
        maps = json.loads((ROOT / 'Source/data/sourceMaps.json').read_text())
        self.assertEqual(maps['maps']['SeafoamIslands1F']['padding'], 0)
        host = Path('/tmp/lane_a_seafoam_boulder.lua')
        host.write_text(SEAFOAM_PUSH)
        completed = subprocess.run(
            [lua_binary(), str(host), str(ROOT)],
            check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn('seafoam-one-tile', completed.stdout)


if __name__ == '__main__':
    unittest.main()
