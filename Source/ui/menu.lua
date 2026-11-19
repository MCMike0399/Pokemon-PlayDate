import "ui/crankScroll"

local gfx <const> = playdate.graphics

Class("BattleMenu")

function BattleMenu:init()
    self.options = {}
    self.selectedIndex = 1
    self.isActive = false
    self.onSelect = nil
    self.onCancel = nil
    self.columns = 1
    self.crank = CrankScroll()
end

function BattleMenu:show(options, onSelect, onCancel)
    self.crank:reset()
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

    local scrolled = self.crank:move(self.selectedIndex, #self.options)
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
    else
        self.selectedIndex = scrolled
    end
end

function BattleMenu:draw(x, y, w, h)
    if not self.isActive then return end

    -- Dialog boxes use a 4px frame. A 1px rect is the thin box BlueBot rejected.
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(x, y, w, h)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(x + 4, y + 4, math.max(1, w - 8), math.max(1, h - 8))
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(x + 4, y + 4, math.max(1, w - 8), math.max(1, h - 8))
    if not BattleMenu.font then
        BattleMenu.font = gfx.font.new("/System/Fonts/Asheville-Sans-14-Bold")
    end

    local cols = self.columns
    local colW = math.floor(w / cols)

    local visibleRows = math.max(1, math.floor((h - 8) / 20))
    local selectedRow = math.floor((self.selectedIndex - 1) / cols)
    local firstRow = math.max(0, selectedRow - visibleRows + 1)
    local first = firstRow * cols + 1
    local last = math.min(#self.options, (firstRow + visibleRows) * cols)
    for i = first, last do
        local option = self.options[i]
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local optX = x + col * colW + 8
        local optY = y + 8 + (row - firstRow) * 20
        local selected = i == self.selectedIndex
        local glyphs = self.glyphs
        if not glyphs then glyphs = {}; self.glyphs = glyphs end
        local glyph = glyphs[i]
        if not glyph or glyph.option ~= option or glyph.selected ~= selected then
            local label = (selected and "▶" or " ") .. option
            local width, height = gfx.getTextSize(label)
            local image = gfx.image.new(math.max(1, width), math.max(1, height), gfx.kColorClear)
            gfx.pushContext(image)
            gfx.setDrawOffset(0, 0)
            gfx.clearClipRect()
            gfx.clearStencil()
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
            gfx.setFont(BattleMenu.font or gfx.getFont())
            gfx.drawText(label, 0, 0)
            gfx.popContext()
            glyph = {option = option, selected = selected, image = image}
            glyphs[i] = glyph
        end
        glyph.image:draw(optX, optY)
    end
end
