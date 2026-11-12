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

local function eachStatic(visit)
    local data <const> = story()
    visit(data.cave.mewtwo)
    for _, row in ipairs(data.power_plant.statics) do
        visit(row)
    end
end

local function staticById(id)
    local found
    eachStatic(function(row)
        if row.id == id then
            found = row
        end
    end)
    return found
end

function PostgameStory.staticRequest(id, flags)
    local row <const> = assert(staticById(id), "unknown static")
    local flag <const> = row.flag
    assert(flags[flag] ~= true, "already-complete")
    local outcomes = {}
    for _, name in ipairs({"victory", "caught", "run", "defeat"}) do
        outcomes[name] = listed(row.battle.hide_on, name) and {flags = {[flag] = true}} or {flags = {}}
        assert(listed(row.battle.hide_on, name) ~= listed(row.battle.stay_on, name), "static outcome overlap")
    end
    return {id = row.id, zone_id = "pokered:" .. row.map_constant, species = row.species:lower(), level = row.level,
        guards = {flags = {[flag] = false}, items = {}},
        rules = {capture = true, unidentified = false}, outcomes = outcomes}
end

function PostgameStory.mewtwoRequest(flags)
    return PostgameStory.staticRequest(story().cave.mewtwo.id, flags)
end

function PostgameStory.staticPlan(id, observation)
    local row <const> = assert(staticById(id), "unknown static")
    if observation.source_receipt then
        return {status = "ready", scene = "postgame", scene_script = "static-return", steps = {},
            static_id = row.id, source_receipt = copy(observation.source_receipt)}
    end
    if observation.flags and observation.flags[row.flag] then
        return {status = "already-complete", steps = {}}
    end
    return {status = "ready", scene = "postgame", scene_script = "static", static_id = row.id,
        text = row.text, cry = row.cry, steps = {}}
end

function PostgameStory.mewtwoPlan(id, observation)
    return PostgameStory.staticPlan(id, observation)
end

function PostgameStory.visibility(id)
    local row <const> = staticById(id)
    if row then
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
    local function addStatic(row)
        events[row.id] = {kind = "bespoke", content = CONTENT}
        SourceEventHandlers[row.id] = function(observation)
            return PostgameStory.staticPlan(row.id, observation)
        end
    end
    addStatic(data.cave.mewtwo)
    for _, item in ipairs(data.power_plant.items) do
        events[item.id] = {kind = "pickup", content = CONTENT, item = item.item,
            flag = "PICKUP:" .. item.id, success = {"_FoundItemText"}, full = {"_NoMoreRoomForItemText"}}
    end
    for _, row in ipairs(data.power_plant.statics) do
        addStatic(row)
    end
    local scientist <const> = data.fossil.scientist
    events[scientist.id] = {kind = "bespoke", content = CONTENT}
    SourceEventHandlers[scientist.id] = function()
        return PostgameStory.fossilPlan(scientist.id)
    end
    local giver <const> = data.deviations.mew.npc
    events[giver.id] = {kind = "bespoke", content = CONTENT}
    SourceEventHandlers[giver.id] = function()
        return PostgameStory.giftPlan(giver.id)
    end
    SourceEvents.registerTextSource(CONTENT, PostgameStory.text)
    SourceEvents.registerEventSource(CONTENT, events)
    eventsInstalled = true
    return true
end

function PostgameStory.fossilPlan(id)
    local scientist <const> = story().fossil.scientist
    assert(id == scientist.id, "fossil plan id")
    return {status = "ready", scene = "postgame", scene_script = "fossil", steps = {}}
end

function PostgameStory.fossilOpen(session)
    assert(FossilRevival, "fossil-service-unavailable")
    local result <const> = FossilRevival.talk(session)
    if result.status == "offer" then
        return {ok = true, status = "offer", fossils = result.fossils,
            labels = {"_CinnabarLabFossilRoomScientist1Text"}}
    end
    if result.status == "no-fossils" then
        return {ok = true, status = "no-fossils", labels = {"_CinnabarLabFossilRoomScientist1NoFossilsText"}}
    end
    if result.status == "still-reviving" then
        return {ok = true, status = "still-reviving", labels = {"_CinnabarLabFossilRoomScientist1GoForAWalkText"}}
    end
    if result.status == "revived" or result.status == "box-full" then
        return {ok = result.status == "revived", status = result.status,
            labels = {"_CinnabarLabFossilRoomScientist1FossilIsBackToLifeText"}}
    end
    return result
end

-- Selecting a fossil writes wFossilItem before Yes/No. Cancel does not.
function PostgameStory.fossilSelect(session, symbol)
    assert(FossilRevival, "fossil-service-unavailable")
    local result <const> = FossilRevival.confirm(session, symbol, false)
    if not result.ok then
        return result
    end
    return {ok = true, status = "confirm", item = symbol,
        labels = {"_CinnabarLabFossilRoomScientist1SeesFossilText"}}
end

function PostgameStory.fossilDecline()
    if FossilRevival then
        FossilRevival.cancel()
    end
    return {ok = true, status = "cancelled", labels = {"_CinnabarLabFossilRoomScientist1ComeAgainText"}}
end

local function championReady(session)
    local gift <const> = story().deviations.mew
    if session:questFlag(gift.requires_flag) ~= true then
        return false
    end
    if gift.requires_hall_team ~= true then
        return true
    end
    local record <const> = session:hallOfFame()
    return type(record) == "table" and type(record.teams) == "table" and #record.teams >= 1
end

function PostgameStory.giftPlan(id)
    local npc <const> = story().deviations.mew.npc
    assert(id == npc.id, "gift plan id")
    return {status = "ready", scene = "postgame", scene_script = "gift", steps = {}}
end

function PostgameStory.giveMew(session)
    local gift <const> = story().deviations.mew
    if not championReady(session) then
        return {ok = false, status = "not-champion", labels = {"_PostgameGiftNotChampionText"}}
    end
    if session:questFlag(gift.flag) == true then
        return {ok = false, status = "already-complete", labels = {"_PostgameMewAlreadyText"}}
    end
    local accepted, result = session:purchaseGiftPokemon({
        species = gift.species, level = gift.level, price = gift.price, flag = gift.flag,
        guard_flags = {[gift.requires_flag] = true},
    }, session:inventory():money())
    if not accepted then
        return {ok = false, status = tostring(result)}
    end
    return {ok = true, status = "received", species = gift.species, level = gift.level,
        destination = result.destination, labels = {"_PostgameMewGiftText"}}
end

-- One cable per ask. The item is consumed like a stone, and four species need one each.
function PostgameStory.giveLinkCable(session)
    local cable <const> = story().deviations.link_cable
    if not championReady(session) then
        return {ok = false, status = "not-champion", labels = {"_PostgameGiftNotChampionText"}}
    end
    local accepted, reason = session:inventory():add(cable.id, 1)
    if not accepted then
        local full <const> = reason == "bag-full" or reason == "stack-limit"
        return {ok = false, status = tostring(reason),
            labels = {full and "_PostgameLinkCableFullText" or "_PostgameLinkCableText"}}
    end
    return {ok = true, status = "received", item = cable.id, labels = {"_PostgameLinkCableText"}}
end

function PostgameStory.fossilAnswer(session, symbol, accepted)
    if accepted ~= true then
        return PostgameStory.fossilDecline()
    end
    assert(FossilRevival, "fossil-service-unavailable")
    local result <const> = FossilRevival.confirm(session, symbol, true)
    if result.status ~= "reviving" then
        return result
    end
    return {ok = true, status = "reviving", labels = {
        "_CinnabarLabFossilRoomScientist1TakesFossilText",
        "_CinnabarLabFossilRoomScientist1GoForAWalkText2"}}
end

local function showFossilLabels(state, labels, done)
    state:source(labels, function()
        if done then
            done()
        else
            state:finish()
        end
    end)
end

function PostgameStory.presentGift(state)
    if not championReady(state.session) then
        showFossilLabels(state, {"_PostgameGiftNotChampionText"})
        return
    end
    showFossilLabels(state, {"_PostgameGiftIntroText"}, function()
        state.menu:show({"MEW", "LINK CABLE"}, state:guard(function(index)
            state.menu:hide()
            local result <const> = index == 1 and PostgameStory.giveMew(state.session)
                or PostgameStory.giveLinkCable(state.session)
            if not result.labels then
                state:fail(result.status or "gift-failed")
                return
            end
            showFossilLabels(state, result.labels)
        end), function()
            state.menu:hide()
            state:finish()
        end)
    end)
end

function PostgameStory.presentFossil(state)
    local opened <const> = PostgameStory.fossilOpen(state.session)
    if opened.status ~= "offer" then
        if not opened.labels then
            state:fail(opened.status or "fossil-failed")
            return
        end
        showFossilLabels(state, opened.labels)
        return
    end
    showFossilLabels(state, opened.labels, function()
        local names = {}
        for _, symbol in ipairs(opened.fossils) do
            local itemId <const> = ItemData.bySymbol[symbol]
            names[#names + 1] = ItemData.definitions[itemId].name
        end
        state.menu:show(names, state:guard(function(index)
            state.menu:hide()
            local symbol <const> = opened.fossils[index]
            local selected <const> = PostgameStory.fossilSelect(state.session, symbol)
            if not selected.labels then
                state:fail(selected.status or "fossil-failed")
                return
            end
            showFossilLabels(state, selected.labels, function()
                state.menu:show({"YES", "NO"}, state:guard(function(choice)
                    state.menu:hide()
                    local answer <const> = PostgameStory.fossilAnswer(state.session, symbol, choice == 1)
                    if not answer.labels then
                        state:fail(answer.status or "fossil-failed")
                        return
                    end
                    showFossilLabels(state, answer.labels)
                end), function()
                    state.menu:hide()
                    local answer <const> = PostgameStory.fossilAnswer(state.session, symbol, false)
                    showFossilLabels(state, answer.labels)
                end)
            end)
        end), function()
            state.menu:hide()
            showFossilLabels(state, PostgameStory.fossilDecline().labels)
        end)
    end)
end

function PostgameStory.onEnter(game)
    local fossil <const> = story().fossil
    if FossilRevival and currentZone and currentZone.stableID == fossil.island_zone then
        FossilRevival.onMapLoad(game.session, fossil.island_map)
    end
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
        if state.plan.scene_script == "static" or state.plan.scene_script == "mewtwo" then
            PostgameStory.playCry(state.plan.cry)
            state:source({state.plan.text}, function()
                state:advance()
            end)
            return true
        end
        if state.plan.scene_script == "static-return" or state.plan.scene_script == "mewtwo-return" then
            if KantoScenes and KantoScenes.reconcileActors then
                KantoScenes.reconcileActors(state.game)
            end
            state:finish()
            return true
        end
        if state.plan.scene_script == "gift" then
            state.postgameScene.phase = "wait"
            local ok, problem = pcall(PostgameStory.presentGift, state)
            if not ok then
                state:fail(tostring(problem))
            end
            return true
        end
        if state.plan.scene_script == "fossil" then
            state.postgameScene.phase = "wait"
            local ok, problem = pcall(PostgameStory.presentFossil, state)
            if not ok then
                state:fail(tostring(problem))
            end
            return true
        end
        state:fail("unsupported-postgame-scene")
        return true
    end
    if (state.plan.scene_script == "static" or state.plan.scene_script == "mewtwo")
        and state.postgameScene.phase == "text" then
        state.postgameScene.phase = "battle"
        if not FieldBattle or not FieldBattle.startSourceEncounter then
            state:fail("source-encounter-unavailable")
            return true
        end
        local request <const> = PostgameStory.staticRequest(state.plan.static_id, state.session:flags().quest)
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
