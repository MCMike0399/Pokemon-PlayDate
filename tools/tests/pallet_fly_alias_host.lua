-- Load the real FieldTravel module and alias a pre-cutover Pallet visit.
local root = assert(arg[1], "project root required")

local function integer(n, low, high)
    return type(n) == "number" and n % 1 == 0 and n >= low and n <= high
end

local function primitive(value, visited)
    local kind = type(value)
    if kind == "boolean" or kind == "string" then return value end
    if kind == "number" then return value end
    assert(kind == "table" and getmetatable(value) == nil, "primitive table required")
    visited = visited or {}
    assert(not visited[value], "cyclic data")
    visited[value] = true
    local out = {}
    for key, item in pairs(value) do
        out[key] = primitive(item, visited)
    end
    visited[value] = nil
    return out
end

local function array(value, limit)
    if type(value) ~= "table" or getmetatable(value) ~= nil or #value > limit then return false end
    local count = 0
    for key in pairs(value) do
        if not integer(key, 1, #value) then return false end
        count = count + 1
    end
    return count == #value
end

Party = {
    _primitive = primitive,
    _array = array,
    _integer = integer,
}

GameSession = {}
function GameSession._object(value, allowed)
    assert(type(value) == "table" and getmetatable(value) == nil, "plain object required")
    for key in pairs(value) do
        assert(allowed[key], "unknown field: " .. tostring(key))
    end
end

local function decode(text)
    local index = 1
    local function peek()
        return text:sub(index, index)
    end
    local function skip()
        while peek():match("%s") do index = index + 1 end
    end
    local parse
    local function parseString()
        assert(peek() == '"', "string expected")
        index = index + 1
        local parts = {}
        while true do
            local char = peek()
            assert(char ~= "", "unterminated string")
            index = index + 1
            if char == '"' then return table.concat(parts) end
            if char == "\\" then
                local escaped = peek()
                index = index + 1
                parts[#parts + 1] = escaped
            else
                parts[#parts + 1] = char
            end
        end
    end
    local function parseNumber()
        local start = index
        if peek() == "-" then index = index + 1 end
        while peek():match("%d") do index = index + 1 end
        return tonumber(text:sub(start, index - 1))
    end
    parse = function()
        skip()
        local char = peek()
        if char == '"' then return parseString() end
        if char == "{" then
            index = index + 1
            local object = {}
            skip()
            if peek() == "}" then index = index + 1; return object end
            while true do
                skip()
                local key = parseString()
                skip()
                assert(peek() == ":", "colon expected")
                index = index + 1
                object[key] = parse()
                skip()
                local mark = peek()
                index = index + 1
                if mark == "}" then return object end
                assert(mark == ",", "object separator expected")
            end
        end
        if char == "[" then
            index = index + 1
            local list = {}
            skip()
            if peek() == "]" then index = index + 1; return list end
            while true do
                list[#list + 1] = parse()
                skip()
                local mark = peek()
                index = index + 1
                if mark == "]" then return list end
                assert(mark == ",", "array separator expected")
            end
        end
        return parseNumber()
    end
    return parse()
end

json = {}
function json.decodeFile(path)
    local handle = assert(io.open(root .. "/Source/" .. path, "rb"))
    local text = handle:read("*a")
    handle:close()
    return decode(text)
end

dofile(root .. "/Source/domain/fieldTravel.lua")

local function travel(cities)
    return {version = 1, mode = "walking", strength = false, visited = cities}
end

local function show(...)
    local parts = {}
    for index = 1, select("#", ...) do
        parts[index] = tostring(select(index, ...))
    end
    print(table.concat(parts, " "))
end

local function rejects(cities)
    local ok = pcall(FieldTravel.normalize, travel(cities))
    return not ok
end

local authored = travel({"pallet_town", "pokered:VIRIDIAN_CITY"})
local normalized = FieldTravel.normalize(authored)
show("caller", table.concat(authored.visited, ","))
show("alias", table.concat(normalized.visited, ","))

local places = FieldTravel.destinations(normalized)
show("destination-count", #places)
for _, entry in ipairs(places) do
    show("destination", entry.id, entry.source_map, entry.x, entry.y, entry.name)
end

local function arrival(entry)
    return {zone_id = entry.id, x = entry.x, y = entry.y, facing = "down"}
end
local position = {zone_id = "pokered:ROUTE_1", x = 10, y = 35, facing = "up"}
local plan = assert(FieldTravel.fly(normalized, position, "pokered:PALLET_TOWN", true, arrival))
show("fly", plan.location.zone_id, plan.location.x, plan.location.y, plan.travel.mode)
local _, reason = FieldTravel.fly(normalized, position, "pallet_town", true, arrival)
show("old-id", reason)

local canonical = FieldTravel.normalize(travel({"pokered:PALLET_TOWN"}))
show("canonical", table.concat(canonical.visited, ","))
local empty = FieldTravel.normalize(travel({}))
show("empty", #empty.visited, #FieldTravel.destinations(empty))
local other = FieldTravel.normalize(travel({"pokered:VIRIDIAN_CITY"}))
show("other", table.concat(other.visited, ","), #FieldTravel.destinations(other))
show("duplicate", rejects({"pallet_town", "pokered:PALLET_TOWN"}) and "rejected" or "accepted")
show("unknown", rejects({"route_1"}) and "rejected" or "accepted")
