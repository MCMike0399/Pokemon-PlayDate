import "game/optionsState"
local gfx <const> = playdate.graphics
Class("TitleState"):extends(State)

function TitleState:init(game)
    TitleState.super.init(self, "title")
    self.game = game
    self.menu = BattleMenu()
    self.logo = assert(gfx.image.new("images/title/logo"))
    self.versionArt = assert(gfx.image.new("images/title/blue"))
    self.pokemonArt = assert(gfx.image.new(PokemonArt.path("blastoise", "front")))
end

function TitleState:enter()
    gfx.sprite.removeAll()
    self.game.camera:reset()
    self.phase, self.message = "menu", nil
    self:refresh()
end

function TitleState:refresh()
    local candidate, metadata = self.game.saves:inspect()
    -- Continue validates and loads the file again. The title needs only these
    -- preview numbers, not a second party, storage and session kept alive.
    self.candidate = candidate and {
        pokemonCount = candidate:party():count(),
        money = candidate:inventory():money(),
    } or nil
    self.metadata = metadata
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
    if self.metadata.proposalAvailable then add("RECOVER NEW SAVE", "proposal") end
    if self.metadata.backupPublished then add("RESTORE BACKUP", "backup-published") end
    if self.metadata.backupCandidate then add("RESTORE CANDIDATE", "backup-candidate") end
    add("NEW GAME", "new")
    add("OPTIONS", "options")
    self.actions = actions
    self.menu:show(options, function(index) self:choose(actions[index]) end)
end

function TitleState:choose(action)
    if action == "options" then
        self.machine:push("options")
    elseif action == "continue" then
        local ok = self.game.saves:continueGame()
        if not ok then self:showMessage("The save could not be opened.") end
    elseif action == "new" then
        self.phase = "confirm-new"
        self.menu:show({"NO", "YES"}, function(index)
            if index == 1 then self.phase = "menu"; self:refresh(); return end
            local ok = self.game.saves:beginNewGame(RulesRNG.snapshot().seed)
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
    if self.phase == "menu" then
        local crowded = #self.actions > 3
        local scale = crowded and 1 or 2
        self.logo:drawScaled(16, 8, scale)
        self.versionArt:drawScaled(crowded and 48 or 80, crowded and 66 or 120, scale)
        local w, h = self.pokemonArt:getSize()
        self.pokemonArt:drawScaled(336 - w, crowded and 40 or 20, 2)
        local menuY = crowded and 82 or 146
        local menuHeight = math.min(150, 16 + #self.actions * 20)
        self.menu:draw(16, menuY, 208, menuHeight)
        if self.candidate then
            gfx.drawText("PLAYER  RED", 240, 158)
            gfx.drawText("POKEMON  " .. self.candidate.pokemonCount, 240, 180)
            gfx.drawText("$" .. self.candidate.money, 240, 202)
        elseif self.metadata.reason ~= "empty" then
            gfx.drawTextInRect("Your save needs attention. It has not been overwritten.", 240, 158, 150, 74)
        end
    elseif self.phase == "message" then
        gfx.drawTextInRect(self.message .. "\n\nA: OK", 20, 60, 360, 160)
    else
        local text = self.phase == "confirm-new"
            and "Start a new adventure?\nOn SAVE, old save files will be kept as a backup before replacement."
            or "Recover this save? Current save files will first be kept as a backup."
        gfx.drawTextInRect(text, 20, 40, 360, 96)
        self.menu:draw(200, 140, 180, 60)
    end
end

function TitleState:resume()
    self.menu.crank:reset()
end
