-- Current-map simulation owner. Sprite rendering contains no movement/RNG;
-- GameSession owns the separate durable world stream and captured actor values.
Class("NPCMotion")
local stores=setmetatable({},{__mode="k"})
local dirs={up={0,-1},down={0,1},left={-1,0},right={1,0}}
local function copy(value)return Party._primitive(value)end
function NPCMotion:init(manager)
    stores[self]={manager=manager,actors={},specs={},byNPC=setmetatable({},{__mode="k"}),epoch=0}
end
function NPCMotion:clear()
    local s=stores[self];s.epoch=s.epoch+1
    for _, actor in pairs(s.actors) do
        if actor.spec.role == "boulder" and actor.script then
            actor.script = nil
            self:_pose(actor)
        end
        actor.npc.isMoving = false
    end
    s.actors,s.specs,s.byNPC={},{},setmetatable({},{__mode="k"})
    s.game,s.zone,s.session,s.descriptor,s.pending,s.interaction,s.migration=nil,nil,nil,nil,nil,nil,nil
end
function NPCMotion:_pose(actor)
    local v,npc=actor.value,actor.npc
    npc.gridX,npc.gridY=v.x,v.y;npc.isMoving=v.phase=="moving"
    if v.phase=="moving"then
        local t=v.tick/8;npc.facing=v.facing
        npc:moveTo((v.origin_x+(v.target_x-v.origin_x)*t)*TILE_SIZE,(v.origin_y+(v.target_y-v.origin_y)*t)*TILE_SIZE-8)
        npc:setImage(v.tick>0 and SourceActors.stepImage(actor.spec.sprite_source,v.facing,v.tick,actor.spec.content_profile)or assert(npc.images[v.facing]))
    else npc:moveTo(v.x*TILE_SIZE,v.y*TILE_SIZE-8);npc:setFacing(v.facing)end
end
function NPCMotion:attach(game,zone,payload,reconcile)
    local s=stores[self];local world=WorldDeltas.export();local descriptor=SourceActors.describe(zone.stableID,world,game)
    if not descriptor then self:clear();return end
    local flags=game.session:flags();local location={zone_id=zone.stableID,x=game.player.gridX,y=game.player.gridY,facing=game.player.facing}
    local migration
    if payload and payload.zone_id=="none"then payload,migration=WorldMotionData.legacyInitial(descriptor,location,flags)
    elseif not payload then payload=WorldMotionData.reconcile(nil,descriptor,flags)
    elseif reconcile then payload=WorldMotionData.reconcile(payload,descriptor,flags)end
    payload=WorldMotionData.normalize(payload,descriptor,location,flags)
    local npcs={}
    for _,npc in ipairs(s.manager.npcs)do if npc.def and npc.def.source_event_id then npcs[npc.def.source_event_id]=npc end end
    local preparedSpecs,preparedActors,preparedByNPC={},{},setmetatable({},{__mode="k"})
    for _,spec in ipairs(descriptor.actors)do preparedSpecs[spec.id]=spec end
    for _,value in ipairs(payload.actors)do
        local npc=assert(npcs[value.id],"saved source actor not present after spawn")
        assert(npc.images[value.facing],"missing exact saved actor pose")
        local actor={spec=preparedSpecs[value.id],npc=npc,value=copy(value)}
        preparedActors[value.id]=actor;preparedByNPC[npc]=actor
    end
    self:clear();s.specs,s.actors,s.byNPC=preparedSpecs,preparedActors,preparedByNPC
    s.game,s.zone,s.session,s.descriptor,s.migration=game,zone,game.session,descriptor,migration
    for _,actor in pairs(s.actors)do self:_pose(actor)end
end
function NPCMotion:migration()local value=stores[self].migration;return value and copy(value)or nil end
function NPCMotion:actor(npc)
    local actor=stores[self].byNPC[npc];return actor and copy(actor.value)or nil
end
function NPCMotion:snapshot()
    local s=stores[self]
    if not s.zone then return WorldMotionData.empty()end
    local result={version=1,zone_id=s.zone.stableID,definition_revision=s.descriptor.revision,count=0,actors={}}
    for _,actor in pairs(s.actors)do
        local value=copy(actor.value)
        if not actor.spec.random then
            value=WorldMotionData.initial(actor.spec);value.x,value.y=actor.npc.gridX,actor.npc.gridY;value.facing=actor.npc.facing
            value.origin_x,value.target_x=value.x,value.x;value.origin_y,value.target_y=value.y,value.y
        end
        result.actors[#result.actors+1]=value
    end
    table.sort(result.actors,function(a,b)return a.id<b.id end);result.count=#result.actors;return result
end
function NPCMotion:remove(npc)
    local s=stores[self];local actor=s.byNPC[npc]
    if not actor then return end
    s.actors[actor.value.id],s.byNPC[npc]=nil,nil
    if s.pending and s.pending.id==actor.value.id then s.pending=nil end
    if s.interaction and s.interaction.id==actor.value.id then s.interaction=nil end
end
function NPCMotion:occupantAt(x,y)
    for _,actor in pairs(stores[self].actors)do
        local value=actor.value
        local move = actor.script and actor.script.move
        if move and (move.x==x and move.y==y or move.toX==x and move.toY==y) then return actor.npc end
        if not actor.spec.random then
            if actor.npc.gridX==x and actor.npc.gridY==y then return actor.npc end
        elseif value.x==x and value.y==y or value.phase=="moving"and value.origin_x==x and value.origin_y==y then return actor.npc end
    end
end
local function held(s)
    local g=s.game;local p=g and g.player;local world=g and g.machine:get("overworld")
    return not g or g.session~=s.session or currentZone~=s.zone or not p or g.machine:getCurrent()~="overworld"or g.machine:depth()~=1
        or not world or world.sub:getCurrent()~="explore"or p.pendingEdgeDoor or p.pendingConnection
end
local function visible(s,actor)
    -- Logical viewport derives from grid state, never interpolated draw/camera.
    local p=s.game.player;local x=math.max(0,math.min(s.zone.width*TILE_SIZE-400,p.gridX*TILE_SIZE+16-200))
    local y=math.max(0,math.min(s.zone.height*TILE_SIZE-240,p.gridY*TILE_SIZE+8-120))
    local v=actor.value;local ax,ay=v.x*TILE_SIZE,v.y*TILE_SIZE-8
    return ax+32>x and ax<x+400 and ay+32>y and ay<y+240
end
function NPCMotion:cancelPending()stores[self].pending=nil end
function NPCMotion:requestInteraction(npc,id)
    local s=stores[self];local actor=s.byNPC[npc]
    if not actor or not actor.spec.random then return false end
    assert(actor.value.id==id,"interaction source identity mismatch")
    local player=s.game.player
    if actor.value.phase=="moving"then
        s.pending={id=id,epoch=s.epoch,player_x=player.gridX,player_y=player.gridY,facing=player.facing}
        return true
    end
    s.interaction={id=id,npc=npc,facing=actor.value.facing,epoch=s.epoch}
    npc:faceTowards(player.gridX,player.gridY)
    return false
end
function NPCMotion:finishInteraction(id)
    local s=stores[self];local interaction=s.interaction
    if not interaction or interaction.id~=id then return end
    s.interaction=nil;local actor=s.byNPC[interaction.npc]
    if actor and interaction.epoch==s.epoch and s.game.session==s.session and currentZone==s.zone then
        actor.value.facing=interaction.facing;self:_pose(actor)
    end
end
function NPCMotion:_finishQueued()
    local s=stores[self];local pending=s.pending
    if not pending then return false end
    local actor=s.actors[pending.id];local p=s.game.player
    if not actor or pending.epoch~=s.epoch or p.gridX~=pending.player_x or p.gridY~=pending.player_y or p.facing~=pending.facing then s.pending=nil;return false end
    if actor.value.phase=="moving"then return false end
    s.pending=nil;local fx,fy=p:getFacingTile()
    if fx~=actor.npc.gridX or fy~=actor.npc.gridY then return false end
    self:requestInteraction(actor.npc,pending.id)
    KantoWorld.dispatch(s.game,pending.id);return true
end
function NPCMotion:tick()
    local s=stores[self]
    if not s.zone or held(s)then return false end
    if self:_finishQueued()then return true end
    local ids={};for id in pairs(s.actors)do ids[#ids+1]=id end
    table.sort(ids,function(a,b)return s.specs[a].order==s.specs[b].order and a<b or s.specs[a].order<s.specs[b].order end)
    for _,id in ipairs(ids)do
        local actor=s.actors[id];local v,spec=actor.value,actor.spec
        if spec.random and not actor.script and visible(s,actor)then
            if v.phase=="delay"then
                v.delay_left=v.delay_left-1
                if v.delay_left==0 then v.phase="ready";v.delay_raw=0 end
            elseif v.phase=="ready"and not s.game.player.isMoving then
                local direction=WorldMotionData.direction(spec.selector,s.session:worldRandom(0,255));local d=dirs[direction]
                if spec.faces[direction]then v.facing=direction end
                local tx,ty=v.x+d[1],v.y+d[2];local player=s.game.player
                local occupied=s.manager:getNPCAt(tx,ty)
                local playerBlocked=tx==player.gridX and ty==player.gridY or player.isMoving and tx==player.startPixelX/TILE_SIZE and ty==player.startPixelY/TILE_SIZE
                if spec.movement=="WALK"and not occupied and not playerBlocked and (s.descriptor.canWanderStep or s.descriptor.canStep)(spec,v.x,v.y,tx,ty,s.zone)then
                    v.origin_x,v.origin_y,v.target_x,v.target_y=v.x,v.y,tx,ty;v.x,v.y=tx,ty;v.phase="moving";v.tick=0
                else v.delay_raw=s.session:worldRandom(0,127);v.delay_left=WorldMotionData.delay(v.delay_raw);v.phase="delay"end
                self:_pose(actor)
            end
            if v.phase=="moving"then
                v.tick=v.tick+1
                if v.tick==8 then
                    v.phase="delay";v.tick=0;v.origin_x,v.origin_y,v.target_x,v.target_y=v.x,v.y,v.x,v.y
                    v.delay_raw=s.session:worldRandom(0,127);v.delay_left=WorldMotionData.delay(v.delay_raw)
                end
                self:_pose(actor)
            end
        end
    end
    return false
end

-- Script leases are transient and opaque. Only this owner changes tracked actor
-- poses; the event keeps the token until exit, including intervening dialogue.
local function scriptLease(s, token)
    for _, actor in pairs(s.actors) do
        local lease = actor.script
        if lease and lease.token == token and lease.epoch == s.epoch then return actor, lease end
    end
end
local function scriptCurrent(s, lease)
    local owner = lease.owner
    return s.game.session == s.session and currentZone == s.zone
        and s.game.player == lease.player and owner.epoch == lease.ownerEpoch
        and owner:valid() and owner:isTop()
end
-- Read-only ownership check for a paired player script intent. Do not probe
-- validity by advancing a cell or reapplying a pose.
function NPCMotion:isScriptOwner(token, owner)
    local s = stores[self]
    local actor, lease = scriptLease(s, token)
    return actor ~= nil and lease.owner == owner and scriptCurrent(s, lease) == true
end
function NPCMotion:claimScript(npc, owner)
    local s = stores[self]
    local actor = s.byNPC[npc]
    if not actor then return nil, "untracked-source-actor" end
    if actor.script then return nil, "source-actor-already-claimed" end
    if actor.value.phase == "moving" or npc.isMoving then return nil, "moving-source-actor" end
    if not owner or owner.game ~= s.game or not owner:valid() or not owner:isTop()
        or owner.session ~= s.session or owner.zone ~= s.zone then return nil, "stale-script-owner" end
    if not actor.spec.random then
        if not s.descriptor.canStand(actor.spec,npc.gridX,npc.gridY,s.zone)
            or not actor.spec.faces[npc.facing] then return nil, "invalid-source-actor-pose" end
        -- Trainer approach has its own existing owner and exposes its completed
        -- position through the sprite. Adopt that same pose as snapshot() does.
        actor.value = WorldMotionData.initial(actor.spec)
        local value = actor.value
        value.x,value.y,value.facing = npc.gridX,npc.gridY,npc.facing
        value.origin_x,value.target_x,value.origin_y,value.target_y = value.x,value.x,value.y,value.y
    end
    local token = {}
    actor.script = {token=token, owner=owner, ownerEpoch=owner.epoch, epoch=s.epoch, player=s.game.player, origin=copy(actor.value)}
    if s.pending and s.pending.id == actor.value.id then s.pending = nil end
    -- Interaction facing restoration must not undo the script's completed pose.
    if s.interaction and s.interaction.id == actor.value.id then s.interaction = nil end
    self:_pose(actor)
    return token
end
function NPCMotion:startScriptStep(token, direction)
    local s = stores[self]
    local actor, lease = scriptLease(s, token)
    if not actor or not scriptCurrent(s, lease) then return false, "stale-script-token" end
    if lease.move then return false, "script-cell-in-progress" end
    local delta = dirs[direction]
    local v, spec, npc = actor.value, actor.spec, actor.npc
    if not delta or spec.role ~= "boulder" and not spec.faces[direction] then return false, "missing-source-actor-facing" end
    local x, y = v.x + delta[1], v.y + delta[2]
    local cell = y * s.descriptor.width + x + 1
    local player = s.game.player
    local occupant = s.manager:getNPCAt(x,y)
    if occupant and occupant ~= npc or x == player.gridX and y == player.gridY
        or player.isMoving and x == player.startPixelX/TILE_SIZE and y == player.startPixelY/TILE_SIZE
        or s.descriptor.protected[cell] and not (spec.script_transit and spec.script_transit[cell])
        or not s.descriptor.canStep(spec,v.x,v.y,x,y,s.zone) then return false, "blocked-scripted-npc-move" end
    -- Verify walking art before reserving or exposing an intermediate pose.
    local ok = spec.role == "boulder" and npc.images[v.facing] ~= nil
        or pcall(SourceActors.stepImage,spec.sprite_source,direction,2,spec.content_profile)
    if not ok then return false, "missing-source-actor-walking-art" end
    lease.move = {x=v.x,y=v.y,toX=x,toY=y,direction=direction,tick=0}
    npc.isMoving = true
    return true
end
function NPCMotion:updateScript(token)
    local s = stores[self]
    local actor, lease = scriptLease(s, token)
    if not actor or not scriptCurrent(s, lease) then return false, "stale-script-token" end
    local move = lease.move
    if not move then return false, "no-script-cell" end
    move.tick = move.tick + 1
    local npc, v = actor.npc, actor.value
    npc.facing = actor.spec.role == "boulder" and v.facing or move.direction
    npc:moveTo((move.x+(move.toX-move.x)*move.tick/8)*TILE_SIZE,
        (move.y+(move.toY-move.y)*move.tick/8)*TILE_SIZE-8)
    if actor.spec.role == "boulder" then
        npc:setImage(assert(npc.images[v.facing], "fixed source boulder art missing"))
    else
        npc:setImage(SourceActors.stepImage(actor.spec.sprite_source,move.direction,move.tick,actor.spec.content_profile))
    end
    if move.tick < 8 then return false, "moving" end
    v.x,v.y = move.toX,move.toY
    if actor.spec.role ~= "boulder" then
        v.facing = move.direction
    end
    v.origin_x,v.target_x,v.origin_y,v.target_y = v.x,v.x,v.y,v.y
    lease.move = nil
    self:_pose(actor)
    return true
end
-- Reset may run during overlay exit, after removal from the stack. Identity
-- and attachment guards still apply; facing and movement require top ownership.
function NPCMotion:faceScript(token, facing)
    local s = stores[self]
    local actor, lease = scriptLease(s, token)
    if not actor or not scriptCurrent(s, lease) or lease.move
        or not actor.spec.faces[facing] then return false end
    actor.value.facing = facing
    self:_pose(actor)
    return true
end
function NPCMotion:resetScript(token)
    local s = stores[self]
    local actor, lease = scriptLease(s, token)
    if not actor or s.game.session ~= s.session or currentZone ~= s.zone
        or s.game.player ~= lease.player or lease.owner.epoch ~= lease.ownerEpoch
        or not lease.owner:valid() then return false end
    local origin, player = lease.origin, s.game.player
    local occupant = s.manager:getNPCAt(origin.x, origin.y)
    if occupant and occupant ~= actor.npc
        or player.gridX == origin.x and player.gridY == origin.y
        or player.isMoving and player.startPixelX/TILE_SIZE == origin.x and player.startPixelY/TILE_SIZE == origin.y
        or not s.descriptor.canStand(actor.spec, origin.x, origin.y, s.zone) then return false end
    lease.move = nil
    actor.value = copy(origin)
    self:_pose(actor)
    return true
end
function NPCMotion:releaseScript(token, rollback)
    local s = stores[self]
    local actor, lease = scriptLease(s, token)
    if not actor then return false end
    if rollback then actor.value = copy(lease.origin) end
    -- Incomplete interpolation never changed the completed durable cell.
    actor.script = nil
    self:_pose(actor)
    return true
end

-- A confirmed trainer return may restore a completed source pose, never an
-- interpolation or an arbitrary scripted placement. Generic trainer rendering
-- stays under this owner just like wandering and leased script movement.
function NPCMotion:restoreTrainerPose(npc, x, y, facing)
    local s = stores[self]
    local actor = s.byNPC[npc]
    if not actor or actor.spec.role ~= "trainer" or actor.script
        or s.game.session ~= s.session or currentZone ~= s.zone
        or not actor.spec.faces[facing]
        or not Party._integer(x,0,s.descriptor.width-1) or not Party._integer(y,0,s.descriptor.height-1)
        or not s.descriptor.canStand(actor.spec,x,y,s.zone) then return false end
    local player = s.game.player
    local occupant = s.manager:getNPCAt(x,y)
    if occupant and occupant ~= npc or player.gridX == x and player.gridY == y then return false end
    local value = WorldMotionData.initial(actor.spec)
    value.x,value.y,value.facing = x,y,facing
    value.origin_x,value.target_x,value.origin_y,value.target_y = x,x,y,y
    actor.value = value
    self:_pose(actor)
    return true
end

-- Source scene placement is a lease operation, never a direct sprite write.
function NPCMotion:placeScript(token, x, y, facing)
    local s = stores[self]
    local actor, lease = scriptLease(s, token)
    if not actor or not scriptCurrent(s, lease) then return false, "stale-script-token" end
    if lease.move then return false, "script-cell-in-progress" end
    if not Party._integer(x,0,s.descriptor.width-1) or not Party._integer(y,0,s.descriptor.height-1)
        or s.descriptor.protected[y*s.descriptor.width+x+1]
        or not actor.spec.script_positions[y*s.descriptor.width+x+1]
        or not s.descriptor.canStand(actor.spec,x,y,s.zone) then return false, "invalid-source-script-placement" end
    local occupant = s.manager:getNPCAt(x,y)
    local player = s.game.player
    if occupant and occupant ~= actor.npc or player.gridX == x and player.gridY == y
        or player.isMoving and player.startPixelX/TILE_SIZE == x and player.startPixelY/TILE_SIZE == y then
        return false, "occupied-source-script-placement"
    end
    if facing ~= nil and not actor.spec.faces[facing] then return false, "missing-source-actor-facing" end
    local v = actor.value
    v.x,v.y = x,y
    if facing then v.facing = facing end
    v.origin_x,v.target_x,v.origin_y,v.target_y = x,x,y,y
    self:_pose(actor)
    return true
end

-- Strength is authorized by the field owner. This API owns only the tracked
-- actor's one-cell movement, fixed source image, reservations and lease lifetime.
function NPCMotion:isBoulder(npc)
    local actor = stores[self].byNPC[npc]
    return actor ~= nil and actor.spec.role == "boulder"
end

function NPCMotion:previewBoulderPush(npc, direction)
    local s = stores[self]
    local actor = s.byNPC[npc]
    if not actor or actor.spec.role ~= "boulder" then
        return nil, "not-source-boulder"
    end
    if not s.game or s.game.session ~= s.session or currentZone ~= s.zone then
        return nil, "stale-boulder-context"
    end
    if actor.script or npc.isMoving then
        return nil, "claimed-source-boulder"
    end
    local delta = dirs[direction]
    local player = s.game.player
    local value = actor.value
    if not delta or not player or player.isMoving or player.pendingEdgeDoor or player.pendingConnection
        or player.facing ~= direction or player.gridX + delta[1] ~= value.x
        or player.gridY + delta[2] ~= value.y then
        return nil, "player-not-behind-boulder"
    end
    local x, y = value.x + delta[1], value.y + delta[2]
    if not s.descriptor.canPush(actor.spec, player.gridX, player.gridY, value.x, value.y, x, y, s.zone)
        or s.descriptor.protected[y * s.descriptor.width + x + 1] then
        return nil, "blocked-boulder-surface"
    end
    local occupant = s.manager:getNPCAt(x, y)
    if occupant or x == player.gridX and y == player.gridY then
        return nil, "occupied-boulder-target"
    end
    return {id=value.id, x=value.x, y=value.y, toX=x, toY=y, direction=direction}
end

function NPCMotion:beginBoulderPush(npc, direction, owner)
    local intent, reason = self:previewBoulderPush(npc, direction)
    if not intent then
        return nil, reason
    end
    local token, problem = self:claimScript(npc, owner)
    if not token then
        return nil, problem
    end
    local started, failure = self:startScriptStep(token, direction)
    if not started then
        self:releaseScript(token)
        return nil, failure
    end
    local s = stores[self]
    local _, lease = scriptLease(s, token)
    lease.push = {playerX=s.game.player.gridX, playerY=s.game.player.gridY}
    return token
end

function NPCMotion:cancelBoulderPush(token)
    local actor, lease = scriptLease(stores[self], token)
    if not actor or actor.spec.role ~= "boulder" or not lease.push then
        return false
    end
    -- updateScript never advances the completed value before frame eight.
    -- Keep any completed push; discard only an incomplete interpolation.
    return self:releaseScript(token)
end

function NPCMotion:updateBoulderPush(token)
    local s = stores[self]
    local actor, lease = scriptLease(s, token)
    if not actor or actor.spec.role ~= "boulder" or not lease.push then
        return nil, "stale-boulder-token"
    end
    local player = s.game and s.game.player
    if not player or player ~= lease.player or player.isMoving
        or player.gridX ~= lease.push.playerX or player.gridY ~= lease.push.playerY then
        self:cancelBoulderPush(token)
        return nil, "player-moved-during-boulder-push"
    end
    local complete, reason = self:updateScript(token)
    if complete then
        self:releaseScript(token)
        return true, "complete"
    end
    if reason == "moving" then
        return false, reason
    end
    self:cancelBoulderPush(token)
    return nil, reason
end
