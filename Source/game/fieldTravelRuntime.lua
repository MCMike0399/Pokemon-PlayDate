-- Couples existing traversal/session owners to completed runtime movement.
FieldTravelRuntime = {}
local gfx <const> = playdate.graphics
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
        visit = owner.presentationVisit, builtView = owner.builtView}
    local sprites = {}
    for _, sprite in ipairs(gfx.sprite.getAllSprites()) do
        sprites[sprite] = true
    end
    local undoRuntime = WorldDeltas.checkpointRuntime()
    local undoWorld, view, player, manager, target, exchanged
    local ok, result = pcall(function()
        local world = FieldWorld.reloadWorld(expected.world, {expected.position.zone_id})
        undoWorld = WorldDeltas.apply(world)
        local key = WorldDeltas.zoneKey(plan.location.zone_id)
        if plan.location.zone_id == "pallet_town" then
            key = "pallet_town"
        end
        assert(key, "Fly destination not installed")
        target = assert(WorldDeltas.ensureZone(key))
        target:assertEnterable()
        -- Same-city Fly must also stage a replacement view without disposing it.
        if target == previous.zone then
            target:detachView(previous.view)
        end
        currentZone = target
        view = setmetatable({}, WorldView)
        view:init(target)
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
        game.player, game.npcManager, currentZone = previous.player, previous.manager, previous.zone
        owner.builtZone, owner.builtSession = previous.builtZone, previous.builtSession
        owner.presentationVisit, owner.builtView = previous.visit, previous.builtView
        game.camera.x, game.camera.y = previous.cameraX, previous.cameraY
        if undoWorld then
            undoWorld()
        end
        undoRuntime()
        if previous.view and not previous.view.disposed then
            previous.zone:attachView(previous.view)
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
    return true, result
end
