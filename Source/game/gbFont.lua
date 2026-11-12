-- Pokered 8x8 font at the GB-to-Playdate integer 2x. Every glyph is
-- 16x16, nearest neighbor, so a tile is never stretched to the 20x13
-- screen cell. gfx/font/font.png, font_extra.png, and the HUD tiles.
-- constants/charmap.asm. The battle HUD tiles are gfx/font/font_battle_extra.2bpp
-- and gfx/battle/battle_hud_1.1bpp after LoadHudTilePatterns.
import "game/titleIdle"

GbFont = {}
GbFont.TILE = 16
local gfx = playdate and playdate.graphics
local sheets
local cache = {}
local HUD_COLUMNS <const> = 13

local function loadSheet(path)
    local image = gfx.image.new(path)
    assert(image, "missing font sheet " .. path)
    return image
end

function GbFont.load()
    if sheets then return sheets end
    sheets = {
        font = loadSheet("images/title/font/font"),
        extra = loadSheet("images/title/font/extra"),
        ed = loadSheet("images/title/font/ed"),
        hud = loadSheet("images/battle/hud"),
    }
    return sheets
end

local function columnsOf(sheetName)
    if sheetName == "ed" then return 1 end
    if sheetName == "hud" then return HUD_COLUMNS end
    return 16
end

-- Exact 2x. Source pixel (sx + floor(px/2), sy + floor(py/2)).
local function blit(sheetName, index, x, y)
    local key = sheetName .. ":" .. index
    local image = cache[key]
    if not image then
        local sheet = GbFont.load()[sheetName]
        local columns = columnsOf(sheetName)
        local sx = (index % columns) * 8
        local sy = math.floor(index / columns) * 8
        image = gfx.image.new(GbFont.TILE, GbFont.TILE, gfx.kColorWhite)
        gfx.pushContext(image)
        gfx.setDrawOffset(0, 0)
        gfx.setColor(gfx.kColorBlack)
        for py = 0, GbFont.TILE - 1 do
            local sourceY = sy + math.floor(py / 2)
            for px = 0, GbFont.TILE - 1 do
                local sourceX = sx + math.floor(px / 2)
                if sheet:sample(sourceX, sourceY) == gfx.kColorBlack then
                    gfx.drawPixel(px, py)
                end
            end
        end
        gfx.popContext()
        cache[key] = image
    end
    image:draw(x, y)
end

function GbFont.line(text, x, y)
    local cursor = x
    for _, code in utf8.codes(text or "") do
        local sheetName, index = TitleIdle.glyph(utf8.char(code))
        blit(sheetName, index, cursor, y)
        cursor = cursor + GbFont.TILE
    end
end

function GbFont.clip(text, maxChars)
    local out, count = {}, 0
    for _, code in utf8.codes(text or "") do
        if count >= maxChars then break end
        out[#out + 1] = utf8.char(code)
        count = count + 1
    end
    return table.concat(out)
end

function GbFont.drawChar(char, col, row)
    local tile = GbFont.TILE
    local sheetName, index = TitleIdle.glyph(char)
    blit(sheetName, index, col * tile, row * tile)
end

function GbFont.drawString(text, col, row)
    GbFont.line(text, col * GbFont.TILE, row * GbFont.TILE)
end

function GbFont.drawBox(box)
    local tile = box.tile or GbFont.TILE
    local cols = math.floor(box.w / tile)
    local rows = math.floor(box.h / tile)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(box.x, box.y, cols * tile, rows * tile)
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
            if char then
                local sheetName, index = TitleIdle.glyph(char)
                blit(sheetName, index, box.x + col * tile, box.y + row * tile)
            end
        end
    end
end

-- One naming-screen cell. PK, MN and ED are single tiles, not two letters.
function GbFont.drawCell(token, x, y)
    local sheetName, index = TitleIdle.glyph(token)
    blit(sheetName, index, x, y)
end

-- Same 16px line. Callers that used the tight path stay on the uniform scale.
function GbFont.drawTight(text, x, y)
    GbFont.line(text, x, y)
end

-- home/pokemon.asm DrawHPBar. wHPBarType 1 (battle) uses the right cap that
-- LoadHudTilePatterns wrote over vChars2 $6d. The bar length d is 6.
local HUD_INDEX <const> = {
    lv = 0, hp = 1, barLeft = 2, barEmpty = 3,
    bar1 = 4, bar2 = 5, bar3 = 6, bar4 = 7, bar5 = 8, bar6 = 9, bar7 = 10,
    barFull = 11, barRight = 12,
}

function GbFont.hudTile(name, x, y)
    blit("hud", HUD_INDEX[name], x, y)
end

local function barTile(pixels)
    if pixels >= 8 then return "barFull" end
    if pixels <= 0 then return "barEmpty" end
    return "bar" .. pixels
end

-- side is "enemy" or "player". A status replaces the level, matching
-- PrintLevel being skipped once a status tile is on the name row.
function GbFont.drawBattleHud(side, info)
    local layout = TitleIdle.battleHud(side, info)
    local tile = GbFont.TILE
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(layout.x, layout.y, layout.w, layout.h)
    GbFont.line(layout.name, layout.x, layout.y)
    if layout.status then
        GbFont.line(layout.status, layout.levelX, layout.y)
    else
        GbFont.hudTile("lv", layout.levelX, layout.y)
        GbFont.line(layout.levelText, layout.levelX + tile, layout.y)
    end
    local barY = layout.y + tile
    GbFont.hudTile("hp", layout.x, barY)
    GbFont.hudTile("barLeft", layout.x + tile, barY)
    local filled = 0
    if layout.maxHp > 0 then
        filled = math.floor((layout.hp / layout.maxHp) * (layout.segments * 8) + 0.5)
    end
    for index = 0, layout.segments - 1 do
        local pixels = math.max(0, math.min(8, filled - index * 8))
        GbFont.hudTile(barTile(pixels), layout.x + (2 + index) * tile, barY)
    end
    GbFont.hudTile("barRight", layout.x + (2 + layout.segments) * tile, barY)
    if layout.numbers then
        local numberX = layout.x + layout.w - utf8.len(layout.numbers) * tile
        GbFont.line(layout.numbers, numberX, layout.y + 2 * tile)
    end
end
