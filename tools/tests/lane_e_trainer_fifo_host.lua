-- Trainer send-out keeps pokered move ids. pret/pokered af519899
-- NUM_ATTACKS is 165. A B2W2 id above that must not fill a party slot.
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
import "data/typechart"
import "battle/dsl"
import "battle/moves"

local function joined(keys)
    return table.concat(keys, ",")
end

local lee = Pokemon.trainerMovesFor("hitmonlee", 55)
if joined(lee) ~= "jumpKick,focusEnergy,highJumpKick,megaKick" then
    error("Hitmonlee 55 trainer moves are " .. joined(lee))
end
local leaked = Pokemon.initialMovesFor("hitmonlee", 55)
if joined(leaked) ~= joined(lee) then
    error("wild Hitmonlee 55 kept a later id: " .. joined(leaked))
end

local function assertPokered(species, level)
    local moves = Pokemon.trainerMovesFor(species, level)
    if joined(moves) ~= joined(PokeredLearnsets.movesAtLevel(species, level)) then
        error(species .. " " .. level .. " trainer moves are " .. joined(moves))
    end
    if #moves < 1 or #moves > 4 then
        error(species .. " " .. level .. " has " .. #moves .. " moves")
    end
end

assertPokered("onix", 53)
assertPokered("onix", 56)
assertPokered("geodude", 12)
assertPokered("poliwag", 18)
assertPokered("machamp", 58)

local banned = {
    magnetBomb = true, rapidSpin = true, furyCutter = true, magnitude = true,
    spark = true, rollout = true, rainDance = true, waterSport = true, charge = true,
    wideGuard = true, flail = true,
}
local function assertInitial(species, level, expected)
    local moves = Pokemon.initialMovesFor(species, level)
    for _, key in ipairs(moves) do
        if banned[key] then
            error(species .. " " .. level .. " initial " .. key)
        end
    end
    if joined(moves) ~= expected then
        error(species .. " " .. level .. " initial moves are " .. joined(moves))
    end
end

assertInitial("magnemite", 21, "tackle,sonicBoom")
assertInitial("sandshrew", 19, "scratch,sandAttack,slash")
assertInitial("voltorb", 18, "tackle,screech,sonicBoom")
assertInitial("poliwag", 18, "bubble,hypnosis")
assertInitial("poliwag", 1, "bubble")
assertInitial("voltorb", 1, "tackle,screech")
assertInitial("magikarp", 30, "splash,tackle")
print("trainer-fifo-held")
