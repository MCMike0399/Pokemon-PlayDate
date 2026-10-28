-- Sparse source door projection; same GameSession scene transaction as Hideout.
SilphStoryWorld = {}
local function copy(value)
    return GameSession._copy(value)
end
local function doorWorld(world, door, opened)
    return RocketHideoutStoryWorld.projectBlock(world, {map = door.map, x = door.x, y = door.y,
        keys = opened and door.open_keys or door.closed_keys})
end
function SilphStoryWorld.unlock(game, id)
    local door <const> = assert(SilphStory.door(id))
    local facing <const> = SilphStory.facingDoor(game)
    if not facing or facing.id ~= id then
        return false, "outside-source-card-key-door"
    end
    local quantity <const> = game.session:inventory():quantity("cardKey")
    if quantity == 0 then
        return false, "no-card-key"
    end
    local before <const> = WorldDeltas.export()
    local candidate <const> = doorWorld(before, door, true)
    return RocketHideoutStoryWorld.commitWorld(game, before, candidate,
        {flags = {[door.flag] = false}, items = {cardKey = quantity}},
        {flags = {[door.flag] = true}, items = {}}, "SILPH_STORY_SCENE_V1_")
end
function SilphStoryWorld.reconcile(game)
    local doors <const> = SilphStory.scenes().doors[currentZone.stableID]
    if not doors then
        return
    end
    local before <const> = WorldDeltas.export()
    local candidate = before
    local expected <const> = {flags = {}, items = {}}
    for _, door in ipairs(doors) do
        local opened <const> = game.session:questFlag(door.flag)
        expected.flags[door.flag] = opened
        candidate = doorWorld(candidate, door, opened)
    end
    local ok, reason = RocketHideoutStoryWorld.commitWorld(game, before, candidate, expected,
        {flags = {}, items = {}}, "SILPH_STORY_SCENE_V1_")
    assert(ok, reason)
end
local function floorFlag(floor)
    return "SILPH_STORY_LIFT_V1_" .. floor
end
function SilphStoryWorld.selectFloor(session, floor)
    local expected <const> = {flags = {}, items = {}}
    local changes <const> = {flags = {}, items = {}}
    local found = false
    for _, entry in ipairs(SilphStory.scenes().elevator) do
        local flag <const> = floorFlag(entry.floor)
        expected.flags[flag] = session:questFlag(flag)
        changes.flags[flag] = entry.floor == floor
        found = found or entry.floor == floor
    end
    assert(found, "source Silph elevator floor required")
    if expected.flags[floorFlag(floor)] then
        return true
    end
    return session:transact(expected, changes)
end
function SilphStoryWorld.enterLift(session, zoneID)
    for _, entry in ipairs(SilphStory.scenes().elevator) do
        if entry.map_id == zoneID then
            return SilphStoryWorld.selectFloor(session, entry.floor)
        end
    end
    return false, "unknown-source-Silph-elevator-origin"
end
function SilphStoryWorld.resolveDoor(game, door)
    if currentZone.stableID ~= "pokered:SILPH_CO_ELEVATOR" then
        return door
    end
    assert(door.source_event_id == "pokered:SILPH_CO_ELEVATOR:warps:1"
        or door.source_event_id == "pokered:SILPH_CO_ELEVATOR:warps:2", "unknown Silph elevator exit")
    for _, entry in ipairs(SilphStory.scenes().elevator) do
        if game.session:questFlag(floorFlag(entry.floor)) then
            local result <const> = copy(door)
            result.to = entry.map_id
            result.toX = entry.destination.x + SilphStory.padding(entry.map_id)
            result.toY = entry.destination.y
            return result
        end
    end
    error("missing persisted Silph elevator destination")
end
