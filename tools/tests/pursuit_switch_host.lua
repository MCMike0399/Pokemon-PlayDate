-- A voluntary switch into Pursuit must close the party selection before returning.
-- Pursuit defers the active-member commit until after the strike. chooseParty
-- still has to clear selectionKind, or BattleScene:completeSelection asserts
-- "selection-unresolved" and the overlay crashes the battle.
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
    local path = SOURCE .. name .. ".lua"
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
    local script = battle.machine:get("script")
    local guard = 0
    while battle:phase() == "script" do
        guard = guard + 1
        if guard > 160 then error("script did not finish: " .. tostring(battle.message)) end
        script.waiting = false
        battle.presentationRequest = nil
        script:advance()
    end
end

local function own(mon, moves)
    mon.moves = moves
    mon.pp = {}
    for _, key in ipairs(moves) do mon.pp[key] = moveData[key].maxPP end
end

RulesRNG.seed(1)
local lead = Pokemon("venusaur", 62)
local bench = Pokemon("drowzee", 25)
local foe = Pokemon("spearow", 26)
own(lead, {"tackle"})
own(bench, {"confusion"})
own(foe, {"pursuit"})
local party = Party()
assert(party:add(lead))
assert(party:add(bench))
local battle = Battle(lead, foe, nil, {party = party})
drain(battle)
assert(battle:beginSelection("party"))
local ok, reason = battle:chooseParty(2)
if not ok then
    io.write("choose-failed " .. tostring(reason) .. "\n")
    os.exit(1)
end
-- BattleScene:completeSelection rejects a successful choice while this is set.
if battle.selectionKind then
    io.write("selection-unresolved kind " .. tostring(battle.selectionKind) .. "\n")
    os.exit(1)
end
io.write("selection-cleared\n")
io.write("player " .. battle.player.species .. "\n")
