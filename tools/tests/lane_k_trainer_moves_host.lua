-- Prints Pokemon.trainerMovesFor for the parties the Python test passes in.
local ROOT = assert(arg[1], "repo path required")
local REQUEST = assert(arg[2], "party request required")
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
import "data/pokemon"
import "data/typechart"
import "battle/dsl"
import "battle/moves"

for item in REQUEST:gmatch("[^;]+") do
    local class, index, species, level = item:match("([^|]+)|([^|]+)|([^|]+)|([^|]+)")
    local moves = Pokemon.trainerMovesFor(species, tonumber(level), class, tonumber(index))
    print(string.format("moves %s %s %s %s %s", class, index, species, level, table.concat(moves, ",")))
end
print("trainer-moves-host-ok")
