-- Application preferences are independent of every adventure/save slot.
GameOptions = {}
local values
local allowed <const> = {
    textSpeed = {"SLOW", "MEDIUM", "FAST"},
    battleAnimations = {"ON", "OFF"},
    battleStyle = {"SHIFT", "SET"},
    crankScrolling = {"OFF", "ON"},
}
local defaults <const> = {textSpeed = "FAST", battleAnimations = "ON", battleStyle = "SHIFT", crankScrolling = "OFF"}

local function registeredKey(id)
    if id == "none" then
        return true
    end
    if type(id) ~= "string" then
        return false
    end
    local item = ItemData.definitions[id]
    return item ~= nil and item.keyItem == true
end

local function valid(key, value)
    for _, candidate in ipairs(allowed[key] or {}) do
        if value == candidate then
            return true
        end
    end
    return false
end

function GameOptions.load()
    if values then
        return
    end
    values = {}
    local ok, record = pcall(playdate.datastore.read, "game-options")
    for key, fallback in pairs(defaults) do
        values[key] = fallback
        if ok and type(record) == "table" and valid(key, record[key]) then
            values[key] = record[key]
        end
    end
    values.registeredItem = "none"
    if ok and type(record) == "table" and registeredKey(record.registeredItem) then
        values.registeredItem = record.registeredItem
    end
end

function GameOptions.crankScrolling()
    GameOptions.load()
    return values.crankScrolling == "ON"
end

function GameOptions.registeredItem()
    GameOptions.load()
    if values.registeredItem == "none" then
        return nil
    end
    return values.registeredItem
end

function GameOptions.setRegisteredItem(id)
    GameOptions.load()
    if id == nil then
        id = "none"
    end
    if not registeredKey(id) then
        return false, "invalid-key-item"
    end
    values.registeredItem = id
    return true
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
    if not valid(key, value) then
        return false, "invalid-option"
    end
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
