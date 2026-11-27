-- Couples existing traversal/session owners to completed runtime movement.
FieldTravelRuntime = {}
local gfx <const> = playdate.graphics
local missedBed = false

-- The next map-bed start may find no inflate window after the destination
-- atlas. One following enterMap may keep that miss quiet. Later beds still raise.
function FieldTravelRuntime.consumeMissedBed()
    local value = missedBed
    missedBed = false
    return value
end
local directions <const> = {up = {0, -1}, down = {0, 1}, left = {-1, 0}, right = {1, 0}}

local function copy(value)
    return Party._primitive(value)
end

function FieldTravelRuntime.position(game)
    return {zone_id = currentZone.stableID, x = game.player.gridX, y = game.player.gridY, facing = game.player.facing}
end

function FieldTravelRuntime.step(game, boarding)
    local position = FieldTravelRuntime.position(game)
    local world = WorldDeltas.export()
    local from, descriptor = FieldTravelWorld.cell(position, world, game.sessionLocationPolicy)
    if not from then
        return nil, descriptor
    end
    local delta = directions[position.facing]
    local target = copy(position)
    target.x = target.x + delta[1]
    target.y = target.y + delta[2]
    local cell, reason = FieldTravelWorld.cell(target, world, game.sessionLocationPolicy)
    if not cell then
        return nil, reason
    end
    from.occupied = false
    cell.occupied = game.npcManager:getNPCAt(target.x, target.y) ~= nil
    local plan
    if boarding then
        plan, reason = FieldTravel.surf(game.session:fieldTravelData(), position, from, cell,
            descriptor.tileset.constant, game:fieldTravelRestrictions(position))
    else
        plan, reason = FieldTravel.surfStep(game.session:fieldTravelData(), position, from, cell,
            descriptor.tileset.constant)
    end
    if not plan then
        return nil, reason
    end
    return {session = game.session, zone = currentZone, player = game.player,
        epoch = game.session:fieldWorldEpoch(), before = game.session:fieldTravelData(),
        world = world, origin = position, plan = plan}
end

function FieldTravelRuntime.finishStep(game, request)
    if game.session ~= request.session or game.player ~= request.player or currentZone ~= request.zone
        or game.session:fieldWorldEpoch() ~= request.epoch
        or not FieldMoves.same(game.session:fieldTravelData(), request.before)
        or not FieldMoves.same(WorldDeltas.export(), request.world)
        or not FieldMoves.same(FieldTravelRuntime.position(game), request.origin)
        or game.npcManager:getNPCAt(request.plan.location.x, request.plan.location.y) then
        return false, "stale-surf-step"
    end
    -- Sprite interpolation/render checks have completed. Publication is the last
    -- fallible operation; Player then assigns only the settled logical cell.
    return game.session:captureTraversal({world = request.world, location = request.plan.location,
        actors = game.npcManager.motion:snapshot(), fieldTravel = request.plan.travel})
end

local function removePlayer(player)
    player:remove()
    player.grassOverlay:remove()
    player.exitArrow:remove()
end

-- The destination definition does not fit beside a live city. Drop the origin
-- definition, view bitmap, event chunks and map bed first. The same player,
-- npc manager and view object stay so a failed capture can reattach them.
local function releaseFlyOrigin(game, owner, previous, sprites)
    local zone = previous.zone
    -- Stacked field travel (and any other live state) keeps the origin object
    -- after the cache and the prepared request have dropped it.
    local held = {}
    if zone then
        local function drop(holder)
            if type(holder) == "table" and holder.zone == zone then
                held[#held + 1] = holder
                holder.zone = nil
            end
        end
        local machine = game.machine
        if machine then
            for _, state in ipairs(machine.stack) do drop(state) end
            local world = machine:get("overworld")
            if world and world.sub then
                for _, state in ipairs(world.sub.stack) do drop(state) end
            end
        end
    end
    previous.heldZones = held
    local view = previous.view
    if view and zone and zone.detachView then zone:detachView(view) end
    if view and view.sprite then sprites[view.sprite] = nil end
    if view and view.releaseBitmaps then view:releaseBitmaps() end
    if view then view.zone = nil end
    local manager = previous.manager
    if manager and manager.npcs then
        for _, npc in ipairs(manager.npcs) do sprites[npc] = nil end
        if manager.clear then manager:clear() end
        previous.originCleared = true
    end
    if previous.player then previous.player.collisionMap = nil end
    if previous.visit then
        previous.visit.zone = nil
        previous.visit.view = nil
    end
    if previous.savedPos then previous.savedPos.zone = nil end
    previous.zone = nil
    previous.builtZone = nil
    if owner then
        owner.builtZone = nil
        owner.builtView = nil
        owner.presentationVisit = nil
        owner.savedPos = nil
    end
    currentZone = nil
    if SourceMaps and SourceMaps.releaseRetainedRuntime then SourceMaps.releaseRetainedRuntime() end
    if SourceMaps and SourceMaps._releaseTileGrids then SourceMaps._releaseTileGrids() end
    if WorldDeltas.disposeImportedCache then WorldDeltas.disposeImportedCache() end
    if SourceEvents and SourceEvents.releaseRecentContent then SourceEvents.releaseRecentContent() end
    if KantoSynth and KantoSynth.unloadAll then KantoSynth.unloadAll() end
    gfx.sprite.removeAll()
    if WorldTiles and WorldTiles.releaseRenderedImages then
        WorldTiles:releaseRenderedImages()
    end
    zone = nil
    previous.scoreReleased = true
end

-- Destination construction happens while the authoritative session still holds
-- the departing location. No root coroutine, input or sprite tick can run here.
-- The old view/actors/player remain available until captureTraversal succeeds.
function FieldTravelRuntime.fly(game, expected, plan)
    if type(WorldView.exchangePrepared) ~= "function" then
        return false, "prepared-view-handoff-not-installed"
    end
    if game.session:fieldWorldEpoch() ~= expected.epoch
        or not FieldMoves.same(WorldDeltas.export(), expected.world) then
        return false, "stale-fly-context"
    end
    local session = game.session
    local owner = game.machine:get("overworld")
    local previous = {zone = currentZone, player = game.player, manager = game.npcManager,
        view = getOverworldView(), cameraX = game.camera.x, cameraY = game.camera.y,
        builtZone = owner.builtZone, builtSession = owner.builtSession,
        visit = owner.presentationVisit, builtView = owner.builtView,
        savedPos = owner.savedPos}
    local sprites = {}
    for _, sprite in ipairs(gfx.sprite.getAllSprites()) do
        sprites[sprite] = true
    end
    local undoRuntime = WorldDeltas.checkpointRuntime()
    local undoWorld, view, player, manager, target, exchanged
    local originKey, originID, released
    local ok, result = pcall(function()
        local world = FieldWorld.reloadWorld(expected.world, {expected.position.zone_id})
        local key = WorldDeltas.zoneKey(plan.location.zone_id)
        assert(key, "Fly destination not installed")
        -- checkpointRuntime and the live cache still name the origin. Drop
        -- both before the destination definition is decoded. Apply the world
        -- after that, so its undo cannot retain the city being left.
        originKey = previous.zone and previous.zone.key
        originID = previous.zone and previous.zone.stableID
        released = true
        releaseFlyOrigin(game, owner, previous, sprites)
        local stale = undoRuntime
        undoRuntime = WorldDeltas.checkpointRuntime()
        stale = nil
        collectgarbage("collect")
        collectgarbage("collect")
        undoWorld = WorldDeltas.apply(world)
        target = assert(WorldDeltas.ensureZone(key))
        -- releaseInactive keeps whichever city currentZone names. The origin
        -- is already gone, so the destination has to be current before that
        -- pass or the cache drop frees the zone that was just built.
        currentZone = target
        target:assertEnterable()
        -- The departing view stays referenced for rollback. Pin the destination
        -- so the inactive release can drop every other cached city first.
        -- The origin view was detached above, including when the destination
        -- is this same city, so the replacement view can attach.
        local provider = WorldDeltas.definitionProvider()
        local unpin = provider and provider.owns and provider:owns(target) and provider:pin(target)
        WorldDeltas.releaseInactiveZones()
        collectgarbage("collect")
        if unpin then unpin() end
        collectgarbage("collect")
        -- Generational GC lets the tile atlas spike past the pool. Incremental
        -- collection during that build stays under it, then the session mode
        -- returns.
        collectgarbage("incremental", 110, 200, 13)
        local viewOk, viewErr = pcall(function()
            view = setmetatable({}, WorldView)
            view:init(target)
        end)
        collectgarbage("generational")
        if not viewOk then error(viewErr, 0) end
        manager = NPCManager(game)
        player = Player(plan.location.x, plan.location.y, target.collision, manager)
        player.facing = plan.location.facing
        player:updateSprite()
        game.player, game.npcManager = player, manager
        target:spawnNPCs(manager)
        manager.motion:attach(game, target, nil, false)
        local actors = manager.motion:snapshot()
        local travel = FieldTravel.enter(plan.travel, plan.location.zone_id, "walking")
        local offset = FieldWorld.transitionOffset(session:fieldWorldData().mapPalOffset,
            expected.position.zone_id, plan.location.zone_id, "map", FieldWorld.eligibleDarkMap)
        -- Strict arrival validation includes source actor reservations.
        GameSession._validateActors(game:getSessionDependencies(), actors, world, plan.location, session:flags())
        local px, py = player:getPixelCenter()
        game.camera:snapTo(px, py, target.width * TILE_SIZE, target.height * TILE_SIZE)
        game.camera:apply()
        owner.builtZone, owner.builtSession = target, session
        owner:_beginPresentationVisit(view)
        WorldView.exchangePrepared(view)
        exchanged = true
        local accepted, reason = session:captureTraversal({world = world, location = plan.location,
            actors = actors, fieldTravel = travel, fieldWorld = {version = 1, mapPalOffset = offset}})
        assert(accepted, reason)
        -- No native work, callback or fallible install remains after publication.
        return {kind = "fly", position = copy(plan.location)}
    end)
    if not ok then
        if exchanged then
            WorldView.exchangePrepared(previous.view)
        end
        if view then
            if target then
                target:detachView(view)
            end
            pcall(view.dispose, view)
        end
        if manager then
            pcall(manager.clear, manager)
        end
        for _, sprite in ipairs(gfx.sprite.getAllSprites()) do
            if not sprites[sprite] then
                pcall(sprite.remove, sprite)
            end
        end
        game.player, game.npcManager = previous.player, previous.manager
        owner.builtSession = previous.builtSession
        owner.presentationVisit, owner.builtView = previous.visit, previous.builtView
        owner.savedPos = previous.savedPos
        game.camera.x, game.camera.y = previous.cameraX, previous.cameraY
        if undoWorld then
            undoWorld()
        end
        if undoRuntime then undoRuntime() end
        collectgarbage("collect")
        local zone = previous.zone
        if zone == nil and released and originKey then
            local rebuilt, restored = pcall(WorldDeltas.ensureZone, originKey)
            if rebuilt then
                zone = restored
            end
        end
        if zone then currentZone = zone end
        owner.builtZone = zone or previous.builtZone
        if previous.player and zone then
            previous.player.collisionMap = zone.collision
            if previous.player.add then previous.player:add() end
            if previous.player.grassOverlay and previous.player.grassOverlay.add then
                previous.player.grassOverlay:add()
            end
            if previous.player.exitArrow and previous.player.exitArrow.add then
                previous.player.exitArrow:add()
            end
        end
        if previous.savedPos and zone then previous.savedPos.zone = zone end
        if previous.visit then
            previous.visit.view = previous.view
            previous.visit.zone = zone
        end
        if previous.view and not previous.view.disposed and zone then
            previous.view.zone = zone
            if previous.view.ensureBitmaps then previous.view:ensureBitmaps() end
            zone:attachView(previous.view)
        end
        if previous.originCleared and zone and previous.manager then
            zone:spawnNPCs(previous.manager)
            previous.manager.motion:attach(game, zone, nil, false)
        end
        if zone and previous.heldZones then
            for _, holder in ipairs(previous.heldZones) do holder.zone = zone end
        end
        if previous.scoreReleased and originID and KantoAudio and KantoAudio.enterMap then
            pcall(KantoAudio.enterMap, originID)
        end
        game.camera:apply()
        return false, tostring(result)
    end
    -- Cleanup cannot invalidate the now-installed visit. All old sprites are
    -- detached; any cleanup exception is reported separately, never rolled back
    -- after durable publication. It owns no further gameplay decision.
    pcall(previous.manager.clear, previous.manager)
    pcall(removePlayer, previous.player)
    pcall(previous.view.dispose, previous.view)
    owner.savedPos, owner.savedActors, owner.savedActorsSession = nil, nil, nil
    owner.fieldArrival = {fromID = expected.position.zone_id, kind = "fly"}
    -- A different city reloads its bed when the audio observer sees the new
    -- zone. The same city keeps the observer's zone id, so start that bed here.
    if previous.scoreReleased and originID and target and target.stableID == originID
        and KantoAudio and KantoAudio.enterMap then
        pcall(KantoAudio.enterMap, originID)
    elseif previous.scoreReleased and target and originID and target.stableID ~= originID then
        missedBed = true
    end
    return true, result
end
