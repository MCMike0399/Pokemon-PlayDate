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
                or self.pokemon.name.." learned\n"..moveData[self.pendingMove].name.."!"},result.kind)
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
            -- data/text/text_4.asm _LearnedMove1Text: the name and " learned"
            -- fill the first row, and `line` puts the move and "!" on the second.
            self:message({self.pokemon.name .. " learned\n" .. moveData[choice.move].name .. "!"}, "learned")
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
    local name = moveData[self.pendingMove].name
    local mon = self.pokemon.name
    -- data/text/text_4.asm _TryingToLearnText. YES is menu item 0:
    -- TryingToLearn does `rra` / `ret c`, so item 0 continues into the
    -- forget list and item 1 (NO) returns carry to AbandonLearning.
    self.prompt = mon .. " is\ntrying to learn\n" .. name
        .. "!\n\nBut, " .. mon .. "\ncan't learn more\nthan 4 moves!\n\nDelete an older\nmove to make room\nfor " .. name .. "?"
    self.menu.columns = 1
    self.menu:show({"YES", "NO"}, self:guard(function(index)
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
    -- _AbandonLearningText. YES (item 0) falls through to DidNotLearnText.
    -- NO (item 1) jumps back to DontAbandonLearning.
    self.prompt = "Abandon learning\n" .. moveData[self.pendingMove].name .. "?"
    self.menu:show({"YES", "NO"}, self:guard(function(index)
        if index == 2 then self:showAsk(); return end
        local result = self:resolveChoice("decline")
        self.results[#self.results + 1] = result
        -- data/text/text_4.asm _DidNotLearnText. The name is the first row,
        -- `line` prints "did not learn", and `cont` scrolls that row up
        -- before the move name and "!".
        self:message({self.pokemon.name .. "\ndid not learn",
            "did not learn\n" .. moveData[self.pendingMove].name .. "!"}, "declined")
    end), self:guard(function() self:showAsk() end))
end

function LearningState:showReplacement(selected)
    self.viewGeneration = self.viewGeneration + 1
    gfx.sprite.addDirtyRect(0, 0, 400, 240)
    self.phase = "replace"
    -- _WhichMoveToForgetText, then the hlcoord 4,7 b=4 c=14 list.
    self.prompt = "Which move should\nbe forgotten?"
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
    local forgotten = moveData[self.pokemon.moves[self.slot]].name
    local name = moveData[self.pendingMove].name
    -- LearnMove writes the move as soon as the list returns it. This
    -- session still asks before that write. YES commits; NO returns to
    -- the same list slot. _HMCantDeleteText blocks an HM.
    self.prompt = "Forget " .. forgotten .. " and\nlearn " .. name .. "?"
    self.menu:show({"YES", "NO"}, self:guard(function(index)
        if index == 2 then self:showReplacement(self.slot); return end
        if Teaching.protectedMove(self.pokemon.moves[self.slot]) then
            self:message({"HM techniques can't be deleted!"},"protected-hm");return
        end
        local result = self:resolveChoice("learn", self.slot)
        self.results[#self.results + 1] = result
        if result.kind=="failed" then self:message({"That machine could not be used."},"failed");return end
        -- _ForgotAndText ends the move with "!". _LearnedMove1Text is the next page.
        self:message({self.pokemon.name .. " forgot\n" .. moveData[result.forgotten].name .. "!",
            self.pokemon.name .. " learned\n" .. moveData[result.move].name .. "!"}, "learned")
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

function LearningState:battleUnderneath()
    local machine = self.machine
    if not machine or type(machine.stack) ~= "table" then return nil end
    for _, state in ipairs(machine.stack) do
        if state == self then return nil end
        if state.name == "battle" and state.scene then return state end
    end
    return nil
end

local function battleText(text, width)
    local boxY, boxH = 180, 60
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, boxY, 400, boxH)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(4, boxY + 4, 392, boxH - 8)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(4, boxY + 4, 392, boxH - 8)
    if not text or text == "" then return end
    local font = gfx.getSystemFont()
    gfx.setFont(font)
    local page = SourceTextFont.paginate(text, font, width or 360)[1] or ""
    local y = boxY + 8
    local step = font:getHeight() + font:getLeading()
    for row in (page .. "\n"):gmatch("(.-)\n") do
        if y + font:getHeight() > boxY + boxH - 4 then break end
        SourceTextFont.draw(row, 14, y, font)
        y = y + step
    end
end

function LearningState:draw()
    if not self.active then return end
    local x, y = gfx.getDrawOffset()
    local font = gfx.getFont()
    gfx.setDrawOffset(0, 0)
    gfx.setFont(gfx.getSystemFont())
    -- LearnMove prints into the battle text box over the saved screen
    -- (SaveScreenTilesToBuffer1). A battle under this state stays up.
    -- There is no separate "MOVE LEARNING" page.
    local battle = self:battleUnderneath()
    if battle then battle:draw() else gfx.clear(gfx.kColorWhite) end
    if self.phase == "message" then
        self.dialog:draw()
    elseif self.phase == "replace" then
        -- hlcoord 4,7 b=4 c=14, above WhichMoveToForgetText.
        self.menu:draw(80, 84, 308, 88)
        battleText(self.prompt, 360)
    elseif self.phase ~= "idle" and self.phase ~= "closed" then
        battleText(self.prompt, 270)
        self.menu:draw(300, 184, 92, 52)
    end
    gfx.setFont(font)
    gfx.setDrawOffset(x, y)
end
