local gfx <const> = playdate.graphics
Class("TitleState"):extends(State)

function TitleState:init(game)
    TitleState.super.init(self, "title")
    self.game = game
    self.menu = BattleMenu()
end

function TitleState:enter()
    gfx.sprite.removeAll()
    self.game.camera:reset()
    self.phase, self.message = "menu", nil
    self:refresh()
end

function TitleState:refresh()
    self.candidate, self.metadata = self.game.saves:inspect()
    local options, actions = {}, {}
    local function add(text, action)
        options[#options + 1], actions[#actions + 1] = text, action
    end
    if self.candidate then add("CONTINUE", "continue") end
    if self.metadata.reason == "recoverable-candidate" then
        add("RECOVER SAVE", "candidate")
    elseif self.candidate and (self.metadata.hasCorruption or self.metadata.pendingCandidate) then
        add("REPAIR SAVE", "published")
    end
    add("NEW GAME", "new")
    self.actions = actions
    self.menu:show(options, function(index) self:choose(actions[index]) end)
end

function TitleState:choose(action)
    if action == "continue" then
        local ok = self.game.saves:continueGame()
        if not ok then self:showMessage("The save could not be opened.") end
    elseif action == "new" then
        self.phase = "confirm-new"
        self.menu:show({"NO", "YES"}, function(index)
            if index == 1 then self.phase = "menu"; self:refresh(); return end
            local ok = self.game:beginNewSession(RulesRNG.snapshot().seed)
            if ok then self.game.machine:push("dialog", Story.openingLines)
            else self:showMessage("The new adventure could not be started.") end
        end, function() self.phase = "menu"; self:refresh() end)
    else
        self.phase = "confirm-recovery"
        self.menu:show({"NO", "YES"}, function(index)
            if index == 1 then self.phase = "menu"; self:refresh(); return end
            local ok = self.game.saves:recover(action)
            self:showMessage(ok and "Your save has been recovered." or "The save could not be recovered.")
        end, function() self.phase = "menu"; self:refresh() end)
    end
end

function TitleState:showMessage(message)
    self.phase, self.message = "message", message
    self.menu:hide()
end

function TitleState:exit()
    self.phase = "closed"
    self.menu:hide()
    self.menu.onSelect, self.menu.onCancel = nil, nil
    self.candidate = nil
    gfx.sprite.addDirtyRect(0, 0, 400, 240)
end

function TitleState:handleInput()
    if self.phase == "message" then
        if playdate.buttonJustPressed(playdate.kButtonA) or playdate.buttonJustPressed(playdate.kButtonB) then
            self.phase, self.message = "menu", nil
            self:refresh()
        end
    else
        self.menu:handleInput()
    end
end

function TitleState:draw()
    self.game.camera:reset()
    gfx.clear(gfx.kColorWhite)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawText("POKEMON BLUE", 20, 16)
    if self.phase == "menu" then
        self.menu:draw(16, 50, 192, 92)
        if self.candidate then
            local mon = self.candidate:activePokemon()
            gfx.drawText("PLAYER  RED", 224, 54)
            gfx.drawText("POKEMON  " .. self.candidate:party():count(), 224, 78)
            gfx.drawText("$" .. self.candidate:inventory():money(), 224, 102)
            if mon then gfx.drawText(mon.name .. "  Lv" .. mon.level, 20, 158) end
        elseif self.metadata.reason ~= "empty" then
            gfx.drawTextInRect("Your save needs attention. It has not been overwritten.", 20, 154, 360, 64)
        end
    elseif self.phase == "message" then
        gfx.drawTextInRect(self.message .. "\n\nA: OK", 20, 60, 360, 160)
    else
        local text = self.phase == "confirm-new"
            and "Start a new adventure?\nSaving it will replace your previous adventure."
            or "Recover the available save?"
        gfx.drawTextInRect(text, 20, 52, 360, 74)
        self.menu:draw(200, 140, 180, 60)
    end
end
