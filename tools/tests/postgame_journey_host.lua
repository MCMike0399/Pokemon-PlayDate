-- Headless postgame journey. Not part of the Playdate build.
-- The Pallet actor snapshot is a fixture: SourceActors and the real map
-- actors are not loaded, so Continue reconciles WorldMotionData.empty().
local ROOT = assert(arg[1], "repo path required")
local PATH = assert(arg[2], "journey file required")
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
    local chunk, problem = loadPlaydate(SOURCE .. name .. ".lua")
    if not chunk then
        loaded[name] = nil
        error(problem)
    end
    local ok
    ok, problem = pcall(chunk)
    if not ok then
        loaded[name] = nil
        error(problem)
    end
end

local function readAll(path)
    local handle = assert(io.open(path, "r"))
    local text = assert(handle:read("a"))
    handle:close()
    return text
end

local function decodeJson(text)
    local i, n = 1, #text
    local function peek() return text:sub(i, i) end
    local function skip()
        while i <= n and text:sub(i, i):match("%s") do i = i + 1 end
    end
    local parse
    local function parseString()
        i = i + 1
        local out = {}
        while i <= n do
            local c = text:sub(i, i)
            if c == '"' then i = i + 1; return table.concat(out) end
            if c == "\\" then
                local esc = text:sub(i + 1, i + 1)
                local simple = {['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t"}
                if esc == "u" then
                    out[#out + 1] = utf8.char(assert(tonumber(text:sub(i + 2, i + 5), 16)))
                    i = i + 6
                else
                    out[#out + 1] = assert(simple[esc], "bad string escape")
                    i = i + 2
                end
            else
                out[#out + 1] = c
                i = i + 1
            end
        end
        error("unterminated string")
    end
    local function parseNumber()
        local start = i
        if peek() == "-" then i = i + 1 end
        while text:sub(i, i):match("%d") do i = i + 1 end
        if peek() == "." then
            i = i + 1
            while text:sub(i, i):match("%d") do i = i + 1 end
        end
        local value = assert(tonumber(text:sub(start, i - 1)), "bad number")
        return math.tointeger(value) or value
    end
    function parse()
        skip()
        local c = peek()
        if c == '"' then return parseString() end
        if c == "-" or c:match("%d") then return parseNumber() end
        if text:sub(i, i + 3) == "true" then i = i + 4; return true end
        if text:sub(i, i + 4) == "false" then i = i + 5; return false end
        if text:sub(i, i + 3) == "null" then i = i + 4; return nil end
        if c == "[" then
            i = i + 1
            local array = {}
            skip()
            if peek() == "]" then i = i + 1; return array end
            while true do
                array[#array + 1] = parse()
                skip()
                local mark = peek()
                if mark == "]" then i = i + 1; return array end
                assert(mark == ",", "expected comma")
                i = i + 1
            end
        end
        if c == "{" then
            i = i + 1
            local object = {}
            skip()
            if peek() == "}" then i = i + 1; return object end
            while true do
                skip()
                local key = parseString()
                skip()
                assert(peek() == ":", "expected colon")
                i = i + 1
                object[key] = parse()
                skip()
                local mark = peek()
                if mark == "}" then i = i + 1; return object end
                assert(mark == ",", "expected comma")
                i = i + 1
            end
        end
        error("unexpected json at " .. i)
    end
    local value = parse()
    skip()
    assert(i > n, "trailing json")
    return value
end

local function encode(value)
    local kind = type(value)
    if value == nil then return "null" end
    if kind == "boolean" then return value and "true" or "false" end
    if kind == "number" then
        local integer = math.tointeger(value)
        if integer then return string.format("%d", integer) end
        return string.format("%.17g", value)
    end
    if kind == "string" then
        return '"' .. value:gsub('[%z\1-\31\\"]', function(char)
            local simple = {['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t"}
            return simple[char] or string.format("\\u%04x", string.byte(char))
        end) .. '"'
    end
    local count = 0
    for _ in pairs(value) do count = count + 1 end
    if count == #value then
        local parts = {}
        for index = 1, count do parts[index] = encode(value[index]) end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    local parts = {}
    for key, item in pairs(value) do
        parts[#parts + 1] = encode(key) .. ":" .. encode(item)
    end
    table.sort(parts)
    return "{" .. table.concat(parts, ",") .. "}"
end

json = {decode = decodeJson, decodeFile = function(path)
    return decodeJson(readAll(SOURCE .. path))
end}

import "lib/oop"
import "battle/dsl"
import "battle/moves"
import "lib/rng"
import "data/individualData"
import "domain/individualStats"
import "data/pokemon"
import "domain/party"
import "domain/storage"
import "domain/inventory"
import "data/items"
import "domain/worldMotion"
import "domain/itemStorage"
import "domain/coinWallet"
import "domain/safariGame"
import "domain/fieldTravel"
import "domain/decimalInteger"
import "domain/gameSession"
import "domain/npcTrades"
import "domain/pokemonCodec"
import "game/daycare"
import "domain/sessionCodec"

-- Fixture. The Playdate actor surface is not loaded in this host.
SourceActors = {describe = function()
    return {zone_id = "pokered:PALLET_TOWN", revision = "postgame-journey-fixture", actors = {}}
end}
function WorldMotionData.reconcile()
    return WorldMotionData.empty()
end

local savedSession
local function continueSession(session)
    local record, reason = SessionCodec.encode(session, {root = "overworld", overworld = "explore", settled = true})
    if not record then return nil, reason end
    local decoded = decodeJson(encode(record))
    local deps = GameSession._state(session).deps
    return SessionCodec.decode(decoded, {
        validateWorld = deps.validateWorld,
        resolveLocation = deps.resolveLocation,
        resolvePlayerLocation = deps.resolvePlayerLocation,
        validateActors = deps.validateActors,
        hiddenActors = deps.hiddenActors,
        itemDefinitions = ItemData.definitions,
    })
end

GameContext = {installSession = function(_, candidate) return candidate end}
GameSaves = {
    continueGame = function()
        local loaded, why = continueSession(savedSession)
        if not loaded then error(tostring(why)) end
        return GameContext:installSession(loaded)
    end,
    continuePreparedTitle = function() return true end,
}
import "game/postgameStory"

local function newSession()
    local function accept(value) return value end
    local session = GameSession.newSession({
        validateWorld = accept,
        resolveLocation = accept,
        itemDefinitions = ItemData.definitions,
    }, {
        world = {schema = 1, zones = {}, zone_count = 0},
        location = {zone_id = "pokered:PALLET_TOWN", x = 0, y = 0, facing = "down"},
        seed = 1,
    })
    assert(session:activateRNG())
    return session
end

local function fill(session)
    local ok, reason = session:recruit(Pokemon("squirtle", 5))
    if not ok then error(reason) end
    local ready, problem = session:setIntro({stage = "done", starter = "squirtle", rivalStarter = "bulbasaur"})
    if not ready then error(problem) end
end

local function hashLocation(value, location)
    local facing = ({up = 1, down = 2, left = 3, right = 4})[location.facing]
    return (value * 33 + location.x * 131 + location.y * 17 + facing + #location.zone_id) % 10000019
end

local function battle(session, request)
    local ok, result = pcall(SourceEncounters.prepare, session, request, session:location())
    if ok then
        return {attempted = true, ok = true, species = result.definition.species}
    end
    return {attempted = true, ok = false, error = tostring(result)}
end

local function requestOf(session, id)
    return PostgameStory.staticRequest(id, session:flags().quest)
end

local journey = decodeJson(readAll(PATH))
local session = newSession()
fill(session)
for _, flag in ipairs(journey.quest_flags) do
    assert(session:setQuestFlag(flag, true), flag)
end
for _, trainer in ipairs(journey.defeated_trainers) do
    assert(session:setTrainerDefeated(trainer, true), trainer)
end
assert(session:recordHallOfFame({{species = "squirtle", level = 5, name = "SQUIRTLE"}}))
assert(session:setLocation({zone_id = "pokered:HALL_OF_FAME", x = 4, y = 2, facing = "up"}))
savedSession = session
local continued = GameSaves:continueGame()
assert(continued:activateRNG())
local where = continued:location()
local flags = continued:flags().quest
local kept = {}
for _, flag in ipairs(journey.quest_flags) do kept[flag] = flags[flag] == true end
local hash = 0
local mewtwoAt, zapdosAt
local mewtwoRequest, zapdosRequest, mewtwoBattle, zapdosBattle
for index, step in ipairs(journey.steps) do
    local moved, why = continued:setLocation({
        zone_id = step.zone, x = step.x, y = step.y, facing = step.facing,
    })
    if not moved then error("step " .. index .. " " .. tostring(why)) end
    local location = continued:location()
    hash = hashLocation(hash, location)
    if index - 1 == journey.mewtwo_index then
        mewtwoAt = {zone = location.zone_id, x = location.x, y = location.y, facing = location.facing}
        mewtwoRequest = requestOf(continued, "pokered:CERULEAN_CAVE_B1F:objects:1")
        mewtwoBattle = battle(continued, mewtwoRequest)
    elseif index - 1 == journey.zapdos_index then
        zapdosAt = {zone = location.zone_id, x = location.x, y = location.y, facing = location.facing}
        zapdosRequest = requestOf(continued, "pokered:POWER_PLANT:objects:9")
        zapdosBattle = battle(continued, zapdosRequest)
    end
end
io.stdout:write(encode({
    actor_snapshot = "fixture-empty",
    continue = {zone = where.zone_id, x = where.x, y = where.y, facing = where.facing},
    hall_teams = #continued:hallOfFame().teams,
    flags = kept,
    rival_defeated = continued:trainerDefeated("pokered:CERULEAN_CITY:objects:1"),
    steps = #journey.steps,
    hash = hash,
    mewtwo = mewtwoAt,
    zapdos = zapdosAt,
    mewtwo_request = mewtwoRequest,
    zapdos_request = zapdosRequest,
    mewtwo_battle = mewtwoBattle,
    zapdos_battle = zapdosBattle,
}))
io.stdout:write("\n")
