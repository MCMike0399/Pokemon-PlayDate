-- Source terrain projection over the existing definition provider and delta set.
-- No Zone allocation, rendering, collision mutation, or second world ledger.
FieldTravelWorld = {}
local revision <const> = "af519899719f0754965776faac0e836a3b906e6d"
local compact

local function data()
    if not compact then
        compact = SourceMaps.compact()
    end
    return compact
end

function FieldTravelWorld.cell(position, world, options)
    local provider = WorldDeltas.definitionProvider()
    if not provider or not provider:hasID(position.zone_id) then
        return nil, "source-travel-surface-unavailable"
    end
    if not options or not options.sliceZones or options.sliceZones[position.zone_id] ~= true then
        return nil, "travel-map-outside-slice"
    end
    local descriptor = provider:descriptor(position.zone_id)
    if descriptor.revision ~= revision or not Party._integer(position.x, 0, descriptor.width - 1)
        or not Party._integer(position.y, 0, descriptor.height - 1) then
        return nil, "invalid-travel-position"
    end
    local index = position.y * descriptor.width + position.x + 1
    local palette = tonumber(descriptor.tile_rows[position.y + 1]:sub(position.x * 2 + 1, position.x * 2 + 2), 16)
    local key = assert(descriptor.palette[palette])
    for _, zone in ipairs(WorldDeltas.validate(world).zones) do
        if zone.zone_id == position.zone_id then
            for _, tile in ipairs(zone.tiles) do
                if tile.x == position.x and tile.y == position.y then
                    key = tile.key
                end
            end
        end
    end
    -- Authored replacement keys need their own terrain contract; no fallback.
    local tile = data().tiles[key]
    if not tile then
        return nil, "source-travel-tile-unavailable"
    end
    local cell = Party._primitive(tile.terrain)
    cell.binding_blocked = descriptor.blocked[tostring(index)] ~= nil
    return cell, descriptor
end

-- Session/codec pass candidate mode before validating candidate location. A
-- water exception can never validate checkpoints or silently alter collisions.
function FieldTravelWorld.resolvePlayerLocation(position, world, options, travel)
    travel = FieldTravel.normalize(travel)
    if travel.mode ~= "surfing" then
        return FieldWorld.resolvePlayerLocation(position, world, options)
    end
    GameSession._object(position, {zone_id = true, x = true, y = true, facing = true})
    assert(position.facing == "up" or position.facing == "down"
        or position.facing == "left" or position.facing == "right", "invalid surfing facing")
    local cell, descriptor = FieldTravelWorld.cell(position, world, options)
    assert(cell, descriptor)
    assert(not cell.binding_blocked and not cell.adapter_padding
        and FieldTravel.surfSurface(cell, descriptor.tileset.constant), "surfing save requires source water or shore")
    return Party._primitive(position)
end

function FieldTravelWorld.outside(zoneID)
    if zoneID == "pallet_town" then
        return true
    end
    local provider = WorldDeltas.definitionProvider()
    if not provider or not provider:hasID(zoneID) then
        return false
    end
    -- CheckIfInOutsideMap uses tilesets, including PLATEAU for Route23/Indigo.
    local tileset = provider:descriptor(zoneID).tileset.constant
    return tileset == "OVERWORLD" or tileset == "PLATEAU"
end

function FieldTravelWorld.flyArrival(entry, world, options)
    if entry.id == "pallet_town" then
        -- Authored Pallet's existing reviewed home/checkpoint cell is (5,6).
        local position = {zone_id = "pallet_town", x = entry.x, y = entry.y, facing = "down"}
        local ok, result = pcall(WorldDeltas.resolveLocation, position, world, options)
        if ok then
            return result
        end
        return nil, "pallet-fly-arrival-unavailable"
    end
    local provider = WorldDeltas.definitionProvider()
    if not provider or not provider:hasID(entry.id) then
        return nil, "fly-map-not-installed"
    end
    local descriptor = provider:descriptor(entry.id)
    if descriptor.revision ~= revision or descriptor.source_map_constant ~= entry.source_map then
        return nil, "fly-source-map-mismatch"
    end
    local position = {zone_id = entry.id, x = entry.x + descriptor.padding, y = entry.y, facing = "down"}
    local ok, result = pcall(WorldDeltas.resolveLocation, position, world, options)
    if not ok then
        return nil, "fly-arrival-blocked"
    end
    return result
end
