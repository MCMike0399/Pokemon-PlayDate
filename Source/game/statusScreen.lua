-- Standalone pdz. PartyState loads it with playdate.file.run("game/statusScreen")
-- while STATS or SUMMARY is open and nils StatusScreen when that page closes.
-- It is not imported, so a boot that never opens those pages does not keep
-- this rasterizer or its glyph images.
--
-- status_screen.asm StatusScreen and StatusScreen2. The name is hlcoord 9, 1.
-- StatsText is ATTACK / DEFENSE / SPEED / SPECIAL, two rows apart, inside
-- the box at hlcoord 0, 8. SPECIAL is that one line; the figure is the
-- special attack. StatusScreen2 prints the moves at hlcoord 2, 9 and PP
-- one row below each move. Text is the uniform 12/8 scale. One 12x12 image
-- is cached per glyph and dropped in StatusScreen.release.
StatusScreen = {}
local gfx = playdate and playdate.graphics
local STATUS_FIT <const> = 12
local glyphs = {}
local front

local function statusFitTile(sheetName, index)
    local key = sheetName .. ":" .. index
    local cached = glyphs[key]
    if cached then return cached end
    local sheet = GbFont.load()[sheetName]
    local columns = sheetName == "ed" and 1 or 16
    local sx = (index % columns) * 8
    local sy = math.floor(index / columns) * 8
    local image = gfx.image.new(STATUS_FIT, STATUS_FIT, gfx.kColorWhite)
    gfx.pushContext(image)
    gfx.setDrawOffset(0, 0)
    gfx.setColor(gfx.kColorBlack)
    for y = 0, STATUS_FIT - 1 do
        local sourceY = sy + math.floor(y * 8 / STATUS_FIT)
        for x = 0, STATUS_FIT - 1 do
            local sourceX = sx + math.floor(x * 8 / STATUS_FIT)
            if sheet:sample(sourceX, sourceY) == gfx.kColorBlack then
                gfx.drawPixel(x, y)
            end
        end
    end
    gfx.popContext()
    glyphs[key] = image
    return image
end

local function statusFitAt(sheetName, index, col, row)
    local ox = math.floor((TitleIdle.COL - STATUS_FIT) / 2)
    local oy = TitleIdle.ROW - STATUS_FIT
    statusFitTile(sheetName, index):draw(col * TitleIdle.COL + ox, row * TitleIdle.ROW + oy)
end

local function statusFitString(text, col, row)
    local cursor, index = 0, 1
    while index <= #text do
        local nextIndex, sheetName, glyph = TitleIdle.nextTile(text, index)
        statusFitAt(sheetName, glyph, col + cursor, row)
        cursor = cursor + 1
        index = nextIndex
    end
end

local STATUS_CONDITION <const> = {poison="PSN", badPoison="PSN", burn="BRN", paralyze="PAR", sleep="SLP", freeze="FRZ"}

local function statusPad(value, digits)
    return string.format("%" .. digits .. "d", math.max(0, math.floor(value or 0)))
end

local function statusFront(mon)
    if not front or front.species ~= mon.species then
        front = {species = mon.species, pic = gfx.image.new("images/pokemon/" .. mon.species .. "-front")}
    end
    local pic = front.pic
    if not pic then return end
    local _, height = pic:getSize()
    if height > 0 then pic:drawScaled(TitleIdle.COL, 0, (6 * TitleIdle.ROW) / height) end
end

local function statusHpBar(col, row, tiles, hp, maxHP)
    local x = col * TitleIdle.COL
    local y = row * TitleIdle.ROW + 4
    local w = tiles * TitleIdle.COL
    local h = 5
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(x, y, w, h)
    local fill = maxHP > 0 and math.floor((w - 2) * math.max(0, hp) / maxHP) or 0
    if fill > 0 then gfx.fillRect(x + 1, y + 1, fill, h - 2) end
end

local function statusLineBox(col, row, down, across)
    for i = 0, down - 1 do GbFont.drawChar("│", col, row + i) end
    GbFont.drawChar("┘", col, row + down)
    for i = 1, across do GbFont.drawChar("─", col - i, row + down) end
end

function StatusScreen.drawStatus(state, mon)
    statusFront(mon)
    statusLineBox(19, 1, 6, 10)
    statusFitString(mon.name, 9, 1)
    statusFitString("L" .. string.format("%2d", mon.level), 14, 2)
    statusFitString(string.format("%03d", mon.dex or 0), 3, 7)
    statusHpBar(11, 3, 6, mon.hp, mon.maxHP)
    statusFitString(statusPad(mon.hp, 3) .. "/" .. statusPad(mon.maxHP, 3), 12, 4)
    statusFitString("STATUS/", 9, 6)
    statusFitString(STATUS_CONDITION[mon.status] or "OK", 16, 6)
    statusLineBox(19, 9, 8, 6)
    statusFitString("TYPE1/", 10, 9)
    statusFitString("TYPE2/", 10, 11)
    statusFitString("IDNo/", 10, 13)
    statusFitString("OT/", 10, 15)
    statusFitString(string.upper(mon.type or ""), 11, 10)
    if mon.type2 then statusFitString(string.upper(mon.type2), 11, 12) end
    statusFitString(Story.playerName(state.game), 12, 16)
    GbFont.drawBox(TitleIdle.textBox(0, 8, 8, 8))
    local stats = {
        {"ATTACK", mon.atk}, {"DEFENSE", mon.def},
        {"SPEED", mon.spe}, {"SPECIAL", mon.spa},
    }
    for index, stat in ipairs(stats) do
        local row = 9 + (index - 1) * 2
        statusFitString(stat[1], 1, row)
        statusFitString(statusPad(stat[2], 3), 6, row + 1)
    end
end

function StatusScreen.drawSummary(state, mon)
    statusFront(mon)
    statusLineBox(19, 1, 6, 10)
    statusFitString(mon.name, 9, 1)
    statusFitString("EXP POINTS", 9, 3)
    statusFitString("LEVEL UP", 9, 5)
    statusFitString(statusPad(mon.xp or 0, 7), 12, 4)
    local remain = math.max(0, (mon.xpToNext or 0) - (mon.xp or 0))
    statusFitString(statusPad(remain, 7), 7, 6)
    -- <to> is one tile at column 14 (status_screen.asm). The dex font
    -- has no <to> tile, so the two letters fill column 14 and the blank
    -- column before PrintLevel at column 16.
    statusFitString("to", 14, 6)
    statusFitString("L" .. string.format("%2d", math.min(100, mon.level + 1)), 16, 6)
    GbFont.drawBox(TitleIdle.textBox(0, 8, 18, 8))
    for index, key in ipairs(mon.moves) do
        local row = 9 + (index - 1) * 2
        local move = moveData[key]
        statusFitString(string.upper(move.name), 2, row)
        statusFitString("PP", 11, row + 1)
        statusFitString(statusPad(mon.pp[key] or 0, 2) .. "/" .. statusPad(move.maxPP or move.pp or 0, 2), 14, row + 1)
    end
end

function StatusScreen.release()
    for key in pairs(glyphs) do glyphs[key] = nil end
    front = nil
end
