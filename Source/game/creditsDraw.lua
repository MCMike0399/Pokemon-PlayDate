-- Credits text and the scrolling silhouette. Loaded on first use so the
-- boot chunk does not keep this draw path.
-- pokered af519899 engine/movie/credits.asm: black bands, white middle,
-- black text, POKé for '#', font.png $BA for é, 27-step silhouette scroll.

-- constants/charmap.asm maps "#" to POKé. The é tile is font.png char $BA,
-- an 8x8 cell, the same height as the other lowercase letters. Rows come
-- from the font generator's sourceText projection. Strings without é are
-- one drawText call so the system font keeps its own advances, including
-- the space and the colon.
function EndgameStory.expandPokeredText(text)
    return (text or ""):gsub("#", "POKé")
end

function EndgameStory.accentCell()
    return 8
end

-- font.png char $BA. Rows 0-1 are the acute accent. Rows 2-6 are the same
-- e body as lowercase e. The system font's e, measured on "Seen", has its
-- ink on rows 6 through 14 of the draw cell. The body is stretched on Y
-- only so it shares that baseline and x-height, and it stays one letter wide.
function EndgameStory.lowercaseInk()
    return 6, 14
end

function EndgameStory.accentBox(eTop, eBottom)
    local scaleY <const> = 2
    local bodyTop <const> = 2
    local bodyBottom <const> = 6
    local bodyInkBottom <const> = (bodyBottom + 1) * scaleY - 1
    local y <const> = eBottom - bodyInkBottom
    return {
        y = y,
        scaleX = 1,
        scaleY = scaleY,
        bodyTop = y + bodyTop * scaleY,
        bodyBottom = y + bodyInkBottom,
        bodyHeight = (bodyBottom - bodyTop + 1) * scaleY,
        inkTop = y,
        inkBottom = y + bodyInkBottom,
        eTop = eTop,
        eBottom = eBottom,
    }
end

function EndgameStory.accentRows()
    local data <const> = json.decodeFile("data/sourceText.json")
    return data.glyphs["é"].rows
end

function EndgameStory.glyphAdvance(font, char)
    if char == "é" then
        char = "e"
    end
    return font:getTextWidth("X" .. char .. "X") - font:getTextWidth("XX")
end

function EndgameStory.textWidth(font, text)
    text = EndgameStory.expandPokeredText(text)
    if not text:find("é", 1, true) then
        return font:getTextWidth(text)
    end
    local width = 0
    for line in (text .. "\n"):gmatch("(.-)\n") do
        local run = ""
        local index = 1
        local function flush()
            if run ~= "" then
                width = width + font:getTextWidth(run)
                run = ""
            end
        end
        while index <= #line do
            local nextIndex = utf8.offset(line, 2, index) or (#line + 1)
            local glyph = line:sub(index, nextIndex - 1)
            if glyph == "é" then
                flush()
                width = width + EndgameStory.glyphAdvance(font, "e")
            else
                run = run .. glyph
            end
            index = nextIndex
        end
        flush()
    end
    return width
end

function EndgameStory.creditsCaption(view)
    view = view or {}
    if view.ending then
        return "THE END"
    end
    local text = table.concat(view.lines or {}, "\n")
    if view.copyright then
        local notice = table.concat({
            "©'95.'96.'98 Nintendo",
            "©'95.'96.'98 Creatures inc.",
            "©'95.'96.'98 GAME FREAK inc.",
        }, "\n")
        if text ~= "" then
            text = text .. "\n"
        end
        text = text .. notice
    end
    return EndgameStory.expandPokeredText(text)
end

-- HallOfFamePC fills rows 0-3 and 14-17 black. The middle, rows 4-13, is
-- white. hallView's 2x shift is the port's row mapping.
function EndgameStory.creditsBands()
    local view <const> = EndgameStory.hallView()
    local function rowY(row)
        return view.y + row * 8 * view.scale
    end
    local function band(row0, row1)
        local y0 = math.max(0, rowY(row0))
        local y1 = math.min(240, rowY(row1))
        return {x = 0, y = y0, w = 400, h = y1 - y0}
    end
    return {top = band(0, 4), middle = band(4, 14), bottom = band(14, 18), text = "black"}
end

-- DisplayCreditsMon draws the pic at hlcoord 8, 6 and copies that tilemap to
-- vBGMap0+$c, twelve columns to the right. The pic therefore starts at
-- column 20, just off the right edge. ScrollCreditsMonLeft raises SCX by 8
-- for LY $20-$70 only, so the white middle slides and the black bands stay.
-- Seven steps, then twenty more. rWX starts at $A7 and drops by 8 on those
-- twenty, and the window's visible edge is WX - 7. That edge masks the text
-- as the 32-tile map wraps it back in on the right. Step 27 is the
-- accumulator after the last add.
function EndgameStory.creditsScroll(scroll)
    scroll = math.floor(tonumber(scroll) or 0)
    if scroll < 0 then
        scroll = 0
    end
    -- Each call displays the current SCX, then adds 8. The 27th call
    -- therefore shows 26 tiles of scroll. One more add happens as the
    -- routine returns and is not a frame. The window has dropped 19
    -- times by that frame, so its edge is at x=8, level with the pic.
    local shown <const> = math.min(scroll, 26)
    local windowGb = 160
    if shown > 7 then
        windowGb = 160 - 8 * (shown - 7)
    end
    local view <const> = EndgameStory.hallView()
    local scx <const> = shown * 8
    return {
        scroll = scroll,
        scx = scx,
        dx = -scx * view.scale,
        topDx = 0,
        bottomDx = 0,
        windowGb = windowGb,
        windowX = view.x + windowGb * view.scale,
        wrap = 256 * view.scale,
    }
end

function EndgameStory.creditsMonPlace(scroll)
    local motion <const> = EndgameStory.creditsScroll(scroll)
    -- Column 8 plus the twelve-column copy. SCX then carries it left.
    local gbX = 160 - motion.scx
    local gbY = 48
    local x, y = EndgameStory.hallPixel(gbX, gbY)
    return {gbX = gbX, gbY = gbY, x = x, y = y, scroll = motion.scroll, width = 56, height = 56}
end

local accentEImage

function EndgameStory.drawAccentE(gfx, x, y)
    local box <const> = EndgameStory.accentBox(EndgameStory.lowercaseInk())
    if not accentEImage then
        local rows <const> = EndgameStory.accentRows()
        accentEImage = gfx.image.new(#rows[1] * box.scaleX, #rows * box.scaleY, gfx.kColorClear)
        gfx.pushContext(accentEImage)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
        gfx.setColor(gfx.kColorBlack)
        for row, bits in ipairs(rows) do
            for col = 1, #bits do
                if bits:sub(col, col) == "#" then
                    gfx.fillRect((col - 1) * box.scaleX, (row - 1) * box.scaleY, box.scaleX, box.scaleY)
                end
            end
        end
        gfx.popContext()
    end
    accentEImage:draw(x, y + box.y)
end

function EndgameStory.drawPokeredText(gfx, text, x, y)
    text = EndgameStory.expandPokeredText(text)
    if not text:find("é", 1, true) then
        gfx.drawText(text, x, y)
        return
    end
    local font <const> = gfx.getSystemFont()
    local height <const> = font:getHeight() + font:getLeading()
    local lineY = y
    for line in (text .. "\n"):gmatch("(.-)\n") do
        local cursor = x
        local run = ""
        local index = 1
        local function flush()
            if run ~= "" then
                gfx.drawText(run, cursor, lineY)
                cursor = cursor + font:getTextWidth(run)
                run = ""
            end
        end
        while index <= #line do
            local nextIndex = utf8.offset(line, 2, index) or (#line + 1)
            local glyph = line:sub(index, nextIndex - 1)
            if glyph == "é" then
                flush()
                EndgameStory.drawAccentE(gfx, cursor, lineY)
                cursor = cursor + EndgameStory.glyphAdvance(font, "e")
            else
                run = run .. glyph
            end
            index = nextIndex
        end
        flush()
        lineY = lineY + height
    end
end

function EndgameStory.drawCreditsMon(gfx, species, scroll)
    local key = species and species:lower() or ""
    local data <const> = json.decodeFile("data/endgame/creditsMonShades.json")
    local rows = data and data.mons and data.mons[key]
    if not rows then
        return
    end
    local place <const> = EndgameStory.creditsMonPlace(scroll)
    local windowX <const> = EndgameStory.creditsScroll(scroll).windowX
    local scale <const> = EndgameStory.hallView().scale
    local width = #rows[1] * scale
    local height = #rows * scale
    local clipW = math.max(0, math.min(place.x + width, windowX) - place.x)
    if clipW <= 0 then
        return
    end
    -- The 7x7 pic replaces the tiles under it. White matches the middle,
    -- so this is not a box. BGP %11111100 then stamps every other shade black.
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(place.x, place.y, clipW, height)
    gfx.setColor(gfx.kColorBlack)
    for rowIndex, row in ipairs(rows) do
        for col = 1, #row do
            if row:sub(col, col) ~= "." then
                local px = place.x + (col - 1) * scale
                if px + scale <= windowX then
                    gfx.fillRect(px, place.y + (rowIndex - 1) * scale, scale, scale)
                end
            end
        end
    end
end

-- PlaceString starts at hlcoord 9, 6. The first byte of each credit is a
-- signed indent. <NEXT> then drops two rows. CopyrightTextString is its own
-- PlaceString at hlcoord 2, 7. THE END is hlcoord 4, 8.
local CREDIT_COLUMN <const> = {
    -- CredMon is db -3 from hlcoord 9, 6. The pic starts off the right edge
    -- and scrolls with this line, so the expanded word is not under it.
    ["#MON"] = 6, ["BLUE VERSION STAFF"] = 1,
    ["DIRECTOR"] = 6, ["SATOSHI TAJIRI"] = 3,
    ["PROGRAMMERS"] = 4, ["TAKENORI OOTA"] = 3, ["SHIGEKI MORIMOTO"] = 2,
    ["TETSUYA WATANABE"] = 2, ["JUNICHI MASUDA"] = 3, ["SOUSUKE TAMADA"] = 3,
    ["CHARACTER DESIGN"] = 2, ["KEN SUGIMORI"] = 4, ["ATSUKO NISHIDA"] = 3,
    ["MUSIC"] = 7, ["SOUND EFFECTS"] = 3,
    ["GAME DESIGN"] = 4, ["GAME SCENARIO"] = 3,
    ["MONSTER DESIGN"] = 3, ["MOTOFUMI FUZIWARA"] = 2,
    ["SATOSHI OOTA"] = 4, ["RENA YOSHIKAWA"] = 3,
    ["RYOHSUKE TANIGUCHI"] = 1, ["FUMIHIRO NONOMURA"] = 1, ["HIROYUKI ZINNAI"] = 2,
    ["PARAMETRIC DESIGN"] = 1, ["KOHJI NISINO"] = 4, ["TAKEO NAKAMURA"] = 3,
    ["MAP DESIGN"] = 5, ["KENJI MATSUSIMA"] = 2,
    ["PRODUCT TESTING"] = 2, ["AKIYOSHI KAKEI"] = 3, ["KAZUKI TSUCHIYA"] = 2,
    ["MASAMITSU YUDA"] = 3, ["SPECIAL THANKS"] = 3,
    ["YASUHIRO SAKAI"] = 3, ["WATARU YAMAGUCHI"] = 2, ["KAZUYUKI YAMAMOTO"] = 1,
    ["AKIHITO TOMISAWA"] = 2, ["HIROSHI KAWAMOTO"] = 2, ["TOMOMICHI OOTA"] = 3,
    ["PRODUCERS"] = 5, ["SHIGERU MIYAMOTO"] = 2, ["TAKASHI KAWAGUCHI"] = 1,
    ["TSUNEKAZU ISHIHARA"] = 1, ["PRODUCER"] = 5, ["TAKEHIRO IZUSHI"] = 2,
    ["EXECUTIVE PRODUCER"] = 1, ["HIROSHI YAMAUCHI"] = 2,
    ["US VERSION STAFF"] = 2, ["US COORDINATION"] = 2,
    ["GAIL TILDEN"] = 4, ["NAOKO KAWAKAMI"] = 3, ["HIRO NAKAMURA"] = 3,
    ["WILLIAM GIESE"] = 3, ["SARA OSBORNE"] = 4,
    ["TEXT TRANSLATION"] = 2, ["NOB OGASAWARA"] = 3,
    ["SATORU IWATA"] = 4, ["TAKAHIRO HARADA"] = 2,
    ["TERUKI MURAKAWA"] = 2, ["KOHTA FUKUI"] = 4,
    ["PAAD TESTING"] = 4, ["NCL SUPER MARIO CLUB"] = 0,
}

function EndgameStory.creditsLine(text, index, kind)
    if kind == "ending" then
        return {text = text, col = 4, row = 8}
    end
    if kind == "copyright" then
        return {text = text, col = 2, row = 7 + (index - 1) * 2}
    end
    return {text = text, col = CREDIT_COLUMN[text] or 9, row = 6 + (index - 1) * 2}
end

function EndgameStory.drawCredits(gfx, view)
    local bands <const> = EndgameStory.creditsBands()
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setFont(gfx.getSystemFont())
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(0, 0, 400, 240)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(bands.top.x, bands.top.y, bands.top.w, bands.top.h)
    gfx.fillRect(bands.bottom.x, bands.bottom.y, bands.bottom.w, bands.bottom.h)
    if not view or view.phase == "preamble" then
        return
    end
    local motion <const> = EndgameStory.creditsScroll(view.phase == "scroll" and view.scroll or 0)
    -- The window covers everything from its edge rightward. The left clip is
    -- the Game Boy screen; the side margins are not part of the scrolling map.
    local viewBox <const> = EndgameStory.hallView()
    local clipX <const> = viewBox.x
    local clipW <const> = math.max(0, motion.windowX - clipX)
    gfx.setClipRect(clipX, bands.middle.y, clipW, bands.middle.h)
    gfx.setColor(gfx.kColorBlack)
    local kind = view.ending and "ending" or (view.copyright and "copyright" or "text")
    local lines = view.lines or {}
    if view.ending then
        lines = {"THE END"}
    elseif view.copyright then
        lines = {
            "©'95.'96.'98 Nintendo",
            "©'95.'96.'98 Creatures inc.",
            "©'95.'96.'98 GAME FREAK inc.",
        }
    end
    for index, line in ipairs(lines) do
        local placed <const> = EndgameStory.creditsLine(line, index, kind)
        local x, y = EndgameStory.hallPixel(placed.col * 8, placed.row * 8)
        local shown <const> = x + motion.dx
        -- The 32-tile map brings a line back on the right. Draw it only while
        -- it is still left of the window; the window itself is blank.
        if shown < motion.windowX then
            EndgameStory.drawPokeredText(gfx, placed.text, shown, y)
        end
        local wrapped <const> = shown + motion.wrap
        if wrapped < motion.windowX then
            EndgameStory.drawPokeredText(gfx, placed.text, wrapped, y)
        end
    end
    if view.phase == "scroll" and view.mon then
        EndgameStory.drawCreditsMon(gfx, view.mon, view.scroll)
    end
    gfx.clearClipRect()
end
