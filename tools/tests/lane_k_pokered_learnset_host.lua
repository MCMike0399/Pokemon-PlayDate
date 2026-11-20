-- Wild/gift construction and one level-up, for the pokered learnset test.
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
    local chunk = assert(loadPlaydate(SOURCE .. name .. ".lua"))
    local ok, problem = pcall(chunk)
    if not ok then error(problem) end
end

playdate = {
    kButtonA = 1,
    buttonJustPressed = function() return false end,
    buttonIsPressed = function() return false end,
    datastore = { read = function() return nil end },
    graphics = setmetatable({}, { __index = function() return function() return 0 end end }),
}

import "lib/oop"
import "lib/rng"
import "lib/statemachine"
import "data/individualData"
import "domain/individualStats"
import "data/growthData"
import "domain/growth"
import "data/pokemon"
import "data/typechart"
import "battle/dsl"
import "battle/moves"

local function joined(moves)
    return table.concat(moves, ",")
end

local function offers(species, level)
    local mon = Pokemon(species, level - 1)
    local _, result = mon:gainXP(mon:xpForLevel(level) - mon.xp)
    local names = {}
    for _, choice in ipairs(result.moveChoices) do
        names[#names + 1] = choice.move .. "@" .. choice.level
    end
    return table.concat(names, ",")
end

print("initial charmander 15 " .. joined(Pokemon.initialMovesFor("charmander", 15)))
print("initial staryu 18 " .. joined(Pokemon.initialMovesFor("staryu", 18)))
print("constructed charmander 15 " .. joined(Pokemon("charmander", 15).moves))
local entries = {}
for _, entry in ipairs(Pokemon.learnsetEntriesFor("charmander", 15, 15)) do
    entries[#entries + 1] = entry.move .. "@" .. entry.level .. "#" .. tostring(entry.id)
end
print("entries charmander 15 " .. table.concat(entries, ","))
print("level charmander 15 " .. offers("charmander", 15))
print("level staryu 17 " .. offers("staryu", 17))
print("pokered-learnset-host-ok")
