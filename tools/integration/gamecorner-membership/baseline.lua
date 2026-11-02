-- Frozen exact 952db34f projection; only owner identifier renamed.
-- Pure source-block projection plus the existing atomic GameSession scene seam.
-- No mutable Zone, delta ledger or alternate session state is owned here.
GameCornerMembershipBaseline = {}
local function copy(value)
    return GameSession._copy(value)
end
local function equal(a, b)
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
function GameCornerMembershipBaseline.project(world, effect)
    return GameCornerMembershipBaseline.projectBlock(world, assert(RocketHideoutStory.scenes().terrain[effect]))
end
function GameCornerMembershipBaseline.projectBlock(world, spec)
    local entry <const> = SourceMaps.entry(spec.map)
    local descriptor <const> = WorldDeltas.definitionProvider():descriptor(entry.id)
    local result <const> = copy(world)
    local record
    for _, value in ipairs(result.zones) do
        if value.zone_id == entry.id then
            record = value
        end
    end
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
        assert(SourceMaps.compact().tiles[key], "content atlas lacks source Hideout block")
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
    return result
end
