-- Blue's positional rivals and two Rocket scripts. No geometry, text or roster
-- copies: the pinned scene projection and CeruleanContent supply those inputs.
CeruleanRoutes = {}
local CONTENT <const> = "ceruleanRoutes"
local ROUTE <const> = "pokered:ROUTE_22:objects:1"
local RIVAL <const> = "pokered:CERULEAN_CITY:objects:1"
local THIEF <const> = "pokered:CERULEAN_CITY:objects:2"
local NUGGET <const> = "pokered:ROUTE_24:objects:1"
local HIDDEN <const> = "TOGGLE_CERULEAN_ROCKET"
local counter = {charmander="squirtle", squirtle="bulbasaur", bulbasaur="charmander"}
local cached, integration
local qualified = false
local decodeFile <const> = json.decodeFile
local function copy(value) return GameSession._copy(value) end
local function data()
    if not cached then
        local path = "data/ceruleanRoutes/scenes.json"
        if qualified then
            cached = ShippedDataPolicy.readBundleJSON(path)
        else
            cached = assert(decodeFile(path))
        end
        assert(cached.schema == 1 and cached.source_revision == "af519899719f0754965776faac0e836a3b906e6d",
            "unverified Blue route scripts")
    end
    return cached
end
local function padding(zoneID)
    return SourceMaps.entry(assert(SourceMaps.nameForID(zoneID))).padding
end
local function text(label) return {op="dialog", labels={label}} end
local function empty(status) return {status=status, steps={}} end
local function at(points, x, y)
    for index, point in ipairs(points) do
        if point.x == x and point.y == y then return index end
    end
end
function CeruleanRoutes.scenes() return copy(data()) end
function CeruleanRoutes.text(label) return CeruleanContent.text(label) end

-- The ordinary importer already owns the Rockets. Only rivals need new
-- definitions. Each variant is a defensive projection of its imported class.
function CeruleanRoutes.trainers()
    local classes, result = CeruleanContent.rivalClasses(), {}
    for _, scene in pairs(data().rivals) do
        local class = assert(classes[scene.class])
        local variants = {}
        for starter, rival in pairs(counter) do
            local number = assert(scene.roster_by_rival_starter[rival])
            local party = copy(assert(class.parties[number]).party)
            assert(party[#party].species == rival, "Blue counter team mismatch")
            variants[starter] = {party=party, payout=class.base_money * party[#party].level}
        end
        local id = scene.id
        result[id] = {id=id, map_id="pokered:" .. id:match("^pokered:([^:]+):"), name="BLUE",
            sprite_source=scene.sprite_source, sight_range_cells=0, talk_only=true,
            party=copy(variants.charmander.party), payout=variants.charmander.payout,
            rival_parties=variants}
    end
    return result
end

function CeruleanRoutes.descriptors()
    local events = {}
    for name, scene in pairs(data().rivals) do
        local route = name == "route22"
        local flags = route and {EVENT_BEAT_ROUTE22_RIVAL_1ST_BATTLE=true,
            EVENT_1ST_ROUTE22_RIVAL_BATTLE=false, EVENT_ROUTE22_RIVAL_WANTS_BATTLE=false}
            or {EVENT_BEAT_CERULEAN_RIVAL=true}
        local positions = copy(scene.script_positions)
        local exceptions = copy(scene.script_collision_positions)
        local pad = padding("pokered:" .. scene.id:match("^pokered:([^:]+):"))
        for _, list in ipairs({positions,exceptions}) do
            for _, position in ipairs(list) do position.x = position.x + pad end
        end
        events[scene.id] = {kind="bespoke", content=CONTENT, scene_script=name,
            lost={route and "_Route22Rival1VictoryText" or "_CeruleanCityRivalVictoryText"},
            script_positions=positions, script_collision_positions=exceptions, victory={guard_flags=route and {
                "EVENT_BEAT_ROUTE22_RIVAL_1ST_BATTLE", "EVENT_1ST_ROUTE22_RIVAL_BATTLE", "EVENT_ROUTE22_RIVAL_WANTS_BATTLE"}
                or {"EVENT_BEAT_CERULEAN_RIVAL"}, flags=flags}}
    end
    -- Bind the overlapping source object as explicitly unavailable, rather
    -- than leaving an unresolved blocker on top of the first rival's origin.
    events["pokered:ROUTE_22:objects:2"] = {kind="bespoke",content=CONTENT,scene_script="later-rival"}
    events[NUGGET] = {kind="bespoke", content=CONTENT, item="nugget", scene_script="nugget",
        lost={"_Route24CooltrainerM1DefeatedText"},
        victory={guard_flags={"EVENT_BEAT_ROUTE24_ROCKET"}, flags={EVENT_BEAT_ROUTE24_ROCKET=true}}}
    events[THIEF] = {kind="trainer", content=CONTENT, lost={"_CeruleanCityRocketIGiveUpText"},
        before={"_CeruleanCityRocketText"}, won={"_CeruleanCityRocketIGiveUpText"},
        after={"_CeruleanCityRocketIllReturnTheTMText"},
        victory={guard_flags={"EVENT_BEAT_CERULEAN_ROCKET_THIEF"}, flags={EVENT_BEAT_CERULEAN_ROCKET_THIEF=true}},
        reward={item="tm28", flag=HIDDEN, before={"_CeruleanCityRocketIllReturnTheTMText"},
            success={"_CeruleanCityRocketReceivedTM28Text", "_CeruleanCityRocketIBetterGetMovingText"},
            full={"_CeruleanCityRocketTM28NoRoomText"}, full_status="tm28-bag-full"}}
    return events
end

-- Source first-rival availability starts after the lab, and Brock clears it.
-- This also migrates accepted pre-region saves without a new bootstrap flag.
function CeruleanRoutes.initialize(session)
    if session:getIntro().stage ~= "done" or session:hasBadge("boulder")
        or session:trainerDefeated(ROUTE) or session:questFlag("EVENT_BEAT_ROUTE22_RIVAL_1ST_BATTLE") then return true end
    local flags = session:flags().quest
    if flags.EVENT_1ST_ROUTE22_RIVAL_BATTLE and flags.EVENT_ROUTE22_RIVAL_WANTS_BATTLE then return true end
    return session:transact({flags={EVENT_1ST_ROUTE22_RIVAL_BATTLE=flags.EVENT_1ST_ROUTE22_RIVAL_BATTLE == true,
        EVENT_ROUTE22_RIVAL_WANTS_BATTLE=flags.EVENT_ROUTE22_RIVAL_WANTS_BATTLE == true}, items={}},
        {flags={EVENT_1ST_ROUTE22_RIVAL_BATTLE=true, EVENT_ROUTE22_RIVAL_WANTS_BATTLE=true}, items={}})
end
function CeruleanRoutes.nuggetPlan(session)
    if session:questFlag("EVENT_GOT_NUGGET") then return nil, "already-complete" end
    return {expected={flags={EVENT_GOT_NUGGET=false}, items={nugget=session:inventory():quantity("nugget")}},
        changes={flags={EVENT_GOT_NUGGET=true}, items={{op="add",id="nugget",quantity=1}}}}
end
function CeruleanRoutes.plan(id, state)
    assert(id ~= "pokered:ROUTE_22:objects:2", "second Route22 rival belongs to the later campaign")
    if id == NUGGET then
        if state.receipt then
            assert(state.receipt.won and state.trainers[id], "unconfirmed Rocket receipt")
            return {status="ready", ram={wAmountMoneyWon=state.receipt.payout}, steps={
                {op="confirmed-dialog",labels={"_Route24CooltrainerM1DefeatedText"}},
                {op="confirmed-dialog",labels={"_MoneyForWinningText"}},
                text("_Route24CooltrainerM1YouCouldBecomeATopLeaderText")}}
        end
        -- In Blue the gift is before battle. After a loss the gift stays, and
        -- the next interaction is the leader speech, not another paid battle.
        if state.flags.EVENT_GOT_NUGGET then
            return {status="already-complete",steps={text("_Route24CooltrainerM1YouCouldBecomeATopLeaderText")}}
        end
        return {status="ready",scene="cerulean-routes",scene_script="nugget",steps={}}
    end
    assert(id == ROUTE or id == RIVAL, "unsupported Blue route identity")
    if state.receipt then
        assert(state.receipt.won and state.trainers[id], "unconfirmed rival receipt")
        return {status="ready",scene="cerulean-routes",scene_script=id == ROUTE and "route22-exit" or "cerulean-exit",
            ram={wAmountMoneyWon=state.receipt.payout},steps={}}
    end
    if state.trainers[id] or id == ROUTE and not (state.flags.EVENT_1ST_ROUTE22_RIVAL_BATTLE
        and state.flags.EVENT_ROUTE22_RIVAL_WANTS_BATTLE) then return empty("unavailable-rival") end
    return {status="ready",scene="cerulean-routes",scene_script=id == ROUTE and "route22" or "cerulean",steps={}}
end

-- Bill owns guard visibility. This layer only reads his documented flags.
function CeruleanRoutes.actorMetadata(id, game)
    if id == ROUTE then
        if game and game.trainers and game.trainers:peekReceipt(ROUTE) then return {} end
        return {visibility={{group="quest",id="EVENT_1ST_ROUTE22_RIVAL_BATTLE",equals=true},
            {group="quest",id="EVENT_ROUTE22_RIVAL_WANTS_BATTLE",equals=true}}}
    elseif id == "pokered:ROUTE_22:objects:2" then
        return {visibility={{group="quest",id="EVENT_2ND_ROUTE22_RIVAL_BATTLE",equals=true}}}
    elseif id == RIVAL then
        -- A fresh return rebuild must keep the actor until its explicit receipt
        -- controller finishes departure. A continued save has no such receipt.
        if game and game.trainers and game.trainers:peekReceipt(RIVAL) then return {} end
        return {visibility={{group="trainers",id=RIVAL,equals=false}}}
    elseif id == THIEF then
        return {visibility={{group="quest",id=HIDDEN,equals=false}}}
    end
    return {}
end
function CeruleanRoutes.install(options)
    assert(not integration, "Blue route scripts already installed")
    assert(options and type(options.reconcileActors) == "function", "root source actor reconciliation required")
    integration = options
    local declared, declaration = SourceEvents._registerRegionDeclaration(
        CONTENT, "data/ceruleanRoutes/", "kanto-first-entry-v1")
    if not declared then
        assert(SourceEvents.trainerDefinition(THIEF) and SourceEvents.trainerDefinition(NUGGET),
            "install imported ordinary Rocket teams first")
        SourceEvents.registerTrainerSource(CONTENT, CeruleanRoutes.trainers)
    end
    qualified = declared
    local events = declared and declaration.bespoke or CeruleanRoutes.descriptors()
    for id, descriptor in pairs(events) do
        if declared or descriptor.kind == "bespoke" then
            assert(not SourceEventHandlers[id], "duplicate Blue route handler")
            local stableID = id
            SourceEventHandlers[id] = function(state) return CeruleanRoutes.plan(stableID,state) end
        end
    end
    if not declared then SourceEvents.registerEventSource(CONTENT, events) end
    SourceEvents.registerTextSource(CONTENT,CeruleanRoutes.text)
end
function CeruleanRoutes.check(game)
    if game.machine:getCurrent() ~= "overworld" or game.session:getIntro().stage ~= "done"
        or not game.player or game.player.isMoving or game.player.pendingEdgeDoor or game.player.pendingConnection then return false end
    assert(CeruleanRoutes.initialize(game.session))
    local zone, player = currentZone, game.player
    if not zone or (zone.stableID ~= "pokered:ROUTE_22" and zone.stableID ~= "pokered:CERULEAN_CITY"
        and zone.stableID ~= "pokered:ROUTE_24") then return false end
    local x, y = player.gridX - padding(zone.stableID), player.gridY
    local id
    if zone.stableID == "pokered:ROUTE_22" and not game.session:trainerDefeated(ROUTE)
        and game.session:questFlag("EVENT_ROUTE22_RIVAL_WANTS_BATTLE") and at(data().triggers.route22,x,y) then id=ROUTE
    elseif zone.stableID == "pokered:CERULEAN_CITY" then
        if not game.session:trainerDefeated(THIEF) and at(data().triggers.thief,x,y) then id=THIEF
        elseif not game.session:trainerDefeated(RIVAL) and at(data().triggers.cerulean,x,y) then id=RIVAL end
    elseif zone.stableID == "pokered:ROUTE_24" and not game.session:questFlag("EVENT_GOT_NUGGET")
        and at(data().triggers.nugget,x,y) then id=NUGGET end
    if id then return SourceEvents.dispatch(game,id) end
    return false
end
CeruleanRoutes.ROUTE, CeruleanRoutes.RIVAL, CeruleanRoutes.THIEF, CeruleanRoutes.NUGGET = ROUTE,RIVAL,THIEF,NUGGET

function CeruleanRoutes.reconcileActors(game)
    assert(integration, "Blue route integration missing").reconcileActors(game)
end
