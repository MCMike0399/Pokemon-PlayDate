-- Guarded field intents. Root owns controller registration and runtime movement.
FieldTravelRequests = {}
local requests = setmetatable({}, {__mode = "k"})
local directions <const> = {up = {0, -1}, down = {0, 1}, left = {-1, 0}, right = {1, 0}}

local function copy(value)
    return Party._primitive(value)
end

local function snapshot(game, party, overlay)
    local machine = game.machine
    local world = machine:get("overworld")
    local player = game.player
    local depth = overlay and 3 or 2
    if machine._transitioning or machine:depth() ~= depth or machine.stack[1] ~= world
        or machine.stack[2] ~= party or machine:current() ~= (overlay or party)
        or not party.active or party.session ~= game.session or party.options.trySelect
        or party.options.onSelect or party.options.mode or not world or not world.sub
        or world.sub:getCurrent() ~= "explore" or not player or player.isMoving
        or player.isJumping or player.stepJustFinished or player.pendingEdgeDoor or player.pendingConnection then
        return nil, "field-only"
    end
    if type(game.session.fieldTravelData) ~= "function" or type(game.commitFieldTravel) ~= "function" then
        return nil, "travel-owner-not-installed"
    end
    return {
        position = {zone_id = currentZone.stableID, x = player.gridX, y = player.gridY, facing = player.facing},
        epoch = game.session:fieldWorldEpoch(), travel = game.session:fieldTravelData(),
        world = WorldDeltas.export(), actors = game.npcManager.motion:snapshot(),
        roster = assert(game.session:party():toData(function(mon)
            return assert(PokemonCodec.encode(mon))
        end)),
        flags = game.session:flags(), checkpoint = game.session:checkpoint(),
        visit = party.visit, view = party.view
    }
end

local function surfPlan(game, observed)
    local position = observed.position
    local from, descriptor = FieldTravelWorld.cell(position, observed.world, game.sessionLocationPolicy)
    if not from then
        return nil, descriptor
    end
    local direction = assert(directions[position.facing])
    local nextPosition = copy(position)
    nextPosition.x = nextPosition.x + direction[1]
    nextPosition.y = nextPosition.y + direction[2]
    local target, reason = FieldTravelWorld.cell(nextPosition, observed.world, game.sessionLocationPolicy)
    if not target then
        return nil, reason
    end
    from.occupied = false
    target.occupied = game.npcManager:getNPCAt(nextPosition.x, nextPosition.y) ~= nil
    -- Source's forced-bike bit belongs to the Cycling Road controller. This
    -- first packet refuses absent restrictions rather than guessing from names.
    if type(game.fieldTravelRestrictions) ~= "function" then
        return nil, "travel-restrictions-not-installed"
    end
    local restrictions = game:fieldTravelRestrictions(position)
    if type(restrictions) ~= "table" or type(restrictions.forcedBicycle) ~= "boolean"
        or type(restrictions.currentTooFast) ~= "boolean" then
        return nil, "invalid-travel-restrictions"
    end
    return FieldTravel.surf(observed.travel, position, from, target, descriptor.tileset.constant, restrictions)
end

function FieldTravelRequests.prepare(game, party, mon, key, destinationID)
    local observed, reason = snapshot(game, party)
    if not observed then
        return nil, reason
    end
    local usable, why = FieldTravel.canUse(game.session, mon, key)
    if not usable then
        return nil, why
    end
    local plan
    if key == "strength" then
        plan = FieldTravel.strength(observed.travel)
    elseif key == "surf" then
        plan, reason = surfPlan(game, observed)
    elseif key == "fly" then
        plan, reason = FieldTravel.fly(observed.travel, observed.position, destinationID,
            FieldTravelWorld.outside(observed.position.zone_id), function(entry)
                return FieldTravelWorld.flyArrival(entry, observed.world, game.sessionLocationPolicy)
            end)
    end
    if not plan then
        return nil, reason or "unsupported-field-move"
    end
    local token = {}
    requests[token] = {
        game = game, session = game.session, party = party, player = game.player,
        zone = currentZone, mon = mon, key = key, destination = destinationID,
        members = game.session:party():members(),
        observed = observed, plan = plan, status = "prepared"
    }
    return token
end

local function current(request, overlay)
    if not request or request.status ~= "prepared" or request.game.session ~= request.session
        or request.game.player ~= request.player or currentZone ~= request.zone then
        return false
    end
    local members = request.session:party():members()
    if #members ~= #request.members then
        return false
    end
    for index, mon in ipairs(members) do
        if mon ~= request.members[index] then
            return false
        end
    end
    local observed = snapshot(request.game, request.party, overlay)
    return observed and FieldMoves.same(observed, request.observed)
        and FieldTravel.canUse(request.session, request.mon, request.key)
end

function FieldTravelRequests.isCurrent(token, overlay)
    local ok, result = pcall(current, requests[token], overlay)
    return ok and result == true
end

function FieldTravelRequests.preview(token)
    local request = requests[token]
    if not request or request.status ~= "prepared" then
        return nil
    end
    return {key = request.key, name = request.mon.name, plan = copy(request.plan)}
end

function FieldTravelRequests.cancel(token)
    local request = requests[token]
    if not request or request.status ~= "prepared" then
        return false, "stale-selection"
    end
    request.status = "cancelled"
    return true
end

function FieldTravelRequests.complete(token, overlay)
    local request = requests[token]
    if not FieldTravelRequests.isCurrent(token, overlay) then
        return false, "stale-selection"
    end
    -- Re-plan the live target: actor occupancy/restrictions can change without
    -- altering a terrain delta. No mutation precedes this final comparison.
    local plan = request.plan
    if request.key == "surf" then
        local fresh = surfPlan(request.game, request.observed)
        if not fresh or not FieldMoves.same(fresh, plan) then
            request.status = "failed"
            return false, "changed-travel-target"
        end
    end
    request.status = "committing"
    local called, accepted, reason = pcall(request.game.commitFieldTravel, request.game,
        copy(request.observed), copy(plan))
    request.status = called and accepted and "complete" or "failed"
    if not called then
        return false, tostring(accepted)
    end
    return accepted, reason
end
