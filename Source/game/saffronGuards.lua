-- One owner for Blue's shared guard script. Future gates are metadata only.
-- EventState executes bounded movement and commits the existing session transaction.
SaffronGuards = {}
local CONTENT <const> = "saffronGuards"
local REVISION <const> = "af519899719f0754965776faac0e836a3b906e6d"
local cached
local function copy(value)
    return GameSession._copy(value)
end
local function data()
    if not cached then
        cached = assert(json.decodeFile("data/saffronGuards/guards.json"))
        assert(cached.schema == 1 and cached.source_revision == REVISION,
            "unverified Blue guard data")
    end
    return cached
end
function SaffronGuards.definitions()
    return copy(data())
end
function SaffronGuards.text(label)
    return copy(assert(data().texts[label], "missing Blue guard text"))
end
function SaffronGuards.descriptors()
    local events <const> = {}
    for id, guard in pairs(data().guards) do
        if guard.active then
            -- itemIDs discovers these observations through its existing data API.
            local observed <const> = {}
            for _, item in ipairs(data().drinks) do
                observed[#observed + 1] = {item=item}
            end
            events[id] = {kind="bespoke", content=CONTENT,
                restore_interaction_facing=true, observed_drinks=observed}
        end
    end
    return events
end
function SaffronGuards.plan(id, observation)
    local guard <const> = assert(data().guards[id], "unknown Blue guard")
    assert(guard.active, "future Blue gate is declaration only")
    assert(observation.intro == "done", "completed intro required")
    local flag <const> = data().flag
    local steps <const> = {}
    local automatic <const> = observation.mode == "sight"
    assert(automatic or observation.mode == "talk", "explicit guard interaction mode required")
    if observation.flags[flag] then
        -- Automatic entry no longer stops the player. Talk still thanks them.
        if not automatic then
            steps[1] = {op="dialog", labels=copy(data().completed)}
        end
        return {status="already-complete", steps=steps}
    end
    if automatic then
        steps[#steps + 1] = {op="face-player", direction=guard.entry_facing}
    end
    local expected <const> = {flags={[flag]=false}, items={}}
    local selected
    for _, item in ipairs(data().drinks) do
        local quantity <const> = observation.items[item]
        assert(Party._integer(quantity, 0, Inventory.CAPACITY * Inventory.STACK_LIMIT), "explicit guard drink observation required")
        expected.items[item] = quantity
        if not selected and quantity > 0 then
            selected = item
        end
    end
    if selected then
        -- No choice exists in Blue. One guarded commit removes exactly one
        -- priority item and opens every guard; receipt prose follows that commit.
        steps[#steps + 1] = {op="receipt", labels=copy(data().accepted)}
        return {status="ready", steps=steps, expected=expected,
            changes={flags={[flag]=true}, items={{op="take", id=selected, quantity=1}}}}
    end
    steps[#steps + 1] = {op="dialog", labels=copy(data().thirsty)}
    steps[#steps + 1] = {op="move", direction=automatic and guard.entry_push or guard.talk_push, count=1}
    return {status="thirsty", steps=steps}
end
function SaffronGuards.check(game)
    local player <const> = game.player
    if game.machine:getCurrent() ~= "overworld" or game.machine:depth() ~= 1
        or game.session:getIntro().stage ~= "done" or not currentZone or not player
        or player.isMoving or player.pendingEdgeDoor or player.pendingConnection
        or game.session:questFlag(data().flag) then
        return false
    end
    for id, guard in pairs(data().guards) do
        if guard.active and currentZone.stableID == "pokered:" .. id:match("^pokered:([^:]+):") then
            local entry <const> = assert(SourceMaps.entry(guard.map))
            for _, point in ipairs(guard.trigger) do
                if player.gridX == point.x + entry.padding and player.gridY == point.y then
                    return SourceEvents.dispatch(game, id, {mode="sight"})
                end
            end
        end
    end
    return false
end
function SaffronGuards.install()
    local events <const> = SaffronGuards.descriptors()
    for id in pairs(events) do
        assert(not SourceEvents.has(id) and not SourceEventHandlers[id], "duplicate Blue guard binding")
    end
    for id in pairs(events) do
        local stableID <const> = id
        SourceEventHandlers[id] = function(observation)
            return SaffronGuards.plan(stableID, observation)
        end
    end
    SourceEvents.registerTextSource(CONTENT, SaffronGuards.text)
    SourceEvents.registerEventSource(CONTENT, events)
    -- One hook owns all current guard entry checks. It neither activates maps
    -- nor edits their blocked, unresolved Saffron destinations.
    SourceEvents.registerWorldHooks("pokered:ROUTE_5_GATE:objects:1", {explore=SaffronGuards.check})
end

-- The shared Blue talk handler always simulates UP. In the horizontal gates,
-- its first step crosses the counter; normal walking collision stays solid.
function SaffronGuards.isCounterArrival(position)
    for id, guard in pairs(data().guards) do
        if guard.active and guard.actor.facing == "down"
            and position.zone_id == id:match("^(pokered:[^:]+):") then
            local entry = SourceMaps.entry(guard.map)
            for _, point in ipairs(guard.trigger) do
                if position.x == point.x + entry.padding and position.y == point.y - 1 then
                    local cell = SourceMaps.cell(guard.map, position.x, position.y)
                    return cell.collision == 1 and cell.terrain.counter == true
                end
            end
        end
    end
    return false
end
function SaffronGuards.permitsCounterStep(event, player, dx, dy)
    local guard = data().guards[event.id]
    if not guard or not guard.active or guard.actor.facing ~= "down" or dx ~= 0 or dy ~= -1
        or not event:valid() or not event:isTop() or event.player ~= player
        or event.game.player ~= player or event.plan.status ~= "thirsty" or player.isMoving then
        return false
    end
    local position = {zone_id = currentZone.stableID, x = player.gridX, y = player.gridY - 1}
    return SaffronGuards.isCounterArrival(position)
        and event.game.npcManager:getNPCAt(position.x, position.y) == nil
end
