#!/usr/bin/env python3
"""Talking to Mewtwo from a neighboring tile starts the level-70 battle.

data/maps/objects/CeruleanCaveB1F.asm object 1 is SPRITE_MONSTER at (27, 13),
STAY, DOWN, MEWTWO, 70. scripts/CeruleanCaveB1F.asm gives that trainer sight
0, so the battle starts from a talk on a neighboring tile, not a sight line.
home/trainers.asm EndTrainerBattle sets EVENT_BEAT_MEWTWO unless the battle
was lost. SourceEncounters has no registration API. The row is the handoff
in tools/notes/lane-e-mewtwo-encounter.patch. Without it, the cry plays and
prepare rejects the battle.

The A press is KantoWorld.tryInteract, the same call ExploreSubstate:interact
makes. The text confirm is the callback EventState:source stores for
_MewtwoBattleText. FieldBattle.startSourceEncounter and SourceEncounters.prepare
are the real functions.
"""

import json
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STORY = ROOT / "Source/data/postgame/story.json"
ENCOUNTERS = ROOT / "Source/domain/sourceEncounters.lua"

PROBE = r"""
local function skip_ws(text, i)
  while text:sub(i, i):match("%s") do i = i + 1 end
  return i
end
local function decode_at(text, i)
  i = skip_ws(text, i)
  local c = text:sub(i, i)
  if c == '"' then
    i = i + 1
    local out = {}
    while true do
      local n = text:sub(i, i)
      assert(n ~= "", "truncated string")
      if n == '"' then return table.concat(out), i + 1 end
      if n == "\\" then
        local e = text:sub(i + 1, i + 1)
        local map = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", n = "\n", r = "\r", t = "\t" }
        assert(map[e], "unsupported escape")
        out[#out + 1] = map[e]
        i = i + 2
      else
        out[#out + 1] = n
        i = i + 1
      end
    end
  elseif c == "{" then
    i = i + 1
    local out = {}
    i = skip_ws(text, i)
    if text:sub(i, i) == "}" then return out, i + 1 end
    while true do
      local key
      key, i = decode_at(text, i)
      i = skip_ws(text, i)
      assert(text:sub(i, i) == ":", "object colon")
      local value
      value, i = decode_at(text, i + 1)
      out[key] = value
      i = skip_ws(text, i)
      local mark = text:sub(i, i)
      if mark == "}" then return out, i + 1 end
      assert(mark == ",", "object comma")
      i = i + 1
    end
  elseif c == "[" then
    i = i + 1
    local out = {}
    i = skip_ws(text, i)
    if text:sub(i, i) == "]" then return out, i + 1 end
    while true do
      local value
      value, i = decode_at(text, i)
      out[#out + 1] = value
      i = skip_ws(text, i)
      local mark = text:sub(i, i)
      if mark == "]" then return out, i + 1 end
      assert(mark == ",", "array comma")
      i = i + 1
    end
  elseif c == "t" then
    assert(text:sub(i, i + 3) == "true")
    return true, i + 4
  elseif c == "f" then
    assert(text:sub(i, i + 4) == "false")
    return false, i + 5
  elseif c == "n" then
    assert(text:sub(i, i + 3) == "null")
    return nil, i + 4
  else
    local number = text:match("^-?%d+", i)
    assert(number, "json value")
    return tonumber(number), i + #number
  end
end
local function read_json(path)
  local handle = assert(io.open(path, "r"))
  local text = handle:read("*a")
  handle:close()
  local value = decode_at(text, 1)
  return value
end

Party = {}
function Party._primitive(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for key, item in pairs(value) do out[key] = Party._primitive(item) end
  return out
end
function Party._validPokemon(mon)
  return type(mon) == "table" and type(mon.is) == "function" and mon:is("Pokemon")
    and pokemonData[mon.species] ~= nil and mon.maxHP == 1 and mon.hp == 1
end
pokemonData = { mewtwo = true }

json = {}
function json.decodeFile(path)
  assert(path == "data/postgame/story.json", path)
  return read_json(story_path)
end

local registered = {}
SourceEvents = {}
SourceEventHandlers = {}
function SourceEvents.registerEventSource(name, events)
  for id, descriptor in pairs(events) do
    assert(descriptor.content == name, "event content")
    registered[id] = descriptor
  end
end
function SourceEvents.registerTextSource() end
function SourceEvents.registerWorldHooks() end
function SourceEvents.has(id) return registered[id] ~= nil end
function SourceEvents.worldHook() return false end
function SourceEvents.dispatch(game, id)
  assert(game.session:getIntro().stage == "done", "intro")
  assert(SourceEvents.has(id), "missing event")
  assert(not game.player.isMoving and not game.player.pendingEdgeDoor, "moving")
  assert(game.machine:getCurrent() == "overworld" and game.machine:get("event"), "executor")
  game.machine:push("event", id)
  return true
end

HideoutTowerController = { advance = function() return false end }
local cries = {}
currentName = "overworld"
KantoAudio = {}
function KantoAudio.playCry(species)
  cries[#cries + 1] = { species = species, where = currentName }
  return true
end

RulesRNG = {}
function RulesRNG.snapshot() return { seed = 1 } end
function RulesRNG.new()
  return { restore = function() end, snapshot = function() return { seed = 1 } end }
end
Specimen = {}
function Specimen.create(species, level, kind)
  assert(kind == "wild", "wild specimen")
  local enemy = { species = species, level = level, maxHP = 1, hp = 1 }
  function enemy:is(name) return name == "Pokemon" end
  function enemy:isAlive() return true end
  return enemy
end

local lead = {}
local party = {
  firstUsable = function() return 1 end,
  active = function() return lead end,
  get = function() return lead end,
}
local session = { _pending = nil }
function session:questFlag() return false end
function session:party() return party end
function session:inventory() return { quantity = function() return 0 end } end
function session:getIntro() return { stage = "done" } end
function session:flags() return { quest = {} } end
function session:prepareSourceEncounter(request, location)
  if self._pending then return nil, "source-encounter-already-active" end
  local ok, prepared = pcall(SourceEncounters.prepare, self, request, location)
  if not ok then return nil, tostring(prepared) end
  self._pending = prepared
  return prepared.token, prepared.enemy
end
function session:sourceEncounterToken(enemy)
  local prepared = self._pending
  return prepared and prepared.enemy == enemy and prepared.token or nil
end
function session:cancelSourceEncounter() self._pending = nil end
GameSession = { activeRNGSession = function() return session end }

dofile(encounters_path)
dofile(battle_path)
dofile(actors_path)
dofile(world_path)
dofile(postgame_path)

local MEWTWO = "pokered:CERULEAN_CAVE_B1F:objects:1"
local started = nil
local event = { epoch = 0, active = false }
function event:valid() return self.active end
function event:isTop() return currentName == "event" end
function event:source(labels, callback)
  assert(labels[1] == "_MewtwoBattleText", "mewtwo text")
  self.onConfirm = callback
end
function event:advance()
  HideoutTowerController.advance(self)
end
function event:fail(reason) error(reason, 0) end
function event:enter(id)
  self.epoch = self.epoch + 1
  self.active = true
  self.id = id
  self.session = session
  self.game = game
  self.player = game.player
  self.plan = SourceEventHandlers[id]({ flags = {} })
  assert(self.plan and self.plan.scene == "postgame" and self.plan.scene_script == "mewtwo",
    "plan " .. tostring(self.plan and self.plan.scene) .. " " .. tostring(self.plan and self.plan.scene_script))
  assert(self:valid() == true and self:isTop() == true,
    "ready " .. tostring(self:valid()) .. " top " .. tostring(self:isTop())
    .. " where " .. tostring(currentName) .. " active " .. tostring(self.active))
  local advanced = HideoutTowerController.advance(self)
  assert(advanced == true, "scene did not take the talk")
  assert(type(self.onConfirm) == "function", "cry text was not opened")
end

local machine = {}
function machine:getCurrent() return currentName end
function machine:get(name)
  if name == "event" then return event end
  if name == "battle" then return {} end
end
function machine:push(name, id)
  assert(currentName == "overworld" and name == "event", "push")
  currentName = "event"
  event:enter(id)
end
function machine:change(name, requested, enemy)
  assert(name == "battle", "battle")
  assert(requested == lead, "lead")
  currentName = "battle"
  started = { species = enemy.species, level = enemy.level }
end

currentZone = {
  stableID = "pokered:CERULEAN_CAVE_B1F",
  width = 40, height = 20,
  isSliceReady = function() return false end,
}
PCTerminals = { tryInteract = function() return false end }

local mewtwo = {
  gridX = 27, gridY = 13,
  def = { source_event_id = MEWTWO },
  faceTowards = function() end,
}
local player = { gridX = 27, gridY = 14, facing = "up", isMoving = false }
function player:getFacingTile()
  if self.facing == "up" then return self.gridX, self.gridY - 1 end
  if self.facing == "down" then return self.gridX, self.gridY + 1 end
  if self.facing == "left" then return self.gridX - 1, self.gridY end
  if self.facing == "right" then return self.gridX + 1, self.gridY end
end
local motion = { requestInteraction = function() return false end }
local npcManager = { motion = motion }
function npcManager:getNPCAt(x, y)
  if x == mewtwo.gridX and y == mewtwo.gridY then return mewtwo end
end
game = {
  player = player, session = session, machine = machine, npcManager = npcManager,
  getPlayerPokemon = function() return lead end,
}

local function reset()
  currentName = "overworld"
  started = nil
  cries = {}
  event.epoch = 0
  event.active = false
  event.onConfirm = nil
  event.plan = nil
  event.postgameScene = nil
  session._pending = nil
end

local found = false
local count = 0
for id in pairs(registered) do
  count = count + 1
  if id == MEWTWO then found = true end
end
assert(found, "mewtwo was not registered among " .. count)
assert(type(SourceEventHandlers[MEWTWO]) == "function", "handler")

local function press_a(x, y, facing)
  reset()
  player.gridX, player.gridY, player.facing = x, y, facing
  return KantoWorld.tryInteract(game)
end

assert(press_a(27, 14, "up") == true, "south talk")
assert(#cries == 1 and cries[1].species == "mewtwo" and cries[1].where == "event", "cry before battle")
assert(currentName == "event" and started == nil, "text is still up")
assert(type(event.onConfirm) == "function", "A dismisses the cry text")
event.onConfirm()
assert(currentName == "battle", "battle started")
assert(started.species == "mewtwo" and started.level == 70, "mewtwo level 70")

assert(press_a(26, 13, "right") == true, "west talk")
event.onConfirm()
assert(started.species == "mewtwo" and started.level == 70, "west neighbor")

assert(press_a(27, 15, "up") == false, "one tile south of the neighbor does not talk")
assert(#cries == 0 and currentName == "overworld", "no cry off the neighbor")

assert(press_a(27, 13, "down") == false, "standing on Mewtwo is not a talk")
local request = PostgameStory.mewtwoRequest({})
local ok, err = pcall(SourceEncounters.prepare, session, request, {
  zone_id = "pokered:CERULEAN_CAVE_B1F", x = 27, y = 13,
})
assert(not ok and tostring(err):find("outside-source-encounter-trigger", 1, true), "sprite tile is not a trigger")
"""


class MewtwoEncounterTests(unittest.TestCase):
    def test_neighbor_talk_starts_the_battle(self):
        story = json.loads(STORY.read_text())
        mewtwo = story["cave"]["mewtwo"]
        self.assertEqual(mewtwo["id"], "pokered:CERULEAN_CAVE_B1F:objects:1")
        self.assertEqual(mewtwo["species"], "MEWTWO")
        self.assertEqual(mewtwo["level"], 70)
        self.assertEqual([mewtwo["x"], mewtwo["y"]], [27, 13])
        self.assertEqual(mewtwo["positions"], [[27, 12], [27, 14], [26, 13], [28, 13]])
        text = ENCOUNTERS.read_text()
        self.assertIn('["pokered:CERULEAN_CAVE_B1F:objects:1"]', text)
        self.assertIn('species = "mewtwo", level = 70', text)
        header = "\n".join([
            "story_path = " + json.dumps(str(STORY)),
            "encounters_path = " + json.dumps(str(ROOT / "Source/domain/sourceEncounters.lua")),
            "battle_path = " + json.dumps(str(ROOT / "Source/game/fieldBattle.lua")),
            "actors_path = " + json.dumps(str(ROOT / "Source/world/sourceActors.lua")),
            "world_path = " + json.dumps(str(ROOT / "Source/game/kantoWorld.lua")),
            "postgame_path = " + json.dumps(str(ROOT / "Source/game/postgameStory.lua")),
        ])
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "probe.lua"
            path.write_text(header + "\n" + PROBE)
            completed = subprocess.run(
                ["lua5.4", str(path)],
                cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)


if __name__ == "__main__":
    unittest.main()
