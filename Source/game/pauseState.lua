local gfx <const> = playdate.graphics
Class("PauseState"):extends(State)

function PauseState:init(game)
    PauseState.super.init(self, "pause")
    self.game, self.menu = game, BattleMenu()
end

function PauseState:enter()
    self.phase = "menu"
    local options = {"POKEMON", "ITEM", "RED", "SAVE", "OPTIONS", "CLOSE"}
    if self.game.session:questFlag("EVENT_GOT_POKEDEX") then table.insert(options, 1, "POKEDEX") end
    self.menu:show(options, function(index)
        local selected = options[index]
        if selected == "POKEDEX" or selected == "POKEMON" or selected == "ITEM" then
            self.machine:pop()
            self.machine:push(({POKEDEX="pokedex", POKEMON="party", ITEM="bag"})[selected])
        elseif selected == "OPTIONS" then
            self.machine:push("options")
        elseif selected == "RED" then
            self.phase = "trainer"
        elseif selected == "SAVE" then
            self.phase = "save"
            self.menu:show({"YES", "NO"}, function(choice)
                if choice == 2 then self:enter(); return end
                self.machine:pop() -- Capture only the settled overworld.
                local ok, metadata = self.game.saves:save()
                self.lastSave = {ok = ok, reason = metadata and metadata.reason}
                local lines
                if ok then
                    lines={"RED saved the game!"}
                    if metadata and metadata.archived then lines[#lines+1]="Previous save files were kept as a backup." end
                else
                    lines={"Save failed. Your adventure is still in memory.","Restart to review available save recovery."}
                end
                self.machine:push("dialog", lines)
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
        self.menu:draw(208, 8, 184, 16 + #self.menu.options * 20)
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

function PauseState:resume()
    self.menu.crank:reset()
end
