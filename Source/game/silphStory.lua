-- SourceEvents plans + existing TrainerEvents/NPCMotion/GameSession owners.
SilphStory = {}
local REVISION <const> = "af519899719f0754965776faac0e836a3b906e6d"
SilphStory.RIVAL = "pokered:SILPH_CO_7F:objects:9"
SilphStory.GIOVANNI = "pokered:SILPH_CO_11F:objects:3"
SilphStory.LAPRAS = "pokered:SILPH_CO_7F:objects:1"
SilphStory.PRESIDENT = "pokered:SILPH_CO_11F:objects:1"
SilphStory.NURSE = "pokered:SILPH_CO_9F:objects:1"
SilphStory.LIFT = "pokered:SILPH_CO_ELEVATOR:background_events:1"
SilphStory.RIVAL_LEFT = "SILPH_STORY_V1_RIVAL_LEFT"
local cached
local integration
local function copy(value)
    return GameSession._copy(value)
end
function SilphStory.scenes()
    if not cached then
        local data <const> = assert(json.decodeFile("data/silphStory/scenes.json"))
        assert(data.schema == 1 and data.source_revision == REVISION, "unverified Silph scenes")
        cached = data.scenes
    end
    return copy(cached)
end
function SilphStory.padding(zoneID)
    return SourceMaps.entry(assert(SourceMaps.nameForID(zoneID))).padding
end
function SilphStory.door(id)
    for _, doors in pairs(SilphStory.scenes().doors) do
        for _, door in ipairs(doors) do
            if door.id == id then
                return door
            end
        end
    end
end
function SilphStory.variant(id, x, y)
    local source <const> = SilphStory.scenes()
    local variants <const> = id == SilphStory.RIVAL and source.rival.variants or source.giovanni.triggers
    for _, variant in ipairs(variants) do
        local point <const> = variant.trigger or variant
        if point.x == x and point.y == y then
            return variant
        end
    end
end
local function scene(script)
    return {status = "ready", scene = "silph-story", scene_script = script, steps = {}}
end
function SilphStory.descriptors()
    local content <const> = "midgameSaffron"
    local events = {}
    for _, id in ipairs({SilphStory.RIVAL, SilphStory.GIOVANNI, SilphStory.LAPRAS, SilphStory.NURSE, SilphStory.LIFT}) do
        events[id] = {kind = "bespoke", content = content}
    end
    local rival <const> = SilphStory.scenes().rival
    events[SilphStory.RIVAL].before = {"_SilphCo7FRivalWaitedHereText"}
    events[SilphStory.RIVAL].won = {"_SilphCo7FRivalDefeatedText"}
    events[SilphStory.RIVAL].lost = {"_SilphCo7FRivalVictoryText"}
    events[SilphStory.RIVAL].script_positions = rival.script_positions
    events[SilphStory.RIVAL].victory = {guard_flags = {"EVENT_BEAT_SILPH_CO_RIVAL"}, flags = {EVENT_BEAT_SILPH_CO_RIVAL = true}}
    events[SilphStory.GIOVANNI].script_positions = {}
    for y = 9, 12 do
        events[SilphStory.GIOVANNI].script_positions[#events[SilphStory.GIOVANNI].script_positions + 1] = {x = 6, y = y}
    end
    events[SilphStory.GIOVANNI].won = {"_SilphCo11FGiovanniILostAgainText"}
    events[SilphStory.GIOVANNI].victory = {guard_flags = {"EVENT_BEAT_SILPH_CO_GIOVANNI"},
        flags = {EVENT_BEAT_SILPH_CO_GIOVANNI = true}}
    events[SilphStory.PRESIDENT] = {kind = "gift", content = content, item = "masterBall",
        flag = "EVENT_GOT_MASTER_BALL", prefix = {{op = "dialog", labels = {"_SilphCo11FSilphPresidentText"}}},
        success = {"_SilphCo11FSilphPresidentReceivedMasterBallText"},
        full = {"_SilphCo11FSilphPresidentNoRoomText"}, completed = {"_SilphCo11FSilphPresidentMasterBallDescriptionText"}}
    for _, doors in pairs(SilphStory.scenes().doors) do
        for _, door in ipairs(doors) do
            events[door.id] = {kind = "bespoke", content = content, item = "cardKey"}
        end
    end
    for id, descriptor in pairs(events) do
        local padding <const> = SilphStory.padding("pokered:" .. id:match("^pokered:([^:]+):"))
        for _, position in ipairs(descriptor.script_positions or {}) do
            position.x = position.x + padding
        end
    end
    return events
end
function SilphStory.plan(id, observation)
    if id == SilphStory.RIVAL or id == SilphStory.GIOVANNI then
        if observation.trainers[id] then
            if id == SilphStory.RIVAL and observation.flags[SilphStory.RIVAL_LEFT] then
                return {status = "already-complete", steps = {}}
            end
            local plan <const> = scene(id == SilphStory.RIVAL and "rival-exit" or "giovanni-exit")
            plan.confirmed_receipt = copy(observation.receipt)
            plan.ram = observation.receipt and {wAmountMoneyWon = observation.receipt.payout} or nil
            return plan
        end
        return scene(id == SilphStory.RIVAL and "rival" or "giovanni")
    elseif id == SilphStory.LAPRAS then
        if observation.flags.BIT_GOT_LAPRAS then
            return {status = "ready", steps = {{op = "dialog", labels = {
                observation.flags.EVENT_BEAT_SILPH_CO_GIOVANNI and "_SilphCo7FSilphWorkerM1SavedText"
                    or "_SilphCo7FSilphWorkerM1IsOurPresidentOkText",
            }}}}
        end
        return scene("lapras")
    elseif id == SilphStory.NURSE then
        if observation.flags.EVENT_BEAT_SILPH_CO_GIOVANNI then
            return {status = "ready", steps = {{op = "dialog", labels = {"SilphCo9FNurseThankYouText"}}}}
        end
        return scene("nurse")
    elseif id == SilphStory.LIFT then
        return scene("elevator")
    end
    local door <const> = assert(SilphStory.door(id), "unsupported Silph scene ID")
    if observation.flags[door.flag] then
        return {status = "already-complete", steps = {}}
    end
    if (observation.items.cardKey or 0) == 0 then
        return {status = "no-card-key", steps = {{op = "dialog", labels = {"_CardKeyFailText"}}}}
    end
    local plan <const> = scene("door")
    plan.door = door
    return plan
end
function SilphStory.facingDoor(game)
    local doors <const> = SilphStory.scenes().doors[currentZone.stableID]
    if not doors then
        return nil
    end
    local x, y = game.player:getFacingTile()
    local terrain <const> = currentZone:terrainAt(x, y)
    if not terrain then
        return nil
    end
    local tile <const> = terrain.foot_tile
    if tile ~= 0x18 and tile ~= 0x24 and not (currentZone.stableID == "pokered:SILPH_CO_11F" and tile == 0x5e) then
        return nil
    end
    local padding <const> = SilphStory.padding(currentZone.stableID)
    for _, door in ipairs(doors) do
        if (x - padding) // 2 == door.x and y // 2 == door.y and not game.session:questFlag(door.flag) then
            return door
        end
    end
end
function SilphStory.actorMetadata(id, game)
    if id == SilphStory.RIVAL then
        return {visibility = {{group = "quest", id = SilphStory.RIVAL_LEFT, equals = false}}}
    end
    if id == SilphStory.GIOVANNI and game and game.trainers and game.trainers:peekReceipt(id) then
        return {visibility = {}}
    end
    for _, hidden in ipairs(SilphStory.scenes().toggles.hide) do
        if hidden == id then
            return {visibility = {{group = "quest", id = "EVENT_BEAT_SILPH_CO_GIOVANNI", equals = false}}}
        end
    end
    for _, shown in ipairs(SilphStory.scenes().toggles.show) do
        if shown == id then
            return {visibility = {{group = "quest", id = "EVENT_BEAT_SILPH_CO_GIOVANNI", equals = true}}}
        end
    end
    return {}
end
function SilphStory.install(options)
    assert(not integration, "Silph story already installed")
    integration = assert(options)
    assert(type(options.reconcileActors) == "function", "content actor reconciliation required")
    for id, descriptor in pairs(SilphStory.descriptors()) do
        assert(SourceEvents.has(id, descriptor.content), "register reserved Silph content first")
        if descriptor.kind == "bespoke" then
            assert(not SourceEventHandlers[id], "duplicate Silph story handler")
            local stableID <const> = id
            SourceEventHandlers[id] = function(observation)
                return SilphStory.plan(stableID, observation)
            end
        end
    end
    SourceEvents.registerWorldHooks(SilphStory.LIFT, {
        beforeSpawn = SilphStoryWorld.reconcile,
        onLeave = function(game, destination)
            if destination == "pokered:SILPH_CO_ELEVATOR" then
                assert(SilphStoryWorld.enterLift(game.session, currentZone.stableID))
            end
        end,
        interact = function(game)
            local door <const> = SilphStory.facingDoor(game)
            return door and SourceEvents.dispatch(game, door.id) or false
        end,
        explore = function(game)
            for _, id in ipairs({SilphStory.RIVAL, SilphStory.GIOVANNI}) do
                local zoneID <const> = "pokered:" .. id:match("^pokered:([^:]+):")
                if currentZone.stableID == zoneID then
                    if id == SilphStory.RIVAL and game.session:trainerDefeated(id)
                        and not game.session:questFlag(SilphStory.RIVAL_LEFT) then
                        return SourceEvents.dispatch(game, id)
                    end
                    local variant <const> = SilphStory.variant(id, game.player.gridX - SilphStory.padding(zoneID), game.player.gridY)
                    if variant and not game.session:trainerDefeated(id) then
                        return SourceEvents.dispatch(game, id)
                    end
                end
            end
            return false
        end,
    })
end
function SilphStory.integration()
    return assert(integration, "Silph story integration missing")
end
