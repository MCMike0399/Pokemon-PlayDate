-- Pinned Blue hidden items and the Itemfinder window.
-- Hidden coins stay on the Celadon service that already owns those 12 rows.
import "game/sourceEvents"

HiddenItems = {}
local CONTENT <const> = "hidden-items"
local installed
local cached

local function rows()
    if cached then return cached end
    local data = assert(json.decodeFile("data/hiddenItems.json"))
    assert(data.schema == 1 and data.source_revision == "af519899719f0754965776faac0e836a3b906e6d",
        "unverified hidden item table")
    assert(#data.items == 54 and #data.coins == 12, "pinned hidden item and coin counts")
    cached = data.items
    return cached
end

-- engine/items/itemfinder.asm: item Y is inside (player Y - 5, player Y + 4]
-- and item X is inside (player X - 5, player X + 5], with the low side clamped at 0.
function HiddenItems.near(px, py, ix, iy)
    local yLow = py - 5
    local xLow = px - 5
    if yLow < 0 then yLow = 0 end
    if xLow < 0 then xLow = 0 end
    return yLow < iy and iy <= py + 4 and xLow < ix and ix <= px + 5
end

local function text(label)
    local found = {
        source = "data/text/text_2.asm",
        recipe = {
            {op = "text", text = "<PLAYER> found"},
            {op = "line", text = "@"},
            {op = "text_ram", symbol = "wNameBuffer"},
            {op = "text", text = "!"},
            {op = "control", source = "text_end"},
        },
    }
    local full = {
        source = "data/text/text_2.asm",
        recipe = {
            {op = "text", text = "But, <PLAYER> has"},
            {op = "line", text = "no more room for"},
            {op = "cont", text = "other items!"},
            {op = "control", source = "done"},
        },
    }
    if label == "_FoundHiddenItemText" then return found end
    if label == "_HiddenItemBagFullText" then return full end
    return nil
end

function HiddenItems.install()
    assert(not installed, "hidden items already installed")
    local events = {}
    for _, row in ipairs(rows()) do
        if not SourceEvents.has(row.id) then
            events[row.id] = {
                content = CONTENT,
                kind = "pickup",
                item = row.item,
                flag = row.flag,
                success = {"_FoundHiddenItemText"},
                full = {"_HiddenItemBagFullText"},
            }
        end
    end
    SourceEvents.registerImmutableEventSource(CONTENT, events)
    SourceEvents.registerTextSource(CONTENT, text)
    SourceEvents.registerWorldHooks("pokered:VIRIDIAN_FOREST:hidden:finder", {
        interact = HiddenItems.tryInteract,
    })
    installed = true
end

function HiddenItems.tryInteract(game)
    if not currentZone or not game.player then return false end
    local x, y = game.player:getFacingTile()
    local map = currentZone.stableID
    for _, row in ipairs(rows()) do
        if row.map_id == map and row.x == x and row.y == y and not game.session:questFlag(row.flag) then
            return SourceEvents.dispatch(game, row.id)
        end
    end
    return false
end

function HiddenItems.use(bag)
    if bag.battle or not currentZone or not bag.game or not bag.game.player then
        return false, "not-now"
    end
    local px, py = bag.game.player.gridX, bag.game.player.gridY
    local map = currentZone.stableID
    local found = false
    for _, row in ipairs(rows()) do
        if row.map_id == map and not bag.session:questFlag(row.flag)
            and HiddenItems.near(px, py, row.x, row.y) then
            found = true
            break
        end
    end
    if found then
        bag:showMessage("Yes! ITEMFINDER indicates there's an item nearby.")
    else
        bag:showMessage("Nope! ITEMFINDER isn't responding.")
    end
    return true
end
