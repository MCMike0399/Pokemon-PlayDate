-- Pins the Misty assist numbers: B2W2 trainer moves, Gen V crit, Bite range, bridge XP.
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
import "data/growthData"
import "domain/growth"
import "battle/dsl"
import "battle/moves"
import "battle/battle"
import "data/items"

local function band(attacker, defender, key)
    local move = moveData[key]
    local function one(roll)
        local real = RulesRNG.random
        RulesRNG.random = function(a, b)
            if a == 1 and b == BattleEffects.criticalDenominator(0) then return 2 end
            if a == 85 and b == 100 then return roll end
            return real(a, b)
        end
        local result = calcDamage(attacker, defender, move)
        RulesRNG.random = real
        return result.damage
    end
    return one(85), one(100)
end

local function climb(rows)
    local xp = Pokemon("wartortle", 17).xp
    local level = 17
    for _, row in ipairs(rows) do
        xp = xp + Growth.battleAward(pokemonData[row[1]].baseExp, row[2], level, true, 1, false)
        while level < 100 and xp >= Pokemon("wartortle", level):xpForLevel(level + 1) do
            level = level + 1
        end
    end
    return level
end

local staryu = Pokemon("staryu", 18)
local starmie = Pokemon("starmie", 21)
local wartortle = Pokemon("wartortle", 20)
print("staryu-18 " .. table.concat(staryu.moves, ","))
print("starmie-21 " .. table.concat(starmie.moves, ","))
print("wartortle-17 " .. table.concat(Pokemon("wartortle", 17).moves, ","))
print("starmie-hp " .. starmie.maxHP)
print("recover " .. math.floor(starmie.maxHP * 0.5))
print("crit " .. BattleEffects.criticalDenominator(0))
local low, high = band(Pokemon("wartortle", 17), starmie, "bite")
print(string.format("bite-17 %d-%d", low, high))
low, high = band(wartortle, starmie, "bite")
print(string.format("bite-20 %d-%d", low, high))
low, high = band(starmie, wartortle, "swift")
print(string.format("swift-20 %d-%d", low, high))
low, high = band(Pokemon("wartortle", 17), starmie, "waterGun")
print(string.format("watergun-17 %d-%d", low, high))

local battle = Battle(Pokemon("wartortle", 17), starmie, "MISTY")
battle.trainerClass = "OPP_MISTY"
local counts = {}
RulesRNG.seed(1)
for _ = 1, 200 do
    starmie.hp = 1
    local turn = battle:enemyTurn()
    counts[turn.key] = (counts[turn.key] or 0) + 1
end
print(string.format("ai-lowhp swift %d recover %d waterGun %d",
    counts.swift or 0, counts.recover or 0, counts.waterGun or 0))

local line = {
    {"caterpie", 14}, {"weedle", 14}, {"pidgey", 14}, {"nidoranF", 14},
    {"rattata", 14}, {"ekans", 14}, {"zubat", 14},
    {"pidgey", 16}, {"nidoranF", 16}, {"mankey", 18},
    {"rattata", 14}, {"ekans", 14}, {"ekans", 15}, {"zubat", 15},
}
local main = {
    {"caterpie", 14}, {"weedle", 14}, {"pidgey", 14}, {"nidoranF", 14},
    {"rattata", 14}, {"ekans", 14}, {"zubat", 14},
    {"pidgey", 16}, {"nidoranF", 16}, {"mankey", 18},
    {"ekans", 15}, {"zubat", 15},
}
print("bridge-with-side " .. climb(line))
print("bridge-main " .. climb(main))
print("nugget-sell " .. ItemData.definitions.nugget.sellPrice)
print("potion-price " .. ItemData.definitions.potion.price)
print("super-price " .. ItemData.definitions.superPotion.price)
local mart = table.concat(ItemData.marts.ceruleanMartClerkText, ",")
print("cerulean-mart " .. mart)
print("misty-assist-ok")
