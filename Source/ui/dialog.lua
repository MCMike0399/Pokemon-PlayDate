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
    self.lines = lines
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
        self.charIndex = self.charIndex + 1
    else
        self.blinkTimer = self.blinkTimer + 1
    end
end

function Dialog:handleInput()
    if not self.isActive then return end

    if playdate.buttonJustPressed(playdate.kButtonA) then
        local line = self.lines[self.currentLine]
        if self.charIndex < #line then
            self.charIndex = #line
        else
            self.currentLine = self.currentLine + 1
            self.charIndex = 0
            self.blinkTimer = 0
            if self.currentLine > #self.lines then
                self.isActive = false
                if self.onComplete then
                    self.onComplete()
                end
            end
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
    gfx.drawText(displayText, 14, boxY + 16)

    if self.charIndex >= #line and math.floor(self.blinkTimer / 15) % 2 == 0 then
        gfx.drawText("v", 380, boxY + 40)
    end
end
