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

-- main_menu.asm TextSpeedOptionText, BattleAnimationOptionText,
-- BattleStyleOptionText, OptionMenuCancelText. CRANK SCROLL is the
-- approved Playdate row and is not in pokered. Text speed stays FAST
-- by the approved options decision; pokered InitOptions uses MEDIUM.
GameOptions.rows = {
    {key = "textSpeed", label = "TEXT SPEED", choices = {"FAST", "MEDIUM", "SLOW"}},
    {key = "battleAnimations", label = "BATTLE ANIMATION", choices = {"ON", "OFF"}},
    {key = "battleStyle", label = "BATTLE STYLE", choices = {"SHIFT", "SET"}},
    {key = "crankScrolling", label = "CRANK SCROLL", choices = {"OFF", "ON"}},
}
GameOptions.cancelLabel = "CANCEL"
-- The three source boxes occupy rows 0-4, 5-9 and 10-14. CANCEL is its
-- own row, under the crank row, with a blank row between them.
GameOptions.CRANK_ROW = 15
GameOptions.CANCEL_ROW = 17

function GameOptions.lastBox()
    return TitleIdle.textBox(0, 10, 18, 3)
end

function GameOptions.crankPlace(choiceIndex)
    local choiceCol = choiceIndex == 1 and 14 or 17
    return {row = GameOptions.CRANK_ROW, labelCol = 1, choiceCol = choiceCol}
end

function GameOptions.crankRect()
    return TitleIdle.cellRect(1, GameOptions.CRANK_ROW, 18, 1)
end

function GameOptions.cancelPlace(selected)
    return {row = GameOptions.CANCEL_ROW, col = 2, cursor = selected and 1 or nil}
end

function GameOptions.cancelRect()
    return TitleIdle.cellRect(1, GameOptions.CANCEL_ROW, 8, 1)
end

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
