-- Host: secondary lines wait until after the crit and effectiveness lines.
-- Not part of the Playdate build.
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

local realRandom = RulesRNG.random
function RulesRNG.random(a, b)
    -- Secondary chances and accuracy use 1..100. Crit rolls use 1..16 or 1..8.
    if a == 1 and b == 100 then return 1 end
    if a == 1 and (b == 16 or b == 8) then return 2 end
    return realRandom(a, b)
end

local function drain(battle)
    local lines = {}
    local script = battle.machine:get("script")
    local guard = 0
    while battle:phase() == "script" do
        guard = guard + 1
        if guard > 200 then error("script did not finish: " .. tostring(battle.message)) end
        lines[#lines + 1] = battle.message or ""
        script.waiting = false
        battle.presentationRequest = nil
        script:advance()
    end
    return table.concat(lines, "\n")
end

local function own(mon, moves)
    mon.moves = moves
    mon.pp = {}
    for _, key in ipairs(moves) do mon.pp[key] = moveData[key].maxPP end
end

local function strike(label, attackerSpecies, defenderSpecies, moveKey, crit)
    RulesRNG.seed(1)
    moveData[moveKey].willCrit = crit or nil
    local player = Pokemon(attackerSpecies, 50)
    local enemy = Pokemon(defenderSpecies, 50)
    player.maxHP, player.hp = 999, 999
    enemy.maxHP, enemy.hp = 999, 999
    own(player, {moveKey})
    own(enemy, {"splash"})
    local party = Party()
    assert(party:add(player))
    local foes = Party()
    assert(foes:add(enemy))
    local battle = Battle(player, enemy, "LORELEI", {party = party, enemyParty = foes})
    drain(battle)
    local before = enemy.hp
    battle:runScript(function()
        return battle:resolveRound({
            {side = "player", actor = player, key = moveKey, move = moveData[moveKey]},
        })
    end)
    local text = drain(battle)
    moveData[moveKey].willCrit = nil
    io.write("case " .. label .. "\n")
    io.write("dealt " .. tostring(before - enemy.hp) .. "\n")
    io.write("---\n")
    io.write(text)
    io.write("\n====\n")
end

strike("burn", "charizard", "slowbro", "flamethrower", false)
strike("stat", "slowbro", "blastoise", "bubbleBeam", false)
strike("crit", "charizard", "slowbro", "flamethrower", true)
