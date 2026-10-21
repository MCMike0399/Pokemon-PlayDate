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
    for _,actor in pairs(s.actors)do actor.npc.isMoving=false end
    s.actors,s.specs,s.byNPC={},{},setmetatable({},{__mode="k"})
    s.game,s.zone,s.session,s.descriptor,s.pending,s.interaction,s.migration=nil,nil,nil,nil,nil,nil,nil
end
function NPCMotion:_pose(actor)
    local v,npc=actor.value,actor.npc
    npc.gridX,npc.gridY=v.x,v.y;npc.isMoving=v.phase=="moving"
    if v.phase=="moving"then
        local t=v.tick/8;npc.facing=v.facing
        npc:moveTo((v.origin_x+(v.target_x-v.origin_x)*t)*TILE_SIZE,(v.origin_y+(v.target_y-v.origin_y)*t)*TILE_SIZE-8)
        npc:setImage(v.tick>0 and PewterSprites.stepImage(actor.spec.sprite_source,v.facing,v.tick)or assert(npc.images[v.facing]))
    else npc:moveTo(v.x*TILE_SIZE,v.y*TILE_SIZE-8);npc:setFacing(v.facing)end
end
function NPCMotion:attach(game,zone,payload,reconcile)
    local s=stores[self];local world=WorldDeltas.export();local descriptor=SourceActors.describe(zone.stableID,world)
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
        if spec.random and visible(s,actor)then
            if v.phase=="delay"then
                v.delay_left=v.delay_left-1
                if v.delay_left==0 then v.phase="ready";v.delay_raw=0 end
            elseif v.phase=="ready"and not s.game.player.isMoving then
                local direction=WorldMotionData.direction(spec.selector,s.session:worldRandom(0,255));local d=dirs[direction]
                if spec.faces[direction]then v.facing=direction end
                local tx,ty=v.x+d[1],v.y+d[2];local player=s.game.player
                local occupied=s.manager:getNPCAt(tx,ty)
                local playerBlocked=tx==player.gridX and ty==player.gridY or player.isMoving and tx==player.startPixelX/TILE_SIZE and ty==player.startPixelY/TILE_SIZE
                if spec.movement=="WALK"and not occupied and not playerBlocked and s.descriptor.canStep(spec,v.x,v.y,tx,ty,s.zone)then
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
