-- Standalone pdz. PauseState loads it with playdate.file.run("game/saveScreen")
-- for the SAVE page and nils SaveScreen when that page closes. It is not
-- imported, so a boot that never opens SAVE does not keep this rasterizer,
-- a glyph cache, or a second font.
--
-- engine/menus/main_menu.asm PrintSaveScreenText draws the info box at
-- hlcoord 4, 0 with b = 8 and c = 14. SaveScreenInfoText starts at
-- hlcoord 5, 2 and <NEXT> is two rows, so TIME is column 5 row 8.
-- engine/menus/save.asm SaveTheGame_YesOrNo then calls DisplayTextBoxID
-- TWO_OPTION_MENU at hlcoord 0, 7 with cursor Y = 8 and X = 1.
-- home/text.asm TextBoxBorder writes c inner tiles and then the right
-- border, so data/yes_no_menu_strings.asm YES_NO (width 4, height 3,
-- no blank line) occupies columns 0-5 and rows 7-11. That right border
-- is the same tile as the T of TIME. The later box covers it. YES is
-- border + SCREEN_WIDTH + 2, column 2 row 8, and NO is the next row.
-- Text uses the uniform 12/8 scale. The covered T stays covered.
SaveScreen = {}
local gfx = playdate and playdate.graphics
local SAVE_FIT <const> = 12

local function saveFitTile(sheetName, index)
    local sheet = GbFont.load()[sheetName]
    local columns = sheetName == "ed" and 1 or 16
    local sx = (index % columns) * 8
    local sy = math.floor(index / columns) * 8
    local image = gfx.image.new(SAVE_FIT, SAVE_FIT, gfx.kColorWhite)
    gfx.pushContext(image)
    gfx.setDrawOffset(0, 0)
    gfx.setColor(gfx.kColorBlack)
    for y = 0, SAVE_FIT - 1 do
        local sourceY = sy + math.floor(y * 8 / SAVE_FIT)
        for x = 0, SAVE_FIT - 1 do
            local sourceX = sx + math.floor(x * 8 / SAVE_FIT)
            if sheet:sample(sourceX, sourceY) == gfx.kColorBlack then
                gfx.drawPixel(x, y)
            end
        end
    end
    gfx.popContext()
    return image
end

local function saveFitAt(sheetName, index, col, row)
    local ox = math.floor((TitleIdle.COL - SAVE_FIT) / 2)
    local oy = TitleIdle.ROW - SAVE_FIT
    local image = saveFitTile(sheetName, index)
    image:draw(col * TitleIdle.COL + ox, row * TitleIdle.ROW + oy)
    image = nil
end

local function saveFitChar(char, col, row)
    local sheetName, index = TitleIdle.glyph(char)
    saveFitAt(sheetName, index, col, row)
end

local function saveFitString(text, col, row)
    local cursor, index = 0, 1
    while index <= #text do
        local nextIndex, sheetName, glyph = TitleIdle.nextTile(text, index)
        saveFitAt(sheetName, glyph, col + cursor, row)
        cursor = cursor + 1
        index = nextIndex
    end
end

function SaveScreen.draw(state)
    local session = state.game.session
    local clock = session:playTime()
    local owned = 0
    for _, flag in pairs(session:pokedex().owned) do
        if flag then owned = owned + 1 end
    end
    local badges = 0
    for _, id in ipairs(TitleIdle.BADGE_FLAGS) do
        if session:questFlag(id) == true then badges = badges + 1 end
    end
    GbFont.drawBox(TitleIdle.textBox(4, 0, 14, 8))
    saveFitString("PLAYER", 5, 2)
    saveFitString(Story.playerName(state.game), 12, 2)
    saveFitString("BADGES", 5, 4)
    saveFitString(string.format("%2d", badges), 17, 4)
    saveFitString("POKéDEX", 5, 6)
    saveFitString(string.format("%3d", owned), 16, 6)
    saveFitString("TIME", 5, 8)
    saveFitString(TitleIdle.playTimeText(clock.hours, clock.minutes), 13, 8)
    GbFont.drawBox(TitleIdle.textBox(0, 12, 18, 4))
    saveFitString("Would you like to", 1, 14)
    saveFitString("SAVE the game?", 1, 16)
    GbFont.drawBox(TitleIdle.textBox(0, 7, 4, 3))
    local cursorRow = state.menu.selectedIndex == 2 and 10 or 8
    saveFitChar(TitleIdle.CURSOR, 1, cursorRow)
    saveFitString("YES", 2, 8)
    saveFitString("NO", 2, 10)
end

function SaveScreen.release()
    -- Glyph images are drawn and dropped inside saveFitAt. Nothing here
    -- is kept. PauseState nils this global and collects.
end
