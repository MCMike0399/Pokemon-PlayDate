-- Playdate drawText treats * as bold and _ as italic. A literal mark is
-- two of the same character. pokered data/types/names.asm (af519899)
-- prints PSYCHIC; the constant PSYCHIC_TYPE is not a display name.
-- DARK and STEEL are the Gen V names this battle engine also draws.

DrawnText = {}

local DISPLAY <const> = {
    NORMAL = "NORMAL", normal = "NORMAL",
    FIGHTING = "FIGHTING", fighting = "FIGHTING",
    FLYING = "FLYING", flying = "FLYING",
    POISON = "POISON", poison = "POISON",
    GROUND = "GROUND", ground = "GROUND",
    ROCK = "ROCK", rock = "ROCK",
    BIRD = "BIRD", bird = "BIRD",
    BUG = "BUG", bug = "BUG",
    GHOST = "GHOST", ghost = "GHOST",
    FIRE = "FIRE", fire = "FIRE",
    WATER = "WATER", water = "WATER",
    GRASS = "GRASS", grass = "GRASS",
    ELECTRIC = "ELECTRIC", electric = "ELECTRIC",
    PSYCHIC = "PSYCHIC", psychic = "PSYCHIC",
    PSYCHIC_TYPE = "PSYCHIC",
    ICE = "ICE", ice = "ICE",
    DRAGON = "DRAGON", dragon = "DRAGON",
    DARK = "DARK", dark = "DARK",
    STEEL = "STEEL", steel = "STEEL",
}

function DrawnText.typeName(value)
    local name <const> = DISPLAY[value]
    if not name then
        error("unknown type name " .. tostring(value))
    end
    return name
end

function DrawnText.escape(text)
    if text == nil then
        return ""
    end
    return (tostring(text):gsub("([_*])", "%1%1"))
end

local function plain(text)
    if type(text) ~= "string" then
        return text
    end
    return DrawnText.escape(text)
end

-- drawTextInRect and drawTextAligned call drawText. Escape once, then
-- hand the already-escaped string to the raw functions so a mark is not doubled.
function DrawnText.install(graphics)
    if not graphics or graphics.__drawnTextInstalled then
        return
    end
    local rawDraw <const> = graphics.drawText
    local rawRect <const> = graphics.drawTextInRect
    local rawAligned <const> = graphics.drawTextAligned
    local rawSize <const> = graphics.getTextSize
    if rawDraw then
        graphics.drawText = function(text, ...)
            return rawDraw(plain(text), ...)
        end
    end
    if rawSize then
        graphics.getTextSize = function(text, ...)
            return rawSize(plain(text), ...)
        end
    end
    local function callingRaw(original, text, ...)
        local savedDraw <const> = graphics.drawText
        local savedSize <const> = graphics.getTextSize
        if rawDraw then graphics.drawText = rawDraw end
        if rawSize then graphics.getTextSize = rawSize end
        local results <const> = {pcall(original, plain(text), ...)}
        graphics.drawText = savedDraw
        graphics.getTextSize = savedSize
        if not results[1] then
            error(results[2])
        end
        return table.unpack(results, 2)
    end
    if rawRect then
        graphics.drawTextInRect = function(text, ...)
            return callingRaw(rawRect, text, ...)
        end
    end
    if rawAligned then
        graphics.drawTextAligned = function(text, ...)
            return callingRaw(rawAligned, text, ...)
        end
    end
    graphics.__drawnTextInstalled = true
end

if playdate and playdate.graphics then
    DrawnText.install(playdate.graphics)
end
