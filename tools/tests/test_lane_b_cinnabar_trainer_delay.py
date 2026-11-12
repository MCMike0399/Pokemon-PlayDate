#!/usr/bin/env python3
"""Why sequence 119 stored a delay for Cinnabar Gym's STAY objects.

pokered af519899 data/maps/objects/CinnabarGym.asm gives Blaine, the seven
Super Nerds and the guide movement STAY and facing DOWN. CanWalkOntoTile
rejects STAY ($FF) before a step, so those sprites never update MAPX/MAPY.
EVENT_2A7 is set after a Cinnabar Gym battle and cleared by
CinnabarGymSetMapAndTiles, and nothing in af519899 reads it. Sequence 119
was saved before any gym battle. All nine actors are still on their
object_event tiles. They are in phase delay because SourceActors marks every
non-trainer, non-item, non-boulder random, and NPCMotion then writes a
wander delay for any random actor that is not taking a WALK step.

Lane A rejected tools/notes/lane-a-cinnabar-trainer-delay.patch's first
version, which rewrote that delay to static inside WorldMotionData.normalize
and kept the saved cell. That would leave a STAY object off its tile if it
had wandered. The replacement patch is the cause: only WALK is random.
normalize still rejects a delay on a stationary actor. Drop the
expectedFailure decorator once lane A applies the patch.
"""

import json
import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / 'tools/notes/lane-a-cinnabar-trainer-delay.patch'
ACTORS = ROOT / 'Source/world/sourceActors.lua'
MOTION = ROOT / 'Source/domain/worldMotion.lua'
ASM = Path.home() / 'Developer/Pokemon-PlayDate-env/pokered/data/maps/objects/CinnabarGym.asm'
SAVE = Path('/opt/cursor/artifacts/lane-b/seq119-adventure.a.json')

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
local spec = {
  id = "pokered:CINNABAR_GYM:objects:1", random = false, movement = "STAY",
  faces = {down = true}, facing = "down", x = 3, y = 3, visibility = {},
}
local initial = WorldMotionData.initial(spec)
assert(initial.phase == "static" and initial.x == 3 and initial.y == 3, "STAY must start on its object tile")
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
print("stay-delay-still-rejected")
'''


def random_expression(source):
    match = re.search(r'random=(.+?),visibility=', source)
    if not match:
        raise AssertionError('random assignment missing')
    return match.group(1)


def random_for(source, movement, boulder=False, trainer=False, item=False):
    expr = random_expression(source).replace('event.movement', repr(movement))
    return eval(expr, {'boulder': boulder, 'trainer': trainer, 'item': item})


def object_events():
    rows = []
    for line in ASM.read_text().splitlines():
        match = re.match(r'\tobject_event\s+(\d+),\s+(\d+),\s+\S+,\s+STAY,\s+DOWN,', line)
        if match:
            rows.append((int(match.group(1)), int(match.group(2))))
    return rows


class CinnabarTrainerDelayTest(unittest.TestCase):
    def test_seq_119_stay_actors_are_on_their_object_tiles(self):
        tiles = object_events()
        self.assertEqual(len(tiles), 9)
        script = ASM.read_text()
        self.assertIn('object_event  3,  3, SPRITE_MIDDLE_AGED_MAN, STAY, DOWN, TEXT_CINNABARGYM_BLAINE', script)
        events = [line for line in script.splitlines() if line.startswith('\tobject_event')]
        self.assertEqual(len(events), 9)
        self.assertTrue(all(', STAY, DOWN,' in line for line in events))
        save = json.loads(json.loads(SAVE.read_text())['payload'])
        actors = save['worldMotion']['actors']['actors']
        self.assertEqual(len(actors), 9)
        for index, (x, y) in enumerate(tiles, 1):
            actor = next(row for row in actors if row['id'].endswith(f':objects:{index}'))
            self.assertEqual((actor['x'], actor['y']), (x, y))
            self.assertEqual(actor['facing'], 'down')
            self.assertEqual(actor['phase'], 'delay')
            self.assertEqual((actor['origin_x'], actor['origin_y']), (x, y))

    def test_the_shared_files_are_unchanged_and_the_patch_applies(self):
        source = ACTORS.read_text()
        self.assertIn('random=not boulder and not trainer and not item,visibility={}', source)
        self.assertNotIn('event.movement=="WALK"', source)
        self.assertNotIn('sourceValue', MOTION.read_text())
        self.assertIn('invalid source actor delay', MOTION.read_text())
        check = subprocess.run(['git', 'apply', '--check', str(PATCH)], cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(check.returncode, 0, check.stderr)
        patched = subprocess.run(['git', 'apply', '--numstat', str(PATCH)], cwd=ROOT, capture_output=True, text=True)
        self.assertIn('Source/world/sourceActors.lua', patched.stdout)
        applied = source.replace(
            'random=not boulder and not trainer and not item,visibility={}',
            'random=event.movement=="WALK" and not boulder and not trainer and not item,visibility={}',
            1)
        self.assertFalse(random_for(applied, 'STAY'))
        self.assertTrue(random_for(applied, 'WALK'))
        self.assertFalse(random_for(applied, 'WALK', trainer=True))
        self.assertFalse(random_for(applied, 'STAY', item=True))
        probe = Path('/tmp/lane_b_stay_probe.lua')
        probe.write_text(PROBE)
        completed = subprocess.run(['lua5.4', str(probe), str(MOTION)], capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn('stay-delay-still-rejected', completed.stdout)

    @unittest.expectedFailure
    def test_a_stay_object_is_not_marked_random(self):
        self.assertFalse(random_for(ACTORS.read_text(), 'STAY'))


if __name__ == '__main__':
    unittest.main()
