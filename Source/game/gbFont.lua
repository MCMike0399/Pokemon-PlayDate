-- Pokered 8x8 font. gfx/font/font.png and font_extra.png through the
-- title-art threshold. constants/charmap.asm. Tiles are scaled to the
-- TitleIdle cell so a TextBoxBorder stays on the 20px by 13px grid.
import "game/titleIdle"

GbFont = {}
local gfx = playdate and playdate.graphics
local sheets
local cache = {}

local function loadSheet(name)
    local image = gfx.image.new("images/title/font/" .. name)
    assert(image, "missing font sheet " .. name)
    return image
end

function GbFont.load()
    if sheets then return sheets end
    sheets = {font = loadSheet("font"), extra = loadSheet("extra"), ed = loadSheet("ed")}
    return sheets
end

local function tileImage(sheetName, index)
    local key = sheetName .. ":" .. index
    local cached = cache[key]
    if cached then return cached end
    local sheet = GbFont.load()[sheetName]
    local columns = 16
    local sx = (index % columns) * 8
    local sy = math.floor(index / columns) * 8
    local image = gfx.image.new(TitleIdle.COL, TitleIdle.ROW, gfx.kColorWhite)
    gfx.pushContext(image)
    gfx.setDrawOffset(0, 0)
    gfx.setColor(gfx.kColorBlack)
    for y = 0, TitleIdle.ROW - 1 do
        local sourceY = sy + math.floor(y * 8 / TitleIdle.ROW)
        for x = 0, TitleIdle.COL - 1 do
            local sourceX = sx + math.floor(x * 8 / TitleIdle.COL)
            if sheet:sample(sourceX, sourceY) == gfx.kColorBlack then
                gfx.drawPixel(x, y)
            end
        end
    end
    gfx.popContext()
    cache[key] = image
    return image
end

-- The fidelity sweep's uniform 12/8 nearest scale of the 8x8 tile.
-- Borders stay on the full 20 by 13 cell (drawChar / drawBox). Text on
-- the title menu, options, naming screen, and continue box uses this
-- inset so a glyph cannot meet the next cell or the border.
GbFont.FIT = 12

local function fitImage(sheetName, index)
    local key = "fit:" .. sheetName .. ":" .. index
    local cached = cache[key]
    if cached then return cached end
    local sheet = GbFont.load()[sheetName]
    local columns = sheetName == "ed" and 1 or 16
    local sx = (index % columns) * 8
    local sy = math.floor(index / columns) * 8
    local image = gfx.image.new(GbFont.FIT, GbFont.FIT, gfx.kColorWhite)
    gfx.pushContext(image)
    gfx.setDrawOffset(0, 0)
    gfx.setColor(gfx.kColorBlack)
    for y = 0, GbFont.FIT - 1 do
        local sourceY = sy + math.floor(y * 8 / GbFont.FIT)
        for x = 0, GbFont.FIT - 1 do
            local sourceX = sx + math.floor(x * 8 / GbFont.FIT)
            if sheet:sample(sourceX, sourceY) == gfx.kColorBlack then
                gfx.drawPixel(x, y)
            end
        end
    end
    gfx.popContext()
    cache[key] = image
    return image
end

function GbFont.drawFitAt(sheetName, index, col, row)
    local ox = math.floor((TitleIdle.COL - GbFont.FIT) / 2)
    local oy = TitleIdle.ROW - GbFont.FIT
    fitImage(sheetName, index):draw(col * TitleIdle.COL + ox, row * TitleIdle.ROW + oy)
end

function GbFont.drawFitChar(char, col, row)
    local sheetName, index = TitleIdle.glyph(char)
    GbFont.drawFitAt(sheetName, index, col, row)
end

function GbFont.drawFitString(text, col, row)
    local cursor, index = 0, 1
    while index <= #text do
        local nextIndex, sheetName, glyph = TitleIdle.nextTile(text, index)
        GbFont.drawFitAt(sheetName, glyph, col + cursor, row)
        cursor = cursor + 1
        index = nextIndex
    end
end

function GbFont.drawChar(char, col, row)
    local sheetName, index = TitleIdle.glyph(char)
    tileImage(sheetName, index):draw(col * TitleIdle.COL, row * TitleIdle.ROW)
end

function GbFont.drawString(text, col, row)
    local cursor, index = 0, 1
    while index <= #text do
        local nextIndex, sheetName, glyph = TitleIdle.nextTile(text, index)
        tileImage(sheetName, glyph):draw((col + cursor) * TitleIdle.COL, row * TitleIdle.ROW)
        cursor = cursor + 1
        index = nextIndex
    end
end

function GbFont.drawBox(box)
    local cols = math.floor(box.w / TitleIdle.COL)
    local rows = math.floor(box.h / TitleIdle.ROW)
    local originCol = math.floor(box.x / TitleIdle.COL)
    local originRow = math.floor(box.y / TitleIdle.ROW)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(box.x, box.y, box.w, box.h)
    for row = 0, rows - 1 do
        for col = 0, cols - 1 do
            local char
            if row == 0 and col == 0 then char = "┌"
            elseif row == 0 and col == cols - 1 then char = "┐"
            elseif row == rows - 1 and col == 0 then char = "└"
            elseif row == rows - 1 and col == cols - 1 then char = "┘"
            elseif row == 0 or row == rows - 1 then char = "─"
            elseif col == 0 or col == cols - 1 then char = "│"
            end
            if char then GbFont.drawChar(char, originCol + col, originRow + row) end
        end
    end
end

-- One naming-screen cell. PK, MN and ED are single tiles, not two letters.
function GbFont.drawCell(token, x, y)
    GbFont.load()
    local sheetName, index = TitleIdle.glyph(token)
    local sheet = sheets[sheetName]
    local columns = sheetName == "ed" and 1 or 16
    local sx = (index % columns) * 8
    local sy = math.floor(index / columns) * 8
    local image = gfx.image.new(16, 16, gfx.kColorWhite)
    gfx.pushContext(image)
    gfx.setColor(gfx.kColorBlack)
    for py = 0, 15 do
        local sourceY = sy + math.floor(py / 2)
        for px = 0, 15 do
            local sourceX = sx + math.floor(px / 2)
            if sheet:sample(sourceX, sourceY) == gfx.kColorBlack then
                gfx.drawPixel(px, py)
            end
        end
    end
    gfx.popContext()
    image:draw(x, y)
end

-- Tight 2x of the 8x8 tile, for a line that is not one glyph per cell.
function GbFont.drawTight(text, x, y)
    GbFont.load()
    local cursor, index = x, 1
    while index <= #text do
        local nextIndex, sheetName, glyph = TitleIdle.nextTile(text, index)
        local sheet = sheets[sheetName]
        local sx = (glyph % 16) * 8
        local sy = math.floor(glyph / 16) * 8
        local image = gfx.image.new(16, 16, gfx.kColorWhite)
        gfx.pushContext(image)
        gfx.setColor(gfx.kColorBlack)
        for py = 0, 15 do
            local sourceY = sy + math.floor(py / 2)
            for px = 0, 15 do
                local sourceX = sx + math.floor(px / 2)
                if sheet:sample(sourceX, sourceY) == gfx.kColorBlack then
                    gfx.drawPixel(px, py)
                end
            end
        end
        gfx.popContext()
        image:draw(cursor, y)
        cursor = cursor + 16
        index = nextIndex
    end
end

-- A money figure is spaces, the charmap yen, and digits. Charmap $f0 is
-- tile 112. Words stay on the current font so the existing boxes still fit,
-- and the yen plus the digits after it use the source tile.
local YEN <const> = utf8.codepoint("¥")

function GbFont.isMoneyFigure(text)
    if text == "" then return true end
    for _, code in utf8.codes(text) do
        if code ~= 32 and code ~= YEN and (code < 48 or code > 57) then
            return false
        end
    end
    return true
end

local function moneyRuns(text)
    local runs = {}
    local codes = {utf8.codepoint(text, 1, -1)}
    local index = 1
    while index <= #codes do
        if codes[index] == YEN then
            local run = "¥"
            index = index + 1
            while index <= #codes and codes[index] >= 48 and codes[index] <= 57 do
                run = run .. string.char(codes[index])
                index = index + 1
            end
            runs[#runs + 1] = {kind = "figure", text = run}
        else
            local chunk = utf8.char(codes[index])
            index = index + 1
            while index <= #codes and codes[index] ~= YEN do
                chunk = chunk .. utf8.char(codes[index])
                index = index + 1
            end
            runs[#runs + 1] = {kind = "text", text = chunk}
        end
    end
    return runs
end

function GbFont.measureMoneyLine(text)
    if GbFont.isMoneyFigure(text) then
        return 16 * (utf8.len(text) or 0), 16
    end
    local width, height = 0, 16
    for _, run in ipairs(moneyRuns(text)) do
        if run.kind == "figure" then
            width = width + 16 * utf8.len(run.text)
        else
            local runWidth, runHeight = gfx.getTextSize(run.text)
            width = width + runWidth
            if runHeight > height then height = runHeight end
        end
    end
    return width, height
end

function GbFont.drawMoneyLine(text, x, y)
    if GbFont.isMoneyFigure(text) then
        GbFont.drawTight(text, x, y)
        return
    end
    local cursor = x
    for _, run in ipairs(moneyRuns(text)) do
        if run.kind == "figure" then
            GbFont.drawTight(run.text, cursor, y)
            cursor = cursor + 16 * utf8.len(run.text)
        else
            gfx.drawText(run.text, cursor, y)
            cursor = cursor + gfx.getTextSize(run.text)
        end
    end
end

function GbFont.drawMoneyRight(text, rightX, y)
    local width = GbFont.measureMoneyLine(text)
    GbFont.drawMoneyLine(text, rightX - width, y)
end
