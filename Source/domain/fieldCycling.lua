-- Source bicycle/status policy. Session owns the movement value and source bit.
FieldCycling = {}
FieldCycling.FLAG = "pokered:status6:BIT_ALWAYS_ON_BIKE"
local cached

local function policy()
    if not cached then
        local record = assert(json.decodeFile("data/fieldGear.json"))
        assert(record.schema == 1 and record.source_revision == "af519899719f0754965776faac0e836a3b906e6d",
            "unverified field gear data")
        cached = record.bicycle
    end
    return cached
end

function FieldCycling.allowed(map, tileset)
    for _, name in ipairs(policy().maps) do
        if name == map then
            return true
        end
    end
    for _, name in ipairs(policy().tilesets) do
        if name == tileset then
            return true
        end
    end
    return false
end

function FieldCycling.toggle(travel, forced, hasBicycle, map, tileset)
    assert(type(forced) == "boolean" and type(hasBicycle) == "boolean", "explicit bicycle ownership/status required")
    if not hasBicycle then
        return nil, "bicycle-not-in-bag"
    end
    local after = FieldTravel.normalize(travel)
    if after.mode == "surfing" then
        return nil, "not-time-to-cycle"
    end
    if forced then
        return nil, "cannot-get-off-here"
    end
    if after.mode == "bicycle" then
        after.mode = "walking"
    elseif FieldCycling.allowed(map, tileset) then
        after.mode = "bicycle"
    else
        return nil, "no-cycling-allowed"
    end
    return {kind = "bicycle", travel = after, forced = forced}
end

-- sourceX is unpadded. Only the four pinned road-entry cells set the source bit.
-- Gate map scripts clear it on entry; ordinary map/battle returns retain it.
function FieldCycling.enter(travel, forced, hasBicycle, map, tileset, sourceX, sourceY, reason)
    assert(type(forced) == "boolean" and type(hasBicycle) == "boolean", "explicit bicycle ownership/status required")
    assert(reason == "map" or reason == "continue" or reason == "blackout" or reason == "escape" or reason == "fly",
        "explicit bicycle entry reason required")
    local after = FieldTravel.normalize(travel)
    if reason == "blackout" or reason == "escape" or reason == "fly" then
        after.mode = "walking"
        return {kind = "bicycle-entry", travel = after, forced = false}
    end
    for _, gate in ipairs(policy().gates) do
        if gate.map == map then
            forced = false
        end
    end
    for _, cell in ipairs(policy().forced_entries) do
        if map == cell.map and sourceX == cell.x and sourceY == cell.y then
            if not hasBicycle then
                return nil, "bicycle-required"
            end
            forced = true
            after.mode = "bicycle"
        end
    end
    if forced then
        if not hasBicycle or not FieldCycling.allowed(map, tileset) then
            return nil, "invalid-forced-bicycle-state"
        end
        after.mode = "bicycle"
    elseif after.mode == "bicycle" and not FieldCycling.allowed(map, tileset) then
        after.mode = "walking"
    end
    return {kind = "bicycle-entry", travel = after, forced = forced}
end

-- Read by the existing Player input owner only while exploration is settled.
-- A/B brake the automatic descent. D-pad input retains its existing priority.
function FieldCycling.motion(travel, map, held, scripted, trainer)
    local mode = FieldTravel.normalize(travel).mode
    local steering = held.up or held.left or held.right
    local downhill = map == "ROUTE_17" and not scripted and not trainer
        and not (steering or held.down or held.a or held.b)
    local accelerated = mode == "bicycle" and not scripted
        and (map ~= "ROUTE_17" or not steering)
    return {automatic = downhill and "down" or false, accelerated = accelerated}
end

-- Let SourceEvents/EventState own the guard dialogue and bounded return walk.
-- This gives the existing owner the source stop/return path, not a new NPC loop.
function FieldCycling.gate(map, sourceX, sourceY, hasBicycle)
    if hasBicycle then
        return nil
    end
    for _, gate in ipairs(policy().gates) do
        if gate.map == map then
            for index, cell in ipairs(gate.stops) do
                if cell.x == sourceX and cell.y == sourceY then
                    local steps = {}
                    for _ = 2, index do
                        steps[#steps + 1] = "up"
                    end
                    return {kind = "bicycle-gate", approach = steps, return_direction = gate.return_direction}
                end
            end
        end
    end
    return nil
end
