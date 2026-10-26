-- Bounded content integration. ImportedMaps owns the disposable cache/ledger;
-- existing WorldDeltas and zoneRegistry retain their world authority.
PewterWorld={}
local installed=setmetatable({},{__mode="k"})
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
    return SourceMaps.isolated(name)
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
function PewterWorld.connection(game, zone, x, y, direction)
    local name = SourceMaps.nameForID(zone.stableID)
    if not name then return nil, false end
    local d = dirs[direction]
    if not d then return nil, true, "invalid-direction" end
    if type(x) ~= "number" or type(y) ~= "number" or x % 1 ~= 0 or y % 1 ~= 0
        or x < 0 or y < 0 or x >= zone.width or y >= zone.height then
        return nil, true, "invalid-origin"
    end
    if zone.collision[y + 1][x + 1] ~= 0 then return nil, true, "blocked-origin" end
    if x + d[1] >= 0 and y + d[2] >= 0 and x + d[1] < zone.width and y + d[2] < zone.height then
        return nil, false
    end

    local descriptor = SourceMaps.descriptor(name)
    -- Authored Pallet retains its reviewed coordinate adapter in KantoSlice.
    for _, c in ipairs(descriptor.connections) do
        if c.target_map == "PALLET_TOWN" and direction == "down" then return nil, false end
    end
    if not game or not game.session or game.session:getIntro().stage ~= "done" then
        return nil, true, "intro-gate"
    end

    -- Preserve the old Viridian error vocabulary while sharing provider-backed
    -- arrival validation with every ordinary manifest connection.
    local sourceDirection = ({up="north", down="south", left="west", right="east"})[direction]
    local legacyErrors = SourceMaps.entry(name).profile == "viridian"
    for _, id in ipairs(descriptor.blocked_connections) do
        if id:sub(1, #sourceDirection + 1) == sourceDirection .. ":" then legacyErrors = false end
    end
    local value = SourceMaps.connection(name, x, y, direction)
    if not value then
        if legacyErrors then
            return nil, true, "unimplemented-connection:" .. zone.stableID .. ":" .. direction
        end
        for _, c in ipairs(descriptor.connections) do
            if c.direction == sourceDirection and SourceMaps.nameForID("pokered:" .. c.target_map) then
                return nil, true, "blocked-source-arrival"
            end
        end
        return nil, true, "unimplemented-source-exit:" .. zone.stableID .. ":" .. direction
    end
    -- Resolve against the complete authoritative world, including unloaded
    -- destination deltas, before applying the existing arrival occupancy guard.
    local provider = WorldDeltas.definitionProvider()
    local loaded = zoneRegistry[value.to]
    local destinationID = provider and provider:hasKey(value.to) and provider:descriptor(value.to).id
        or (loaded and loaded.stableID)
    local valid = pcall(WorldDeltas.resolveLocation,
        { zone_id = destinationID, x = value.x, y = value.y, facing = direction },
        WorldDeltas.export(), game.sessionLocationPolicy)
    if not valid then
        return nil, true, legacyErrors and "blocked-connection-arrival" or "blocked-source-arrival"
    end
    local door, reason = target(game, value.to, value.x, value.y, direction)
    if legacyErrors then
        if reason == "blocked-source-arrival" then reason = "blocked-connection-arrival" end
        if reason == "occupied-source-arrival" then reason = "occupied-connection-arrival" end
        if door then door.source = value.source end
    end
    return door, true, reason
end
function PewterWorld.trySight(game)
    return SourceActors.trySight(game)
end

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
    if not SourceEvents.has(id) then player.lastTraversalBlock={kind="unimplemented-source-event",id=id};return true end
    if npc then
        if game.npcManager.motion:requestInteraction(npc,id)then return true end
        npc:faceTowards(player.gridX,player.gridY)
    end
    KantoWorld.dispatch(game,id);return true
end
