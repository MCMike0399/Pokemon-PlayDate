-- Scripted source passage. Player owns each interpolated cell; SafariPassage
-- retains the old runtime until the source path and final session commit succeed.
Class("SafariPassageState"):extends(State)
local gfx <const> = playdate.graphics
function SafariPassageState:init(game)
    SafariPassageState.super.init(self, "safariPassage")
    self.game = game
    self.dialog = Dialog()
end
function SafariPassageState.open(game, token)
    if not game.machine:get("safariPassage") or game.machine:getCurrent() ~= "overworld"
        or not SafariPassage.valid(token) then
        SafariPassage.cancel(token)
        return false, "safari-passage-boundary"
    end
    game.machine:push("safariPassage", token)
    return true
end
function SafariPassageState:enter(token)
    self.active, self.token, self.done = true, token, false
    self.plan = assert(SafariPassage.preview(token))
    self.phase, self.index, self.clock, self.moving = "before", 1, 0, false
    self.lastFailure = nil
    if self.plan.kind == "forced-return" then
        local state = self.game.session:safariData()
        self.phase = "announcement"
        self.dialog:show(state.ending == "steps" and {"Ding-dong! Time's up!", "Your SAFARI GAME is over!"}
            or {"Your SAFARI GAME is over!"}, function() self.phase = "before" end)
    else
        self:walk(self.plan.before)
    end
end
function SafariPassageState:fail(reason)
    self.lastFailure = tostring(reason)
    SafariPassage.cancel(self.token)
    self.phase = "failed"
    self.dialog:show({"The passage failed. Your adventure is unchanged."}, function() self.machine:pop() end)
end
function SafariPassageState:walk(steps)
    if self.moving then
        local player = self.game.player
        local called, reason = pcall(player.update, player)
        if not called then
            self:fail(reason)
            return
        end
        if not player.isMoving then
            if not player.stepJustFinished then
                self:fail("Safari Player cell did not finish")
                return
            end
            SafariPassage.completedStep(self.token)
            self.moving = false
            self.index = self.index + 1
            self:walk(steps)
        end
        return
    end
    local direction = steps[self.index]
    if not direction then
        if self.phase == "before" then
            self.phase, self.clock, self.index = "fade", 0, 1
        else
            self:commit()
        end
        return
    end
    local player = self.game.player
    local y = player.gridY + (direction == "up" and -1 or 1)
    local called, reason = pcall(function()
        SafariPassage.beginCell(self.token, direction, self)
        player:tryMove(0, direction == "up" and -1 or 1, self.token)
        assert(player.isMoving and not player.isJumping and player.gridY == y, "Player rejected source Safari cell")
    end)
    if not called then
        self:fail(reason)
        return
    end
    self.moving = true
end
function SafariPassageState:commit()
    local accepted, reason = self.game.session:commitSafariPassage(self.token)
    if not accepted then
        self:fail(reason)
        return
    end
    self.done = true
    SafariPassage.finish(self.token)
    self.game.lastSafariPassage = {kind = self.plan.kind, ok = true}
    self.game.lastSafariPassageSession = self.game.session
    self.machine:pop()
end
function SafariPassageState:update()
    if not self.active or not self:isTop() then
        return
    end
    if self.phase == "failed" then
        self.dialog:update()
        return
    end
    if not SafariPassage.valid(self.token) then
        self:fail("stale Safari passage")
        return
    end
    if self.phase == "announcement" then
        self.dialog:update()
    elseif self.phase == "before" then
        self:walk(self.plan.before)
    elseif self.phase == "fade" then
        self.clock = self.clock + 1
        if self.clock >= 12 then
            local accepted, reason = SafariPassage.stage(self.token)
            if not accepted then
                self:fail(reason)
                return
            end
            self.phase, self.index = "after", 1
            self:walk(self.plan.after)
        end
    elseif self.phase == "after" then
        self:walk(self.plan.after)
    end
    if self.active then
        local px, py = self.game.player:getPixelCenter()
        local width, height = getMapPixelSize()
        self.game.camera:follow(px, py, width, height)
        self.game.camera:apply()
    end
end
function SafariPassageState:handleInput()
    if self.phase == "announcement" or self.phase == "failed" then
        self.dialog:handleInput()
    end
end
function SafariPassageState:draw()
    gfx.pushContext()
    gfx.setDrawOffset(0, 0)
    if self.phase == "fade" then
        Shade.set(self.clock < 4 and Shade.LIGHT or self.clock < 8 and Shade.DARK or Shade.BLACK)
        gfx.fillRect(0, 0, 400, 240)
        Shade.reset()
    elseif self.phase == "announcement" or self.phase == "failed" then
        self.dialog:draw()
    end
    gfx.popContext()
end
function SafariPassageState:exit()
    if self.token and not self.done then
        SafariPassage.cancel(self.token)
    end
    self.active = false
    self.dialog.isActive = false
    self.dialog.onComplete = nil
    self.token = nil
    gfx.sprite.addDirtyRect(0, 0, 400, 240)
end
function SafariPassageState:getSnapshot()
    return {active = self.active == true, phase = self.active and self.phase or "closed",
        kind = self.plan and self.plan.kind or "none", stepIndex = self.index or 0, lastFailure = self.lastFailure}
end
