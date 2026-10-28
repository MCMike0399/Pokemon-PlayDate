-- Lifecycle policy over existing WorldDeltas and GameSession transactions.
-- No map geometry, progression flags, render state or second world ledger.
FieldWorld = {}
local revision <const> = "af519899719f0754965776faac0e836a3b906e6d"
local function copy(value)
    return GameSession._copy(value)
end

local function same(a, b)
    return FieldMoves.same(a, b)
end

local function descriptor(id)
    local provider = WorldDeltas.definitionProvider()
    if not provider or not provider:hasID(id) then
        return nil
    end
    local d = provider:descriptor(id)
    if d.revision ~= revision then
        return nil
    end
    return d
end

local function sourceKey(d, x, y)
    local index = assert(tonumber(d.tile_rows[y + 1]:sub(x * 2 + 1, x * 2 + 2), 16))
    return assert(d.palette[index])
end

local function candidateKey(world, d, x, y)
    for _, zone in ipairs(world.zones) do
        if zone.zone_id == d.id then
            for _, tile in ipairs(zone.tiles) do
                if tile.x == x and tile.y == y then
                    return tile.key
                end
            end
        end
    end
    return sourceKey(d, x, y)
end

-- Only an exact restored, pinned Cut block may contain a blocked player.
-- No collision value is changed, even in the candidate. Immutable descriptor
-- slice, bounds and binding checks stay strict; checkpoints/actors stay strict.
function FieldWorld.resolvePlayerLocation(position, world, options)
    local ok, result = pcall(WorldDeltas.resolveLocation, position, world, options)
    if ok then
        return result
    end
    local originalError = result
    -- Source StepOutFromDoor intentionally bypasses collision for one down
    -- step. Root's immutable helper identifies only exact supported arrivals.
    local arrival = descriptor(position.zone_id)
    if arrival and ((SourceMaps.isDoorArrival and SourceMaps.isDoorArrival(arrival.name, position.x, position.y))
        or (SaffronGuards and SaffronGuards.isCounterArrival(position))) then
        local normalized = WorldDeltas.validate(world)
        GameSession._object(position, {zone_id = true, x = true, y = true, facing = true})
        assert(options and options.sliceZones and options.sliceZones[arrival.id] == true, "unsupported door arrival slice")
        assert(Party._integer(position.x, 0, arrival.width - 1)
            and Party._integer(position.y, 0, arrival.height - 1), "invalid door arrival bounds")
        assert(position.facing == "up" or position.facing == "down"
            or position.facing == "left" or position.facing == "right", "invalid door arrival facing")
        assert(not arrival.blocked[tostring(position.y * arrival.width + position.x + 1)], "blocked door arrival binding")
        assert(candidateKey(normalized, arrival, position.x, position.y) == sourceKey(arrival, position.x, position.y),
            "changed source door arrival terrain")
        return copy(position)
    end
    local spec = FieldMoves.data().maps[position.zone_id]
    local d = spec and descriptor(position.zone_id)
    if not d or d.name ~= spec.name or d.source_width ~= spec.width or d.height ~= spec.height then
        error(originalError, 0)
    end
    world = WorldDeltas.validate(world)
    for _, site in ipairs(spec.sites) do
        local target, exact = nil, true
        for _, cell in ipairs(site.cells) do
            local x = cell.x + d.padding
            if sourceKey(d, x, cell.y) ~= cell.before or candidateKey(world, d, x, cell.y) ~= cell.before then
                exact = false
            end
            if x == position.x and cell.y == position.y and cell.before ~= cell.after
                and FieldMoves.tile(cell.before).collision == 1 and FieldMoves.tile(cell.after).collision == 0 then
                target = cell
            end
        end
        if exact and target then
            GameSession._object(position, {zone_id = true, x = true, y = true, facing = true})
            assert(options and options.sliceZones and options.sliceZones[d.id] == true, "unsupported Cut slice")
            assert(Party._integer(position.x, 0, d.width - 1)
                and Party._integer(position.y, 0, d.height - 1), "invalid Cut position")
            assert(position.facing == "up" or position.facing == "down"
                or position.facing == "left" or position.facing == "right", "invalid Cut facing")
            assert(not d.blocked[tostring(position.y * d.width + position.x + 1)], "blocked Cut binding")
            return copy(position)
        end
    end
    error(originalError, 0)
end

function FieldWorld.reloadWorld(world, ids)
    local candidate = WorldDeltas.validate(world)
    for _, id in ipairs(ids) do
        local d = descriptor(id)
        if d and FieldMoves.data().maps[id] then
            candidate = FieldMoves.reloadWorld(candidate, id, d.padding)
        end
    end
    return WorldDeltas.validate(candidate)
end

-- Inactive candidate only. installSession owns atomic publication and actor/
-- player reconstruction; a failed install cannot mutate the previous session.
function FieldWorld.prepareContinue(candidate)
    local ids = {}
    for id in pairs(FieldMoves.data().maps) do
        ids[#ids + 1] = id
    end
    table.sort(ids)
    local ok, world = pcall(FieldWorld.reloadWorld, candidate:worldData(), ids)
    if not ok then
        return false, tostring(world)
    end
    local travel = FieldTravel.enter(candidate:fieldTravelData(), candidate:location().zone_id,
        candidate:fieldTravelData().mode)
    return candidate:captureTraversal({world = world, location = candidate:location(),
        actors = candidate:actorData(), fieldTravel = travel})
end

-- Native apply can fail via WorldView; session validation can reject afterward.
-- Neither path changes session identity, actors, player position or RNG.
function FieldWorld.commit(game, expected, snapshot)
    if not same(WorldDeltas.export(), expected) then
        return false, "stale-world"
    end
    local session = game.session
    local undoRuntime = WorldDeltas.checkpointRuntime()
    local ok, undoWorld = pcall(WorldDeltas.apply, snapshot.world)
    if not ok then
        undoRuntime()
        return false, tostring(undoWorld)
    end
    local called, accepted, reason = pcall(session.captureTraversal, session, snapshot)
    if not called or not accepted then
        undoWorld()
        undoRuntime()
        return false, tostring(called and reason or accepted)
    end
    return true
end

-- Declared source-map eligibility. Absent Rock Tunnel is never synthesized.
function FieldWorld.eligibleDarkMap(id, resolveDescriptor)
    for _, eligible in ipairs(FieldMoves.data().dark_maps) do
        if eligible == id then
            local d = (resolveDescriptor or descriptor)(id)
            return d ~= nil and d.id == id and d.revision == revision
        end
    end
    return false
end

function FieldWorld.transitionOffset(offset, fromID, toID, reason, eligible)
    assert(offset == 0 or offset == 6, "invalid palette offset")
    assert(reason == "map" or reason == "reload" or reason == "escape" or reason == "blackout",
        "explicit field transition reason required")
    if reason == "escape" or reason == "blackout" then
        return 0
    end
    if not eligible(toID) then
        return 0
    end
    if eligible(fromID) then
        return offset
    end
    -- Source only sets six on outside entry into 1F. Other entry is unsupported.
    assert(toID == "pokered:ROCK_TUNNEL_1F", "unsupported Rock Tunnel outside entry")
    return 6
end

-- Called by the lifecycle owner with the *departing* visit, before rebuilding.
-- Battle/menu returns do not call this. Target actors are already owned values.
function FieldWorld.enter(game, fromID, position, actors, reason)
    local expected = WorldDeltas.export()
    local ok, world = pcall(FieldWorld.reloadWorld, expected, {fromID})
    if not ok then
        return false, tostring(world)
    end
    local prepared, offset = pcall(FieldWorld.transitionOffset, game.session:fieldWorldData().mapPalOffset,
        fromID, position.zone_id, reason, FieldWorld.eligibleDarkMap)
    if not prepared then
        return false, tostring(offset)
    end
    local mode = game.session:fieldTravelData().mode
    if reason == "escape" or reason == "blackout" then
        mode = "walking"
    elseif mode == "surfing" then
        local cell, d = FieldTravelWorld.cell(position, world, game.sessionLocationPolicy)
        if not cell or not FieldTravel.surfSurface(cell, d.tileset.constant) then
            mode = "walking"
        end
    end
    local travel = FieldTravel.enter(game.session:fieldTravelData(), position.zone_id, mode)
    return FieldWorld.commit(game, expected, {
        fieldTravel = travel,
        world = world,
        location = position,
        actors = actors,
        fieldWorld = {version = 1, mapPalOffset = offset}
    })
end

-- epoch is allocated by GameSession on creation/traversal/CAS, never by read.
function FieldWorld.darknessAdapter(resolveDescriptor)
    assert(resolveDescriptor == nil or type(resolveDescriptor) == "function", "declared source map adapter required")
    local adapter = {}
    function adapter:read(game)
        local id = currentZone and currentZone.stableID
        if not id or game.session:location().zone_id ~= id or not FieldWorld.eligibleDarkMap(id, resolveDescriptor) then
            return nil
        end
        return {
            zone_id = id,
            source_revision = revision,
            offset = game.session:fieldWorldData().mapPalOffset,
            epoch = game.session:fieldWorldEpoch()
        }
    end
    function adapter:clear(game, expected)
        local input = self:read(game)
        if not input or input.offset ~= 6 or not same(input, expected) then
            return false, "stale-darkness"
        end
        return game.session:clearFieldDarkness(expected.epoch)
    end
    return adapter
end
