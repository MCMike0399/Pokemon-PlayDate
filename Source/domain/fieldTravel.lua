-- Blue traversal values and plans. GameSession retains the only durable copy.
-- This module never changes terrain, actors, inventory, PP, or RNG.
FieldTravel = {}
local revision <const> = "af519899719f0754965776faac0e836a3b906e6d"
local directions <const> = {up = {0, -1}, down = {0, 1}, left = {-1, 0}, right = {1, 0}}
local badges <const> = {surf = "soul", strength = "rainbow", fly = "thunder"}
local cached

local function copy(value)
    return Party._primitive(value)
end

local function data()
    if not cached then
        cached = assert(json.decodeFile("data/fieldTravel.json"))
        assert(cached.schema == 1 and cached.source_revision == revision, "unverified traversal data")
    end
    return cached
end

function FieldTravel.empty()
    return {version = 1, mode = "walking", strength = false, visited = {}}
end

function FieldTravel.normalize(value)
    GameSession._object(value, {version = true, mode = true, strength = true, visited = true})
    assert(value.version == 1, "unsupported field travel version")
    assert(value.mode == "walking" or value.mode == "surfing" or value.mode == "bicycle", "invalid travel mode")
    assert(type(value.strength) == "boolean", "invalid Strength state")
    assert(Party._array(value.visited, 11), "invalid visited cities")
    local allowed, seen, result = {}, {}, copy(value)
    for _, entry in ipairs(data().fly) do
        allowed[entry.id] = true
    end
    for _, id in ipairs(value.visited) do
        assert(allowed[id] and not seen[id], "unknown or duplicate Fly city")
        seen[id] = true
    end
    table.sort(result.visited)
    return result
end

function FieldTravel.known(mon)
    local result = {}
    for _, key in ipairs(mon and mon.moves or {}) do
        if badges[key] then
            result[#result + 1] = key
        end
    end
    return result
end

function FieldTravel.canUse(session, mon, key)
    if not badges[key] then
        return false, "unsupported-field-move"
    end
    if Party._owner(mon) ~= session:party() or not mon:hasMove(key) then
        return false, "move-not-known"
    end
    if not session:hasBadge(badges[key]) then
        return false, "badge-required"
    end
    if mon.pendingEvolution or #mon:getPendingMoveChoices() > 0 then
        return false, "progression-pending"
    end
    -- Source field moves permit fainted users and never consume battle PP.
    return true
end

-- Call only on a real map entry, including Continue/reload; never on overlays
-- or battle returns. carriedMode is an explicit result from the transition owner.
function FieldTravel.enter(value, zoneID, carriedMode)
    local result = FieldTravel.normalize(value)
    result.mode = carriedMode or "walking"
    result.strength = false
    for _, entry in ipairs(data().fly) do
        if entry.id == zoneID then
            local found = false
            for _, id in ipairs(result.visited) do
                found = found or id == zoneID
            end
            if not found then
                result.visited[#result.visited + 1] = zoneID
            end
        end
    end
    return FieldTravel.normalize(result)
end

function FieldTravel.destinations(value)
    local visited, result = {}, {}
    for _, id in ipairs(FieldTravel.normalize(value).visited) do
        visited[id] = true
    end
    for _, entry in ipairs(data().fly) do
        if visited[entry.id] then
            result[#result + 1] = copy(entry)
        end
    end
    return result
end

function FieldTravel.strength(value)
    local result = FieldTravel.normalize(value)
    result.strength = true
    return {kind = "strength", travel = result}
end

local function legalCell(cell)
    return cell and cell.binding_blocked == false and cell.adapter_padding ~= true
        and cell.occupied == false
end

local function water(cell)
    return cell.water_candidate == true and cell.foot_tile == 0x14
end

function FieldTravel.surfSurface(cell, tileset)
    local supported = false
    for _, name in ipairs(data().water_tilesets) do
        supported = supported or name == tileset
    end
    return supported and (cell.foot_tile == 0x14
        or tileset ~= "SHIP_PORT" and (cell.foot_tile == 0x32 or cell.foot_tile == 0x48))
end

local function pairBlocked(tileset, from, to)
    for _, pair in ipairs(data().water_pairs) do
        if pair.tileset == tileset and (pair.a == from and pair.b == to or pair.b == from and pair.a == to) then
            return true
        end
    end
    return false
end

-- Cells are source terrain observations, not collision overrides. The controller
-- supplies occupancy and current-world metadata, and rechecks before completion.
function FieldTravel.surf(value, position, from, target, tileset, restrictions)
    local travel = FieldTravel.normalize(value)
    if not legalCell(from) or not legalCell(target) then
        return nil, "blocked-surf-target"
    end
    if restrictions.forcedBicycle then
        return nil, "cycling-is-fun"
    end
    if restrictions.currentTooFast then
        return nil, "current-too-fast"
    end
    if pairBlocked(tileset, from.foot_tile, target.foot_tile) then
        return nil, "blocked-water-pair"
    end
    if travel.mode == "surfing" then
        if not target.land_passable or water(target) then
            return nil, "no-place-to-get-off"
        end
        travel.mode = "walking"
    else
        if not FieldTravel.surfSurface(target, tileset) then
            return nil, "no-surfing-here"
        end
        travel.mode = "surfing"
    end
    local direction = assert(directions[position.facing], "invalid field facing")
    local destination = copy(position)
    destination.x = destination.x + direction[1]
    destination.y = destination.y + direction[2]
    return {kind = "surf", travel = travel, location = destination}
end

-- Player uses this for every settled surfing step, including automatic landing.
function FieldTravel.surfStep(value, position, from, target, tileset)
    local travel = FieldTravel.normalize(value)
    if travel.mode ~= "surfing" then
        return nil, "not-surfing"
    end
    if not legalCell(from) or not legalCell(target)
        or pairBlocked(tileset, from.foot_tile, target.foot_tile) then
        return nil, "blocked-surf-target"
    end
    if not FieldTravel.surfSurface(target, tileset) then
        return FieldTravel.surf(value, position, from, target, tileset, {})
    end
    local direction = assert(directions[position.facing], "invalid field facing")
    local destination = copy(position)
    destination.x = destination.x + direction[1]
    destination.y = destination.y + direction[2]
    return {kind = "surf-step", travel = travel, location = destination}
end

-- Only visited city maps appear, even though special_warps also has Route4/10.
-- Arrival resolution uses existing provider/slice validation and authored adapters.
function FieldTravel.fly(value, position, destinationID, outside, resolveArrival)
    if outside ~= true then
        return nil, "cannot-fly-here"
    end
    for _, entry in ipairs(FieldTravel.destinations(value)) do
        if entry.id == destinationID then
            local destination, reason = resolveArrival(copy(entry))
            if not destination then
                return nil, reason or "fly-destination-unavailable"
            end
            assert(destination.zone_id == entry.id, "wrong Fly arrival map")
            local travel = FieldTravel.normalize(value)
            travel.mode = "walking"
            travel.strength = false
            return {kind = "fly", travel = travel, location = copy(destination)}
        end
    end
    return nil, "unvisited-fly-destination"
end

-- NPCMotion must lease/animate/commit the actual source actor. A boulder is
-- never drawn into tile deltas. Scripts own holes/switches after the settled push.
-- heldAttempts reproduces source's requirement to try pushing twice.
function FieldTravel.push(value, position, actor, target, heldAttempts)
    if not FieldTravel.normalize(value).strength then
        return nil, "strength-required"
    end
    if not actor or actor.source_sprite ~= "SPRITE_BOULDER" or actor.movement_byte_2 ~= 0x10 then
        return nil, "not-a-source-boulder"
    end
    local direction = assert(directions[position.facing], "invalid field facing")
    if actor.x ~= position.x + direction[1] or actor.y ~= position.y + direction[2] then
        return nil, "boulder-not-in-front"
    end
    if not Party._integer(heldAttempts, 2, 65535) then
        return nil, "push-again"
    end
    if not legalCell(target) or not target.land_passable or target.pair_blocked ~= false
        or target.protected ~= false then
        return nil, "blocked-boulder-target"
    end
    return {
        kind = "push-boulder", actor_id = actor.id,
        from = {x = actor.x, y = actor.y},
        to = {x = actor.x + direction[1], y = actor.y + direction[2]},
        facing = position.facing
    }
end
