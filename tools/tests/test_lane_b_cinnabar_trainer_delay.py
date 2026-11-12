#!/usr/bin/env python3
"""Sequence 119 cannot continue once Blaine's objects are trainers.

The gym save stored every STAY object in a wander delay. Registering the
trainers clears spec.random, and WorldMotionData.normalize then rejects the
record. The shared settle is tools/notes/lane-a-cinnabar-trainer-delay.patch.
"""

import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / 'tools/notes/lane-a-cinnabar-trainer-delay.patch'
MOTION = ROOT / 'Source/domain/worldMotion.lua'

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
local descriptor = {
  zone_id = "pokered:CINNABAR_GYM",
  revision = "af519899719f0754965776faac0e836a3b906e6d",
  width = 20, height = 18,
  actors = {{
    id = "pokered:CINNABAR_GYM:objects:1", random = false, movement = "STAY",
    faces = {down = true}, facing = "down", x = 3, y = 3, visibility = {},
  }},
  canStand = function() return true end,
  canStep = function() return true end,
}
local payload = {
  version = 1, zone_id = descriptor.zone_id, definition_revision = descriptor.revision, count = 1,
  actors = {{
    id = "pokered:CINNABAR_GYM:objects:1", x = 3, y = 3, facing = "down", phase = "delay",
    origin_x = 3, origin_y = 3, target_x = 3, target_y = 3, tick = 0,
    delay_raw = 37, delay_left = 6,
  }},
}
local location = {zone_id = descriptor.zone_id, x = 3, y = 4, facing = "up"}
local ok, result = pcall(WorldMotionData.normalize, payload, descriptor, location, {})
assert(ok, result)
local actor = result.actors[1]
assert(actor.phase == "static" and actor.delay_raw == 0 and actor.delay_left == 0)
assert(payload.actors[1].phase == "delay", "normalize mutated the saved record")
print("delay-settled")
'''


class CinnabarTrainerDelayTest(unittest.TestCase):
    def test_the_shared_file_is_unchanged_and_the_patch_applies(self):
        source = MOTION.read_text()
        self.assertIn('invalid source actor delay', source)
        self.assertNotIn('sourceValue', source)
        check = subprocess.run(['git', 'apply', '--check', str(PATCH)], cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(check.returncode, 0, check.stderr)

    @unittest.expectedFailure
    def test_a_stationary_trainer_delay_from_seq_119_settles_static(self):
        probe = Path('/tmp/lane_b_delay_probe.lua')
        probe.write_text(PROBE)
        completed = subprocess.run(['lua5.4', str(probe), str(MOTION)], capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn('delay-settled', completed.stdout)


if __name__ == '__main__':
    unittest.main()
