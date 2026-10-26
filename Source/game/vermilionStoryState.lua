-- The next bespoke layer in the one event-controller chain. All ordinary and
-- earlier scenes retain their executor; no secondary progression/UI owner.
Class("VermilionStoryState"):extends(VermilionGiftsState)
local PENDING <const> = "VERMILION_SCENE_V1_DEPARTURE_PENDING"
local function actor(state, id)
    for _, npc in ipairs(state.game.npcManager.npcs) do
        if npc.def and npc.def.source_event_id == id then
            return npc
        end
    end
end

function VermilionStoryState:enter(id, options)
    self.vermilionActions, self.vermilionIndex = nil, nil
    self.vermilionShip = nil
    VermilionStoryState.super.enter(self, id, options)
end

function VermilionStoryState:sceneQueue(action)
    assert(#self.vermilionActions < 64,"Vermilion scene action limit")
    self.vermilionActions[#self.vermilionActions + 1] = action
end

function VermilionStoryState:sceneText(labels)
    self:sceneQueue(function()
        self:source(labels, function()
            self:advance()
        end)
    end)
end

function VermilionStoryState:scenePath(id, path)
    for _, direction in ipairs(path) do
        local facing <const> = direction
        self:sceneQueue(function()
            self:startNPCMove({id = id, direction = facing})
        end)
    end
end

function VermilionStoryState:scenePlace(id, point, facing)
    self:sceneQueue(function()
        local npc <const> = actor(self, id)
        if not npc then
            self:fail("absent-Vermilion-scene-actor")
            return
        end
        local motion <const> = self.game.npcManager.motion
        local lease, reason = self.npcLeases[id]
        if not lease then
            lease, reason = motion:claimScript(npc, self)
            if not lease then
                self:fail(reason)
                return
            end
            self.npcLeases[id] = lease
        end
        local ok
        if npc.gridX == point.x + VermilionStory.padding(self.zone.stableID) and npc.gridY == point.y then
            ok = motion:faceScript(lease, facing or npc.facing)
            reason = "invalid-source-script-facing"
        else
            ok, reason = motion:placeScript(lease, point.x + VermilionStory.padding(self.zone.stableID), point.y, facing)
        end
        if not ok then
            self:fail(reason)
            return
        end
        self:advance()
    end)
end

function VermilionStoryState:sceneTransaction(plan)
    if not self:valid() or not self:isTop() then
        return false
    end
    local ok, reason = self.session:transact(plan.expected, plan.changes)
    if not ok then
        self:failureDialogue(reason)
        return false
    end
    self.committed = true
    return true
end

function VermilionStoryState:boarding()
    local t <const> = VermilionStory.scenes().boarding
    local x <const> = self.player.gridX - VermilionStory.padding(self.zone.stableID)
    local gate <const> = x == t.x and self.player.gridY == t.y and self.player.facing == t.facing
    local departed <const> = self.session:questFlag("EVENT_SS_ANNE_LEFT")
    local ticket <const> = self.session:inventory():quantity("ssTicket") > 0
    if departed then
        self:sceneText({"_VermilionCitySailor1ShipSetSailText"})
    elseif self.player.facing == "right" or x == 19 and (self.player.gridY == 29 or self.player.gridY == 31) then
        self:sceneText({"_VermilionCitySailor1WelcomeToSSAnneText"})
    else
        self:sceneText({"_VermilionCitySailor1DoYouHaveATicketText",
            ticket and "_VermilionCitySailor1FlashedTicketText" or "_VermilionCitySailor1YouNeedATicketText"})
    end
    if gate and (departed or not ticket) then
        self:sceneQueue(function()
            self:startMove("up")
        end)
    end
end

function VermilionStoryState:captain()
    local prefix <const> = "_SSAnneCaptainsRoomCaptain"
    if self.session:questFlag("EVENT_GOT_HM01") then
        self:sceneText({prefix .. "NotSickAnymoreText"})
        return
    end
    self.plan.failure_labels = {prefix .. "HM01NoRoomText"}
    self:sceneText({"_SSAnneCaptainsRoomRubCaptainsBackText"})
    self:sceneQueue(function()
        if not self.session:questFlag("EVENT_RUBBED_CAPTAINS_BACK") then
            local plan <const> = {
                expected = {flags = {EVENT_RUBBED_CAPTAINS_BACK = false}, items = {}},
                changes = {flags = {EVENT_RUBBED_CAPTAINS_BACK = true}, items = {}},
            }
            if not self:sceneTransaction(plan) then
                return
            end
        end
        self:advance()
    end)
    self:sceneText({prefix .. "IFeelMuchBetterText"})
    self:sceneQueue(function()
        local plan, reason = VermilionStory.captainReward(self.session)
        if not plan then
            self:fail(reason)
            return
        end
        if self:sceneTransaction(plan) then
            self.plan.ram = {wStringBuffer = ItemData.definitions.hm01.name}
            self:source({prefix .. "ReceivedHM01Text"}, function()
                self:advance()
            end)
        end
    end)
end

function VermilionStoryState:rival(departure)
    local id <const> = VermilionStory.RIVAL
    local v <const> = VermilionStory.variant(self.player.gridX - VermilionStory.padding(self.zone.stableID), self.player.gridY)
    if not v then
        self:fail("outside-source-Anne-rival-trigger")
        return
    end
    if departure then
        self:sceneText({"_SSAnne2FRivalDefeatedText","_MoneyForWinningText","_SSAnne2FRivalCutMasterText"})
        self:scenePlace(id, v["end"], v.facing)
        self:scenePath(id, v.departure)
        self:sceneQueue(function()
            self:cancelNPCMove()
            VermilionStory.reconcileActors(self.game)
            self:advance()
        end)
    else
        self:scenePlace(id, v.origin,"down")
        self:scenePath(id, v.approach)
        self:scenePlace(id, v["end"], v.facing)
        self:sceneQueue(function()
            self.player.facing = v.facing == "right" and "left" or "up"
            self.player:updateSprite()
            self:cancelNPCMove() -- TrainerEvents exclusively leases the battle actor.
            self:startTrainer({op = "trainer", id = id, mode = "talk", before = {"_SSAnne2FRivalText"}})
        end)
    end
end

function VermilionStoryState:trash()
    self:sceneQueue(function()
        if self.session:questFlag("EVENT_2ND_LOCK_OPENED") then
            self:source({"_VermilionGymTrashText"}, function()
                self:advance()
            end)
            return
        end
        local index <const> = assert(SourceEvents.descriptor(self.id).trash_index)
        local ok, label = VermilionStory.commitIntent(self.game,"trash", index)
        if not ok then
            self:fail(label)
            return
        end
        self.committed = true
        self:source({assert(label)}, function()
            self:advance()
        end)
    end)
end

function VermilionStoryState:departure()
    if not self.session:questFlag(PENDING) or not self.session:questFlag("EVENT_GOT_HM01") then
        self:fail("no-actual-post-HM01-ship-exit")
        return
    end
    if not self.session:questFlag("EVENT_SS_ANNE_LEFT") then
        self:sceneQueue(function()
            self.vermilionShip = VermilionShip(self)
            self.phase, self.waiting = "vermilion-departure", "ship-departure"
        end)
        self:sceneQueue(function()
            local presentation <const> = self.vermilionShip
            if not presentation or not presentation:snapshot().complete then
                self:fail("ship-presentation-incomplete")
                return
            end
            local ok, reason = VermilionStory.commitIntent(self.game, "departure")
            if not ok then
                self:fail(reason)
                return
            end
            self.committed = true
            assert(presentation:retainAfterCommit())
            self:advance()
        end)
    end
    -- The importer may advance the arrival off its warp. Walk to the real north
    -- exit, then give traversal to DoorWarp; never assign player/NPC coordinates.
    local distance <const> = self.player.gridY
    if not Party._integer(distance, 0, 3) then
        self:fail("unexpected-source-dock-arrival")
        return
    end
    for _ = 1, distance do
        self:sceneQueue(function()
            self:startMove("up")
        end)
    end
    self:sceneQueue(function()
        local door <const> = self.zone:getDoorAt(self.player.gridX, self.player.gridY)
        if not door then
            self:fail("missing-source-dock-north-exit")
            return
        end
        local step <const> = GameSession._copy(door)
        step.facing = door.preserveFacing and self.player.facing or door.facing
        step.preserveFacing = nil
        self:prepareWarp(step)
    end)
end

function VermilionStoryState:advance()
    if not self.plan or self.plan.scene ~= "vermilion-story" then
        return VermilionStoryState.super.advance(self)
    end
    if not self:valid() or not self:isTop() then
        return
    end
    if not self.vermilionActions then
        self.vermilionActions, self.vermilionIndex = {}, 1
        local script <const> = self.plan.scene_script
        if script == "city-exit" then
            for _ = 1, 2 do
                self:sceneQueue(function()
                    self:startMove("up")
                end)
            end
            self:sceneQueue(function()
                local plan <const> = {
                    expected = {flags = {EVENT_WALKED_PAST_GUARD_AFTER_SS_ANNE_LEFT = false}, items = {}},
                    changes = {flags = {EVENT_WALKED_PAST_GUARD_AFTER_SS_ANNE_LEFT = true}, items = {}},
                }
                if self:sceneTransaction(plan) then
                    self:advance()
                end
            end)
        elseif script == "boarding" then
            self:boarding()
        elseif script == "captain" then
            self:captain()
        elseif script == "rival" or script == "rival-exit" then
            self:rival(script == "rival-exit")
        elseif script == "trash" then
            self:trash()
        elseif script == "departure" then
            self:departure()
        else
            self:fail("unsupported-Vermilion-scene")
            return
        end
    end
    if self.phase == "failed" then
        return
    end
    local action <const> = self.vermilionActions[self.vermilionIndex]
    self.vermilionIndex = self.vermilionIndex + 1
    if action then
        action()
    else
        self:finish()
    end
end

function VermilionStoryState:update()
    if self:valid() and self:isTop() and self.phase == "vermilion-departure" then
        local complete, reason = self.vermilionShip:update()
        if complete then
            self:advance()
        elseif reason then
            self:fail(reason)
        end
        return
    end
    VermilionStoryState.super.update(self)
end

function VermilionStoryState:rollbackSceneLeases()
    for _, lease in pairs(self.npcLeases or {}) do
        self.game.npcManager.motion:releaseScript(lease, true)
    end
    self.npcLeases, self.npcMove = {}, nil
end

function VermilionStoryState:fail(reason)
    if self.plan and self.plan.scene == "vermilion-story" then
        self:rollbackSceneLeases()
    end
    if self.vermilionShip then
        self.vermilionShip:releaseEvent()
    end
    VermilionStoryState.super.fail(self, reason)
end

function VermilionStoryState:exit()
    local scene <const> = self.plan and self.plan.scene == "vermilion-story"
    local reconcile <const> = scene and self.id == VermilionStory.RIVAL and self.session:trainerDefeated(self.id)
    if scene and self.phase ~= "complete" then
        self:rollbackSceneLeases()
    end
    self.vermilionActions, self.vermilionIndex = nil, nil
    if self.vermilionShip then
        self.vermilionShip:releaseEvent()
        self.vermilionShip = nil
    end
    VermilionStoryState.super.exit(self)
    if reconcile and self.game.session == self.session and currentZone == self.zone then
        VermilionStory.reconcileActors(self.game)
    end
end
