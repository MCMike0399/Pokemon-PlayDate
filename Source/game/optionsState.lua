import "game/gameOptions"
local gfx <const> = playdate.graphics
Class("OptionsState"):extends(State)
local rows <const> = {
    {key = "textSpeed", label = "TEXT SPEED"},
    {key = "battleAnimations", label = "BATTLE ANIMATION"},
    {key = "battleStyle", label = "BATTLE STYLE"},
    {key = "crankScrolling", label = "CRANK SCROLL"},
}

function OptionsState:init(game)
    OptionsState.super.init(self, "options")
    self.game = game
end

function OptionsState:enter()
    GameOptions.load()
    self.selected = 1
    self.error = nil
end

function OptionsState:handleInput()
    if playdate.buttonJustPressed(playdate.kButtonUp) then
        self.selected = (self.selected - 2) % #rows + 1
    elseif playdate.buttonJustPressed(playdate.kButtonDown) then
        self.selected = self.selected % #rows + 1
    elseif playdate.buttonJustPressed(playdate.kButtonLeft) then
        GameOptions.cycle(rows[self.selected].key, -1)
    elseif playdate.buttonJustPressed(playdate.kButtonRight) or playdate.buttonJustPressed(playdate.kButtonA) then
        GameOptions.cycle(rows[self.selected].key, 1)
    elseif playdate.buttonJustPressed(playdate.kButtonB) then
        if GameOptions.save() then
            self.machine:pop()
        else
            self.error = "Options could not be saved. B: Retry"
        end
    end
end

function OptionsState:draw()
    local x, y = gfx.getDrawOffset()
    local font = gfx.getFont()
    gfx.setDrawOffset(0, 0)
    gfx.setFont(gfx.getSystemFont())
    gfx.clear(gfx.kColorWhite)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(4, 4, 392, 232)
    gfx.drawText("OPTIONS", 20, 16)
    for index, row in ipairs(rows) do
        local rowY = 52 + (index - 1) * 38
        gfx.drawText(index == self.selected and ">" or "", 14, rowY)
        gfx.drawText(row.label, 30, rowY)
        gfx.drawText("< " .. GameOptions.get(row.key) .. " >", 260, rowY)
    end
    gfx.drawText(self.error or "D-pad: Choose / Change     B: Save & Back", 18, 208)
    gfx.setFont(font)
    gfx.setDrawOffset(x, y)
end

function OptionsState:exit()
    gfx.sprite.addDirtyRect(0, 0, 400, 240)
end
