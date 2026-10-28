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
local function openingOptions(options)
    if options == nil then return {} end
    assert(type(options) == "table", "learning options must be an object")
    for key in pairs(options) do assert(key == "waitForRelease", "unknown learning option") end
    assert(options.waitForRelease == nil or type(options.waitForRelease) == "boolean", "invalid learning input gate")
    return options
end

function LearningState.open(game, pokemon, onComplete, options)
    options = openingOptions(options)
    local state = game.machine:get("learning")
    assert(state, "LearningState must be registered before offering learning")
    if state.active then
        assert(state.pokemon == pokemon, "Another Pokemon owns the learning session")
        return true
    end
    if not pokemon or #pokemon:getPendingMoveChoices() == 0 then return false end
    game.machine:push("learning", pokemon, onComplete, options)
    return true
end

-- Machine teaching is an explicit typed request from a current field Bag visit.
-- It never becomes a durable level/evolution choice or a free-form resolver.
function LearningState.openTeaching(game,request,onComplete)
    if type(request)~="table" or type(request.is)~="function" or not request:is("TeachingRequest") then return false,"invalid-request" end
    local bag=game.machine:get("bag")
    if not bag or game.machine:current()~=bag or not bag.active or bag.session~=game.session
        or bag.options.trySelect or bag.options.mode=="held" then return false,"field-bag-required" end
    local state=game.machine:get("learning")
    if state.active or request:getSnapshot().status~="prepared" then return false,"not-prepared" end
    game.machine:push("learning",request,onComplete,{waitForRelease=true})
    return true
end

-- Old UI callbacks become inert after exit or reentry.
function LearningState:guard(callback)
    local visit, generation = self.visit, self.viewGeneration
    return function(...)
        if self.active and self.visit == visit and self.viewGeneration == generation then return callback(...) end
    end
end

function LearningState:enter(pokemon, onComplete, options)
    options = openingOptions(options)
    local teaching=pokemon and pokemon:is("TeachingRequest") and pokemon
    if teaching then pokemon=Teaching.pokemon(teaching) end
    assert(pokemon and pokemon:is("Pokemon"), "LearningState requires a Pokemon or teaching request")
    self.teaching,self.teachingSession=teaching,teaching and self.game.session or nil
    self.visit = self.visit + 1
    self.active = true
    self.waitForRelease = options.waitForRelease == true
    self.pokemon = pokemon
    self.onComplete = onComplete
    self.results = {}
    self.requestedAdvance = false
    self.requestedClose = nil
    self.slot = nil
    self:nextChoice()
end

function LearningState:exit()
    if self.teaching then Teaching.cancel(self.teaching) end
    self.teaching,self.teachingSession=nil,nil
    self.active = false
    self.waitForRelease = false
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

function LearningState:resolveChoice(decision,slot)
    if not self.teaching then return self.pokemon:resolveMoveChoice(self.choiceId,decision,slot) end
    local ok,result
    if self.game.session~=self.teachingSession then ok,result=false,"stale-session"
    else ok,result=Teaching.complete(self.teaching,decision,slot) end
    if ok then return result end
    Teaching.cancel(self.teaching)
    return {kind="failed",move=self.pendingMove,reason=result}
end

function LearningState:nextChoice()
    self.viewGeneration = self.viewGeneration + 1
    gfx.sprite.addDirtyRect(0, 0, 400, 240)
    self.dialog.isActive, self.dialog.onComplete = false, nil
    self.requestedAdvance = false
    if self.teaching then
        local preview=self.teaching:getSnapshot()
        if preview.status~="prepared" then self.phase="idle";self.requestedClose="complete";return end
        self.choiceId,self.pendingMove=0,preview.move
        if #self.pokemon.moves<4 then
            local result=self:resolveChoice("learn")
            self.results[#self.results+1]=result
            self:message({result.kind=="failed" and "That machine could not be used."
                or self.pokemon.name.." learned "..moveData[self.pendingMove].name.."!"},result.kind)
        else self:showAsk() end
        return
    end
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
        local result = self:resolveChoice("decline")
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
        if Teaching.protectedMove(self.pokemon.moves[self.slot]) then
            self:message({"HM moves can't be forgotten here."},"protected-hm");return
        end
        local result = self:resolveChoice("learn", self.slot)
        self.results[#self.results + 1] = result
        if result.kind=="failed" then self:message({"That machine could not be used."},"failed");return end
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
    if self.waitForRelease then
        if not playdate.buttonIsPressed(playdate.kButtonA) and not playdate.buttonIsPressed(playdate.kButtonB) then
            self.waitForRelease = false
        end
        return
    end
    if self.phase == "message" then self.dialog:handleInput() else self.menu:handleInput() end
    if self.requestedAdvance and self.active then self:nextChoice() end
    if self.requestedClose and self.active then self:finish(self.requestedClose) end
end

function LearningState:getSnapshot()
    local line = self.dialog.lines[self.dialog.currentLine]
    return {mode=self.teaching and "machine" or "level", item=self.teaching and self.teaching:getSnapshot().item or "none", input_blocked = self.waitForRelease == true, phase = self.phase, move = self.pendingMove or "", choice_id = self.choiceId or 0,
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
