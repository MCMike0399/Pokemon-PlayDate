-- Prepared for the real SDK only. Root alone executes these production owners.
PickupContracts = {}
local function eq(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function same(a, b)
    eq(type(a), type(b))
    if type(a) ~= "table" then
        eq(a, b)
        return
    end
    for key, value in pairs(a) do same(value, b[key]) end
    for key in pairs(b) do assert(a[key] ~= nil, "extra field " .. tostring(key)) end
end
local function mon(species, level, item, slot)
    return Pokemon(species or "meowth", level or 10, {
        natureId = 0, abilitySlot = slot or "first", heldItem = item or "none",
    })
end
local function settle(battle)
    for _ = 1, 250 do
        if battle:phase() ~= "script" then return end
        assert(not battle.pendingLearning, "unexpected pending learning")
        battle.machine:get("script"):advance()
    end
    error("Pickup script did not settle")
end
local function owned(members)
    local game <const> = GameContext()
    for _, pokemon in ipairs(members or {mon()}) do assert(game:recruit(pokemon)) end
    assert(game.session:setIntro({stage = "done", starter = "squirtle", rivalStarter = "bulbasaur"}))
    assert(game.session:activateRNG())
    return game
end
local function battleFor(game, fieldType)
    local b <const> = Battle(game.session:party():active(), mon("rattata", 1),
        fieldType == 1 and "PICKUP TRAINER" or nil, {session = game.session})
    settle(b)
    assert(game.session:beginPickupBattle(b, fieldType or 0))
    return b
end
local function seedFor(gate, roll)
    for seed = 1, 100000 do
        local stream <const> = RulesRNG.new(seed)
        if stream:random(0, 9) == gate and (roll == nil or stream:random(0, 99) == roll) then return seed end
    end
    error("no real RulesRNG seed found")
end
-- Exercise real terminal phases and emitEnd guards. Eligibility cases inject
-- terminal outcomes explicitly; the XP case below uses handleFaint itself.
local function finish(game, b, kind, seed)
    local accepted, receipt
    b:on("battleEnd", function(won, outcome)
        if seed then RulesRNG.seed(seed) end
        accepted, receipt = game.session:resolvePickupBattle(b, won, outcome)
    end)
    b:runScript(function() return kind end)
    settle(b)
    if not b.endEmitted then assert(b:emitEnd()) end
    return accepted, receipt
end
local function fillBag(bag, excluded)
    local first
    local keys = {}
    for id, data in pairs(ItemData.definitions) do
        if id ~= excluded and not data.keyItem then keys[#keys + 1] = id end
    end
    table.sort(keys)
    for index = 1, Inventory.CAPACITY do
        assert(bag:add(keys[index], 1))
        first = first or keys[index]
    end
    return first
end
local function move(b, key, seed)
    b.player.moves = {key}
    b.player.pp = {[key] = moveData[key].maxPP}
    RulesRNG.seed(seed)
    b:runScript(function()
        return b:resolveTurn({side = "player", actor = b.player, key = key, move = moveData[key]})
    end)
    settle(b)
end
local function fresh(player, enemy)
    local b <const> = Battle(player, enemy)
    settle(b)
    return b
end

function PickupContracts.run()
    local report <const> = {ok = true, passed = 0, failed = 0, tests = {}}
    local initial <const> = RulesRNG.snapshot()
    local originalSession <const> = GameSession.activeRNGSession()
    local function test(name, body)
        local prior <const> = RulesRNG.snapshot()
        local priorSession <const> = GameSession.activeRNGSession()
        local sprites = playdate.graphics.sprite.getAllSprites()
        local ok, why = pcall(body)
        playdate.graphics.sprite.removeAll()
        for _, sprite in ipairs(sprites) do sprite:add() end
        local current = GameSession.activeRNGSession()
        if current then assert(current:deactivateRNG()) end
        if priorSession then assert(priorSession:activateRNG()) end
        RulesRNG.restore(prior)
        report.tests[#report.tests + 1] = {name = name, ok = ok, error = not ok and tostring(why) or nil}
        if ok then report.passed = report.passed + 1
        else
            report.failed = report.failed + 1
            report.ok = false
        end
    end
    -- Independent, approved numeric matrix, including the reverse rare-roll order.
    local rows <const> = {
        {17,18,26,3,79,78,27,25,2,25,92},
        {18,26,3,79,78,27,25,2,28,92,221},
        {26,3,79,78,27,25,2,28,50,221,23},
        {3,79,78,27,25,2,28,50,80,23,38},
        {79,78,27,25,2,28,50,80,81,38,278},
        {78,27,25,2,28,50,80,81,93,278,537},
        {27,25,2,28,50,80,81,93,23,537,40},
        {25,2,28,50,80,81,93,23,29,40,537},
        {2,28,50,80,81,93,23,29,51,537,234},
        {28,50,80,81,93,23,29,51,41,234,537},
    }
    for band = 0, 9 do
        test("Pickup all 100 rolls at both boundaries of band " .. band, function()
            for _, level in ipairs({band * 10 + 1, band * 10 + 10}) do
                for roll = 0, 99 do
                    local column
                    if roll < 30 then column = 1
                    elseif roll < 90 then column = 2 + (roll - 30) // 10
                    elseif roll < 94 then column = 8
                    elseif roll < 98 then column = 9
                    elseif roll == 99 then column = 10
                    else column = 11 end
                    local item, native, actualBand = Pickup.select(level, roll)
                    eq(native, rows[band + 1][column])
                    eq(actualBand, band)
                    assert(ItemData.definitions[item] and SpecimenData.holdable[item])
                end
            end
        end)
    end
    test("Pickup rejects invalid levels and roll bounds without RNG", function()
        local before = RulesRNG.snapshot()
        for _, pair in ipairs({{0,0},{101,0},{1,-1},{1,100},{1.5,0},{1,0.5}}) do
            eq(pcall(Pickup.select, pair[1], pair[2]), false)
        end
        same(RulesRNG.snapshot(), before)
    end)
    for _, fieldType in ipairs({0, 1}) do
        test("Pickup wild/trainer win field type " .. fieldType, function()
            local game = owned()
            local pokemon = game.session:party():get(1)
            local party, bag = game.session:party(), game.session:inventory()
            local world = game.session:worldRngData()
            local seed = seedFor(0, 99)
            local accepted, receipt = finish(game, battleFor(game, fieldType), "victory", seed)
            assert(accepted, receipt)
            eq(pokemon.heldItem, "hyperPotion")
            eq(receipt.awards[1].slot, 1)
            eq(receipt.awards[1].gen5Id, 25)
            eq(RulesRNG.snapshot().rolls, 2)
            eq(game.session:party(), party)
            eq(party:get(1), pokemon)
            eq(game.session:inventory(), bag)
            eq(bag:quantity("hyperPotion"), 0)
            same(game.session:worldRngData(), world)
        end)
    end
    for _, kind in ipairs({"run", "caught", "defeat"}) do
        test("Pickup excludes terminal " .. kind, function()
            local game = owned()
            local accepted, receipt = finish(game, battleFor(game), kind, 123)
            assert(accepted, receipt)
            eq(#receipt.eligible, 0)
            eq(game.session:party():get(1).heldItem, "none")
            eq(RulesRNG.snapshot().rolls, 0)
        end)
    end
    test("Pickup miss consumes gate only and no item-selection roll", function()
        local game = owned()
        local accepted, receipt = finish(game, battleFor(game), "victory", seedFor(9))
        assert(accepted, receipt)
        eq(#receipt.eligible, 1)
        eq(#receipt.awards, 0)
        eq(RulesRNG.snapshot().rolls, 1)
        eq(game.session:party():get(1).heldItem, "none")
    end)
    test("Pickup physical party order includes fainted unused members; held and boxed excluded", function()
        local lead, fainted, unused = mon("squirtle"), mon(), mon()
        local held, boxed = mon(nil, nil, "potion"), mon()
        fainted.hp = 0
        local game = owned({lead, fainted, unused, held, boxed})
        assert(game.session:storage():deposit(game.session:party(), 5))
        local seed = seedFor(0)
        local stream = RulesRNG.new(seed)
        local expected = {}
        for _, pokemon in ipairs({fainted, unused}) do
            if stream:random(0, 9) == 0 then expected[pokemon] = Pickup.select(pokemon.level, stream:random(0,99)) end
        end
        local ok, receipt = finish(game, battleFor(game), "victory", seed)
        assert(ok, receipt)
        eq(receipt.eligible[1].slot, 2)
        eq(receipt.eligible[2].slot, 3)
        eq(#receipt.eligible, 2)
        eq(fainted.heldItem, expected[fainted] or "none")
        eq(unused.heldItem, expected[unused] or "none")
        eq(held.heldItem, "potion")
        eq(boxed.heldItem, "none")
        same(RulesRNG.snapshot(), stream:snapshot())
    end)
    test("Pickup full bag award, atomic Take retry and Give preserve identities", function()
        local game = owned()
        local session = game.session
        local pokemon = session:party():get(1)
        local bag = session:inventory()
        local freed = fillBag(bag, "kingsRock")
        pokemon:gainXP(pokemon:xpForLevel(11) - pokemon.xp)
        local ok, receipt = finish(game, battleFor(game), "victory", seedFor(0,98))
        assert(ok, receipt)
        eq(pokemon.heldItem, "kingsRock")
        local before = bag:toData()
        eq(session:takeHeldItem(pokemon), false)
        same(bag:toData(), before)
        eq(pokemon.heldItem, "kingsRock")
        assert(bag:consume(freed, 1))
        assert(session:takeHeldItem(pokemon))
        eq(pokemon.heldItem, "none")
        assert(session:giveHeldItem(pokemon, "kingsRock"))
        eq(pokemon.heldItem, "kingsRock")
        eq(session:inventory(), bag)
        eq(session:party():get(1), pokemon)
    end)
    test("Pickup real faint reward uses resulting level before return evolution", function()
        local pokemon = mon(nil, 10)
        pokemon.xp = pokemon:xpForLevel(11) - 1
        local game = owned({pokemon})
        local b = battleFor(game)
        local ok, receipt
        b:on("battleEnd", function(won, kind)
            eq(pokemon.level, 11)
            RulesRNG.seed(seedFor(0,98))
            ok, receipt = game.session:resolvePickupBattle(b, won, kind)
        end)
        b:setDirection("player")
        b.enemy.hp = 0
        b:runScript(function() return b:handleFaint() end)
        settle(b)
        assert(b:emitEnd())
        assert(ok, receipt)
        eq(pokemon.heldItem, "kingsRock")
    end)
    test("Pickup failure after detached award rolls preserves all identities and both RNGs; no retry", function()
        local first, second = mon(), mon()
        local game = owned({first, second})
        local session = game.session
        local b = battleFor(game)
        local party, bag = session:party(), session:inventory()
        local beforeBag, world = bag:toData(), session:worldRngData()
        local before = RulesRNG.new(seedFor(0)):snapshot()
        before.rolls = 2147483645
        local ok, why
        b:on("battleEnd", function(won, kind)
            RulesRNG.restore(before)
            ok, why = session:resolvePickupBattle(b, won, kind)
            eq(ok, false)
            assert(why:find("exhausted", 1, true), why)
            eq(session:resolvePickupBattle(b, won, kind), false)
        end)
        b:runScript(function() return "victory" end)
        settle(b)
        assert(b:emitEnd())
        eq(ok, false)
        eq(first.heldItem, "none")
        eq(second.heldItem, "none")
        eq(session:party(), party)
        eq(party:get(1), first)
        eq(party:get(2), second)
        eq(session:inventory(), bag)
        same(bag:toData(), beforeBag)
        same(session:worldRngData(), world)
        same(RulesRNG.snapshot(), before)
    end)
    test("Pickup actual receipt cannot replay or rebind; Continue has no battle receipt", function()
        local game = owned({mon(), mon("squirtle")})
        local b = battleFor(game)
        assert(finish(game, b, "victory", seedFor(0,98)))
        local before = RulesRNG.snapshot()
        eq(b:emitEnd(), false)
        eq(game.session:beginPickupBattle(b, 0), false)
        eq(game.session:resolvePickupBattle(b, true, "victory"), false)
        local data = assert(SessionCodec.encode(game.session, {root="overworld", overworld="explore", settled=true}))
        eq(data.version, SessionCodec.VERSION)
        local continued = assert(SessionCodec.decode(json.decode(json.encode(data)), game:getSessionDependencies()))
        eq(continued:party():get(1).heldItem, game.session:party():get(1).heldItem)
        eq(continued:resolvePickupBattle(b, true, "victory"), false)
        same(RulesRNG.snapshot(), before)
    end)
    test("Pickup premature and foreign owner rejected without losing real receipt", function()
        local game = owned()
        local b = battleFor(game)
        local before = RulesRNG.snapshot()
        eq(game.session:resolvePickupBattle(b, true, "victory"), false)
        eq(GameContext().session:resolvePickupBattle(b, true, "victory"), false)
        same(RulesRNG.snapshot(), before)
        assert(finish(game, b, "victory", seedFor(0)))
    end)
    for _, id in ipairs({"sunStone", "heartScale", "kingsRock", "ironBall", "prismScale", "leftovers"}) do
        test("Pickup validated Give Take storage JSON roundtrip and unsupported manual use " .. id, function()
            local pokemon = mon()
            local game = owned({mon("squirtle"), pokemon})
            local session = game.session
            assert(session:inventory():add(id, 1))
            assert(session:giveHeldItem(pokemon, id))
            eq(Items.planUse(id, pokemon), nil)
            local _, why = Items.planUse(id, pokemon)
            eq(why, "unsupported-item-use")
            assert(session:storage():deposit(session:party(), 2))
            local data = assert(SessionCodec.encode(session, {root="overworld", overworld="explore", settled=true}))
            local continued = assert(SessionCodec.decode(json.decode(json.encode(data)), game:getSessionDependencies()))
            eq(continued:storage():get(1).heldItem, id)
            assert(continued:storage():withdraw(continued:party(), 1))
            local again = continued:party():get(2)
            assert(continued:takeHeldItem(again))
            eq(continued:inventory():quantity(id), 1)
            eq(again.heldItem, "none")
        end)
    end
    test("Pickup ordinary BattleState return owns the one award before evolution", function()
        local lead, reserve = mon("squirtle", 10), mon(nil, 11)
        reserve.hp = 0
        local game = owned({lead, reserve})
        game.machine:register("overworld", State("overworld"))
        game.machine:register("learning", LearningState(game))
        local controller = BattleState(game)
        game.machine:register("battle", controller)
        game.machine:change("battle", lead, mon("rattata", 1))
        local b = controller.battle
        settle(b)
        b:setDirection("player")
        b.enemy.hp = 0
        b:runScript(function() return b:handleFaint() end)
        settle(b)
        RulesRNG.seed(seedFor(0,98))
        assert(b:emitEnd())
        eq(game.machine:getCurrent(), "overworld")
        eq(game.lastBattleOutcome.kind, "victory")
        eq(game.lastBattleOutcome.pickup.awards[1].slot, 2)
        eq(reserve.heldItem, "kingsRock")
        eq(reserve.hp, 0)
        eq(game.session:party():get(2), reserve)
        local before = RulesRNG.snapshot()
        eq(b:emitEnd(), false)
        same(RulesRNG.snapshot(), before)
    end)
    test("Pickup actual private SaveStore reload preserves all six held IDs and both RNGs", function()
        assert(HarnessBuild and HarnessBuild.enabled
            and HarnessBuild.bundle_id:match("^com%.poc%.pokemon%.harness%."), "private harness bundle required")
        local game = owned({mon("squirtle", 11), mon(), mon(), mon(), mon(), mon()})
        local ids = {"sunStone", "heartScale", "kingsRock", "ironBall", "prismScale", "leftovers"}
        for index, id in ipairs(ids) do game.session:party():get(index).heldItem = id end
        RulesRNG.seed(16777217)
        RulesRNG.random(0, 99)
        game.session:worldRandom(0, 99)
        local beforeRules, beforeWorld = game.session:rngData(), game.session:worldRngData()
        local prefix = "pickup-contract-" .. HarnessBuild.session_id
        -- Isolated bundle only. Clear this suite's own prefix for repeated runs.
        for _, suffix in ipairs({".a.json", ".b.json", ".candidate.json"}) do
            playdate.file.delete(prefix .. suffix)
        end
        local dependencies = game:getSessionDependencies()
        local store = SessionCodec.store(prefix, dependencies)
        local saved, problem = SessionCodec.save(store, game.session,
            {root="overworld", overworld="explore", settled=true})
        assert(saved, type(problem) == "table" and json.encode(problem) or problem)
        local continued = assert(SessionCodec.load(SessionCodec.store(prefix, dependencies), dependencies))
        for index, id in ipairs(ids) do eq(continued:party():get(index).heldItem, id) end
        same(continued:rngData(), beforeRules)
        same(continued:worldRngData(), beforeWorld)
        same(continued:fieldTravelData(), game.session:fieldTravelData())
    end)
    test("Pickup rejects non-field binding and inactive eligible attempt without RNG", function()
        local game = owned()
        local b = Battle(game.session:activePokemon(), mon("rattata", 1), nil, {session=game.session})
        settle(b)
        eq(game.session:beginPickupBattle(b, 2), false)
        assert(game.session:beginPickupBattle(b, 0))
        assert(game.session:deactivateRNG())
        local before = RulesRNG.snapshot()
        local ok, why = finish(game, b, "victory")
        eq(ok, false)
        assert(why:find("inactive-pickup-session", 1, true), why)
        eq(game.session:activePokemon().heldItem, "none")
        same(RulesRNG.snapshot(), before)
    end)
    test("King's Rock actual successful hit flinches through the typed payload", function()
        local seed
        for candidate = 1, 1000 do
            local stream = RulesRNG.new(candidate)
            stream:random(1,100) -- Scratch accuracy
            stream:random(1,16) -- critical chance
            stream:random(85,100) -- damage
            if stream:random(1,100) <= 10 then
                seed = candidate
                break
            end
        end
        assert(seed)
        local b = fresh(mon("squirtle", 25, "kingsRock"), mon("snorlax", 100))
        move(b, "scratch", seed)
        eq(b.enemy.flinched, true)
        eq(RulesRNG.snapshot().rolls, 4)
    end)
    test("Iron Ball speed, Flying dual-type neutral Ground and Levitate grounding", function()
        local b = fresh(mon("magnemite", 25, "ironBall"), mon("pidgey", 25, "ironBall"))
        eq(b:effectiveSpeed(b.player), math.max(1, b.player.spe // 2))
        eq(b.effects:grounded(b.enemy), true)
        eq(b:typeMatchup("ground", b.enemy), 1)
        local original, originalSecond = b.enemy.type, b.enemy.type2
        b.enemy.type, b.enemy.type2 = "flying", "steel"
        eq(b:typeMatchup("ground", b.enemy), 1)
        b.enemy.type, b.enemy.type2 = original, originalSecond
        b.enemy.heldItem = "none"
        eq(b:typeMatchup("ground", b.enemy), 0)
        local levitate = fresh(mon("squirtle"), mon("gastly", 25, "ironBall"))
        eq(levitate.effects:grounded(levitate.enemy), true)
        eq(levitate.effects:groundImmune(levitate.player, levitate.enemy, moveData.earthquake), false)
        levitate.enemy.heldItem = "none"
        eq(levitate.effects:grounded(levitate.enemy), false)
        eq(levitate.effects:groundImmune(levitate.player, levitate.enemy, moveData.earthquake), true)
    end)
    test("Iron Ball real Ground move and Spikes use existing damage owners; close removes hooks", function()
        local b = fresh(mon("squirtle", 25), mon("pidgey", 25, "ironBall"))
        move(b, "mudSlap", 42)
        assert(b.enemy.hp < b.enemy.maxHP)
        b.enemy:heal(b.enemy.maxHP)
        b.conditions.sides.enemy = {spikes=1, order={"spikes"}}
        b:runScript(function() b.conditions:entry(b.enemy, "enemy") end)
        settle(b)
        eq(b.enemy.hp, b.enemy.maxHP - math.max(1,b.enemy.maxHP // 8))
        b.effects:close()
        eq(PickupHeld.has(b.effects, b.enemy, "ironBall"), false)
        eq(b.effects:grounded(b.enemy), false)
    end)
    test("Leftovers ordered cohort heals before poison, clamps, no RNG or consumption", function()
        local b = fresh(mon("squirtle", 25, "leftovers"), mon("rattata", 25))
        local events = b.effects:events()
        eq(events[1].kind, "leftovers")
        eq(events[1].order, 5)
        eq(events[1].suborder, 4)
        b.player.hp = 1
        b.player.status = "poison"
        local before = RulesRNG.snapshot()
        local healed
        b:runScript(function()
            PickupHeld.residual(b.effects, events[1])
            healed = b.player.hp
            PickupHeld.residual(b.effects, events[1])
        end)
        settle(b)
        eq(healed, 1 + b.player.maxHP // 16)
        eq(b.player.hp, healed)
        b.player.hp = b.player.maxHP // 8 - b.player.maxHP // 16 + 1
        b:runScript(function() return b:endOfRoundStatus() end)
        settle(b)
        eq(b.player.hp, 1, "Leftovers precedes poison in the real residual cohort")
        b.player.hp = b.player.maxHP - 1
        b.player.status = nil
        b:runScript(function() return b:endOfRoundStatus() end)
        settle(b)
        eq(b.player.hp, b.player.maxHP)
        eq(b.player.heldItem, "leftovers")
        same(RulesRNG.snapshot(), before)
    end)
    test("Leftovers absent, fainted, withdrawn and closed holders cannot heal", function()
        local b = fresh(mon("squirtle", 25, "leftovers"), mon("rattata", 25))
        b.player.hp = 0
        eq(PickupHeld.event(b.effects, b.player, "player"), nil)
        b.player.hp = 1
        local event = PickupHeld.event(b.effects, b.player, "player")
        local previous = b.player
        b.player = mon("squirtle")
        PickupHeld.residual(b.effects, event)
        eq(previous.hp, 1)
        b.effects:close()
        eq(PickupHeld.event(b.effects, b.enemy, "enemy"), nil)
        local medicine = fresh(mon("squirtle", 25, "potion"), mon("rattata"))
        medicine.player.hp = 1
        eq(PickupHeld.event(medicine.effects, medicine.player, "player"), nil)
        eq(medicine.player.hp, 1)
        eq(medicine.player.heldItem, "potion")
    end)
    test("King's Rock real damaging hit adds one typed chance; absence has none", function()
        local withItem = fresh(mon("squirtle", 25, "kingsRock"), mon("snorlax", 60))
        local without = fresh(mon("squirtle", 25), mon("snorlax", 60))
        move(withItem, "scratch", 42)
        local itemRolls = RulesRNG.snapshot().rolls
        move(without, "scratch", 42)
        eq(itemRolls, RulesRNG.snapshot().rolls + 1)
        eq(withItem.enemy.hp, without.enemy.hp)
        eq(withItem.player.heldItem, "kingsRock")
    end)
    test("King's Rock each real Double Kick hit owns a chance", function()
        local withItem = fresh(mon("squirtle", 25, "kingsRock"), mon("snorlax", 100))
        local without = fresh(mon("squirtle", 25), mon("snorlax", 100))
        move(withItem, "doubleKick", 42)
        local rolls = RulesRNG.snapshot().rolls
        move(without, "doubleKick", 42)
        eq(rolls, RulesRNG.snapshot().rolls + 2)
    end)
    test("King's Rock does not stack with Stench or an existing typed flinch", function()
        for _, row in ipairs({{"grimer", "scratch"}, {"squirtle", "bite"}}) do
            local withItem = fresh(mon(row[1], 25, "kingsRock"), mon("snorlax", 100))
            local without = fresh(mon(row[1], 25), mon("snorlax", 100))
            move(withItem, row[2], 42)
            local after = RulesRNG.snapshot()
            move(without, row[2], 42)
            same(RulesRNG.snapshot(), after)
            eq(withItem.enemy.flinched, without.enemy.flinched)
        end
    end)
    test("King's Rock Shield Dust blocks before chance and Inner Focus blocks payload", function()
        for _, row in ipairs({{"caterpie", true}, {"abra", false}}) do
            local b = fresh(mon("squirtle", 25, "kingsRock"), mon(row[1], 100, "none", row[1] == "abra" and "second" or "first"))
            local before = RulesRNG.snapshot()
            b:runScript(function() ContactAbilities.secondaries(b.effects, b.player, b.enemy, moveData.scratch) end)
            settle(b)
            eq(RulesRNG.snapshot().rolls - before.rolls, row[2] and 0 or 1)
            eq(b.enemy.flinched, false)
        end
    end)
    test("King's Rock status move, absent target and closed lifecycle have no chance", function()
        local b = fresh(mon("squirtle", 25, "kingsRock"), mon("snorlax"))
        local before = RulesRNG.snapshot()
        ContactAbilities.secondaries(b.effects, b.player, b.enemy, moveData.growl)
        ContactAbilities.secondaries(b.effects, b.player, mon("snorlax"), moveData.scratch)
        b.effects:close()
        ContactAbilities.secondaries(b.effects, b.player, b.enemy, moveData.scratch)
        same(RulesRNG.snapshot(), before)
    end)
    if originalSession then eq(GameSession.activeRNGSession(), originalSession) end
    RulesRNG.restore(initial)
    return report
end
