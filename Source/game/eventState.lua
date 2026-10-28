-- Finite executor for shared source plans and the bespoke authored Oak scene.
-- Session owns durable state; Event owns only these temporary callbacks/actors.
local gfx <const> = playdate.graphics
Class("EventState"):extends(State)
local DELTA={up={0,-1},down={0,1},left={-1,0},right={1,0}}
-- SDK Lua has no draw-only sprite entry point. Suppress every update callback
-- for this dirty redraw, then restore exact enable flags even if drawing fails.
function EventState.redrawSprites()
    local states={}
    for _,sprite in ipairs(gfx.sprite.getAllSprites()) do
        local enabled=sprite:updatesEnabled();states[#states+1]={sprite=sprite,enabled=enabled}
        if enabled then sprite:setUpdatesEnabled(false) end
    end
    local ok,problem=pcall(gfx.sprite.update)
    for _,state in ipairs(states) do state.sprite:setUpdatesEnabled(state.enabled) end
    assert(ok,problem)
end
function EventState.observe(game,id,options)
    local bag=game.session:inventory();local items,canAdd={},{}
    for _,id in ipairs(SourceEvents.itemIDs()) do
        items[id]=bag:quantity(id)
        local candidate=assert(Inventory.fromData(ItemData.definitions,bag:toData()))
        canAdd[id]=candidate:add(id,1)==true
    end
    return {intro=game.session:getIntro().stage,flags=game.session:flags().quest,trainers=game.session:flags().trainers,items=items,can_add=canAdd,
        mode=options and options.mode or "talk"}
end
function EventState:init(game)
    EventState.super.init(self,"event");self.game=game;self.menu=BattleMenu()
    self.epoch,self.serial=0,0;self.phase,self.waiting="closed","none"
end
function EventState:valid()
    return self.active and self.game.session==self.session and self.game.player==self.player and currentZone==self.zone
end
function EventState:guard(callback)
    self.serial=self.serial+1;local epoch,serial=self.epoch,self.serial
    return function(...)
        if self:valid() and self:isTop() and self.epoch==epoch and self.serial==serial then
            self.serial=self.serial+1;callback(...)
        end
    end
end
function EventState:dialog(pages,callback,receipt)
    assert(#pages>0 and #pages<=64,"bounded source pages required")
    local lines={};for _,page in ipairs(pages) do lines[#lines+1]=page.text end
    self.phase,self.waiting=receipt and "receipt" or "dialog",pages[1].label
    self.machine:push("dialog",lines,self:guard(callback))
end
function EventState:pages(labels)
    return SourceEvents.pages(self.id,labels,self.plan.ram)
end
function EventState:source(labels,callback) self:dialog(self:pages(labels),callback) end
function EventState:_queueDialog(labels)
    local pages={}
    for _,page in ipairs(self:pages(labels)) do
        if page.receipt then self.receipts[#self.receipts+1]=page else pages[#pages+1]=page end
    end
    if #pages>0 then self.ops[#self.ops+1]={op="pages",pages=pages} end
end
function EventState:enter(id,options)
    assert(type(id)=="string" and SourceEvents.has(id),"supported source event required")
    local descriptor=SourceEvents.descriptor(id)
    local content=descriptor.content
    local extended=content~="viridian"
    assert(options==nil or type(options)=="table" and (options.mode==nil or options.mode=="talk" or options.mode=="sight"),"bounded source event options required")
    self.content=content
    if extended then assert(currentZone.stableID=="pokered:"..id:match("^pokered:([^:]+):"),"source event belongs to another map") end
    assert(self.game.player and not self.game.player.isMoving,"event requires settled player")
    local observation=EventState.observe(self.game,id,options)
    -- Receipt ownership changes only on this explicit controller entry, never
    -- during diagnostics, previews or repeated read-only observations.
    if extended and self.game.trainers then observation.receipt=self.game.trainers:takeReceipt(id) end
    if extended and FieldBattle.takeSourceReceipt then
        observation.source_receipt = FieldBattle.takeSourceReceipt(self.game, id)
    end
    local plan=SourceEvents.plan(id,observation)
    assert(type(plan.steps)=="table" and #plan.steps<=16,"event step limit")
    self.epoch=self.epoch+1;self.active=true;self.serial=0
    self.id,self.plan,self.session,self.player,self.zone=id,plan,self.game.session,self.game.player,currentZone
    self.phase,self.waiting,self.index,self.committed="running","none",1,false
    self.ops,self.receipts,self.books={},{},{}
    self.npcMove,self.pendingWarp=nil,nil
    self.interactionPose=nil
    self.audioGaps = {}
    -- Interaction facing is transient for STAY actors as well as wanderers.
    -- NPCMotion retains the completed source pose; execution never changes it
    -- merely because the player talked from another side.
    if descriptor.restore_interaction_facing then
        for _, npc in ipairs(self.game.npcManager.npcs) do
            if npc.def and npc.def.source_event_id == id then
                local pose <const> = self.game.npcManager.motion:actor(npc)
                if pose then
                    self.interactionPose = {npc=npc, pose=pose}
                end
                break
            end
        end
    end
    self.npcLeases = {}
    self.hasFailureText=false
    self.menu:hide();self.menu.onSelect,self.menu.onCancel=nil,nil
    if plan.scene=="oak-pokedex" then
        assert(currentZone==zoneRegistry.oaks_lab,"Oak parcel scene requires protected authored lab")
        self.oak=assert(self.game.npcManager:findByName("OAK"),"Oak actor missing")
        self.oldOakFacing=self.oak.facing
        local aisle=self:oakAisle()
        if not aisle then self:fail("blocked-rival-route");return end
        self.aisle=aisle;self:createBooks()
    end
    for index,step in ipairs(plan.steps) do
        if plan.scene=="oak-pokedex" and index==2 then
            self:_queueDialog({"_OaksLabRivalGrampsText"})
            self.ops[#self.ops+1]={op="oak-arrive"}
        end
        SourceEvents.validateStep(step)
        if step.op=="dialog" then
            assert(type(step.labels)=="table","source dialogue labels required")
            for _,label in ipairs(step.labels) do
                if label=="_Route1Youngster1NoRoomText" or label=="_PokemartItemBagFullText" then self.hasFailureText=true end
                local failureLabels = descriptor.reward and descriptor.reward.full or descriptor.full or {}
                for _, failureLabel in ipairs(failureLabels) do
                    if label == failureLabel then self.hasFailureText = true end
                end
                if plan.scene=="oak-pokedex" and label=="_OaksLabRivalLeaveItAllToMeText" then
                    self.ops[#self.ops+1]={op="oak-face-player"}
                end
                self:_queueDialog({label})
            end
        elseif step.op=="confirmed-dialog" then
            assert(extended and observation.receipt and observation.receipt.won and self.session:trainerDefeated(id),"unconfirmed source victory receipt")
            self.ops[#self.ops+1]={op="pages",pages=self:pages(step.labels)}
        elseif step.op=="receipt" then
            assert(plan.expected,"source item receipt requires guarded commit")
            for _,page in ipairs(self:pages(step.labels)) do self.receipts[#self.receipts+1]=page end
        elseif step.op=="trainer" then
            assert(extended and step.id==id and self.game.trainers,"explicit source trainer owner required")
            self.ops[#self.ops+1]=step
        elseif step.op=="face-player" then
            SourceEvents.validateStep(step)
            self.ops[#self.ops+1]=step
        elseif step.op=="move" then
            assert(DELTA[step.direction] and type(step.count)=="number" and step.count%1==0 and step.count>=1 and step.count<=8,"bounded movement required")
            for _=1,step.count do self.ops[#self.ops+1]={op="move",direction=step.direction} end
        elseif step.op=="move-npc" then
            for _=1,step.count do
                self.ops[#self.ops+1]={op="move-npc",id=step.id,direction=step.direction}
            end
        elseif step.op=="warp" then
            assert(index==#plan.steps,"warp must terminate source plan")
            self.ops[#self.ops+1]=step
        elseif step.op=="shop" or step.op=="heal" or step.op=="random-dialog"
            or step.op=="source-audio" or step.op=="show-pokemon" then self.ops[#self.ops+1]=step
        else error("unsupported slice operation: "..tostring(step.op)) end
    end
    if plan.scene=="oak-pokedex" then self.ops[#self.ops+1]={op="oak-depart"} end
    assert(#self.ops<=64,"expanded event step limit")
    self:advance()
end
function EventState:fail(reason)
    self:cancelNPCMove()
    self.pendingWarp=nil
    self.serial=self.serial+1;self.phase,self.waiting="failed",tostring(reason)
    self.menu:hide();self.menu.onSelect,self.menu.onCancel=nil,nil
end
function EventState:finish()
    if not self:valid() or not self:isTop() then return end
    local warp=self.pendingWarp
    self.pendingWarp=nil
    self.phase,self.waiting="complete","none"
    self.machine:pop()
    if warp then self.machine:get("overworld").sub:change("doorWarp",warp) end
end
function EventState:commit()
    if self.plan.expected then
        local ok, reason
        if self.plan.transaction == "source-effects" then
            ok, reason = self.session:transactSourceEffects(self.plan.expected, self.plan.changes)
        else
            ok, reason = self.session:transact(self.plan.expected, self.plan.changes)
        end
        if not ok then self:failureDialogue(reason);return end
        self.committed=true
        SourceEvents.afterCommit(self.game,self.plan)
        self:removeBooks()
        if #self.receipts>0 then self:dialog(self.receipts,function() self:finish() end,true);return end
    elseif self.plan.status=="bag-full" and not self.hasFailureText then self:failureDialogue("bag-full");return end
    -- No receipt text can be displayed without a corresponding commit.
    self:finish()
end
function EventState:failureDialogue(reason)
    self.receipts={}
    self.pendingWarp=nil
    if reason=="bag-full" then
        self:source(self.plan.failure_labels or {"_PokemartItemBagFullText"},function() self:finish() end)
    else self:fail(reason) end
end
function EventState:advance()
    if not self:valid() or not self:isTop() then return end
    local step=self.ops[self.index];self.index=self.index+1
    if not step then self:commit();return end
    if step.op=="pages" then self:dialog(step.pages,function() self:advance() end)
    elseif step.op=="random-dialog" then
        -- Selection belongs to execution, after valid/top guards. Source
        -- hRandomAdd is sampled separately on each interaction, not shared by
        -- these NPCs. Use the persistent world stream, never the rules stream.
        SourceEvents.validateStep(step)
        if not self.interactionPose then
            for _,npc in ipairs(self.game.npcManager.npcs) do
                if npc.def and npc.def.source_event_id==self.id then
                    local pose=self.game.npcManager.motion:actor(npc)
                    if pose then self.interactionPose={npc=npc,pose=pose} end
                    break
                end
            end
        end
        local byte=self.session:worldRandom(0,255)
        for _,choice in ipairs(step.choices) do
            if byte<=choice.max then
                self:source(choice.labels,function() self:advance() end)
                return
            end
        end
    elseif step.op == "source-audio" then
        -- Global audio remains unimplemented. Keep exact source cues/waits for
        -- SourceAudio; do not simulate playback or accept source audio timing.
        self.audioGaps[#self.audioGaps + 1] = step
        self:advance()
    elseif step.op == "show-pokemon" then
        self:showPokemon(step)
    elseif step.op=="face-player" then
        self.player.facing=step.direction
        self.player:updateSprite()
        self:advance()
    elseif step.op=="move" then self:startMove(step.direction)
    elseif step.op=="move-npc" then self:startNPCMove(step)
    elseif step.op=="warp" then self:prepareWarp(step)
    elseif step.op=="trainer" then self:startTrainer(step)
    elseif step.op=="shop" then
        self.phase,self.waiting="shop",step.id
        self.machine:push("shop",{martId=step.id,onComplete=self:guard(function() self:advance() end)})
    elseif step.op=="heal" then self:heal(step)
    elseif step.op=="oak-arrive" then self:startRival(false)
    elseif step.op=="oak-depart" then self:startRival(true)
    elseif step.op=="oak-face-player" then self.rival:faceTowards(self.player.gridX,self.player.gridY);self:advance()
    else error("unhandled bounded event operation") end
end
function EventState:startMove(direction)
    local delta = DELTA[direction]
    local player = self.player
    local x, y = player.gridX + delta[1], player.gridY + delta[2]
    local counterStep = SaffronGuards and SaffronGuards.permitsCounterStep(self, player, delta[1], delta[2])
    if not counterStep and (not self.zone.collision[y + 1] or self.zone.collision[y + 1][x + 1] ~= 0
        or self.game.npcManager:getNPCAt(x, y)) then
        self:fail("blocked-scripted-move")
        return
    end
    self.moveOrigin = {x=player.gridX, y=player.gridY, facing=player.facing, walkToggle=player.walkToggle,
        image=player:getImage(), rustleFrames=player.rustleFrames}
    if counterStep then
        player:stepAcrossSourceCounter(self, delta[1], delta[2])
    else
        player:tryMove(delta[1], delta[2])
    end
    if not player.isMoving or player.isJumping or player.gridX ~= x or player.gridY ~= y then
        self:fail("player-rejected-scripted-move")
        return
    end
    self.phase, self.waiting = "move", direction
end
function EventState:oakAisle()
    for _,x in ipairs({6,5}) do
        local clear=true
        for y=4,9 do
            if self.zone.collision[y+1][x+1]~=0 or self.game.npcManager:getNPCAt(x,y)
                or (self.player.gridX==x and self.player.gridY==y) then clear=false end
        end
        if clear then return x end
    end
end
function EventState:createBooks()
    for _,x in ipairs({2,3}) do
        local sprite=gfx.sprite.new(EventArt.pokedex());sprite:setCenter(0,0);sprite:setZIndex(95)
        sprite:moveTo(x*TILE_SIZE,5*TILE_SIZE-8);sprite:setUpdatesEnabled(false);sprite:add()
        self.books[#self.books+1]=sprite
    end
end
function EventState:removeBooks()
    for _,sprite in ipairs(self.books or {}) do sprite:remove() end;self.books={}
end
function EventState:startRival(depart)
    if not depart then
        assert(not self.game.npcManager:findByName("BLUE"),"unexpected existing lab rival")
        local npc=NPC(self.aisle,9,"BLUE",{},nil,"rival","up")
        npc.def={source_event_id="event:oak-pokedex:rival"};npc:setUpdatesEnabled(false)
        self.game.npcManager:addNPC(npc);self.rival=npc
        self.oak:faceTowards(npc.gridX,npc.gridY)
    end
    if depart then self.rival:setFacing("down") else self.rival:faceTowards(self.oak.gridX,self.oak.gridY) end
    self.rivalFrame,self.rivalDepart=0,depart
    self.rivalStartY,self.rivalEndY=depart and 4 or 9,depart and 9 or 4
    self.phase,self.waiting=depart and "oak-departure" or "oak-arrival","BLUE"
end
function EventState:updateRival()
    local npc=self.rival;self.rivalFrame=self.rivalFrame+1
    local step=(self.rivalFrame-1)//8;local frame=(self.rivalFrame-1)%8+1
    local sign=self.rivalDepart and 1 or -1
    local start=self.rivalStartY+sign*step;local target=start+sign
    if frame==1 then
        if self.zone.collision[target+1][self.aisle+1]~=0
            or (self.player.gridX==self.aisle and self.player.gridY==target) then self:fail("rival-route-became-blocked");return end
        local occupant=self.game.npcManager:getNPCAt(self.aisle,target)
        if occupant and occupant~=npc then self:fail("rival-route-became-blocked");return end
    end
    npc:moveTo(self.aisle*TILE_SIZE,(start+(target-start)*frame/8)*TILE_SIZE-8)
    npc:setImage(frame<=4 and EventArt.walking()[npc.facing] or npc.images[npc.facing])
    if frame==8 then npc.gridY=target end
    if self.rivalFrame>=40 then
        npc:setImage(npc.images[npc.facing])
        if self.rivalDepart then self.game.npcManager:removeNPC(npc);self.rival=nil end
        self:advance()
    end
end
function EventState:heal(step)
    self.healStep=step
    self:source({step.welcome,step.prompt},function()
        self.phase,self.waiting="heal-confirm","choice"
        local selected=self:guard(function(index)
            self.menu:hide();self.menu.onSelect,self.menu.onCancel=nil,nil
            if index==2 then self:source({step.farewell},function() self:advance() end)
            else self:source({step.before},function() self:beginHealing() end) end
        end)
        self.menu:show({"YES","NO"},selected,function() selected(2) end)
    end)
end
function EventState:beginHealing()
    if self.session:party():count()==0 then self:fail("empty-party");return end
    self.healClock,self.healCount=0,self.session:party():count()
    self.healNurse=nil
    for _,npc in ipairs(self.game.npcManager.npcs) do
        if npc.def and npc.def.source_event_id==(self.healStep.nurse_id or "pokered:VIRIDIAN_POKECENTER:objects:1") then self.healNurse=npc end
    end
    if self.healNurse then self.oldNurseFacing=self.healNurse.facing;self.healNurse:setFacing("left") end
    self.phase,self.waiting="heal-animation","healing"
end
function EventState:finishHealing()
    local checkpoint=self.healStep.checkpoint or {zone_id="pokered:VIRIDIAN_CITY",x=23,y=26,facing="down"}
    local ok,reason=self.session:captureTraversal({world=WorldDeltas.export(),
        location={zone_id=self.zone.stableID,x=self.player.gridX,y=self.player.gridY,facing=self.player.facing},checkpoint=checkpoint})
    if not ok then self:fail(reason);return end
    self.session:party():healAll()
    if self.healNurse then self.healNurse:setFacing(self.oldNurseFacing) end
    gfx.sprite.addDirtyRect(0,0,400,240) -- erase transient machine OAM before the following dialogue
    local step=self.healStep
    self:source({step.after,step.farewell},function() self:advance() end)
end
function EventState:update()
    if not self:valid() or not self:isTop() then return end
    if self.phase=="trainer-notice" then
        self.trainerNoticeClock=self.trainerNoticeClock+1
        if self.trainerNoticeClock>=30 then self:removeTrainerBubble();self.phase="trainer-approach" end
    elseif self.phase=="trainer-approach" then
        local done,reason=self.game.trainers:updateApproach(self.trainerToken)
        if done then self:trainerReady() elseif reason~="moving" then self:fail(reason) end
    elseif self.phase=="move-npc" then self:updateNPCMove()
    elseif self.phase=="move" then
        self.player:update()
        if not self.player.isMoving then self.moveOrigin=nil;self.player.stepJustFinished=false;self.player.pendingEdgeDoor=nil;self.player.pendingConnection=nil;self:advance() end
    elseif self.phase=="oak-arrival" or self.phase=="oak-departure" then self:updateRival()
    elseif self.phase=="heal-animation" then
        self.healClock=self.healClock+1
        if self.healClock>=15*self.healCount+56 then self:finishHealing() end
    end
    if self:valid() and self.game.camera then
        local x,y=self.player:getPixelCenter();local w,h=getMapPixelSize()
        self.game.camera:follow(x,y,w,h);self.game.camera:apply()
    end
end
function EventState:handleButton(button)
    if not self:valid() or not self:isTop() then return end
    if self.phase=="heal-confirm" then
        if button=="up" or button=="down" then self.menu.selectedIndex=3-self.menu.selectedIndex
        elseif button=="a" then self.menu.onSelect(self.menu.selectedIndex)
        elseif button=="b" then self.menu.onCancel() end
    elseif self.phase=="failed" and (button=="a" or button=="b") then self:finish() end
end
function EventState:handleInput()
    for _,button in ipairs({"a","b","up","down"}) do
        local key=({a=playdate.kButtonA,b=playdate.kButtonB,up=playdate.kButtonUp,down=playdate.kButtonDown})[button]
        if playdate.buttonJustPressed(key) then self:handleButton(button);return end
    end
end
function EventState:exit()
    self.epoch=self.epoch+1;self.serial=self.serial+1;self.active=false
    self.menu:hide();self.menu.onSelect,self.menu.onCancel=nil,nil
    self:removeTrainerBubble()
    self:cancelNPCMove()
    self.pendingWarp=nil
    if self.trainerToken and not self.trainerLaunching then self.game.trainers:cancel(self.trainerToken) end
    self.trainerToken,self.trainerNPC,self.trainerStep=nil,nil,nil;self.trainerLaunching=false
    if self.rival then self.game.npcManager:removeNPC(self.rival);self.rival=nil end
    self:removeBooks()
    if self.oak then self.oak:setFacing(self.oldOakFacing);self.oak=nil end
    if self.healNurse then self.healNurse:setFacing(self.oldNurseFacing);self.healNurse=nil end
    if self.game.player==self.player and currentZone==self.zone then
        if self.moveOrigin then
            self.player.gridX,self.player.gridY=self.moveOrigin.x,self.moveOrigin.y
            self.player.isMoving=false;self.player.moveFrames=0
            self.player.facing=self.moveOrigin.facing;self.player.walkToggle=self.moveOrigin.walkToggle
            self.player.rustleFrames=self.moveOrigin.rustleFrames
            self.player.startPixelX,self.player.targetPixelX=self.player.gridX*TILE_SIZE,self.player.gridX*TILE_SIZE
            self.player.startPixelY,self.player.targetPixelY=self.player.gridY*TILE_SIZE,self.player.gridY*TILE_SIZE
            if self.player.groundPixelX~=nil then self.player.groundPixelX=self.player.gridX*TILE_SIZE end
            if self.player.groundPixelY~=nil then self.player.groundPixelY=self.player.gridY*TILE_SIZE end
            self.player.isJumping=false;self.player.jumpOffset=0
            if self.player.jumpShadow then self.player.jumpShadow:setVisible(false) end
            self.player:moveTo(self.player.gridX*TILE_SIZE,self.player.gridY*TILE_SIZE);self.player:updateSprite()
            self.player:setImage(self.moveOrigin.image)
        end
        self.player.stepJustFinished=false;self.player.pendingEdgeDoor=nil;self.player.pendingConnection=nil
    end
    self.moveOrigin=nil;self.phase,self.waiting="closed","none"
    self.game.npcManager.motion:finishInteraction(self.id)
    -- STAY actors do not get NPCMotion's wandering interaction token. Restore
    -- only this operation's unchanged logical actor pose, like nurse facing.
    -- A replaced context, removed actor or completed scripted move wins.
    local saved=self.interactionPose
    if saved and self.game.session==self.session and self.game.player==self.player and currentZone==self.zone then
        local pose=self.game.npcManager.motion:actor(saved.npc)
        if pose and pose.id==saved.pose.id and pose.x==saved.pose.x and pose.y==saved.pose.y
            and pose.facing==saved.pose.facing then saved.npc:setFacing(pose.facing) end
    end
    self.interactionPose=nil
    gfx.sprite.addDirtyRect(0,0,400,240)
end
function EventState:getSnapshot()
    local options={};for i,value in ipairs(self.menu.options) do options[i]=value end
    local gaps = {}
    for index, cue in ipairs(self.audioGaps or {}) do
        gaps[index] = GameSession._copy(cue)
    end
    return {id=self.id or "none",phase=self.phase,waiting=self.waiting,
        menu={active=self.menu.isActive,selected=self.menu.selectedIndex,options=options},
        audio_gaps=gaps,
        trainer=self.game.trainers and self.game.trainers:snapshot() or {phase="idle"}}
end
function EventState:draw()
    if not self:valid() then return end
    if self.phase=="heal-animation" then gfx.sprite.addDirtyRect(0,0,400,240) end
    EventState.redrawSprites()
    if self.phase=="heal-animation" then
        HealingComposition.draw(self.zone,self.healCount,self.healClock,self.game.camera)
        return
    end
    if self.phase~="heal-confirm" and self.phase~="heal-animation" and self.phase~="failed" then return end
    gfx.pushContext();gfx.setDrawOffset(0,0);gfx.clearClipRect();gfx.clearStencil();gfx.setFont(gfx.getSystemFont());gfx.setLineWidth(1);gfx.setImageDrawMode(gfx.kDrawModeCopy);gfx.setColor(gfx.kColorWhite)
    if self.phase=="heal-confirm" then self.menu:draw(244,120,140,56)
    elseif self.phase=="failed" then
        gfx.fillRect(4,180,392,56);gfx.setColor(gfx.kColorBlack);gfx.drawRect(4,180,392,56)
        gfx.drawText("The event could not complete.\nA / B: Back",16,188)
    end
    gfx.popContext()
end

function EventState:removeTrainerBubble()
    if self.trainerBubble then self.trainerBubble:remove();self.trainerBubble=nil end
end
function EventState:startTrainer(step)
    local npc
    for _,actor in ipairs(self.game.npcManager.npcs) do if actor.def and actor.def.source_event_id==step.id then npc=actor;break end end
    if not npc then self:fail("absent-source-trainer");return end
    local token,reason=self.game.trainers:prepare(npc,step.mode,self)
    if not token then self:fail(reason);return end
    self.trainerToken,self.trainerNPC,self.trainerStep=token,npc,step;self.trainerLaunching=false
    self.phase,self.waiting="trainer-approach",step.id
    if step.mode=="sight" then
        self.trainerNoticeClock=0
        self.trainerBubble=gfx.sprite.new(PewterSprites.exclamation());self.trainerBubble:setCenter(0,0)
        self.trainerBubble:moveTo(npc.x,npc.y-32);self.trainerBubble:setZIndex(110);self.trainerBubble:add()
        self.phase="trainer-notice"
    else
        local done,problem=self.game.trainers:updateApproach(token)
        if done then self:trainerReady() elseif problem~="moving" then self:fail(problem) end
    end
end
function EventState:trainerReady()
    self:source(self.trainerStep.before,function()
        local party,reason=self.game.trainers:launch(self.trainerToken)
        if not party then self:fail(reason);return end
        self.trainerLaunching=true
        assert(FieldBattle.start(self.game,self.game:getPlayerPokemon(),party:active(),self.trainerNPC,party))
    end)
end

-- Reusable source movement has one pose owner. The bespoke Oak rival scene
-- above remains separate; temporary actors cannot bypass source descriptors.
function EventState:startNPCMove(step)
    local npc
    for _, actor in ipairs(self.game.npcManager.npcs) do
        if actor.def and actor.def.source_event_id == step.id then
            npc = actor
            break
        end
    end
    if not npc then
        self:fail("absent-source-actor")
        return
    end
    local owner = self.game.npcManager.motion
    local token = self.npcLeases[step.id]
    local reason
    if not token then
        token, reason = owner:claimScript(npc, self)
        if not token then
            self:fail(reason)
            return
        end
        self.npcLeases[step.id] = token
    end
    local ok
    ok, reason = owner:startScriptStep(token, step.direction)
    if not ok then
        self:fail(reason)
        return
    end
    self.npcMove = { token = token }
    self.phase, self.waiting = "move-npc", step.id
end

function EventState:updateNPCMove()
    local done, reason = self.game.npcManager.motion:updateScript(self.npcMove.token)
    if done then
        self.npcMove = nil
        self:advance()
    elseif reason ~= "moving" then
        self:fail(reason)
    end
end

function EventState:cancelNPCMove()
    for _, token in pairs(self.npcLeases or {}) do
        self.game.npcManager.motion:releaseScript(token)
    end
    self.npcLeases = {}
    self.npcMove = nil
end

function EventState:prepareWarp(step)
    local target = zoneRegistry[step.to]
    local provider = WorldDeltas.definitionProvider()
    local descriptor = not target and provider and provider:hasKey(step.to) and provider:descriptor(step.to)
    local stableID = target and target.stableID or descriptor and descriptor.id
    if not stableID then
        self:fail("unknown-source-warp")
        return
    end
    local ok = pcall(WorldDeltas.resolveLocation,
        { zone_id = stableID, x = step.toX, y = step.toY, facing = step.facing },
        WorldDeltas.export(), self.game.sessionLocationPolicy)
    if not ok then
        self:fail("blocked-source-warp")
        return
    end
    if target == self.zone then
        if self.game.npcManager:getNPCAt(step.toX, step.toY) then
            self:fail("occupied-source-warp")
            return
        end
    elseif target then
        for _, npc in ipairs(target.npcDefs) do
            if npc.gridX == step.toX and npc.gridY == step.toY and (not npc.appearsIf or npc.appearsIf()) then
                self:fail("occupied-source-warp")
                return
            end
        end
    elseif descriptor then
        -- Unloaded source actor positions come from the provider's immutable
        -- surface, without resolving/registering a Zone during validation.
        local actors = SourceActors.describe(stableID, WorldDeltas.export())
        for _, actor in ipairs(actors and actors.actors or {}) do
            if actor.x == step.toX and actor.y == step.toY and WorldMotionData.visible(actor, self.session:flags()) then
                self:fail("occupied-source-warp")
                return
            end
        end
    end
    -- The existing door transition owns the actual zone switch and fade. Wait
    -- until the guarded transaction and its receipt have both completed.
    self.pendingWarp = step
    self:advance()
end


-- DisplayPokedex marks seen only after the source display returns. This uses
-- the existing encyclopedia renderer and a session transaction, not a Dex copy
-- owned by the event. Its callback has the same stale/cancel guards as dialog.
function EventState:showPokemon(step)
    local species <const> = step.species
    local seen <const> = self.session:pokedex().seen[species] == true
    self.audioGaps[#self.audioGaps + 1] = GameSession._copy(step.audio)
    self.phase, self.waiting = "source-pokedex", species
    self.machine:push("pokedex", {
        sourceSpecies = species,
        onComplete = self:guard(function()
            local ok, reason = self.session:transactSourceEffects(
                {flags={}, seen={[species]=seen}},
                {flags={}, seen={[species]=true}})
            if not ok then
                self:fail(reason)
                return
            end
            self:advance()
        end),
    })
end
