local gfx <const> = playdate.graphics

class("BattleMenu").extends()

function BattleMenu:init()
    self.options = {}
    self.selectedIndex = 1
    self.isActive = false
    self.onSelect = nil
    self.onCancel = nil
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

    if playdate.buttonJustPressed(playdate.kButtonUp) then
        self.selectedIndex = self.selectedIndex - 1
        if self.selectedIndex < 1 then self.selectedIndex = #self.options end
    elseif playdate.buttonJustPressed(playdate.kButtonDown) then
        self.selectedIndex = self.selectedIndex + 1
        if self.selectedIndex > #self.options then self.selectedIndex = 1 end
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

    for i, option in ipairs(self.options) do
        local optY = y + 8 + (i - 1) * 20
        if i == self.selectedIndex then
            gfx.drawText("> " .. option, x + 8, optY)
        else
            gfx.drawText("  " .. option, x + 8, optY)
        end
    end
end
