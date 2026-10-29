-- Compact canonical rows stay resident; requested arrays can be collected.
PokemonLearnsets = {}
local encoded = {}
local decoded = setmetatable({}, {__mode = "v"})
local moveLists = setmetatable({}, {__mode = "v"})

local function entries(record)
    local dex = record.dex
    if decoded[dex] then
        return decoded[dex]
    end
    local result = {}
    for row in assert(encoded[dex], "missing compact learnset"):gmatch("[^;]+") do
        local move, level, order, id = row:match("^([%w_]+)|(%d+)|([^|]+)|(%d+)$")
        assert(move and (order == "-" or order:match("^%d+$")), "invalid compact learnset")
        result[#result + 1] = {
            move = move, level = tonumber(level),
            order = order ~= "-" and tonumber(order) or nil, id = tonumber(id),
        }
    end
    decoded[dex] = result
    return result
end

local metadata = {
    __index = function(record, key)
        if key == "learnset" then
            return entries(record)
        end
        if key == "moves" then
            local result = moveLists[record.dex]
            if not result then
                result = {}
                for _, entry in ipairs(entries(record)) do
                    result[#result + 1] = entry.move
                end
                moveLists[record.dex] = result
            end
            return result
        end
    end,
    __pairs = function(record)
        local key
        local rawDone = false
        local virtual = 0
        return function()
            if not rawDone then
                local value
                key, value = next(record, key)
                if key then
                    return key, value
                end
                rawDone = true
            end
            while virtual < 2 do
                virtual = virtual + 1
                local field = virtual == 1 and "learnset" or "moves"
                if rawget(record, field) == nil then
                    return field, record[field]
                end
            end
        end
    end,
}

function PokemonLearnsets.install(roster)
    for _, record in pairs(roster) do
        assert(type(record.learnset) == "string" and getmetatable(record) == nil,
            "compact species definition required")
        encoded[record.dex] = record.learnset
        record.learnset = nil
        if record.moves == false then
            record.moves = nil
        end
        setmetatable(record, metadata)
    end
end
