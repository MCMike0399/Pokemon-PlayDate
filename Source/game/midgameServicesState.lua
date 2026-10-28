-- Root registers this ONE event executor in place of NPCTradeState. Every
-- existing source program/handler keeps the inherited dispatcher and ownership.
Class("MidgameServicesState"):extends(NPCTradeState)

function MidgameServicesState:enter(id, options)
    self.serviceStarted = false
    self.serviceContinuation = nil
    MidgameServicesState.super.enter(self, id, options)
end
function MidgameServicesState:serviceChoice(callback)
    self.phase, self.waiting = "service-choice", self.plan.service
    local selected = self:guard(function(index)
        self.menu:hide()
        self.menu.onSelect, self.menu.onCancel = nil, nil
        callback(index == 1)
    end)
    self.menu:show({"YES", "NO"}, selected, function() selected(2) end)
end
function MidgameServicesState:advance()
    if self.plan.scene ~= "midgame-service" then
        return MidgameServicesState.super.advance(self)
    end
    if not self:valid() or not self:isTop() then
        return
    end
    if self.serviceContinuation then
        local continuation = self.serviceContinuation
        self.serviceContinuation = nil
        continuation()
        return
    end
    if self.serviceStarted then
        return
    end
    self.serviceStarted = true
    local service = self.plan.service
    if service == "warden-question" then
        local prefix = "_WardensHouseWarden"
        self:source({prefix .. "Gibberish1Text"}, function()
            self:serviceChoice(function(yes)
                self:source({prefix .. (yes and "Gibberish2Text" or "Gibberish3Text")}, function() self:finish() end)
            end)
        end)
    elseif service == "safari-information" then
        local prefix = "_SafariZoneGateSafariZoneWorker2"
        self:source({prefix .. "FirstTimeHereText"}, function()
            self:serviceChoice(function(yes)
                self:source({prefix .. (yes and "SafariZoneExplanationText" or "YoureARegularHereText")},
                    function() self:finish() end)
            end)
        end)
    elseif service == "safari-admission" then
        self:safariAdmission()
    else
        self:fail("midgame-service-not-installed")
    end
end
function MidgameServicesState:safariAdmission()
    if type(self.session.safariData) ~= "function" or type(self.session.commitSafari) ~= "function"
        or type(self.game.prepareSafariPassage) ~= "function" then
        self:fail("safari-owner-or-passage-not-installed")
        return
    end
    local state = self.session:safariData()
    if state.active then
        self:fail("safari-return-controller-required")
        return
    end
    local entry = SourceMaps.entry("SafariZoneGate")
    if self.player.gridX - entry.padding == 3 and self.player.gridY == 2 then
        self:serviceMove("right", function() self:safariAdmission() end)
        return
    end
    self.player.facing = "right"
    self.player:updateSprite()
    local prefix = "_SafariZoneGateSafariZoneWorker1"
    local money, epoch = self.session:inventory():money(), self.session:fieldWorldEpoch()
    self:source({prefix .. "WouldYouLikeToJoinText"}, function()
        self:serviceChoice(function(yes)
            if not yes then
                self:source({prefix .. "PleaseComeAgainText"}, function() self:serviceMove("down", function() self:finish() end) end)
                return
            end
            local plan, reason = SafariGame.admit(state, money)
            if not plan then
                self:source({prefix .. "NotEnoughMoneyText"}, function() self:serviceMove("down", function() self:finish() end) end)
                return
            end
            -- Root preflights the source entrance walk/warp and returns a
            -- guarded fee/counter commit closure and a prepared EventState warp.
            -- No debit precedes the source passage preflight.
            local commit, why = self.game:prepareSafariPassage(self, plan, epoch)
            if not commit then
                self:fail(why)
                return
            end
            local accepted, problem = commit()
            if not accepted then
                self:fail(problem)
                return
            end
            self.committed = true
            self:source({prefix .. "ThatllBe500PleaseText", prefix .. "CallYouOnThePAText"}, function() self:finish() end)
        end)
    end)
end
-- Reuse EventState's movement owner and its completed-cell continuation.
function MidgameServicesState:serviceMove(direction, continuation)
    self.serviceContinuation = continuation
    self:startMove(direction)
end
function MidgameServicesState:handleButton(button)
    if self.phase == "service-choice" and self:valid() and self:isTop() then
        if button == "up" or button == "down" then
            self.menu.selectedIndex = 3 - self.menu.selectedIndex
        elseif button == "a" then
            self.menu.onSelect(self.menu.selectedIndex)
        elseif button == "b" then
            self.menu.onCancel()
        end
        return
    end
    MidgameServicesState.super.handleButton(self, button)
end
function MidgameServicesState:draw()
    MidgameServicesState.super.draw(self)
    if self:valid() and self.phase == "service-choice" then
        playdate.graphics.pushContext()
        playdate.graphics.setDrawOffset(0, 0)
        self.menu:draw(248, 112, 140, 56)
        playdate.graphics.popContext()
    end
end
