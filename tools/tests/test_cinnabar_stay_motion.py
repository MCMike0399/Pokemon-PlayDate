#!/usr/bin/env python3
"""Cinnabar Gym STAY objects do not wander, and STAY+NONE still turns.

pokered af519899 data/maps/objects/CinnabarGym.asm gives all nine objects
STAY, DOWN. constants/map_object_constants.asm defines STAY as $FF and WALK
as $FE. engine/overworld/movement.asm sends both through .randomMovement.
CanWalkOntoTile rejects $FF before MAPX/MAPY change. A fixed facing ignores
the random byte. NONE and ANY_DIR write a new facing in TryWalking before
that rejection. WorldMotionData.normalize still rejects a delay on a
stationary actor.
"""

import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ACTORS = ROOT / 'Source/world/sourceActors.lua'
MOTION = ROOT / 'Source/domain/worldMotion.lua'
ASM = Path.home() / 'Developer/Pokemon-PlayDate-env/pokered/data/maps/objects/CinnabarGym.asm'

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
assert(SourceActors.wanders("STAY", "NONE", false, false, false) == true)
assert(SourceActors.wanders("STAY", "ANY_DIR", false, false, false) == true)
assert(SourceActors.wanders("WALK", "ANY_DIR", false, false, false) == true)
assert(SourceActors.wanders("WALK", "DOWN", false, true, false) == false)
assert(SourceActors.wanders("STAY", "NONE", false, false, true) == false)
assert(SourceActors.wanders("STAY", "BOULDER_MOVEMENT_BYTE_2", true, false, false) == false)
local spec = {
  id = "pokered:CINNABAR_GYM:objects:1", random = false, movement = "STAY",
  faces = {down = true}, facing = "down", x = 3, y = 3, visibility = {},
}
local initial = WorldMotionData.initial(spec)
assert(initial.phase == "static" and initial.x == 3 and initial.y == 3)
local descriptor = {
  zone_id = "pokered:CINNABAR_GYM",
  revision = "af519899719f0754965776faac0e836a3b906e6d",
  width = 20, height = 18, actors = {spec},
  canStand = function() return true end, canStep = function() return true end,
}
local payload = {
  version = 1, zone_id = descriptor.zone_id, definition_revision = descriptor.revision, count = 1,
  actors = {{
    id = spec.id, x = 3, y = 3, facing = "down", phase = "delay",
    origin_x = 3, origin_y = 3, target_x = 3, target_y = 3, tick = 0,
    delay_raw = 37, delay_left = 6,
  }},
}
local location = {zone_id = descriptor.zone_id, x = 3, y = 4, facing = "up"}
local ok, err = pcall(WorldMotionData.normalize, payload, descriptor, location, {})
assert(not ok and tostring(err):find("invalid source actor delay", 1, true), err)
print("cinnabar-stay-motion")
'''


class CinnabarStayMotionTest(unittest.TestCase):
    def test_gym_objects_are_stay_down_and_fixed_facing_does_not_wander(self):
        script = ASM.read_text()
        events = [line for line in script.splitlines() if line.startswith('\tobject_event')]
        self.assertEqual(len(events), 9)
        self.assertTrue(all(', STAY, DOWN,' in line for line in events))
        self.assertIn('object_event  3,  3, SPRITE_MIDDLE_AGED_MAN, STAY, DOWN, TEXT_CINNABARGYM_BLAINE', script)
        source = ACTORS.read_text()
        self.assertIn('function SourceActors.wanders(movement, facing, boulder, trainer, item)', source)
        self.assertNotIn('random=not boulder and not trainer and not item', source)
        self.assertNotIn('random=event.movement=="WALK" and not boulder', source)
        probe = Path('/tmp/cinnabar_stay_probe.lua')
        probe.write_text(PROBE)
        completed = subprocess.run(
            ['lua5.4', str(probe), str(ACTORS), str(MOTION)],
            capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn('cinnabar-stay-motion', completed.stdout)


if __name__ == '__main__':
    unittest.main()
