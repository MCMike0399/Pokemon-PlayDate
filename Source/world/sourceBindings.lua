import "world/sourceMaps"
SourceBindings = {}

function SourceBindings.specs(name, d, hasEvent)
    local profile = SourceMaps.entry(name).profile
    local viridian = profile == "viridian"
    local specs = {}
    for _, kind in ipairs({ "objects", "background_events", "warps" }) do
        for _, event in ipairs(d.events[kind]) do
            if kind == "warps" then
                specs[event.id] = SourceMaps.warpSpec(name, event)
            else
                local bound = hasEvent(event.id)
                local reason = "source control outside implemented milestone"
                if viridian then reason = "source event outside implemented parcel handlers" end
                specs[event.id] = { status = bound and "bound" or "blocked", reason = reason }
            end
        end
    end
    for _, c in ipairs(d.connections) do
        local supported = SourceMaps.nameForID("pokered:" .. c.target_map) ~= nil or c.target_map == "PALLET_TOWN"
        for _, id in ipairs(SourceMaps.descriptor(name).blocked_connections) do
            if id == c.direction .. ":" .. c.target_map then supported = false end
        end
        specs[c.direction .. ":" .. c.target_map] = { status = supported and "bound" or "blocked",
            reason = viridian and (supported and "explicit slice connection" or "source target outside slice")
                or "explicit bounded source connection" }
    end
    if #d.directional_rules.ledges > 0 then specs["ledges:" .. d.id] = { status = "bound" } end
    specs[d.script.source] = { status = (profile == "source" or name == "ViridianCity" or name == "PewterCity") and "blocked" or "bound",
        reason = viridian and "city gym, old-man tutorial and secondary state scripts remain enumerated gaps"
            or "source escorts/Route3 scripts remain explicit gaps" }
    if profile == "source" then specs[d.script.source].reason = "source script requires an explicit handler" end
    if d.encounters.grass.rate_byte > 0 then specs[d.id] = { status = "bound" } end
    return specs
end

-- Content resolvers own NPC art/story predicates only. A source-only map may
-- supply its own resolver without joining either historical regional inventory.
function SourceBindings.options(profile, options)
    local result = {}
    for key, value in pairs(options) do result[key] = value end
    result.contentProfile = profile
    if profile == "viridian" then
        result.objectDefinition = MapBindings.object
        result.hasEvent = SliceEvents.has
    elseif profile == "pewter" then
        result.objectDefinition = PewterBindings.object
        result.hasEvent = PewterEvents.has
    elseif profile == "source" then
        result.objectDefinition = SourceActors.objectDefinition
        result.hasEvent = SourceEvents.has
    end
    return result
end

function SourceBindings.prepare(d, specs, options)
    local name = assert(SourceMaps.nameForID(d.id), "map outside source manifest")
    local entry = SourceMaps.entry(name)
    assert(d.name == name and d.source_revision == "af519899719f0754965776faac0e836a3b906e6d", "unverified source map identity")
    assert(type(options.dispatch) == "function" and type(options.questFlag) == "function", "explicit source event dependencies required")
    local viridian = entry.profile == "viridian"
    local width, height = table.unpack(d.dimensions.cells)
    local expected, bound, npcs, doors = {}, {}, {}, {}
    local function source(id, event)
        assert(type(id) == "string" and not expected[id], "duplicate source binding ID")
        expected[id] = true
        if event then
            assert(type(event.x) == "number" and event.x % 1 == 0 and event.x >= 0 and event.x < width
                and type(event.y) == "number" and event.y % 1 == 0 and event.y >= 0 and event.y < height,
                "source event outside padded map")
        end
        local spec = assert(specs[id], "missing explicit source binding: " .. id)
        assert(spec.status == "bound" or spec.status == "blocked", "invalid source binding status")
        if spec.status == "bound" then bound[id] = true end
        return spec
    end
    for _, event in ipairs(d.events.objects) do
        local spec = source(event.id, event)
        assert(options.objectDefinition, "source object requires an immutable content resolver")
        npcs[#npcs + 1] = options.objectDefinition(d, event, spec, options)
    end
    for _, event in ipairs(d.events.warps) do
        local spec = source(event.id, event)
        if spec.status == "bound" then
            local verified = SourceMaps.warpSpec(name, event)
            for _, field in ipairs({ "to", "toX", "toY", "facing", "preserveFacing", "target_name", "target_warp",
                "source_target_map", "source_target_warp", "source_target_x", "source_target_y", "arrival_advance" }) do
                assert(spec[field] == verified[field], "warp differs from pinned source projection")
            end
            local interior = d.tileset.constant ~= "OVERWORLD" and d.tileset.constant ~= "FOREST"
            doors[#doors + 1] = { x = event.x, y = event.y, to = spec.to, toX = spec.toX, toY = spec.toY,
                facing = spec.facing, preserveFacing = spec.preserveFacing, source_event_id = event.id,
                edge = (viridian or interior) and event.y == height - 1 and "down" or nil }
        end
    end
    for _, event in ipairs(d.events.background_events) do
        local spec = source(event.id, event)
        if spec.status == "bound" then assert(options.hasEvent(event.id), "missing source sign handler") end
    end
    for _, c in ipairs(d.connections) do source(c.direction .. ":" .. c.target_map) end
    if #d.directional_rules.ledges > 0 then source("ledges:" .. d.id) end
    source(d.script.source)
    if d.encounters.grass.rate_byte > 0 then source(d.id) end
    for id in pairs(specs) do assert(expected[id], "unknown source binding ID") end
    local encounters, total = {}, 0
    for _, slot in ipairs(d.encounters.grass.slots) do
        assert(pokemonData[slot.species] and slot.level % 1 == 0 and slot.level >= 1 and slot.level <= 100
            and slot.weight_256 % 1 == 0 and slot.weight_256 > 0, "unresolved Blue encounter")
        encounters[#encounters + 1] = { species = slot.species, minLevel = slot.level, maxLevel = slot.level, weight = slot.weight_256 }
        total = total + slot.weight_256
    end
    assert(#encounters == 0 and d.encounters.grass.rate_byte == 0 or #encounters == 10 and total == 256, "invalid Blue encounter weights")
    local result = { bound = bound, npcs = npcs, doors = doors, specs = GameSession._copy(specs), encounters = encounters,
        encounterRateByte = d.encounters.grass.rate_byte, sliceReady = true }
    if viridian then
        result.source = GameSession._copy(d)
        result.dispatch = options.dispatch
    else
        result.source = { dimensions = GameSession._copy(d.dimensions), events = GameSession._copy(d.events),
            directional_rules = GameSession._copy(d.directional_rules) }
        result.scope = "pewter-slice-only"
        result.scopeStatus = "bounded Route2/Forest/Pewter slice; campaign and remaining source controls incomplete"
    end
    return result
end
