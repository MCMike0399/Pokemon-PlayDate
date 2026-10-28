-- Application preferences are independent of every adventure/save slot.
GameOptions = {}
local values
local allowed <const> = {
    textSpeed = {"SLOW", "MEDIUM", "FAST"},
    battleAnimations = {"ON", "OFF"},
    battleStyle = {"SHIFT", "SET"},
}
local defaults <const> = {textSpeed = "FAST", battleAnimations = "ON", battleStyle = "SHIFT"}

local function valid(key, value)
    for _, candidate in ipairs(allowed[key] or {}) do
        if value == candidate then return true end
    end
    return false
end

function GameOptions.load()
    if values then return end
    values = {}
    local ok, record = pcall(playdate.datastore.read, "game-options")
    for key, fallback in pairs(defaults) do
        values[key] = ok and type(record) == "table" and valid(key, record[key]) and record[key] or fallback
    end
end

function GameOptions.textSpeed()
    GameOptions.load()
    return values.textSpeed
end

function GameOptions.battleAnimations()
    GameOptions.load()
    return values.battleAnimations == "ON"
end

function GameOptions.battleStyle()
    GameOptions.load()
    return values.battleStyle
end

function GameOptions.get(key)
    GameOptions.load()
    assert(allowed[key], "unknown application option")
    return values[key]
end

function GameOptions.set(key, value)
    GameOptions.load()
    if not valid(key, value) then return false, "invalid-option" end
    values[key] = value
    return true
end

function GameOptions.cycle(key, direction)
    local current = GameOptions.get(key)
    local choices = allowed[key]
    for index, value in ipairs(choices) do
        if value == current then
            return GameOptions.set(key, choices[(index - 1 + direction) % #choices + 1])
        end
    end
end

function GameOptions.save()
    GameOptions.load()
    local ok, result = pcall(playdate.datastore.write, values, "game-options", true)
    return ok and result ~= false
end
