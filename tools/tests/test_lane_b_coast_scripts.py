#!/usr/bin/env python3
"""Coast story rules against the af519899 Seafoam, Mansion, quiz, and Blaine scripts."""

import json
import os
import re
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REF = Path(os.environ.get('POKERED_REFERENCE_DIR', Path.home() / 'Developer/Pokemon-PlayDate-env/pokered'))


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
local closed = {
  EVENT_SEAFOAM3_BOULDER1_DOWN_HOLE = true,
  EVENT_SEAFOAM3_BOULDER2_DOWN_HOLE = true,
}
local stairs = CoastStory.current("pokered:SEAFOAM_ISLANDS_B3F", 15, 8, {}, false)
assert(stairs and stairs.kind == "b3-stairs" and stairs.forced_warp and not stairs.surf)
assert(join(stairs.buttons) == "down,down,down,right,right,right,right,right,down,down,down,down,down,down")
assert(CoastStory.current("pokered:SEAFOAM_ISLANDS_B3F", 15, 8, closed, false) == nil)

local quiet = CoastStory.current("pokered:SEAFOAM_ISLANDS_B3F", 18, 7, closed, false)
assert(quiet == nil)
assert(CoastStory.current("pokered:SEAFOAM_ISLANDS_B3F", 18, 7, closed, true) == nil)
local left = CoastStory.current("pokered:SEAFOAM_ISLANDS_B3F", 18, 7, {}, true)
assert(left.surf and left.forced_warp and join(left.buttons) == "down,down,down,down,right,right,down,down,down,down,down,down")

local exit = CoastStory.current("pokered:SEAFOAM_ISLANDS_B4F", 20, 16, {}, false)
assert(join(exit.buttons) == "up" and exit.forced_warp == false)
assert(CoastStory.current("pokered:SEAFOAM_ISLANDS_B4F", 20, 16, closed, false) == nil)
local mouth = CoastStory.current("pokered:SEAFOAM_ISLANDS_B4F", 21, 17, {}, false)
assert(join(mouth.buttons) == "up,up")
assert(CoastStory.current("pokered:SEAFOAM_ISLANDS_B4F", 21, 17, closed, false) == nil)
local pool = CoastStory.current("pokered:SEAFOAM_ISLANDS_B4F", 4, 14, {}, true)
assert(pool.kind == "b4-left" and pool.surf and pool.dismount_before_last and pool.buttons[1] == "up")
assert(CoastStory.current("pokered:SEAFOAM_ISLANDS_B4F", 4, 14, {
  EVENT_SEAFOAM4_BOULDER1_DOWN_HOLE = true,
  EVENT_SEAFOAM4_BOULDER2_DOWN_HOLE = true,
}, true) == nil)

local fall = CoastStory.boulderFall("pokered:SEAFOAM_ISLANDS_B2F", 22, 6)
assert(fall.index == 2 and fall.flag == "EVENT_SEAFOAM3_BOULDER2_DOWN_HOLE")
local upper = CoastStory.boulderVisibility("pokered:SEAFOAM_ISLANDS_1F:objects:2")
assert(upper[1].group == "quest" and upper[1].id == "EVENT_SEAFOAM1_BOULDER2_DOWN_HOLE" and upper[1].equals == false)
assert(CoastStory.boulderVisible("pokered:SEAFOAM_ISLANDS_1F:objects:2", {}) == true)
assert(CoastStory.boulderVisible("pokered:SEAFOAM_ISLANDS_1F:objects:2", {
  EVENT_SEAFOAM1_BOULDER2_DOWN_HOLE = true,
}) == false)
local lower = CoastStory.boulderVisibility("pokered:SEAFOAM_ISLANDS_B1F:objects:2")
assert(lower[1].equals == true and lower[2].id == "EVENT_SEAFOAM2_BOULDER2_DOWN_HOLE" and lower[2].equals == false)
assert(CoastStory.boulderVisible("pokered:SEAFOAM_ISLANDS_B1F:objects:2", {}) == false)
assert(CoastStory.boulderVisible("pokered:SEAFOAM_ISLANDS_B1F:objects:2", {
  EVENT_SEAFOAM1_BOULDER2_DOWN_HOLE = true,
}) == true)
assert(CoastStory.boulderVisible("pokered:SEAFOAM_ISLANDS_B1F:objects:2", {
  EVENT_SEAFOAM1_BOULDER2_DOWN_HOLE = true,
  EVENT_SEAFOAM2_BOULDER2_DOWN_HOLE = true,
}) == false)
assert(CoastStory.boulderVisible("pokered:SEAFOAM_ISLANDS_B3F:objects:5", {}) == false)
assert(CoastStory.boulderVisible("pokered:SEAFOAM_ISLANDS_B3F:objects:5", {
  EVENT_SEAFOAM3_BOULDER1_DOWN_HOLE = true,
}) == true)
assert(CoastStory.boulderVisible("pokered:ROUTE_20:objects:1", {}) == true)
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
assert(CoastStory.currentTooFast("pokered:SEAFOAM_ISLANDS_B4F", 7, 11, {}) == true)
assert(CoastStory.currentTooFast("pokered:SEAFOAM_ISLANDS_B4F", 7, 11, {
  EVENT_SEAFOAM4_BOULDER1_DOWN_HOLE = true,
}) == true)
assert(CoastStory.currentTooFast("pokered:SEAFOAM_ISLANDS_B4F", 7, 11, {
  EVENT_SEAFOAM4_BOULDER1_DOWN_HOLE = true,
  EVENT_SEAFOAM4_BOULDER2_DOWN_HOLE = true,
}) == false)
assert(CoastStory.currentTooFast("pokered:SEAFOAM_ISLANDS_B4F", 7, 3, {}) == false)
assert(CoastStory.currentTooFast("pokered:SEAFOAM_ISLANDS_B3F", 18, 7, {}) == false)
assert(CoastStory.currentTooFast("pokered:SEAFOAM_ISLANDS_B3F", 7, 11, {}) == false)
local bird = CoastStory.articuno(false)
assert(bird.level == 50 and bird.x == 6 and bird.y == 1 and bird.flag == "EVENT_BEAT_ARTICUNO")
assert(CoastStory.articuno(true) == nil)
local request = CoastStory.articunoRequest({})
assert(request.id == bird.id and request.level == 50 and request.species == "articuno")
assert(request.rules.capture == true and request.rules.unidentified == false)
assert(request.outcomes.victory.flags.EVENT_BEAT_ARTICUNO == true)
assert(request.outcomes.caught.flags.EVENT_BEAT_ARTICUNO == true)
assert(request.outcomes.run.flags.EVENT_BEAT_ARTICUNO == true)
assert(request.outcomes.defeat.flags.EVENT_BEAT_ARTICUNO == nil)
assert(CoastStory.articunoRequest({ EVENT_BEAT_ARTICUNO = true }) == nil)
local plan = CoastStory.articunoPlan({ flags = {} })
assert(plan.scene == "coast-articuno" and plan.scene_script == "battle")
local done = CoastStory.articunoPlan({ flags = { EVENT_BEAT_ARTICUNO = true } })
assert(done.status == "already-complete")
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
assert(CoastStory.gateQuadrantSolid(0x2d, 0, 0) == false)
assert(CoastStory.gateQuadrantSolid(0x2d, 1, 0) == false)
assert(CoastStory.gateQuadrantSolid(0x2d, 0, 1) == true)
assert(CoastStory.gateQuadrantSolid(0x2d, 1, 1) == true)
assert(CoastStory.gateQuadrantSolid(0x5f, 0, 0) == false)
assert(CoastStory.gateQuadrantSolid(0x5f, 1, 0) == true)
assert(CoastStory.gateQuadrantSolid(0x5f, 0, 1) == false)
assert(CoastStory.gateQuadrantSolid(0x5f, 1, 1) == true)
assert(CoastStory.gateQuadrantSolid(0x54, 0, 0) == true)
assert(CoastStory.gateQuadrantSolid(0x54, 1, 0) == true)
assert(CoastStory.gateQuadrantSolid(0x54, 0, 1) == false)
assert(CoastStory.gateQuadrantSolid(0x54, 1, 1) == false)
assert(CoastStory.gateQuadrantSolid(0x0e, 0, 0) == false)
assert(CoastStory.gateQuadrantSolid(0x0e, 1, 1) == false)
local stairDoor = off[3]
assert(stairDoor.x == 10 and stairDoor.y == 8 and stairDoor.block == 0x2d)
assert(CoastStory.gateQuadrantSolid(stairDoor.block, 1, 0) == false)
assert(CoastStory.gateQuadrantSolid(stairDoor.block, 1, 1) == true)
local switchLines = CoastStory.switchLines()
assert(switchLines.prompt[1] == "A secret switch!")
assert(switchLines.prompt[2] == "Press it?")
assert(switchLines.pressed[1] == "Who wouldn't?")
assert(switchLines.declined[1] == "Not quite yet!")
local roster = CoastStory.gymRoster()
assert(#roster == 8)
local blaine = roster[1]
assert(blaine.leader and blaine.name == "BLAINE" and blaine.payout == 99 * 47)
assert(blaine.party[1].species == "growlithe" and blaine.party[1].level == 42)
assert(blaine.party[4].species == "arcanine" and blaine.party[4].level == 47)
assert(blaine.id == "pokered:CINNABAR_GYM:objects:1")
local events = CoastStory.gymEvents()
local leader = events[blaine.id]
assert(leader.kind == "trainer" and leader.content == "coastGym")
assert(leader.reward.item == "tm38" and leader.reward.flag == "EVENT_GOT_TM38")
assert(leader.victory.flags.BADGE_VOLCANO == true)
assert(leader.victory.flags.EVENT_BEAT_BLAINE == true)
assert(leader.before[1] == "_CinnabarGymBlainePreBattleText")
assert(leader.won[1] == "_CinnabarGymBlaineReceivedVolcanoBadgeText")
for index = 2, 8 do
  local row = roster[index]
  assert(row.payout == row.base * row.party[#row.party].level)
  assert(events[row.id].victory.flags[row.flag] == true)
  assert(events[row.id].victory.flags[row.gate] == true)
  assert(leader.victory.flags[row.flag] == true)
  assert(leader.victory.trainers[row.id] == true)
  print(string.format("gym %d %s %d %s %d", row.index, row.class_source, row.roster, row.party[#row.party].species, row.payout))
end
local wrong = CoastStory.quizAnswer(1, "no")
assert(wrong.opponent == 3 and roster[wrong.opponent].gate == "EVENT_CINNABAR_GYM_GATE1_UNLOCKED")
local nurse = events["pokered:CINNABAR_POKECENTER:objects:1"]
assert(nurse.kind == "program" and nurse.steps[1].op == "heal")
assert(nurse.steps[1].checkpoint.zone_id == "pokered:CINNABAR_ISLAND")
assert(nurse.steps[1].checkpoint.x == 11 and nurse.steps[1].checkpoint.y == 12)
local guide = events["pokered:CINNABAR_GYM:objects:9"]
assert(guide.kind == "cases")
assert(guide.cases[1].when.flags.EVENT_BEAT_BLAINE == true)
assert(guide.otherwise.steps[1].labels[1] == "_CinnabarGymGymGuideChampInMakingText")
print(string.format("blaine %d %d %d %d payout %d", blaine.party[1].level, blaine.party[2].level, blaine.party[3].level, blaine.party[4].level, blaine.payout))
print("coast-story-ok")
'''


def write_host():
    host = Path('/tmp/lane_b_coast_story_host.lua')
    host.write_text(HOST)
    return host


class CoastScriptTest(unittest.TestCase):
    def test_seafoam_mansion_and_quiz_match_the_pinned_scripts(self):
        host = write_host()
        completed = subprocess.run(
            [lua_binary(), str(host), str(ROOT / 'Source/game/coastStory.lua')],
            check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn('coast-story-ok', completed.stdout)

    def test_a_forced_current_hands_its_landing_warp_to_the_door(self):
        text = (ROOT / 'Source/game/coastStoryWorld.lua').read_text()
        start = text.index('local function doorAt')
        region = text[start:text.index('local function gymDoor', start)]
        self.assertIn('forcedWarp', region)
        self.assertIn('currentZone.doors', region)
        self.assertIn('pendingEdgeDoor', region)

    def test_mansion_gates_use_the_facility_quadrant(self):
        text = (ROOT / 'Source/game/coastStoryWorld.lua').read_text()
        start = text.index('local function setBlock')
        region = text[start:text.index('local function applyBlocks', start)]
        self.assertIn('CoastStory.gateQuadrantSolid', region)
        self.assertNotIn('block.solid', region)
        self.assertIn('function switchInteract', text)
        self.assertIn('coastSwitch', text)

    def test_blaine_matches_the_pinned_gym_script(self):
        parties = (REF / 'data/trainers/parties.asm').read_text()
        blaine = re.search(
            r'BlaineData:\s*db \$FF,\s*42,\s*GROWLITHE,\s*40,\s*PONYTA,\s*42,\s*RAPIDASH,\s*47,\s*ARCANINE,\s*0',
            parties)
        self.assertIsNotNone(blaine)
        nerd = re.search(r'SuperNerdData:(.*?)(?=\n\n[A-Za-z])', parties, re.S)
        burglar = re.search(r'BurglarData:(.*?)(?=\n\n[A-Za-z])', parties, re.S)
        self.assertIsNotNone(nerd and burglar)

        def parties_of(block):
            rows = []
            for line in block.group(1).splitlines():
                match = re.match(r'\s*db\s+(.+)', line)
                if not match or match.group(1).startswith('$FF'):
                    continue
                parts = [part.strip() for part in match.group(1).split(',')]
                level = int(parts[0])
                rows.append((level, [name for name in parts[1:] if name != '0']))
            return rows

        nerds = parties_of(nerd)
        burglars = parties_of(burglar)
        self.assertEqual(nerds[8], (36, ['VULPIX', 'VULPIX', 'NINETALES']))
        self.assertEqual(nerds[9], (34, ['PONYTA', 'CHARMANDER', 'VULPIX', 'GROWLITHE']))
        self.assertEqual(nerds[10], (41, ['RAPIDASH']))
        self.assertEqual(nerds[11], (37, ['GROWLITHE', 'VULPIX']))
        self.assertEqual(burglars[3], (36, ['GROWLITHE', 'VULPIX', 'NINETALES']))
        self.assertEqual(burglars[4], (41, ['PONYTA']))
        self.assertEqual(burglars[5], (37, ['VULPIX', 'GROWLITHE']))
        script = (REF / 'scripts/CinnabarGym.asm').read_text()
        for token in (
            'SetEvent EVENT_BEAT_BLAINE', 'TM_FIRE_BLAST', 'SetEvent EVENT_GOT_TM38',
            'BIT_VOLCANOBADGE',
            'SetEventRange EVENT_BEAT_CINNABAR_GYM_TRAINER_0, EVENT_BEAT_CINNABAR_GYM_TRAINER_6',
            '_CinnabarGymBlainePreBattleText', '_CinnabarGymBlaineReceivedVolcanoBadgeText',
            '_CinnabarGymBlaineVolcanoBadgeInfoText', '_CinnabarGymBlaineReceivedTM38Text',
        ):
            self.assertIn(token, script)
        money = (REF / 'data/trainers/pic_pointers_money.asm').read_text()
        self.assertIn('pic_money BlainePic,       9900', money)
        self.assertIn('base money × level of last enemy mon', money)
        host = write_host()
        completed = subprocess.run(
            [lua_binary(), str(host), str(ROOT / 'Source/game/coastStory.lua')],
            check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn('blaine 42 40 42 47 payout 4653', completed.stdout)
        world = (ROOT / 'Source/game/coastStoryWorld.lua').read_text()
        self.assertIn('CoastStory.gymEvents()', world)
        self.assertIn('registerTrainerSource("coastGym", CoastStory.gymTrainers)', world)
        story = (ROOT / 'Source/game/coastStory.lua').read_text()
        center = json.loads((ROOT / 'Source/data/zCoast/events.json').read_text())
        nurse = center['events']['pokered:CINNABAR_POKECENTER:objects:1']['steps'][0]
        self.assertEqual(nurse['op'], 'heal')
        self.assertEqual(nurse['checkpoint'], {
            'facing': 'down', 'x': 11, 'y': 12, 'zone_id': 'pokered:CINNABAR_ISLAND',
        })
        for token in (
            'pokered:CINNABAR_POKECENTER:objects:1', nurse['welcome'], nurse['prompt'],
            nurse['before'], nurse['after'], nurse['farewell'], 'CinnabarPokecenter',
        ):
            self.assertIn(token, story)


if __name__ == '__main__':
    unittest.main()
