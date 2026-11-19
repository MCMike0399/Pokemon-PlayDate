-- Recoil KO where the user moves first. The foe's queued move must not run.
local ROOT = assert(arg[1], "repo path required")
local BATTLE_OVERRIDE = arg[2]
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
    local path = SOURCE .. name .. ".lua"
    if name == "battle/battle" and BATTLE_OVERRIDE and BATTLE_OVERRIDE ~= "" then
        path = BATTLE_OVERRIDE
    end
    local ok, problem = pcall(loadPlaydate, path)
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
    while battle:phase() == "script" do
        guard = guard + 1
        if guard > 160 then error("script did not finish: " .. tostring(battle.message)) end
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

RulesRNG.seed(1)
local user = Pokemon("venusaur", 60)
local bench = Pokemon("pidgey", 20)
local foe = Pokemon("charizard", 53)
own(user, {"doubleEdge"})
own(foe, {"wingAttack"})
user.hp = 1
local party = Party()
assert(party:add(user))
assert(party:add(bench))
local foes = Party()
assert(foes:add(foe))
local battle = Battle(user, foe, "BLUE", {party = party, enemyParty = foes})
drain(battle)
user.hp = 1
local wingPP = foe.pp.wingAttack
local foeHP = foe.hp
battle:runScript(function()
    return battle:resolveRound({
        {side = "player", actor = user, key = "doubleEdge", move = moveData.doubleEdge},
        {side = "enemy", actor = foe, key = "wingAttack", move = moveData.wingAttack},
    })
end)
local text = drain(battle)
io.write("phase " .. battle:phase() .. "\n")
io.write("userhp " .. tostring(user.hp) .. "\n")
io.write("foehp " .. tostring(foe.hp) .. "\n")
io.write("foehp-before " .. tostring(foeHP) .. "\n")
io.write("wingpp " .. tostring(foe.pp.wingAttack) .. "\n")
io.write("wingpp-before " .. tostring(wingPP) .. "\n")
io.write("---\n")
io.write(text)
io.write("\n")
