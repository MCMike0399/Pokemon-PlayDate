-- Host for Gen V Counter against a multi-hit physical move.
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

local function drain(battle)
    local lines = {}
    local script = battle.machine:get("script")
    local guard = 0
    while battle:phase() == "script" do
        guard = guard + 1
        if guard > 400 then error("script did not finish: " .. tostring(battle.message)) end
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

local function battleOf(moveKey)
    RulesRNG.seed(1)
    local player = Pokemon("snorlax", 50)
    local enemy = Pokemon("tauros", 50)
    player.maxHP, player.hp = 900, 900
    enemy.maxHP, enemy.hp = 900, 900
    player.spe, enemy.spe = 400, 10
    own(player, {"counter"})
    own(enemy, {moveKey})
    local party = Party()
    assert(party:add(player))
    local foes = Party()
    assert(foes:add(enemy))
    local battle = Battle(player, enemy, "BLUE", {party = party, enemyParty = foes})
    drain(battle)
    if battle:phase() ~= "command" then
        error("did not reach command: " .. tostring(battle:phase()))
    end
    return battle, player
end

local function write(key, value)
    io.write(key .. " " .. tostring(value) .. "\n")
end

local function measure(moveKey, hits)
    local move = moveData[moveKey]
    move.accuracy = 100
    if hits then
        move.minHits = hits
        move.maxHits = hits
    end
    local battle, player = battleOf(moveKey)
    local strikes = {}
    local countered = 0
    local real = battle.effects.hit
    function battle.effects:hit(source, target, used, amount, hitNumber)
        local receipt = real(self, source, target, used, amount, hitNumber)
        if target == player and used and used.name ~= "COUNTER" then
            strikes[#strikes + 1] = receipt.removed
        end
        if source == player and used and used.name == "COUNTER" then
            countered = receipt.removed
        end
        return receipt
    end
    assert(battle:selectMove(1), "select failed")
    local text = drain(battle)
    local sum = 0
    for _, removed in ipairs(strikes) do sum = sum + removed end
    write(moveKey .. "-hits", #strikes)
    write(moveKey .. "-last", strikes[#strikes] or 0)
    write(moveKey .. "-sum", sum)
    write(moveKey .. "-countered", countered)
    write(moveKey .. "-failed", text:find("But it failed!", 1, true) ~= nil)
end

measure("doubleKick")
measure("furyAttack", 3)
measure("cometPunch", 3)
