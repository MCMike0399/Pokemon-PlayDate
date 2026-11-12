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

function GbFont.drawChar(char, col, row)
    local sheetName, index = TitleIdle.glyph(char)
    tileImage(sheetName, index):draw(col * TitleIdle.COL, row * TitleIdle.ROW)
end

function GbFont.drawString(text, col, row)
    local cursor = 0
    for _, code in utf8.codes(text) do
        GbFont.drawChar(utf8.char(code), col + cursor, row)
        cursor = cursor + 1
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
    local cursor = x
    for _, code in utf8.codes(text) do
        local char = utf8.char(code)
        local sheetName, index = TitleIdle.glyph(char)
        local sheet = sheets[sheetName]
        local sx = (index % 16) * 8
        local sy = math.floor(index / 16) * 8
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
    end
end
