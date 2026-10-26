-- Explicit reviewed four-map traversal and root-event dispatch.
KantoWorld = {}
local names={"Route1","ViridianCity","ViridianMart","ViridianPokecenter"}
local keys={Route1="kanto_route1",ViridianCity="kanto_viridian_city",ViridianMart="kanto_viridian_mart",ViridianPokecenter="kanto_viridian_center"}
local stable={Route1="pokered:ROUTE_1",ViridianCity="pokered:VIRIDIAN_CITY",ViridianMart="pokered:VIRIDIAN_MART",ViridianPokecenter="pokered:VIRIDIAN_POKECENTER"}
local byID={};for name,id in pairs(stable) do byID[id]=name end
local installed=setmetatable({},{__mode="k"})
local directions={up={0,-1},down={0,1},left={-1,0},right={1,0}}
local function inside(zone,x,y) return type(x)=="number" and type(y)=="number" and x%1==0 and y%1==0 and x>=0 and y>=0 and x<zone.width and y<zone.height end
local function refs(zones) local copy={};for key,zone in pairs(zones) do copy[key]=zone end;return copy end
local function block(player,kind,id) if player then player.lastTraversalBlock={kind=kind,id=id} end end
function KantoWorld.locationPolicy()
    local list={};for _,id in pairs(stable) do list[id]=true end
    return {sliceZones=list}
end
function KantoWorld.install(game)
    assert(game and game.machine and game.session, "Kanto traversal needs the authoritative context")
    local policy = game.sessionLocationPolicy and game.sessionLocationPolicy.sliceZones
    for _, id in pairs(stable) do
        assert(policy and policy[id] == true, "explicit Kanto save-location policy required")
    end
    if installed[game] then
        SliceSprites.install()
        for key, zone in pairs(installed[game]) do
            assert(zoneRegistry[key] == zone, "installed Kanto map registry replaced")
        end
        return refs(installed[game])
    end
    -- The legacy facade keeps its four stable Zone references, but their
    -- construction, durable deltas and cache ownership now use one provider.
    local provider = PewterWorld.install(game)
    local zones = {}
    local restoreCache = provider:checkpointRuntime()
    local restoreTiles = WorldTiles:checkpointRuntime()
    local ok, problem = pcall(function()
        for _, name in ipairs(names) do zones[keys[name]] = provider:ensure(keys[name]) end
    end)
    if not ok then
        restoreCache()
        restoreTiles()
        error(problem, 0)
    end
    installed[game] = zones
    return refs(zones)
end
function KantoWorld.connection(game,zone,x,y,direction)
    local d=directions[direction]
    if not d or not inside(zone,x,y) then return nil,"invalid-origin" end
    if zone.collision[y+1][x+1]~=0 then return nil,"blocked-origin" end
    if PewterWorld then
        local door,handled,reason=PewterWorld.connection(game,zone,x,y,direction)
        if handled then return door,reason end
    end
    local name=byID[zone.stableID] or (zone.stableID=="pallet_town" and "pallet_town")
    if not name then return nil end
    if x+d[1]>=0 and y+d[2]>=0 and x+d[1]<zone.width and y+d[2]<zone.height then return nil end
    if not game or not game.session or game.session:getIntro().stage~="done" then return nil,"intro-gate" end
    local ok,value=pcall(KantoSlice.connection,name,x,y,direction,"done")
    if not ok then return nil,"unimplemented-connection:"..zone.stableID..":"..direction end
    local target=zoneRegistry[value.to]
    if not target or not inside(target,value.x,value.y) or target.collision[value.y+1][value.x+1]~=0 then return nil,"blocked-connection-arrival" end
    for _,npc in ipairs(target.npcDefs) do
        if npc.gridX==value.x and npc.gridY==value.y and (not npc.appearsIf or npc.appearsIf()) then return nil,"occupied-connection-arrival" end
    end
    return {to=value.to,toX=value.x,toY=value.y,facing=value.facing,connection=true,source=value.source}
end
function KantoWorld.dispatch(game,id)
    return SourceEvents.dispatch(game,id)
end

function KantoWorld.onEnter(game,options)
    if options and options.fromDoor and currentZone.stableID==stable.ViridianMart then
        return KantoWorld.dispatch(game,"pokered:VIRIDIAN_MART:script:entry")
    end
    return false -- Continue is an exact saved position; Center has no generic UP step.
end
function KantoWorld.tryInteract(game)
    if HomeRest and HomeRest.tryInteract(game)then return true end
    if FieldItems and FieldItems.tryDaisy(game)then return true end
    if PCTerminals.tryInteract(game) then return true end
    if PewterWorld and PewterWorld.tryInteract(game) then return true end
    local player=game.player;local fx,fy=player:getFacingTile()
    if not inside(currentZone,fx,fy) then return false end
    local npc=game.npcManager:getNPCAt(fx,fy)
    if not npc and currentZone:isSliceReady() and currentZone:terrainAt(fx,fy).counter then
        local d=directions[player.facing];fx,fy=fx+d[1],fy+d[2]
        if inside(currentZone,fx,fy) then npc=game.npcManager:getNPCAt(fx,fy) end
    end
    local id=npc and npc.def and npc.def.source_event_id
    if not id and npc and npc.name=="OAK" and currentZone.stableID=="oaks_lab" and game.session:getIntro().stage=="done" then
        id="pokered:OAKS_LAB:script:parcel-handoff"
    end
    if not id and currentZone:isSliceReady() and inside(currentZone,fx,fy) then
        for _,event in ipairs(currentZone:sourceEventsAt(fx,fy)) do
            if event.kind=="background_events" or event.kind=="warps" and event.status=="blocked" then id=event.id;break end
        end
    end
    if not id then return false end
    player.lastTraversalBlock=nil
    if player.isMoving or player.pendingEdgeDoor then block(player,"source-event","movement-active");return true end
    if not SourceEvents.has(id) then block(player,"unimplemented-source-event",id);return true end
    if npc then npc:faceTowards(player.gridX,player.gridY) end
    KantoWorld.dispatch(game,id)
    return true
end
