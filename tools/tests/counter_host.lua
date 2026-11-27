-- Host: Bruno's AI uses Counter after the player's move.
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
import "data/fieldMoveBattleData"
import "domain/decimalInteger"
import "domain/gameSession"
import "domain/npcTrades"
import "domain/pokemonCodec"
import "battle/battle"

local realRandom = RulesRNG.random
local suppressCrit = false
function RulesRNG.random(a, b)
    -- Stage 0 crits roll 1..16 and stage 1 rolls 1..8. Force a miss of that roll.
    if suppressCrit and a == 1 and (b == 16 or b == 8) then return 2 end
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

local armed = nil
local function fight(label, moveKey, crit)
    RulesRNG.seed(1)
    suppressCrit = not crit
    if armed then moveData[armed].willCrit = nil end
    moveData[moveKey].willCrit = crit or nil
    armed = moveKey
    local player = Pokemon("charizard", 65)
    local enemy = Pokemon("hitmonchan", 55)
    player.maxHP, player.hp = 999, 999
    enemy.maxHP, enemy.hp = 999, 999
    own(player, {moveKey})
    -- Earthquake is immune to Fire/Flying, so Bruno's scorer leaves Counter.
    own(enemy, {"counter", "earthquake"})
    local party = Party()
    assert(party:add(player))
    local foes = Party()
    assert(foes:add(enemy))
    local battle = Battle(player, enemy, "BRUNO", {party = party, enemyParty = foes})
    battle.trainerClass = "BRUNO"
    drain(battle)
    if battle:phase() ~= "command" then
        error(label .. " did not reach command: " .. tostring(battle:phase()))
    end
    local beforePlayer, beforeEnemy = player.hp, enemy.hp
    assert(battle:selectMove(1))
    local text = drain(battle)
    io.write("case " .. label .. "\n")
    io.write("move " .. moveKey .. "\n")
    io.write("crit-line " .. tostring(text:find("A critical hit!", 1, true) ~= nil) .. "\n")
    io.write("counter-line " .. tostring(text:find("HITMONCHAN used COUNTER!", 1, true) ~= nil) .. "\n")
    io.write("failed-line " .. tostring(text:find("But it failed!", 1, true) ~= nil) .. "\n")
    io.write("dealt " .. tostring(beforeEnemy - enemy.hp) .. "\n")
    io.write("counter-damage " .. tostring(beforePlayer - player.hp) .. "\n")
    io.write("phase " .. battle:phase() .. "\n")
    io.write("---\n")
    io.write(text)
    io.write("\n====\n")
end

fight("strength-plain", "strength", false)
fight("strength-crit", "strength", true)
fight("karate-plain", "karateChop", false)
fight("karate-crit", "karateChop", true)
fight("wing-plain", "wingAttack", false)
fight("water-gun", "waterGun", false)
fight("growl", "growl", false)
if armed then moveData[armed].willCrit = nil end
