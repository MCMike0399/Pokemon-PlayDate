-- Runtime/controller owner. Persistent data lives only in self.session.
Class("GameContext")
local TRANSITION_LOG_MAX <const> = 12
local function startLocation() return {zone_id="reds_house_2f",x=5,y=3,facing="up"} end
local function zoneKey(stableID)
    for key,zone in pairs(zoneRegistry) do if zone.stableID==stableID then return key end end
    error("unknown stable session zone: "..tostring(stableID))
end
local function newModel(context,seed)
    local session=GameSession.newSession(context:getSessionDependencies(),{location=startLocation(),checkpoint=startLocation(),seed=seed or 1})
    assert(session:inventory():credit(3000)) -- pinned Blue InitPlayerData START_MONEY.
    return session
end
function GameContext:init(options)
    options=options or {}
    self.sessionLocationPolicy=options.sessionLocationPolicy
    self.machine=StateMachine(); self.camera=Camera(); self.npcManager=NPCManager(self); self.debugMenu=DebugMenu()
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
    return {itemDefinitions=ItemData.definitions,validateWorld=WorldDeltas.validate,
        resolveLocation=function(location,world) return WorldDeltas.resolveLocation(location,world,self.sessionLocationPolicy) end}
end
function GameContext:getPlayerPokemon() return self.session:activePokemon() end
function GameContext:recruit(mon) return self.session:recruit(mon) end
function GameContext:recentTransitions() return table.concat(self.transitionLog," ") end
function GameContext:offerLearning(pokemon,onComplete) return LearningState.open(self,pokemon or self:getPlayerPokemon(),onComplete) end
function GameContext:offerPartyLearning(onComplete)
    local session = self.session
    local function advance()
        if self.session ~= session then return end
        for _, mon in ipairs(session:party():members()) do
            if #mon:getPendingMoveChoices() > 0 then
                return self:offerLearning(mon, advance)
            end
        end
        if onComplete then onComplete() end
        return false
    end
    return advance()
end
function GameContext:beginNewSession(seed)
    local ok,candidate=pcall(newModel,self,seed)
    if not ok then return false,tostring(candidate) end
    return self:installSession(candidate)
end
function GameContext:captureSession()
    local world=self.machine:get("overworld")
    local player=self.player
    if self.machine:getCurrent()~="overworld" or self.machine:depth()~=1 or not world or not world.sub
        or world.sub:getCurrent()~="explore" or not player or player.isMoving or player.pendingEdgeDoor or player.stepJustFinished then
        return nil,"save requires settled exploration after step triggers"
    end
    local position={zone_id=currentZone.stableID,x=player.gridX,y=player.gridY,facing=player.facing}
    local ok,reason=self.session:captureTraversal({location=position,world=WorldDeltas.export()})
    if not ok then return nil,reason end
    return SessionCodec.encode(self.session,{root="overworld",overworld="explore",settled=true})
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
        owner=GameSession.activeRNGSession(),story=Story.currentContext(),player=self.player}
    -- World owner validates/rolls back view rejection before session/RNG change.
    local applied,error=pcall(WorldDeltas.apply,payload.world)
    if not applied then return false,tostring(error) end
    local activated,activationError=candidate:activateRNG()
    if not activated then WorldDeltas.apply(previous.world); return false,activationError end
    self.session=candidate; Story.bind(self); switchZone(key)
    local rebuilt,rebuildError=pcall(self.machine.change,self.machine,"overworld",{entry={x=location.x,y=location.y,facing=location.facing}})
    if rebuilt then return true end
    -- No arbitrary old coroutine resume: root controller can surface failure;
    -- restore durable owners and rebuild a safe previous overworld entry.
    candidate:deactivateRNG()
    if previous.owner then previous.owner:activateRNG() else RulesRNG.restoreData(previous.rng) end
    self.session=previous.session; currentZone=previous.zone; Story.bind(previous.story)
    local restored,restoreError=pcall(WorldDeltas.apply,previous.world)
    if restored and previous.player then
        pcall(self.machine.change,self.machine,"overworld",{entry={x=previous.player.gridX,y=previous.player.gridY,facing=previous.player.facing}})
    end
    return false,tostring(rebuildError)..(restored and "" or "; world rollback failed: "..tostring(restoreError))
end
function GameContext:returnToCheckpoint()
    local position=self.session:checkpoint()
    self:getSessionDependencies().resolveLocation(position,WorldDeltas.export())
    switchZone(zoneKey(position.zone_id))
    self.machine:change("overworld",{entry={x=position.x,y=position.y,facing=position.facing}})
end
-- Explicit development fixture: replace the single fixture party, preserving
-- starter acquisition history via the authoritative codec, never a loose owner.
function GameContext:resetFixturePokemon(species,level)
    local mon=Pokemon(species,level)
    if self.session:party():count()==0 then return self:recruit(mon) end
    assert(self.session:party():count()==1,"reset the whole fixture before replacing its player")
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
    local replacement=Pokemon(mon.species,level)
    for key in pairs(mon) do mon[key]=nil end
    for key,value in pairs(replacement) do mon[key]=value end
    return mon
end
