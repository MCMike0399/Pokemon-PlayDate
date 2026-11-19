#!/usr/bin/env python3
"""Silph Co. clip review against pokered af519899 and the Gen V chart.

The rocket clip rests the bag cursor on SECRET KEY, then prints
"RED used REVIVE". Revive is numericId 53 and restores half of 150,
which is 75. SECRET KEY is numericId 43, a key item whose effect is
unsupported. No key item may take the revive branch.

The scientist clip prints "MAGNETON used MIRROR SHOT!" and, after
Venusaur answers with Double-Edge, "It's not very effective...".
Mirror Shot is steel. Gen V steel against grass/poison is 1. Double-Edge
is normal, and normal against Magneton's electric/steel is 0.5, so that
second line is the right matchup. pokered af519899 has no MIRROR_SHOT;
the port's id 429 is the B2W2 move, and the name and type stay together.

The same clips replace a battle line while it is still typing. A mashed
A finishes the line and confirms it on the next frame, so the box shows
a prefix and the next say takes its place. The patch makes the finished
line stay up. pokered home/print_text.asm PrintLetterDelay only shortens the
per-letter wait while A is held, and home/joypad2.asm
WaitForTextScrollButtonPress then requires a new press. The battle script
already waits MESSAGE_MIN_FRAMES (10) before that press can turn the page.
"""

import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
POKERED = Path.home() / 'Developer/Pokemon-PlayDate-env/pokered'
PATCH = ROOT / 'tools/notes/lane-e-battle-message.patch'
DIALOG = ROOT / 'Source/ui/dialog.lua'

PROBE = r'''
justPressed = false
held = false
playdate = {
  graphics = {
    kColorWhite = 1, kColorBlack = 0, kColorClear = 2, kDrawModeCopy = 0,
    getFont = function() return {} end,
    getTextSizeForMaxWidth = function() return 100, 14 end,
    getTextSize = function() return 8, 14 end,
    image = { new = function() return { draw = function() end } end },
    pushContext = function() end, popContext = function() end,
    setDrawOffset = function() end, clearClipRect = function() end,
    clearStencil = function() end, setImageDrawMode = function() end,
    setFont = function() end, clear = function() end,
    drawTextInRect = function() end, drawText = function() end,
    fillRect = function() end, drawRect = function() end, setColor = function() end,
  },
  kButtonA = 1,
  buttonJustPressed = function() return justPressed end,
  buttonIsPressed = function() return held end,
}
function import() end
function Class(name)
  local cls = {}
  cls.__index = cls
  setmetatable(cls, { __call = function(_, ...)
    local instance = setmetatable({}, cls)
    if instance.init then instance:init(...) end
    return instance
  end })
  _G[name] = cls
  return cls
end
GameOptions = { textSpeed = function() return "FAST" end }
SourceText = { nextBoundary = function(line, index) return index + 1 end }
SourceTextFont = {
  paginate = function(text) return {text} end,
  width = function(text) return #text end,
  draw = function() end,
}
dofile(arg[1])
local line = "VENUSAUR is damaged by recoil!"
local done = 0
local dialog = Dialog()
dialog:show({line}, function() done = done + 1 end)
local full = 0
for _ = 1, 40 do
  justPressed = true
  held = true
  dialog:update()
  dialog:handleInput()
  if done == 0 and dialog.isActive and dialog.charIndex >= #dialog.lines[1] then
    full = full + 1
  end
  if done > 0 then break end
end
print(full)
assert(done == 1, "the mashed A never confirmed")
'''


def run_lua(script, *args):
    completed = subprocess.run(
        ['lua5.4', '-e', script, *args], cwd=ROOT, capture_output=True, text=True)
    return completed


def magneton_moves(level):
    text = (ROOT / 'Source/data/pokemon.lua').read_text()
    match = re.search(r'magneton = \{.*?learnset = "([^"]+)"', text, re.S)
    if not match:
        raise AssertionError('magneton learnset missing')
    moves = []
    for row in match.group(1).split(';'):
        move, raw_level, _order, _move_id = row.split('|')
        learned = int(raw_level)
        if learned > level:
            break
        if learned < 1 or move in moves:
            continue
        if len(moves) == 4:
            del moves[0]
        moves.append(move)
    return moves


class LaneEBattleReviewTest(unittest.TestCase):
    def test_no_key_item_is_usable_in_battle(self):
        bag = (ROOT / 'Source/game/bagState.lua').read_text()
        battle = (ROOT / 'Source/battle/battle.lua').read_text()
        self.assertIn(
            'local medicine={heal=true,fullRestore=true,cure=true,revive=true,pp=true}', bag)
        self.assertIn('if self.battle and medicine[item.effect] then', bag)
        self.assertIn(
            'local legal={heal=true,fullRestore=true,cure=true,revive=true,pp=true}', battle)
        self.assertIn(
            'if not item or not legal[item.effect] then return false,"unsupported-item-use" end',
            battle)
        script = r'''
dofile("Source/data/items.lua")
moveData = { tackle = { maxPP = 35, noPP = false } }
dofile("Source/domain/items.lua")
local mon = {
  hp = 0, maxHP = 150, status = nil, statusTurns = 0, sleepDuration = 0,
  confusion = nil, moves = {"tackle"}, pp = {tackle = 10},
  is = function(_, class) return class == "Pokemon" end,
}
local keys = 0
local ids = {}
for id, item in pairs(ItemData.definitions) do
  assert(ids[item.numericId] == nil, "duplicate numeric id")
  ids[item.numericId] = id
  if item.keyItem then
    keys = keys + 1
    local plan, err = Items.planUse(id, mon)
    assert(plan == nil and err == "unsupported-item-use", id .. " -> " .. tostring(err))
    assert(mon.hp == 0, id)
    assert(item.effect ~= "revive" and item.effect ~= "heal" and item.effect ~= "fullRestore")
  end
end
assert(keys > 0)
assert(ItemData.definitions.secretKey.numericId == 43)
assert(ItemData.definitions.secretKey.name == "SECRET KEY")
assert(ItemData.definitions.revive.numericId == 53)
assert(ItemData.definitions.revive.effect == "revive")
local plan = Items.planUse("revive", mon)
assert(plan and plan.hpAfter == 75 and plan.revived and mon.hp == 0)
print("key-items-rejected")
'''
        completed = run_lua(script)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn('key-items-rejected', completed.stdout)

    def test_steel_against_grass_poison_is_neutral(self):
        moves = (POKERED / 'data/moves/moves.asm').read_text()
        evos = (POKERED / 'data/pokemon/evos_moves.asm').read_text()
        self.assertNotIn('MIRROR_SHOT', moves)
        block = evos.split('MagnetonEvosMoves:', 1)[1].split('KoffingEvosMoves:', 1)[0]
        self.assertIn('db 21, SONICBOOM', block)
        self.assertIn('db 25, THUNDERSHOCK', block)
        self.assertNotIn('MIRROR', block)
        script = r'''
dofile("Source/data/typechart.lua")
local steel = TypeChart.getMatchup("steel", "grass", "poison")
local normal = TypeChart.getMatchup("normal", "electric", "steel")
local electric = TypeChart.getMatchup("electric", "grass", "poison")
assert(steel == 1, steel)
assert(normal == 0.5, normal)
assert(electric == 0.5, electric)
print(steel)
'''
        completed = run_lua(script)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn('1.0', completed.stdout)
        learned = magneton_moves(28)
        self.assertIn('mirrorShot', learned)
        pokemon = (ROOT / 'Source/data/pokemon.lua').read_text()
        self.assertIn('mirrorShot|25|-|429', pokemon)
        move = (ROOT / 'Source/battle/moves.lua').read_text()
        mirror = re.search(r'mirrorShot = function\(\)\s*return Move\{([^}]*)\}', move)
        edge = re.search(r'doubleEdge = function\(\)\s*return Move\{([^}]*)\}', move)
        self.assertIsNotNone(mirror)
        self.assertIsNotNone(edge)
        self.assertIn('name = "MIRROR SHOT"', mirror.group(1))
        self.assertIn('type = "steel"', mirror.group(1))
        self.assertIn('type = "normal"', edge.group(1))

    def test_mashed_a_holds_the_finished_battle_line(self):
        probe = Path('/tmp/lane_e_battle_message_probe.lua')
        probe.write_text(PROBE)
        completed = subprocess.run(
            ['lua5.4', str(probe), str(DIALOG)], cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        full = int(completed.stdout.strip())
        self.assertGreaterEqual(full, 10)

    def test_the_message_patch_is_already_applied(self):
        check = subprocess.run(
            ['git', 'apply', '--check', str(PATCH)], cwd=ROOT, capture_output=True, text=True)
        self.assertNotEqual(check.returncode, 0, check.stderr)
        self.assertIn('pageShown', DIALOG.read_text())
        self.assertIn('MESSAGE_MIN_FRAMES <const> = 10', (ROOT / 'Source/battle/battle.lua').read_text())


if __name__ == '__main__':
    unittest.main()
