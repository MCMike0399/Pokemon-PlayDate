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

function TitleState:enter(options)
    gfx.sprite.removeAll()
    self.game.camera:reset()
    self.epoch = (self.epoch or 0) + 1
    self.phase, self.message = "preparing", nil
    self.menu:hide()
    if not (options and options.preparing) then self:finishStartup() end
end

function TitleState:finishStartup()
    if self.phase ~= "preparing" or not self:isTop() then return end
    self:refresh()
end

function TitleState:refresh()
    self.epoch = (self.epoch or 0) + 1
    local epoch = self.epoch
    self.phase = "preparing"
    self.menu:hide()
    self.candidate, self.metadata = nil, nil
    return GameBootstrap.withLoading("title.inspect", function()
        local candidate, metadata
        if self.game.saves.prepareTitle then
            -- This optional hook retains fully decoded inactive owners, with
            -- all untrusted-load validators and constructor checks intact.
            candidate, metadata = self.game.saves:prepareTitle()
        else
            candidate, metadata = self.game.saves:inspect()
        end
        if epoch ~= self.epoch or not self:isTop() then return end
        if candidate then
            BootTrace.mark("title.map.prepare.begin")
            local provider = WorldDeltas.definitionProvider()
            local key = provider and provider:keyForID(candidate:location().zone_id)
            -- Existing bounded cache only: no zone switch, durable deltas,
            -- RNG activation, actors or second runtime/view are installed.
            if key then provider:ensure(key) end
            BootTrace.mark("title.map.prepare.end")
        end
        if epoch ~= self.epoch or not self:isTop() then return end
        self.candidate, self.metadata = candidate, metadata
        self.phase = "menu"
        self:showChoices(epoch)
    end, function()
        self:draw()
        return true
    end)
end

function TitleState:showChoices(epoch)
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
    self.menu:show(options, function(index)
        if self.epoch == epoch and self:isTop() and self.phase == "menu" then
            self:choose(actions[index])
        end
    end)
end

function TitleState:choose(action)
    if not self:isTop() or self.phase ~= "menu" then return end
    local epoch = self.epoch
    local function current(phase)
        return self.epoch == epoch and self:isTop() and self.phase == phase
    end
    if action == "options" then
        self.machine:push("options")
    elseif action == "continue" then
        local saves = self.game.saves
        local continueGame = saves.continuePreparedTitle or saves.continueGame
        local ok = continueGame(saves)
        if not ok then self:showMessage("The save could not be opened.") end
    elseif action == "new" then
        self.phase = "confirm-new"
        self.menu:show({"NO", "YES"}, function(index)
            if not current("confirm-new") then return end
            if index == 1 then self.phase = "menu"; self:refresh(); return end
            local ok = self.game.saves:beginNewGame(RulesRNG.snapshot().seed)
            if ok then self.game.machine:push("dialog", Story.openingLines)
            else self:showMessage("The new adventure could not be started.") end
        end, function()
            if current("confirm-new") then self:refresh() end
        end)
    else
        self.phase = "confirm-recovery"
        self.menu:show({"NO", "YES"}, function(index)
            if not current("confirm-recovery") then return end
            if index == 1 then self.phase = "menu"; self:refresh(); return end
            local ok = self.game.saves:recover(action)
            self:showMessage(ok and "Your save has been recovered." or "The save could not be recovered.")
        end, function()
            if current("confirm-recovery") then self:refresh() end
        end)
    end
end

function TitleState:showMessage(message)
    if not self:isTop() then return end
    self.phase, self.message = "message", message
    self.menu:hide()
end

function TitleState:exit()
    self.epoch = (self.epoch or 0) + 1
    self.phase = "closed"
    self.menu:hide()
    self.menu.onSelect, self.menu.onCancel = nil, nil
    self.candidate = nil
    if self.game.saves and self.game.saves.discardPreparedTitle then
        self.game.saves:discardPreparedTitle()
    end
    gfx.sprite.addDirtyRect(0, 0, 400, 240)
end

function TitleState:handleInput()
    if self.phase == "preparing" or self.phase == "closed" then return end
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
    if self.phase == "menu" or self.phase == "preparing" then
        local crowded = self.phase == "menu" and #self.actions > 3
        local scale = crowded and 1 or 2
        self.logo:drawScaled(16, 8, scale)
        self.versionArt:drawScaled(crowded and 48 or 80, crowded and 66 or 120, scale)
        local w, h = self.pokemonArt:getSize()
        self.pokemonArt:drawScaled(336 - w, crowded and 40 or 20, 2)
        if self.phase == "preparing" then
            gfx.drawText("Preparing adventure...", 24, 180)
            return
        end
        local menuY = crowded and 82 or 146
        local menuHeight = math.min(150, 16 + #self.actions * 20)
        self.menu:draw(16, menuY, 208, menuHeight)
        if self.candidate then
            gfx.drawText("PLAYER  RED", 240, 158)
            gfx.drawText("POKEMON  " .. self.candidate:party():count(), 240, 180)
            gfx.drawText("$" .. self.candidate:inventory():money(), 240, 202)
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
