-- Native SDK witnesses. Requires the root-installed source content and services.
-- No host Lua, translated code, fake SDK, or Simulator launch from this module.
import "dev/sessionFixture"
KantoServicesContracts = {}
local MUSEUM <const> = "pokered:MUSEUM_1F:objects:1"
local SALESMAN <const> = "pokered:MT_MOON_POKECENTER:objects:4"
local BIKE <const> = "pokered:BIKE_SHOP:objects:1"
local function eq(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then eq(a, b); return end
    for key, value in pairs(a) do same(value, b[key]) end
    for key in pairs(b) do assert(a[key] ~= nil, "extra field " .. tostring(key)) end
end
local function drain(g)
    for _ = 1, 256 do
        if g.machine:getCurrent() ~= "dialog" then return end
        local state = g.machine:get("dialog")
        state.dialog:advance()
        state:handleInput()
    end
    error("service dialogue did not settle")
end
local function settle(g)
    for _ = 1, 512 do
        if g.machine:getCurrent() == "overworld" then return end
        if g.machine:getCurrent() == "dialog" then drain(g) else g.machine:update() end
        local event = g.machine:get("event")
        assert(event.phase ~= "failed", event.waiting)
    end
    error("service did not settle")
end
local function restore(g)
    local wire = assert(SessionCodec.encode(g.session, {root="overworld", overworld="explore", settled=true}))
    local decoded = assert(SessionCodec.decode(wire, g:getSessionDependencies()))
    assert(g.session:deactivateRNG())
    g.session = decoded
    assert(decoded:activateRNG())
    return decoded
end
local function offer(g, id)
    SourceEvents.dispatch(g, id)
    drain(g)
    eq(g.machine:get("event").phase, "service-choice")
end
local function fullBag(session)
    local discard
    for id, definition in pairs(ItemData.definitions) do
        if not definition.keyItem and session:inventory():count() < Inventory.CAPACITY then
            assert(session:inventory():add(id, 1))
            discard = id
        end
    end
    eq(session:inventory():count(), Inventory.CAPACITY)
    return discard
end
local function fullParty(g)
    while g.session:party():count() < Party.CAPACITY do assert(g:recruit(Pokemon("pidgey", 5))) end
end

-- The fixture uses actual imported geometry, sprite factories, NPCMotion,
-- DialogState and the composed production event executor. Missing integration
-- fails explicitly; injected withScene must supply the same native surface.
function KantoServicesContracts.withScene(name, options, fn)
    local oldZone = currentZone
    local oldOwner = GameSession.activeRNGSession()
    local oldRNG = RulesRNG.snapshot()
    local restoreTiles = WorldTiles:checkpointRuntime()
    local g, zone
    local ok, problem = pcall(function()
        local entry = SourceMaps.entry(name)
        assert(entry.profile == "source", "imported service map fixture required")
        g = GameContext({sessionLocationPolicy=PewterWorld.locationPolicy()})
        assert(g.session:inventory():spend(g.session:inventory():money()))
        assert(g:recruit(Pokemon("squirtle", 5)))
        assert(g.session:setIntro({stage="done", starter="squirtle", rivalStarter="bulbasaur"}))
        for id, value in pairs(options.quest or {}) do assert(g.session:setQuestFlag(id, value)) end
        g.trainers = TrainerEvents(g)
        local profiles = SourceMaps.legacyProfiles({dispatch=function(id) return SourceEvents.dispatch(g, id) end,
            questFlag=function(id) return g.session:questFlag(id) end,
            sourceFlag=function(id) return g.trainers:sourceFlag(id) end})
        zone = SourceMaps.createZone(name, profiles.source, WorldTiles)
        currentZone = zone
        g.player = Player(options.x + entry.padding, options.y, zone.collision, g.npcManager)
        g.player.facing = options.facing or "up"
        g.player:setImage(SpriteFactory.playerStand[g.player.facing])
        local sub = StateMachine()
        sub:register("explore", {})
        sub:change("explore")
        g.machine:register("overworld", {sub=sub})
        g.machine:register("event", KantoServicesState(g))
        g.machine:register("dialog", DialogState(g))
        g.machine:change("overworld")
        zone:spawnNPCs(g.npcManager)
        g.npcManager.motion:attach(g, zone)
        eq(zone.collision[g.player.gridY + 1][g.player.gridX + 1], 0)
        eq(g.npcManager:getNPCAt(g.player.gridX, g.player.gridY), nil)
        assert(g.session:activateRNG())
        fn(g)
    end)
    if g then
        while g.machine:depth() > 0 do g.machine:pop() end
        g.npcManager:clear()
        if g.player then
            g.player:remove()
            g.player.grassOverlay:remove()
            g.player.exitArrow:remove()
        end
    end
    if zone then zone:disposeView() end
    restoreTiles()
    local active = GameSession.activeRNGSession()
    if active then active:deactivateRNG() end
    if oldOwner then oldOwner:activateRNG() end
    RulesRNG.restore(oldRNG)
    currentZone = oldZone
    assert(ok, problem)
end

function KantoServicesContracts.run(withScene)
    withScene = withScene or KantoServicesContracts.withScene
    local report = {ok=true, passed=0, failed=0, tests={}}
    local function test(name, fn)
        local ok, problem = pcall(fn)
        report.tests[#report.tests + 1] = {name=name, ok=ok, error=not ok and tostring(problem) or nil}
        if ok then report.passed = report.passed + 1
        else report.failed = report.failed + 1; report.ok = false end
    end
    local function center(fn)
        withScene("MtMoonPokecenter", {x=10, y=5, facing="down"}, fn)
    end
    for _, home in ipairs({
        {map="Museum1F", id="pokered:MUSEUM_1F:objects:5", x=16, y=2, player={x=9,y=4}},
        {map="MtMoonPokecenter", id="pokered:MT_MOON_POKECENTER:objects:5", x=7, y=2, player={x=10,y=5}},
    }) do
        test(home.id .. " retains its pinned blocked STAY home without opening terrain", function()
            withScene(home.map, home.player, function(g)
                local world = WorldDeltas.export()
                local descriptor = SourceActors.describe(currentZone.stableID, world)
                local spec
                for _, actor in ipairs(descriptor.actors) do
                    if actor.id == home.id then spec = actor end
                end
                assert(spec and spec.blocked_home)
                eq(spec.x,home.x); eq(spec.y,home.y)
                eq(currentZone.collision[home.y+1][home.x+1],1)
                eq(descriptor.canStand(spec,home.x,home.y,currentZone),true)
                eq(descriptor.canStand(spec,home.x+1,home.y,currentZone),false)
                eq(descriptor.canStep(spec,home.x-1,home.y,home.x,home.y,currentZone),false)
                eq(descriptor.canWanderStep(spec,home.x,home.y,home.x+1,home.y,currentZone),false)
                eq(descriptor.canStand(spec,-1,home.y,currentZone),false)
                -- Newly blocking ordinary floor cannot create a home exception.
                local ordinary = descriptor.actors[1]
                assert(not ordinary.blocked_home)
                local changed = {collision=Party._primitive(currentZone.collision)}
                changed.collision[ordinary.y+1][ordinary.x+1] = 1
                eq(descriptor.canStand(ordinary,ordinary.x,ordinary.y,changed),false)
                local snapshot = g.npcManager.motion:snapshot()
                local rng, worldRng = RulesRNG.toData(), g.session:worldRngData()
                assert(g.session:captureTraversal({world=world,actors=snapshot,
                    location={zone_id=currentZone.stableID,x=g.player.gridX,y=g.player.gridY,facing=g.player.facing}}))
                local decoded = restore(g)
                same(decoded:actorData(),snapshot)
                g.npcManager.motion:attach(g,currentZone,decoded:actorData())
                same(g.npcManager.motion:snapshot(),snapshot)
                same(RulesRNG.toData(),rng); same(decoded:worldRngData(),worldRng)
                same(WorldDeltas.export(),world)
                eq(currentZone.collision[home.y+1][home.x+1],1)
            end)
        end)
    end
    for _, x in ipairs({9, 10}) do
        test("museum source trigger " .. x .. " charges 50 once, survives codec, resets only in Pewter", function()
            withScene("Museum1F", {x=x, y=4}, function(g)
                assert(g.session:inventory():credit(150))
                local rng = RulesRNG.snapshot()
                assert(KantoServices.check(g))
                drain(g)
                g.machine:get("event"):handleButton("a")
                eq(g.session:inventory():money(), 100)
                settle(g)
                eq(KantoServices.check(g), false)
                SourceEvents.dispatch(g, MUSEUM)
                eq(g.machine:get("event").waiting, "_Museum1FScientist1TakePlentyOfTimeText")
                settle(g)
                eq(g.session:inventory():money(), 100)
                restore(g)
                assert(KantoServices.onMapEnter(g.session, "pokered:MUSEUM_1F"))
                assert(KantoServices.onMapEnter(g.session, "pokered:MUSEUM_2F"))
                eq(g.session:questFlag("EVENT_BOUGHT_MUSEUM_TICKET"), true)
                eq(KantoServices.check(g), false)
                assert(KantoServices.onMapEnter(g.session, "pokered:PEWTER_CITY"))
                eq(g.session:questFlag("EVENT_BOUGHT_MUSEUM_TICKET"), false)
                assert(KantoServices.check(g))
                drain(g)
                g.machine:get("event"):handleButton("a")
                settle(g)
                eq(g.session:inventory():money(), 50)
                same(RulesRNG.snapshot(), rng)
            end)
        end)
    end
    for _, decision in ipairs({"decline", "no-money"}) do
        test("museum " .. decision .. " backs player down with no payment", function()
            withScene("Museum1F", {x=9, y=4}, function(g)
                assert(g.session:inventory():credit(49))
                local rng = RulesRNG.snapshot()
                assert(KantoServices.check(g))
                drain(g)
                g.machine:get("event"):handleButton(decision == "decline" and "b" or "a")
                settle(g)
                eq(g.player.gridY, 5)
                eq(g.session:inventory():money(), 49)
                eq(g.session:questFlag("EVENT_BOUGHT_MUSEUM_TICKET"), false)
                same(RulesRNG.snapshot(), rng)
            end)
        end)
    end
    for _, point in ipairs({{x=13,y=4}, {x=12,y=3}}) do
        for _, yes in ipairs({true, false}) do
            test("museum behind-counter branch " .. point.x .. "," .. point.y .. " " .. tostring(yes), function()
                withScene("Museum1F", point, function(g)
                    offer(g, MUSEUM)
                    eq(KantoServices.check(g), false)
                    g.machine:get("event"):handleButton(yes and "a" or "b")
                    eq(g.machine:get("event").waiting, "_Museum1FScientist1" ..
                        (yes and "TheresALabSomewhereText" or "AmberIsFossilizedTreeSapText"))
                    settle(g)
                    eq(g.session:questFlag("EVENT_BOUGHT_MUSEUM_TICKET"), false)
                end)
            end)
        end
    end
    test("museum outside ticket row asks other side and cannot unlock amber access", function()
        withScene("Museum1F", {x=10,y=5}, function(g)
            SourceEvents.dispatch(g, MUSEUM)
            eq(g.machine:get("event").waiting, "_Museum1FScientist1GoToOtherSideText")
            settle(g)
            eq(g.session:questFlag("EVENT_GOT_OLD_AMBER"), false)
            eq(g.session:questFlag("EVENT_BOUGHT_MUSEUM_TICKET"), false)
        end)
    end)
    test("Magikarp purchase uses ordinary gift traits, nine draws, dex, codec and exact-once price", function()
        center(function(g)
            assert(g.session:inventory():credit(1000))
            local stream = RulesRNG.new(1)
            stream:restore(RulesRNG.snapshot())
            local expected = assert(Specimen.create("magikarp", 5, "gift", stream))
            offer(g, SALESMAN)
            g.machine:get("event"):handleButton("a")
            eq(g.session:inventory():money(), 500)
            eq(g.session:party():count(), 2)
            local actual = g.session:party():get(2)
            same(PokemonCodec.encode(actual), PokemonCodec.encode(expected))
            same(RulesRNG.snapshot(), stream:snapshot())
            eq(actual.sexProvenance.origin, "gift")
            eq(g.session:pokedex().owned.magikarp, true)
            settle(g)
            local rng = RulesRNG.snapshot()
            restore(g)
            SourceEvents.dispatch(g, SALESMAN)
            eq(g.machine:get("event").waiting, "_MtMoonPokecenterMagikarpSalesmanNoRefundsText")
            settle(g)
            eq(g.session:inventory():money(), 500)
            eq(g.session:party():count(), 2)
            same(PokemonCodec.encode(g.session:party():get(2)), PokemonCodec.encode(expected))
            same(RulesRNG.snapshot(), rng)
        end)
    end)
    for _, decision in ipairs({"decline", "no-money"}) do
        test("Magikarp " .. decision .. " leaves cash, party, dex, flag and RNG unchanged", function()
            center(function(g)
                assert(g.session:inventory():credit(499))
                local rng = RulesRNG.snapshot()
                offer(g, SALESMAN)
                g.machine:get("event"):handleButton(decision == "decline" and "b" or "a")
                eq(g.machine:get("event").waiting, "_MtMoonPokecenterMagikarpSalesman" ..
                    (decision == "decline" and "NoText" or "NoMoneyText"))
                settle(g)
                eq(g.session:inventory():money(), 499)
                eq(g.session:party():count(), 1)
                eq(g.session:pokedex().owned.magikarp, nil)
                eq(g.session:questFlag("EVENT_BOUGHT_MAGIKARP"), false)
                same(RulesRNG.snapshot(), rng)
            end)
        end)
    end
    test("full party sends paid gift to selected box exactly as source GivePokemon", function()
        center(function(g)
            fullParty(g)
            assert(g.session:storage():selectBox(3))
            assert(g.session:inventory():credit(500))
            offer(g, SALESMAN)
            g.machine:get("event"):handleButton("a")
            eq(g.machine:get("event").waiting, "_SentToBoxText")
            settle(g)
            eq(g.session:party():count(), 6)
            eq(g.session:storage():count(3), 1)
            eq(g.session:storage():get(1, 3).species, "magikarp")
            eq(g.session:inventory():money(), 0)
            restore(g)
            eq(g.session:storage():get(1, 3).species, "magikarp")
        end)
    end)
    test("full party and selected box reject before RNG; retry produces original specimen", function()
        center(function(g)
            fullParty(g)
            for _ = 1, Storage.BOX_CAPACITY do assert(g:recruit(Pokemon("pidgey", 5))) end
            assert(g.session:inventory():credit(500))
            local rng = RulesRNG.snapshot()
            offer(g, SALESMAN)
            g.machine:get("event"):handleButton("a")
            eq(g.machine:get("event").waiting, "_BoxIsFullText")
            settle(g)
            eq(g.session:inventory():money(), 500)
            eq(g.session:questFlag("EVENT_BOUGHT_MAGIKARP"), false)
            same(RulesRNG.snapshot(), rng)
            restore(g)
            assert(g.session:storage():move(1, 2))
            local stream = RulesRNG.new(1)
            stream:restore(rng)
            local expected = assert(Specimen.create("magikarp", 5, "gift", stream))
            offer(g, SALESMAN)
            g.machine:get("event"):handleButton("a")
            settle(g)
            same(PokemonCodec.encode(g.session:storage():get(20)), PokemonCodec.encode(expected))
            same(RulesRNG.snapshot(), stream:snapshot())
        end)
    end)
    test("gift preparation rejects stale money, invalid level, and flag capacity without any mutation", function()
        center(function(g)
            assert(g.session:inventory():credit(500))
            local rng = RulesRNG.snapshot()
            eq(KantoServices.magikarpPurchase(g.session, 499), false)
            local invalid = KantoServices.policy().magikarp
            invalid.level = 101
            eq(g.session:purchaseGiftPokemon(invalid, 500), false)
            for i = 1, 4096 do
                assert(g.session:setQuestFlag("CAPACITY:" .. i, false))
                SessionFixture.collectPreparationGarbage(i)
            end
            eq(KantoServices.magikarpPurchase(g.session, 500), false)
            eq(g.session:inventory():money(), 500)
            eq(g.session:party():count(), 1)
            eq(g.session:questFlag("EVENT_BOUGHT_MAGIKARP"), false)
            eq(g.session:pokedex().owned.magikarp, nil)
            same(RulesRNG.snapshot(), rng)
        end)
    end)
    for _, yes in ipairs({true, false}) do
        test("no-voucher bicycle million offer " .. tostring(yes) .. " never changes cash or items", function()
            withScene("BikeShop", {x=6,y=4}, function(g)
                assert(g.session:inventory():credit(Inventory.MONEY_LIMIT))
                local rng = RulesRNG.snapshot()
                offer(g, BIKE)
                eq(g.machine:get("event").menu.options[1], "BICYCLE  ¥1000000")
                g.machine:draw()
                g.machine:get("event"):handleButton(yes and "a" or "b")
                eq(g.machine:get("event").waiting, yes and "_BikeShopCantAffordText" or "_BikeShopComeAgainText")
                settle(g)
                eq(g.session:inventory():money(), Inventory.MONEY_LIMIT)
                eq(g.session:inventory():quantity("bicycle"), 0)
                eq(g.session:questFlag("EVENT_GOT_BICYCLE"), false)
                same(RulesRNG.snapshot(), rng)
            end)
        end)
    end
    test("voucher full bag is atomic; codec, retry, receipt and revisit consume exactly one voucher", function()
        withScene("BikeShop", {x=6,y=4}, function(g)
            assert(g.session:inventory():add("bikeVoucher", 1))
            local discard = fullBag(g.session)
            local rng = RulesRNG.snapshot()
            SourceEvents.dispatch(g, BIKE)
            drain(g)
            settle(g)
            eq(g.session:inventory():quantity("bikeVoucher"), 1)
            eq(g.session:inventory():quantity("bicycle"), 0)
            eq(g.session:questFlag("EVENT_GOT_BICYCLE"), false)
            restore(g)
            assert(g.session:inventory():consume(discard, 1))
            SourceEvents.dispatch(g, BIKE)
            drain(g)
            settle(g)
            eq(g.session:inventory():quantity("bikeVoucher"), 0)
            eq(g.session:inventory():quantity("bicycle"), 1)
            eq(g.session:questFlag("EVENT_GOT_BICYCLE"), true)
            restore(g)
            SourceEvents.dispatch(g, BIKE)
            eq(g.machine:get("event").waiting, "_BikeShopClerkHowDoYouLikeYourBicycleText")
            settle(g)
            eq(g.session:inventory():quantity("bicycle"), 1)
            same(RulesRNG.snapshot(), rng)
        end)
    end)
    test("cancelled voucher prompt cannot commit via stale dialogue callback", function()
        withScene("BikeShop", {x=6,y=4}, function(g)
            assert(g.session:inventory():add("bikeVoucher", 1))
            local rng = RulesRNG.snapshot()
            SourceEvents.dispatch(g, BIKE)
            local stale = g.machine:get("dialog").onComplete
            g.machine:change("overworld")
            stale()
            eq(g.session:inventory():quantity("bikeVoucher"), 1)
            eq(g.session:inventory():quantity("bicycle"), 0)
            same(RulesRNG.snapshot(), rng)
        end)
    end)
    test("cancelled and reentered Magikarp menus reject old callbacks without rerolls", function()
        center(function(g)
            assert(g.session:inventory():credit(1000))
            local rng = RulesRNG.snapshot()
            offer(g, SALESMAN)
            local stale = g.machine:get("event").menu.onSelect
            g.machine:change("overworld")
            offer(g, SALESMAN)
            stale(1)
            eq(g.session:inventory():money(), 1000)
            same(RulesRNG.snapshot(), rng)
            local selected = g.machine:get("event").menu.onSelect
            selected(1)
            selected(1)
            settle(g)
            eq(g.session:party():count(), 2)
            eq(g.session:inventory():money(), 500)
        end)
    end)
    return report
end
