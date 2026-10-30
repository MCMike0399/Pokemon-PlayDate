-- Actual SDK witnesses prepared for root. Compilation is not execution evidence.
DaycareContracts = {}
local gfx <const> = playdate.graphics
local GATE <const> = {root="overworld", overworld="explore", settled=true}
local ID <const> = "pokered:DAYCARE:objects:1"
local function eq(a, b, context)
    assert(a == b, (context or "value") .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
end
local function same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        eq(a, b)
        return
    end
    for key, value in pairs(a) do
        same(value, b[key])
    end
    for key in pairs(b) do
        assert(a[key] ~= nil, "extra field " .. tostring(key))
    end
end
local function fresh(species, level)
    local g = GameContext({sessionLocationPolicy=PewterWorld.locationPolicy()})
    assert(g.session:setIntro({stage="done", starter="squirtle", rivalStarter="bulbasaur"}))
    assert(g.session:recruit(Pokemon("squirtle", 5)))
    local mon = Pokemon(species or "charmander", level or 15)
    assert(g.session:recruit(mon))
    return g, g.session, mon
end
local function deposit(s, index)
    local request, plan = Daycare.prepare(s, "deposit", index or 2)
    eq(plan.status, "ready")
    assert(s:resolveDaycare(request, true))
    return request
end
local function steps(s, count)
    for _ = 1, count do
        s:daycareStep()
    end
end
local function wire(s)
    return assert(SessionCodec.encode(s, GATE))
end
local function roundtrip(g)
    return assert(SessionCodec.decode(json.decode(json.encode(wire(g.session))), g:getSessionDependencies()))
end
local function drain(g)
    for _ = 1, 512 do
        if g.machine:getCurrent() ~= "dialog" then
            return
        end
        local state = g.machine:get("dialog")
        state.dialog:advance()
        state:handleInput()
    end
    error("Day Care dialogue did not settle")
end
-- Failure-only native context. These probes forward the exact production calls;
-- they never advance Player, manufacture a completion, or change gate results.
local function worldScene(name, entry, fn)
    local oldRegistry, oldList, oldZone = zoneRegistry, zoneList, currentZone
    local oldStory, oldRNG, oldOwner = Story.currentContext(), RulesRNG.toData(), GameSession.activeRNGSession()
    local oldWorld = WorldDeltas.export()
    local count, ids = gfx.sprite.spriteCount(), WorldTiles:maxID()
    local ox, oy = gfx.getDrawOffset()
    local screen, sprites, sets = gfx.getWorkingImage():copy(), {}, {}
    for _, sprite in ipairs(gfx.sprite.getAllSprites()) do
        sprites[sprite] = {visible = sprite:isVisible(), enabled = sprite:updatesEnabled()}
        sprite:setVisible(false)
        sprite:setUpdatesEnabled(false)
    end
    for key, value in pairs(SpriteFactory.npc) do
        sets[key] = value
    end
    local g = GameContext({sessionLocationPolicy = PewterWorld.locationPolicy()})
    local registry = TileRegistry()
    local provider = PewterWorld.createProvider(g, registry)
    zoneRegistry, zoneList = {}, {}
    local oldProvider = WorldDeltas.definitionProvider()
    for _, key in ipairs(oldList) do
        local zone = oldRegistry[key]
        if not oldProvider or not oldProvider:owns(zone) then
            zoneRegistry[key] = zone
            zoneList[#zoneList + 1] = key
        end
    end
    local ok, problem = pcall(function()
        WorldDeltas._withDefinitionProvider(provider, function()
            WorldView.withIsolation(function()
                assert(g:recruit(Pokemon("squirtle", 5)))
                assert(g:recruit(Pokemon("pidgey", 5)))
                assert(g.session:setIntro({stage="done", starter="squirtle", rivalStarter="bulbasaur"}))
                currentZone = provider:ensure(SourceMaps.entry(name).key)
                Story.bind(g)
                g.machine:register("overworld", OverworldState(g))
                g.machine:register("dialog", DialogState(g))
                g.machine:register("pause", PauseState(g))
                g.machine:register("tutorial-escort", TutorialEscortState(g))
                g.machine:change("overworld", {entry=entry})
                assert(g.session:activateRNG())
                local owner = g.machine:get("overworld")
                assert(owner:isTop(), "Day Care fixture must own the root world")
                eq(owner.sub:getCurrent(), "explore", "Day Care fixture substate")
                assert(g.player:updatesEnabled(), "Day Care fixture Player callbacks must be enabled")
                fn(g, owner, provider)
            end)
        end)
    end)
    if g then
        while #g.machine.stack > 0 do
            local state = table.remove(g.machine.stack)
            pcall(state.exit, state)
        end
        g.npcManager:clear()
        if g.player then
            g.player:remove()
            g.player.grassOverlay:remove()
            g.player.exitArrow:remove()
            if g.player.jumpShadow then
                g.player.jumpShadow:remove()
            end
        end
    end
    provider:disposeCache()
    zoneRegistry, zoneList, currentZone = oldRegistry, oldList, oldZone
    Story.bind(oldStory)
    WorldDeltas.apply(oldWorld)
    local owner = GameSession.activeRNGSession()
    if owner ~= oldOwner then
        if owner then
            owner:deactivateRNG()
        end
        if oldOwner then
            oldOwner:activateRNG()
        end
    end
    RulesRNG.restoreData(oldRNG)
    for _, sprite in ipairs(gfx.sprite.getAllSprites()) do
        if not sprites[sprite] then
            sprite:remove()
        end
    end
    local present = {}
    for _, sprite in ipairs(gfx.sprite.getAllSprites()) do
        present[sprite] = true
    end
    for sprite, state in pairs(sprites) do
        if not present[sprite] then
            sprite:add()
        end
        sprite:setVisible(state.visible)
        sprite:setUpdatesEnabled(state.enabled)
    end
    for key in pairs(SpriteFactory.npc) do
        if not sets[key] then
            SpriteFactory.npc[key] = nil
        end
    end
    for key, value in pairs(sets) do
        SpriteFactory.npc[key] = value
    end
    gfx.setDrawOffset(0, 0)
    screen:draw(0, 0)
    gfx.setDrawOffset(ox, oy)
    eq(gfx.sprite.spriteCount(), count)
    eq(WorldTiles:maxID(), ids)
    if not ok then
        error(problem, 0)
    end
end

local function frames(g, count)
    for _ = 1, count do
        g.machine:update()
    end
end
local function ordinaryStep(g, dx, dy, earned)
    local player = g.player
    eq(g.machine:getCurrent(), "overworld", "ordinary step root")
    eq(g.machine:get("overworld").sub:getCurrent(), "explore", "ordinary step substate")
    assert(player:updatesEnabled(), "ordinary Player callbacks must be enabled")
    eq(player.isMoving, false, "ordinary step starts settled")
    eq(Daycare.observe(g.session).earned, earned, "ordinary step initial XP")
    player:tryMove(dx, dy)
    assert(player.isMoving, "ordinary step must start through real collision checks")
    for tick = 1, 8 do
        frames(g, 1)
        eq(g.player, player, "ordinary step retains Player")
        eq(g.machine:getCurrent(), "overworld", "ordinary step retains root at tick " .. tick)
        eq(player.moveFrames, tick, "ordinary Player callback tick")
        eq(player.isMoving, tick < 8, "ordinary eight-frame movement")
        eq(Daycare.observe(g.session).earned, earned + (tick == 8 and 1 or 0), "completed-step XP at tick " .. tick)
    end
end
function DaycareContracts.run()
    local report = {ok=true, passed=0, failed=0, tests={}}
    local function test(name, fn)
        local ok, reason = pcall(fn)
        report.tests[#report.tests + 1] = {name=name, ok=ok, error=not ok and tostring(reason) or nil}
        if ok then
            report.passed = report.passed + 1
        else
            report.ok = false
            report.failed = report.failed + 1
        end
    end
    test("detached plans and cancelled requests preserve identity, party, cash and both RNG streams", function()
        local g, s, chosen = fresh()
        local before, rng, world = wire(s), s:rngData(), s:worldRngData()
        local request, plan = Daycare.prepare(s, "deposit", 2)
        plan.pokemon.name = "FORGED"
        plan.index = 1
        local observation = Daycare.observe(s)
        observation.party.members[2].name = "OTHER"
        assert(s:resolveDaycare(request, false))
        eq(s:resolveDaycare(request, true), false)
        eq(s:party():get(2), chosen)
        same(before, wire(s))
        same(rng, s:rngData())
        same(world, s:worldRngData())
    end)
    test("deposit keeps exact selected member and preserves the other active member", function()
        local g, s, chosen = fresh()
        local lead = s:party():get(1)
        local bag, party = s:inventory(), s:party()
        deposit(s)
        eq(s:party(), party)
        eq(s:inventory(), bag)
        eq(s:party():active(), lead)
        eq(GameSession._state(s).daycare.mon, chosen)
        eq(Party._owner(chosen), s)
        eq(Daycare.plan(Daycare.observe(s), "deposit", 1).status, "occupied")
    end)
    test("zero-growth fee, money guard and duplicate resolve", function()
        local g, s, mon = fresh()
        deposit(s)
        local balance = s:inventory():money()
        local request, plan = Daycare.prepare(s, "withdraw")
        eq(plan.fee, 100)
        assert(s:resolveDaycare(request, true))
        eq(s:party():get(2), mon)
        eq(s:inventory():money(), balance - 100)
        eq(s:resolveDaycare(request, true), false)
        eq(Party._owner(mon), s:party())
        eq(wire(s).daycare.pokemon, nil)
    end)
    test("one XP per step, deferred B2W2 stats and FIFO learning, no evolution or battle choices", function()
        local g, s, mon = fresh()
        mon.hp = 1
        mon.status = "poison"
        mon.pp.growl = 2
        local attributes, rng, world = mon:attributes(), s:rngData(), s:worldRngData()
        local needed = mon:xpForLevel(16) - mon.xp
        deposit(s)
        steps(s, needed - 1)
        eq(Daycare.plan(Daycare.observe(s), "withdraw").grown, 0)
        s:daycareStep()
        eq(mon.level, 15)
        local request, plan = Daycare.prepare(s, "withdraw")
        eq(plan.grown, 1)
        eq(plan.fee, 200)
        assert(s:resolveDaycare(request, true))
        eq(s:party():get(2), mon)
        eq(mon.level, 16)
        eq(mon.species, "charmander")
        eq(mon.pendingEvolution, nil)
        eq(#mon.pendingMoveChoices, 0)
        same(mon.moves, {"growl", "ember", "smokescreen", "dragonRage"})
        eq(mon.pp.growl, 2)
        eq(mon.pp.scratch, nil)
        eq(mon.pp.dragonRage, moveData.dragonRage.maxPP)
        eq(mon.hp, mon.maxHP)
        eq(mon.maxHP, mon:calculatedStats().maxHP)
        eq(mon.status, "poison")
        same(attributes, mon:attributes())
        same(rng, s:rngData())
        same(world, s:worldRngData())
    end)
    test("full party and insufficient funds retries never consume held mon or payment", function()
        local g, s, mon = fresh()
        deposit(s)
        while s:party():count() < Party.CAPACITY do
            assert(s:recruit(Pokemon("pidgey", 5)))
        end
        local before = wire(s)
        local request, plan = Daycare.prepare(s, "withdraw")
        eq(plan.status, "party-full")
        eq(s:resolveDaycare(request, true), false)
        same(before, wire(s))
        assert(s:storage():deposit(s:party(), 6))
        assert(s:inventory():spend(s:inventory():money()))
        before = wire(s)
        request, plan = Daycare.prepare(s, "withdraw")
        eq(plan.status, "insufficient-money")
        eq(s:resolveDaycare(request, true), false)
        same(before, wire(s))
        assert(s:inventory():credit(100))
        request = Daycare.prepare(s, "withdraw")
        assert(s:resolveDaycare(request, true))
        eq(s:party():get(6), mon)
        eq(s:inventory():money(), 0)
    end)
    test("stale money, step quote, reorder and same-record different identity reject atomically", function()
        local g, s = fresh()
        local request = Daycare.prepare(s, "deposit", 2)
        assert(s:party():swap(1, 2))
        eq(s:resolveDaycare(request, true), false)
        deposit(s, 1)
        request = Daycare.prepare(s, "withdraw")
        s:invalidateFieldWorldContext()
        local before = wire(s)
        eq(s:resolveDaycare(request, true), false)
        same(before, wire(s))
        request = Daycare.prepare(s, "withdraw")
        local beforeMoney = s:inventory():money()
        s:daycareStep()
        eq(s:resolveDaycare(request, true), false)
        eq(s:inventory():money(), beforeMoney)
        request = Daycare.prepare(s, "withdraw")
        assert(s:inventory():credit(1))
        eq(s:resolveDaycare(request, true), false)
        local _, other = fresh("pidgey", 5)
        local first = Pokemon("pidgey", 5)
        assert(other:recruit(first))
        request = Daycare.prepare(other, "deposit", 2)
        assert(other:party():swap(2, 3))
        eq(other:resolveDaycare(request, true), false)
    end)
    -- Keep unsupported HM registrations visible as contextual native failures.
    -- Never forge a codec-invalid moveset to reach the service guard.
    for _, fixture in ipairs({
        {move="cut", item="hm01", species="bulbasaur"},
        {move="fly", item="hm02", species="pidgey"},
        {move="surf", item="hm03", species="squirtle"},
        {move="strength", item="hm04", species="charmander"},
        {move="flash", item="hm05", species="pikachu"},
    }) do
        test("Blue HM rejection after compatible teaching: " .. fixture.move, function()
            local g, s, mon = fresh(fixture.species, 5)
            assert(MachineData.compatibility[mon.species][fixture.item], "HM fixture species must be compatible")
            assert(moveData[fixture.move], "root HM move registration required: " .. fixture.move)
            assert(s:inventory():add(fixture.item, 1))
            local request, reason = Teaching.prepare(s, mon, fixture.item)
            assert(request, "compatible HM teaching failed: " .. tostring(reason))
            assert(Teaching.complete(request, "learn"))
            assert(mon:hasMove(fixture.move), "HM must be acquired by real teaching")
            assert(PokemonCodec.encode(mon), "taught HM fixture must be codec-valid")
            local before, rng, world = wire(s), s:rngData(), s:worldRngData()
            local rejected, plan = Daycare.prepare(s, "deposit", 2)
            eq(plan.status, "hm-move", fixture.move .. " deposit guard")
            eq(s:resolveDaycare(rejected, true), false, "HM deposit rejects atomically")
            same(before, wire(s))
            same(rng, s:rngData())
            same(world, s:worldRngData())
            eq(s:party():get(2), mon, "HM rejection preserves identity")
            eq(s:inventory():quantity(fixture.item), 1, "HM remains reusable")
        end)
    end
    test("last member and last usable are rejected without changing party or payment", function()
        local g, s = fresh()
        s:party():get(1).hp = 0
        local before = wire(s)
        local request, plan = Daycare.prepare(s, "deposit", 2)
        eq(plan.status, "last-usable")
        eq(s:resolveDaycare(request, true), false)
        same(before, wire(s))
        s:party():get(1).hp = 1
        deposit(s)
        eq(Daycare.plan(Daycare.observe(s), "deposit", 1).status, "occupied")
        request = Daycare.prepare(s, "withdraw")
        assert(s:resolveDaycare(request, true))
        assert(s:storage():deposit(s:party(), 2))
        before = wire(s)
        request, plan = Daycare.prepare(s, "deposit", 1)
        eq(plan.status, "last-member")
        eq(s:resolveDaycare(request, true), false)
        same(before, wire(s))
    end)
    test("actual SDK JSON/codec held-mon roundtrip and old-save empty migration", function()
        local g, s = fresh()
        local old = SessionFixture.forVersion(wire(s), 1)
        old.daycare = nil
        old.fieldWorld = nil
        local migrated = assert(SessionCodec.decode(old, g:getSessionDependencies()))
        eq(Daycare.observe(migrated).pokemon, nil)
        deposit(s)
        steps(s, 400)
        local restored = roundtrip(g)
        same(wire(s), wire(restored))
        eq(Party._owner(GameSession._state(restored).daycare.mon), restored)
        local request = Daycare.prepare(restored, "withdraw")
        assert(restored:resolveDaycare(request, true))
        eq(restored:party():count(), 2)
        local malformed = wire(s)
        malformed.daycare.earned = "1250001"
        eq(SessionCodec.validate(malformed, g:getSessionDependencies()), false)
        malformed = wire(s)
        malformed.daycare.extra = true
        eq(SessionCodec.validate(malformed, g:getSessionDependencies()), false)
    end)
    test("schema3 preserves fieldWorld and strictly migrates v1/v2 without invented Day Care state", function()
        local g, s = fresh()
        for _, offset in ipairs({0, 6}) do
            GameSession._state(s).fieldWorld = {version=1, mapPalOffset=offset}
            local current = wire(s)
            eq(current.version, SessionCodec.VERSION)
            eq(current.fieldWorld.mapPalOffset, offset)
            local legacy = SessionFixture.forVersion(current, 2)
            legacy.daycare = nil
            local restored = assert(SessionCodec.decode(legacy, g:getSessionDependencies()))
            eq(wire(restored).fieldWorld.mapPalOffset, offset)
            eq(wire(restored).daycare.pokemon, nil)
            eq(wire(restored).version, SessionCodec.VERSION)
            local malformed = GameSession._copy(current)
            malformed.daycare = nil
            eq(SessionCodec.validate(malformed, g:getSessionDependencies()), false)
            malformed = GameSession._copy(legacy)
            malformed.daycare = current.daycare
            eq(SessionCodec.validate(malformed, g:getSessionDependencies()), false)
            malformed = GameSession._copy(legacy)
            malformed.fieldWorld = nil
            eq(SessionCodec.validate(malformed, g:getSessionDependencies()), false)
        end
    end)
    test("pending progression is guarded and encoding rejects duplicate owner identity", function()
        local g, s, mon = fresh()
        mon:gainXP(mon:xpForLevel(16) - mon.xp)
        eq(Daycare.plan(Daycare.observe(s), "deposit", 2).status, "pending-progression")
        mon.pendingEvolution = nil
        mon.pendingMoveChoices = {}
        deposit(s)
        local held = GameSession._state(s).daycare
        held.mon = s:party():get(1)
        eq(SessionCodec.encode(s, GATE), nil)
        held.mon = mon
        assert(SessionCodec.encode(s, GATE))
    end)
    test("level99/100 cap and original two-byte BCD fee saturation", function()
        local g, s, mon = fresh("pidgey", 99)
        deposit(s)
        local held = GameSession._state(s).daycare
        steps(s, mon:xpForLevel(100) - mon.xp - 1)
        s:daycareStep()
        s:daycareStep()
        eq(held.earned, mon:xpForLevel(100) - mon.xp)
        local request, plan = Daycare.prepare(s, "withdraw")
        eq(plan.level, 100)
        eq(plan.fee, 200)
        assert(s:resolveDaycare(request, true))
        local _, other, low = fresh("pidgey", 1)
        deposit(other)
        steps(other, low:xpForLevel(100) - low.xp)
        local _, quote = Daycare.prepare(other, "withdraw")
        eq(quote.fee, 9999)
    end)
    test("level 100 stops XP growth and preserves base fee", function()
        local g, s = fresh("pidgey", 100)
        deposit(s)
        steps(s, 5)
        eq(Daycare.observe(s).earned, 0)
        local request, plan = Daycare.prepare(s, "withdraw")
        eq(plan.grown, 0)
        eq(plan.fee, 100)
        assert(s:resolveDaycare(request, true))
    end)
    test("real connection handoff counts once without granting repeated arrival XP", function()
        worldScene("Route6", {x=9, y=35, facing="down"}, function(g, owner)
            deposit(g.session)
            local player = g.player
            player:tryMove(0, 1)
            assert(player.pendingEdgeDoor and player.pendingEdgeDoor.connection, "source Route 6 connection required")
            eq(player.isMoving, false, "connection has no ordinary interpolation")
            frames(g, 24)
            eq(currentZone.stableID, "pokered:VERMILION_CITY", "connection destination")
            eq(owner.sub:getCurrent(), "explore", "connection settles in Explore")
            eq(Daycare.observe(g.session).earned, 1, "completed connection counts once")
            frames(g, 12)
            eq(Daycare.observe(g.session).earned, 1, "connection arrival and idle add no XP")
        end)
    end)
    test("source escort uses actual Player updates without earning Day Care XP", function()
        worldScene("PewterCity", {x=34, y=16, facing="down"}, function(g)
            deposit(g.session)
            assert(TutorialEscort.dispatch(g, "pokered:PEWTER_CITY:objects:5"))
            drain(g)
            local scene = g.machine:get("tutorial-escort")
            eq(scene.phase, "escort-walk", "real source escort owns script movement")
            eq(g.player:updatesEnabled(), false, "script advances Player explicitly beneath overlay")
            local originX, originY = g.player.gridX, g.player.gridY
            for _ = 1, 128 do
                frames(g, 1)
                assert(scene.phase ~= "failed", "source escort failed: " .. tostring(scene.waiting))
                eq(Daycare.observe(g.session).earned, 0, "scripted Player/NPC updates grant no XP")
                if scene.playerIndex > 1 then break end
            end
            assert(scene.playerIndex > 1, "real source escort must complete a Player cell")
            assert(g.player.gridX ~= originX or g.player.gridY ~= originY, "script must actually move Player")
            scene:cancel()
            frames(g, 1)
            eq(g.machine:getCurrent(), "overworld", "script cancellation resumes world")
            eq(Daycare.observe(g.session).earned, 0, "script return adds no XP")
        end)
    end)
    -- Real controller witnesses use the shared source map fixture, not a fake
    -- machine. Root must activate Daycare's prepared manifest entry first.
    test("source event YES, selected second member, cancelled withdrawal and retry", function()
        KantoServicesContracts.withScene("Daycare", {x=2, y=5}, function(g)
            g.machine:register("event", DaycareState(g))
            g.machine:register("party", PartyState(g))
            assert(g.session:inventory():credit(1000))
            local s = g.session
            local selected = Pokemon("pidgey", 5)
            assert(s:recruit(selected))
            assert(SourceEvents.dispatch(g, ID))
            drain(g)
            local event = g.machine:get("event")
            eq(event.phase, "service-choice")
            event:handleButton("a")
            drain(g)
            eq(g.machine:getCurrent(), "party")
            g.machine:get("party"):close(2)
            drain(g)
            eq(g.machine:getCurrent(), "overworld")
            eq(GameSession._state(s).daycare.mon, selected)
            local before = wire(s)
            assert(SourceEvents.dispatch(g, ID))
            drain(g)
            event:handleButton("b")
            drain(g)
            same(before, wire(s))
            assert(SourceEvents.dispatch(g, ID))
            drain(g)
            event:handleButton("a")
            drain(g)
            eq(s:party():get(2), selected)
        end)
    end)
    return report
end
