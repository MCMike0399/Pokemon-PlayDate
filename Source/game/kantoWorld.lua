-- Explicit reviewed four-map traversal and root-event dispatch.
KantoWorld = {}
local keys={Route1="kanto_route1",ViridianCity="kanto_viridian_city",ViridianMart="kanto_viridian_mart",ViridianPokecenter="kanto_viridian_center"}
local legacyKeys = {}
for _, key in pairs(keys) do legacyKeys[key] = true end
local stable={Route1="pokered:ROUTE_1",ViridianCity="pokered:VIRIDIAN_CITY",ViridianMart="pokered:VIRIDIAN_MART",ViridianPokecenter="pokered:VIRIDIAN_POKECENTER"}
local byID={};for name,id in pairs(stable) do byID[id]=name end
local installed=setmetatable({},{__mode="k"})
local directions={up={0,-1},down={0,1},left={-1,0},right={1,0}}
local function inside(zone,x,y) return type(x)=="number" and type(y)=="number" and x%1==0 and y%1==0 and x>=0 and y>=0 and x<zone.width and y<zone.height end
-- Resolve each legacy lookup through the cache. Never retain an evicted Zone
-- in this facade; callers may still request the historical four map keys.
local function refs(provider)
    return setmetatable({}, {
        __index = function(_, key)
            if legacyKeys[key] then return provider:ensure(key) end
        end,
    })
end
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
        assert(WorldDeltas.definitionProvider() == installed[game], "installed Kanto provider replaced")
        return refs(installed[game])
    end
    -- Installation validates the provider only. Maps and their art are created
    -- on first entry through the existing bounded cache.
    local provider = PewterWorld.install(game)
    installed[game] = provider
    return refs(provider)
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
    -- The authored Pallet seam can be the first request for Route1. Validate
    -- unloaded durable deltas before constructing its actors/collision surface.
    local provider = WorldDeltas.definitionProvider()
    if provider and provider:hasKey(value.to) then
        local descriptor = provider:descriptor(value.to)
        local valid = pcall(provider.resolveLocation, provider,
            { zone_id = descriptor.id, x = value.x, y = value.y, facing = value.facing },
            provider:export(), game.sessionLocationPolicy)
        if not valid then return nil, "blocked-connection-arrival" end
        target = provider:ensure(value.to)
    end
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
    if SourceEvents.worldHook("interact", game) then return true end
    if HomeRest and HomeRest.tryInteract(game)then return true end
    if FieldItems and FieldItems.tryDaisy(game)then return true end
    if PCTerminals.tryInteract(game) then return true end
    if PewterWorld and PewterWorld.tryInteract(game) then return true end
    local player=game.player;local fx,fy=player:getFacingTile()
    if not inside(currentZone,fx,fy) then return false end
    local id
    if currentZone:isSliceReady() then
        for _, event in ipairs(currentZone:sourceEventsAt(fx, fy)) do
            if event.kind == "background_events" then
                id = event.id
                break
            end
        end
    end
    local npc
    if not id then
        npc = game.npcManager:getNPCAt(fx, fy)
        if not npc and currentZone:isSliceReady() and currentZone:terrainAt(fx, fy).counter then
            local direction = directions[player.facing]
            fx, fy = fx + direction[1], fy + direction[2]
            if inside(currentZone, fx, fy) then
                npc = game.npcManager:getNPCAt(fx, fy)
            end
        end
        id = npc and npc.def and npc.def.source_event_id
    end
    if not id and npc and npc.name=="OAK" and currentZone.stableID=="oaks_lab" and game.session:getIntro().stage=="done" then
        id="pokered:OAKS_LAB:script:parcel-handoff"
    end
    if not id and currentZone:isSliceReady() and inside(currentZone,fx,fy) then
        for _,event in ipairs(currentZone:sourceEventsAt(fx,fy)) do
            if event.kind == "warps" and event.status == "blocked" then
                id = event.id
                break
            end
        end
    end
    if not id then return false end
    player.lastTraversalBlock=nil
    if player.isMoving or player.pendingEdgeDoor then block(player,"source-event","movement-active");return true end
    if not SourceEvents.has(id) then block(player,"unimplemented-source-event",id);return true end
    if npc then
        return SourceActors.interact(game, npc, id)
    end
    KantoWorld.dispatch(game,id)
    return true
end
