-- Host driver for Gen V Dig. It is not part of the Playdate build.
-- Showdown 9b136a8 two-turn Dig: the first turn burrows and spends one PP,
-- the locked second turn is the 80-power hit. Earthquake and Magnitude hit
-- an underground target for double final damage. Other moves miss unless
-- No Guard is on either living actor. Flying-type and Levitate immunity
-- still apply. The reviewed Solar Beam / Skull Bash / Fly charge body is
-- not the owner of this receipt.
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
local function open(playerSpecies, enemySpecies)
    local player = Pokemon(playerSpecies, 20)
    local enemy = Pokemon(enemySpecies, 20)
    local party = Party()
    assert(party:add(player))
    local battle = Battle(player, enemy, nil, {party = party})
    drain(battle)
    eq(battle:phase(), "command", "intro")
    return battle, player, enemy
end
local function use(battle, side, key, continuation)
    battle:setDirection(side)
    return script(battle, function()
        battle:resolveTurn({
            side = side,
            actor = battle[side],
            key = key,
            move = moveData[key],
            continuation = continuation,
        })
    end)
end

eq(MoveSupport.handlers.dig, "engine-dsl", "handler")
eq(MoveSupport.gaps.dig, nil, "gap")
eq(moveData.dig.power, 80, "power")
eq(moveData.dig.chargeRule, nil, "charge rule stays off the reviewed owner")
eq(moveData.dig.pp, 10, "pp")

local battle, player, enemy = open("sandshrew", "geodude")
own(player, {"dig"})
own(enemy, {"tackle", "earthquake", "magnitude"})
player.spe = 200
enemy.spe = 20
local enemyHP = enemy.hp
local playerHP = player.hp
RulesRNG.seed(3)
local surface = calcDamage(enemy, player, moveData.earthquake, nil, battle.effects).damage
local buriedText = use(battle, "player", "dig")
assert(buriedText:find("burrowed its way underground!", 1, true), buriedText)
eq(enemy.hp, enemyHP, "burrow deals no damage")
eq(player.pp.dig, 9, "one PP on the burrow")
eq(battle.conditions:lockedKey(player), "dig", "locked into dig")
eq(battle.conditions:underground(player), true, "user is underground")
RulesRNG.seed(3)
battle.currentMoveKey = "earthquake"
local buriedQuake = calcDamage(enemy, player, moveData.earthquake, nil, battle.effects).damage
eq(buriedQuake, surface * 2, "earthquake doubles underground")
local mag = {}
for key, value in pairs(moveData.magnitude) do
    mag[key] = value
end
mag.power = 70
RulesRNG.seed(5)
battle.currentMoveKey = "tackle"
local surfaceMag = calcDamage(enemy, player, mag, nil, battle.effects).damage
RulesRNG.seed(5)
battle.currentMoveKey = "magnitude"
local buriedMag = calcDamage(enemy, player, mag, nil, battle.effects).damage
eq(buriedMag, surfaceMag * 2, "magnitude doubles underground")
local miss = use(battle, "enemy", "tackle")
assert(miss:find("attack missed!", 1, true), miss)
eq(player.hp, playerHP, "tackle misses underground")
eq(player.pp.dig, 9, "miss spends no dig PP")
own(enemy, {"tackle"})
RulesRNG.seed(8)
assert(battle:selectMove(1), "locked release")
local released = drain(battle)
assert(released:find("DIG", 1, true), released)
assert(enemy.hp < enemyHP, "release hits")
eq(player.pp.dig, 9, "release spends no second PP")
eq(battle.conditions:underground(player), false, "release ends the burrow")
eq(player.species, "sandshrew", "species unchanged")

local flyer, _, pidgey = open("sandshrew", "pidgey")
own(flyer.player, {"earthquake"})
flyer.conditions:of(pidgey).charge = {key = "dig"}
local immune = use(flyer, "player", "earthquake")
assert(immune:find("doesn't affect", 1, true), immune)
eq(pidgey.hp, pidgey.maxHP, "flying immunity remains")

local levitate, _, target = open("sandshrew", "geodude")
own(levitate.player, {"earthquake"})
levitate.conditions:of(target).charge = {key = "dig"}
levitate.effects.abilityOverrides[target] = 26
local floated = use(levitate, "player", "earthquake")
assert(floated:find("doesn't affect", 1, true), floated)
eq(target.hp, target.maxHP, "levitate immunity remains")

local guard, guarded, attacker = open("sandshrew", "geodude")
own(guarded, {"dig"})
own(attacker, {"tackle"})
use(guard, "player", "dig")
local before = guarded.hp
guard.effects.abilityOverrides[attacker] = 99
local landed = use(guard, "enemy", "tackle")
assert(guarded.hp < before, "no guard hits underground: " .. landed)
guard.conditions:abortMove(guarded)
eq(guard.conditions:underground(guarded), false, "interrupt clears the burrow")

print("dig-host ok")
