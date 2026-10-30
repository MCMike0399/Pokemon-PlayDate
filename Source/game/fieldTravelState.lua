-- Field confirmation, Fly picker and the actor owner's bounded boulder lease.
local gfx <const> = playdate.graphics
Class("FieldTravelState"):extends(State)

function FieldTravelState:init(game)
    FieldTravelState.super.init(self, "fieldTravel")
    self.game = game
    self.menu = BattleMenu()
end

local function failure(reason)
    if reason == "badge-required" then
        return "A new BADGE is required."
    elseif reason == "cannot-fly-here" then
        return "You can't FLY here!"
    elseif reason == "cycling-is-fun" then
        return "Cycling is fun! Forget SURFing!"
    elseif reason == "no-place-to-get-off" then
        return "There's no place to get off!"
    end
    return "That move can't be used here."
end

function FieldTravelState.open(game, party, mon, key)
    if not game.machine:get("fieldTravel") then
        party.message = "That move can't be used here."
        return false, "field-travel-state-not-registered"
    end
    local token, choices, reason
    if key == "fly" then
        choices, reason = FieldTravelRequests.destinations(game, party, mon)
        if choices and #choices == 0 then
            choices, reason = nil, "no-visited-fly-city"
        end
    else
        token, reason = FieldTravelRequests.prepare(game, party, mon, key)
    end
    if not token and not choices then
        party.message = failure(reason)
        return false, reason
    end
    party.phase = "field-wait"
    party.menu:hide()
    game.machine:push("fieldTravel", {party = party, mon = mon, key = key, token = token, choices = choices})
    return true
end

function FieldTravelState.openPush(game, npc, direction)
    local state = game.machine:get("fieldTravel")
    if not state or game.machine:depth() ~= 1 or game.machine:getCurrent() ~= "overworld"
        or not game.session:fieldTravelData().strength or not game.session:questFlag("BADGE_RAINBOW") then
        return false, "strength-required"
    end
    game.machine:push("fieldTravel", {npc = npc, direction = direction, key = "push"})
    return true
end

function FieldTravelState:valid()
    return self.active and self.game.session == self.session and currentZone == self.zone
        and self.game.player == self.player and self.session:fieldWorldEpoch() == self.fieldEpoch
        and (not self.party or self.party.active and self.party.visit == self.partyVisit
            and self.party.view == self.partyView and self.party.session == self.session)
end

function FieldTravelState:enter(options)
    self.epoch = (self.epoch or 0) + 1
    self.active = true
    self.session, self.zone, self.player = self.game.session, currentZone, self.game.player
    self.fieldEpoch = self.session:fieldWorldEpoch()
    self.game.lastFieldTravel = {key = options.key, kind = "pending"}
    self.party, self.mon, self.key, self.token = options.party, options.mon, options.key, options.token
    self.partyVisit = self.party and self.party.visit
    self.partyView = self.party and self.party.view
    self.frame, self.message, self.success, self.failure = 0, nil, false, nil
    self.boulder, self.choices = nil, nil
    if self.key == "push" then
        local motion = self.game.npcManager.motion
        if not motion.beginBoulderPush then
            self.message, self.phase = "That boulder can't move yet.", "result"
            return
        end
        self.boulder, self.failure = motion:beginBoulderPush(options.npc, options.direction, self)
        self.phase = self.boulder and "push" or "result"
        if not self.boulder then
            self.message = failure(self.failure)
        end
    elseif options.choices then
        self.choices = options.choices
        local labels = {}
        for _, entry in ipairs(self.choices) do
            labels[#labels + 1] = entry.source_map:gsub("_", " ")
        end
        labels[#labels + 1] = "CANCEL"
        self.phase = "destination"
        self.menu:show(labels, function(index)
            if not self:valid() or not self:isTop() then
                return
            end
            local entry = self.choices[index]
            if not entry then
                self:close(false)
                return
            end
            local token, reason = FieldTravelRequests.prepare(self.game, self.party, self.mon, "fly", entry.id, self)
            if not token then
                self.message, self.phase = failure(reason), "result"
                self.menu:hide()
                return
            end
            self.token = token
            self:confirm()
        end, function() self:close(false) end)
    else
        self:confirm()
    end
end

function FieldTravelState:confirm()
    self.phase = "confirm"
    self.menu:show({"NO", "YES"}, function(index)
        if not self:valid() or not self:isTop() then
            return
        end
        if index ~= 2 then
            self:close(false)
            return
        end
        self.phase, self.frame = "announce", 0
        self.menu:hide()
    end, function() self:close(false) end)
end

function FieldTravelState:close(success)
    if not self.active or not self:isTop() then
        return
    end
    local party = self.party
    if not success then
        self.game.lastFieldTravel = {key = self.key, kind = self.phase == "result" and "failed" or "cancelled",
            reason = self.failure}
    end
    self.machine:pop()
    if party and self.machine:current() == party and party.active then
        if success then
            self.machine:pop()
        else
            party:actions()
        end
    end
end

function FieldTravelState:exit()
    if self.token then
        FieldTravelRequests.cancel(self.token)
    end
    if self.boulder then
        self.game.npcManager.motion:cancelBoulderPush(self.boulder)
    end
    if self.player and self.player.fieldStep then
        self.player:cancelFieldStep("field-move-cancelled")
    end
    self.active, self.token, self.boulder = false, nil, nil
    self.epoch = (self.epoch or 0) + 1
    self.menu:hide()
    self.menu.onSelect, self.menu.onCancel = nil, nil
    gfx.sprite.addDirtyRect(0, 0, 400, 240)
end

function FieldTravelState:update()
    if not self.active or not self:isTop() then
        return
    end
    if not self:valid() then
        self:close(false)
        return
    end
    if self.phase == "push" then
        local complete, reason = self.game.npcManager.motion:updateBoulderPush(self.boulder)
        if complete then
            self.boulder = nil
            self.game.lastFieldTravel = {key = "strength", kind = "pushed"}
            self:close(true)
        elseif complete == nil then
            self.failure = reason
            self.message, self.phase = failure(reason), "result"
        end
    elseif self.phase == "moving" then
        self.player:updateFieldStep()
        if not self.player.fieldStep then
            local result = self.player.fieldStepResult
            -- Successful settled traversal increments the epoch deliberately.
            self.fieldEpoch = self.session:fieldWorldEpoch()
            if result and result.ok then
                self.game.lastFieldTravel = {key = "surf", kind = "complete", mode = self.session:fieldTravelData().mode}
                self.game.session:daycareStep()
                self:close(true)
            else
                self.message, self.phase = "SURF failed!", "result"
            end
        end
    elseif self.phase == "fade" then
        self.frame = self.frame + 1
        if self.frame >= 12 then
            self:complete()
        end
    end
end

function FieldTravelState:complete()
    local ok, result = FieldTravelRequests.complete(self.token, self)
    if not ok then
        self.failure = result
        self.game.lastFieldTravel = {key = self.key, kind = "failed", reason = result}
        self.message, self.phase = failure(result), "result"
        return
    end
    self.fieldEpoch = self.session:fieldWorldEpoch()
    if self.key == "surf" then
        self.phase = "moving"
    else
        self.game.lastFieldTravel = {key = self.key, kind = "complete",
            position = FieldTravelRuntime.position(self.game)}
        self:close(true)
    end
end

function FieldTravelState:handleInput()
    if not self:isTop() or not self.active then
        return
    end
    if self.phase == "confirm" or self.phase == "destination" then
        self.menu:handleInput()
    elseif playdate.buttonJustPressed(playdate.kButtonB) then
        self:close(false)
    elseif playdate.buttonJustPressed(playdate.kButtonA) then
        if self.phase == "announce" then
            if self.key == "fly" then
                self.phase, self.frame = "fade", 0
            else
                self:complete()
            end
        elseif self.phase == "result" then
            self:close(false)
        end
    end
end

function FieldTravelState:draw()
    gfx.pushContext()
    gfx.setDrawOffset(0, 0)
    if self.phase == "fade" then
        Shade.set(self.frame < 4 and Shade.LIGHT or self.frame < 8 and Shade.DARK or Shade.BLACK)
        gfx.fillRect(0, 0, 400, 240)
        Shade.reset()
    elseif self.phase ~= "moving" and self.phase ~= "push" then
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(4, 174, 392, 62)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawRect(4, 174, 392, 62)
        local message = self.message or (self.phase == "destination" and "FLY to where?"
            or self.phase == "confirm" and "Use " .. self.key:upper() .. "?"
            or self.mon.name .. " used " .. self.key:upper() .. "!")
        gfx.drawText(message, 14, 184)
        if self.phase == "confirm" then
            self.menu:draw(264, 112, 126, 56)
        elseif self.phase == "destination" then
            self.menu:draw(132, 2, 264, 168)
        end
    end
    gfx.popContext()
end
