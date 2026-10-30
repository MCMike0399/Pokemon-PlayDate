-- Four game behavior contracts using real SDK owners and actual battle commands.
-- They arrange prerequisites, but never inject a terminal outcome or catch result.
SourceEncounterContracts = {}
local function same(a, b)
    assert(SourceEncounters.equal(a, b), "source encounter value changed")
end
local function pokemon(species, level)
    return Pokemon(species, level, {natureId = 0, abilitySlot = "first", heldItem = "none"})
end
local function owned(weak)
    local game = GameContext({sessionLocationPolicy=PewterWorld.locationPolicy()})
    local lead = pokemon(weak and "caterpie" or "machamp", weak and 1 or 100)
    if not weak then
        lead.moves, lead.pp = {"karateChop"}, {karateChop = moveData.karateChop.maxPP}
    end
    assert(game:recruit(lead))
    assert(game.session:setIntro({stage="done", starter="squirtle", rivalStarter="bulbasaur"}))
    assert(game.session:activateRNG())
    return game
end
local function settle(battle)
    for _ = 1, 1200 do
        if battle:phase() ~= "script" then return end
        assert(not battle.pendingLearning, "unexpected learning in source contract")
        assert(battle.machine:get("script"):advance())
    end
    error("source battle did not settle")
end
local function begin(game, request, x, y)
    local token, enemy = game.session:prepareSourceEncounter(request, {zone_id=request.zone_id, x=x, y=y})
    assert(token, enemy)
    local battle = Battle(game.session:party():active(), enemy, nil,
        {session=game.session, sourceFieldContext={token=token, zone_id=request.zone_id}})
    local result = {}
    battle:on("battleEnd", function(won, kind)
        local accepted, receipt = game.session:resolveSourceEncounter(battle, won, kind)
        assert(accepted, receipt)
        result.receipt = receipt
        result.kind = kind
    end)
    return battle, result
end
local function complete(battle)
    settle(battle)
    if battle.outcome and not battle.endEmitted then assert(battle:emitEnd()) end
end
local function arm(game, id)
    local d = assert(SnorlaxStory.definition(id))
    assert(game.session:inventory():add("pokeFlute", 1))
    assert(game.session:setQuestFlag(d.fight_flag, true))
    return assert(SnorlaxStory.request(game.session, id))
end
local function fill(game)
    while game.session:party():count() < Party.CAPACITY do
        assert(game:recruit(pokemon("magikarp", 1)))
    end
    while game.session:storage():count() < Storage.BOX_CAPACITY do
        assert(game:recruit(pokemon("magikarp", 1)))
    end
end
function SourceEncounterContracts.run()
    local report = {ok=true, passed=0, failed=0, tests={}}
    local function test(name, body)
        local prior = RulesRNG.snapshot()
        local priorSession = GameSession.activeRNGSession()
        local sprites = playdate.graphics.sprite.getAllSprites()
        local ok, reason = pcall(body)
        playdate.graphics.sprite.removeAll()
        for _, sprite in ipairs(sprites) do sprite:add() end
        local active = GameSession.activeRNGSession()
        if active then assert(active:deactivateRNG()) end
        if priorSession then assert(priorSession:activateRNG()) end
        RulesRNG.restore(prior)
        report.tests[#report.tests+1] = {name=name, ok=ok, error=not ok and tostring(reason) or nil}
        if ok then report.passed = report.passed + 1
        else report.failed, report.ok = report.failed + 1, false end
    end
    test("source ghosts: identification, fear, uncapturable Marowak and confirmed completion", function()
        local game = owned()
        local request = TowerStory.ghostRequest(game.session)
        local forged = GameSession._copy(request)
        forged.outcomes.victory.flags.EVENT_GOT_MASTER_BALL = true
        local before = RulesRNG.snapshot()
        assert(not game.session:prepareSourceEncounter(forged, {zone_id=request.zone_id,x=10,y=16}))
        same(RulesRNG.snapshot(), before)
        assert(not game.session:prepareSourceEncounter(request, {zone_id=request.zone_id,x=11,y=16}))
        same(RulesRNG.snapshot(), before)
        local token = assert(game.session:prepareSourceEncounter(request, {zone_id=request.zone_id,x=10,y=16}))
        same(RulesRNG.snapshot(), before)
        assert(game.session:cancelSourceEncounter(token))
        same(RulesRNG.snapshot(), before)
        -- A prepared intent cannot publish another active session's RNG.
        token, before = assert(game.session:prepareSourceEncounter(request,
            {zone_id=request.zone_id,x=10,y=16})), RulesRNG.snapshot()
        local foreign = owned()
        local foreignBefore = RulesRNG.snapshot()
        local enemy = GameSession._state(game.session).sourcePending.enemy
        assert(not pcall(Battle, game.session:party():active(), enemy, nil,
            {session=game.session, sourceFieldContext={token=token,zone_id=request.zone_id}}))
        same(RulesRNG.snapshot(), foreignBefore)
        assert(game.session:cancelSourceEncounter(token))
        assert(game.session:activateRNG())
        same(RulesRNG.snapshot(), before)
        local battle, result = begin(game, request, 10, 16)
        assert(battle:opponentDisplayName() == "GHOST" and battle.message:find("GHOST", 1, true))
        assert(not game.session:pokedex().seen.marowak)
        settle(battle)
        local hp, pp = battle.enemy.hp, battle.player.pp.karateChop
        before = RulesRNG.snapshot()
        assert(battle:selectMove(1))
        settle(battle)
        assert(battle.enemy.hp == hp and battle.player.pp.karateChop == pp)
        same(RulesRNG.snapshot(), before)
        assert(game.session:inventory():add("masterBall", 1))
        before = RulesRNG.snapshot()
        local thrown, trial = battle:throwBall("masterBall")
        assert(thrown and not trial.caught and trial.source_blocked)
        settle(battle)
        same(RulesRNG.snapshot(), before)
        assert(game.session:inventory():quantity("masterBall") == 0)
        assert(not game.session:pokedex().owned.marowak and not game.session:pokedex().seen.marowak)
        assert(not game.session:resolveSourceEncounter(battle, false, "run"))
        assert(battle:tryRun())
        complete(battle)
        assert(result.kind == "run" and not result.receipt.completed)
        assert(not game.session:questFlag("EVENT_BEAT_GHOST_MAROWAK"))
        assert(game.session:takeSourceReceipt(TowerStory.GHOST).kind == "run")
        assert(not game.session:takeSourceReceipt(TowerStory.GHOST))
        -- Ordinary Tower encounters share the unidentified policy and do not
        -- generate a scripted progression receipt.
        local ordinary = Battle(game.session:party():active(), pokemon("gastly", 20), nil,
            {session=game.session, sourceFieldContext={zone_id="pokered:POKEMON_TOWER_3F"}})
        assert(ordinary:opponentDisplayName() == "GHOST" and not game.session:pokedex().seen.gastly)
        game.session:abortSourceBattle(ordinary)
        ordinary:clearListeners()
        ordinary:clearVolatiles()
        assert(game.session:inventory():add("silphScope", 1))
        battle, result = begin(game, TowerStory.ghostRequest(game.session), 10, 16)
        settle(battle)
        assert(game.session:pokedex().seen.marowak and not battle.sourceEncounter.unidentified)
        assert(game.session:inventory():add("masterBall", 1))
        thrown, trial = battle:throwBall("masterBall")
        assert(thrown and not trial.caught and trial.source_blocked)
        settle(battle)
        for _ = 1, 4 do
            if battle.outcome then break end
            assert(battle:selectMove(1))
            settle(battle)
        end
        complete(battle)
        assert(result.kind == "victory" and result.receipt.completed)
        assert(game.session:questFlag("EVENT_BEAT_GHOST_MAROWAK"))
        assert(not game.session:pokedex().owned.marowak)
    end)
    test("source Snorlax: genuine capture, victory, escape, defeat, capacity and cancellation", function()
        local ids = {"pokered:ROUTE_12:objects:1", "pokered:ROUTE_16:objects:7"}
        for index, id in ipairs(ids) do
            local game = owned()
            local d = SnorlaxStory.definition(id)
            local request = arm(game, id)
            if index == 2 then
                while game.session:party():count() < Party.CAPACITY do
                    assert(game:recruit(pokemon("magikarp", 1)))
                end
                assert(game.session:storage():selectBox(3))
            end
            assert(game.session:inventory():add("masterBall", 1))
            local battle, result = begin(game, request, index == 1 and 9 or 25, index == 1 and 62 or 10)
            settle(battle)
            assert(not game.session:questFlag(d.fight_flag))
            local count = game.session:party():count()
            local thrown, trial = battle:throwBall("masterBall")
            assert(thrown and trial.caught and not Party._owner(battle.enemy))
            assert(game.session:party():count() == count and not game.session:questFlag(d.defeated_flag))
            settle(battle)
            assert(battle.outcome == "caught" and not game.session:questFlag(d.defeated_flag))
            assert(not game.session:resolveSourceEncounter(battle, false, "caught"))
            assert(battle:emitEnd())
            assert(result.kind == "caught" and result.receipt.completed)
            if index == 1 then
                assert(game.session:party():get(count + 1) == battle.enemy)
                assert(trial.destination.destination == "party")
            else
                assert(game.session:storage():get(trial.destination.index) == battle.enemy)
                assert(trial.destination.destination == "storage" and trial.destination.box == 3)
                assert(game.session:party():count() == count)
            end
            assert(game.session:questFlag(d.defeated_flag))
            assert(not game.session:questFlag(SnorlaxStory.definition(ids[3-index]).defeated_flag))
            assert(game.session:pokedex().owned.snorlax)
            assert(not battle:emitEnd())
            assert(not game.session:resolveSourceEncounter(battle, false, "caught"))
            local wire = assert(SessionCodec.encode(game.session, {root="overworld",overworld="explore",settled=true}))
            local restored = assert(SessionCodec.decode(wire, game:getSessionDependencies()))
            assert(restored:questFlag(d.defeated_flag) and restored:pokedex().owned.snorlax)
            assert(not restored:takeSourceReceipt(id))
        end
        -- Real run command: Blue removes Snorlax even when the player escapes.
        local game = owned()
        local request = arm(game, ids[1])
        local battle, result = begin(game, request, 9, 62)
        settle(battle)
        assert(battle:tryRun())
        complete(battle)
        assert(result.kind == "run" and game.session:questFlag("EVENT_BEAT_ROUTE12_SNORLAX"))
        -- Real damaging move, never an injected faint/result.
        game = owned()
        request = arm(game, ids[2])
        battle, result = begin(game, request, 25, 10)
        settle(battle)
        for _ = 1, 4 do
            if battle.outcome then break end
            assert(battle:selectMove(1))
            settle(battle)
        end
        complete(battle)
        assert(result.kind == "victory" and game.session:questFlag("EVENT_BEAT_ROUTE16_SNORLAX"))
        -- Real low-level combat loss preserves the blocker and grants no catch.
        game = owned(true)
        request = arm(game, ids[1])
        battle, result = begin(game, request, 9, 62)
        settle(battle)
        for _ = 1, 40 do
            if battle.outcome then break end
            assert(battle:selectMove(1))
            settle(battle)
        end
        complete(battle)
        assert(result.kind == "defeat" and game.session:party():allFainted())
        assert(not game.session:questFlag("EVENT_BEAT_ROUTE12_SNORLAX"))
        assert(not game.session:takeSourceReceipt(ids[1]))
        game = owned()
        fill(game)
        request = arm(game, ids[1])
        assert(game.session:inventory():add("masterBall", 1))
        battle = begin(game, request, 9, 62)
        settle(battle)
        local before = RulesRNG.snapshot()
        assert(not battle:throwBall("masterBall"))
        same(RulesRNG.snapshot(), before)
        assert(game.session:inventory():quantity("masterBall") == 1)
        assert(not game.session:questFlag("EVENT_BEAT_ROUTE12_SNORLAX"))
        game.session:abortSourceBattle(battle)
        battle:clearListeners()
        battle:clearVolatiles()
        game = owned()
        request = arm(game, ids[2])
        assert(game.session:inventory():add("masterBall", 1))
        battle = begin(game, request, 25, 10)
        settle(battle)
        assert(battle:throwBall("masterBall"))
        assert(game.session:abortSourceBattle(battle))
        battle:clearListeners()
        battle:clearVolatiles()
        assert(not Party._owner(battle.enemy) and not game.session:pokedex().owned.snorlax)
        assert(not game.session:questFlag("EVENT_BEAT_ROUTE16_SNORLAX"))
        assert(game.session:inventory():quantity("masterBall") == 0)
    end)
    test("Dojo gift: exclusive flags and specimen claim share the existing gift commit", function()
        local game = owned()
        local before = RulesRNG.snapshot()
        local offer = MidgameGymStory.giftOffer("pokered:FIGHTING_DOJO:objects:6")
        local malformed = GameSession._copy(offer)
        malformed.extra_flags.EVENT_GOT_MASTER_BALL = true
        assert(not game.session:purchaseGiftPokemon(malformed, game.session:inventory():money()))
        same(RulesRNG.snapshot(), before)
        assert(not game.session:questFlag("EVENT_GOT_HITMONLEE"))
        local accepted = game.session:purchaseGiftPokemon(offer, game.session:inventory():money())
        assert(accepted and game.session:party():get(2).species == "hitmonlee")
        assert(game.session:party():get(2).level == 30)
        assert(game.session:questFlag("EVENT_GOT_HITMONLEE") and game.session:questFlag("EVENT_DEFEATED_FIGHTING_DOJO"))
        assert(not game.session:questFlag("EVENT_GOT_HITMONCHAN") and not game.session:questFlag("EVENT_BEAT_KARATE_MASTER"))
        before = RulesRNG.snapshot()
        assert(not game.session:purchaseGiftPokemon(MidgameGymStory.giftOffer("pokered:FIGHTING_DOJO:objects:7"), game.session:inventory():money()))
        same(RulesRNG.snapshot(), before)
        game = owned()
        fill(game)
        offer = MidgameGymStory.giftOffer("pokered:FIGHTING_DOJO:objects:7")
        before = RulesRNG.snapshot()
        assert(not game.session:purchaseGiftPokemon(offer, game.session:inventory():money()))
        same(RulesRNG.snapshot(), before)
        assert(not game.session:questFlag("EVENT_GOT_HITMONCHAN"))
        local released = game.session:storage():get(1)
        assert(game.session:storage():release(1, released))
        local result
        accepted, result = game.session:purchaseGiftPokemon(offer, game.session:inventory():money())
        assert(accepted and result.destination == "storage")
        assert(game.session:storage():get(result.index).species == "hitmonchan")
        assert(game.session:questFlag("EVENT_GOT_HITMONCHAN") and game.session:questFlag("EVENT_DEFEATED_FIGHTING_DOJO"))
    end)
    test("Bicycle session mode: reversible false-to-false source bit and stale context guards", function()
        local game = owned()
        assert(game.session:inventory():add("bicycle", 1))
        local travel = game.session:fieldTravelData()
        local epoch = game.session:fieldWorldEpoch()
        local actors = game.session:actorData()
        local candidate = assert(FieldCycling.toggle(travel, false, true, "ROUTE_1", "OVERWORLD"))
        assert(game.session:commitCycling(epoch, travel, false, candidate))
        assert(game.session:fieldTravelData().mode == "bicycle")
        assert(not game.session:questFlag(FieldCycling.FLAG))
        assert(not game.session:commitCycling(epoch, travel, false, candidate))
        travel, epoch = game.session:fieldTravelData(), game.session:fieldWorldEpoch()
        candidate = assert(FieldCycling.toggle(travel, false, true, "ROUTE_1", "OVERWORLD"))
        assert(game.session:commitCycling(epoch, travel, false, candidate))
        assert(game.session:fieldTravelData().mode == "walking")
        same(game.session:actorData(), actors)
        -- Actual source Cycling Road entry publishes the mode and source bit in
        -- the same existing traversal boundary. Bad actor/boolean candidates
        -- leave every previously published owner value untouched.
        local entry = assert(FieldCycling.enter(game.session:fieldTravelData(), false, true,
            "ROUTE_16", "OVERWORLD", 17, 10, "map"))
        local snapshot = {location={zone_id="pokered:ROUTE_16",x=17,y=10,facing="left"},
            world=game.session:worldData(), fieldTravel=entry.travel, cyclingForced=entry.forced}
        local beforeFlags, beforeLocation = game.session:flags(), game.session:location()
        epoch = game.session:fieldWorldEpoch()
        local invalid = GameSession._copy(snapshot)
        invalid.cyclingForced = 1
        assert(not game.session:captureTraversal(invalid))
        same(game.session:flags(), beforeFlags)
        same(game.session:location(), beforeLocation)
        assert(game.session:fieldWorldEpoch() == epoch)
        invalid = GameSession._copy(snapshot)
        invalid.actors = WorldMotionData.empty()
        invalid.actors.count = 1
        assert(not game.session:captureTraversal(invalid))
        same(game.session:flags(), beforeFlags)
        same(game.session:location(), beforeLocation)
        assert(game.session:fieldTravelData().mode == "walking")
        assert(game.session:fieldWorldEpoch() == epoch)
        assert(game.session:captureTraversal(snapshot))
        assert(game.session:questFlag(FieldCycling.FLAG))
        assert(game.session:fieldTravelData().mode == "bicycle")
        same(game.session:location(), snapshot.location)
        local wire = assert(SessionCodec.encode(game.session,{root="overworld",overworld="explore",settled=true}))
        local restored = assert(SessionCodec.decode(wire,game:getSessionDependencies()))
        assert(restored:questFlag(FieldCycling.FLAG) and restored:fieldTravelData().mode == "bicycle")
        assert(SessionCodec.VERSION == 4)
    end)
    return report
end
