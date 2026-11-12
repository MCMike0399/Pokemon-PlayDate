-- Cerulean Cave, the Hall of Fame rematch, and the post-credits Continue spawn.
-- Decisions read data/postgame/story.json. Mewtwo's battle definition is a
-- lane E handoff: SourceEncounters keeps that table private.
PostgameStory = {}
local CONTENT <const> = "postgame"
local REVISION <const> = "af519899719f0754965776faac0e836a3b906e6d"
local cached, playCached
local eventsInstalled, planWrapped, hookRegistered, sceneWrapped, continueWrapped = false, false, false, false, false
local staticContractsRegistered = false
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
    -- registerEventSource only accepts pokered object, background, hidden, and
    -- script ids, and it rejects ids the compiled catalog already owns.
    -- The Mew gift id is postgame:CERULEAN_CAVE_1F:mew-gift. Its handler stays
    -- on SourceEventHandlers. A shared-file pattern change would be a lane E
    -- patch, and lane E is not taking handoffs.
    local accepted = {}
    for id, descriptor in pairs(events) do
        local stable = id:match("^pokered:[^:]+:objects:%d+$")
            or id:match("^pokered:[^:]+:background_events:%d+$")
            or id:match("^pokered:[^:]+:hidden_events:%d+$")
            or id:match("^pokered:[^:]+:script:[%w%-]+$")
        if stable and not SourceEvents.has(id) then
            accepted[id] = descriptor
        end
    end
    SourceEvents.registerTextSource(CONTENT, PostgameStory.text)
    if next(accepted) then
        SourceEvents.registerEventSource(CONTENT, accepted)
    end
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

local function registerStaticContracts()
    -- This file boots while the pdx is still loading, before dev/contracts.
    -- main.lua calls ensureRuntime again after that module exists. A loader
    -- yield can re-enter while `entering` is set, so this stays in front of
    -- that guard and only registers once both objects are present.
    if staticContractsRegistered or not (Contracts and HarnessBuild and HarnessBuild.enabled) then
        return
    end
    if not (PostgameStaticContracts and PostgameStaticContracts.run) then
        return
    end
    Contracts.register("postgame-statics", PostgameStaticContracts.run)
    staticContractsRegistered = true
end

function PostgameStory.ensureRuntime()
    registerStaticContracts()
    if entering then
        return
    end
    entering = true
    PostgameStory.installEvents()
    PostgameStory.installContinue()
    PostgameStory.installHall()
    PostgameStory.installScene()
    registerStaticContracts()
    entering = false
end

function PostgameStory.boot()
    PostgameStory.ensureRuntime()
end

-- SDK contract for the statics. Battle:selectMove, throwBall, and tryRun are
-- the real commands. Nothing here writes the beat flag or the catch result.
-- pokered af519899:
--   data/maps/objects/CeruleanCaveB1F.asm:15 MEWTWO 70 at (27, 13)
--   data/maps/objects/PowerPlant.asm:28-35 Voltorb 40 / Electrode 43, :36 ZAPDOS 50
--   scripts/PowerPlant.asm:36-52 EVENT_BEAT_POWER_PLANT_VOLTORB_0 through _7, then EVENT_BEAT_ZAPDOS
--   data/maps/objects/SeafoamIslandsB4F.asm:22 ARTICUNO 50 at (6, 1)
--   data/maps/objects/VictoryRoad2F.asm:36 MOLTRES 50 at (11, 5)
--   data/maps/objects/Route12.asm:27 SNORLAX at (10, 62); scripts/Route12.asm:35 level 30
--   data/maps/objects/Route16.asm:35 SNORLAX at (26, 10); scripts/Route16.asm:36 level 30
PostgameStaticContracts = {}
local function staticPokemon(species, level)
    return Pokemon(species, level, {natureId = 0, abilitySlot = "first", heldItem = "none"})
end
local function staticOwned(weak)
    local context = GameContext({sessionLocationPolicy = PewterWorld.locationPolicy()})
    local lead = staticPokemon(weak and "caterpie" or "machamp", weak and 1 or 100)
    if not weak then
        lead.moves, lead.pp = {"karateChop"}, {karateChop = moveData.karateChop.maxPP}
    end
    assert(context:recruit(lead))
    assert(context:recruit(staticPokemon("squirtle", 5)))
    assert(context.session:storage():deposit(context.session:party(), 2))
    assert(context.session:setIntro({stage = "done", starter = "squirtle", rivalStarter = "bulbasaur"}))
    assert(context.session:activateRNG())
    return context
end
local function staticSettle(battle)
    for _ = 1, 1200 do
        if battle:phase() ~= "script" then return end
        assert(not battle.pendingLearning, "unexpected learning in static contract")
        assert(battle.machine:get("script"):advance())
    end
    error("static battle did not settle")
end
local function staticBegin(context, request, x, y)
    local token, enemy = context.session:prepareSourceEncounter(request, {zone_id = request.zone_id, x = x, y = y})
    assert(token, enemy)
    assert(enemy.species == request.species and enemy.level == request.level, "prepared species")
    local battle = Battle(context.session:party():active(), enemy, nil,
        {session = context.session, sourceFieldContext = {token = token, zone_id = request.zone_id}})
    local result = {}
    battle:on("battleEnd", function(won, kind)
        local accepted, receipt = context.session:resolveSourceEncounter(battle, won, kind)
        assert(accepted, receipt)
        result.receipt = receipt
        result.kind = kind
    end)
    return battle, result
end
local function staticComplete(battle)
    staticSettle(battle)
    if battle.outcome and not battle.endEmitted then assert(battle:emitEnd()) end
end
local function staticNeighbor(id)
    local positions = assert(SourceEncounters.positions(id), id)
    return positions[1][1], positions[1][2]
end
local function staticPlay(context, request, x, y, kind, flag)
    if kind == "caught" then assert(context.session:inventory():add("masterBall", 1)) end
    local battle, result = staticBegin(context, request, x, y)
    staticSettle(battle)
    if kind == "caught" then
        local thrown, trial = battle:throwBall("masterBall")
        assert(thrown and trial.caught, "master ball missed a static")
        staticSettle(battle)
        assert(battle:emitEnd())
    elseif kind == "run" then
        assert(battle:tryRun())
        staticComplete(battle)
    else
        for _ = 1, kind == "defeat" and 40 or 24 do
            if battle.outcome then break end
            assert(battle:selectMove(1))
            staticSettle(battle)
        end
        staticComplete(battle)
    end
    assert(result.kind == kind, tostring(result.kind))
    if kind == "defeat" then
        assert(not context.session:questFlag(flag), flag)
        assert(result.receipt and not result.receipt.completed, flag)
        assert(not context.session:takeSourceReceipt(request.id))
    else
        assert(context.session:questFlag(flag), flag)
        assert(result.receipt and result.receipt.completed, flag)
    end
    battle:clearListeners()
end
local function staticCase(test, title, request, flag)
    local x, y = staticNeighbor(request.id)
    for _, kind in ipairs({"victory", "caught", "run", "defeat"}) do
        test(title .. " " .. kind, function()
            local prior = RulesRNG.snapshot()
            local priorSession = GameSession.activeRNGSession()
            local sprites = playdate.graphics.sprite.getAllSprites()
            local ok, reason = pcall(function()
                staticPlay(staticOwned(kind == "defeat"), request, x, y, kind, flag)
            end)
            playdate.graphics.sprite.removeAll()
            for _, sprite in ipairs(sprites) do sprite:add() end
            local active = GameSession.activeRNGSession()
            if active then assert(active:deactivateRNG()) end
            if priorSession then assert(priorSession:activateRNG()) end
            RulesRNG.restore(prior)
            if not ok then error(reason, 0) end
        end)
    end
end
function PostgameStaticContracts.run()
    local report = {ok = true, passed = 0, failed = 0, tests = {}}
    local function test(name, body)
        Contracts.progress("postgame-statics", name, "running")
        local ok, reason = pcall(body)
        report.tests[#report.tests + 1] = {name = name, ok = ok, error = not ok and tostring(reason) or nil}
        Contracts.progress("postgame-statics", name, ok and "passed" or "failed")
        if ok then report.passed = report.passed + 1
        else report.failed, report.ok = report.failed + 1, false end
    end
    staticCase(test, "Mewtwo L70", PostgameStory.staticRequest("pokered:CERULEAN_CAVE_B1F:objects:1", {}), "EVENT_BEAT_MEWTWO")
    staticCase(test, "Zapdos L50", PostgameStory.staticRequest("pokered:POWER_PLANT:objects:9", {}), "EVENT_BEAT_ZAPDOS")
    staticCase(test, "Articuno L50", CoastStory.articunoRequest({}), "EVENT_BEAT_ARTICUNO")
    staticCase(test, "Moltres L50", EndgameStory.moltresRequest({}), "EVENT_BEAT_MOLTRES")
    staticCase(test, "Voltorb L40", PostgameStory.staticRequest("pokered:POWER_PLANT:objects:1", {}), "EVENT_BEAT_POWER_PLANT_VOLTORB_0")
    staticCase(test, "Electrode L43", PostgameStory.staticRequest("pokered:POWER_PLANT:objects:4", {}), "EVENT_BEAT_POWER_PLANT_VOLTORB_3")
    local function arm(context, id)
        local definition = assert(SnorlaxStory.definition(id))
        assert(context.session:inventory():add("pokeFlute", 1))
        assert(context.session:setQuestFlag(definition.fight_flag, true))
        return assert(SnorlaxStory.request(context.session, id))
    end
    for _, kind in ipairs({"victory", "caught", "run", "defeat"}) do
        test("Route 12 Snorlax L30 " .. kind, function()
            local prior = RulesRNG.snapshot()
            local priorSession = GameSession.activeRNGSession()
            local sprites = playdate.graphics.sprite.getAllSprites()
            local ok, reason = pcall(function()
                local context = staticOwned(kind == "defeat")
                local request = arm(context, "pokered:ROUTE_12:objects:1")
                local x, y = staticNeighbor(request.id)
                staticPlay(context, request, x, y, kind, "EVENT_BEAT_ROUTE12_SNORLAX")
            end)
            playdate.graphics.sprite.removeAll()
            for _, sprite in ipairs(sprites) do sprite:add() end
            local active = GameSession.activeRNGSession()
            if active then assert(active:deactivateRNG()) end
            if priorSession then assert(priorSession:activateRNG()) end
            RulesRNG.restore(prior)
            if not ok then error(reason, 0) end
        end)
    end
    test("remaining static rows prepare the pinned species and level", function()
        local context = staticOwned(false)
        local rows = {
            {"pokered:POWER_PLANT:objects:2", "voltorb", 40},
            {"pokered:POWER_PLANT:objects:3", "voltorb", 40},
            {"pokered:POWER_PLANT:objects:5", "voltorb", 40},
            {"pokered:POWER_PLANT:objects:6", "voltorb", 40},
            {"pokered:POWER_PLANT:objects:7", "electrode", 43},
            {"pokered:POWER_PLANT:objects:8", "voltorb", 40},
        }
        for _, row in ipairs(rows) do
            local request = PostgameStory.staticRequest(row[1], {})
            local x, y = staticNeighbor(row[1])
            local token, enemy = context.session:prepareSourceEncounter(request, {zone_id = request.zone_id, x = x, y = y})
            assert(token, enemy)
            assert(enemy.species == row[2] and enemy.level == row[3], row[1])
            assert(context.session:cancelSourceEncounter(token))
        end
        local request = arm(context, "pokered:ROUTE_16:objects:7")
        local x, y = staticNeighbor(request.id)
        local token, enemy = context.session:prepareSourceEncounter(request, {zone_id = request.zone_id, x = x, y = y})
        assert(token and enemy.species == "snorlax" and enemy.level == 30, "route 16 snorlax")
        assert(context.session:cancelSourceEncounter(token))
        context.session:deactivateRNG()
    end)
    test("revived Dome Fossil survives a Simulator save and Continue", function()
        local live = game
        assert(live and live.saves and live.session, "live simulator session")
        assert(live.machine:getCurrent() == "overworld" and live.machine:depth() == 1, "save needs the overworld")
        assert(live.session:inventory():add("domeFossil", 1))
        local offered = FossilRevival.confirm(live.session, "DOME_FOSSIL", true)
        assert(offered.ok and offered.status == "reviving", offered.status)
        assert(FossilRevival.storedItem(live.session) == 41)
        assert(live.session:questFlag("EVENT_GAVE_FOSSIL_TO_LAB"))
        assert(live.session:questFlag("EVENT_LAB_STILL_REVIVING_FOSSIL"))
        assert(live.session:questFlag("wFossilItem:DOME_FOSSIL") and live.session:questFlag("wFossilMon:KABUTO"))
        local cleared = FossilRevival.onMapLoad(live.session, "CINNABAR_ISLAND")
        assert(cleared.ok and cleared.status == "cleared", cleared.status)
        assert(not live.session:questFlag("EVENT_LAB_STILL_REVIVING_FOSSIL"))
        -- The live game has a naming state. Passing it would push the nickname
        -- dialog and leave the machine too deep to save. The specimen still
        -- lands in this session; the dialog is not part of the round trip.
        local revived = FossilRevival.talk(live.session, nil, {session = live.session})
        assert(revived.ok and revived.status == "revived", revived.status)
        assert(revived.species == "KABUTO" and revived.level == 30 and revived.destination == "party")
        local mon = live.session:party():get(revived.index)
        assert(mon.species == "kabuto" and mon.level == 30)
        assert(FossilRevival.storedItem(live.session) == 0)
        assert(not live.session:questFlag("EVENT_GAVE_FOSSIL_TO_LAB"))
        assert(not live.session:questFlag("EVENT_LAB_STILL_REVIVING_FOSSIL"))
        assert(not live.session:questFlag("EVENT_LAB_HANDING_OVER_FOSSIL_MON"))
        assert(not live.session:questFlag("wFossilItem:DOME_FOSSIL") and not live.session:questFlag("wFossilMon:KABUTO"))
        local saved, problem = live.saves:save()
        assert(saved, problem and (problem.reason or problem.error) or "save failed")
        mon.level = 1
        assert(live.session:setQuestFlag("EVENT_GAVE_FOSSIL_TO_LAB", true))
        local continued, loaded = live.saves:continueGame()
        assert(continued, loaded and (loaded.reason or loaded.error) or "continue failed")
        mon = live.session:party():get(revived.index)
        assert(mon.species == "kabuto" and mon.level == 30, "continued fossil")
        assert(FossilRevival.storedItem(live.session) == 0)
        assert(not live.session:questFlag("EVENT_GAVE_FOSSIL_TO_LAB"))
        assert(not live.session:questFlag("EVENT_LAB_STILL_REVIVING_FOSSIL"))
        assert(not live.session:questFlag("EVENT_LAB_HANDING_OVER_FOSSIL_MON"))
        assert(not live.session:questFlag("wFossilItem:DOME_FOSSIL") and not live.session:questFlag("wFossilMon:KABUTO"))
    end)
    return report
end

PostgameStory.boot()
