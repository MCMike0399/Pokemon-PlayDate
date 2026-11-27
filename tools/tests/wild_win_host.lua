-- A wild KO must return after the faint and EXP pages.
-- Main 821694b8 removed the invented "You won the battle!" line.
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
    return lines
end

local function own(mon, moves)
    mon.moves = moves
    mon.pp = {}
    for _, key in ipairs(moves) do mon.pp[key] = moveData[key].maxPP end
end

local function write(key, value)
    io.write(key .. " " .. tostring(value) .. "\n")
end

RulesRNG.seed(1)
local player = Pokemon("charizard", 50)
local enemy = Pokemon("caterpie", 2)
enemy.hp = 1
own(player, {"ember"})
own(enemy, {"tackle"})
local party = Party()
assert(party:add(player))
local battle = Battle(player, enemy, nil, {party = party})
drain(battle)
if battle:phase() ~= "command" then
    error("did not reach command: " .. tostring(battle:phase()) .. " " .. tostring(battle.message))
end
assert(battle:selectMove(1), "select failed")
local lines = drain(battle)
local text = table.concat(lines, "\n")
local victory = false
for _, line in ipairs(lines) do
    if line == "You won the battle!" or line:find("You won the battle!", 1, true) then
        victory = true
    end
end
write("phase", battle:phase())
write("outcome", battle.outcome or "")
write("enemy-hp", enemy.hp)
write("fainted", text:find("fainted!", 1, true) ~= nil)
write("exp", text:find("EXP. Points!", 1, true) ~= nil)
write("victory-line", victory)
write("defeated-line", text:find("defeated ", 1, true) ~= nil)
write("transcript", text:gsub("\n", " | "))
