#!/usr/bin/env python3
"""Mewtwo outcomes follow scripts/CeruleanCaveB1F.asm.

pret/pokered af519899 scripts/CeruleanCaveB1F.asm:

    def_script_pointers
        dw CheckFightingMapTrainers
        dw DisplayEnemyTrainerTextAndStartBattle
        dw EndTrainerBattle

    MewtwoTrainerHeader:
        trainer EVENT_BEAT_MEWTWO, 0, MewtwoBattleText, MewtwoBattleText, MewtwoBattleText

home/trainers.asm EndTrainerBattle compares wIsInBattle with LOST_BATTLE.
That value skips the flag and leaves the object. Every other result calls
TrainerFlagAction FLAG_SET. Mewtwo's class is below OPP_ID_OFFSET, so
HideObject runs too.

engine/battle/core.asm .canEscape stores wBattleResult 2 and returns.
_InitBattleCommon then calls EndOfBattle, which clears wIsInBattle before
EndTrainerBattle. Only .allPokemonFainted writes LOST_BATTLE. A run therefore
sets EVENT_BEAT_MEWTWO and hides the object. A blackout does not. A catch
and a KO do, and a second prepare is already-complete, so he does not respawn.

story.json hide_on is victory, caught, run. stay_on is defeat. Those lists
already match this path, so this test passes on the current tree and there
is no outcome patch. A sentence that groups a run with a blackout does not
match EndTrainerBattle. MallocPoolSize stays 16645684. No skip.
"""

import json
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

PROBE = r"""
Party = {}
function Party._primitive(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, item in pairs(value) do
        out[key] = Party._primitive(item)
    end
    return out
end
RulesRNG = {}
function RulesRNG.snapshot() return { seed = 1 } end
function RulesRNG.new()
    return {
        restore = function() end,
        snapshot = function() return { seed = 1 } end,
    }
end
Specimen = {}
function Specimen.create(species, level, kind)
    assert(kind == "wild" and species == "mewtwo" and level == 70, species)
    return { species = species, level = level }
end
local hidden = false
local session = {}
function session:questFlag() return hidden end
function session:inventory()
    return { quantity = function() return 0 end }
end
function session:party()
    return { firstUsable = function() return 1 end }
end
function session:fieldWorldEpoch() return 7 end
GameSession = {}
function GameSession.activeRNGSession() return session end
dofile(__SOURCE__)
local request = {
    id = "pokered:CERULEAN_CAVE_B1F:objects:1",
    zone_id = "pokered:CERULEAN_CAVE_B1F",
    species = "mewtwo",
    level = 70,
    rules = { capture = true, unidentified = false },
    guards = { flags = { EVENT_BEAT_MEWTWO = false }, items = {} },
    outcomes = {
        victory = { flags = { EVENT_BEAT_MEWTWO = true } },
        caught = { flags = { EVENT_BEAT_MEWTWO = true } },
        run = { flags = { EVENT_BEAT_MEWTWO = true } },
        defeat = { flags = {} },
    },
}
local location = { zone_id = "pokered:CERULEAN_CAVE_B1F", x = 26, y = 13 }
local plan = assert(SourceEncounters.prepare(session, request, location))
local function flagsText(result)
    local names = {}
    for key, value in pairs(result.flags) do
        names[#names + 1] = key .. "=" .. tostring(value)
    end
    table.sort(names)
    if #names == 0 then return "(none)" end
    return table.concat(names, ",")
end
local function finish(kind, won)
    local player = { isAlive = function() return kind ~= "defeat" end }
    local enemy = { isAlive = function() return kind ~= "victory" end }
    local party = {
        active = function() return player end,
        firstUsable = function() return 1 end,
    }
    function session:party() return party end
    local battle = {
        session = session, party = party, player = player, enemy = enemy,
        emittingEnd = true, endEmitted = true, outcome = kind,
        hasUsablePlayer = function() return kind ~= "defeat" end,
    }
    local record = {
        phase = "active", battle = battle, party = party, enemy = enemy,
        fieldEpoch = 7, definition = plan.definition,
        guards = { flags = { EVENT_BEAT_MEWTWO = false }, items = {} },
        policy = { unidentified = false },
    }
    if kind == "caught" then
        record.capture = { caught = true, enemy = enemy, result = "ok" }
        battle.caughtPokemon = enemy
        battle.captureResult = "ok"
    end
    local result = SourceEncounters.terminal(session, record, battle, won, kind)
    print(kind .. " " .. flagsText(result) .. " completed=" .. tostring(result.completed))
end
finish("caught", false)
finish("victory", true)
finish("run", false)
finish("defeat", false)
hidden = true
local ok, err = pcall(SourceEncounters.prepare, session, request, location)
assert(not ok and tostring(err):find("already-complete", 1, true), tostring(err))
print("respawn already-complete")
"""


def function_body(text, name):
    start = text.split("function " + name, 1)[1]
    return start.split("\nfunction ", 1)[0]


class MewtwoOutcomeTests(unittest.TestCase):
    def test_catch_ko_and_run_hide_and_blackout_stays(self):
        script = ROOT / "Source/domain/sourceEncounters.lua"
        code = PROBE.replace("__SOURCE__", json.dumps(str(script)))
        result = subprocess.run(
            ["lua5.4", "-e", code],
            capture_output=True, text=True, check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        self.assertIn("caught EVENT_BEAT_MEWTWO=true completed=true", result.stdout)
        self.assertIn("victory EVENT_BEAT_MEWTWO=true completed=true", result.stdout)
        self.assertIn("run EVENT_BEAT_MEWTWO=true completed=true", result.stdout)
        self.assertIn("defeat (none) completed=false", result.stdout)
        self.assertIn("respawn already-complete", result.stdout)

    def test_story_hides_on_victory_caught_and_run(self):
        story = json.loads((ROOT / "Source/data/postgame/story.json").read_text(encoding="utf-8"))
        battle = story["cave"]["mewtwo"]["battle"]
        self.assertEqual(battle["hide_on"], ["victory", "caught", "run"])
        self.assertEqual(battle["stay_on"], ["defeat"])
        self.assertEqual(battle["lost_marker"], "LOST_BATTLE")
        self.assertEqual(battle["source"], "home/trainers.asm:EndTrainerBattle")
        postgame = (ROOT / "Source/game/postgameStory.lua").read_text(encoding="utf-8")
        request = function_body(postgame, "PostgameStory.staticRequest(id, flags)")
        self.assertIn("row.battle.hide_on", request)
        self.assertIn("row.battle.stay_on", request)
        self.assertIn('assert(flags[flag] ~= true, "already-complete")', request)
        visibility = function_body(postgame, "PostgameStory.visibility(id)")
        self.assertIn("equals = false", visibility)


if __name__ == "__main__":
    unittest.main()
