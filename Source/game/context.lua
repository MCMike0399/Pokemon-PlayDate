-- Runtime/controller owner. Persistent data lives only in self.session.
Class("GameContext")
local TRANSITION_LOG_MAX <const> = 12
local function startLocation() return {zone_id="reds_house_2f",x=5,y=3,facing="up"} end
local function zoneKey(stableID)
    for key,zone in pairs(zoneRegistry) do if zone.stableID==stableID then return key end end
    local provided=WorldDeltas.zoneKey(stableID)
    if provided then return provided end
    error("unknown stable session zone: "..tostring(stableID))
end
local function newModel(context,seed)
    local session=GameSession.newSession(context:getSessionDependencies(),{location=startLocation(),checkpoint={zone_id="pallet_town",x=5,y=6,facing="down"},seed=seed or 1})
    assert(session:inventory():credit(3000)) -- pinned Blue InitPlayerData START_MONEY.
    -- OakSpeech places one Potion in the item PC, not in the bag. This freshly
    -- constructed model has not been published; loading never calls newModel.
    session:itemStorage():_prepareCommit({version=1,slots={{id="potion",quantity=1}}})()
    return session
end
function GameContext:init(options)
    options=options or {}
    self.sessionLocationPolicy=options.sessionLocationPolicy
    self.machine=StateMachine(); self.camera=Camera(); self.npcManager=NPCManager(self); self.debugMenu=DebugMenu()
    self.fieldWorld=FieldWorld
    self.fieldDarkness=FieldWorld.darknessAdapter()
    self.player=nil; self.transitionLog={}
    -- Inactive: isolated contexts must not seize the live rules stream.
    self.session=newModel(self,options.seed or 1)
    self.machine:on("changed",function(kind,from,to)
        local log=self.transitionLog
        log[#log+1]=kind..":"..tostring(from)..">"..tostring(to)
        if #log>TRANSITION_LOG_MAX then table.remove(log,1) end
    end)
end
function GameContext:getSessionDependencies()
    assert(ItemData and ItemData.definitions,"production item definitions required")
    return {itemDefinitions=ItemData.definitions,validateWorld=WorldDeltas.validate,validateActors=SourceActors.validate,
        resolvePlayerLocation=function(location, world, travel)
            return FieldTravelWorld.resolvePlayerLocation(location, world, self.sessionLocationPolicy, travel)
        end,
        resolveLocation=function(location,world) return WorldDeltas.resolveLocation(location,world,self.sessionLocationPolicy) end}
end
function GameContext:getPlayerPokemon() return self.session:activePokemon() end
function GameContext:recruit(mon) return self.session:recruit(mon) end
function GameContext:recentTransitions() return table.concat(self.transitionLog," ") end
function GameContext:offerLearning(pokemon,onComplete) return LearningState.open(self,pokemon or self:getPlayerPokemon(),onComplete) end
function GameContext:offerPartyProgression(onComplete)
    local session = self.session
    local function advance()
        if self.session ~= session then return end
        for _, mon in ipairs(session:party():members()) do
            if #mon:getPendingMoveChoices() > 0 then
                return self:offerLearning(mon, advance)
            end
        end
        for _,mon in ipairs(session:party():members()) do
            if Evolution.hasPending(mon) then
                local request,reason=Evolution.prepare(session,mon,{kind="level"})
                if not request then return false,reason end
                return EvolutionState.open(self,request,function(result)
                    if result.kind=="failed" then if onComplete then onComplete(result) end;return end
                    advance()
                end)
            end
        end
        if onComplete then onComplete() end
        return false
    end
    return advance()
end
-- Existing afterbattle/Continue owners keep their callback contract.
function GameContext:offerPartyLearning(onComplete) return self:offerPartyProgression(onComplete) end
function GameContext:beginNewSession(seed)
    local ok,candidate=pcall(newModel,self,seed)
    if not ok then return false,tostring(candidate) end
    return self:installSession(candidate)
end
local function settledTraversal(context)
    local world=context.machine:get("overworld")
    local player=context.player
    return world and world.sub and world.sub:getCurrent()=="explore" and player
        and not player.isMoving and not player.pendingEdgeDoor and not player.stepJustFinished
end
local function captureSettledTraversal(context)
    local player=context.player
    local position={zone_id=currentZone.stableID,x=player.gridX,y=player.gridY,facing=player.facing}
    local ok,reason=context.session:captureTraversal({location=position,world=WorldDeltas.export(),actors=context.npcManager.motion:snapshot()})
    if not ok then return nil,reason end
    return SessionCodec.encode(context.session,{root="overworld",overworld="explore",settled=true})
end
function GameContext:captureSession()
    if self.machine:getCurrent()~="overworld" or self.machine:depth()~=1 or not settledTraversal(self) then
        return nil,"save requires settled exploration after step triggers"
    end
    return captureSettledTraversal(self)
end
function GameContext:isPCSaveBoundary(pc,epoch)
    local machine=self.machine
    return type(pc)=="table" and type(pc.is)=="function" and pc:is("PCState")
        and type(epoch)=="number" and epoch%1==0 and epoch>=1 and machine:get("pc")==pc and machine:current()==pc and machine:depth()==2
        and machine.stack[1]==machine:get("overworld") and pc.game==self and pc.active==true
        and pc.epoch==epoch and pc.session==self.session and settledTraversal(self)
        and not self.player.pendingConnection and not self.player.isJumping and true or false
end
function GameContext:captureSessionFromPC(pc,epoch)
    if not self:isPCSaveBoundary(pc,epoch) then return nil,"save requires current settled PC boundary" end
    return captureSettledTraversal(self)
end
function GameContext:installSession(candidate)
    local payload,reason=SessionCodec.encode(candidate,{root="overworld",overworld="explore",settled=true})
    if not payload then return false,reason end
    local valid,problem=SessionCodec.validate(payload,self:getSessionDependencies())
    if not valid then return false,problem end
    local location=candidate:location()
    local located,key=pcall(zoneKey,location.zone_id)
    if not located then return false,tostring(key) end
    if not self.machine:get("overworld") then return false,"overworld state must be registered before install" end
    local previous={session=self.session,zone=currentZone,world=WorldDeltas.export(),rng=RulesRNG.toData(),
        owner=GameSession.activeRNGSession(),story=Story.currentContext(),player=self.player,actors=self.npcManager.motion:snapshot()}
    local undoRuntime=WorldDeltas.checkpointRuntime()
    -- World owner validates/rolls back view rejection before session/RNG change.
    local applied,undoWorld=pcall(WorldDeltas.apply,payload.world)
    if not applied then undoRuntime();return false,tostring(undoWorld) end
    local activated,activationError=candidate:activateRNG()
    if not activated then undoWorld();undoRuntime();return false,activationError end
    self.session=candidate; Story.bind(self)
    local rebuilt,rebuildError=pcall(function()
        switchZone(key)
        self.machine:change("overworld",{entry={x=location.x,y=location.y,facing=location.facing},actors=candidate:actorData()})
    end)
    if rebuilt then return true end
    -- No arbitrary old coroutine resume: root controller can surface failure;
    -- restore durable owners and rebuild a safe previous overworld entry.
    candidate:deactivateRNG()
    if previous.owner then previous.owner:activateRNG() else RulesRNG.restoreData(previous.rng) end
    self.session=previous.session; currentZone=previous.zone; Story.bind(previous.story)
    local restored,restoreError=pcall(function() undoWorld();undoRuntime() end)
    if restored and previous.player then
        pcall(self.machine.change,self.machine,"overworld",{entry={x=previous.player.gridX,y=previous.player.gridY,facing=previous.player.facing},actors=previous.actors})
    end
    return false,tostring(rebuildError)..(restored and "" or "; world rollback failed: "..tostring(restoreError))
end
function GameContext:returnToCheckpoint()
    local position=self.session:checkpoint()
    self:getSessionDependencies().resolveLocation(position,WorldDeltas.export())
    switchZone(zoneKey(position.zone_id))
    self.machine:change("overworld",{entry={x=position.x,y=position.y,facing=position.facing},fieldReloadReason="blackout"})
end
-- Explicit development fixture: replace the single fixture party, preserving
-- starter acquisition history via the authoritative codec, never a loose owner.
function GameContext:resetFixturePokemon(species,level)
    local count=self.session:party():count()
    assert(count<=1,"reset the whole fixture before replacing its player")
    local mon=assert(Specimen.createForSession(self.session,species,level,"debug"))
    if count==0 then return self:recruit(mon) end
    local position = self.player and {zone_id=currentZone.stableID,x=self.player.gridX,y=self.player.gridY,facing=self.player.facing}
        or self.session:location()
    assert(self.session:captureTraversal({location=position,world=WorldDeltas.export()}))
    local original=assert(SessionCodec.encode(self.session,{root="overworld",overworld="explore",settled=true}))
    local detached=assert(SessionCodec.decode(original,self:getSessionDependencies()))
    assert(detached:recruit(mon))
    local data=assert(SessionCodec.encode(detached,{root="overworld",overworld="explore",settled=true}))
    data.party.members={data.party.members[2]}; data.party.active=1
    local candidate=assert(SessionCodec.decode(data,self:getSessionDependencies()))
    return self:installSession(candidate)
end
function GameContext:resetActiveLevelForDebug(level)
    local mon=assert(self:getPlayerPokemon(),"debug level requires a player")
    local replacement=Pokemon(mon.species,level,mon:attributes())
    replacement.name=mon.name
    for key in pairs(mon) do mon[key]=nil end
    for key,value in pairs(replacement) do mon[key]=value end
    return mon
end

-- Prepared field transaction adapter; apply only with source reload ownership.
function GameContext:commitFieldTerrain(before, after, position, actors)
    return FieldMoveWorld.commit(self, before, after, position, actors)
end


function GameContext:fieldTravelRestrictions(position)
    local forced = self.session:questFlag("pokered:status6:BIT_ALWAYS_ON_BIKE")
    local currentTooFast = false
    if position.zone_id == "pokered:SEAFOAM_ISLANDS_B4F" then
        -- Seafoam is outside 5.5. Its source controller must provide the exact
        -- stairs/current predicate when those maps become campaign content.
        error("Seafoam field current controller is not installed", 0)
    end
    return {forcedBicycle = forced, currentTooFast = currentTooFast}
end

function GameContext:commitFieldTravel(expected, plan)
    if self.session:fieldWorldEpoch() ~= expected.epoch
        or not FieldMoves.same(WorldDeltas.export(), expected.world)
        or not FieldMoves.same(FieldTravelRuntime.position(self), expected.position) then
        return false, "stale-field-travel"
    end
    if plan.kind == "strength" then
        return self.session:captureTraversal({world = expected.world, location = expected.position,
            actors = self.npcManager.motion:snapshot(), fieldTravel = plan.travel})
    elseif plan.kind == "surf" then
        local request, reason = FieldTravelRuntime.step(self, true)
        if not request or not FieldMoves.same(request.plan, plan) then
            return false, reason or "changed-surf-target"
        end
        return self.player:beginFieldStep(request)
    elseif plan.kind == "fly" then
        return FieldTravelRuntime.fly(self, expected, plan)
    end
    return false, "unsupported-travel-plan"
end


-- Read-only journey/UI projection. Absence remains explicit; no fixture fields
-- or inferred success receipts are created by observation.
function GameContext:getFieldTravelSnapshot()
    local value = self.session:fieldTravelData()
    local state = self.machine:get("fieldTravel")
    local active = state and state.active and self.machine:current() == state
    local selected = active and state.phase == "destination" and state.choices
        and state.choices[state.menu.selectedIndex]
    local pending = self.player and self.player.fieldStep
    return {
        installed = state ~= nil,
        preparedViewHandoff = type(WorldView.exchangePrepared) == "function",
        mode = value.mode, strength = value.strength, visited = GameSession._copy(value.visited),
        active = active == true, key = active and state.key or "none",
        phase = active and state.phase or "closed", selected = selected and selected.id or "none",
        pendingCell = pending and GameSession._copy(pending.plan.location) or nil,
        last = self.lastFieldTravel and GameSession._copy(self.lastFieldTravel) or nil
    }
end
