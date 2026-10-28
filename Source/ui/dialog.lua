local gfx <const> = playdate.graphics

Class("Dialog")

function Dialog:init()
    self.lines = {}
    self.currentLine = 1
    self.charIndex = 0
    self.isActive = false
    self.onComplete = nil
    self.blinkTimer = 0
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
end

function Dialog:update()
    if not self.isActive then return end

    local line = self.lines[self.currentLine]
    if self.charIndex < #line then
        self.charIndex = SourceText.nextBoundary(line, self.charIndex)
    else
        self.blinkTimer = self.blinkTimer + 1
    end
end

function Dialog:handleInput()
    if not self.isActive then return end

    if playdate.buttonJustPressed(playdate.kButtonA) then self:advance() end
end

-- The same reveal/advance seam serves native keys and SDK contracts.
function Dialog:advance()
    if not self.isActive then return end
    local line = self.lines[self.currentLine]
    if self.charIndex < #line then
        self.charIndex = #line
    else
        self.currentLine = self.currentLine + 1
        self.charIndex = 0
        self.blinkTimer = 0
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

    local boxY = 180
    local boxH = 60
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, boxY, 400, boxH)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(4, boxY + 4, 392, boxH - 8)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(4, boxY + 4, 392, boxH - 8)

    local line = self.lines[self.currentLine]
    local displayText = string.sub(line, 1, self.charIndex)
    -- Word-wrapped inside the frame so long lines never escape the box
    if self.legacy[self.currentLine] then
        gfx.drawTextInRect(displayText, 14, boxY + 12, 372, 42)
    else
        local y = boxY + 12
        for row in (displayText .. "\n"):gmatch("(.-)\n") do
            SourceTextFont.draw(row, 14, y, self.font)
            y = y + self.font:getHeight() + self.font:getLeading()
        end
    end

    if self.charIndex >= #line and math.floor(self.blinkTimer / 15) % 2 == 0 then
        if self.legacy[self.currentLine] then
            gfx.drawText("v", 380, boxY + 40)
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
