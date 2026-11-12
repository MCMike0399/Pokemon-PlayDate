import "game/gameOptions"

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

function Dialog:show(lines, onComplete)
    assert(type(lines) == "table" and #lines > 0, "nonempty dialogue required")
    self.font = gfx.getFont()
    self.lines, self.legacy = {}, {}
    for _, text in ipairs(lines) do
        assert(type(text) == "string" and utf8.len(text), "valid UTF-8 dialogue required")
        -- Retain exact existing drawing for short ordinary strings. Longer
        -- strings use precomputed full pages; draw never decides pagination.
        local width, height = gfx.getTextSizeForMaxWidth(text, 372)
        local ordinary = not text:find("[\128-\255\f*_]")
        local legacySafe = false
        if ordinary and width <= 372 and height <= 42 then
            local measured = SourceTextFont.paginate(text, self.font, 372)
            local lastRow = measured[#measured]:match("[^\n]*$")
            legacySafe = #measured == 1 and SourceTextFont.width(lastRow, self.font) <= 360
        end
        if legacySafe then
            self.lines[#self.lines + 1] = text
            self.legacy[#self.lines] = true
        else
            local pages = SourceTextFont.paginate(text, self.font)
            for _, page in ipairs(pages) do
                self.lines[#self.lines + 1] = page
                self.legacy[#self.lines] = false
            end
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

function Dialog:_pageImage()
    local key = self.currentLine * 100000 + self.charIndex
    if self.pageKey == key then return self.pageImage end
    self.pageKey = key
    if not self.pageImage then
        self.pageImage = gfx.image.new(372, 42, gfx.kColorWhite)
    end
    local line = self.lines[self.currentLine]
    local displayText = string.sub(line, 1, self.charIndex)
    gfx.pushContext(self.pageImage)
    gfx.setDrawOffset(0, 0)
    gfx.clearClipRect()
    gfx.clearStencil()
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setFont(self.font or gfx.getSystemFont())
    gfx.clear(gfx.kColorWhite)
    if self.legacy[self.currentLine] then
        gfx.drawTextInRect(displayText, 0, 0, 372, 42)
    else
        local y = 0
        local font = self.font
        for row in (displayText .. "\n"):gmatch("(.-)\n") do
            SourceTextFont.draw(row, 0, y, font)
            y = y + font:getHeight() + font:getLeading()
        end
    end
    gfx.popContext()
    return self.pageImage
end

function Dialog:draw()
    if not self.isActive then return end

    local boxY = 180
    local boxH = 60
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, boxY, 400, boxH)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(4, boxY + 4, 392, boxH - 8)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(4, boxY + 4, 392, boxH - 8)

    self:_pageImage():draw(14, boxY + 12)

    local line = self.lines[self.currentLine]
    if self.charIndex >= #line and math.floor(self.blinkTimer / 15) % 2 == 0 then
        if self.legacy[self.currentLine] then
            if not self.arrowImage then
                local width, height = gfx.getTextSize("v")
                self.arrowImage = gfx.image.new(math.max(1, width), math.max(1, height), gfx.kColorClear)
                gfx.pushContext(self.arrowImage)
                gfx.setDrawOffset(0, 0)
                gfx.setImageDrawMode(gfx.kDrawModeCopy)
                gfx.drawText("v", 0, 0)
                gfx.popContext()
            end
            self.arrowImage:draw(380, boxY + 40)
        else
            -- A small source-style down arrow has a dedicated gutter and fits
            -- entirely inside the frame, independent of the SDK font ascent.
            gfx.fillRect(380, 226, 7, 1)
            gfx.fillRect(381, 227, 5, 1)
            gfx.fillRect(382, 228, 3, 1)
            gfx.fillRect(383, 229, 1, 1)
        end
    end
end
