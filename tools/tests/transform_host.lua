-- Host driver for Gen V Transform. It is not part of the Playdate build.
-- Pinned Showdown 9b136a8 transformInto fails when the target has a substitute
-- (gen >= 5), the target is already transformed (gen >= 2), or the user is
-- already transformed (gen >= 5). Those three checks are implemented.
-- Reference notes, not a ledger: the shared status-substitute gate says
-- "substitute blocked the move!" before onHit, while the handler and gen5
-- -fail say "But it failed!". A fainted target hits the shared "no target"
-- gate on the move path; the handler still says "But it failed!". Copied PP
-- is min(5, dex base PP). Every learned move in this registry has base PP >= 5
-- (Sketch is absent; Struggle is not a copied slot), so that is 5. Gen 5 does
-- not copy crit volatiles. Imposter, Illusion, Terastal, Autotomize weight,
-- Hidden Power typing, and ability onStart/onUpdate are not run by Transform.
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
local function open(playerSpecies, playerLevel, enemySpecies, enemyLevel)
    local player = Pokemon(playerSpecies, playerLevel)
    local enemy = Pokemon(enemySpecies, enemyLevel)
    local party = Party()
    assert(party:add(player))
    local battle = Battle(player, enemy, nil, {party = party})
    drain(battle)
    eq(battle:phase(), "command", "intro")
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
local function stage(mon, name)
    return mon.statStages[name]
end

eq(MoveSupport.handlers.transform, "battle-condition", "handler")
eq(MoveSupport.gaps.transform, nil, "gap")
eq(moveData.transform.protectable, false, "protectable")
eq(moveData.transform.accuracy, 0, "accuracy")
eq(SpeciesWeight.of("ditto"), 40, "ditto weight")
eq(SpeciesWeight.of("snorlax"), 4600, "snorlax weight")
eq(SpeciesWeight.of("pikachu"), 60, "pikachu weight")
eq(SpeciesWeight.of("charizard"), 905, "charizard weight")
eq(#Pokemon("ditto", 25).moves, 1, "ditto move count")
eq(Pokemon("ditto", 25).moves[1], "transform", "ditto move")

local battle, player, enemy, party = open("ditto", 25, "snorlax", 50)
own(enemy, {"tackle", "bodySlam", "hyperBeam", "splash"}, {tackle = 1, bodySlam = 2, hyperBeam = 3, splash = 4})
enemy.atk = 400
enemy.def = 40
enemy.spa = 210
enemy.spd = 180
enemy.spe = 300
enemy.statStages.atk = 4
enemy.statStages.def = -2
enemy.statStages.spa = 1
enemy.statStages.spd = 3
enemy.statStages.spe = 2
enemy.statStages.acc = -1
enemy.statStages.eva = 5
player.statStages.atk = 1
player.statStages.spe = -1
player.hp = 40
player.status = "poison"
player.statusTurns = 0
enemy.hp = 90
enemy.status = "burn"
enemy.statusTurns = 0
battle.conditions:of(enemy).focusEnergy = true
battle.conditions:of(enemy).disable = {key = "tackle", turns = 4}
local originalAtk = player.atk
local originalDef = player.def
local originalSpa = player.spa
local originalSpd = player.spd
local originalSpe = player.spe
local originalMax = player.maxHP
RulesRNG.seed(1)
local rollsBefore = RulesRNG.snapshot().rolls
local damageBefore = calcDamage(player, enemy, moveData.tackle, nil, battle.effects).damage
local speedBefore = battle:effectiveSpeed(player)
RulesRNG.seed(1)
local text = use(battle, "player", "transform")
eq(RulesRNG.snapshot().rolls, rollsBefore, "transform rolls")
assert(text:find("transformed into SNORLAX", 1, true), text)
assert(party:active() == player, "party member")
eq(player.species, "ditto", "species")
eq(player.name, "DITTO", "name")
eq(player.level, 25, "level")
eq(player.hp, 40, "hp")
eq(player.maxHP, originalMax, "max hp")
eq(player.status, "poison", "status")
eq(player.statusTurns, 0, "status turns")
eq(player.moves[1], "transform", "party move")
eq(#player.moves, 1, "party move count")
eq(player.pp.transform, 9, "spent transform pp")
eq(player.atk, originalAtk, "stored atk")
eq(player.def, originalDef, "stored def")
eq(player.spa, originalSpa, "stored spa")
eq(player.spd, originalSpd, "stored spd")
eq(player.spe, originalSpe, "stored spe")
eq(player:ability(), 7, "specimen ability")
eq(battle.effects:effectiveAbility(player), 17, "copied ability")
eq(battle.conditions:speciesOf(player), "snorlax", "forme species")
eq(battle.conditions:weightOf(player), 4600, "forme weight")
eq(battle.conditions:statOf(player, "atk"), 400, "copied atk")
eq(battle.conditions:statOf(player, "def"), 40, "copied def")
eq(battle.conditions:statOf(player, "spa"), 210, "copied spa")
eq(battle.conditions:statOf(player, "spd"), 180, "copied spd")
eq(battle.conditions:statOf(player, "spe"), 300, "copied spe")
eq(stage(player, "atk"), 4, "atk stage")
eq(stage(player, "def"), -2, "def stage")
eq(stage(player, "spa"), 1, "spa stage")
eq(stage(player, "spd"), 3, "spd stage")
eq(stage(player, "spe"), 2, "spe stage")
eq(stage(player, "acc"), -1, "acc stage")
eq(stage(player, "eva"), 5, "eva stage")
eq(battle:hasType(player, "normal"), true, "normal type")
eq(battle:hasType(player, "flying"), false, "not flying")
local copied = battle.conditions:movesOf(player)
eq(copied[1], "tackle", "move 1")
eq(copied[2], "bodySlam", "move 2")
eq(copied[3], "hyperBeam", "move 3")
eq(copied[4], "splash", "move 4")
eq(battle.conditions:ppOf(player, "tackle"), 5, "tackle pp")
eq(battle.conditions:maxPPOf(player, "tackle"), 5, "tackle max")
eq(battle.conditions:ppOf(player, "hyperBeam"), 5, "beam pp")
eq(enemy.pp.tackle, 1, "target current pp")
eq(battle.conditions:of(player).focusEnergy, nil, "no crit volatile")
eq(battle.conditions:of(player).disable, nil, "no disable volatile")
assert(type(player.hasPP) == "function", "move view installed")
assert(player:hasPP("tackle"), "forme has tackle")
assert(not player:hasPP("transform"), "forme dropped transform")
local encoded = assert(PokemonCodec.encode(player))
eq(encoded.species, "ditto", "codec species")
eq(encoded.level, 25, "codec level")
eq(encoded.hp, 40, "codec hp")
eq(encoded.status, "poison", "codec status")
eq(encoded.moves[1], "transform", "codec move")
eq(encoded.pp.transform, 9, "codec pp")
eq(encoded.abilitySlot, player.abilitySlot, "codec ability slot")
RulesRNG.seed(1)
local damageAfter = calcDamage(player, enemy, moveData.tackle, nil, battle.effects).damage
assert(damageAfter > damageBefore, "copied stats change damage")
assert(battle:effectiveSpeed(player) > speedBefore, "copied speed")
player.statStages.atk = 0
player.statStages.def = 0
local forme = battle.conditions:forme(player)
forme.stats.atk = 100
forme.stats.def = 20
player.hp = player.maxHP
player.atk = 1
player.def = 400
local hpBeforeHit = player.hp
player.confusion = 2
RulesRNG.seed(1)
local confusionSeed = nil
local probe = 1
while probe <= 30 do
    RulesRNG.seed(probe)
    if RulesRNG.random(1, 2) == 1 then
        confusionSeed = probe
        probe = 31
    end
    probe = probe + 1
end
assert(confusionSeed, "confusion seed")
RulesRNG.seed(confusionSeed)
use(battle, "player", "tackle")
assert(player.hp < hpBeforeHit / 2, "confusion uses forme stats")
eq(player.atk, 1, "confusion leaves stored atk")
eq(battle.conditions:ppOf(player, "tackle"), 5, "confusion spends no pp")
eq(player.status, "poison", "existing poison stays")
player.status = nil
player.statusTurns = 0
battle:setDirection("enemy")
local immune = script(battle, function()
    ApplyStatus(DEFENDER, "poison"):apply(battle)
end)
assert(immune:find("Immunity", 1, true), immune)
eq(player.status, nil, "immunity blocks a new poison")
battle.effects.abilityOverrides[enemy] = 108
local warned = script(battle, function()
    battle.effects:forewarn(enemy, player)
end)
assert(warned:find("HYPER BEAM", 1, true), warned)
assert(not warned:find("TRANSFORM", 1, true), warned)
local again = script(battle, function()
    battle.conditions:transform()
end)
assert(again:find("But it failed!", 1, true), again)
eq(battle.conditions:speciesOf(player), "snorlax", "second transform keeps forme")
eq(player.pp.transform, 9, "direct retry spends no party pp")
battle:clearVolatiles()
eq(battle.conditions:speciesOf(player), "ditto", "cleared species")
eq(battle.conditions:movesOf(player)[1], "transform", "cleared moves")
eq(battle.conditions:weightOf(player), 40, "cleared weight")
eq(battle:hasType(player, "normal"), true, "cleared type")
eq(stage(player, "atk"), 1, "restored atk stage")
eq(stage(player, "spe"), -1, "restored spe stage")
eq(battle.effects:effectiveAbility(player), 7, "restored ability")
eq(player.pp.transform, 9, "party pp after clear")
assert(player:hasPP("transform"), "class pp restored")

local blocked, ditto, snorlax = open("ditto", 25, "snorlax", 25)
own(snorlax, {"tackle"})
blocked.conditions:of(snorlax).substituteHP = 25
local blockedText = use(blocked, "player", "transform")
assert(blockedText:find("substitute blocked the move!", 1, true), blockedText)
eq(blocked.conditions:forme(ditto), nil, "substitute skips forme")
eq(ditto.pp.transform, 9, "substitute spends pp")
eq(ditto.species, "ditto", "substitute keeps species")
local directBlock = script(blocked, function()
    blocked.conditions:transform()
end)
assert(directBlock:find("But it failed!", 1, true), directBlock)
eq(blocked.conditions:forme(ditto), nil, "direct substitute")

local mirror, left, right = open("ditto", 25, "ditto", 25)
use(mirror, "enemy", "transform")
eq(mirror.conditions:speciesOf(right), "ditto", "enemy copied ditto")
assert(mirror.conditions:forme(right), "enemy transformed")
local denied = use(mirror, "player", "transform")
assert(denied:find("But it failed!", 1, true), denied)
eq(mirror.conditions:forme(left), nil, "cannot copy a transformed target")
eq(left.species, "ditto", "user species")
eq(left.pp.transform, 9, "failed copy spends pp")

local repeatBattle, repeater, target = open("ditto", 25, "snorlax", 30)
own(target, {"transform", "tackle"})
use(repeatBattle, "player", "transform")
eq(repeatBattle.conditions:ppOf(repeater, "transform"), 5, "copied transform pp")
eq(repeater.pp.transform, 9, "party transform pp")
local repeated = use(repeatBattle, "player", "transform")
assert(repeated:find("But it failed!", 1, true), repeated)
eq(repeatBattle.conditions:speciesOf(repeater), "snorlax", "still snorlax")
eq(repeatBattle.conditions:ppOf(repeater, "transform"), 4, "copied pp spent")
eq(repeater.pp.transform, 9, "party pp unchanged")
eq(repeatBattle.conditions:ppOf(repeater, "tackle"), 5, "other copied pp")

local guard, guarded, bulky = open("ditto", 25, "snorlax", 30)
own(bulky, {"splash"})
guard.conditions:of(bulky).protect = true
local protected = use(guard, "player", "transform")
assert(protected:find("transformed into SNORLAX", 1, true), protected)
eq(guard.conditions:speciesOf(guarded), "snorlax", "protect does not block")

local typed, typer, zard = open("ditto", 25, "charizard", 50)
own(zard, {"flamethrower"})
zard.hp = zard.maxHP - 4
script(typed, function()
    typed:setDirection("enemy")
    typed.conditions:roost()
end)
eq(typed:hasType(zard, "flying"), false, "roost drops flying")
eq(typed:hasType(zard, "fire"), true, "roost keeps fire")
use(typed, "player", "transform")
eq(typed:hasType(typer, "fire"), true, "copied fire")
eq(typed:hasType(typer, "flying"), true, "copied latent flying")
eq(typed.conditions:of(typer).roost, nil, "user is not roosted")
eq(typer.species, "ditto", "roost user species")
typed.conditions:clear(typer)
typed.effects:clear(typer)
eq(typed.conditions:speciesOf(typer), "ditto", "switch clear")
eq(typer.moves[1], "transform", "switch moves")

local ground, changer, plain = open("ditto", 25, "charizard", 40)
own(plain, {"ember"})
ground.conditions:of(plain).changedType = "ground"
use(ground, "player", "transform")
eq(ground:hasType(changer, "ground"), true, "copied changed type")
eq(ground:hasType(changer, "fire"), false, "changed type replaces fire")
eq(changer.type, "normal", "durable type")

local overwritten, overwrittenUser, flyer = open("ditto", 25, "charizard", 40)
own(flyer, {"ember"})
overwritten.conditions:of(overwrittenUser).changedType = "ground"
overwrittenUser.hp = overwrittenUser.maxHP - 4
script(overwritten, function()
    overwritten:setDirection("player")
    overwritten.conditions:roost()
end)
use(overwritten, "player", "transform")
eq(overwritten:hasType(overwrittenUser, "fire"), true, "transform replaces camouflage")
eq(overwritten:hasType(overwrittenUser, "ground"), false, "old changed type is gone")
eq(overwritten:hasType(overwrittenUser, "flying"), false, "user roost still strips flying")
eq(overwritten.conditions:forme(overwrittenUser).type2, "flying", "latent flying kept")
eq(overwritten.conditions:of(overwrittenUser).roost ~= nil, true, "user roost remains")

local seeded, sleeper, victim = open("ditto", 25, "snorlax", 40)
own(victim, {"tackle"})
seeded.effects.abilityOverrides[victim] = 15
use(seeded, "player", "transform")
eq(seeded.effects:effectiveAbility(sleeper), 15, "worry seed ability")
eq(sleeper:ability(), 7, "worry seed slot")

local ball, holder, mouse = open("ditto", 25, "pikachu", 20)
own(mouse, {"thunderbolt"})
holder.heldItem = "lightBall"
local plainAttack = ball.effects:attackStat(holder, moveData.tackle, 10)
use(ball, "player", "transform")
local ballAttack = ball.effects:attackStat(holder, moveData.tackle, 10)
eq(plainAttack, 10, "light ball ignores ditto")
eq(ballAttack, 20, "light ball sees pikachu")
eq(ball.conditions:speciesOf(holder), "pikachu", "pikachu forme")
eq(ball.conditions:weightOf(holder), 60, "pikachu weight")
eq(ball.effects:effectiveAbility(holder), 9, "static")
holder.heldItem = "none"
eq(holder.species, "ditto", "light ball identity")

local splashBattle, splasher, foe = open("ditto", 25, "snorlax", 25)
own(foe, {"splash"})
splasher.spe = 999
use(splashBattle, "player", "transform")
eq(splashBattle:phase(), "command", "back to command")
assert(splashBattle:selectMove(1), "select copied splash")
drain(splashBattle)
eq(splashBattle.conditions:ppOf(splasher, "splash"), 4, "selected pp")
eq(splasher.pp.splash, nil, "splash is not a party move")
eq(splasher.pp.transform, 9, "transform pp after splash")
eq(splasher.species, "ditto", "splash identity")

local faintedBattle, fainter, gone = open("ditto", 25, "snorlax", 25)
own(gone, {"tackle"})
gone.hp = 0
local faintedMove = use(faintedBattle, "player", "transform")
assert(faintedMove:find("no target", 1, true), faintedMove)
eq(faintedBattle.conditions:forme(fainter), nil, "fainted move")
gone.hp = gone.maxHP
local faintedDirect = script(faintedBattle, function()
    faintedBattle:setDirection("player")
    gone.hp = 0
    faintedBattle.conditions:transform()
end)
assert(faintedDirect:find("But it failed!", 1, true), faintedDirect)
eq(faintedBattle.conditions:forme(fainter), nil, "fainted handler")

print("transform-host ok")
