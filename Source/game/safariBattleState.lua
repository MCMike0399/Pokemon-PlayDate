-- Overlay Safari mode: no normal Battle, attack menu, payout or XP owner.
Class("SafariBattleState"):extends(State)
local gfx <const> = playdate.graphics
local commands <const> = {"ball", "bait", "rock", "run"}
function SafariBattleState:init(game)
    SafariBattleState.super.init(self, "safariBattle")
    self.game = game
    self.menu = BattleMenu()
    self.menu.columns = 2
    self.dialog = Dialog()
end
function SafariBattleState.open(game, enemy)
    if not game.machine:get("safariBattle") or game.machine:getCurrent() ~= "overworld"
        or game.machine:depth() ~= 1 or game.player.isMoving
        or not SafariGame.isBattleMap(currentZone.stableID) then
        return false, "safari-battle-boundary"
    end
    local battle, reason = SafariBattle.begin(game.session:safariData(), enemy)
    if not battle then
        return false, reason
    end
    local called, scene = pcall(SafariScene, enemy)
    if not called then
        return false, tostring(scene)
    end
    local world = game.machine:get("overworld")
    if world.sub:getCurrent() == "irisOut" then
        world.sub:change("explore")
    end
    game.player.stepJustFinished = false
    game.machine:push("safariBattle", enemy, battle, scene)
    return true
end
function SafariBattleState:enter(enemy, battle, scene)
    self.epoch = (self.epoch or 0) + 1
    self.active = true
    self.session, self.zone = self.game.session, currentZone
    self.enemy, self.battle, self.scene = enemy, battle, scene
    self.animation, self.token, self.receipt, self.command = nil, nil, nil, nil
    self.lastFailure, self.frame = nil, 0
    self.turnCount, self.lastTurn = 0, nil
    self.session:markSeen(enemy.species)
    self:message({"Wild " .. enemy.name .. " appeared!"}, function() self:choose() end)
end
function SafariBattleState:valid()
    return self.active and self.game.session == self.session and currentZone == self.zone
        and self:isTop() and self.session:safariData().active
end
function SafariBattleState:message(lines, continuation)
    self.phase = "message"
    self.continuation = continuation
    self.dialog:show(lines, function()
        local callback = self.continuation
        self.continuation = nil
        if self:valid() and callback then
            callback()
        end
    end)
end
function SafariBattleState:choose()
    self.phase, self.command, self.animation = "command", nil, nil
    self.menu:show({"BALL", "BAIT", "ROCK", "RUN"}, function(index)
        self:select(commands[index])
    end, function() end)
end
function SafariBattleState:select(command)
    if not self:valid() or self.phase ~= "command" then
        return false, "stale-safari-selection"
    end
    local before = self.session:safariData()
    local token, reason = SafariBattle.prepare(self.session, self.enemy, self.battle, command)
    if not token then
        self.lastFailure = reason
        self:message({reason == "storage-full" and "The POKEMON BOX is full!" or "That action failed."},
            function() self:choose() end)
        return false, reason
    end
    local preview = assert(SafariBattle.preview(token))
    local animation
    if preview.receipt.capture then
        local called, result = pcall(CaptureAnimation, preview.receipt.capture)
        if not called then
            SafariBattle.cancel(token)
            self.lastFailure = tostring(result)
            self:message({"The SAFARI BALL could not be prepared."}, function() self:choose() end)
            return false, self.lastFailure
        end
        animation = result
    end
    -- All presentation allocations precede resource/capture publication.
    local accepted, result = self.session:commitSafariBattle(token)
    if not accepted then
        SafariBattle.cancel(token)
        self.lastFailure = result
        self:message({"That action failed."}, function() self:choose() end)
        return false, result
    end
    self.token = nil
    self.turnCount = self.turnCount + 1
    self.lastTurn = {sequence = self.turnCount, command = command,
        before = before, after = self.session:safariData(),
        receipt = GameSession._copy(result.receipt), destination = result.destination and GameSession._copy(result.destination) or nil,
        outcome = result.battle.outcome}
    self.command, self.battle, self.receipt = command, result.battle, result.receipt
    self.animation, self.frame, self.phase = animation, 0, "action"
    self.menu:hide()
    return true
end
function SafariBattleState:afterAction()
    local outcome = self.battle.outcome
    local lines = {}
    if outcome == "caught" then
        lines[1] = "Gotcha! " .. self.enemy.name .. " was caught!"
    elseif outcome == "fled" then
        lines[1] = self.enemy.name .. " ran away!"
    elseif outcome == "run" then
        lines[1] = "Got away safely!"
    elseif outcome == "out-of-balls" then
        lines[1] = "You're out of SAFARI BALLs!"
    else
        if self.command == "ball" then
            lines[#lines + 1] = "Oh no! The POKEMON broke free!"
        elseif self.command == "bait" then
            lines[#lines + 1] = "RED threw some BAIT!"
        elseif self.command == "rock" then
            lines[#lines + 1] = "RED threw a ROCK!"
        end
        lines[#lines + 1] = self.enemy.name .. (self.receipt.message == "eating" and " is eating!"
            or self.receipt.message == "angry" and " is angry!" or " is watching carefully!")
    end
    self:message(lines, function()
        if outcome == "command" then
            self:choose()
        else
            self:finish()
        end
    end)
end
function SafariBattleState:finish()
    if not self:valid() then
        return false, "stale-safari-finish"
    end
    local check = SafariGame.check(self.session:safariData())
    local accepted, reason = self.session:commitSafari(check, self.session:fieldWorldEpoch())
    if not accepted then
        self.lastFailure = reason
        return false, reason
    end
    self.game.lastSafariBattle = {kind = self.battle.outcome, species = self.enemy.species,
        encounter = self.epoch, turns = self.turnCount, lastTurn = GameSession._copy(self.lastTurn),
        resources = self.session:safariData()}
    self.game.lastSafariBattleSession = self.session
    self.machine:pop()
    return true
end
function SafariBattleState:update()
    if not self:valid() then
        return
    end
    if self.phase == "message" then
        self.dialog:update()
    elseif self.phase == "action" then
        self.frame = self.frame + 1
        if self.animation then
            self.animation:update()
            if self.animation.done then
                self:afterAction()
            end
        elseif self.frame >= (self.command == "run" and 1 or 24) then
            self:afterAction()
        end
    end
end
function SafariBattleState:handleInput()
    if not self:valid() then
        return
    end
    if self.phase == "command" then
        self.menu:handleInput()
    elseif self.phase == "message" then
        self.dialog:handleInput()
    end
end
function SafariBattleState:draw()
    if not self.active then
        return
    end
    self.scene:draw(self.session:safariData(), self.animation,
        self.phase == "action" and self.command or nil, self.frame or 0)
    gfx.pushContext()
    gfx.setDrawOffset(0, 0)
    if self.phase == "command" then
        self.menu:draw(4, 170, 392, 66)
    elseif self.phase == "message" then
        self.dialog:draw()
    end
    gfx.popContext()
end
function SafariBattleState:exit()
    if self.token then
        SafariBattle.cancel(self.token)
    end
    if self.animation then
        self.animation:cancel()
    end
    self.active = false
    self.menu:hide()
    self.dialog.isActive = false
    self.dialog.onComplete, self.continuation = nil, nil
    self.scene, self.enemy, self.session = nil, nil, nil
    gfx.sprite.addDirtyRect(0, 0, 400, 240)
end
function SafariBattleState:getSnapshot()
    return {active = self.active == true, phase = self.active and self.phase or "closed",
        enemy = self.enemy and self.enemy.species or "none", command = self.command or "none",
        outcome = self.battle and self.battle.outcome or "none", balls = self.session and self.session:safariData().balls or 0,
        selected = self.menu.selectedIndex, lastFailure = self.lastFailure,
        encounter = self.epoch or 0, turns = self.turnCount or 0,
        catchRate = self.battle and self.battle.catchRate or nil,
        bait = self.battle and self.battle.bait or nil,
        anger = self.battle and self.battle.anger or nil,
        menu = {active = self.menu.isActive == true, columns = self.menu.columns,
            options = GameSession._copy(self.menu.options or {})},
        lastTurn = self.lastTurn and GameSession._copy(self.lastTurn) or nil}
end
