-- Lane E: run `python3 tools/visual/compare.py <reviewed-baseline> <candidate> --protected-preservation`
-- (docs/validation/visual-catalog.md) and update baselines only for dialog-box pixels.
-- Do not regenerate other catalog art. The overworld, battle messages, and Oak's speech share this font.
import "game/gameOptions"
import "game/gbFont"

local gfx <const> = playdate.graphics

Class("Dialog")

function Dialog:init()
    self.lines = {}
    self.currentLine = 1
    self.charIndex = 0
    self.isActive = false
    self.onComplete = nil
    self.blinkTimer = 0
    self.revealTimer = 0
    self.holdFrames = 0
    self.pageShown = false
    self.shownFrames = 0
end

-- home/text.asm PrintText. MESSAGE_BOX is two rows of 18 tiles. An explicit
-- newline is the second row. A third row, or a form feed, starts the next
-- page. A row longer than 18 tiles breaks at the last space, or at 18 when
-- the word itself is longer.
function Dialog.wrapLine(text, width)
    width = width or 18
    local chars = {}
    for _, code in utf8.codes(text) do chars[#chars + 1] = utf8.char(code) end
    if #chars <= width then return {text} end
    local chunks, i = {}, 1
    while i <= #chars do
        local last = math.min(i + width - 1, #chars)
        if last == #chars then
            chunks[#chunks + 1] = table.concat(chars, "", i, last)
            break
        end
        local breakAt
        for j = last, i, -1 do
            if chars[j] == " " then breakAt = j break end
        end
        if breakAt and breakAt > i then
            chunks[#chunks + 1] = table.concat(chars, "", i, breakAt - 1)
            i = breakAt + 1
            while chars[i] == " " do i = i + 1 end
        else
            chunks[#chunks + 1] = table.concat(chars, "", i, last)
            i = last + 1
        end
    end
    if #chunks == 0 then chunks[1] = "" end
    return chunks
end

local function splitOn(text, sep)
    local parts, start = {}, 1
    while true do
        local found = text:find(sep, start, true)
        if not found then
            parts[#parts + 1] = text:sub(start)
            return parts
        end
        parts[#parts + 1] = text:sub(start, found - 1)
        start = found + #sep
    end
end

-- PromptText, Paragraph and _ContText place ▼ at hlcoord 18, 16 and wait.
-- DoneText does not. A page with no recorded ending does not either.
function Dialog.showsArrow(ending)
    return ending == "prompt" or ending == "para" or ending == "cont"
end

function Dialog.paginate(text)
    local pages = {}
    local function emit(rows)
        if #rows == 0 then return end
        pages[#pages + 1] = table.concat(rows, "\n")
    end
    local paragraphs = splitOn(text, "\f")
    if text:sub(-1) == "\f" then paragraphs[#paragraphs] = nil end
    for _, paragraph in ipairs(paragraphs) do
        local rows = {}
        local function push(row)
            if #rows == 2 then emit(rows) rows = {} end
            rows[#rows + 1] = row
        end
        for _, hard in ipairs(splitOn(paragraph, "\n")) do
            for _, chunk in ipairs(Dialog.wrapLine(hard, 18)) do push(chunk) end
        end
        emit(rows)
    end
    if #pages == 0 then pages[1] = "" end
    return pages
end

function Dialog:show(lines, onComplete)
    assert(type(lines) == "table" and #lines > 0, "nonempty dialogue required")
    self.font = gfx.getFont()
    self.lines, self.legacy, self.arrows = {}, {}, {}
    for _, entry in ipairs(lines) do
        local text, ending = entry, nil
        if type(entry) == "table" then
            text, ending = entry.text, entry.ending
        end
        assert(type(text) == "string" and utf8.len(text), "valid UTF-8 dialogue required")
        local pages = Dialog.paginate(text)
        for index, page in ipairs(pages) do
            self.lines[#self.lines + 1] = page
            self.legacy[#self.lines] = false
            -- A wrapped overflow is not its own prompt. The command's ending
            -- belongs to the last row pair.
            self.arrows[#self.arrows + 1] = index == #pages and Dialog.showsArrow(ending) or false
        end
    end
    self.currentLine = 1
    self.charIndex = 0
    self.isActive = true
    self.onComplete = onComplete
    self.blinkTimer = 0
    self.revealTimer = 0
    self.holdFrames = 0
    self.pageShown = false
    self.shownFrames = 0
end

function Dialog:update()
    if not self.isActive then return end

    local line = self.lines[self.currentLine]
    if self.charIndex < #line then
        self.revealTimer = self.revealTimer + 1
        local speed = GameOptions.textSpeed()
        local interval = speed == "SLOW" and 3 or speed == "MEDIUM" and 2 or 1
        local held = playdate.buttonIsPressed(playdate.kButtonA)
        if held or self.revealTimer % interval == 0 then
            local count = held and 8 or speed == "FAST" and 3 or 1
            for _ = 1, count do
                if self.charIndex >= #line then
                    break
                end
                self.charIndex = SourceText.nextBoundary(line, self.charIndex)
            end
        end
    else
        self.blinkTimer = self.blinkTimer + 1
    end
end

function Dialog:handleInput()
    if not self.isActive then return end

    local line = self.lines[self.currentLine]
    -- A held or mashed while the typewriter is still running used to count
    -- toward the confirm. The frame that finished the line then dismissed it
    -- before draw, so the box showed a prefix ("VENUSAUR is dam", "RED used
    -- REVIVE") and the next say replaced it. Finish the line first. The
    -- complete line has to be the one on screen for 10 frames, the same
    -- minimum the battle script already uses, before a later A or a hold
    -- that starts after that wait can turn the page. Golden-path auto-input
    -- presses A every frame; that press still cannot skip the wait.
    if self.charIndex < #line then
        self.holdFrames = 0
        self.pageShown = false
        self.shownFrames = 0
        if playdate.buttonJustPressed(playdate.kButtonA) then
            self.charIndex = #line
        end
        return
    end
    if not self.pageShown then
        self.pageShown = true
        self.holdFrames = 0
        self.shownFrames = 0
        return
    end
    self.shownFrames = self.shownFrames + 1
    if self.shownFrames < 10 then
        return
    end
    local held = playdate.buttonIsPressed(playdate.kButtonA)
    self.holdFrames = held and self.holdFrames + 1 or 0
    if playdate.buttonJustPressed(playdate.kButtonA) or self.holdFrames >= 12 then
        self.holdFrames = 0
        self.pageShown = false
        self.shownFrames = 0
        self:advance()
    end
end

-- The same reveal/advance seam serves native keys and SDK contracts.
function Dialog:advance()
    if not self.isActive then return end
    local line = self.lines[self.currentLine]
    if self.charIndex < #line then
        self.charIndex = #line
        -- Direct advance() is how a contract presents a finished page and
        -- then acknowledges it on the next handleInput. The typewriter path
        -- above does not come through here, so a mash cannot use this.
        self.pageShown = true
        self.shownFrames = 10
    else
        self.currentLine = self.currentLine + 1
        self.charIndex = 0
        self.blinkTimer = 0
        self.pageShown = false
        self.shownFrames = 0
        if self.currentLine > #self.lines then
            self.isActive = false
            local callback = self.onComplete
            self.onComplete = nil
            if callback then callback() end
        end
    end
end

function Dialog:draw()
    if not self.isActive then return end
    local ox, oy = gfx.getDrawOffset()
    gfx.setDrawOffset(0, 0)
    -- The 20 by 13 map ends at y 234. Cover the rest so a battle message bar
    -- drawn underneath does not show a black strip below the border.
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(0, 234, 400, 6)
    -- data/text_boxes.asm MESSAGE_BOX is hlcoord 0, 12 through 19, 17.
    -- Text is placed at bccoord 1, 14. The second row is hlcoord 1, 16.
    -- constants/charmap.asm puts ▼ at $ee, and PromptText writes it at 18, 16.
    GbFont.drawBox(TitleIdle.textBox(0, 12, 18, 4))
    local shown = string.sub(self.lines[self.currentLine], 1, self.charIndex)
    local row1, row2 = shown, nil
    local newline = shown:find("\n", 1, true)
    if newline then
        row1 = shown:sub(1, newline - 1)
        row2 = shown:sub(newline + 1)
    end
    local function clip(text)
        local out, count = {}, 0
        for _, code in utf8.codes(text) do
            if count >= 18 then break end
            out[#out + 1] = utf8.char(code)
            count = count + 1
        end
        return table.concat(out)
    end
    if row1 ~= "" then GbFont.drawString(clip(row1), 1, 14) end
    if row2 and row2 ~= "" then GbFont.drawString(clip(row2), 1, 16) end
    local line = self.lines[self.currentLine]
    if self.arrows[self.currentLine] and self.charIndex >= #line
        and math.floor(self.blinkTimer / 15) % 2 == 0 then
        GbFont.drawChar("▼", 18, 16)
    end
    gfx.setDrawOffset(ox, oy)
end
