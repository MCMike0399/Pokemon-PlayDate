-- Import after ceruleanStory when composing both candidates. All non-route
-- scenes retain that executor; route scenes reuse EventState's guarded UI,
-- trainer handoff and NPCMotion leases.
Class("CeruleanRoutesState"):extends(CeruleanEventState or EventState)
local function actor(state, id)
    for _, npc in ipairs(state.game.npcManager.npcs) do
        if npc.def and npc.def.source_event_id == id then return npc end
    end
end
local function padding(state)
    return SourceMaps.entry(assert(SourceMaps.nameForID(state.zone.stableID))).padding
end
local function endpoint(variant)
    local x, y = variant.origin.x, variant.origin.y
    local vectors = {up={0,-1}, down={0,1}, left={-1,0}, right={1,0}}
    for _, direction in ipairs(variant.approach) do
        x, y = x + vectors[direction][1], y + vectors[direction][2]
    end
    return x, y
end
function CeruleanRoutesState:routeQueue(action)
    assert(#self.routeActions < 64, "route scene action limit")
    self.routeActions[#self.routeActions+1] = action
end
function CeruleanRoutesState:routeText(labels)
    self:routeQueue(function() self:source(labels,function() self:advance() end) end)
end
function CeruleanRoutesState:routePath(directions)
    for _, direction in ipairs(directions) do
        local facing = direction
        self:routeQueue(function() self:startNPCMove({id=self.id,direction=facing}) end)
    end
end
function CeruleanRoutesState:routePlace(x, y, facing)
    self:routeQueue(function()
        local npc = actor(self,self.id)
        if not npc then self:fail("absent-source-rival"); return end
        local motion = self.game.npcManager.motion
        local token = self.npcLeases[self.id]
        local reason
        if not token then
            token, reason = motion:claimScript(npc,self)
            if not token then self:fail(reason); return end
            self.npcLeases[self.id] = token
        end
        local ok
        ok, reason = motion:placeScript(token,x+padding(self),y,facing)
        if not ok then self:fail(reason); return end
        self:advance()
    end)
end
function CeruleanRoutesState:routeBattle(before)
    self:routeQueue(function()
        -- The scene and TrainerEvents must never hold competing actor leases.
        self:cancelNPCMove()
        self:startTrainer({op="trainer",id=self.id,mode="talk",before=before})
    end)
end
function CeruleanRoutesState:prepareRoute()
    local scenes = CeruleanRoutes.scenes()
    local script = self.plan.scene_script
    if script == "nugget" then
        self:routeText({"_Route24CooltrainerM1YouBeatOurContestText", "_Route24CooltrainerM1YouJustEarnedAPrizeText"})
        self:routeQueue(function()
            local plan, reason = CeruleanRoutes.nuggetPlan(self.session)
            if not plan then self:fail(reason); return end
            local ok
            ok, reason = self.session:transact(plan.expected,plan.changes)
            if not ok then
                if reason ~= "bag-full" then self:fail(reason); return end
                self:source({"_Route24CooltrainerM1NoRoomText"},function()
                    -- The source backs the player away from the automatic
                    -- trigger after a full bag, so exploration can resume.
                    local point = scenes.triggers.nugget[1]
                    self.routeActions = {}
                    self.routeIndex = 1
                    if self.player.gridX-padding(self) == point.x and self.player.gridY == point.y then
                        self:routeQueue(function() self:startMove("down") end)
                    end
                    self:advance()
                end)
                return
            end
            self.committed = true
            self.plan.ram = {wStringBuffer=ItemData.definitions.nugget.name}
            self:source({"_Route24CooltrainerM1ReceivedNuggetText"},function() self:advance() end)
        end)
        self:routeBattle({"_Route24CooltrainerM1JoinTeamRocketText"})
        return
    end
    local departure = script == "route22-exit" or script == "cerulean-exit"
    local key = (script == "route22" or script == "route22-exit") and "route22" or "cerulean"
    local scene = scenes.rivals[key]
    local variant
    for index, point in ipairs(scenes.triggers[key]) do
        if self.player.gridX-padding(self) == point.x and self.player.gridY == point.y then
            variant = scene.variants[index]
            break
        end
    end
    if not variant then self:fail("outside-source-rival-trigger"); return end
    local x, y = endpoint(variant)
    local facing = key == "cerulean" and "down" or self.player.gridY < y and "up" or "right"
    if departure then
        -- Entry already claimed the exact confirmed receipt. No diagnostic or
        -- planner may consume it, and Continue never recreates a payout.
        self:routeText({key == "route22" and "_Route22Rival1DefeatedText" or "_CeruleanCityRivalDefeatedText"})
        self:routeText({"_MoneyForWinningText"})
        self:routeText({key == "route22" and "_Route22RivalAfterBattleText1" or "_CeruleanCityRivalIWentToBillsText"})
        self:routePlace(x,y,facing)
        self:routePath(variant.departure)
        self:routeQueue(function()
            self:cancelNPCMove()
            local npc = actor(self,self.id)
            if npc then self.game.npcManager:removeNPC(npc) end
            self:advance()
        end)
    else
        self:routePlace(variant.origin.x,variant.origin.y)
        if key == "route22" then
            self:routeQueue(function()
                local npc = assert(actor(self,self.id))
                self.trainerBubble = playdate.graphics.sprite.new(PewterSprites.exclamation())
                self.trainerBubble:setCenter(0,0)
                self.trainerBubble:moveTo(npc.x,npc.y-32)
                self.trainerBubble:setZIndex(110)
                self.trainerBubble:add()
                self.routeNoticeTicks = 0
                self.phase, self.waiting = "route-notice",self.id
            end)
        end
        self:routePath(variant.approach)
        self:routePlace(x,y,facing)
        self:routeQueue(function()
            self.player.facing = key == "cerulean" and "up" or self.player.gridY < y and "down" or "left"
            self.player:updateSprite()
            self:advance()
        end)
        self:routeBattle({key == "route22" and "_Route22RivalBeforeBattleText1" or "_CeruleanCityRivalPreBattleText"})
    end
end
function CeruleanRoutesState:advance()
    if not self.plan or self.plan.scene ~= "cerulean-routes" then
        return CeruleanRoutesState.super.advance(self)
    end
    if not self:valid() or not self:isTop() then return end
    if not self.routeActions then
        self.routeActions, self.routeIndex = {},1
        self:prepareRoute()
    end
    if self.phase == "failed" then return end
    local action = self.routeActions[self.routeIndex]
    self.routeIndex = self.routeIndex + 1
    if action then action() else self:finish() end
end
function CeruleanRoutesState:update()
    if self:valid() and self:isTop() and self.phase == "route-notice" then
        self.routeNoticeTicks = self.routeNoticeTicks + 1
        if self.routeNoticeTicks >= 30 then
            self:removeTrainerBubble()
            self:advance()
        end
        return
    end
    CeruleanRoutesState.super.update(self)
end
function CeruleanRoutesState:fail(reason)
    if self.plan and self.plan.scene == "cerulean-routes" then
        for _, token in pairs(self.npcLeases or {}) do
            self.game.npcManager.motion:releaseScript(token,true)
        end
        self.npcLeases = {}
    end
    CeruleanRoutesState.super.fail(self,reason)
end
function CeruleanRoutesState:exit()
    local route = self.plan and self.plan.scene == "cerulean-routes"
    if route and self.phase ~= "complete" then
        for _, token in pairs(self.npcLeases or {}) do
            self.game.npcManager.motion:releaseScript(token,true)
        end
        self.npcLeases = {}
    end
    local reconcile = self.id == CeruleanRoutes.THIEF and self.committed
    self.routeActions, self.routeIndex, self.routeNoticeTicks = nil,nil,nil
    CeruleanRoutesState.super.exit(self)
    if reconcile then CeruleanRoutes.reconcileActors(self.game) end
end
