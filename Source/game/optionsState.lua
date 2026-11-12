import "game/gameOptions"
local gfx <const> = playdate.graphics
Class("OptionsState"):extends(State)

function OptionsState:init(game)
    OptionsState.super.init(self, "options")
    self.game = game
end

function OptionsState:enter()
    GameOptions.load()
    self.selected = 1
    self.error = nil
end

function OptionsState:rowCount()
    return #GameOptions.rows + 1
end

function OptionsState:moveChoice(direction)
    local row = GameOptions.rows[self.selected]
    if not row then return end
    local choices = row.choices
    local current = GameOptions.get(row.key)
    local index = 1
    for cursor, value in ipairs(choices) do
        if value == current then index = cursor end
    end
    -- DisplayOptionMenu does not wrap a row's choices.
    if direction < 0 and index == 1 then return end
    if direction > 0 and index == #choices then return end
    GameOptions.set(row.key, choices[index + direction])
end

function OptionsState:exitMenu()
    if GameOptions.save() then
        self.machine:pop()
    else
        self.error = "Options could not be saved. B: Retry"
    end
end

function OptionsState:handleInput()
    local count = self:rowCount()
    if playdate.buttonJustPressed(playdate.kButtonUp) then
        self.selected = (self.selected - 2) % count + 1
    elseif playdate.buttonJustPressed(playdate.kButtonDown) then
        self.selected = self.selected % count + 1
    elseif playdate.buttonJustPressed(playdate.kButtonLeft) then
        self:moveChoice(-1)
    elseif playdate.buttonJustPressed(playdate.kButtonRight) then
        self:moveChoice(1)
    elseif playdate.buttonJustPressed(playdate.kButtonA) then
        if self.selected == count then self:exitMenu() end
    elseif playdate.buttonJustPressed(playdate.kButtonB) then
        self:exitMenu()
    end
end

function OptionsState:draw()
    local x, y = gfx.getDrawOffset()
    local font = gfx.getFont()
    gfx.setDrawOffset(0, 0)
    gfx.setFont(gfx.getSystemFont())
    gfx.clear(gfx.kColorWhite)
    gfx.setColor(gfx.kColorBlack)
    for index, row in ipairs(GameOptions.rows) do
        local rowY = 8 + (index - 1) * 44
        gfx.drawRect(8, rowY, 384, 40)
        gfx.drawText(row.label, 20, rowY + 4)
        local line = {}
        local current = GameOptions.get(row.key)
        for _, choice in ipairs(row.choices) do
            local marker = (index == self.selected and choice == current) and ">" or " "
            line[#line + 1] = marker .. choice
        end
        gfx.drawText(table.concat(line, "   "), 20, rowY + 20)
    end
    local cancelY = 8 + #GameOptions.rows * 44
    local marker = self.selected == self:rowCount() and ">" or " "
    gfx.drawText(marker .. GameOptions.cancelLabel, 20, cancelY)
    gfx.drawText(self.error or "D-pad: Choose     A on CANCEL / B: Save & Back", 16, 214)
    gfx.setFont(font)
    gfx.setDrawOffset(x, y)
end

function OptionsState:exit()
    gfx.sprite.addDirtyRect(0, 0, 400, 240)
end
