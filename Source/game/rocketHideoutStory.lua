-- Blue scene planning. SourceEvents selects; GameSession/NPCMotion own changes.
RocketHideoutStory = {}
local REVISION <const> = "af519899719f0754965776faac0e836a3b906e6d"
local B4 <const> = "pokered:ROCKET_HIDEOUT_B4F:objects:"
RocketHideoutStory.GUARD = "pokered:GAME_CORNER:objects:11"
RocketHideoutStory.GUARD_LEFT = "ROCKET_HIDEOUT_SCENE_V1_GUARD_LEFT"
RocketHideoutStory.GIOVANNI = B4 .. "1"
RocketHideoutStory.KEY_ROCKET = B4 .. "4"
RocketHideoutStory.SCOPE = B4 .. "8"
RocketHideoutStory.KEY = B4 .. "9"
RocketHideoutStory.POSTER = "pokered:GAME_CORNER:background_events:1"
RocketHideoutStory.LIFT = "pokered:ROCKET_HIDEOUT_ELEVATOR:background_events:1"
local cached
local integration
local function copy(value)
    return GameSession._copy(value)
end
function RocketHideoutStory.scenes()
    if not cached then
        local data <const> = assert(json.decodeFile("data/rocketHideoutStory/scenes.json"))
        assert(data.schema == 1 and data.source_revision == REVISION, "unverified Hideout scenes")
        cached = data.scenes
    end
    return copy(cached)
end
function RocketHideoutStory.padding(zoneID)
    return SourceMaps.entry(assert(SourceMaps.nameForID(zoneID))).padding
end
local function text(...)
    return {op = "dialog", labels = {...}}
end
local function scene(script)
    return {status = "ready", scene = "rocket-hideout", scene_script = script, steps = {}}
end
-- The content owner supplies text, rosters and ordinary descriptors once. Merge
-- these descriptors into that registration, then call install(contentName).
function RocketHideoutStory.descriptors(content)
    local events = {}
    for _, id in ipairs({RocketHideoutStory.POSTER, RocketHideoutStory.LIFT,
        RocketHideoutStory.GIOVANNI, RocketHideoutStory.KEY_ROCKET, RocketHideoutStory.GUARD}) do
        events[id] = {kind = "bespoke", content = content}
    end
    events[RocketHideoutStory.GIOVANNI].before = {"_RocketHideoutB4FGiovanniImpressedYouGotHereText"}
    events[RocketHideoutStory.GIOVANNI].won = {"_RocketHideoutB4FGiovanniWhatCannotBeText"}
    events[RocketHideoutStory.GIOVANNI].after = {"_RocketHideoutB4FGiovanniHopeWeMeetAgainText"}
    events[RocketHideoutStory.GIOVANNI] = RocketHideoutStory.decorate(RocketHideoutStory.GIOVANNI, events[RocketHideoutStory.GIOVANNI])
    events[RocketHideoutStory.KEY_ROCKET].before = {"_RocketHideoutB4FRocket3BattleText"}
    events[RocketHideoutStory.KEY_ROCKET].won = {"_RocketHideoutB4FRocket3EndBattleText"}
    events[RocketHideoutStory.KEY_ROCKET].after = {"_RocketHideoutB4FRocket3AfterBattleText"}
    events[RocketHideoutStory.GUARD].before = {"_GameCornerRocketImGuardingThisPosterText"}
    events[RocketHideoutStory.GUARD].won = {"_GameCornerRocketBattleEndText"}
    events[RocketHideoutStory.GUARD].after = {"_GameCornerRocketAfterBattleText"}
    events[RocketHideoutStory.GUARD].script_positions = RocketHideoutStory.scenes().guard.script_positions
    local fifth = "pokered:ROCKET_HIDEOUT_B1F:objects:5"
    events[fifth] = {kind = "trainer", content = content,
        before = {"_RocketHideoutB1FRocket5BattleText"}, won = {"_RocketHideoutB1FRocket5EndBattleText"},
        after = {"_RocketHideoutB1FRocket5AfterBattleText"},
        victory = {guard_flags = {"EVENT_BEAT_ROCKET_HIDEOUT_1_TRAINER_4"},
            flags = {EVENT_BEAT_ROCKET_HIDEOUT_1_TRAINER_4 = true}}}
    events[RocketHideoutStory.LIFT].item = "liftKey"
    for _, routes in pairs(RocketHideoutStory.scenes().spinners) do
        for _, route in ipairs(routes) do
            events[route.id] = {kind = "bespoke", content = content}
        end
    end
    return events
end
-- Apply to the content worker's source trainer/pickup descriptors BEFORE its
-- single registration. No duplicate registry or trainer roster lives here.
function RocketHideoutStory.decorate(id, descriptor)
    local d <const> = copy(descriptor)
    if id == RocketHideoutStory.GIOVANNI then
        d.victory = {guard_flags = {"EVENT_BEAT_ROCKET_HIDEOUT_GIOVANNI"},
            flags = {EVENT_BEAT_ROCKET_HIDEOUT_GIOVANNI = true}}
    elseif id == RocketHideoutStory.SCOPE or id == RocketHideoutStory.KEY then
        local flag <const> = id == RocketHideoutStory.SCOPE and "EVENT_BEAT_ROCKET_HIDEOUT_GIOVANNI"
            or "EVENT_ROCKET_DROPPED_LIFT_KEY"
        return {kind = "cases", content = d.content, flag = d.flag, item = d.item, cases = {
            {when = {flags = {[flag] = true}}, ["then"] = d},
        }, otherwise = {kind = "program", steps = {}}}
    end
    return d
end
function RocketHideoutStory.plan(id, observation)
    if id == RocketHideoutStory.POSTER then
        return scene("poster")
    elseif id == RocketHideoutStory.LIFT then
        if (observation.items.liftKey or 0) == 0 then
            return {status = "no-key", steps = {text("_RocketHideoutElevatorAppearsToNeedKeyText")}}
        end
        return scene("elevator")
    elseif id == RocketHideoutStory.GUARD then
        if observation.trainers[id] then
            if observation.flags[RocketHideoutStory.GUARD_LEFT] then
                return {status = "already-complete", steps = {}}
            end
            local plan = scene("guard-exit")
            plan.confirmed_receipt = copy(observation.receipt)
            plan.ram = observation.receipt and {wAmountMoneyWon = observation.receipt.payout} or nil
            return plan
        end
        local descriptor = SourceEvents.descriptor(id)
        descriptor.kind = "trainer"
        return SourceEvents.compile(descriptor, observation, id)
    elseif id == RocketHideoutStory.KEY_ROCKET or id == RocketHideoutStory.GIOVANNI then
        -- Content registration retains the source trainer fields on the bespoke
        -- descriptor. Compile a detached ordinary view to keep receipt semantics.
        local descriptor <const> = assert(SourceEvents.descriptor(id))
        descriptor.kind = "trainer"
        local plan <const> = SourceEvents.compile(descriptor, observation, id)
        if observation.trainers[id] then
            if id == RocketHideoutStory.KEY_ROCKET then
                plan.expected = {flags = {EVENT_ROCKET_DROPPED_LIFT_KEY = false},
                    trainers = {[id] = true}, items = {}}
                plan.changes = {flags = {EVENT_ROCKET_DROPPED_LIFT_KEY = true}, items = {}}
                if observation.flags.EVENT_ROCKET_DROPPED_LIFT_KEY then
                    plan.expected, plan.changes = nil, nil
                end
                -- Source prints the after-battle line only on a later talk.
                if observation.receipt then
                    plan.expected, plan.changes = nil, nil
                end
            elseif observation.receipt then
                plan.steps[#plan.steps + 1] = text("_RocketHideoutB4FGiovanniHopeWeMeetAgainText")
            end
        end
        return plan
    end
    for _, routes in pairs(RocketHideoutStory.scenes().spinners) do
        for _, route in ipairs(routes) do
            if route.id == id then
                local plan <const> = scene("spinner")
                plan.path = route.path
                plan.origin = {x = route.x, y = route.y}
                return plan
            end
        end
    end
    error("unsupported Hideout source ID")
end
local function destinationFlag(floor)
    return "ROCKET_HIDEOUT_LIFT_V1_" .. floor
end
function RocketHideoutStory.selectFloor(session, floor)
    local expected <const> = {flags = {}, items = {liftKey = session:inventory():quantity("liftKey")}}
    local changes <const> = {flags = {}, items = {}}
    local found = false
    for _, entry in ipairs(RocketHideoutStory.scenes().elevator) do
        local flag <const> = destinationFlag(entry.floor)
        expected.flags[flag] = session:questFlag(flag)
        changes.flags[flag] = entry.floor == floor
        found = found or entry.floor == floor
    end
    assert(found, "unknown Blue elevator floor")
    if expected.items.liftKey == 0 then
        return false, "no-key"
    end
    if session:questFlag(destinationFlag(floor)) then
        return true
    end
    return session:transact(expected, changes)
end
-- Source cabin arrival initializes both exit entries to the origin floor even
-- without a key. Kept in the existing session codec as three mutually exclusive
-- booleans; no new saved owner or mutable map warp table.
function RocketHideoutStory.enterLift(session, mapID)
    local expected <const> = {flags = {}, items = {}}
    local changes <const> = {flags = {}, items = {}}
    local selected
    for _, entry in ipairs(RocketHideoutStory.scenes().elevator) do
        local flag <const> = destinationFlag(entry.floor)
        expected.flags[flag] = session:questFlag(flag)
        changes.flags[flag] = entry.map_id == mapID
        if entry.map_id == mapID then
            selected = flag
        end
    end
    assert(selected, "Hideout lift requires source arrival floor")
    if expected.flags[selected] then
        return true
    end
    return session:transact(expected, changes)
end
function RocketHideoutStory.resolveDoor(game, door)
    if currentZone.stableID ~= "pokered:ROCKET_HIDEOUT_ELEVATOR" then
        return door
    end
    assert(door.source_event_id == "pokered:ROCKET_HIDEOUT_ELEVATOR:warps:1"
        or door.source_event_id == "pokered:ROCKET_HIDEOUT_ELEVATOR:warps:2", "unknown lift exit")
    for _, entry in ipairs(RocketHideoutStory.scenes().elevator) do
        if game.session:questFlag(destinationFlag(entry.floor)) then
            local result <const> = copy(door)
            result.to = entry.map_id
            result.toX = entry.destination.x + RocketHideoutStory.padding(entry.map_id)
            result.toY = entry.destination.y
            return result
        end
    end
    error("missing persisted Hideout lift destination")
end
function RocketHideoutStory.install(content, options)
    assert(not integration, "Hideout story already installed")
    integration = assert(options)
    assert(type(options.reconcileActors) == "function" and type(options.reconcileWorld) == "function"
        and type(options.openEntrance) == "function",
        "content actor/atomic terrain integration required")
    for id in pairs(RocketHideoutStory.descriptors(content)) do
        assert(SourceEvents.has(id, content), "content registration must precede story install")
        if SourceEvents.descriptor(id).kind == "bespoke" then
            assert(not SourceEventHandlers[id], "duplicate Hideout handler")
            local stableID <const> = id
            SourceEventHandlers[id] = function(observation)
                return RocketHideoutStory.plan(stableID, observation)
            end
        end
    end
    SourceEvents.registerWorldHooks(RocketHideoutStory.LIFT, {
        onLeave = function(game, destination)
            if destination == "pokered:ROCKET_HIDEOUT_ELEVATOR" then
                assert(RocketHideoutStory.enterLift(game.session, currentZone.stableID))
            end
        end,
        beforeSpawn = function(game)
            options.reconcileWorld(game)
            options.reconcileActors(game)
        end,
        explore = function(game)
            if currentZone.stableID == "pokered:GAME_CORNER"
                and game.session:trainerDefeated(RocketHideoutStory.GUARD)
                and not game.session:questFlag(RocketHideoutStory.GUARD_LEFT) then
                return SourceEvents.dispatch(game, RocketHideoutStory.GUARD)
            end
            local routes <const> = RocketHideoutStory.scenes().spinners[currentZone.stableID]
            for _, route in ipairs(routes or {}) do
                if game.player.gridX == route.x + RocketHideoutStory.padding(currentZone.stableID)
                    and game.player.gridY == route.y then
                    return SourceEvents.dispatch(game, route.id)
                end
            end
            return false
        end,
    })
end
function RocketHideoutStory.integration()
    return assert(integration, "Hideout story integration missing")
end

function RocketHideoutStory.actorMetadata(id, game)
    if id == RocketHideoutStory.GUARD then
        return {visibility = {{group = "quest", id = RocketHideoutStory.GUARD_LEFT, equals = false}}}
    elseif id == RocketHideoutStory.GIOVANNI then
        if game and game.trainers and game.trainers:peekReceipt(id) then
            return {visibility = {}}
        end
        return {visibility = {{group = "quest", id = "EVENT_BEAT_ROCKET_HIDEOUT_GIOVANNI", equals = false}}}
    elseif id == RocketHideoutStory.SCOPE or id == RocketHideoutStory.KEY then
        local d = assert(SourceEvents.descriptor(id))
        local flag = id == RocketHideoutStory.SCOPE and "EVENT_BEAT_ROCKET_HIDEOUT_GIOVANNI"
            or "EVENT_ROCKET_DROPPED_LIFT_KEY"
        return {visibility = {{group = "quest", id = flag, equals = true},
            {group = "quest", id = assert(d.flag), equals = false}}}
    end
    return {}
end
