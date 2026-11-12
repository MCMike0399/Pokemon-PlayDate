import "game/gameOptions"
import "game/gbFont"
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

-- DisplayOptionMenu places ▷ on each row's current choice and ▶ on the
-- active row (PlaceMenuCursor). The three boxes match options.asm.
-- CRANK SCROLL sits on the row under the last box. CANCEL has the next
-- row to itself, with a blank row between them.
function OptionsState:draw()
    local x, y = gfx.getDrawOffset()
    gfx.setDrawOffset(0, 0)
    gfx.clear(gfx.kColorWhite)
    local boxes = {
        {origin = 0, labelRow = 1, choiceRow = 2, cols = {1, 7, 14}},
        {origin = 4, labelRow = 5, choiceRow = 6, cols = {1, 10}},
        {origin = 8, labelRow = 9, choiceRow = 10, cols = {1, 10}},
    }
    for index, row in ipairs(GameOptions.rows) do
        local current = GameOptions.get(row.key)
        local choiceIndex = 1
        for cursor, value in ipairs(row.choices) do
            if value == current then choiceIndex = cursor end
        end
        local marker = index == self.selected and TitleIdle.CURSOR or TitleIdle.MARK
        if boxes[index] then
            local spec = boxes[index]
            GbFont.drawBox(TitleIdle.textBox(0, spec.origin, 18, 2))
            GbFont.drawString(row.label, 1, spec.labelRow)
            for cursor, value in ipairs(row.choices) do
                local col = spec.cols[cursor] or (1 + (cursor - 1) * 8)
                if cursor == choiceIndex then GbFont.drawChar(marker, col, spec.choiceRow) end
                GbFont.drawString(value, col + 1, spec.choiceRow)
            end
        else
            local place = GameOptions.crankPlace(choiceIndex)
            GbFont.drawString(row.label, place.labelCol, place.row)
            GbFont.drawChar(marker, place.choiceCol, place.row)
            GbFont.drawString(row.choices[choiceIndex], place.choiceCol + 1, place.row)
        end
    end
    local cancel = GameOptions.cancelPlace(self.selected == self:rowCount())
    if cancel.cursor then GbFont.drawChar(TitleIdle.CURSOR, cancel.cursor, cancel.row) end
    GbFont.drawString(GameOptions.cancelLabel, cancel.col, cancel.row)
    if self.error then GbFont.drawTight(self.error, 8, 222) end
    gfx.setDrawOffset(x, y)
end

function OptionsState:exit()
    gfx.sprite.addDirtyRect(0, 0, 400, 240)
end
