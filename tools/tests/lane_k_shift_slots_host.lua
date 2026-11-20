-- Party-shift YES/NO skipped when the lead has fainted.
-- pret/pokered af519899 engine/battle/core.asm HandleEnemyMonFainted:
-- a fainted battle mon goes through ChooseNextMon, then
-- ReplaceFaintedEnemyMon. That still prints _TrainerAboutToUseText and
-- opens TWO_OPTION_MENU (data/text/text_2.asm) when BIT_BATTLE_SHIFT is
-- clear and the party has a bench. The clips miss that question for
-- Lapras after Lorelei and for Onix with Weepinbell on the bench.
local ROOT = assert(arg[1], "repo path required")
local SOURCE = ROOT .. "/Source/"

local loaded = {}
local function loadPlaydate(path)
    local handle = assert(io.open(path, "r"))
    local source = assert(handle:read("a"))
    handle:close()
    source = source:gsub("([%w_%.]+)%s*([%+%-])=%s*", "%1 = %1 %2 ")
    return assert(load(source, "@" .. path))
end
function import(name)
    if loaded[name] then return end
    loaded[name] = true
    local ok, problem = pcall(loadPlaydate, SOURCE .. name .. ".lua")
    if not ok then loaded[name] = nil; error(problem) end
    local chunk = problem
    ok, problem = pcall(chunk)
    if not ok then loaded[name] = nil; error(problem) end
end

playdate = {
    kButtonA = 1,
    buttonJustPressed = function() return false end,
    buttonIsPressed = function() return false end,
    datastore = { read = function() return nil end },
}

import "lib/oop"
import "lib/rng"
import "lib/statemachine"
import "data/individualData"
import "domain/individualStats"
import "data/pokemon"
import "domain/party"
import "data/typechart"
import "battle/dsl"
import "battle/moves"
import "domain/decimalInteger"
import "domain/gameSession"
import "domain/npcTrades"
import "domain/pokemonCodec"
import "battle/battle"

local function drain(battle)
    local lines = {}
    local script = battle.machine:get("script")
    local guard = 0
    while battle:phase() == "script" and not battle.shiftChoice do
        guard = guard + 1
        if guard > 80 then error("script did not finish: " .. tostring(battle.message)) end
        lines[#lines + 1] = battle.message
        script.waiting = false
        battle.presentationRequest = nil
        script:advance()
    end
    return table.concat(lines, "\n")
end

local function faintInto(trainer, foeSpecies, foeLevel, nextSpecies, nextLevel)
    assert(GameOptions.set("battleStyle", "SHIFT"))
    local lead = Pokemon("charizard", 100)
    local bench = Pokemon("weepinbell", 100)
    local foe = Pokemon(foeSpecies, foeLevel)
    local incoming = Pokemon(nextSpecies, nextLevel)
    local roster = Party()
    assert(roster:add(lead))
    assert(roster:add(bench))
    local foes = Party()
    assert(foes:add(foe))
    assert(foes:add(incoming))
    local battle = Battle(lead, foe, trainer, {party = roster, enemyParty = foes})
    drain(battle)
    foe.hp = 0
    lead.hp = 0
    battle.presentationAttached = true
    battle:runScript(function()
        local result = battle:handleFaint("enemy")
        if result ~= "replacement" then return result end
        return battle:finishRound()
    end)
    local log = drain(battle)
    if not battle.shiftChoice then
        error(trainer .. " sent " .. battle.enemy.name .. " without YES/NO\n" .. log)
    end
    if battle.enemy ~= foe then
        error(trainer .. " replaced " .. foe.name .. " before the question; active is " .. battle.enemy.name)
    end
    if battle.message ~= "Will RED\nchange POKéMON?" then
        error(trainer .. " question was [" .. tostring(battle.message) .. "]")
    end
    return true
end

-- Bruno's Onix faints. Weepinbell is benched. Hitmonchan must not come
-- out until the SHIFT question is on screen.
faintInto("BRUNO", "onix", 53, "hitmonchan", 55)
-- Lorelei's Jynx faints. Lapras is the next send-out.
faintInto("LORELEI", "jynx", 56, "lapras", 56)
print("shift-slots-held")
