local gfx <const> = playdate.graphics

Class("BattleMenu")

function BattleMenu:init()
    self.options = {}
    self.selectedIndex = 1
    self.isActive = false
    self.onSelect = nil
    self.onCancel = nil
    self.columns = 1
end

function BattleMenu:show(options, onSelect, onCancel)
    self.options = options
    self.selectedIndex = 1
    self.isActive = true
    self.onSelect = onSelect
    self.onCancel = onCancel
end

function BattleMenu:hide()
    self.isActive = false
end

function BattleMenu:handleInput()
    if not self.isActive then return end

    local cols = self.columns
    local rows = math.ceil(#self.options / cols)
    local col = (self.selectedIndex - 1) % cols
    local row = math.floor((self.selectedIndex - 1) / cols)

    if playdate.buttonJustPressed(playdate.kButtonUp) then
        row = row - 1
        if row < 0 then row = rows - 1 end
        local newIdx = row * cols + col + 1
        if newIdx <= #self.options then self.selectedIndex = newIdx end
    elseif playdate.buttonJustPressed(playdate.kButtonDown) then
        row = row + 1
        if row >= rows then row = 0 end
        local newIdx = row * cols + col + 1
        if newIdx <= #self.options then self.selectedIndex = newIdx end
    elseif playdate.buttonJustPressed(playdate.kButtonLeft) and cols > 1 then
        col = col - 1
        if col < 0 then col = cols - 1 end
        local newIdx = row * cols + col + 1
        if newIdx <= #self.options then self.selectedIndex = newIdx end
    elseif playdate.buttonJustPressed(playdate.kButtonRight) and cols > 1 then
        col = col + 1
        if col >= cols then col = 0 end
        local newIdx = row * cols + col + 1
        if newIdx <= #self.options then self.selectedIndex = newIdx end
    elseif playdate.buttonJustPressed(playdate.kButtonA) then
        if self.onSelect then
            self.onSelect(self.selectedIndex, self.options[self.selectedIndex])
        end
    elseif playdate.buttonJustPressed(playdate.kButtonB) then
        if self.onCancel then
            self.onCancel()
        end
    end
end

function BattleMenu:draw(x, y, w, h)
    if not self.isActive then return end

    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(x, y, w, h)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(x, y, w, h)

    local cols = self.columns
    local colW = math.floor(w / cols)

    for i, option in ipairs(self.options) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local optX = x + col * colW + 8
        local optY = y + 8 + row * 20
        if i == self.selectedIndex then
            gfx.drawText(">" .. option, optX, optY)
        else
            gfx.drawText(" " .. option, optX, optY)
        end
    end
end
