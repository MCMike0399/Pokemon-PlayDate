-- Bounded content integration. ImportedMaps owns the disposable cache/ledger;
-- existing WorldDeltas and zoneRegistry retain their world authority.
PewterWorld={}
local installed=setmetatable({},{__mode="k"})
local starts={Route2={8,71},ViridianForestSouthGate={5,7},ViridianForest={16,47},ViridianForestNorthGate={5,7},PewterCity={18,35},PewterGym={5,13},PewterMart={5,7},PewterPokecenter={3,7}}
local function ensureKeys(registry,tiles)
    local entries,seen={},{}
    for _,tile in ipairs(tiles) do if not registry:has(tile.key) and not seen[tile.key] then
        seen[tile.key]=true;entries[#entries+1]=PewterSlice.tile(tile.key)
    end end
    if #entries>0 then registry:registerBatch(entries) end
end
local function create(game,name,registry,desired,isolated)
    local d=PewterSlice.padded(name);local start=assert(starts[name])
    if not isolated then PewterSprites.installFor(d) end
    local dispatch=function(id) assert(not isolated,"catalog source events cannot execute");return KantoWorld.dispatch(game,id) end
    local quest=function(id)return not isolated and game.session:questFlag(id) or false end
    local sourceFlag=function(id)return not isolated and game.trainers:sourceFlag(id) or false end
    local config={registry=registry,bindingAdapter=PewterBindings,compactTerrain=true,isolatedCatalog=isolated or false,
        spawn={x=start[1],y=start[2],facing="up"},sliceBindings=PewterSlice.specs(name,d),dispatch=dispatch,questFlag=quest,sourceFlag=sourceFlag}
    -- Source refs are provenance for the external generator, not a retained
    -- per-cell Lua table in a live Zone. The full immutable JSON remains on disk.
    d.source_refs=nil
    local zone=Zone.fromMapDefinition(d,registry,config)
    if desired and desired.tile_count>0 then ensureKeys(registry,desired.tiles);zone:applyDeltas(desired) end
    return zone
end
function PewterWorld.locationPolicy()
    local policy = { sliceZones = {} }
    for _, name in ipairs(SourceMaps.names()) do
        policy.sliceZones[SourceMaps.entry(name).id] = true
    end
    return policy
end
function PewterWorld.createProvider(game, registry)
    if not game.trainers then game.trainers = TrainerEvents(game) end
    local profiles = SourceMaps.legacyProfiles({
        dispatch = function(id) return KantoWorld.dispatch(game, id) end,
        questFlag = function(id) return game.session:questFlag(id) end,
        sourceFlag = function(id) return game.trainers:sourceFlag(id) end,
    })
    return SourceMaps.createProvider(profiles, registry or WorldTiles)
end
function PewterWorld.install(game)
    if installed[game] then
        assert(WorldDeltas.definitionProvider() == installed[game], "source world provider replaced")
        return installed[game]
    end
    local policy = game.sessionLocationPolicy and game.sessionLocationPolicy.sliceZones
    for _, name in ipairs(SourceMaps.names()) do
        local entry = SourceMaps.entry(name)
        assert(policy and policy[entry.id] == true and not zoneRegistry[entry.key], "explicit unloaded source location policy required")
        for _, zone in pairs(zoneRegistry) do
            assert(zone.stableID ~= entry.id, "source stable map ID already owned")
        end
    end
    SourceActors.register("pewter", SourceActors.describePewter)
    local provider = PewterWorld.createProvider(game)
    WorldDeltas.installDefinitionProvider(provider)
    installed[game] = provider
    return provider
end
function PewterWorld.isolated(name)
    return create(nil,name,TileRegistry(),nil,true)
end
local dirs={up={0,-1},down={0,1},left={-1,0},right={1,0}}
local function target(game,key,x,y,direction)
    local legacy=zoneRegistry[key]
    local provider=WorldDeltas.definitionProvider()
    if provider and provider:hasKey(key) then
        local d=provider:descriptor(key)
        local ok=pcall(provider.resolveLocation,provider,{zone_id=d.id,x=x,y=y,facing=direction},provider:export(),game.sessionLocationPolicy)
        if not ok then return nil,"blocked-source-arrival" end
        if legacy then
            for _,npc in ipairs(legacy.npcDefs) do if npc.gridX==x and npc.gridY==y and (not npc.appearsIf or npc.appearsIf()) then return nil,"occupied-source-arrival" end end
        end
    else
        if not legacy or x<0 or y<0 or x>=legacy.width or y>=legacy.height or legacy.collision[y+1][x+1]~=0 then return nil,"blocked-source-arrival" end
        for _,npc in ipairs(legacy.npcDefs) do if npc.gridX==x and npc.gridY==y and (not npc.appearsIf or npc.appearsIf()) then return nil,"occupied-source-arrival" end end
    end
    return {to=key,toX=x,toY=y,facing=direction,connection=true,source="pinned Route2/Pewter header connection"}
end
-- Second return distinguishes this module's explicit surfaces from old Kanto.
function PewterWorld.connection(game,zone,x,y,direction)
    local name=PewterSlice.nameForID(zone.stableID)
    if zone.stableID=="pokered:VIRIDIAN_CITY" and direction=="up" and y==0 then
        if game.session:getIntro().stage~="done" then return nil,true,"intro-gate" end
        local door,reason=target(game,"kanto_route2",x-10,71,"up");return door,true,reason
    end
    if not name then return nil,false end
    local d=dirs[direction];if not d then return nil,true,"invalid-direction" end
    if x+d[1]>=0 and y+d[2]>=0 and x+d[1]<zone.width and y+d[2]<zone.height then return nil,false end
    if game.session:getIntro().stage~="done" then return nil,true,"intro-gate" end
    local key,tx,ty
    if name=="Route2" and direction=="up" and y==0 then key,tx,ty="kanto_pewter_city",x+10,35
    elseif name=="Route2" and direction=="down" and y==71 then key,tx,ty="kanto_viridian_city",x+10,0
    elseif name=="PewterCity" and direction=="down" and y==35 then key,tx,ty="kanto_route2",x-10,0
    else return nil,true,"unimplemented-source-exit:"..zone.stableID..":"..direction end
    local door,reason=target(game,key,tx,ty,direction);return door,true,reason
end
function PewterWorld.trySight(game)
    if not game.trainers or game.machine:getCurrent()~="overworld" or game.player.isMoving or game.player.pendingEdgeDoor then return false end
    if not PewterSlice.nameForID(currentZone.stableID) then return false end
    for _,npc in ipairs(game.npcManager.npcs) do
        local id=npc.def and npc.def.source_event_id
        if id and PewterSlice.trainer(id) and not game.session:trainerDefeated(id) then
            local steps,reason=game.trainers:approach(npc,"sight")
            if steps then game.machine:push("event",id,{mode="sight"});return true end
            if reason=="occupied-trainer-approach" or reason=="blocked-trainer-approach" or reason=="blocked-trainer-pair" then
                game.player.lastTraversalBlock={kind="trainer",id=reason}
            end
        end
    end
    return false
end
local hidden
function PewterWorld.hiddenAt(x,y)
    if not hidden then hidden=assert(json.decodeFile("data/pewterSlice/hidden-events.json")).events end
    for _,event in ipairs(hidden) do
        if event.map_id==currentZone.stableID then
            local name=PewterSlice.nameForID(event.map_id);local pad=PewterSlice.descriptor(name).padding
            if event.x+pad==x and event.y==y then return event.id end
        end
    end
end
function PewterWorld.tryInteract(game)
    if PCTerminals and PCTerminals.tryInteract(game) then return true end
    if not PewterSlice.nameForID(currentZone.stableID) then return false end
    local player=game.player;local x,y=player:getFacingTile()
    if x<0 or y<0 or x>=currentZone.width or y>=currentZone.height then return false end
    local npc=game.npcManager:getNPCAt(x,y)
    if not npc and currentZone:terrainAt(x,y).counter then
        local d=dirs[player.facing];x,y=x+d[1],y+d[2]
        if x>=0 and y>=0 and x<currentZone.width and y<currentZone.height then npc=game.npcManager:getNPCAt(x,y) end
    end
    local id=npc and npc.def and npc.def.source_event_id
    if not id and x>=0 and y>=0 and x<currentZone.width and y<currentZone.height then
        for _,event in ipairs(currentZone:sourceEventsAt(x,y)) do
            if event.kind=="background_events" or event.kind=="warps" and event.status=="blocked" then id=event.id;break end
        end
        id=id or PewterWorld.hiddenAt(x,y)
    end
    if not id then return false end
    if player.isMoving or player.pendingEdgeDoor then player.lastTraversalBlock={kind="source-event",id="movement-active"};return true end
    if not PewterEvents.has(id) then player.lastTraversalBlock={kind="unimplemented-source-event",id=id};return true end
    if npc then
        if game.npcManager.motion:requestInteraction(npc,id)then return true end
        npc:faceTowards(player.gridX,player.gridY)
    end
    KantoWorld.dispatch(game,id);return true
end
