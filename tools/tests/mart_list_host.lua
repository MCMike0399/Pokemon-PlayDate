-- Ink and bounds for the pokered mart list. af519899 home/list_menu.asm
-- and data/text_boxes.asm. Fails until lane-e-mart-list-fidelity.patch
-- adds Source/game/martList.lua.
local ROOT = assert(arg[1], "repo path required")
dofile(ROOT .. "/Source/game/martList.lua")

local function eq(actual, expected, label)
    if actual ~= expected then
        error(label .. " expected " .. tostring(expected) .. " got " .. tostring(actual))
    end
end

local boxes = MartList.boxes()
eq(boxes.money.col, 11, "money column")
eq(boxes.money.row, 0, "money row")
eq(boxes.money.innerW, 7, "money inner width")
eq(boxes.money.innerH, 1, "money inner height")
eq(boxes.money.x, 220, "money x")
eq(boxes.money.y, 0, "money y")
eq(boxes.money.w, 180, "money width")
eq(boxes.money.h, 39, "money height")
eq(boxes.list.col, 4, "list column")
eq(boxes.list.row, 2, "list row")
eq(boxes.list.innerW, 14, "list inner width")
eq(boxes.list.innerH, 9, "list inner height")
eq(boxes.list.x, 80, "list x")
eq(boxes.list.y, 26, "list y")
eq(boxes.list.w, 320, "list width")
eq(boxes.list.h, 143, "list height")
eq(boxes.list.y, boxes.money.y + boxes.money.h - 13, "money box and list share one row")
eq(boxes.message.col, 0, "message column")
eq(boxes.message.row, 12, "message row")
eq(boxes.message.innerW, 18, "message inner width")
eq(boxes.message.innerH, 4, "message inner height")
eq(boxes.message.x, 0, "message x")
eq(boxes.message.y, 156, "message y")
eq(boxes.message.w, 400, "message width")
eq(boxes.message.h, 78, "message height")
eq(boxes.message.y, boxes.list.y + boxes.list.h - 13, "list and message share one row")
eq(MartList.figure(2100), "¥002100", "buy figure")
eq(MartList.figure(1050), "¥001050", "sell figure")
eq(MartList.figure(3000), "¥003000", "money figure")

local function joined(paint)
    local lines = {}
    for _, cell in ipairs(paint.cells) do lines[#lines + 1] = cell.text end
    return table.concat(lines, "\n")
end
local function forbid(paint)
    local text = joined(paint)
    for _, needle in ipairs({"POKE MART", "A: Choose", "B: Back", "B: Leave"}) do
        if text:find(needle, 1, true) then error("list paints " .. needle) end
    end
end
local function cell(paint, text, row)
    for _, entry in ipairs(paint.cells) do
        if entry.text == text and entry.row == row then return entry end
    end
    error("missing " .. text .. " on row " .. tostring(row))
end

local rows = {
    {name = "POKE DOLL", price = 1000, quantity = 1},
    {name = "FIRE STONE", price = 2100, quantity = 1},
    {name = "THUNDERSTONE", price = 2100, quantity = 1},
    {name = "WATER STONE", price = 2100, quantity = 1},
    {name = "LEAF STONE", price = 2100, quantity = 1},
    {name = "LINK CABLE", price = 2100, quantity = 1},
}
local paint = MartList.paint(rows, 1, 3000, "buy", nil)
eq(paint.title, false, "title is not drawn")
eq(paint.hint, false, "hint is not drawn")
eq(paint.rows, 4, "four visible rows")
forbid(paint)
local name = cell(paint, "POKE DOLL", 4)
eq(name.col, 6, "name column")
local price = cell(paint, "¥001000", 5)
eq(price.col, 11, "price column")
eq(price.row, name.row + 1, "price sits one row under the name")
local cursor = cell(paint, "▶", 4)
eq(cursor.col, 5, "cursor column")
eq(cell(paint, "MONEY", 0).col, 13, "MONEY column")
eq(cell(paint, "¥003000", 1).col, 12, "amount column")
eq(cell(paint, "Take your time.", 14).col, 1, "buy greeting")
local ink = MartList.occupied(paint)
local function has(col, row)
    return ink[col .. "," .. row] ~= nil
end
eq(has(0, 1), false, "old POKE MART title cell is blank")
eq(has(1, 15), false, "old A: Choose hint cell is blank")
eq(has(11, 0), true, "money box corner")
eq(has(13, 0), true, "MONEY ink")
eq(has(12, 1), true, "yen ink")
eq(has(18, 1), true, "last money digit")
eq(has(4, 2), true, "list box corner")
eq(has(19, 12), true, "list box lower right")
eq(has(6, 4), true, "name ink")
for _, entry in ipairs(paint.cells) do
    if entry.row == name.row and entry.text:find("¥", 1, true) then
        error("price sits on the name row")
    end
end
eq(price.row, name.row + 1, "price ink is the row under the name")
eq(has(11, 5), true, "price ink")
eq(has(17, 5), true, "last price digit")
eq(has(18, 5), false, "price stops inside the list")
eq(has(1, 14), true, "greeting ink")

local scrolled = MartList.paint(rows, 6, 900, "buy", nil)
forbid(scrolled)
local scrolledInk = MartList.occupied(scrolled)
eq(scrolledInk["6,10"] ~= nil, true, "scrolled LINK CABLE name")
eq(scrolledInk["11,11"] ~= nil, true, "scrolled price stays inside the list")
eq(scrolledInk["18,11"] ~= nil, true, "down arrow")
eq(cell(scrolled, "LINK CABLE", 10).col, 6, "cable name")
eq(cell(scrolled, "¥002100", 11).col, 11, "cable price")
eq(cell(scrolled, "¥000900", 1).col, 12, "money after the purchase")

local sell = MartList.paint({{name = "LINK CABLE", price = 1050, quantity = 1}}, 1, 900, "sell", nil)
forbid(sell)
eq(sell.boxes.list.x, boxes.list.x, "sell uses the list box")
eq(sell.boxes.money.x, boxes.money.x, "sell uses the money box")
eq(cell(sell, "×01", 5).col, 14, "sell quantity")
local sellText = joined(sell)
if sellText:find("¥001050", 1, true) then error("the sell list prints a price") end
eq(cell(sell, "What would you", 14).col, 1, "sell greeting")
eq(cell(sell, "like to sell?", 16).col, 1, "sell greeting second line")
local sellInk = MartList.occupied(sell)
eq(sellInk["0,1"] == nil, true, "sell list leaves the title cell blank")
eq(sellInk["1,15"] == nil, true, "sell list leaves the hint cell blank")
