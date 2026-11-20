-- Prints VermilionStory.secondCan for every can and random byte.
-- arg2 is the 15 GymTrashCans rows, five comma-separated bytes, rows joined by ';'.
local ROOT = assert(arg[1], "repo path required")
local TABLE = assert(arg[2], "trash table required")
local SOURCE = ROOT .. "/Source/"

GameSession = { _copy = function(v) return v end }
Party = {
    _integer = function(n, lo, hi)
        return type(n) == "number" and n == math.floor(n) and n >= lo and n <= hi
    end,
}

local function loadPlaydate(path)
    local handle = assert(io.open(path, "r"))
    local source = assert(handle:read("a"))
    handle:close()
    source = source:gsub("([%w_%.]+)%s*([%+%-])=%s*", "%1 = %1 %2 ")
    return assert(load(source, "@" .. path))
end

local rows = {}
for row in TABLE:gmatch("[^;]+") do
    local cells = {}
    for cell in row:gmatch("[^,]+") do cells[#cells + 1] = tonumber(cell) end
    assert(#cells == 5, row)
    rows[#rows + 1] = cells
end
assert(#rows == 15, "15 trash rows required")

VermilionStory = {}
local chunk = assert(loadPlaydate(SOURCE .. "game/vermilionStoryIntent.lua"))
chunk()
function VermilionStory.scenes()
    return {trash = {table = rows}}
end

for first = 0, 14 do
    for byte = 0, 255 do
        print(string.format("second %d %d %d", first, byte, VermilionStory.secondCan(first, byte)))
    end
end
print("trash-can-host-ok")
