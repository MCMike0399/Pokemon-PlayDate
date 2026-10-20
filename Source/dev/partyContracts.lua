-- SDK contracts exercising actual domain modules + actual production Pokemon.
-- No fake Playdate or Pokemon implementation. Import after all three modules.
PartyContracts = {}
local function eq(a, b, message) assert(a == b, message or (tostring(a) .. " ~= " .. tostring(b))) end
local function fail(ok, err, expected) eq(ok, false); eq(err, expected) end
local function mon(species) return Pokemon(species or "squirtle", 5) end
local function refsEqual(before, after)
    eq(#before, #after)
    for i, value in ipairs(before) do eq(value, after[i]) end
end
local function deepEqual(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do if not deepEqual(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end
local function encode(pokemon)
    -- Deliberately minimal TEST codec, not the final Pokemon save format.
    return { species = pokemon.species, level = pokemon.level, hp = pokemon.hp, marker = pokemon.testMarker or "none" }
end
local function decode(record)
    local pokemon = Pokemon(record.species, record.level)
    pokemon.hp, pokemon.testMarker = record.hp, record.marker
    return pokemon
end
local definitions = { potion = { keyItem = false }, pokeBall = { keyItem = false }, parcel = { keyItem = true } }

function PartyContracts.run()
    local results = {}
    local function test(name, fn)
        local ok, problem = pcall(fn)
        results[#results + 1] = { name = name, ok = ok, error = not ok and tostring(problem) or nil }
    end
    test("party-empty-full-duplicate-indices", function()
        local party = Party()
        eq(party:count(), 0); eq(party:activeIndex(), 0); eq(party:active(), nil); eq(party:allFainted(), false)
        local ok, err = party:add(nil); fail(ok, err, "invalid-pokemon")
    end)
    -- Multiple return values must remain the last argument to helper calls.
    test("party-capacity-and-cross-owner-atomicity", function()
        local party, other, storage = Party(), Party(), Storage()
        for i = 1, 6 do assert(party:add(mon())) end
        local extra, before = mon(), party:members()
        local ok, err = party:add(extra); fail(ok, err, "party-full")
        refsEqual(before, party:members()); eq(party:count(), 6)
        assert(storage:receive(extra)) -- failure did not claim the extra.
        ok, err = other:add(party:get(1)); fail(ok, err, "already-owned"); eq(other:count(), 0)
        for _, index in ipairs({0, -1, 7, 1.5}) do
            local active = party:active()
            ok, err = party:switch(index); fail(ok, err, "invalid-index")
            eq(party:active(), active); refsEqual(before, party:members())
        end
    end)
    test("party-order-switch-fainted-and-heal-all", function()
        local party = Party()
        local a, b = mon("bulbasaur"), mon("charmander")
        assert(party:add(a)); assert(party:add(b)); assert(party:switch(2))
        assert(party:swap(1, 2)); eq(party:active(), b); eq(party:activeIndex(), 1)
        local ok, err = party:swap(0, 1); fail(ok, err, "invalid-index"); eq(party:active(), b)
        a:takeDamage(a.maxHP); b:takeDamage(b.maxHP)
        eq(party:allFainted(), true); eq(party:firstUsable(), nil)
        ok, err = party:switch(2); fail(ok, err, "fainted"); eq(party:active(), b)
        for _, pokemon in ipairs(party:members()) do
            pokemon.status, pokemon.confusion, pokemon.flinched = "poison", 2, true
            pokemon.statStages.atk = -3
            for _, move in ipairs(pokemon.moves) do pokemon.pp[move] = 0 end
        end
        assert(party:healAll()); eq(party:allFainted(), false); eq(party:active(), b)
        for _, pokemon in ipairs(party:members()) do
            eq(pokemon.hp, pokemon.maxHP); eq(pokemon.status, nil); eq(pokemon.confusion, nil); eq(pokemon.flinched, false)
            eq(pokemon.statStages.atk, 0)
            for _, move in ipairs(pokemon.moves) do eq(pokemon.pp[move], moveData[move].maxPP) end
        end
        local exposed = party:members(); exposed[1] = nil; eq(party:count(), 2)
    end)
    test("storage-last-member-and-last-usable-protected", function()
        local party, storage = Party(), Storage()
        local a, b = mon(), mon("pidgey")
        assert(party:add(a))
        local ok, err = storage:deposit(party, 1); fail(ok, err, "last-member")
        eq(party:get(1), a); eq(storage:count(), 0)
        assert(party:add(b)); b:takeDamage(b.maxHP)
        ok, err = storage:deposit(party, 1); fail(ok, err, "last-usable")
        eq(party:get(1), a); eq(party:get(2), b); eq(storage:count(), 0)
        assert(storage:deposit(party, 2)); eq(storage:get(1), b); eq(party:count(), 1)
        assert(storage:withdraw(party, 1)); eq(party:get(2), b); eq(storage:count(), 0)
        b:fullRestore(); assert(storage:deposit(party, 1)); eq(party:active(), b); eq(storage:get(1), a)
        assert(storage:withdraw(party, 1)); eq(party:get(2), a)
    end)
    test("storage-capacity-active-box-and-transfer-identity", function()
        local party, storage = Party(), Storage()
        assert(party:add(mon())); assert(party:add(mon("pidgey")))
        for i = 1, 20 do assert(storage:receive(mon("rattata"))) end
        local first, before = storage:get(1), party:members()
        local ok, err = storage:deposit(party, 2); fail(ok, err, "box-full")
        refsEqual(before, party:members()); eq(storage:get(1), first); eq(storage:count(), 20); eq(storage:count(2), 0)
        ok, err = storage:selectBox(13); fail(ok, err, "invalid-box"); eq(storage:activeBox(), 1)
        ok, err = storage:withdraw(party, 0); fail(ok, err, "invalid-index"); eq(storage:count(), 20)
        assert(storage:move(1, 2)); eq(storage:count(), 19); eq(storage:get(1, 2), first)
        assert(storage:selectBox(2)); assert(storage:withdraw(party, 1)); eq(party:get(3), first)
        eq(storage:count(), 0); eq(storage:count(1), 19)
        while party:count() < 6 do assert(party:add(mon())) end
        assert(storage:selectBox(1)); first = storage:get(1)
        ok, err = storage:withdraw(party, 1); fail(ok, err, "party-full"); eq(storage:get(1), first)
        eq(storage:count(), 19); eq(party:count(), 6)
        ok, err = storage:receive(first); fail(ok, err, "already-owned")
        for box = 2, 12 do
            assert(storage:selectBox(box))
            for i = 1, 20 do assert(storage:receive(mon())) end
        end
        eq(storage:count(12), 20)
        ok, err = storage:move(1, 2); fail(ok, err, "box-full"); eq(storage:count(12), 20)
    end)
    test("party-storage-primitive-codec-roundtrip-and-rejections", function()
        local party, storage = Party(), Storage()
        local a, b = mon("bulbasaur"), mon("charmander")
        a.testMarker, b.testMarker = "chosen-a", "chosen-b"
        assert(party:add(a)); assert(party:add(b)); assert(party:switch(2))
        assert(storage:receive(mon("rattata"))); assert(storage:selectBox(12)); assert(storage:receive(mon("pidgey")))
        local pdata, sdata = assert(party:toData(encode)), assert(storage:toData(encode))
        local restored, boxes = assert(Party.fromData(pdata, decode)), assert(Storage.fromData(sdata, decode))
        assert(deepEqual(restored:toData(encode), pdata)); assert(deepEqual(boxes:toData(encode), sdata))
        eq(restored:activeIndex(), 2); eq(restored:get(1).testMarker, "chosen-a"); eq(boxes:activeBox(), 12)
        pdata.members[1].hp = 0; eq(party:get(1).hp, party:get(1).maxHP)
        local invalid, err = Party.fromData({version=1,active=2,members={}}, decode); eq(invalid,nil); eq(err,"invalid-party-data")
        invalid, err = Party.fromData({version=1,active=1,members={{}, {}}}, function() return a end)
        eq(invalid,nil); eq(err,"already-owned"); eq(party:get(1), a)
        local duplicate = mon()
        invalid, err = Party.fromData({version=1,active=1,members={{}, {}}}, function() return duplicate end)
        eq(invalid,nil); eq(err,"already-owned"); assert(Party():add(duplicate)) -- failed decode did not claim it.
        local cycle = {}; cycle.self = cycle
        invalid, err = party:toData(function() return cycle end); eq(invalid,nil); eq(err,"encode-failed")
    end)
    test("party-active-get-and-codec-input-validation", function()
        local party = Party()
        local pokemon = mon()
        assert(party:add(pokemon))
        for _, index in ipairs({0, -1, 2, 1.5}) do
            local value, err = party:get(index); eq(value, nil); eq(err, "invalid-index")
            eq(party:active(), pokemon); eq(party:activeIndex(), 1)
        end
        pokemon:takeDamage(pokemon.maxHP)
        local data = assert(party:toData(encode))
        local restored = assert(Party.fromData(data, decode))
        eq(restored:active(), restored:get(1)); eq(restored:activeIndex(), 1); eq(restored:allFainted(), true)
        for _, active in ipairs({-1, 0, 2, 1.5}) do
            local invalid, err = Party.fromData({version=1,active=active,members={encode(pokemon)}}, decode)
            eq(invalid,nil); eq(err,"invalid-party-data")
        end
        local invalid, err = Party.fromData({version=1,active=1,members={encode(pokemon)}}, function() return nil end)
        eq(invalid,nil); eq(err,"decode-failed")
        invalid, err = Party.fromData({version=1,active=1,members={[1]=encode(pokemon),[3]=encode(pokemon)}}, decode)
        eq(invalid,nil); eq(err,"invalid-party-data")
        invalid, err = party:toData(nil); eq(invalid,nil); eq(err,"codec-required")
        eq(party:active(), pokemon); eq(party:count(), 1)
    end)
    test("inventory-stack-splitting-key-items-and-capacity-atomicity", function()
        local bag = Inventory(definitions)
        assert(bag:add("potion", 98)); assert(bag:add("potion", 3))
        eq(bag:count(), 2); eq(bag:quantity("potion"), 101); eq(bag:slots()[1].quantity, 99); eq(bag:slots()[2].quantity, 2)
        assert(bag:add("parcel", 1))
        local before = bag:toData()
        local ok, err = bag:add("parcel", 1); fail(ok, err, "unique-key-item"); assert(deepEqual(before,bag:toData()))
        ok, err = bag:consume("parcel", 1); fail(ok, err, "key-item"); assert(deepEqual(before,bag:toData()))
        assert(bag:handoffKey("parcel")); eq(bag:quantity("parcel"), 0)
        for _, amount in ipairs({0,-1,100,1.5}) do
            before = bag:toData(); ok, err = bag:add("potion", amount); fail(ok, err, "invalid-quantity")
            assert(deepEqual(before,bag:toData()))
        end
        ok, err = bag:add("unknown", 1); fail(ok, err, "unknown-item")
        assert(bag:consume("potion", 99)); eq(bag:quantity("potion"), 2); eq(bag:count(), 1)
        before = bag:toData(); ok, err = bag:consume("potion", 3); fail(ok, err, "insufficient-items")
        assert(deepEqual(before,bag:toData()))
        while bag:count() < 20 do assert(bag:add("pokeBall", 99)) end
        before = bag:toData(); ok, err = bag:add("potion", 99); fail(ok, err, "bag-full")
        assert(deepEqual(before,bag:toData())) -- cannot partly fill potion from2 to99.
        local copy = bag:slots(); copy[1].quantity = 1; eq(bag:quantity("potion"), 2)
    end)
    test("inventory-wallet-serialization-and-quantity-bounds", function()
        local bag = Inventory(definitions)
        assert(bag:credit(3000)); assert(bag:spend(200)); eq(bag:money(), 2800)
        local before = bag:toData()
        local ok, err = bag:spend(2801); fail(ok, err, "insufficient-money"); assert(deepEqual(before,bag:toData()))
        ok, err = bag:credit(999999); fail(ok, err, "money-limit"); assert(deepEqual(before,bag:toData()))
        for _, amount in ipairs({-1, 0.5, 1000000}) do
            ok, err = bag:spend(amount); fail(ok, err, "invalid-money"); assert(deepEqual(before,bag:toData()))
        end
        assert(bag:add("potion", 20)); assert(bag:add("parcel", 1))
        local data = bag:toData(); local restored = assert(Inventory.fromData(definitions,data)); assert(deepEqual(data,restored:toData()))
        data.slots[1].quantity = 100
        local invalid, problem = Inventory.fromData(definitions,data); eq(invalid,nil); eq(problem,"invalid-slot")
        data = bag:toData(); data.slots[3] = {id="parcel",quantity=1}
        invalid, problem = Inventory.fromData(definitions,data); eq(invalid,nil); eq(problem,"unique-key-item")
        assert(deepEqual(bag:toData(),restored:toData()))
    end)
    local passed = 0
    for _, result in ipairs(results) do if result.ok then passed = passed + 1 end end
    return { ok = passed == #results, passed = passed, failed = #results - passed, tests = results }
end
