-- Cerulean Cave, the Hall of Fame rematch, and the post-credits Continue spawn.
-- Decisions read data/postgame/story.json. Mewtwo's battle definition is a
-- lane E handoff: SourceEncounters keeps that table private.
PostgameStory = {}
local CONTENT <const> = "postgame"
local REVISION <const> = "af519899719f0754965776faac0e836a3b906e6d"
local cached, playCached
local eventsInstalled, planWrapped, hookRegistered, sceneWrapped, continueWrapped = false, false, false, false, false
local entering = false
local continueDepth = 0
local hallEnteredSet, hallHandled = false, false
local previousInstall, previousContinue, previousPrepared

local function copy(value)
    if GameSession and GameSession._copy then
        return GameSession._copy(value)
    end
    if type(value) ~= "table" then
        return value
    end
    local out = {}
    for key, item in pairs(value) do
        out[key] = copy(item)
    end
    return out
end

local function story()
    if not cached then
        local data <const> = assert(json.decodeFile("data/postgame/story.json"))
        assert(data.schema == 1 and data.source_revision == REVISION, "unverified postgame story")
        cached = data
    end
    return cached
end

local function play()
    if not playCached then
        local data <const> = assert(json.decodeFile("data/postgame/play.json"))
        assert(data.schema == 1 and data.source_revision == REVISION, "unverified postgame text")
        playCached = data
    end
    return playCached
end

function PostgameStory.story()
    return story()
end

function PostgameStory.text(label)
    local row <const> = play().texts[label]
    assert(row, "missing postgame text: " .. tostring(label))
    return copy(row)
end

local function listed(names, name)
    for _, item in ipairs(names) do
        if item == name then
            return true
        end
    end
    return false
end

function PostgameStory.mewtwoRequest(flags)
    local row <const> = story().cave.mewtwo
    local flag <const> = row.flag
    assert(flags[flag] ~= true, "already-complete")
    local outcomes = {}
    for _, name in ipairs({"victory", "caught", "run", "defeat"}) do
        outcomes[name] = listed(row.battle.hide_on, name) and {flags = {[flag] = true}} or {flags = {}}
        assert(listed(row.battle.hide_on, name) ~= listed(row.battle.stay_on, name), "mewtwo outcome overlap")
    end
    return {id = row.id, zone_id = "pokered:" .. row.map_constant, species = row.species:lower(), level = row.level,
        guards = {flags = {[flag] = false}, items = {}},
        rules = {capture = true, unidentified = false}, outcomes = outcomes}
end

function PostgameStory.mewtwoPlan(id, observation)
    local row <const> = story().cave.mewtwo
    assert(id == row.id, "mewtwo plan id")
    if observation.source_receipt then
        return {status = "ready", scene = "postgame", scene_script = "mewtwo-return", steps = {},
            source_receipt = copy(observation.source_receipt)}
    end
    if observation.flags and observation.flags[row.flag] then
        return {status = "already-complete", steps = {}}
    end
    return {status = "ready", scene = "postgame", scene_script = "mewtwo", cry = row.cry, steps = {}}
end

function PostgameStory.visibility(id)
    local row <const> = story().cave.mewtwo
    if id == row.id then
        return {visibility = {{group = "quest", id = row.flag, equals = false}}}
    end
end

-- HallOfFameResetEventsAndSaveScript resets through INDIGO_PLATEAU_EVENTS_END.
-- Lane D stops at EVENT_LANCES_ROOM_LOCK_DOOR, which leaves the champion set.
function PostgameStory.amendHallPlan(plan, id, observation)
    local rematch <const> = story().rematch
    if type(plan) ~= "table" or id ~= rematch.oak_id then
        return plan
    end
    local name <const> = rematch.champion_flag
    if plan.changes and plan.changes.flags and plan.expected and plan.expected.flags then
        local flags <const> = observation and observation.flags or {}
        plan.expected.flags[name] = flags[name] == true
        plan.changes.flags[name] = false
    end
    plan.continue_at = copy(rematch.continue_spawn)
    plan.rematch_roster = rematch.roster.roster
    return plan
end

function PostgameStory.continueDecision(location, teamCount)
    local rematch <const> = story().rematch
    if type(location) ~= "table" or location.zone_id ~= rematch.hall_zone then
        return nil
    end
    if type(teamCount) ~= "number" or teamCount < 1 then
        return nil
    end
    return copy(rematch.continue_spawn)
end

local function teamCount(candidate)
    if not candidate or type(candidate.hallOfFame) ~= "function" then
        return 0
    end
    local record <const> = candidate:hallOfFame()
    if type(record) ~= "table" or type(record.teams) ~= "table" then
        return 0
    end
    return #record.teams
end

function PostgameStory.relocateContinue(candidate)
    if not candidate or type(candidate.location) ~= "function" then
        return false
    end
    local spot <const> = PostgameStory.continueDecision(candidate:location(), teamCount(candidate))
    if not spot then
        return false
    end
    local ok, saved, reason = pcall(function()
        local world <const> = candidate:worldData()
        local descriptor <const> = SourceActors.describe(spot.zone_id, world)
        if not descriptor then
            return false, "pallet-actors-unavailable"
        end
        local actors <const> = WorldMotionData.reconcile(nil, descriptor, candidate:flags())
        return candidate:captureTraversal({
            location = {zone_id = spot.zone_id, x = spot.x, y = spot.y, facing = spot.facing},
            world = world, actors = actors, checkpoint = candidate:checkpoint(),
        })
    end)
    if not ok then
        return false, tostring(saved)
    end
    return saved, reason
end

function PostgameStory._duringContinue(method, self, ...)
    continueDepth = continueDepth + 1
    local ok, first, second = pcall(method, self, ...)
    continueDepth = continueDepth - 1
    if not ok then
        error(first, 0)
    end
    return first, second
end

function PostgameStory.installContinue()
    if continueWrapped then
        return true
    end
    if not (GameContext and GameContext.installSession and GameSaves
        and GameSaves.continueGame and GameSaves.continuePreparedTitle) then
        return false
    end
    previousInstall = GameContext.installSession
    previousContinue = GameSaves.continueGame
    previousPrepared = GameSaves.continuePreparedTitle
    function GameContext:installSession(candidate)
        if continueDepth > 0 then
            PostgameStory.relocateContinue(candidate)
        end
        return previousInstall(self, candidate)
    end
    function GameSaves:continueGame(...)
        return PostgameStory._duringContinue(previousContinue, self, ...)
    end
    function GameSaves:continuePreparedTitle(...)
        return PostgameStory._duringContinue(previousPrepared, self, ...)
    end
    continueWrapped = true
    return true
end

function PostgameStory.installEvents()
    if eventsInstalled then
        return true
    end
    if not (SourceEvents and SourceEvents.registerEventSource and SourceEvents.registerTextSource) then
        return false
    end
    local data <const> = story()
    local events = {}
    for _, floor in ipairs(data.cave.floors) do
        for _, item in ipairs(floor.items) do
            events[item.id] = {kind = "pickup", content = CONTENT, item = item.item,
                flag = "PICKUP:" .. item.id, success = {"_FoundItemText"}, full = {"_NoMoreRoomForItemText"}}
        end
    end
    local mewtwo <const> = data.cave.mewtwo
    events[mewtwo.id] = {kind = "bespoke", content = CONTENT}
    SourceEventHandlers[mewtwo.id] = function(observation)
        return PostgameStory.mewtwoPlan(mewtwo.id, observation)
    end
    SourceEvents.registerTextSource(CONTENT, PostgameStory.text)
    SourceEvents.registerEventSource(CONTENT, events)
    eventsInstalled = true
    return true
end

function PostgameStory.onEnter(game)
    local rematch <const> = story().rematch
    if currentZone and currentZone.stableID == rematch.hall_zone then
        hallEnteredSet = game.session:questFlag(story().cave.hide) == true
        hallHandled = false
    else
        hallEnteredSet, hallHandled = false, false
    end
end

local function noteLiveParty(game)
    local party <const> = game.session:party()
    local members = {}
    for index = 1, party:count() do
        local mon <const> = party:get(index)
        members[#members + 1] = {species = mon.species, level = mon.level, name = mon.name}
    end
    EndgameStory.noteParty(members)
end

-- The first visit is still EndgameStory.check, while the guard flag is clear.
-- A later entry finds the flag already set, so that check does not run again.
function PostgameStory.checkHall(game)
    local rematch <const> = story().rematch
    if not currentZone or currentZone.stableID ~= rematch.hall_zone then
        hallEnteredSet, hallHandled = false, false
        return false
    end
    if not hallEnteredSet or hallHandled then
        return false
    end
    hallHandled = true
    noteLiveParty(game)
    return SourceEvents.dispatch(game, rematch.oak_id)
end

function PostgameStory.installHall()
    if EndgameStory and EndgameStory.plan and not planWrapped then
        local previous <const> = EndgameStory.plan
        function EndgameStory.plan(id, observation)
            return PostgameStory.amendHallPlan(previous(id, observation), id, observation)
        end
        planWrapped = true
    end
    if SourceEvents and SourceEvents.registerWorldHooks and not hookRegistered then
        SourceEvents.registerWorldHooks(story().rematch.hook_id, {
            onEnter = PostgameStory.onEnter,
            explore = PostgameStory.checkHall,
        })
        hookRegistered = true
    end
end

function PostgameStory.playCry(species)
    if type(species) ~= "string" or not KantoAudio or not KantoAudio.playCry then
        return false
    end
    return pcall(KantoAudio.playCry, species) == true
end

function PostgameStory.advanceScene(state)
    if not state.plan or state.plan.scene ~= "postgame" then
        return false
    end
    if not state:valid() or not state:isTop() then
        return true
    end
    if not state.postgameScene or state.postgameScene.epoch ~= state.epoch then
        state.postgameScene = {epoch = state.epoch, phase = "text"}
        if state.plan.scene_script == "mewtwo" then
            PostgameStory.playCry(state.plan.cry or "mewtwo")
            state:source({"_MewtwoBattleText"}, function()
                state:advance()
            end)
            return true
        end
        if state.plan.scene_script == "mewtwo-return" then
            if KantoScenes and KantoScenes.reconcileActors then
                KantoScenes.reconcileActors(state.game)
            end
            state:finish()
            return true
        end
        state:fail("unsupported-postgame-scene")
        return true
    end
    if state.plan.scene_script == "mewtwo" and state.postgameScene.phase == "text" then
        state.postgameScene.phase = "battle"
        if not FieldBattle or not FieldBattle.startSourceEncounter then
            state:fail("source-encounter-unavailable")
            return true
        end
        local request <const> = PostgameStory.mewtwoRequest(state.session:flags().quest)
        local started, reason = FieldBattle.startSourceEncounter(state.game, request)
        if not started then
            state:fail(reason)
        end
    end
    return true
end

function PostgameStory.installScene()
    if sceneWrapped or not (HideoutTowerController and HideoutTowerController.advance) then
        return false
    end
    local previous <const> = HideoutTowerController.advance
    function HideoutTowerController.advance(state)
        if PostgameStory.advanceScene(state) then
            return true
        end
        return previous(state)
    end
    sceneWrapped = true
    return true
end

function PostgameStory.ensureRuntime()
    if entering then
        return
    end
    entering = true
    PostgameStory.installEvents()
    PostgameStory.installContinue()
    PostgameStory.installHall()
    PostgameStory.installScene()
    entering = false
end

function PostgameStory.boot()
    PostgameStory.ensureRuntime()
end

PostgameStory.boot()
