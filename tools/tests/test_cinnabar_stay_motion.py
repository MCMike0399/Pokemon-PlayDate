#!/usr/bin/env python3
"""Fixed-facing STAY objects do not wander, and an old delay still loads.

pokered af519899 constants/map_object_constants.asm defines STAY as $FF and
WALK as $FE. engine/overworld/movement.asm sends both through .randomMovement.
.determineDirection ignores the random byte for DOWN, UP, LEFT and RIGHT.
TryWalking writes the facing before CanWalkOntoTile rejects $FF, so NONE and
ANY_DIR still turn. data/maps/objects/CinnabarGym.asm gives all nine objects
STAY, DOWN. data/maps/objects/CinnabarPokecenter.asm gives the nurse and the
link receptionist STAY, DOWN and the gentleman STAY, NONE.

Sequences 119, 124 and 125 stored delay on those fixed-facing actors.
normalize publishes that record as static on the object_event tile. It does
not keep a cell the actor could not have reached. The gentleman stays random,
so his delay still validates.
"""

import os
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ACTORS = ROOT / 'Source/world/sourceActors.lua'
MOTION = ROOT / 'Source/domain/worldMotion.lua'
REFERENCE = Path(os.environ['POKERED_REFERENCE_DIR'])
GYM = REFERENCE / 'data/maps/objects/CinnabarGym.asm'
CENTER = REFERENCE / 'data/maps/objects/CinnabarPokecenter.asm'

PROBE = r'''
Party = {}
function Party._primitive(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for k, v in pairs(value) do out[k] = Party._primitive(v) end
  return out
end
function Party._integer(n, low, high)
  return type(n) == "number" and n % 1 == 0 and n >= low and n <= high
end
function Party._array(value, limit)
  if type(value) ~= "table" or #value > limit then return false end
  local count = 0
  for k in pairs(value) do
    if type(k) ~= "number" then return false end
    count = count + 1
  end
  return count == #value
end
dofile(arg[1])
dofile(arg[2])
assert(SourceActors.wanders("STAY", "DOWN", false, false, false) == false)
assert(SourceActors.wanders("STAY", "UP", false, false, false) == false)
assert(SourceActors.wanders("STAY", "LEFT", false, false, false) == false)
assert(SourceActors.wanders("STAY", "RIGHT", false, false, false) == false)
assert(SourceActors.wanders("STAY", "NONE", false, false, false) == true)
assert(SourceActors.wanders("STAY", "ANY_DIR", false, false, false) == true)
assert(SourceActors.wanders("STAY", "LEFT_RIGHT", false, false, false) == true)
assert(SourceActors.wanders("WALK", "ANY_DIR", false, false, false) == true)
assert(SourceActors.wanders("WALK", "DOWN", false, true, false) == false)
assert(SourceActors.wanders("WALK", "ANY_DIR", false, false, true) == false)
assert(SourceActors.wanders("STAY", "NONE", false, false, true) == false)
assert(SourceActors.wanders("STAY", "BOULDER_MOVEMENT_BYTE_2", true, false, false) == false)
assert(SourceActors.wanders("STAY", "NONE", true, false, false) == false)

local function spec_for(id, movement, selector, x, y, facing)
  return {
    id = id, random = SourceActors.wanders(movement, selector, false, false, false),
    movement = movement, faces = {down = true, up = true, left = true, right = true},
    facing = facing, x = x, y = y, visibility = {},
  }
end

local function actor(spec, phase, x, y)
  return {
    id = spec.id, x = x, y = y, facing = "down", phase = phase,
    origin_x = x, origin_y = y, target_x = x, target_y = y, tick = 0,
    delay_raw = phase == "delay" and 37 or 0,
    delay_left = phase == "delay" and 6 or 0,
  }
end

local function load(spec, record, px, py)
  local descriptor = {
    zone_id = "pokered:CINNABAR_GYM",
    revision = "af519899719f0754965776faac0e836a3b906e6d",
    width = 20, height = 18, actors = {spec},
    canStand = function() return true end, canStep = function() return true end,
  }
  local payload = {
    version = 1, zone_id = descriptor.zone_id, definition_revision = descriptor.revision,
    count = 1, actors = {record},
  }
  local location = {zone_id = descriptor.zone_id, x = px, y = py, facing = "up"}
  return WorldMotionData.normalize(payload, descriptor, location, {})
end

local guide = spec_for("pokered:CINNABAR_GYM:objects:9", "STAY", "DOWN", 16, 13, "down")
assert(guide.random == false)
local initial = WorldMotionData.initial(guide)
assert(initial.phase == "static" and initial.x == 16 and initial.y == 13)
local settled = load(guide, actor(guide, "delay", 16, 13), 3, 4)
assert(settled.actors[1].phase == "static")
assert(settled.actors[1].x == 16 and settled.actors[1].y == 13)
assert(settled.actors[1].delay_left == 0 and settled.actors[1].delay_raw == 0)
local wandered = load(guide, actor(guide, "delay", 10, 10), 3, 4)
assert(wandered.actors[1].phase == "static")
assert(wandered.actors[1].x == 16 and wandered.actors[1].y == 13)
local trainer = spec_for("pokered:CINNABAR_GYM:objects:1", "STAY", "DOWN", 3, 3, "down")
trainer.random = false
local blaine = load(trainer, actor(trainer, "delay", 3, 3), 3, 4)
assert(blaine.actors[1].phase == "static" and blaine.actors[1].x == 3 and blaine.actors[1].y == 3)

local nurse = spec_for("pokered:CINNABAR_POKECENTER:objects:1", "STAY", "DOWN", 3, 1, "down")
local receptionist = spec_for("pokered:CINNABAR_POKECENTER:objects:4", "STAY", "DOWN", 11, 2, "down")
assert(nurse.random == false and receptionist.random == false)
local nurseLoaded = load(nurse, actor(nurse, "delay", 3, 1), 3, 3)
assert(nurseLoaded.actors[1].phase == "static" and nurseLoaded.actors[1].x == 3 and nurseLoaded.actors[1].y == 1)
local desk = load(receptionist, actor(receptionist, "delay", 11, 2), 3, 3)
assert(desk.actors[1].phase == "static" and desk.actors[1].x == 11 and desk.actors[1].y == 2)

local gentleman = spec_for("pokered:CINNABAR_POKECENTER:objects:3", "STAY", "NONE", 2, 6, "down")
assert(gentleman.random == true)
local turning = load(gentleman, actor(gentleman, "delay", 2, 6), 3, 3)
assert(turning.actors[1].phase == "delay")
assert(turning.actors[1].x == 2 and turning.actors[1].y == 6)
assert(turning.actors[1].delay_left == 6)
print("cinnabar-stay-motion")
'''


def object_lines(path):
    return [line for line in path.read_text().splitlines() if line.startswith('\tobject_event')]


class CinnabarStayMotionTest(unittest.TestCase):
    def test_fixed_facing_stay_loads_on_its_object_tile(self):
        gym = object_lines(GYM)
        self.assertEqual(len(gym), 9)
        self.assertTrue(all(', STAY, DOWN,' in line for line in gym))
        self.assertIn(
            'object_event 16, 13, SPRITE_GYM_GUIDE, STAY, DOWN, TEXT_CINNABARGYM_GYM_GUIDE',
            GYM.read_text())
        center = CENTER.read_text()
        self.assertIn('object_event  3,  1, SPRITE_NURSE, STAY, DOWN, TEXT_CINNABARPOKECENTER_NURSE', center)
        self.assertIn(
            'object_event  2,  6, SPRITE_GENTLEMAN, STAY, NONE, TEXT_CINNABARPOKECENTER_GENTLEMAN',
            center)
        self.assertIn(
            'object_event 11,  2, SPRITE_LINK_RECEPTIONIST, STAY, DOWN, TEXT_CINNABARPOKECENTER_LINK_RECEPTIONIST',
            center)
        source = ACTORS.read_text()
        self.assertIn('function SourceActors.wanders(movement, facing, boulder, trainer, item)', source)
        self.assertIn(
            'random=SourceActors.wanders(event.movement, event.range_or_facing, boulder, trainer, item)',
            source)
        self.assertNotIn('random=not boulder and not trainer and not item', source)
        self.assertNotIn('random=event.movement=="WALK"', source)
        probe = Path('/tmp/cinnabar_stay_probe.lua')
        probe.write_text(PROBE)
        completed = subprocess.run(
            ['lua5.4', str(probe), str(ACTORS), str(MOTION)],
            capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn('cinnabar-stay-motion', completed.stdout)


if __name__ == '__main__':
    unittest.main()
