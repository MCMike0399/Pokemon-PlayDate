local gfx <const> = playdate.graphics
Class("PauseState"):extends(State)

function PauseState:init(game)
    PauseState.super.init(self, "pause")
    self.game, self.menu = game, BattleMenu()
end

function PauseState:enter()
    self.phase = "menu"
    self.menu:show({"POKEMON", "ITEM", "RED", "SAVE", "CLOSE"}, function(index)
        if index == 1 or index == 2 then
            self.machine:pop()
            self.machine:push(index == 1 and "party" or "bag")
        elseif index == 3 then
            self.phase = "trainer"
        elseif index == 4 then
            self.phase = "save"
            self.menu:show({"YES", "NO"}, function(choice)
                if choice == 2 then self:enter(); return end
                self.machine:pop() -- Capture only the settled overworld.
                local ok, metadata = self.game.saves:save()
                self.lastSave = {ok = ok, reason = metadata and metadata.reason}
                self.machine:push("dialog", {ok and "RED saved the game!"
                    or "Save failed. Your adventure is still in memory."})
            end, function() self:enter() end)
        else
            self.machine:pop()
        end
    end, function() self.machine:pop() end)
end

function PauseState:exit()
    self.phase = "closed"
    self.menu:hide()
    self.menu.onSelect, self.menu.onCancel = nil, nil
    gfx.sprite.addDirtyRect(0, 0, 400, 240)
end

function PauseState:handleInput()
    if self.phase == "trainer" then
        if playdate.buttonJustPressed(playdate.kButtonA) or playdate.buttonJustPressed(playdate.kButtonB) then self:enter() end
    else
        self.menu:handleInput()
    end
end

function PauseState:draw()
    local x, y = gfx.getDrawOffset()
    gfx.setDrawOffset(0, 0)
    if self.phase == "menu" then
        self.menu:draw(208, 8, 184, 116)
    else
        gfx.setColor(gfx.kColorWhite); gfx.fillRect(16, 24, 368, 192)
        gfx.setColor(gfx.kColorBlack); gfx.drawRect(16, 24, 368, 192)
        if self.phase == "save" then
            gfx.drawText("Would you like to SAVE the game?", 28, 40)
            self.menu:draw(200, 112, 172, 60)
        else
            gfx.drawText("NAME  RED", 32, 42)
            gfx.drawText("MONEY  $" .. self.game.session:inventory():money(), 32, 72)
            local count = 0
            for _ in pairs(self.game.session:pokedex().owned) do count = count + 1 end
            gfx.drawText("POKEMON OWNED  " .. count, 32, 102)
            gfx.drawText("A / B: Back", 32, 178)
        end
    end
    gfx.setDrawOffset(x, y)
end
