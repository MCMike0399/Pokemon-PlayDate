-- Blue title idle from pret/pokered af519899.
-- data/pokemon/title_mons.asm (DEF _BLUE) and engine/movie/title2.asm.
-- DisplayTitleScreen waits 200 frames, then TitleScreenScrollInMon passes
-- d=0. TitleScroll treats 0 as TitleScroll_Out, so the current species
-- leaves to the left. TitleScreenAnimateBallIfStarterOut then plays the
-- first five TitleBallYTable steps when that species is Charmander,
-- Squirtle, or Bulbasaur. TitleScreenPickNewMon passes d=1, which
-- TitleScroll treats as TitleScroll_In, so a different TitleMon enters
-- from the right. The inline "scroll in" / "scroll out" comments are
-- swapped relative to that branch.
--
-- title.asm DrawPlayerCharacter places gfx/title/player.png on a 5-by-7
-- OAM grid with `lb de, $60, $5a` (Y, then X) and parks a Poké Ball on
-- sprite 10. OAM Y is the screen row plus 16 and OAM X is the screen
-- column plus 8, so the sprite is GB y 80-135 and x 82-122. That ends one
-- pixel row above the copyright at hlcoord 2, 17 (GB y 136). Sprite 10 is
-- column 0, row 2 of the sheet. TitleBallYTable moves it. The species
-- slot does not draw the ball.

TitleIdle = {}

TitleIdle.MONS = {
    "squirtle", "charmander", "bulbasaur", "mankey", "hitmonlee", "vulpix",
    "chansey", "aerodactyl", "jolteon", "snorlax", "gloom", "poliwag",
    "doduo", "porygon", "gengar", "raichu",
}
TitleIdle.HOLD = 200
TitleIdle.BALL_REST = 0x74
TitleIdle.BALL_Y = { 0x71, 0x6f, 0x6e, 0x6d, 0x6c }

local STARTERS <const> = { squirtle = true, charmander = true, bulbasaur = true }
local OUT_SPEEDS <const> = { 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 8, 8, 8, 9, 9, 9 }
local IN_SPEEDS <const> = { 10, 10, 9, 9, 9, 9, 8, 8, 8, 8, 6, 6, 6, 5, 5, 3, 1 }
TitleIdle.OUT_FRAMES = #OUT_SPEEDS
TitleIdle.IN_FRAMES = #IN_SPEEDS
TitleIdle.OUT_DISTANCE = 93
TitleIdle.IN_DISTANCE = 120

local function beginIn(state, random)
    state.species = TitleIdle.pick(state.species, random)
    state.phase = "in"
    state.cursor = 0
    state.offset = TitleIdle.IN_DISTANCE
    state.ball = nil
end

function TitleIdle.start()
    return { species = "squirtle", phase = "hold", hold = 0, cursor = 0, offset = 0, ball = nil }
end

function TitleIdle.pick(current, random)
    for _ = 1, 32 do
        local species = TitleIdle.MONS[random(#TitleIdle.MONS)]
        if species ~= current then return species end
    end
    for index, species in ipairs(TitleIdle.MONS) do
        if species == current then return TitleIdle.MONS[index % #TitleIdle.MONS + 1] end
    end
    return TitleIdle.MONS[1]
end

function TitleIdle.advance(state, random)
    if state.phase == "hold" then
        if state.hold == TitleIdle.HOLD then
            state.phase = "out"
            state.cursor = 0
            state.offset = 0
            state.ball = nil
            return
        end
        state.hold = state.hold + 1
        return
    end
    if state.phase == "out" then
        if state.cursor == #OUT_SPEEDS then
            if STARTERS[state.species] then
                state.phase = "ball"
                state.ball = 0
            else
                beginIn(state, random)
            end
            return
        end
        state.cursor = state.cursor + 1
        state.offset = state.offset - OUT_SPEEDS[state.cursor]
        return
    end
    if state.phase == "ball" then
        if state.ball == #TitleIdle.BALL_Y then
            beginIn(state, random)
            return
        end
        state.ball = state.ball + 1
        return
    end
    if state.cursor == #IN_SPEEDS then
        state.phase = "hold"
        state.hold = 0
        state.cursor = 0
        state.offset = 0
        state.ball = nil
        return
    end
    state.cursor = state.cursor + 1
    state.offset = state.offset - IN_SPEEDS[state.cursor]
end

-- DrawPlayerCharacter sprite 10. title.asm writes the grid row-major.
TitleIdle.PLAYER_COLUMNS = 5
TitleIdle.PLAYER_ROWS = 7
TitleIdle.BALL_SPRITE = 10
TitleIdle.PLAYER_OAM_X = 0x5a
TitleIdle.PLAYER_OAM_Y = 0x60
TitleIdle.TILE = 8
-- main_menu.asm MainMenu waits 20 frames before HandleMenuInput.
-- DisplayContinueGameInfo waits 30 frames after the info box is drawn.
TitleIdle.MENU_DELAY = 20
TitleIdle.CONTINUE_DELAY = 30
TitleIdle.CONTINUE_LABELS = {"PLAYER", "BADGES", "POKéDEX", "TIME"}
-- title.asm .tileScreenCopyrightTiles. $42 is the '9 tile and is stored
-- three times. A $41..$4E range would draw that tile once.
TitleIdle.COPYRIGHT_TILES = {
    0x41, 0x42, 0x43, 0x42, 0x44, 0x42, 0x45,
    0x46, 0x47, 0x48, 0x49, 0x4A, 0x4B, 0x4C, 0x4D, 0x4E,
}
-- LoadTitleMonSprite is hlcoord 5, 10. A front pic is 7 tiles, so it
-- ends on row 16. The copyright row is 17 and is not part of the pic.
TitleIdle.MON_COL = 5
TitleIdle.MON_ROW = 10
TitleIdle.MON_TILES = 7
TitleIdle.COPYRIGHT_COL = 2
TitleIdle.COPYRIGHT_ROW = 17
TitleIdle.BADGE_FLAGS = {
    "BADGE_BOULDER", "BADGE_CASCADE", "BADGE_THUNDER", "BADGE_RAINBOW",
    "BADGE_SOUL", "BADGE_MARSH", "BADGE_VOLCANO", "BADGE_EARTH",
}
-- 400x240 placement. Logo and version stay at the approved scale. Red uses
-- playerRect(), the same 20-by-13 cells as the copyright row. Text tiles
-- are a separate 16px grid (GbFont), so a glyph is never stretched into
-- one of these cells.
TitleIdle.LAYOUT = {
    logo = {x = 8, y = 4, scale = 2},
    version = {x = 24, y = 112, scale = 2},
    mon = {col = 5, row = 10, tiles = 7},
    copyright = {col = 2, row = 17, tiles = #TitleIdle.COPYRIGHT_TILES},
}

-- vTitleLogo2 tile 16 is $41. Five Nintendo tiles, then nine Game Freak tiles.
-- The same source tile is drawn again wherever the tilemap repeats it.
function TitleIdle.copyrightSource(tile)
    if tile >= 0x41 and tile <= 0x45 then
        return "copyright", tile - 0x41
    end
    if tile >= 0x46 and tile <= 0x4E then
        return "gamefreak", tile - 0x46
    end
    error("copyright tile out of range")
end

function TitleIdle.ballTile()
    local index = TitleIdle.BALL_SPRITE
    return index % TitleIdle.PLAYER_COLUMNS, math.floor(index / TitleIdle.PLAYER_COLUMNS)
end

function TitleIdle.ballOamY(state)
    if state.phase == "ball" and state.ball and state.ball > 0 then
        return TitleIdle.BALL_Y[state.ball]
    end
    return TitleIdle.BALL_REST
end

function TitleIdle.mainMenu(hasSave)
    if hasSave then
        return {"CONTINUE", "NEW GAME", "OPTION"}
    end
    return {"NEW GAME", "OPTION"}
end

-- draw_start_menu.asm DrawStartMenu. The Pokédex row is absent until
-- EVENT_GOT_POKEDEX. The fourth row is wPlayerName, not a fixed label.
function TitleIdle.startMenu(hasDex, playerName)
    local items = {}
    if hasDex then items[#items + 1] = "POKéDEX" end
    items[#items + 1] = "POKéMON"
    items[#items + 1] = "ITEM"
    items[#items + 1] = playerName
    items[#items + 1] = "SAVE"
    items[#items + 1] = "OPTION"
    items[#items + 1] = "EXIT"
    return items
end

function TitleIdle.startAction(hasDex, index)
    local actions = {"pokemon", "item", "trainer", "save", "option", "exit"}
    if hasDex then
        table.insert(actions, 1, "pokedex")
    end
    return actions[index]
end

-- home/text.asm TextBoxBorder. The border adds one tile on every side,
-- so a box at hlcoord col,row with inner size c,b occupies
-- (c + 2) by (b + 2) tiles.
-- Sprites, the copyright row, and Red stay on the 20px by 13px cells.
-- Text is TitleIdle.FONT (16px), the integer 2x of an 8px GB tile.
-- Eighteen glyphs are 288px. Tile (0, 0) is the top-left, which is where
-- main_menu.asm draws the main menu.
TitleIdle.COL = 20
TitleIdle.ROW = 13
TitleIdle.FONT = 16

function TitleIdle.fontRect(col, row, cols, rows)
    local tile = TitleIdle.FONT
    return {
        x = col * tile,
        y = row * tile,
        w = (cols or 1) * tile,
        h = (rows or 1) * tile,
    }
end

function TitleIdle.textBox(col, row, innerW, innerH)
    local tile = TitleIdle.FONT
    return {
        col = col, row = row, innerW = innerW, innerH = innerH, tile = tile,
        x = col * tile,
        y = row * tile,
        w = (innerW + 2) * tile,
        h = (innerH + 2) * tile,
    }
end

function TitleIdle.boxInterior(box)
    local tile = box.tile or TitleIdle.FONT
    return {
        x = box.x + tile,
        y = box.y + tile,
        w = box.w - 2 * tile,
        h = box.h - 2 * tile,
    }
end

function TitleIdle.cellRect(col, row, cols, rows)
    return {
        x = col * TitleIdle.COL,
        y = row * TitleIdle.ROW,
        w = (cols or 1) * TitleIdle.COL,
        h = (rows or 1) * TitleIdle.ROW,
    }
end

function TitleIdle.contains(outer, inner)
    return inner.x >= outer.x and inner.y >= outer.y
        and inner.x + inner.w <= outer.x + outer.w
        and inner.y + inner.h <= outer.y + outer.h
end

-- DisplayContinueGameInfo: hlcoord 4, 7; b = 8; c = 14.
-- PlaceString of SaveScreenInfoText starts at hlcoord 5, 9 and <NEXT>
-- is two rows. The numbers are PrintNumBadges, PrintNumOwnedMons, PrintPlayTime.
TitleIdle.CONTINUE_BOX_SPEC = {col = 4, row = 7, innerW = 14, innerH = 8}
TitleIdle.CONTINUE_TEXT = {
    {label = "PLAYER", labelCol = 5, row = 9, valueCol = 12},
    {label = "BADGES", labelCol = 5, row = 11, valueCol = 17},
    {label = "POKéDEX", labelCol = 5, row = 13, valueCol = 16},
    {label = "TIME", labelCol = 5, row = 15, valueCol = 13},
}

-- The GB box is hlcoord 4, 7, inner 14 by 8. At 16px that is 160px tall
-- and leaves the screen. The four text rows stay 16px. Only the blank
-- row between them shrinks, to 8px, so the box ends on y 240.
function TitleIdle.continueBox()
    local spec = TitleIdle.CONTINUE_BOX_SPEC
    local tile = TitleIdle.FONT
    return {
        col = spec.col, row = spec.row, innerW = spec.innerW, innerH = spec.innerH,
        tile = tile,
        x = spec.col * tile,
        y = spec.row * tile,
        w = (spec.innerW + 2) * tile,
        h = 128,
    }
end

function TitleIdle.continueCells(name, badges, owned, timeText)
    local values = {
        name,
        string.format("%2d", badges),
        string.format("%3d", owned),
        timeText,
    }
    local tile = TitleIdle.FONT
    local textY = {136, 160, 184, 208}
    local cells = {}
    for index, spec in ipairs(TitleIdle.CONTINUE_TEXT) do
        local value = values[index]
        local y = textY[index]
        cells[#cells + 1] = {
            label = spec.label,
            value = value,
            labelRect = {
                x = spec.labelCol * tile, y = y,
                w = utf8.len(spec.label) * tile, h = tile,
            },
            valueRect = {
                x = spec.valueCol * tile, y = y,
                w = utf8.len(value) * tile, h = tile,
            },
        }
    end
    return cells
end

-- MainMenu with a save is hlcoord 0, 0; b = 6; c = 13. No save is b = 4.
-- ContinueText / NewGameText start at hlcoord 2, 2 and <NEXT> skips a row.
-- The cursor is wTopMenuItemX = 1. Recovery rows keep that stride.
function TitleIdle.mainMenuBox(hasSave, extra)
    local innerH = (hasSave and 6 or 4) + (extra or 0) * 2
    return TitleIdle.textBox(0, 0, 13, innerH)
end

function TitleIdle.mainMenuCells(labels)
    local cells = {}
    for index, label in ipairs(labels) do
        local row = 2 + (index - 1) * 2
        cells[#cells + 1] = {
            label = label,
            row = row,
            cursor = TitleIdle.fontRect(1, row, 1, 1),
            text = TitleIdle.fontRect(2, row, utf8.len(label), 1),
        }
    end
    return cells
end

-- DrawStartMenu: hlcoord 10, 0. With the dex, b = 14; without, b = 12.
-- Items start at hlcoord 12, 2. The cursor column is $0b. A blank row
-- between seven 16px items would run past y 240, so those gaps shrink
-- to nothing and the glyphs stay 16px.
function TitleIdle.startMenuBox(hasDex)
    local items = hasDex and 7 or 6
    local tile = TitleIdle.FONT
    return {
        col = 10, row = 0, innerW = 8, innerH = items, tile = tile,
        x = 10 * tile, y = 0, w = 10 * tile, h = (items + 2) * tile,
    }
end

function TitleIdle.startMenuCells(labels)
    local cells = {}
    for index, label in ipairs(labels) do
        local row = index
        cells[#cells + 1] = {
            label = label,
            row = row,
            cursor = TitleIdle.fontRect(11, row, 1, 1),
            text = TitleIdle.fontRect(12, row, utf8.len(label), 1),
        }
    end
    return cells
end

-- data/text_boxes.asm MESSAGE_BOX is columns 0,12 through 19,17.
-- Text is bccoord 1,14 and hlcoord 1,16. Row 13 is the pad under the
-- top border. Row 15 is the blank tile between the two text rows.
-- The Playdate screen is 400px, so the horizontal border run is 25
-- tiles and the right corner moves to x=384. Text stays one column in
-- from the left border, and the arrow stays at column 18. compact
-- drops the pad and the blank row (AskName, where the YES/NO box
-- occupies rows 7-11) and uses the same width.
function TitleIdle.messageBox(compact)
    local tile = TitleIdle.FONT
    local width = 25 * tile
    if compact then
        local height = 4 * tile
        local y = 240 - height
        return {
            x = 0, y = y, w = width, h = height, tile = tile, columns = 18,
            textX = tile, textY1 = y + tile, textY2 = y + 2 * tile,
            arrowX = 18 * tile, arrowY = y + 2 * tile,
        }
    end
    local height = 6 * tile
    local y = 240 - height
    return {
        x = 0, y = y, w = width, h = height, tile = tile, columns = 18,
        textX = tile, textY1 = y + 2 * tile, textY2 = y + 4 * tile,
        arrowX = 18 * tile, arrowY = y + 4 * tile,
    }
end

-- data/text_boxes.asm line 31:
--   text_box_text BATTLE_MENU_TEMPLATE, 8, 12, 19, 17, BattleMenuText, 10, 14
-- DisplayBattleMenu restores the screen, then that template covers columns
-- 8-19. The cursor is hlcoord 9, 14 and the text is column 10. The port's
-- labels are FIGHT / BAG / POKEMON / RUN. "POKEMON RUN" plus the cursor
-- and both borders is 14 tiles, so the menu is wider than columns 8-19
-- and is right-aligned to the 400px edge. The left box keeps its border
-- and stays empty: pokered has no "What will" prompt.
function TitleIdle.commandBoxes()
    local message = TitleIdle.messageBox(false)
    local tile = TitleIdle.FONT
    local menuW = 14 * tile
    local menuX = 400 - menuW
    local left = {
        x = 0, y = message.y, w = menuX, h = message.h, tile = tile,
        columns = math.floor(menuX / tile) - 2,
    }
    local menu = {
        x = menuX, y = message.y, w = menuW, h = message.h, tile = tile,
        cursorX = menuX + tile,
        textX = menuX + 2 * tile,
        textX2 = menuX + 10 * tile,
        textY1 = message.textY1, textY2 = message.textY2,
    }
    return {message = message, left = left, menu = menu}
end

-- DrawEnemyHUDAndHPBar / DrawPlayerHUDAndHPBar (engine/battle/core.asm).
-- Enemy: name hlcoord 1,0, level 4,1, bar 2,2, d=6. That block ends at
-- y=48, above the enemy platform (y=84). Player: name hlcoord 10,7,
-- level 14,8, bar 10,9. Row 7 is y=112, which clears the platform, but
-- three 16px rows from there end at y=160, inside the message box.
-- The screen forces two rows: the level shares the name row, and the
-- current/max numbers share the bar row. The block ends on the box.
function TitleIdle.battleHud(side, info)
    info = info or {}
    local tile = TitleIdle.FONT
    local name = info.name or ""
    local levelText = tostring(info.level or 0)
    local status = info.status
    local segments = 6
    local barTiles = 2 + segments + 1
    local levelTiles = status and utf8.len(status) or (1 + #levelText)
    if side == "enemy" then
        local nameX, nameY = tile, 0
        local levelX, levelY = 4 * tile, tile
        local barX, barY = 2 * tile, 2 * tile
        local right = math.max(
            nameX + utf8.len(name) * tile,
            levelX + levelTiles * tile,
            barX + barTiles * tile)
        return {
            x = nameX, y = nameY, w = right - nameX, h = 3 * tile, tile = tile,
            name = name, nameX = nameX, nameY = nameY,
            levelText = levelText, status = status,
            levelX = levelX, levelY = levelY,
            barX = barX, barY = barY,
            hp = info.hp or 0, maxHp = info.maxHp or 0,
            segments = segments,
        }
    end
    local nameX, nameY = 10 * tile, 7 * tile
    local levelX, levelY = nameX + (utf8.len(name) + 1) * tile, nameY
    local barX, barY = nameX, nameY + tile
    local numbers = tostring(info.hp or 0) .. "/" .. tostring(info.maxHp or 0)
    local numbersX = barX + barTiles * tile
    local right = math.max(levelX + levelTiles * tile, numbersX + utf8.len(numbers) * tile)
    return {
        x = nameX, y = nameY, w = right - nameX, h = 2 * tile, tile = tile,
        name = name, nameX = nameX, nameY = nameY,
        levelText = levelText, status = status,
        levelX = levelX, levelY = levelY,
        barX = barX, barY = barY,
        numbers = numbers, numbersX = numbersX, numbersY = barY,
        hp = info.hp or 0, maxHp = info.maxHp or 0,
        segments = segments,
    }
end

-- gfx/font/font.png tiles are (code - $80). font_extra.png is (code - $60).
-- constants/charmap.asm. The filled cursor is ▶ and the hollow one is ▷.
function TitleIdle.titleMonSlot()
    return TitleIdle.cellRect(TitleIdle.MON_COL, TitleIdle.MON_ROW, TitleIdle.MON_TILES, TitleIdle.MON_TILES)
end

function TitleIdle.copyrightRect()
    return TitleIdle.cellRect(TitleIdle.COPYRIGHT_COL, TitleIdle.COPYRIGHT_ROW, #TitleIdle.COPYRIGHT_TILES, 1)
end

-- DrawPlayerCharacter's 5-by-7 grid, mapped with the copyright cells.
-- One GB pixel is COL/TILE by ROW/TILE, and tile (0, 0) is the origin.
function TitleIdle.playerRect()
    local screenX = TitleIdle.PLAYER_OAM_X - 8
    local screenY = TitleIdle.PLAYER_OAM_Y - 16
    return {
        x = screenX * TitleIdle.COL / TitleIdle.TILE,
        y = screenY * TitleIdle.ROW / TitleIdle.TILE,
        w = TitleIdle.PLAYER_COLUMNS * TitleIdle.COL,
        h = TitleIdle.PLAYER_ROWS * TitleIdle.ROW,
    }
end

-- The pic is sampled into the 7 by 7 slot. A 2x blit of a 56px front
-- is taller than seven 13px rows and would cross the copyright row.
function TitleIdle.placedMonRect(pixelWidth, pixelHeight)
    local slot = TitleIdle.titleMonSlot()
    assert(type(pixelWidth) == "number" and pixelWidth > 0, "title mon width required")
    assert(type(pixelHeight) == "number" and pixelHeight > 0, "title mon height required")
    return {x = slot.x, y = slot.y, w = slot.w, h = slot.h, sourceWidth = pixelWidth, sourceHeight = pixelHeight}
end

function TitleIdle.rectsOverlap(a, b)
    return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

function TitleIdle.glyph(char)
    if char == "PK" then return "font", 0xe1 - 0x80 end
    if char == "MN" then return "font", 0xe2 - 0x80 end
    if char == "ED" then return "ed", 0 end
    local extra = {
        [" "] = 0x7f - 0x60,
        ["┌"] = 0x79 - 0x60, ["─"] = 0x7a - 0x60, ["┐"] = 0x7b - 0x60,
        ["│"] = 0x7c - 0x60, ["└"] = 0x7d - 0x60, ["┘"] = 0x7e - 0x60,
    }
    if extra[char] then return "extra", extra[char] end
    local font = {
        ["▶"] = 0xed - 0x80, ["▷"] = 0xec - 0x80, ["▼"] = 0xee - 0x80,
        ["é"] = 0xba - 0x80, [":"] = 0x9c - 0x80,
        [";"] = 0x9d - 0x80, ["["] = 0x9e - 0x80, ["]"] = 0x9f - 0x80,
        ["-"] = 0xe3 - 0x80, ["."] = 0xe8 - 0x80,
        ["'"] = 0xe0 - 0x80, ["?"] = 0xe6 - 0x80, ["!"] = 0xe7 - 0x80,
        ["("] = 0x9a - 0x80, [")"] = 0x9b - 0x80,
        ["♂"] = 0xef - 0x80, ["×"] = 0xf1 - 0x80,
        ["/"] = 0xf3 - 0x80, [","] = 0xf4 - 0x80, ["♀"] = 0xf5 - 0x80,
    }
    if font[char] then return "font", font[char] end
    local byte = char:byte()
    if byte and #char == 1 then
        if byte >= 65 and byte <= 90 then return "font", byte - 65 end
        if byte >= 97 and byte <= 122 then return "font", 0x20 + (byte - 97) end
        if byte >= 48 and byte <= 57 then return "font", (0xf6 - 0x80) + (byte - 48) end
    end
    return "extra", extra[" "]
end

TitleIdle.CURSOR = "▶"
TitleIdle.MARK = "▷"

-- PrintPlayTime: hours in 3 digits, colon tile, minutes in 2 digits.
function TitleIdle.playTimeText(hours, minutes)
    hours = math.max(0, math.min(255, math.floor(hours or 0)))
    minutes = math.max(0, math.min(59, math.floor(minutes or 0)))
    return string.format("%3d:%02d", hours, minutes)
end

function TitleIdle.countFlags(flags)
    local count = 0
    for _, id in ipairs(TitleIdle.BADGE_FLAGS) do
        if flags and flags[id] then count = count + 1 end
    end
    return count
end

-- Lane F owns KantoAudio. playTitle is the seam; missing means silence.
function TitleIdle.playMusic()
    if type(KantoAudio) == "table" and type(KantoAudio.playTitle) == "function" then
        return pcall(KantoAudio.playTitle) == true
    end
    return false
end
