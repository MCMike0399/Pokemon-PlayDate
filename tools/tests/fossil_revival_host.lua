-- Host driver for the unactivated fossil service. It is not part of the Playdate build.
local ROOT = assert(arg[1], "repo path required")
local OPS = assert(arg[2], "scenario file required")
local CANONICAL = assert(arg[3], "generator revival required")
local SOURCE = ROOT .. "/Source/"

local loaded = {}
-- Playdate Lua accepts compound assignment. PUC Lua 5.4 does not.
-- Rewrite only a plain field or name so the real module still executes.
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
    if not ok then
        loaded[name] = nil
        error(problem)
    end
    local chunk = problem
    ok, problem = pcall(chunk)
    if not ok then
        loaded[name] = nil
        error(problem)
    end
end

json = {}
local function decodeJson(text)
    local i, n = 1, #text
    local function peek()
        return text:sub(i, i)
    end
    local function skip()
        while i <= n and text:sub(i, i):match("%s") do i = i + 1 end
    end
    local parse
    local function parseString()
        i = i + 1
        local out = {}
        while i <= n do
            local c = text:sub(i, i)
            if c == '"' then
                i = i + 1
                return table.concat(out)
            end
            if c == "\\" then
                local esc = text:sub(i + 1, i + 1)
                local simple = {['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t"}
                if esc == "u" then
                    local hex = text:sub(i + 2, i + 5)
                    out[#out + 1] = utf8.char(assert(tonumber(hex, 16), "bad unicode escape"))
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
        if text:sub(i, i):match("[eE]") then
            i = i + 1
            if text:sub(i, i):match("[+-]") then i = i + 1 end
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
                assert(mark == ",", "expected comma in array")
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
                assert(peek() == '"', "expected object key")
                local key = parseString()
                skip()
                assert(peek() == ":", "expected colon")
                i = i + 1
                object[key] = parse()
                skip()
                local mark = peek()
                if mark == "}" then i = i + 1; return object end
                assert(mark == ",", "expected comma in object")
                i = i + 1
            end
        end
        error("unexpected json at " .. i .. ": " .. text:sub(i, i + 20))
    end
    local value = parse()
    skip()
    assert(i > n, "trailing json")
    return value
end

function json.decode(text)
    return decodeJson(text)
end

function json.decodeFile(path)
    local handle = assert(io.open(SOURCE .. path, "r"))
    local text = assert(handle:read("a"))
    handle:close()
    return decodeJson(text)
end

local function readAll(path)
    local handle = assert(io.open(path, "r"))
    local text = assert(handle:read("a"))
    handle:close()
    return text
end

local NULL = {}
local function encode(value)
    local kind = type(value)
    if value == nil or value == NULL then return "null" end
    if kind == "boolean" then return value and "true" or "false" end
    if kind == "number" then
        assert(value == value and math.abs(value) ~= math.huge, "nonfinite json number")
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
    assert(kind == "table", "unsupported json value")
    local count = 0
    for _ in pairs(value) do count = count + 1 end
    if count == #value then
        local parts = {}
        for index = 1, count do parts[index] = encode(value[index]) end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    local parts = {}
    for key, item in pairs(value) do
        assert(type(key) == "string", "json object keys must be strings")
        parts[#parts + 1] = encode(key) .. ":" .. encode(item)
    end
    table.sort(parts)
    return "{" .. table.concat(parts, ",") .. "}"
end

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
import "domain/gameSession"
import "game/daycare"
import "game/fossilRevival"

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

local function countSpecies(session, species)
    local total = 0
    for _, mon in ipairs(session:party():members()) do
        if mon.species == species then total = total + 1 end
    end
    for box = 1, Storage.BOX_COUNT do
        for index = 1, session:storage():count(box) do
            if session:storage():get(index, box).species == species then total = total + 1 end
        end
    end
    return total
end

local function snapshot(session, revival)
    local gave, still, handing = (function()
        local clear = revival.still_reviving_cleared_on_map_load.event
        local gaveFlag
        for _, flag in ipairs(revival.give_sets) do
            if flag ~= clear then gaveFlag = flag end
        end
        return gaveFlag, clear, revival.handover_sets[1]
    end)()
    local items, owned, counts = {}, {}, {}
    for _, row in ipairs(revival.results) do
        items[row.item] = session:inventory():quantity(assert(ItemData.bySymbol[row.item]))
        local id
        for species, name in pairs(PokemonNames) do
            if name == row.species then id = species end
        end
        owned[row.species] = session:pokedex().owned[id] == true
        counts[row.species] = countSpecies(session, id)
    end
    local record = FossilRevival.pending(session)
    return {
        flags = {[gave] = session:questFlag(gave), [still] = session:questFlag(still), [handing] = session:questFlag(handing)},
        items = items,
        owned = owned,
        counts = counts,
        party = session:party():count(),
        box = session:storage():count(),
        boxIndex = session:storage():activeBox(),
        pending = record or NULL,
        rolls = session:rngData().rolls,
    }
end

local function fill(session, partyOnly)
    local limit = partyOnly and Party.CAPACITY or (Party.CAPACITY + Storage.BOX_CAPACITY)
    for _ = 1, limit do
        local ok, reason = session:recruit(Pokemon("pidgey", 2))
        if not ok then error(reason) end
    end
    return {ok = true, status = partyOnly and "party-filled" or "party-and-box-filled"}
end

local function perform(session, revival, step)
    local op = step.op
    if op == "add" then
        local ok, reason = session:inventory():add(assert(ItemData.bySymbol[step.symbol]), 1)
        return {ok = ok and true or false, status = ok and "added" or reason}
    elseif op == "take" then
        local ok, reason = session:inventory():handoffKey(assert(ItemData.bySymbol[step.symbol]))
        return {ok = ok and true or false, status = ok and "taken" or reason}
    elseif op == "confirm" then
        return FossilRevival.confirm(session, step.item, step.accepted, revival)
    elseif op == "cancel" then
        return FossilRevival.cancel()
    elseif op == "talk" then
        return FossilRevival.talk(session, revival)
    elseif op == "map" then
        return FossilRevival.onMapLoad(session, step.map, revival)
    elseif op == "fill" then
        return fill(session, step.partyOnly == true)
    elseif op == "box" then
        local ok, reason = session:storage():selectBox(step.index)
        return {ok = ok and true or false, status = ok and "box-selected" or reason}
    end
    error("unknown fossil host op: " .. tostring(op))
end

local function main()
    local canonical = decodeJson(readAll(CANONICAL))
    local scenarios = decodeJson(readAll(OPS)).scenarios
    local output = {plan = FossilRevival.plan(), scenarios = {}}
    for _, scenario in ipairs(scenarios) do
        local revival = scenario.revival or canonical
        local session = newSession()
        local steps = {}
        for _, step in ipairs(scenario.steps) do
            local result = perform(session, revival, step)
            steps[#steps + 1] = {op = step.op, result = result, state = snapshot(session, revival)}
        end
        output.scenarios[scenario.name] = steps
    end
    io.stdout:write(encode(output))
    io.stdout:write("\n")
end

local ok, err = xpcall(main, function(problem)
    return debug.traceback(tostring(problem), 2)
end)
if not ok then
    io.stderr:write(err, "\n")
    os.exit(1)
end
