-- Inactive field intent owner. GameSession and WorldDeltas retain all durable state.
FieldMoves = {}
local revision <const> = "af519899719f0754965776faac0e836a3b906e6d"
local requests = setmetatable({}, {__mode="k"})
local source
local function copy(value)
    if value == nil then return nil end
    return Party._primitive(value)
end
local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do if not same(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end
FieldMoves.same = same
function FieldMoves.data()
    if not source then
        source = assert(json.decodeFile("data/fieldMoves.json"))
        assert(source.schema == 1 and source.source_revision == revision, "unverified field move data")
    end
    return copy(source)
end
function FieldMoves.tile(key)
    return FieldMoves.data().tiles[key]
end
function FieldMoves.known(mon)
    local result = {}
    for _, key in ipairs(mon and mon.moves or {}) do
        if key == "cut" or key == "flash" then result[#result + 1] = key end
    end
    return result
end
local function position(game)
    return {zone_id=currentZone.stableID, x=game.player.gridX, y=game.player.gridY, facing=game.player.facing}
end
local function boundary(game, party, state)
    local world = game.machine:get("overworld")
    local player = game.player
    local depth = state and 3 or 2
    return not game.machine._transitioning and game.machine:depth() == depth
        and game.machine.stack[1] == world and game.machine.stack[2] == party
        and game.machine:current() == (state or party) and party.active
        and party.session == game.session and not party.options.trySelect and not party.options.onSelect
        and not party.options.mode and world and world.sub and world.sub:getCurrent() == "explore"
        and player and not player.isMoving and not player.isJumping and not player.stepJustFinished
        and not player.pendingEdgeDoor and not player.pendingConnection
end
local function occupied(game, cells)
    for _, cell in ipairs(cells) do
        if game.player.gridX == cell.x and game.player.gridY == cell.y then return true end
        if game.npcManager:getNPCAt(cell.x, cell.y) then return true end
        if #currentZone:sourceEventsAt(cell.x, cell.y) > 0 then return true end
    end
    return false
end
local function replace(world, zone, cells)
    local out = copy(world)
    local record
    for _, value in ipairs(out.zones) do if value.zone_id == zone.stableID then record = value end end
    if not record then
        record = zone:exportDeltas()
        record.tiles, record.tile_count = {}, 0
        out.zones[#out.zones + 1] = record
    end
    for _, cell in ipairs(cells) do
        if cell.before ~= cell.after then
            local retained = {}
            for _, tile in ipairs(record.tiles) do
                if tile.x ~= cell.x or tile.y ~= cell.y then retained[#retained + 1] = tile end
            end
            retained[#retained + 1] = {x=cell.x, y=cell.y, key=cell.after}
            record.tiles, record.tile_count = retained, #retained
        end
    end
    out.zone_count = #out.zones
    return WorldDeltas.validate(out)
end
function FieldMoves.cutPlan(game)
    local zone = currentZone
    local data = FieldMoves.data()
    local spec = data.maps[zone.stableID]
    if not zone.imported or not spec then return nil, "nothing-to-cut" end
    local provider = WorldDeltas.definitionProvider()
    if not provider or not provider:owns(zone) then return nil, "unsupported-map" end
    local descriptor = provider:descriptor(zone.stableID)
    if descriptor.revision ~= revision or descriptor.source_width ~= spec.width
        or descriptor.height ~= spec.height or descriptor.name ~= spec.name then return nil, "source-map-mismatch" end
    local fx, fy = game.player:getFacingTile()
    for _, site in ipairs(spec.sites) do
        for _, target in ipairs(site.targets) do
            if fx == target.x + descriptor.padding and fy == target.y then
                local cells = copy(site.cells)
                for _, cell in ipairs(cells) do
                    cell.x = cell.x + descriptor.padding
                    local terrain = zone:terrainAt(cell.x, cell.y)
                    if terrain.binding_blocked or zone.registry:key(zone.tiles[cell.y+1][cell.x+1]) ~= cell.before then
                        return nil, "changed-source-block"
                    end
                end
                -- Only changed quadrants are mutation endpoints; standing on an
                -- unchanged quadrant in this source block is legal.
                local endpoints = {}
                for _, cell in ipairs(cells) do if cell.before ~= cell.after then endpoints[#endpoints+1] = cell end end
                if occupied(game, endpoints) then return nil, "occupied-target" end
                local before = WorldDeltas.export()
                return {before=before, after=replace(before, zone, cells), cells=cells,
                        target={x=fx,y=fy}, endpoints=endpoints}
            end
        end
    end
    return nil, "nothing-to-cut"
end
function FieldMoves.validDarknessInput(zoneID, input)
    local eligible = false
    for _, id in ipairs(FieldMoves.data().dark_maps) do if id == zoneID then eligible = true end end
    return eligible and type(input) == "table" and input.zone_id == zoneID
        and input.source_revision == revision and input.offset == 6
        and type(input.epoch) == "number" and input.epoch % 1 == 0 and input.epoch >= 1
end
local function darkPlan(game)
    -- Adapter is supplied by the source darkness/save owner in 5.5. Never infer
    -- darkness from a map name, invent geometry, or create a parallel save flag.
    local adapter = game.fieldDarkness
    if not adapter or type(adapter.read) ~= "function" or type(adapter.clear) ~= "function" then
        return nil, "darkness-not-installed"
    end
    local input = adapter:read(game)
    if not FieldMoves.validDarknessInput(currentZone.stableID,input) then return nil, "already-light" end
    return {adapter=adapter, input=copy(input)}
end
local function monRecord(session, mon, key)
    if type(mon) ~= "table" or Party._owner(mon) ~= session:party() or not mon:hasMove(key) then return nil, "move-not-known" end
    if #mon:getPendingMoveChoices() > 0 or mon.pendingEvolution then return nil, "progression-pending" end
    -- Gen I field moves allow fainted members and consume no PP.
    return PokemonCodec.encode(mon)
end
function FieldMoves.prepare(game, party, mon, key)
    if key ~= "cut" and key ~= "flash" then return nil, "unsupported-field-move" end
    if not boundary(game, party) then return nil, "field-only" end
    local session = game.session
    if not session:hasBadge(key == "cut" and "cascade" or "boulder") then return nil, "badge-required" end
    local record, reason = monRecord(session, mon, key)
    if not record then return nil, reason end
    local plan, why
    if key == "cut" then
        if type(game.commitFieldTerrain) ~= "function" then return nil, "world-owner-not-installed" end
        plan, why = FieldMoves.cutPlan(game)
    else plan, why = darkPlan(game) end
    if not plan then return nil, why end
    local token = {}
    requests[token] = {game=game, session=session, party=party, visit=party.visit, view=party.view,
        player=game.player, zone=currentZone, position=position(game), mon=mon, record=record,
        roster=session:party():members(), activeIndex=session:party():activeIndex(),
        checkpoint=session:checkpoint(), flags=session:flags(), world=WorldDeltas.export(),
        actors=game.npcManager.motion:snapshot(), sessionWorld=session:worldData(), key=key,
        plan=plan, status="prepared"}
    return token
end
local function valid(p, state)
    if not p or p.status ~= "prepared" then return false end
    local g = p.game
    if g.session ~= p.session or g.player ~= p.player or currentZone ~= p.zone
        or p.party.visit ~= p.visit or p.party.view ~= p.view or not boundary(g,p.party,state)
        or not same(position(g),p.position) or not same(g.session:flags(),p.flags)
        or g.session:party():activeIndex() ~= p.activeIndex or not same(g.session:checkpoint(),p.checkpoint)
        or not same(WorldDeltas.export(),p.world) or not same(g.session:worldData(),p.sessionWorld)
        or not same(g.npcManager.motion:snapshot(),p.actors) then return false end
    local roster = g.session:party():members()
    if #roster ~= #p.roster then return false end
    for i, mon in ipairs(roster) do if mon ~= p.roster[i] then return false end end
    local record = monRecord(p.session,p.mon,p.key)
    if not record or not same(record,p.record) then return false end
    if p.key == "cut" then return not occupied(g,p.plan.endpoints) end
    return g.fieldDarkness == p.plan.adapter and same(p.plan.adapter:read(g),p.plan.input)
end
function FieldMoves.isCurrent(token, state)
    local ok, result = pcall(valid,requests[token],state)
    return ok and result == true
end
function FieldMoves.preview(token)
    local p = requests[token]
    if not p then return nil end
    return {key=p.key, name=p.mon.name, target=copy(p.plan.target), cells=copy(p.plan.cells)}
end
function FieldMoves.cancel(token)
    local p = requests[token]
    if not p or p.status ~= "prepared" then return false, "stale-selection" end
    p.status = "cancelled"
    return true
end
function FieldMoves.complete(token, state)
    local p = requests[token]
    if not FieldMoves.isCurrent(token,state) then return false, "stale-selection" end
    p.status = "committing"
    local called, accepted, reason = pcall(function()
        if p.key == "cut" then
            return p.game:commitFieldTerrain(p.world,p.plan.after,p.position,p.actors)
        end
        return p.plan.adapter:clear(p.game,copy(p.plan.input))
    end)
    p.status = called and accepted and "complete" or "failed"
    if not called then return false, tostring(accepted) end
    return accepted, reason
end
-- Pure source reload projection. Cut blocks are not saved by pokered's
-- LoadTileBlockMap: remove only complete, exact, generated replacements.
-- Root invokes this on map reload/Continue, never merely on overlay/battle return.
function FieldMoves.reloadWorld(world, zoneID, padding)
    local out = copy(world)
    local spec = FieldMoves.data().maps[zoneID]
    if not spec then return out end
    for index, record in ipairs(out.zones) do
        if record.zone_id == zoneID then
            assert(record.definition_revision == revision, "wrong cut reset revision")
            local byCell, remove = {}, {}
            for _, tile in ipairs(record.tiles) do byCell[tile.y..":"..tile.x] = tile.key end
            for _, site in ipairs(spec.sites) do
                local matches, changed = true, false
                for _, cell in ipairs(site.cells) do
                    local id = cell.y..":"..(cell.x + padding)
                    if (byCell[id] or cell.before) ~= cell.after then matches = false end
                    if cell.before ~= cell.after then changed = true end
                end
                if matches and changed then
                    for _, cell in ipairs(site.cells) do
                        if cell.before ~= cell.after then remove[cell.y..":"..(cell.x+padding)] = true end
                    end
                end
            end
            local tiles = {}
            for _, tile in ipairs(record.tiles) do if not remove[tile.y..":"..tile.x] then tiles[#tiles+1] = tile end end
            record.tiles, record.tile_count = tiles, #tiles
            if #tiles == 0 then table.remove(out.zones,index) end
            break
        end
    end
    out.zone_count = #out.zones
    return out
end
