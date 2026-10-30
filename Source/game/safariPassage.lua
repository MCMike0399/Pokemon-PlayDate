-- Transient passage transaction over the existing Player/Zone/WorldView owners.
-- No parallel world ledger or movement timer; the scene calls Player:update.
SafariPassage = {}
local gfx <const> = playdate.graphics
local requests = setmetatable({}, {__mode = "k"})
local function copy(value)
    if value == nil then
        return nil
    end
    return Party._primitive(value)
end
local function position(game)
    return {zone_id = currentZone.stableID, x = game.player.gridX, y = game.player.gridY, facing = game.player.facing}
end
local function arrival(name, warpIndex, facing)
    local descriptor = SourceMaps.descriptor(name)
    local warp = assert(descriptor.warps[warpIndex], "missing immutable Safari arrival")
    local advance = SourceMaps.isDoor(name, warp.x, warp.y) and 1 or 0
    return {zone_id = descriptor.id, x = warp.x, y = warp.y + advance, facing = facing}, descriptor.key
end
local function walkable(game, name, point, steps)
    local descriptor = SourceMaps.descriptor(name)
    local target = copy(point)
    for _, direction in ipairs(steps) do
        target.y = target.y + (direction == "up" and -1 or 1)
        assert(target.x >= 0 and target.y >= 0 and target.x < descriptor.width and target.y < descriptor.height,
            "source Safari passage outside map")
        local terrain = SourceMaps.cell(name, target.x, target.y)
        assert(terrain.collision == 0 and not descriptor.blocked[tostring(target.y * descriptor.width + target.x + 1)],
            "blocked source Safari passage")
    end
    local travel = game.session:fieldTravelData()
    travel.mode = "walking"
    game:getSessionDependencies().resolvePlayerLocation(target, WorldDeltas.export(), travel)
    return target
end
function SafariPassage.prepare(game, kind, mutation)
    if type(game.session.commitSafariPassage) ~= "function" or type(WorldView.exchangePrepared) ~= "function" then
        return nil, "safari-passage-owner-not-installed"
    end
    local called, token = pcall(function()
        assert(not game.player.isMoving, "Safari passage requires settled Player")
        local origin = position(game)
        local initial = game.session:safariData()
        local before, after, target, targetKey, targetName = {}, {}, nil, nil, nil
        if kind == "admission" then
            assert(currentZone.stableID == "pokered:SAFARI_ZONE_GATE", "Safari admission outside gate")
            local gate = SourceMaps.entry("SafariZoneGate")
            assert(origin.x == 4 + gate.padding and origin.y == 2, "source Safari worker alignment required")
            assert(mutation.kind == "admission", "admission resource plan required")
            before, after = {"up", "up"}, {"up"}
            target, targetKey = arrival("SafariZoneCenter", 2, "up")
            targetName = "SafariZoneCenter"
            walkable(game, "SafariZoneGate", origin, before)
        elseif kind == "early-exit" then
            assert(currentZone.stableID == "pokered:SAFARI_ZONE_GATE", "Safari early exit outside gate")
            assert(mutation.kind == "leave" and initial.ending == "none", "confirmed early exit plan required")
            after = {"down", "down", "down"}
            walkable(game, "SafariZoneGate", origin, after)
        elseif kind == "forced-return" then
            assert(mutation.kind == "leave" and initial.ending ~= "none", "Safari return reason required")
            target, targetKey = arrival("SafariZoneGate", 3, "down")
            targetName = "SafariZoneGate"
            after = {"down", "down", "down"}
        elseif kind == "continue" then
            assert(currentZone.stableID == "pokered:SAFARI_ZONE_GATE" and initial.active, "Safari continuation outside gate")
            local gate = SourceMaps.entry("SafariZoneGate")
            assert(origin.y == 0 and (origin.x == 3 + gate.padding or origin.x == 4 + gate.padding),
                "source Safari continuation warp required")
            target, targetKey = arrival("SafariZoneCenter", origin.x - gate.padding == 3 and 1 or 2, "up")
            targetName = "SafariZoneCenter"
            assert(mutation.kind == "check", "Safari continuation must retain resources")
        else
            error("unknown Safari passage", 0)
        end
        assert(FieldMoves.same(mutation.before, initial), "stale Safari resource plan")
        SafariGame.validatePlan(mutation)
        if target then
            walkable(game, targetName, target, after)
        end
        local token = {}
        requests[token] = {game = game, session = game.session, kind = kind, mutation = copy(mutation),
            epoch = game.session:fieldWorldEpoch(), safari = initial, inventory = game.session:inventory():toData(),
            flags = game.session:flags(), rules = RulesRNG.snapshot(), worldRNG = game.session:worldRngData(),
            origin = origin, originalPlayer = game.player, originalManager = game.npcManager, originalZone = currentZone,
            world = WorldDeltas.export(), before = before, after = after, target = target, targetKey = targetKey,
            count = 0, status = "prepared", walkToggle = game.player.walkToggle,
            cameraX = game.camera.x, cameraY = game.camera.y}
        return token
    end)
    if not called then
        return nil, tostring(token)
    end
    return token
end
function SafariPassage.preview(token)
    local request = requests[token]
    if not request or request.status ~= "prepared" then
        return nil
    end
    return {kind = request.kind, before = copy(request.before), after = copy(request.after), target = copy(request.target)}
end
function SafariPassage.valid(token)
    local request = requests[token]
    if not request or request.status ~= "prepared" then
        return false
    end
    local game = request.game
    local stage = request.stage
    return game.session == request.session and game.session:fieldWorldEpoch() == request.epoch
        and game.player == (stage and stage.player or request.originalPlayer)
        and game.npcManager == (stage and stage.manager or request.originalManager)
        and currentZone == (stage and stage.zone or request.originalZone)
        and FieldMoves.same(game.session:safariData(), request.safari)
        and FieldMoves.same(game.session:inventory():toData(), request.inventory)
        and FieldMoves.same(game.session:flags(), request.flags)
        and FieldMoves.same(RulesRNG.snapshot(), request.rules)
        and FieldMoves.same(game.session:worldRngData(), request.worldRNG)
end
-- Called only at a completed actual Player cell, never an elapsed-time estimate.
function SafariPassage.completedStep(token)
    local request = requests[token]
    assert(SafariPassage.valid(token) and not request.game.player.isMoving
        and request.game.player.stepJustFinished, "incomplete Safari passage cell")
    request.count = request.count + 1
    request.game.player.stepJustFinished = false
    request.game.player.pendingEdgeDoor, request.game.player.pendingConnection = nil, nil
end
function SafariPassage.stage(token)
    local request = requests[token]
    if not SafariPassage.valid(token) then
        return false, "stale-safari-passage"
    end
    if not request.target then
        return true
    end
    local game = request.game
    local owner = game.machine:get("overworld")
    request.previous = {view = getOverworldView(), cameraX = game.camera.x, cameraY = game.camera.y,
        builtZone = owner.builtZone, builtSession = owner.builtSession,
        visit = owner.presentationVisit, builtView = owner.builtView}
    request.undoRuntime = WorldDeltas.checkpointRuntime()
    request.sprites = {}
    for _, sprite in ipairs(gfx.sprite.getAllSprites()) do
        request.sprites[sprite] = true
    end
    local called, reason = pcall(function()
        request.candidateWorld = FieldWorld.reloadWorld(request.world, {request.originalZone.stableID})
        request.undoWorld = WorldDeltas.apply(request.candidateWorld)
        local zone = assert(WorldDeltas.ensureZone(request.targetKey))
        zone:assertEnterable()
        if zone == request.originalZone then
            zone:detachView(request.previous.view)
        end
        local stage = {zone = zone}
        request.stage = stage
        currentZone = zone
        stage.view = setmetatable({}, WorldView)
        stage.view:init(zone)
        stage.manager = NPCManager(game)
        stage.player = Player(request.target.x, request.target.y, zone.collision, stage.manager)
        stage.player.facing = request.target.facing
        stage.player:updateSprite()
        game.player, game.npcManager = stage.player, stage.manager
        zone:spawnNPCs(stage.manager)
        stage.manager.motion:attach(game, zone, nil, false)
        stage.player:setUpdatesEnabled(false)
        for _, npc in ipairs(stage.manager.npcs) do
            npc:setUpdatesEnabled(false)
        end
        local px, py = stage.player:getPixelCenter()
        game.camera:snapTo(px, py, zone.width * TILE_SIZE, zone.height * TILE_SIZE)
        game.camera:apply()
        owner.builtZone, owner.builtSession = zone, request.session
        owner:_beginPresentationVisit(stage.view)
        request.hidden = {}
        local function hide(sprite)
            if sprite then
                request.hidden[#request.hidden + 1] = {sprite = sprite, visible = sprite:isVisible()}
                sprite:setVisible(false)
            end
        end
        hide(request.previous.view.sprite)
        hide(request.originalPlayer)
        hide(request.originalPlayer.grassOverlay)
        hide(request.originalPlayer.exitArrow)
        for _, npc in ipairs(request.originalManager.npcs) do
            hide(npc)
        end
        WorldView.exchangePrepared(stage.view)
        request.exchanged = true
    end)
    if not called then
        SafariPassage.cancel(token)
        return false, tostring(reason)
    end
    return true
end
function SafariPassage._commitPlan(session, token)
    local request = requests[token]
    if not request or request.session ~= session or not SafariPassage.valid(token) then
        return nil, "stale-safari-passage"
    end
    local game = request.game
    local owner = game.machine:current()
    if not owner or owner.name ~= "safariPassage" or owner.token ~= token or not owner.active then
        return nil, "stale Safari passage owner"
    end
    if game.player.isMoving or request.count ~= #request.before + #request.after then
        return nil, "incomplete-safari-passage"
    end
    local location = position(game)
    local origin = request.target or request.origin
    local destination = copy(origin)
    for _, direction in ipairs(request.after) do
        destination.y = destination.y + (direction == "up" and -1 or 1)
        destination.facing = direction
    end
    if not FieldMoves.same(location, destination) then
        return nil, "wrong-safari-arrival"
    end
    local world = request.candidateWorld or request.world
    if not FieldMoves.same(WorldDeltas.export(), world) then
        return nil, "changed-safari-passage-world"
    end
    local travel = session:fieldTravelData()
    if request.stage then
        travel = FieldTravel.enter(travel, location.zone_id, "walking")
    end
    local offset = FieldWorld.transitionOffset(session:fieldWorldData().mapPalOffset,
        request.origin.zone_id, location.zone_id, "map", FieldWorld.eligibleDarkMap)
    -- Native enable restoration occurs before the root session publication.
    game.player:setUpdatesEnabled(true)
    for _, npc in ipairs(game.npcManager.npcs) do
        npc:setUpdatesEnabled(true)
    end
    return {mutation = copy(request.mutation), countedSteps = request.count,
        snapshot = {world = world, location = location, actors = game.npcManager.motion:snapshot(),
            fieldTravel = travel, fieldWorld = {version = 1, mapPalOffset = offset}}}
end
function SafariPassage.finish(token)
    local request = requests[token]
    if not request or request.status ~= "prepared" then
        return false
    end
    if request.session:fieldWorldEpoch() == request.epoch then
        return false, "Safari passage not committed"
    end
    request.status = "complete"
    if request.stage then
        pcall(request.originalManager.clear, request.originalManager)
        pcall(request.originalPlayer.remove, request.originalPlayer)
        pcall(request.originalPlayer.grassOverlay.remove, request.originalPlayer.grassOverlay)
        pcall(request.originalPlayer.exitArrow.remove, request.originalPlayer.exitArrow)
        pcall(request.previous.view.dispose, request.previous.view)
        local owner = request.game.machine:get("overworld")
        owner.savedPos, owner.savedActors, owner.savedActorsSession = nil, nil, nil
        owner.fieldArrival = {fromID = request.origin.zone_id, kind = "safari"}
    end
    return true
end
function SafariPassage.cancel(token)
    local request = requests[token]
    if not request or request.status ~= "prepared" then
        return false
    end
    request.status = "cancelled"
    if request.game.session ~= request.session then
        return false
    end
    local game, stage = request.game, request.stage
    if stage then
        if request.exchanged then
            WorldView.exchangePrepared(request.previous.view)
        end
        stage.zone:detachView(stage.view)
        if stage.view then
            pcall(stage.view.dispose, stage.view)
        end
        if stage.manager then
            pcall(stage.manager.clear, stage.manager)
        end
        for _, sprite in ipairs(gfx.sprite.getAllSprites()) do
            if not request.sprites[sprite] then
                pcall(sprite.remove, sprite)
            end
        end
        game.player, game.npcManager, currentZone = request.originalPlayer, request.originalManager, request.originalZone
        local owner = game.machine:get("overworld")
        owner.builtZone, owner.builtSession = request.previous.builtZone, request.previous.builtSession
        owner.presentationVisit, owner.builtView = request.previous.visit, request.previous.builtView
        game.camera.x, game.camera.y = request.previous.cameraX, request.previous.cameraY
    end
    if request.undoWorld then
        request.undoWorld()
    end
    if request.undoRuntime then
        request.undoRuntime()
    end
    if request.previous and not request.previous.view.disposed then
        request.originalZone:attachView(request.previous.view)
    end
    if not stage then
        game.camera.x, game.camera.y = request.cameraX, request.cameraY
    end
    for _, saved in ipairs(request.hidden or {}) do
        saved.sprite:setVisible(saved.visible)
    end
    local player = request.originalPlayer
    player.gridX, player.gridY, player.facing = request.origin.x, request.origin.y, request.origin.facing
    player.isMoving, player.stepJustFinished = false, false
    player.pendingEdgeDoor, player.pendingConnection = nil, nil
    player.walkToggle = request.walkToggle
    player:moveTo(player.gridX * TILE_SIZE, player.gridY * TILE_SIZE)
    player:updateSprite()
    game.camera:apply()
    return true
end


-- Root's Player recognizes ONLY these opaque source passage intents; all
-- collision remains in Player and Safari scripts gain no escort overlap rule.
function SafariPassage.beginCell(token, direction, owner)
    local request = requests[token]
    assert(SafariPassage.valid(token) and owner:isTop() and owner.active
        and owner.game == request.game and owner.token == token, "stale Safari cell owner")
    local staged = request.stage or not request.target
    local index = staged and request.count - #request.before + 1 or request.count + 1
    local expected = (staged and request.after or request.before)[index]
    assert(direction == expected, "Safari cell differs from source passage")
    local player = request.game.player
    request.intent = {owner = owner, direction = direction, x = player.gridX, y = player.gridY}
end
function SafariPassage.permits(token, player, dx, dy)
    local request = requests[token]
    if not request or not SafariPassage.valid(token) then
        return false
    end
    local intent = request.intent
    if not intent or request.game.player ~= player or not intent.owner:isTop() or not intent.owner.active
        or intent.owner.token ~= token or player.gridX ~= intent.x or player.gridY ~= intent.y
        or dx ~= 0 or dy ~= (intent.direction == "up" and -1 or 1) then
        return false
    end
    request.intent = nil
    return true
end
