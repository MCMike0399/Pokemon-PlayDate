-- Bounded earlier-region scenes. Root must explicitly route these IDs here;
-- importing this module does not activate any campaign handler or mutation.
import "game/tutorialEscortData"
import "game/tutorialDemo"
import "game/tutorialEscortPlayer"
TutorialEscort = {}
local gfx <const> = playdate.graphics
local data <const> = TutorialEscortData.get()
local delta <const> = {up={0,-1}, down={0,1}, left={-1,0}, right={1,0}}
function TutorialEscort.has(id)
    for _, actor in pairs(data.actors) do if actor.id == id then return true end end
    return false
end
function TutorialEscort.trigger(game)
    if game.session:getIntro().stage ~= "done" or game.player.isMoving then return nil end
    local p = game.player
    if currentZone.stableID == "pokered:VIRIDIAN_CITY" and not game.session:questFlag(data.tutorial.gate)
        and p.gridX == 19 and p.gridY == 9 then return data.actors.sleepy.id end
    if currentZone.stableID == "pokered:PEWTER_CITY" and not game.session:trainerDefeated(TrainerEvents.BROCK) then
        for _, cell in ipairs(data.escort.triggers) do
            if p.gridX == cell[1] and p.gridY == cell[2] then return data.actors.escort.id end
        end
    end
end
function TutorialEscort.tryInteract(game)
    local x,y = game.player:getFacingTile()
    local npc = game.npcManager:getNPCAt(x,y)
    local id = npc and npc.def and npc.def.source_event_id
    if not id or not TutorialEscort.has(id) then return false end
    if game.player.isMoving or game.player.pendingEdgeDoor then return true end
    npc:faceTowards(game.player.gridX,game.player.gridY)
    return TutorialEscort.dispatch(game,id)
end
function TutorialEscort.dispatch(game, id)
    assert(TutorialEscort.has(id), "unsupported scene event")
    assert(game.machine:getCurrent() == "overworld" and game.machine:get("tutorial-escort"), "explicit scene registration required")
    game.machine:push("tutorial-escort", id)
    return true
end

Class("TutorialEscortState"):extends(EventState)
function TutorialEscortState:init(game)
    TutorialEscortState.super.init(self, game)
    self.name = "tutorial-escort"
end
function TutorialEscortState:pages(labels)
    return EventText.pagesFrom(labels, TutorialEscortData.text)
end
function TutorialEscortState:enter(id)
    assert(TutorialEscort.has(id) and not self.active, "unique supported scene entry required")
    assert(self.game.session:getIntro().stage == "done" and not self.game.player.isMoving, "settled post-intro entry required")
    assert(currentZone.stableID == "pokered:" .. id:match("^pokered:([^:]+):"), "scene belongs to another map")
    self.epoch = self.epoch + 1
    self.serial, self.active = 0, true
    self.id, self.session, self.player, self.zone = id, self.game.session, self.game.player, currentZone
    self.npcLeases, self.books = {}, {}
    self.phase, self.waiting = "starting", "none"
    self.demo, self.actor, self.token, self.playerRoute, self.npcRoute = nil, nil, nil, nil, nil
    self.moveOrigin, self.npcMoving, self.playerMoving = nil, false, false
    self.initialPlayer, self.completed = TutorialEscortPlayer.capture(self.player), false
    self.blockedTicks, self.returning, self.hidden = 0, false, false
    self.menu:hide()
    local pokedex = self.session:questFlag(data.tutorial.gate)
    if id == data.actors.girl.id then
        self:source({pokedex and "_ViridianCityGirlWhenIGoShopText" or "_ViridianCityGirlHasntHadHisCoffeeYetText"}, function() self:finish() end)
    elseif id == data.actors.sleepy.id then
        if pokedex then self:finish(); return end
        self:source({"_ViridianCityOldManSleepyPrivatePropertyText"}, function()
            self.playerRoute, self.playerIndex = {"down"}, 1
            self.phase = "sleepy-step"
        end)
    elseif id == data.actors.oldman.id then
        if not pokedex then self:finish(); return end
        self:source({"_ViridianCityOldManHadMyCoffeeNowText"}, function() self:chooseHurry() end)
    else
        if self.session:trainerDefeated(TrainerEvents.BROCK) then self:finish(); return end
        local key = self.player.gridX .. "," .. self.player.gridY
        local route = data.escort.player_routes[key]
        if not route then self:fail("unsupported-source-escort-entry"); return end
        self.playerRoute, self.playerIndex = route, 1
        self.npcRoute, self.npcIndex = data.escort.npc_route, 1
        for _, npc in ipairs(self.game.npcManager.npcs) do
            if npc.def and npc.def.source_event_id == id then self.actor = npc end
        end
        if not self.actor then self:fail("absent-source-escort"); return end
        if self.actor.gridX ~= data.actors.escort.x or self.actor.gridY ~= data.actors.escort.y then
            self:fail("escort-not-at-source-home"); return
        end
        self:source({"_PewterCityYoungsterYoureATrainerFollowMeText"}, function()
            local reason
            self.token, reason = self.game.npcManager.motion:claimScript(self.actor, self)
            if not self.token then self:fail(reason); return end
            self.npcLeases[id] = self.token
            self.phase = "escort-walk"
        end)
    end
end
function TutorialEscortState:chooseHurry()
    self.phase, self.waiting = "hurry-choice", "YES/NO"
    local choose = self:guard(function(index)
        self.menu:hide()
        self.menu.onSelect, self.menu.onCancel = nil, nil
        if index == 1 then
            self:source({"_ViridianCityOldManTimeIsMoneyText"}, function() self:finish() end)
        else
            self:source({"_ViridianCityOldManKnowHowToCatchPokemonText"}, function()
                self.demo = TutorialDemo()
                self.phase = "tutorial-demo"
            end)
        end
    end)
    self.menu:show({"YES", "NO"}, choose, function() choose(2) end)
end
-- Start only through the player's ordinary collision/movement owner. An
-- incomplete player cell is restored by EventState:exit, as in source plans.
function TutorialEscortState:tryPlayerCell(direction)
    if direction == "wait" then return true end
    local d = assert(delta[direction])
    local x, y = self.player.gridX + d[1], self.player.gridY + d[2]
    if not self.zone.collision[y+1] or self.zone.collision[y+1][x+1] ~= 0
        or self.game.npcManager:getNPCAt(x,y) then return false end
    self:startMove(direction)
    if self.phase == "failed" then return false end
    self.playerMoving = true
    return true
end
function TutorialEscortState:tickRoutes()
    local progress = false
    local motion = self.game.npcManager.motion
    if self.npcMoving then
        local done, reason = motion:updateScript(self.token)
        if done then
            self.npcMoving = false
            self.npcIndex = self.npcIndex + 1
            progress = true
        elseif reason ~= "moving" then self:fail(reason); return end
    end
    if not self.npcMoving and self.npcRoute and self.npcRoute[self.npcIndex] then
        local ok, reason = motion:startScriptStep(self.token, self.npcRoute[self.npcIndex])
        if ok then self.npcMoving, progress = true, true
        elseif reason ~= "blocked-scripted-npc-move" then self:fail(reason); return end
    end
    if self.playerMoving then
        self.player:update()
        if not self.player.isMoving then
            self.playerMoving, self.moveOrigin = false, nil
            self.player.stepJustFinished = false
            self.player.pendingEdgeDoor, self.player.pendingConnection = nil, nil
            self.playerIndex = self.playerIndex + 1
            progress = true
        end
    end
    if not self.playerMoving and self.playerRoute and self.playerRoute[self.playerIndex] then
        local phase = self.phase
        -- Both source routes turn right in the same narrow final aisle. Let
        -- the guide clear it first; source scripts bypassed ordinary occupancy.
        local yielding = phase == "escort-walk" and self.playerIndex >= #self.playerRoute - 2
            and self.playerRoute[self.playerIndex] == "right" and self.npcRoute[self.npcIndex] ~= nil
        if not yielding and self:tryPlayerCell(self.playerRoute[self.playerIndex]) then
            if not self.playerMoving then self.playerIndex = self.playerIndex + 1 end
            progress = true
        end
        if self.phase == "failed" then return end
        self.phase = phase
    end
    if self.hidden then self.actor:setVisible(false) end
    self.blockedTicks = progress and 0 or self.blockedTicks + 1
    if self.blockedTicks >= 16 and not self.playerMoving and not self.npcMoving then
        self.retryPhase, self.phase = self.phase, "blocked"
    end
    local playerDone = not self.playerMoving and (not self.playerRoute or not self.playerRoute[self.playerIndex])
    local npcDone = not self.npcMoving and (not self.npcRoute or not self.npcRoute[self.npcIndex])
    if not playerDone or not npcDone then return end
    if self.phase == "sleepy-step" then self:finish()
    elseif self.phase == "escort-walk" then
        assert(self.player.gridX == data.escort.player_end[1] and self.player.gridY == data.escort.player_end[2], "source player route endpoint differs")
        assert(self.actor.gridX == data.escort.npc_end[1] and self.actor.gridY == data.escort.npc_end[2], "source escort route endpoint differs")
        assert(motion:faceScript(self.token, "left"), "source facing lease rejected")
        self:source({"_PewterCityYoungsterGoTakeOnBrockText"}, function()
            self.playerRoute = nil
            self.npcRoute, self.npcIndex = data.escort.departure, 1
            self.phase = "escort-depart"
        end)
    elseif self.phase == "escort-depart" then
        -- Pinned source hides, restores the saved pose, then shows the actor.
        -- The owner validates restoration; no scene writes NPC coordinates.
        self.hidden = true
        self.actor:setVisible(false)
        if motion:resetScript(self.token) then self:finish()
        else self.retryPhase, self.phase = "escort-reset", "blocked" end
    elseif self.phase == "escort-reset" then
        if motion:resetScript(self.token) then self:finish()
        else self.retryPhase, self.phase = "escort-reset", "blocked" end
    end
end
function TutorialEscortState:update()
    if not self.active then return end
    if not self:valid() then
        if self:isTop() then self.machine:pop() end
        return
    end
    if not self:isTop() then return end
    if self.phase == "tutorial-demo" then self.demo:update()
    elseif self.phase == "escort-walk" or self.phase == "escort-depart" or self.phase == "escort-reset" or self.phase == "sleepy-step" then
        self:tickRoutes()
    end
    if self.game.camera then
        local x,y = self.player:getPixelCenter()
        local w,h = getMapPixelSize()
        self.game.camera:follow(x,y,w,h)
        self.game.camera:apply()
    end
end
function TutorialEscortState:handleButton(button)
    if not self:valid() or not self:isTop() then return end
    if self.phase == "hurry-choice" then
        if button == "up" or button == "down" then self.menu.selectedIndex = 3-self.menu.selectedIndex
        elseif button == "a" then self.menu.onSelect(self.menu.selectedIndex)
        elseif button == "b" then self.menu.onCancel() end
    elseif self.phase == "tutorial-demo" and button == "a" and self.demo.phase == "caught" then
        self.demo:close()
        self:source({"_ViridianCityOldManYouNeedToWeakenTheTargetText"}, function() self:finish() end)
    elseif self.phase == "blocked" and button == "a" then
        self.phase, self.blockedTicks = self.retryPhase, 0
    elseif button == "b" or self.phase == "failed" and button == "a" then self:cancel() end
end
function TutorialEscortState:finish()
    if not self:valid() or not self:isTop() then return end
    self.completed = true
    TutorialEscortState.super.finish(self)
end
function TutorialEscortState:cancel()
    if not self:valid() or not self:isTop() then return end
    self.machine:pop()
end
function TutorialEscortState:exit()
    if not self.completed and self:valid() then
        TutorialEscortPlayer.restore(self.player, self.initialPlayer)
        self.moveOrigin = nil
        if self.token then self.game.npcManager.motion:resetScript(self.token) end
    end
    if self.demo then self.demo:close() end
    if self.actor then self.actor:setVisible(true) end
    TutorialEscortState.super.exit(self)
end
function TutorialEscortState:draw()
    if not self:valid() then return end
    if self.phase == "tutorial-demo" then self.demo:draw(); return end
    EventState.redrawSprites()
    if self.phase ~= "hurry-choice" and self.phase ~= "blocked" and self.phase ~= "failed" then return end
    gfx.pushContext()
    gfx.setDrawOffset(0,0)
    gfx.clearClipRect()
    gfx.setFont(gfx.getSystemFont())
    if self.phase == "hurry-choice" then self.menu:draw(244,120,140,56)
    else
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(4,180,392,56)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawRect(4,180,392,56)
        gfx.drawText("The path is blocked.\nA: Retry   B: Back",16,188)
    end
    gfx.popContext()
end
function TutorialEscortState:getSnapshot()
    return {id=self.id, phase=self.phase, playerIndex=self.playerIndex, npcIndex=self.npcIndex,
        demo=self.demo and self.demo.phase, scriptedDemo=self.demo ~= nil, hidden=self.hidden,
        blockedTicks=self.blockedTicks, epoch=self.epoch}
end
