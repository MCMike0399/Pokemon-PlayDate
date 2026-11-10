-- Live Zone water policy versus SeaRoutes. WaterEncounters projects the table
-- and Zone._readEncounterMapPolicy must return that projection.
local root = arg[1]
local waterPath = arg[2]
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path

local function decode(text)
    local i, n = 1, #text
    local function skip()
        while i <= n and text:sub(i, i):match("%s") do i = i + 1 end
    end
    local parse
    local function parseString()
        assert(text:sub(i, i) == '"')
        i = i + 1
        local out = {}
        while true do
            local c = text:sub(i, i)
            if c == '"' then i = i + 1 break end
            if c == "\\" then error("unsupported json escape") end
            out[#out + 1] = c
            i = i + 1
        end
        return table.concat(out)
    end
    local function parseNumber()
        local start = i
        if text:sub(i, i) == "-" then i = i + 1 end
        while text:sub(i, i):match("%d") do i = i + 1 end
        return tonumber(text:sub(start, i - 1))
    end
    function parse()
        skip()
        local c = text:sub(i, i)
        if c == '"' then return parseString() end
        if c == "{" then
            i = i + 1
            local object = {}
            skip()
            if text:sub(i, i) == "}" then i = i + 1 return object end
            while true do
                skip()
                local key = parseString()
                skip()
                assert(text:sub(i, i) == ":")
                i = i + 1
                object[key] = parse()
                skip()
                local mark = text:sub(i, i)
                i = i + 1
                if mark == "}" then return object end
                assert(mark == ",")
            end
        end
        if c == "[" then
            i = i + 1
            local array = {}
            skip()
            if text:sub(i, i) == "]" then i = i + 1 return array end
            while true do
                array[#array + 1] = parse()
                skip()
                local mark = text:sub(i, i)
                i = i + 1
                if mark == "]" then return array end
                assert(mark == ",")
            end
        end
        if text:sub(i, i + 3) == "true" then i = i + 4 return true end
        if text:sub(i, i + 4) == "false" then i = i + 5 return false end
        if text:sub(i, i + 3) == "null" then i = i + 4 return nil end
        return parseNumber()
    end
    return parse()
end

local handle = assert(io.open(waterPath, "rb"))
local water = decode(handle:read("a"))
handle:close()

function Class()
    local cls = {}
    cls.__index = cls
    return setmetatable(cls, {__call = function() return setmetatable({}, cls) end})
end
Party = {
    _integer = function(value, low, high)
        return type(value) == "number" and value % 1 == 0 and value >= low and value <= high
    end,
    _array = function(value, count)
        return type(value) == "table" and #value <= count
    end,
}
pokemonData = {tentacool = {name = "TENTACOOL"}}

dofile(root .. "/game/waterEncounters.lua")
local projected = WaterEncounters.project(water)
local levels = {}
for index, slot in ipairs(projected.slots) do
    assert(slot.species == "tentacool" and slot.minLevel == slot.maxLevel and slot.weight == water.slots[index].weight_256,
        "projection drifted from the SeaRoutes slot")
    levels[index] = tostring(slot.minLevel)
end
assert(projected.kind == "byte" and projected.value == 5, "SeaRoutes water rate is 5")
print("module matches SeaRoutes " .. table.concat(levels, ","))

dofile(root .. "/world/zone.lua")
local function upvalue(fn, name)
    local index = 1
    while true do
        local found, value = debug.getupvalue(fn, index)
        if not found then return nil end
        if found == name then return value end
        index = index + 1
    end
end
local zone = {imported = true}
function zone:isSliceReady() return true end
upvalue(Zone._readEncounterMapPolicy, "zoneData")[zone] = {sourceWaterEncounters = water}
local ok, result = pcall(function() return Zone._readEncounterMapPolicy(zone, nil, "water") end)
if not ok then
    io.stderr:write("zone.lua rejected Route 19/20 water: " .. tostring(result) .. "\n")
    os.exit(1)
end
local got = {}
for index, slot in ipairs(result.slots) do
    got[index] = tostring(slot.minLevel) .. ":" .. slot.species .. ":" .. tostring(slot.weight)
end
print("zone projected " .. table.concat(got, ","))