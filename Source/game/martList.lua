-- Pokered priced list and money box.
-- home/list_menu.asm PrintListMenuEntries, data/text_boxes.asm
-- LIST_MENU_BOX and MONEY_BOX_TEMPLATE, engine/menus/text_box.asm DisplayMoneyBox.
-- af519899. The list has no shop title and no button hint.
MartList = {}

local COL, ROW = 20, 13
local VISIBLE = 4
-- Same inset as GbFont.drawFitAt. The spare pixels sit above the glyph
-- so the yen's top row cannot enter the name cell.
MartList.CELL_W = COL
MartList.CELL_H = ROW
MartList.GLYPH = 12
-- home/list_menu.asm PrintListMenuEntries: the name is hlcoord 6, 4 and the
-- price is SCREEN_WIDTH + 5 from there, column 11. The 7-tile BCD field
-- ends on column 17. Column 18 is the ▼ at (18, 11) in home/window.asm.
MartList.PRICE_COLUMN = 11
MartList.PRICE_RIGHT = 17
-- engine/menus/text_box.asm DisplayMoneyBox prints at hlcoord 12, 1.
MartList.MONEY_COLUMN = 12
MartList.MONEY_RIGHT = 18

function MartList.glyphBox(col, row)
    local ox = math.floor((MartList.CELL_W - MartList.GLYPH) / 2)
    local oy = MartList.CELL_H - MartList.GLYPH
    return {
        col = col, row = row,
        x = col * MartList.CELL_W + ox,
        y = row * MartList.CELL_H + oy,
        w = MartList.GLYPH, h = MartList.GLYPH,
    }
end

function MartList.interior(box)
    return {
        x = box.x + COL, y = box.y + ROW,
        w = box.w - 2 * COL, h = box.h - 2 * ROW,
        col = box.col + 1, row = box.row + 1,
        cols = box.innerW, rows = box.innerH,
    }
end

function MartList.box(col, row, innerW, innerH)
    return {
        col = col, row = row, innerW = innerW, innerH = innerH,
        x = col * COL, y = row * ROW,
        w = (innerW + 2) * COL, h = (innerH + 2) * ROW,
    }
end

function MartList.boxes()
    -- LIST_MENU_BOX (4,2)-(19,12): inner 14 by 9.
    -- MONEY_BOX_TEMPLATE (11,0)-(19,2): inner 7 by 1.
    -- MESSAGE_BOX (0,12): inner 18 by 4. The list and the money box share
    -- row 2; the list and the message box share row 12.
    return {
        money = MartList.box(11, 0, 7, 1),
        list = MartList.box(4, 2, 14, 9),
        message = MartList.box(0, 12, 18, 4),
    }
end

function MartList.figure(amount)
    -- home/print_bcd.asm PrintBCDNumber. The call is
    -- `ld c, 3 | LEADING_ZEROES | MONEY_SIGN` from both
    -- PrintListMenuEntries and DisplayMoneyBox.
    -- constants/text_constants.asm: bit 7 is LEADING_ZEROES and, when set,
    -- suppresses leading zeroes; bit 5 prints ¥ immediately before the
    -- first nonzero digit; bits 0-4 are 3 BCD bytes, six digits. Bit 6
    -- (LEFT_ALIGN) is clear, so a suppressed digit leaves a space.
    -- An all-zero value steps back one column and prints ¥0.
    amount = math.max(0, math.min(999999, math.floor(amount or 0)))
    local digits = string.format("%06d", amount)
    local out, started = {}, false
    for index = 1, 6 do
        local digit = digits:sub(index, index)
        if not started then
            if digit == "0" then
                out[#out + 1] = " "
            else
                out[#out + 1] = "¥"
                out[#out + 1] = digit
                started = true
            end
        else
            out[#out + 1] = digit
        end
    end
    if not started then return "     ¥0" end
    return table.concat(out)
end

function MartList.window(count, selected)
    local total = count + 1
    selected = math.max(1, math.min(selected or 1, total))
    local first = 1
    if total > VISIBLE and selected > VISIBLE then
        first = selected - VISIBLE + 1
    end
    local lastStart = math.max(1, total - VISIBLE + 1)
    if first > lastStart then first = lastStart end
    return first, VISIBLE, total, selected
end

local function put(cells, glyphs, col, row, text, region)
    cells[#cells + 1] = {col = col, row = row, text = text, region = region}
    local cursor = 0
    for char in text:gmatch(utf8.charpattern) do
        local box = MartList.glyphBox(col + cursor, row)
        box.char = char
        box.region = region
        glyphs[#glyphs + 1] = box
        cursor = cursor + 1
    end
end

local function wrapped(text)
    local lines = {}
    for raw in (text .. "\n"):gmatch("(.-)\n") do
        local line = ""
        for word in raw:gmatch("%S+") do
            local joined = line == "" and word or (line .. " " .. word)
            if #joined > 18 and line ~= "" then
                lines[#lines + 1] = line
                line = word
            else
                line = joined
            end
        end
        if line ~= "" then lines[#lines + 1] = line end
    end
    return lines
end

function MartList.paint(rows, selected, money, trade, resultText)
    local cells, glyphs, clears = {}, {}, {}
    local function place(col, row, text, region)
        put(cells, glyphs, col, row, text, region)
    end
    -- data/text_boxes.asm MoneyText is drawn on the top border at (13, 0).
    -- PlaceString replaces those tiles. The fit glyph does not cover the
    -- dash, so each label cell, including a gap in the span, is
    -- cleared to white before the letters are drawn.
    local function clearSpan(col, row, text)
        for index = 0, utf8.len(text) - 1 do
            local glyphCol = col + index
            clears[#clears + 1] = {
                col = glyphCol, row = row,
                x = glyphCol * COL, y = row * ROW, w = COL, h = ROW,
            }
        end
    end
    clearSpan(13, 0, "MONEY")
    place(13, 0, "MONEY", "money")
    place(MartList.MONEY_COLUMN, 1, MartList.figure(money), "money")
    local first, visible, total = MartList.window(#rows, selected)
    for slot = 0, visible - 1 do
        local index = first + slot
        if index > total then break end
        local nameRow = 4 + slot * 2
        if index == selected then place(5, nameRow, "▶", "list") end
        if index <= #rows then
            local row = rows[index]
            place(6, nameRow, row.name, "list")
            if trade == "buy" then
                place(MartList.PRICE_COLUMN, nameRow + 1, MartList.figure(row.price), "list")
            elseif row.quantity then
                place(14, nameRow + 1, "×" .. string.format("%02d", math.min(99, row.quantity)), "list")
            end
        else
            place(6, nameRow, "CANCEL", "list")
        end
    end
    if first + visible - 1 < total then place(18, 11, "▼", "list") end
    if resultText and resultText ~= "" then
        local lines = wrapped(resultText)
        for index, line in ipairs(lines) do
            if index > 2 then break end
            place(1, 12 + index * 2, line, "message")
        end
    elseif trade == "sell" then
        place(1, 14, "What would you", "message")
        place(1, 16, "like to sell?", "message")
    else
        place(1, 14, "Take your time.", "message")
    end
    return {
        boxes = MartList.boxes(),
        cells = cells,
        glyphs = glyphs,
        clears = clears,
        rows = VISIBLE,
        title = false,
        hint = false,
    }
end

function MartList.occupied(paint)
    local ink = {}
    local function mark(col, row, kind)
        ink[col .. "," .. row] = kind
    end
    local function border(box)
        local right = box.col + box.innerW + 1
        local bottom = box.row + box.innerH + 1
        for col = box.col, right do
            mark(col, box.row, "border")
            mark(col, bottom, "border")
        end
        for row = box.row, bottom do
            mark(box.col, row, "border")
            mark(right, row, "border")
        end
    end
    -- Message, then money, then the list, matching the buy loop's draw order.
    border(paint.boxes.message)
    border(paint.boxes.money)
    border(paint.boxes.list)
    for _, cell in ipairs(paint.cells) do
        local col = cell.col
        for _ in cell.text:gmatch(utf8.charpattern) do
            mark(col, cell.row, "text")
            col = col + 1
        end
    end
    return ink
end
