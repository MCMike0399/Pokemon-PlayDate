-- Host driver for Low Kick weight bands, Pay Day coins, Taunt, and
-- Sunny Day / Hail. Not part of the Playdate build.
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

local function eq(actual, expected, label)
    if actual ~= expected then
        error(label .. " expected " .. tostring(expected) .. " got " .. tostring(actual))
    end
end
local function drain(battle)
    local lines = {}
    local script = battle.machine:get("script")
    local guard = 0
    while battle:phase() == "script" do
        guard = guard + 1
        if guard > 80 then error("script did not finish: " .. tostring(battle.message)) end
        lines[#lines + 1] = battle.message
        script.waiting = false
        battle.presentationRequest = nil
        script:advance()
    end
    return table.concat(lines, "\n")
end
local function script(battle, fn)
    battle:runScript(fn)
    return drain(battle)
end
local function own(mon, moves)
    mon.moves = moves
    mon.pp = {}
    for _, key in ipairs(moves) do mon.pp[key] = moveData[key].maxPP end
end
local function open(playerSpecies, enemySpecies)
    local player = Pokemon(playerSpecies, 50)
    local enemy = Pokemon(enemySpecies, 50)
    local party = Party()
    assert(party:add(player))
    local battle = Battle(player, enemy, nil, {party = party})
    drain(battle)
    eq(battle:phase(), "command", "intro")
    player.atk, player.def, player.spa, player.spd = 80, 80, 80, 80
    enemy.atk, enemy.def, enemy.spa, enemy.spd = 80, 80, 80, 80
    enemy.maxHP, enemy.hp = 500, 500
    return battle, player, enemy
end
local function use(battle, side, key)
    return script(battle, function()
        battle:resolveTurn({
            side = side, actor = battle[side], key = key, move = moveData[key],
        })
    end)
end

eq(moveData.lowKick.powerRule, "lowKick", "low kick rule")
eq(MoveSupport.handlers.lowKick, "engine-dsl", "low kick handler")
eq(MoveSupport.handlers.payDay, "engine-dsl", "pay day handler")
eq(MoveSupport.handlers.taunt, "battle-condition", "taunt handler")
eq(MoveSupport.handlers.sunnyDay, "engine-dsl", "sunny day handler")
eq(MoveSupport.handlers.hail, "engine-dsl", "hail handler")
eq(MoveSupport.gaps.lowKick, nil, "low kick gap")
eq(MoveSupport.gaps.payDay, nil, "pay day gap")
eq(MoveSupport.gaps.taunt, nil, "taunt gap")

local weights = open("pidgey", "pidgey")
eq(weights:effectiveMovePower(moveData.lowKick, weights.player, weights.enemy), 20, "pidgey low kick")
weights.enemy.species = "charizard"
eq(weights:effectiveMovePower(moveData.lowKick, weights.player, weights.enemy), 80, "charizard low kick")
weights.enemy.species = "snorlax"
eq(weights:effectiveMovePower(moveData.lowKick, weights.player, weights.enemy), 120, "snorlax low kick")

RulesRNG.seed(1)
local payday, payer = open("meowth", "magikarp")
own(payer, {"payDay"})
own(payday.enemy, {"tackle"})
local paid = use(payday, "player", "payDay")
if not paid:find("Coins scattered everywhere!", 1, true) then
    error("pay day missed or skipped:\n" .. paid)
end
eq(payday.payDayCoins, 5 * payer.level, "pay day coins")

local taunt = open("rattata", "ekans")
own(taunt.player, {"growl", "tackle"})
own(taunt.enemy, {"taunt"})
local taunted = use(taunt, "enemy", "taunt")
if not taunted:find("fell for the taunt!", 1, true) then
    error("taunt did not land:\n" .. taunted)
end
eq(taunt.conditions:moveAllowed(taunt.player, "growl"), false, "taunt blocks growl")
eq(taunt.conditions:moveAllowed(taunt.player, "tackle"), true, "taunt leaves tackle")
local blocked = use(taunt, "player", "growl")
if not blocked:find("can't use GROWL after the taunt!", 1, true) then
    error("taunted growl was not stopped:\n" .. blocked)
end
for _ = 1, 2 do
    script(taunt, function()
        taunt.conditions:residual({kind = "taunt", pokemon = taunt.player, side = "player"})
    end)
end
eq(taunt.conditions:taunted(taunt.player), true, "taunt still active")
local ended = script(taunt, function()
    taunt.conditions:residual({kind = "taunt", pokemon = taunt.player, side = "player"})
end)
if not ended:find("taunt wore off!", 1, true) then
    error("taunt did not end:\n" .. ended)
end
eq(taunt.conditions:taunted(taunt.player), false, "taunt cleared")

local sun = open("charmander", "squirtle")
eq(sun.effects:weatherDamage(moveData.ember, 4096), 4096, "ember before sun")
local harsh = script(sun, function()
    eq(sun.effects:setWeather("sunnyday"), true, "sunny day")
end)
if not harsh:find("The sunlight turned harsh!", 1, true) then
    error("sun line missing:\n" .. harsh)
end
eq(sun.effects:weatherDamage(moveData.ember, 4096), 6144, "ember in sun")
eq(sun.effects:weatherDamage(moveData.waterGun, 4096), 2048, "water in sun")
local same = script(sun, function()
    local ok, why = sun.effects:setWeather("sunnyday")
    eq(ok, false, "same sun")
    eq(why, "same-weather", "same sun reason")
end)

local hail = open("charmander", "articuno")
script(hail, function()
    eq(hail.effects:setWeather("hail"), true, "hail")
end)
local playerBefore = hail.player.hp
local enemyBefore = hail.enemy.hp
script(hail, function()
    for _, event in ipairs(hail.effects:events()) do
        hail.effects:residual(event)
    end
end)
if not (hail.player.hp < playerBefore) then
    error("hail did not chip charmander")
end
eq(hail.enemy.hp, enemyBefore, "hail skips ice")
eq(hail.effects:snapshot().turns, 4, "hail ticked")

print("low-kick-payday-taunt-weather-host ok")
