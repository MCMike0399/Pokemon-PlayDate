-- Confuse Ray and Supersonic against a Pokémon that is already confused.
-- The failure line is But it failed! and the confusion counter stays put.
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
    kButtonA = 1, kButtonB = 2,
    buttonJustPressed = function() return false end,
    buttonIsPressed = function() return false end,
    getCrankChange = function() return 0 end,
    isCrankDocked = function() return true end,
    datastore = { read = function() return nil end },
    graphics = setmetatable({
        sprite = { addDirtyRect = function() end },
        getSystemFont = function() return { getHeight = function() return 14 end, getTextWidth = function() return 8 end } end,
        font = { new = function() return { getHeight = function() return 14 end, getTextWidth = function() return 10 end } end },
    }, { __index = function() return function() return 0 end end }),
}

import "lib/oop"
import "lib/rng"
import "lib/statemachine"
import "data/individualData"
import "domain/individualStats"
import "data/pokemon"
import "data/typechart"
import "battle/dsl"
import "battle/moves"
import "battle/battle"

local function own(mon, moves)
    mon.moves = moves
    mon.pp = {}
    for _, key in ipairs(moves) do mon.pp[key] = moveData[key].maxPP end
end

local function drain(battle, onMessage)
    local script = battle.machine:get("script")
    local guard = 0
    while battle:phase() == "script" do
        guard = guard + 1
        if guard > 200 then error("script-stuck:" .. tostring(battle.message)) end
        if script.waiting and battle.message then
            if onMessage then onMessage(battle.message) end
            battle.message = nil
        end
        script.waiting = false
        battle.presentationRequest = nil
        script:advance()
    end
end

local function cast(moveKey)
    RulesRNG.seed(1)
    local player = Pokemon("haunter", 30)
    local enemy = Pokemon("slowpoke", 20)
    own(player, {moveKey})
    own(enemy, {"tailWhip"})
    enemy.confusion = 2
    player.statStages.spe = 6
    enemy.statStages.spe = -6
    player.statStages.acc = 6
    enemy.statStages.eva = -6
    local battle = Battle(player, enemy)
    drain(battle)
    if battle:phase() ~= "command" then error(moveKey .. " not-command:" .. battle:phase()) end
    if not battle:selectMove(1) then error(moveKey .. " select failed") end
    local failed = 0
    local counter = nil
    local confused = false
    drain(battle, function(text)
        if text == "But it failed!" then
            failed = failed + 1
            counter = battle.enemy.confusion
        end
        if text:find("became confused", 1, true) then confused = true end
    end)
    if failed ~= 1 then error(moveKey .. " fail-count " .. failed) end
    if counter ~= 2 then error(moveKey .. " counter " .. tostring(counter)) end
    if confused then error(moveKey .. " reapplied confusion") end
    if battle.enemy.confusion ~= 2 and battle.enemy.confusion ~= 1 then
        error(moveKey .. " counter left the original value: " .. tostring(battle.enemy.confusion))
    end
    io.write(moveKey .. " failed-and-kept 2\n")
end

cast("confuseRay")
cast("supersonic")
io.write("confuse-ray-flow-ok\n")
