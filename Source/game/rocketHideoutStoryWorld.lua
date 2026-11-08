-- Pure source-block projection plus the existing atomic GameSession scene seam.
-- No mutable Zone, delta ledger or alternate session state is owned here.
RocketHideoutStoryWorld = {}
local function copy(value)
    return GameSession._copy(value)
end
local function equal(a, b)
    -- Identical tables are the same world. A shared export must not recurse.
    if a == b then
        return true
    end
    if type(a) ~= type(b) then
        return false
    end
    if type(a) ~= "table" then
        return a == b
    end
    for key, value in pairs(a) do
        if not equal(value, b[key]) then
            return false
        end
    end
    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end
    return true
end
function RocketHideoutStoryWorld.project(world, effect)
    return RocketHideoutStoryWorld.projectBlock(world, assert(RocketHideoutStory.scenes().terrain[effect]))
end
local function mappedRecord(world, zoneID)
    for _, value in ipairs(world.zones) do
        if value.zone_id == zoneID then
            return value
        end
    end
end
local function applyBlock(result, spec)
    local entry <const> = SourceMaps.entry(spec.map)
    local descriptor <const> = WorldDeltas.definitionProvider():descriptor(entry.id)
    local record = mappedRecord(result, entry.id)
    if not record then
        record = {schema = 1, zone_id = entry.id, definition_revision = descriptor.revision, tiles = {}, tile_count = 0}
        result.zones[#result.zones + 1] = record
    end
    local cells = {}
    for _, tile in ipairs(record.tiles) do
        cells[tile.y * entry.width + tile.x + 1] = tile
    end
    for quadrant = 0, 3 do
        local x <const> = spec.x * 2 + quadrant % 2 + entry.padding
        local y <const> = spec.y * 2 + quadrant // 2
        local key <const> = spec.keys[quadrant + 1]
        assert(SourceMaps.hasTile(key), "content atlas lacks source Hideout block")
        local index <const> = y * entry.width + x + 1
        if SourceMaps.cell(spec.map, x, y).key == key then
            cells[index] = nil
        else
            cells[index] = {x = x, y = y, key = key}
        end
    end
    record.tiles = {}
    for _, tile in pairs(cells) do
        record.tiles[#record.tiles + 1] = tile
    end
    table.sort(record.tiles, function(a, b)
        return a.y == b.y and a.x < b.x or a.y < b.y
    end)
    record.tile_count = #record.tiles
    if record.tile_count == 0 then
        for index, value in ipairs(result.zones) do
            if value == record then
                table.remove(result.zones, index)
                break
            end
        end
    end
    table.sort(result.zones, function(a, b)
        return a.zone_id < b.zone_id
    end)
    result.zone_count = #result.zones
end
-- True when this block is already the exported world, so no copy is required.
local function blockMatches(world, spec)
    local entry <const> = SourceMaps.entry(spec.map)
    -- Keep the unknown-map failure even when the floor already matches.
    WorldDeltas.definitionProvider():descriptor(entry.id)
    local record = mappedRecord(world, entry.id)
    local have = {}
    if record then
        for _, tile in ipairs(record.tiles) do
            have[tile.y * entry.width + tile.x + 1] = tile.key
        end
    end
    for quadrant = 0, 3 do
        local x <const> = spec.x * 2 + quadrant % 2 + entry.padding
        local y <const> = spec.y * 2 + quadrant // 2
        local key <const> = spec.keys[quadrant + 1]
        assert(SourceMaps.hasTile(key), "content atlas lacks source Hideout block")
        local index <const> = y * entry.width + x + 1
        local sourceKey <const> = SourceMaps.cell(spec.map, x, y).key
        if sourceKey == key then
            if have[index] ~= nil then
                return false
            end
        elseif have[index] ~= key then
            return false
        end
    end
    return true
end
function RocketHideoutStoryWorld.projectBlock(world, spec)
    local result <const> = copy(world)
    applyBlock(result, spec)
    return result
end
-- Several blocks share one owned copy. A floor that already matches is the
-- exported table itself; callers must not mutate that result.
function RocketHideoutStoryWorld.projectBlocks(world, specs)
    for _, spec in ipairs(specs) do
        if not blockMatches(world, spec) then
            local result <const> = copy(world)
            for _, item in ipairs(specs) do
                applyBlock(result, item)
            end
            return result
        end
    end
    return world
end
function RocketHideoutStoryWorld.commit(game, effect, expected, changes)
    local before <const> = WorldDeltas.export()
    local candidate <const> = RocketHideoutStoryWorld.project(before, effect)
    return RocketHideoutStoryWorld.commitWorld(game, before, candidate, expected, changes, "ROCKET_HIDEOUT_SCENE_V1_")
end
function RocketHideoutStoryWorld.commitWorld(game, before, candidate, expected, changes, prefix)
    if equal(before, candidate) and not next(changes.flags) then
        return true
    end
    local session <const> = game.session
    local a <const> = prefix .. "TURN_A"
    local b <const> = prefix .. "TURN_B"
    expected.flags[a], expected.flags[b] = session:questFlag(a), session:questFlag(b)
    changes.flags[a], changes.flags[b] = not expected.flags[a], expected.flags[a]
    local random, token = session:forkWorldRNG()
    return session:transactScene(expected, changes, {
        token = token, beforeWorld = before, world = candidate,
        beforeRng = session:worldRngData(), rng = random:toData(),
        location = {zone_id = currentZone.stableID, x = game.player.gridX,
            y = game.player.gridY, facing = game.player.facing},
    })
end
function RocketHideoutStoryWorld.openEntrance(game)
    return RocketHideoutStoryWorld.commit(game, "entrance-open", {
        flags = {EVENT_FOUND_ROCKET_HIDEOUT = game.session:questFlag("EVENT_FOUND_ROCKET_HIDEOUT")}, items = {},
    }, {flags = {EVENT_FOUND_ROCKET_HIDEOUT = true}, items = {}})
end
function RocketHideoutStoryWorld.reconcile(game)
    local session <const> = game.session
    local expected <const> = {flags = {}, trainers = {}, items = {}}
    local changes <const> = {flags = {}, items = {}}
    local effect
    if currentZone.stableID == "pokered:GAME_CORNER" then
        local found <const> = session:questFlag("EVENT_FOUND_ROCKET_HIDEOUT")
        expected.flags.EVENT_FOUND_ROCKET_HIDEOUT = found
        effect = found and "entrance-open" or "entrance-closed"
    elseif currentZone.stableID == "pokered:ROCKET_HIDEOUT_B1F" then
        local trainer <const> = "pokered:ROCKET_HIDEOUT_B1F:objects:5"
        expected.trainers[trainer] = session:trainerDefeated(trainer)
        expected.flags.EVENT_ENTERED_ROCKET_HIDEOUT = session:questFlag("EVENT_ENTERED_ROCKET_HIDEOUT")
        effect = (expected.trainers[trainer] or expected.flags.EVENT_ENTERED_ROCKET_HIDEOUT) and "b1-open" or "b1-closed"
        -- Preserve the source CheckEventHL typo: do not manufacture an entered flag.
    elseif currentZone.stableID == "pokered:ROCKET_HIDEOUT_B4F" then
        local left <const> = "pokered:ROCKET_HIDEOUT_B4F:objects:2"
        local right <const> = "pokered:ROCKET_HIDEOUT_B4F:objects:3"
        expected.trainers[left], expected.trainers[right] = session:trainerDefeated(left), session:trainerDefeated(right)
        local unlocked <const> = session:questFlag("EVENT_ROCKET_HIDEOUT_4_DOOR_UNLOCKED")
        expected.flags.EVENT_ROCKET_HIDEOUT_4_DOOR_UNLOCKED = unlocked
        if unlocked or expected.trainers[left] and expected.trainers[right] then
            effect = "b4-open"
            if not unlocked then
                changes.flags.EVENT_ROCKET_HIDEOUT_4_DOOR_UNLOCKED = true
            end
        else
            effect = "b4-closed"
        end
    end
    if effect then
        local ok, reason = RocketHideoutStoryWorld.commit(game, effect, expected, changes)
        assert(ok, reason)
    end
end
