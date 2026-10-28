-- Four approved game behaviors, one real-SDK contract each. No driver contracts.
ApprovedQoLContracts = {}

local function equal(actual, expected)
    assert(actual == expected, tostring(actual) .. " ~= " .. tostring(expected))
end

local function same(a, b)
    equal(type(a), type(b))
    if type(a) ~= "table" then
        equal(a, b)
        return
    end
    for key, value in pairs(a) do
        same(value, b[key])
    end
    for key in pairs(b) do
        assert(a[key] ~= nil)
    end
end

function ApprovedQoLContracts.run()
    local report = {ok = true, passed = 0, failed = 0, tests = {}}
    local function test(name, fn)
        local crank = GameOptions.get("crankScrolling")
        local registered = GameOptions.registeredItem()
        local zone = currentZone
        local rng = RulesRNG.snapshot()
        local owner = GameSession.activeRNGSession()
        local ok, problem = pcall(fn)
        GameOptions.set("crankScrolling", crank)
        GameOptions.setRegisteredItem(registered)
        GameOptions.save()
        currentZone = zone
        local active = GameSession.activeRNGSession()
        if active ~= owner then
            if active then
                active:deactivateRNG()
            end
            if owner then
                assert(owner:activateRNG())
            end
        end
        RulesRNG.restore(rng)
        report.tests[#report.tests + 1] = {name = name, ok = ok, error = not ok and tostring(problem) or nil}
        if ok then
            report.passed = report.passed + 1
        else
            report.failed = report.failed + 1
            report.ok = false
        end
    end

    test("Optional crank detents reset on menu entry and preserve explicit selection", function()
        assert(GameOptions.set("crankScrolling", "ON"))
        local menu = BattleMenu()
        menu:show({"ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX"})
        equal(menu.crank:steps(23), 0)
        equal(menu.crank:steps(1), 1)
        equal(menu.crank:steps(-48), -2)
        equal(menu.selectedIndex, 1)
        equal(menu.crank:steps(23), 0)
        menu:show({"ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX"})
        equal(menu.crank:steps(1), 0)
        equal(menu.crank.remainder, 1)
        assert(GameOptions.set("crankScrolling", "OFF"))
        equal(menu.crank:steps(240), 0)
        equal(menu.crank.remainder, 0)
        equal(menu.selectedIndex, 1)
        local pc = PCState(GameContext())
        assert(GameOptions.set("crankScrolling", "ON"))
        equal(pc.crank:steps(23), 0)
        pc:hideMenu()
        equal(pc.crank:steps(1), 0)
    end)

    test("Registered key item reuses Bag USE and A+B consumes one field gesture", function()
        local gesture = FieldGestures()
        gesture:step(false, false, false, false)
        equal(gesture:step(true, false, false, false), nil)
        equal(gesture:step(true, true, false, false), "registered")
        for _ = 1, 20 do
            local action, running = gesture:step(true, true, true, false)
            equal(action, nil)
            equal(running, false)
        end
        gesture:step(false, false, false, false)
        local action, running = gesture:step(false, true, true, false)
        equal(action, nil)
        equal(running, true)
        equal(gesture:step(true, true, true, false), "registered")
        gesture:step(false, false, false, false)
        gesture:step(true, false, false, false)
        equal(gesture:step(false, false, false, false), "interact")
        gesture:step(false, false, false, false)
        gesture:step(false, true, false, false)
        equal(gesture:step(false, false, false, false), "pause")

        local game = GameContext()
        local sub = StateMachine()
        sub:register("explore", State("explore"))
        sub:change("explore")
        game.machine:register("overworld", {sub = sub})
        game.machine:register("bag", BagState(game))
        game.machine:register("dialog", DialogState(game))
        game.machine:register("townMap", TownMapState(game))
        game.machine:change("overworld")
        currentZone = zoneRegistry.pallet_town
        game.player = Player(5, 6, currentZone.collision, game.npcManager)
        game.player:remove()
        assert(game.session:inventory():add("townMap", 1))
        assert(GameOptions.setRegisteredItem(nil))
        game.machine:push("bag")
        local bag = game.machine:get("bag")
        assert(bag:registerItem("townMap"))
        equal(GameOptions.registeredItem(), "townMap")
        equal(playdate.datastore.read("game-options").registeredItem, "townMap")
        equal(BagState.canRegister("bicycle"), false)
        equal(bag:registerItem("bicycle"), false)
        equal(GameOptions.registeredItem(), "townMap")
        game.machine:pop()
        assert(BagState.useRegistered(game))
        game.machine:update()
        equal(game.machine:getCurrent(), "townMap")
        game.machine:pop()
        equal(game.machine:getCurrent(), "overworld")
        assert(game.session:inventory():handoffKey("townMap"))
        equal(BagState.useRegistered(game), false)
        equal(game.machine:getCurrent(), "dialog")
        local generation = game.machine._generation
        equal(BagState.useRegistered(game), false)
        equal(game.machine._generation, generation)
        game.machine:change("overworld")
    end)

    test("Manual Bag sort atomically groups keys and preserves stable stacks and money", function()
        local bag = Inventory(ItemData.definitions)
        assert(bag:credit(1234))
        assert(bag:add("potion", 99))
        assert(bag:add("pokeBall", 4))
        assert(bag:add("potion", 2))
        assert(bag:add("townMap", 1))
        assert(bag:add("antidote", 3))
        local before = bag:toData()
        assert(bag:sort())
        local slots = bag:slots()
        equal(slots[1].id, "townMap")
        equal(slots[2].id, "antidote")
        equal(slots[3].id, "pokeBall")
        equal(slots[4].id, "potion")
        equal(slots[4].quantity, 99)
        equal(slots[5].id, "potion")
        equal(slots[5].quantity, 2)
        equal(bag:money(), before.money)
        equal(bag:quantity("potion"), 101)
        equal(bag:quantity("antidote"), 3)
        equal(bag:quantity("pokeBall"), 4)
        equal(#slots, #before.slots)
        local sorted = bag:toData()
        assert(bag:sort())
        same(bag:toData(), sorted)
        slots[1].quantity = 99
        equal(bag:quantity("townMap"), 1)
    end)

    test("One reusable TM teaches two compatible members without weakening intent guards", function()
        local game = GameContext()
        local first = Pokemon("bulbasaur", 5)
        local second = Pokemon("bulbasaur", 5)
        assert(game:recruit(first))
        assert(game:recruit(second))
        local bag = game.session:inventory()
        assert(bag:add("tm21", 1))
        local request = assert(Teaching.prepare(game.session, first, "tm21"))
        local ok, receipt = Teaching.complete(request, "learn")
        assert(ok, receipt)
        equal(receipt.consumed, false)
        equal(bag:quantity("tm21"), 1)
        assert(first:hasMove("megaDrain"))
        equal(Teaching.complete(request, "learn"), false)
        request = assert(Teaching.prepare(game.session, second, "tm21"))
        assert(bag:consume("tm21", 1))
        equal(Teaching.complete(request, "learn"), false)
        assert(Teaching.cancel(request))
        assert(bag:add("tm21", 1))
        request = assert(Teaching.prepare(game.session, second, "tm21"))
        assert(Teaching.cancel(request))
        equal(second:hasMove("megaDrain"), false)
        assert(Teaching.complete(assert(Teaching.prepare(game.session, second, "tm21")), "learn"))
        assert(second:hasMove("megaDrain"))
        equal(bag:quantity("tm21"), 1)
        equal(Teaching.protectedMove("cut"), true)
        equal(Teaching.protectedMove("surf"), true)
    end)
    return report
end
