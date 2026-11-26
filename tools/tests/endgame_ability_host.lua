-- Host driver for the endgame roster abilities that had no callback.
-- Giovanni, the Elite Four, the rival, and the static legendaries can roll
-- these first or second slots. Each one now has its Gen V effect:
-- Limber, Lightning Rod, Chlorophyll, Pressure, Thick Fat, Iron Fist,
-- Hydration, and Reckless. A reviewed move gap still says "But it failed!".
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
    if loaded[name] then
        return
    end
    loaded[name] = true
    local ok, problem = pcall(loadPlaydate, SOURCE .. name .. ".lua")
    if not ok then
        loaded[name] = nil
        error(problem)
    end
    local chunk = problem
    ok, problem = pcall(chunk)
    if not ok then
        loaded[name] = nil
        error(problem)
    end
end

playdate = {
    kButtonA = 1,
    buttonJustPressed = function()
        return false
    end,
    buttonIsPressed = function()
        return false
    end,
    datastore = {
        read = function()
            return nil
        end,
    },
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
        if guard > 80 then
            error("script did not finish: " .. tostring(battle.message))
        end
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
    for _, key in ipairs(moves) do
        mon.pp[key] = moveData[key].maxPP
    end
end
local function born(species, slot)
    return Pokemon(species, 50, {natureId = 0, abilitySlot = slot, heldItem = "none"})
end
local function open(player, enemy)
    local party = Party()
    assert(party:add(player))
    local battle = Battle(player, enemy, nil, {party = party})
    drain(battle)
    eq(battle:phase(), "command", "intro")
    return battle
end
local function use(battle, side, key)
    battle:setDirection(side)
    return script(battle, function()
        battle:resolveTurn({
            side = side,
            actor = battle[side],
            key = key,
            move = moveData[key],
        })
    end)
end
local function power(battle, attacker, defender, key)
    battle:setDirection(attacker == battle.player and "player" or "enemy")
    return battle:effectiveMovePower(moveData[key], attacker, defender)
end

for _, id in ipairs({7, 31, 34, 46, 47, 89, 93, 120}) do
    eq(BattleEffects:supported(id) and true or false, true, "supported " .. id)
end
eq(MoveSupport.gaps.perishSong ~= nil, true, "perish song stays a reviewed gap")

local lee = born("hitmonlee", "first")
local caster = born("pikachu", "first")
own(caster, {"thunderWave"})
local limber = open(caster, lee)
eq(limber.effects:statusImmunity(lee, "paralyze"), "Limber", "limber query")
local limberText = use(limber, "player", "thunderWave")
assert(limberText:find("protected by Limber!", 1, true), limberText)
eq(lee.status, nil, "limber stays unparalyzed")

local horn = born("rhyhorn", "first")
local bolt = born("pikachu", "first")
own(bolt, {"thunderbolt"})
local rod = open(bolt, horn)
local rodHP = horn.hp
local rodText = use(rod, "player", "thunderbolt")
assert(rodText:find("Lightning Rod raised its SP. ATK!", 1, true), rodText)
eq(horn.hp, rodHP, "lightning rod absorbs electric")
eq(horn.statStages.spa, 1, "lightning rod special attack")

local egg = born("exeggutor", "first")
local sunFoe = born("magnemite", "first")
local sun = open(egg, sunFoe)
local calm, harsh
script(sun, function()
    calm = sun:effectiveSpeed(egg)
    sun.effects:setWeather("sunnyday")
    harsh = sun:effectiveSpeed(egg)
end)
eq(harsh, calm * 2, "chlorophyll doubles speed in sun")

local mew = born("mewtwo", "first")
local pressured = born("rattata", "first")
own(pressured, {"tackle"})
local pressure = open(pressured, mew)
local tacklePP = pressured.pp.tackle
use(pressure, "player", "tackle")
eq(pressured.pp.tackle, tacklePP - 2, "pressure spends an extra PP")

local plainTarget = born("rhyhorn", "first")
local plainUser = born("rattata", "first")
own(plainUser, {"tackle"})
local ordinary = open(plainUser, plainTarget)
local ordinaryPP = plainUser.pp.tackle
use(ordinary, "player", "tackle")
eq(plainUser.pp.tackle, ordinaryPP - 1, "no pressure spends one PP")

local fat = born("dewgong", "first")
local hydrated = born("dewgong", "second")
local fire = born("charizard", "first")
local thick = open(fire, fat)
local half = power(thick, fire, fat, "flamethrower")
fat.abilitySlot = "second"
local full = power(thick, fire, fat, "flamethrower")
fat.abilitySlot = "first"
assert(half < full, "thick fat lowers fire power " .. half .. " vs " .. full)
assert(half * 2 <= full + 1 and half * 2 >= full - 1, "thick fat is one half")

local chan = born("hitmonchan", "second")
local punchBag = born("snorlax", "first")
local fist = open(chan, punchBag)
local boosted = power(fist, chan, punchBag, "firePunch")
chan.abilitySlot = "first"
local plainPunch = power(fist, chan, punchBag, "firePunch")
assert(boosted > plainPunch, "iron fist boosts fire punch")

local recklessLee = born("hitmonlee", "second")
local recoilBag = born("snorlax", "first")
local reckless = open(recklessLee, recoilBag)
local boostedEdge = power(reckless, recklessLee, recoilBag, "doubleEdge")
recklessLee.abilitySlot = "first"
local plainEdge = power(reckless, recklessLee, recoilBag, "doubleEdge")
assert(boostedEdge > plainEdge, "reckless boosts double-edge")

local rainMon = born("dewgong", "second")
eq(rainMon:ability(), 93, "dewgong second is hydration")
local rainFoe = born("magnemite", "first")
local rain = open(rainMon, rainFoe)
rainMon.status = "burn"
local rainText = script(rain, function()
    rain.effects:setWeather("raindance")
    rain:endOfRoundStatus()
end)
assert(rainText:find("Hydration cured its status!", 1, true), rainText)
eq(rainMon.status, nil, "hydration clears the burn")
eq(hydrated:ability(), 93, "slot check")

local singer = born("jynx", "first")
local audience = born("abra", "first")
own(singer, {"perishSong"})
local gap = open(audience, singer)
local gapText = use(gap, "enemy", "perishSong")
assert(gapText:find("But it failed!", 1, true), gapText)
local found = false
for _, row in ipairs(gap:getMoveGaps()) do
    if row.move == "perishSong" then
        found = true
    end
end
eq(found, true, "perish song recorded a move gap")

print("endgame-ability-host ok")
