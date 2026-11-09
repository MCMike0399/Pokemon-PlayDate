-- Host driver for Hyper Beam / Giga Impact recharge, Thrash / Outrage
-- rampage, and Gen V freeze thaw. Not part of the Playdate build.
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

eq(moveData.hyperBeam.recharge, true, "hyper beam recharges")
eq(moveData.gigaImpact.recharge, true, "giga impact recharges")
eq(moveData.thrash.lockRule, "rampage", "thrash rampage")
eq(moveData.outrage.lockRule, "rampage", "outrage rampage")
eq(moveData.flameWheel.defrost, true, "flame wheel defrosts")
eq(moveData.flareBlitz.defrost, true, "flare blitz defrosts")
eq(moveData.ember.defrost, false, "ember does not defrost the user")
eq(MoveSupport.handlers.hyperBeam, "engine-dsl", "hyper beam handler")
eq(MoveSupport.gaps.hyperBeam, nil, "hyper beam gap")
eq(MoveSupport.handlers.thrash, "engine-dsl", "thrash handler")
eq(MoveSupport.handlers.outrage, "engine-dsl", "outrage handler")
eq(MoveSupport.handlers.gigaImpact, "engine-dsl", "giga impact handler")

local battle, player, enemy = open("snorlax", "snorlax")
own(player, {"hyperBeam", "tackle"})
own(enemy, {"splash"})
RulesRNG.seed(1)
local before = enemy.hp
local text = use(battle, "player", "hyperBeam")
assert(enemy.hp < before, "hyper beam should hit: " .. text)
assert(enemy.hp > 0, "target stays up so the user must recharge")
eq(player.pp.hyperBeam, 4, "hyper beam spends one PP")
eq(battle.conditions:mustRecharge(player), true, "recharge is pending")
eq(battle:selectMove(1), false, "a move cannot be chosen while recharging")
local queued = battle:enemyTurn()
-- enemyTurn above was the foe; the player's receipt is what the next action uses.
local recharge = script(battle, function()
    battle:resolveTurn({side = "player", actor = player, recharge = true})
end)
assert(recharge:find("must recharge!", 1, true), recharge)
eq(battle.conditions:mustRecharge(player), false, "recharge is spent")
eq(player.pp.hyperBeam, 4, "recharge spends no PP")
eq(queued.move, moveData.splash, "a foe without the receipt still acts")

local ko, koUser, koFoe = open("snorlax", "magikarp")
own(koUser, {"hyperBeam"})
own(koFoe, {"splash"})
koFoe.hp = 1
RulesRNG.seed(1)
local koText = use(ko, "player", "hyperBeam")
eq(koFoe.hp, 0, "hyper beam can KO: " .. koText)
eq(ko.conditions:mustRecharge(koUser), false, "a KO skips recharge")

local impact, impactUser, impactFoe = open("snorlax", "snorlax")
own(impactUser, {"gigaImpact"})
own(impactFoe, {"splash"})
RulesRNG.seed(1)
local impactBefore = impactFoe.hp
use(impact, "player", "gigaImpact")
assert(impactFoe.hp < impactBefore and impactFoe.hp > 0, "giga impact hits and leaves the target")
eq(impact.conditions:mustRecharge(impactUser), true, "giga impact recharge")

local thrash, thrashUser, thrashFoe = open("snorlax", "snorlax")
own(thrashUser, {"thrash"})
own(thrashFoe, {"splash"})
RulesRNG.seed(2)
use(thrash, "player", "thrash")
local rampage = thrash.conditions:of(thrashUser).rampage
assert(rampage and rampage.key == "thrash", "thrash locks the user")
assert(rampage.total == 2 or rampage.total == 3, "rampage lasts 2 or 3")
eq(rampage.remaining, rampage.total - 1, "the first hit spends one lock turn")
eq(thrashUser.confusion, nil, "fatigue waits for the last turn")
while thrash.conditions:of(thrashUser).rampage do
    thrashFoe.hp = 500
    RulesRNG.seed(2)
    use(thrash, "player", "thrash")
end
assert(thrashUser.confusion ~= nil, "the last rampage turn confuses")

local outrage, outrageUser = open("dragonite", "snorlax")
own(outrageUser, {"outrage"})
own(outrage.enemy, {"splash"})
RulesRNG.seed(2)
use(outrage, "player", "outrage")
eq(outrage.conditions:of(outrageUser).rampage.key, "outrage", "outrage uses the same lock")

local frozen, frozenUser, frozenFoe = open("ponyta", "snorlax")
own(frozenUser, {"ember", "flameWheel"})
own(frozenFoe, {"splash"})
frozenUser.status = "freeze"
RulesRNG.seed(4)
local stuck = use(frozen, "player", "ember")
assert(stuck:find("frozen solid!", 1, true), stuck)
eq(frozenUser.status, "freeze", "ember does not thaw the user")
frozenUser.status = "freeze"
local thawed = use(frozen, "player", "flameWheel")
assert(thawed:find("thawed out!", 1, true), thawed)
eq(frozenUser.status, nil, "flame wheel thaws the user")
assert(frozenFoe.hp < 500, "the thawed flame wheel still hits")

local target, heater, icebox = open("ponyta", "snorlax")
own(heater, {"ember"})
own(icebox, {"splash"})
icebox.status = "freeze"
RulesRNG.seed(1)
local hit = use(target, "player", "ember")
assert(hit:find(icebox.name .. " thawed out!", 1, true), hit)
eq(icebox.status, nil, "a damaging fire hit thaws the target")
assert(icebox.hp < 500, "the fire move still deals damage")

print("recharge-rampage-freeze-host ok")
