-- Host driver for Gen V Fury Cutter, Fake Out, and Mirror Move.
-- It is not part of the Playdate build.
-- Fury Cutter powers are 20, 40, 80, 160 and stay at 160. The chain resets
-- on a miss, no target, type immunity, or a different committed move, and
-- switch-out drops it with the rest of the per-mon condition receipt.
-- Fake Out lands only on the first committed move since entering.
-- Mirror Move repeats the last foe-aimed move, including a miss, and does
-- not spend that move's PP.
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
local function own(mon, moves, current)
    mon.moves = moves
    mon.pp = {}
    for _, key in ipairs(moves) do
        mon.pp[key] = moveData[key].maxPP
    end
    for key, value in pairs(current or {}) do
        mon.pp[key] = value
    end
end
local function open(playerSpecies, enemySpecies)
    local player = Pokemon(playerSpecies, 50)
    local enemy = Pokemon(enemySpecies, 50)
    local party = Party()
    assert(party:add(player))
    local battle = Battle(player, enemy, nil, {party = party})
    drain(battle)
    eq(battle:phase(), "command", "intro")
    player.atk, player.def = 80, 80
    enemy.atk, enemy.def = 80, 80
    enemy.maxHP, enemy.hp = 500, 500
    return battle, player, enemy, party
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
local function furyPower(battle, mon, foe)
    return battle:effectiveMovePower(moveData.furyCutter, mon, foe)
end
local function hitFury(battle)
    RulesRNG.seed(1)
    local before = battle.enemy.hp
    local text = use(battle, "player", "furyCutter")
    assert(battle.enemy.hp < before, "fury cutter should hit: " .. text)
    battle.enemy:heal()
    battle.enemy.hp = 500
    return text
end

eq(MoveSupport.handlers.furyCutter, "engine-dsl", "fury handler")
eq(MoveSupport.gaps.furyCutter, nil, "fury gap")
eq(MoveSupport.handlers.fakeOut, "engine-dsl", "fake handler")
eq(MoveSupport.gaps.fakeOut, nil, "fake gap")
eq(MoveSupport.handlers.mirrorMove, "battle-condition", "mirror handler")
eq(MoveSupport.gaps.mirrorMove, nil, "mirror gap")
eq(moveData.furyCutter.power, 20, "fury base")
eq(moveData.furyCutter.type, "bug", "fury type")
eq(moveData.fakeOut.priority, 3, "fake priority")
eq(moveData.mirrorMove.pp, 20, "mirror pp")

local battle, player, enemy = open("sandshrew", "geodude")
own(player, {"furyCutter", "tackle"})
own(enemy, {"splash"})
eq(furyPower(battle, player, enemy), 20, "opening power")
hitFury(battle)
eq(furyPower(battle, player, enemy), 40, "second power")
eq(battle.conditions:of(player).furyCutter, 2, "stored multiplier")
hitFury(battle)
eq(furyPower(battle, player, enemy), 80, "third power")
RulesRNG.seed(1)
local tacklePP = player.pp.tackle
use(battle, "player", "tackle")
eq(player.pp.tackle, tacklePP - 1, "different move spends its pp")
eq(battle.conditions:of(player).furyCutter, nil, "different move clears the chain")
eq(furyPower(battle, player, enemy), 20, "power after a different move")

local missed, misser, target = open("sandshrew", "geodude")
own(misser, {"furyCutter"})
own(target, {"splash"})
hitFury(missed)
eq(furyPower(missed, misser, target), 40, "chain before the miss")
RulesRNG.seed(14)
local hp = target.hp
local missText = use(missed, "player", "furyCutter")
assert(missText:find("attack missed!", 1, true), missText)
eq(target.hp, hp, "miss deals no damage")
eq(missed.conditions:of(misser).furyCutter, nil, "miss clears the chain")
eq(furyPower(missed, misser, target), 20, "power after a miss")

local typed, bugger, ghost = open("sandshrew", "gastly")
own(bugger, {"furyCutter"})
own(ghost, {"splash"})
hitFury(typed)
eq(furyPower(typed, bugger, ghost), 40, "chain before immunity")
local savedType = moveData.furyCutter.type
moveData.furyCutter.type = "normal"
local immuneText = use(typed, "player", "furyCutter")
moveData.furyCutter.type = savedType
assert(immuneText:find("doesn't affect", 1, true), immuneText)
eq(typed.conditions:of(bugger).furyCutter, nil, "immunity clears the chain")
eq(furyPower(typed, bugger, ghost), 20, "power after immunity")

local gone, goneUser = open("sandshrew", "geodude")
own(goneUser, {"furyCutter"})
hitFury(gone)
eq(furyPower(gone, gone.player, gone.enemy), 40, "chain before no target")
gone.enemy.hp = 0
local absent = use(gone, "player", "furyCutter")
assert(absent:find("But there was no target!", 1, true), absent)
eq(gone.conditions:of(gone.player).furyCutter, nil, "no target clears the chain")

local capped, cutter, wall = open("sandshrew", "snorlax")
own(cutter, {"furyCutter"})
own(wall, {"splash"})
eq(furyPower(capped, cutter, wall), 20, "cap start")
hitFury(capped)
eq(furyPower(capped, cutter, wall), 40, "cap 40")
hitFury(capped)
eq(furyPower(capped, cutter, wall), 80, "cap 80")
hitFury(capped)
eq(furyPower(capped, cutter, wall), 160, "cap 160")
eq(capped.conditions:of(cutter).furyCutter, 8, "8x cap")
hitFury(capped)
eq(furyPower(capped, cutter, wall), 160, "cap holds")
eq(capped.conditions:of(cutter).furyCutter, 8, "cap stays 8x")

local reserve = Pokemon("sandshrew", 50)
assert(capped.party:add(reserve))
own(reserve, {"splash"})
assert(capped:chooseParty(2))
drain(capped)
eq(capped.player, reserve, "switched")
eq(capped.conditions.members[cutter], nil, "switch clears the fury receipt")
assert(capped:chooseParty(1))
drain(capped)
eq(capped.player, cutter, "switched back")
eq(furyPower(capped, cutter, wall), 20, "power after switch")

local fake, user, foe = open("meowth", "snorlax")
own(user, {"fakeOut", "tackle"})
own(foe, {"splash"})
local fakePP = user.pp.fakeOut
RulesRNG.seed(1)
local before = foe.hp
local first = use(fake, "player", "fakeOut")
assert(foe.hp < before, "fake out hits on the first action: " .. first)
eq(foe.flinched, true, "fake out flinches")
eq(user.pp.fakeOut, fakePP - 1, "first fake out spends pp")
foe:heal()
foe.hp = 500
foe.flinched = false
local held = foe.hp
local second = use(fake, "player", "fakeOut")
assert(second:find("But it failed!", 1, true), second)
eq(foe.hp, held, "later fake out deals nothing")
eq(user.pp.fakeOut, fakePP - 2, "failed fake out still spends pp")

local later, actor, victim = open("meowth", "snorlax")
own(actor, {"tackle", "fakeOut"})
own(victim, {"splash"})
RulesRNG.seed(1)
use(later, "player", "tackle")
local quiet = victim.hp
local denied = use(later, "player", "fakeOut")
assert(denied:find("But it failed!", 1, true), denied)
eq(victim.hp, quiet, "fake out fails after another move")

local mirror, copier, source = open("sandshrew", "sandshrew")
own(copier, {"mirrorMove", "splash"})
own(source, {"tackle", "swordsDance", "furyCutter", "struggle"})
eq(copier.pp.mirrorMove, 20, "mirror stock")
local nothing = use(mirror, "player", "mirrorMove")
assert(nothing:find("But it failed!", 1, true), nothing)
eq(copier.pp.mirrorMove, 19, "failed mirror spends its own pp")

RulesRNG.seed(1)
local tackled = copier.hp
use(mirror, "enemy", "tackle")
local fromTackle = tackled - copier.hp
assert(fromTackle > 0, "setup tackle hit")
local tacklePP = source.pp.tackle
RulesRNG.seed(1)
local mirroredHP = source.hp
local copied = use(mirror, "player", "mirrorMove")
assert(copied:find("MIRROR MOVE", 1, true), copied)
assert(copied:find("TACKLE", 1, true), copied)
eq(mirroredHP - source.hp, fromTackle, "mirror repeats tackle damage")
eq(source.pp.tackle, tacklePP, "copied tackle spends no pp")
eq(copier.pp.mirrorMove, 18, "mirror pp spent once for the copy")

local dancer, dancerUser, dancerFoe = open("sandshrew", "geodude")
own(dancerUser, {"mirrorMove"})
own(dancerFoe, {"swordsDance"})
RulesRNG.seed(1)
use(dancer, "enemy", "swordsDance")
local selfOnly = use(dancer, "player", "mirrorMove")
assert(selfOnly:find("But it failed!", 1, true), selfOnly)
assert(not selfOnly:find("SWORDS DANCE", 1, true), selfOnly)

source:heal()
RulesRNG.seed(14)
local missedHP = copier.hp
local enemyMiss = use(mirror, "enemy", "furyCutter")
assert(enemyMiss:find("attack missed!", 1, true), enemyMiss)
eq(copier.hp, missedHP, "targeting miss deals nothing")
local furyPP = source.pp.furyCutter
RulesRNG.seed(1)
local repeatMiss = use(mirror, "player", "mirrorMove")
assert(repeatMiss:find("FURY CUTTER", 1, true), repeatMiss)
eq(source.pp.furyCutter, furyPP, "copied fury cutter spends no pp")

RulesRNG.seed(1)
use(mirror, "enemy", "struggle")
local strugglePP = source.pp.tackle
local refused = use(mirror, "player", "mirrorMove")
assert(refused:find("But it failed!", 1, true), refused)
assert(not refused:find("STRUGGLE", 1, true), refused)
eq(source.pp.tackle, strugglePP, "struggle refusal leaves other pp")

print("fury-fake-mirror-host ok")
