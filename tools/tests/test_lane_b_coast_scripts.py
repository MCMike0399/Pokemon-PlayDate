#!/usr/bin/env python3
"""Coast story rules against the af519899 Seafoam, Mansion, and quiz scripts."""

import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def lua_binary():
    for name in ('lua5.4', 'lua'):
        found = shutil.which(name)
        if found:
            return found
    raise AssertionError('Lua 5.4 is required')


HOST = r'''
dofile(arg[1])
local function join(list)
  return table.concat(list or {}, ",")
end
local stairs = CoastStory.current("pokered:SEAFOAM_ISLANDS_B3F", 15, 8, {
  EVENT_SEAFOAM3_BOULDER1_DOWN_HOLE = true,
  EVENT_SEAFOAM3_BOULDER2_DOWN_HOLE = true,
}, false)
assert(stairs and stairs.kind == "b3-stairs" and stairs.forced_warp and not stairs.surf)
assert(join(stairs.buttons) == "down,down,down,right,right,right,right,right,down,down,down,down,down,down")
assert(CoastStory.current("pokered:SEAFOAM_ISLANDS_B3F", 15, 8, {}, false) == nil)

local quiet = CoastStory.current("pokered:SEAFOAM_ISLANDS_B3F", 18, 7, {
  EVENT_SEAFOAM3_BOULDER1_DOWN_HOLE = true,
  EVENT_SEAFOAM3_BOULDER2_DOWN_HOLE = true,
}, false)
assert(quiet == nil)
local left = CoastStory.current("pokered:SEAFOAM_ISLANDS_B3F", 18, 7, {
  EVENT_SEAFOAM3_BOULDER1_DOWN_HOLE = true,
  EVENT_SEAFOAM3_BOULDER2_DOWN_HOLE = true,
}, true)
assert(left.surf and left.forced_warp and join(left.buttons) == "down,down,down,down,right,right,down,down,down,down,down,down")

local exit = CoastStory.current("pokered:SEAFOAM_ISLANDS_B4F", 20, 16, {
  EVENT_SEAFOAM3_BOULDER1_DOWN_HOLE = true,
  EVENT_SEAFOAM3_BOULDER2_DOWN_HOLE = true,
}, false)
assert(join(exit.buttons) == "up" and exit.forced_warp == false)
local mouth = CoastStory.current("pokered:SEAFOAM_ISLANDS_B4F", 21, 17, {
  EVENT_SEAFOAM3_BOULDER1_DOWN_HOLE = true,
  EVENT_SEAFOAM3_BOULDER2_DOWN_HOLE = true,
}, false)
assert(join(mouth.buttons) == "up,up")

local fall = CoastStory.boulderFall("pokered:SEAFOAM_ISLANDS_B2F", 22, 6)
assert(fall.index == 2 and fall.flag == "EVENT_SEAFOAM3_BOULDER2_DOWN_HOLE")
local drop = CoastStory.playerHole("pokered:SEAFOAM_ISLANDS_B3F", 6, 16, false)
assert(drop.entry == "SeafoamIslandsB4F" and drop.x == 5 and drop.y == 14)
assert(CoastStory.playerHole("pokered:SEAFOAM_ISLANDS_B3F", 6, 16, true) == nil)
local mansion = CoastStory.playerHole("pokered:POKEMON_MANSION_3F", 19, 14, false)
assert(mansion.entry == "PokemonMansion2F" and mansion.x == 18 and mansion.y == 14)

local quiz = CoastStory.quizAt(15, 7)
assert(quiz.index == 1 and quiz.answer == "yes")
local right = CoastStory.quizAnswer(1, "yes")
assert(right.correct and right.flag == "EVENT_CINNABAR_GYM_GATE1_UNLOCKED")
local wrong = CoastStory.quizAnswer(2, "yes")
assert(wrong.correct == false and wrong.opponent == 4)
assert(CoastStory.quizAnswer(6, "no").flag == "EVENT_CINNABAR_GYM_GATE6_UNLOCKED")

local door = CoastStory.gymDoor(18, 4, false)
assert(door.step == "down" and door.text[1] == "The door is")
assert(CoastStory.gymDoor(18, 4, true) == nil)

local closed = CoastStory.gymGates({})
assert(closed[1].x == 9 and closed[1].y == 3 and closed[1].solid and closed[1].block == 0x54)
local open = CoastStory.gymGates({ EVENT_CINNABAR_GYM_GATE1_UNLOCKED = true })
assert(open[1].solid == false and open[1].block == 0x0e and open[6].solid)

local off = CoastStory.mansionDoors("pokered:POKEMON_MANSION_1F", false)
assert(off[1].x == 12 and off[1].y == 6 and off[1].solid == false)
assert(off[2].block == 0x2d and off[2].solid)
local on = CoastStory.mansionDoors("pokered:POKEMON_MANSION_1F", true)
assert(on[1].solid and on[2].solid == false)
assert(CoastStory.mansionSwitch("pokered:POKEMON_MANSION_B1F", 18, 25).facing == "up")
assert(CoastStory.switchDecision(false, true).on == true)
assert(CoastStory.switchDecision(true, false).changed == false)

local key = CoastStory.secretKey()
assert(key.x == 5 and key.y == 13 and key.item == "secretKey")
local bird = CoastStory.articuno(false)
assert(bird.level == 50 and bird.x == 6 and bird.y == 1 and bird.flag == "EVENT_BEAT_ARTICUNO")
assert(CoastStory.articuno(true) == nil)
local flags = CoastStory.scriptFlags("pokered:SEAFOAM_ISLANDS_1F")
assert(flags.set.EVENT_IN_SEAFOAM_ISLANDS)
local island = CoastStory.scriptFlags("pokered:CINNABAR_ISLAND")
assert(island.clear.EVENT_MANSION_SWITCH_ON and island.clear.EVENT_LAB_STILL_REVIVING_FOSSIL)
local water = { water_candidate = true, foot_tile = 0x14 }
local shore = { water_candidate = false, foot_tile = 0x30 }
assert(CoastStory.surfEdge(true, water, water, true))
assert(CoastStory.surfEdge(false, water, water, true) == false)
assert(CoastStory.surfEdge(true, shore, water, true) == false)
assert(CoastStory.surfEdge(true, water, water, false) == false)
local first = CoastStory.quizLines(1)
assert(first.question == "CATERPIE evolves into BUTTERFREE?")
assert(first.correct[1] == "You're absolutely correct!")
assert(first.incorrect[1] == "Sorry! Bad call!")
assert(CoastStory.quizLines(2).question == "There are 9 certified #MON LEAGUE BADGEs?")
assert(CoastStory.quizLines(3).question == "POLIWAG evolves 3 times?")
assert(CoastStory.quizLines(4).question == "Are thunder moves effective against ground element-type #MON?")
assert(CoastStory.quizLines(5).question == "#MON of the same kind and level are not identical?")
assert(CoastStory.quizLines(6).question == "TM28 contains TOMBSTONER?")
assert(CoastStory.quizLines(7) == nil)
print("coast-story-ok")
'''


class CoastScriptTest(unittest.TestCase):
    def test_seafoam_mansion_and_quiz_match_the_pinned_scripts(self):
        host = Path('/tmp/lane_b_coast_story_host.lua')
        host.write_text(HOST)
        completed = subprocess.run(
            [lua_binary(), str(host), str(ROOT / 'Source/game/coastStory.lua')],
            check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn('coast-story-ok', completed.stdout)


if __name__ == '__main__':
    unittest.main()
