-- Guarded Bag/registered-item boundary for Bicycle and the three source rods.
-- Root owns the presentation and final Player/Overworld controller hooks.
FieldGearRequests = {}
local requests = setmetatable({}, {__mode = "k"})
local directions <const> = {up = {0, -1}, down = {0, 1}, left = {-1, 0}, right = {1, 0}}

local function copy(value)
    return Party._primitive(value)
end

function FieldGearRequests.supports(id)
    return id == "bicycle" or FieldFishing.isRod(id)
end

local function observe(game, bag, overlay)
    local machine = game.machine
    local player = game.player
    local world = machine:get("overworld")
    if machine._transitioning or machine:depth() ~= (overlay and 3 or 2)
        or machine.stack[1] ~= world or machine.stack[2] ~= bag
        or machine:current() ~= (overlay or bag) or not bag.active
        or bag.session ~= game.session or bag.battle or bag.options.mode
        or bag.options.trySelect or bag.options.onSelect or not world or not world.sub
        or world.sub:getCurrent() ~= "explore" or not player or player.isMoving
        or player.isJumping or player.stepJustFinished or player.pendingEdgeDoor or player.pendingConnection then
        return nil, "field-only"
    end
    if type(game.session.fieldTravelData) ~= "function" then
        return nil, "travel-owner-not-installed"
    end
    local provider = WorldDeltas.definitionProvider()
    local descriptor
    if currentZone.stableID == "pallet_town" then
        descriptor = {source_map_constant = "PALLET_TOWN", tileset = {constant = "OVERWORLD"}, padding = 0}
    elseif provider and provider:hasID(currentZone.stableID) then
        descriptor = provider:descriptor(currentZone.stableID)
    else
        return nil, "gear-map-not-installed"
    end
    return {
        position = {zone_id = currentZone.stableID, x = player.gridX, y = player.gridY, facing = player.facing},
        epoch = game.session:fieldWorldEpoch(), travel = game.session:fieldTravelData(),
        forced = game.session:questFlag(FieldCycling.FLAG), inventory = game.session:inventory():toData(),
        world = WorldDeltas.export(), actors = game.npcManager.motion:snapshot(),
        flags = game.session:flags(), rules = RulesRNG.snapshot(), worldRng = game.session:worldRngData(),
        visit = bag.visit, map = descriptor.source_map_constant, tileset = descriptor.tileset.constant
    }
end

local function canFish(game, before)
    if before.travel.mode == "surfing" then
        return false, "cannot-fish-while-surfing"
    end
    local direction = assert(directions[before.position.facing], "invalid fishing facing")
    local target = copy(before.position)
    target.x = target.x + direction[1]
    target.y = target.y + direction[2]
    local cell, descriptor = FieldTravelWorld.cell(target, before.world, game.sessionLocationPolicy)
    if not cell then
        return false, descriptor
    end
    -- FishingInit checks water/shore only, without Surf's tile-pair collision.
    if cell.binding_blocked or cell.adapter_padding or not FieldTravel.surfSurface(cell, before.tileset) then
        return false, "not-facing-fishing-water"
    end
    return true
end

function FieldGearRequests.prepare(game, bag, id)
    if not FieldGearRequests.supports(id) then
        return nil, "unsupported-field-gear"
    end
    local before, reason = observe(game, bag)
    if not before then
        return nil, reason
    end
    if game.session:inventory():quantity(id) ~= 1 then
        return nil, "gear-not-in-bag"
    end
    local plan, fishing
    if id == "bicycle" then
        if type(game.commitCycling) ~= "function" then
            return nil, "cycling-owner-not-installed"
        end
        plan, reason = FieldCycling.toggle(before.travel, before.forced, true, before.map, before.tileset)
        if not plan then
            return nil, reason
        end
    else
        local eligible, why = canFish(game, before)
        if not eligible then
            return nil, why
        end
        if not game.machine:get("battle") then
            return nil, "battle-state-not-registered"
        end
        fishing, reason = FieldFishing.prepare(game.session, id, before.map)
        if not fishing then
            return nil, reason
        end
        plan = {kind = "fishing", rod = id}
    end
    local token = {}
    requests[token] = {
        game = game, session = game.session, bag = bag, player = game.player,
        zone = currentZone, before = before, plan = plan, fishing = fishing, status = "prepared"
    }
    return token
end

function FieldGearRequests.preview(token)
    local request = requests[token]
    if not request or request.status ~= "prepared" then
        return nil
    end
    return copy(request.plan)
end

function FieldGearRequests.cancel(token)
    local request = requests[token]
    if not request or request.status ~= "prepared" then
        return false, "stale-gear-request"
    end
    if request.fishing then
        FieldFishing.cancel(request.fishing)
    end
    request.status = "cancelled"
    return true
end

function FieldGearRequests.complete(token, overlay)
    local request = requests[token]
    local ok, result, reason = pcall(function()
        assert(request and request.status == "prepared", "stale-gear-request")
        local game = request.game
        assert(game.session == request.session and game.player == request.player and currentZone == request.zone,
            "stale-gear-owner")
        local before = observe(game, request.bag, overlay)
        assert(before and FieldMoves.same(before, request.before), "stale-gear-context")
        if request.fishing then
            local eligible, why = canFish(game, before)
            assert(eligible, why)
            return FieldFishing.resolve(request.fishing)
        end
        return game:commitCycling(copy(before), copy(request.plan))
    end)
    if request and request.status == "prepared" then
        request.status = ok and result and "complete" or "failed"
        if request.fishing then
            FieldFishing.cancel(request.fishing)
        end
    end
    if not ok then
        return false, tostring(result)
    end
    return result, reason
end
