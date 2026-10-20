-- Pending move choices as a native overlay. Pokemon owns durable choices;
-- this state owns only menus/messages and an explicit learning session.
local gfx <const> = playdate.graphics
Class("LearningState"):extends(State)

function LearningState:init(game)
    LearningState.super.init(self, "learning")
    self.game = game
    self.menu = BattleMenu()
    self.dialog = Dialog()
    self.phase = "closed"
    self.active = false
    self.visit = 0
    self.viewGeneration = 0
end

-- Called by the session owner after the world/battle return is established.
-- An interrupted session leaves unresolved choices on the Pokemon.
function LearningState.open(game, pokemon, onComplete)
    local state = game.machine:get("learning")
    assert(state, "LearningState must be registered before offering learning")
    if state.active then
        assert(state.pokemon == pokemon, "Another Pokemon owns the learning session")
        return true
    end
    if not pokemon or #pokemon:getPendingMoveChoices() == 0 then return false end
    game.machine:push("learning", pokemon, onComplete)
    return true
end

-- Old UI callbacks become inert after exit or reentry.
function LearningState:guard(callback)
    local visit, generation = self.visit, self.viewGeneration
    return function(...)
        if self.active and self.visit == visit and self.viewGeneration == generation then return callback(...) end
    end
end

function LearningState:enter(pokemon, onComplete)
    assert(pokemon and pokemon:is("Pokemon"), "LearningState requires a Pokemon")
    self.visit = self.visit + 1
    self.active = true
    self.pokemon = pokemon
    self.onComplete = onComplete
    self.results = {}
    self.requestedAdvance = false
    self.requestedClose = nil
    self.slot = nil
    self:nextChoice()
end

function LearningState:exit()
    self.active = false
    self.visit = self.visit + 1
    self.menu:hide()
    self.menu.onSelect, self.menu.onCancel = nil, nil
    self.dialog.isActive, self.dialog.onComplete = false, nil
    self.pokemon, self.onComplete, self.choiceId, self.pendingMove = nil, nil, nil, nil
    self.requestedAdvance, self.requestedClose = false, nil
    self.phase = "closed"
    -- Screen-coordinate invalidation: the world uses dirty sprite rendering.
    -- Force the departing menu/dialog area to be redrawn on return.
    gfx.sprite.addDirtyRect(0, 0, 400, 240)
end

function LearningState:message(lines, kind)
    self.viewGeneration = self.viewGeneration + 1
    gfx.sprite.addDirtyRect(0, 0, 400, 240)
    self.phase = "message"
    self.messageKind = kind
    self.menu:hide()
    self.dialog:show(lines, self:guard(function() self.requestedAdvance = true end))
end

function LearningState:nextChoice()
    self.viewGeneration = self.viewGeneration + 1
    gfx.sprite.addDirtyRect(0, 0, 400, 240)
    self.dialog.isActive, self.dialog.onComplete = false, nil
    self.requestedAdvance = false
    while true do
        local choice = self.pokemon:getPendingMoveChoices()[1]
        if not choice then
            self.phase = "idle"
            self.requestedClose = "complete"
            return
        end
        self.choiceId, self.pendingMove = choice.id, choice.move
        if self.pokemon:hasMove(choice.move) then
            self.results[#self.results + 1] = self.pokemon:resolveMoveChoice(choice.id, "learn")
        elseif #self.pokemon.moves < 4 then
            self.results[#self.results + 1] = self.pokemon:resolveMoveChoice(choice.id, "learn")
            self:message({self.pokemon.name .. " learned " .. moveData[choice.move].name .. "!"}, "learned")
            return
        else
            self:showAsk()
            return
        end
    end
end

function LearningState:showAsk()
    self.viewGeneration = self.viewGeneration + 1
    gfx.sprite.addDirtyRect(0, 0, 400, 240)
    self.phase = "ask"
    self.messageKind = nil
    self.slot = nil
    self.menu.columns = 1
    self.menu:show({"LEARN", "KEEP MOVES"}, self:guard(function(index)
        if index == 1 then
            self:showReplacement()
        else
            self:showStopConfirmation()
        end
    end), self:guard(function() self:showStopConfirmation() end))
end

function LearningState:showStopConfirmation()
    self.viewGeneration = self.viewGeneration + 1
    gfx.sprite.addDirtyRect(0, 0, 400, 240)
    self.phase = "stop"
    self.menu:show({"YES", "NO"}, self:guard(function(index)
        if index == 2 then self:showAsk(); return end
        local result = self.pokemon:resolveMoveChoice(self.choiceId, "decline")
        self.results[#self.results + 1] = result
        self:message({self.pokemon.name .. " did not learn " .. moveData[self.pendingMove].name .. "."}, "declined")
    end), self:guard(function() self:showAsk() end))
end

function LearningState:showReplacement(selected)
    self.viewGeneration = self.viewGeneration + 1
    gfx.sprite.addDirtyRect(0, 0, 400, 240)
    self.phase = "replace"
    local options = {}
    for _, key in ipairs(self.pokemon.moves) do
        local move = moveData[key]
        options[#options + 1] = move.name .. "  " .. (self.pokemon.pp[key] or 0) .. "/" .. move.maxPP
    end
    self.menu.columns = 1
    self.menu:show(options, self:guard(function(index)
        self.slot = index
        self:showConfirmation()
    end), self:guard(function() self:showAsk() end))
    if selected then self.menu.selectedIndex = selected end
end

function LearningState:showConfirmation()
    self.viewGeneration = self.viewGeneration + 1
    gfx.sprite.addDirtyRect(0, 0, 400, 240)
    self.phase = "confirm"
    self.menu:show({"FORGET MOVE", "BACK"}, self:guard(function(index)
        if index == 2 then self:showReplacement(self.slot); return end
        local result = self.pokemon:resolveMoveChoice(self.choiceId, "learn", self.slot)
        self.results[#self.results + 1] = result
        self:message({self.pokemon.name .. " forgot " .. moveData[result.forgotten].name .. ".",
            self.pokemon.name .. " learned " .. moveData[result.move].name .. "!"}, "learned")
    end), self:guard(function() self:showReplacement(self.slot) end))
end

function LearningState:finish(kind)
    if not self.active or not self:isTop() then return end
    local callback = self.onComplete
    local result = {kind = kind, results = self.results, pending = #self.pokemon:getPendingMoveChoices()}
    self.onComplete = nil
    self.machine:pop()
    if callback then callback(result) end
end

function LearningState:update()
    self.dialog:update()
    if self.requestedClose and self:isTop() then self:finish(self.requestedClose) end
end

function LearningState:handleInput()
    if not self.active then return end
    if self.phase == "message" then self.dialog:handleInput() else self.menu:handleInput() end
    if self.requestedAdvance and self.active then self:nextChoice() end
    if self.requestedClose and self.active then self:finish(self.requestedClose) end
end

function LearningState:getSnapshot()
    local line = self.dialog.lines[self.dialog.currentLine]
    return {phase = self.phase, move = self.pendingMove or "", choice_id = self.choiceId or 0,
        selected = self.menu.selectedIndex, message_kind = self.messageKind or "",
        dialog_ready = self.dialog.isActive and line ~= nil and self.dialog.charIndex >= #line,
        remaining = self.pokemon and #self.pokemon:getPendingMoveChoices() or 0,
        pokemon = self.pokemon and self.pokemon.species or ""}
end

local function box(x, y, width, height, text)
    gfx.setColor(gfx.kColorWhite); gfx.fillRect(x, y, width, height)
    gfx.setColor(gfx.kColorBlack); gfx.drawRect(x, y, width, height)
    if text then gfx.drawTextInRect(text, x + 10, y + 9, width - 20, height - 12) end
end

function LearningState:draw()
    if not self.active then return end
    local x, y = gfx.getDrawOffset()
    local font = gfx.getFont()
    gfx.setDrawOffset(0, 0)
    gfx.setFont(gfx.getSystemFont())
    if self.phase == "message" then
        self.dialog:draw()
    elseif self.phase ~= "idle" then
        local name = moveData[self.pendingMove].name
        if self.phase == "replace" then
            box(12, 20, 376, 42, "Choose a move to forget.")
            self.menu:draw(12, 72, 376, 96)
            box(4, 184, 392, 52, "Learning " .. name .. ".  B: Back")
        elseif self.phase == "stop" then
            self.menu:draw(12, 112, 376, 60)
            box(4, 184, 392, 52, "Stop trying to learn " .. name .. "?")
        elseif self.phase == "confirm" then
            local forgotten = moveData[self.pokemon.moves[self.slot]].name
            self.menu:draw(12, 112, 376, 60)
            box(4, 184, 392, 52, "Forget " .. forgotten .. " and learn " .. name .. "?")
        else
            self.menu:draw(12, 112, 376, 60)
            box(4, 184, 392, 52, self.pokemon.name .. " wants to learn " .. name .. ".")
        end
    end
    gfx.setFont(font)
    gfx.setDrawOffset(x, y)
end
