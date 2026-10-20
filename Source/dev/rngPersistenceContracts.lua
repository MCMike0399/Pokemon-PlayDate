-- Real SDK JSON and production RNG contracts; independent known recurrence
-- vectors, no Store/codec dependency or replacement JSON implementation.
RNGPersistenceContracts = {}
local ALGORITHM <const> = "park-miller-16807-v1"
local MAX <const> = 2147483647
local function equal(actual, wanted, label)
    assert(actual == wanted, (label or "value") .. ": expected " .. tostring(wanted) .. ", got " .. tostring(actual))
end
local function same(actual, wanted)
    for _, key in ipairs({"algorithm", "seed", "state", "rolls"}) do equal(actual[key], wanted[key], key) end
end
local function rejectUnchanged(stream, fn)
    local before = stream:snapshot()
    local ok = pcall(fn)
    equal(ok, false, "expected rejected input")
    same(stream:snapshot(), before)
end
local function clone(data)
    local copy = {}; for key, value in pairs(data) do copy[key] = value end; return copy
end
local function data(seed, state, rolls)
    return {version = 1, algorithm = ALGORITHM, seed = seed, state = state, rolls = rolls}
end

function RNGPersistenceContracts.run()
    local saved = RulesRNG.snapshot()
    local report = {ok = true, passed = 0, failed = 0, tests = {}}
    local function test(name, fn)
        local ok, problem = pcall(fn)
        report.tests[#report.tests + 1] = {name = name, ok = ok, error = not ok and tostring(problem) or nil}
        if ok then report.passed = report.passed + 1 else report.failed = report.failed + 1; report.ok = false end
    end

    test("SDK numeric float inputs normalize to actual native integers", function()
        equal(type(math.tointeger), "function", "installed SDK math.tointeger")
        equal(math.type(math.tointeger(42.0)), "integer")
        local integer, float = RulesRNG.new(42), RulesRNG.new(42.0)
        same(float:snapshot(), integer:snapshot())
        for _, field in ipairs({"seed", "state", "rolls"}) do equal(math.type(float:snapshot()[field]), "integer", field) end
        for _ = 1, 1000 do
            equal(float:random(), integer:random(), "float/int seeded continuation")
            same(float:snapshot(), integer:snapshot())
        end
        local exactHighFloat = RulesRNG.new(2147483520.0)
        local exactHighInt = RulesRNG.new(2147483520)
        for _ = 1, 25 do exactHighFloat:random(); exactHighInt:random(); same(exactHighFloat:snapshot(), exactHighInt:snapshot()) end
    end)

    test("Numeric restore and random interval floats do not leak float32 arithmetic", function()
        local r = RulesRNG.new(1)
        r:restore({algorithm = ALGORITHM, seed = 42.0, state = 42.0, rolls = 16777216.0})
        equal(math.type(r:snapshot().state), "integer")
        equal(math.type(r:snapshot().rolls), "integer")
        r:random(85.0, 100.0)
        equal(r:snapshot().state, 705894, "known seed42 first state")
        equal(r:snapshot().rolls, 16777217, "counter advances beyond float32 exact-integer boundary")
        equal(math.type(r:snapshot().state), "integer")
        local ints, floats = RulesRNG.new(42), RulesRNG.new(42)
        for _ = 1, 100 do
            local actual = floats:random(-6.0, 12.0)
            equal(actual, ints:random(-6, 12)); equal(math.type(actual), "integer", "normalized interval result")
            same(floats:snapshot(), ints:snapshot())
        end
    end)

    test("Integer seeds retain reference vectors and complete native seed range", function()
        local vectors = {
            {seed = 1, normalized = 1, state = 16807},
            {seed = 42, normalized = 42, state = 705894},
            {seed = 16777217, normalized = 16777217, state = 654328362},
            {seed = 2147483646, normalized = 2147483646, state = 2147466840},
            {seed = 2147483647, normalized = 1, state = 16807},
            {seed = -2147483647-1, normalized = 2147483644, state = 2147433226},
        }
        for _, vector in ipairs(vectors) do
            local r = RulesRNG.new(vector.seed)
            equal(r:snapshot().seed, vector.normalized)
            r:random(); equal(r:snapshot().state, vector.state, "seed " .. tostring(vector.seed))
            equal(math.type(r:snapshot().state), "integer")
        end
    end)

    test("Persistence exports canonical decimal strings and detached versioned records", function()
        local r = RulesRNG.new(16777217)
        local record = r:toData()
        equal(record.version, 1); equal(record.algorithm, ALGORITHM)
        equal(record.seed, "16777217"); equal(record.state, "16777217"); equal(record.rolls, "0")
        equal(type(record.seed), "string"); equal(type(record.state), "string"); equal(type(record.rolls), "string")
        record.seed, record.state, record.rolls = "1", "1", "3"
        equal(r:snapshot().seed, 16777217); equal(r:snapshot().state, 16777217); equal(r:snapshot().rolls, 0)
    end)

    test("Actual SDK JSON roundtrip preserves every high integer boundary exactly", function()
        for _, value in ipairs({16777215, 16777216, 16777217, 2147483646}) do
            local text = assert(DecimalInteger.encode(value))
            local r = RulesRNG.new(1)
            r:restoreData(data(text, text, "2147483647"))
            local original = r:snapshot()
            local decoded = json.decode(json.encode(r:toData()))
            equal(decoded.seed, text); equal(decoded.state, text); equal(decoded.rolls, "2147483647")
            local restored = RulesRNG.new(1); restored:restoreData(decoded)
            same(restored:snapshot(), original)
            for _, field in ipairs({"seed", "state", "rolls"}) do equal(math.type(restored:snapshot()[field]), "integer", field) end
        end
    end)

    test("High-state JSON reload continues the independently known sequence", function()
        local r = RulesRNG.new(1)
        r:restoreData(data("2147483646", "2147483646", "16777217"))
        local restored = RulesRNG.new(1)
        restored:restoreData(json.decode(json.encode(r:toData())))
        local expected = {2147466840, 1865008398, 524833574, 1162539989, 1003374717}
        for index, state in ipairs(expected) do
            equal(restored:random(1, 100), r:random(1, 100))
            equal(restored:snapshot().state, state, "high-state continuation " .. index)
            equal(restored:snapshot().rolls, 16777217 + index)
            equal(math.type(restored:snapshot().rolls), "integer")
        end
    end)

    test("Numeric snapshot API remains numeric and fully detached", function()
        local r = RulesRNG.new(42.0)
        local snapshot = r:snapshot()
        equal(type(snapshot.seed), "number"); equal(type(snapshot.state), "number"); equal(type(snapshot.rolls), "number")
        snapshot.state = 1; equal(r:snapshot().state, 42)
        local wire = r:toData()
        r:random(); r:restoreData(wire)
        equal(r:snapshot().state, 42); equal(r:snapshot().rolls, 0)
    end)

    test("Malformed versions, algorithms and extra fields reject without mutation", function()
        local r = RulesRNG.new(197)
        local valid = r:toData()
        for _, version in ipairs({0, 2, 1.5, "1", true, math.huge}) do
            local record = clone(valid); record.version = version
            rejectUnchanged(r, function() r:restoreData(record) end)
        end
        local record = clone(valid); record.version = nil
        rejectUnchanged(r, function() r:restoreData(record) end)
        record = clone(valid); record.algorithm = "other-v1"
        rejectUnchanged(r, function() r:restoreData(record) end)
        record = clone(valid); record.algorithm = nil
        rejectUnchanged(r, function() r:restoreData(record) end)
        record = clone(valid); record.extra = "unexpected"
        rejectUnchanged(r, function() r:restoreData(record) end)
        rejectUnchanged(r, function() r:restoreData(nil) end)
        rejectUnchanged(r, function() r:restoreData("not-a-table") end)
        local invoked = false
        local record = setmetatable({}, {__index = function() invoked = true; return "unexpected" end})
        rejectUnchanged(r, function() r:restoreData(record) end)
        equal(invoked, false, "wire records must not execute metatable getters")
    end)

    test("Noncanonical decimal text and numeric wire values reject transactionally", function()
        local r = RulesRNG.new(197)
        for _, field in ipairs({"seed", "state", "rolls"}) do
            for _, text in ipairs({"", "00", "01", "+1", "-0", "-1", " 1", "1 ", "1.0", "1e3", "0x10", "1\0", "NaN", 1, 42.0, true}) do
                local record = r:toData(); record[field] = text
                rejectUnchanged(r, function() r:restoreData(record) end)
            end
            local record = r:toData(); record[field] = nil
            rejectUnchanged(r, function() r:restoreData(record) end)
        end
    end)

    test("Out-of-range decimal boundaries never overflow or partially import", function()
        local r = RulesRNG.new(197)
        for _, field in ipairs({"seed", "state"}) do
            for _, text in ipairs({"0", "2147483647", "2147483648", "4294967296", "999999999999999999999999999"}) do
                local record = r:toData(); record[field] = text
                rejectUnchanged(r, function() r:restoreData(record) end)
            end
        end
        for _, text in ipairs({"2147483648", "4294967296", "999999999999999999999999999"}) do
            local record = r:toData(); record.rolls = text
            rejectUnchanged(r, function() r:restoreData(record) end)
        end
        -- Validation is all-or-nothing even when earlier fields are valid.
        rejectUnchanged(r, function() r:restoreData(data("1", "1", "2147483648")) end)
    end)

    test("Numeric APIs reject fractions, nonfinite and native overflow without mutation", function()
        local r = RulesRNG.new(197)
        for _, value in ipairs({1.5, math.huge, -math.huge, 0/0, 2147483648.0, "42", true}) do
            rejectUnchanged(r, function() r:seed(value) end)
            rejectUnchanged(r, function() r:restore({algorithm = ALGORITHM, seed = 1, state = value, rolls = 0}) end)
            rejectUnchanged(r, function() r:random(1, value) end)
        end
        rejectUnchanged(r, function() r:restore({algorithm = ALGORITHM, seed = 1, state = 1, rolls = -1}) end)
        rejectUnchanged(r, function() r:restore({algorithm = ALGORITHM, seed = 1, state = 1, rolls = 2147483648.0}) end)
    end)

    test("Full native counter boundary imports exactly, then blocks overflow unchanged", function()
        local r = RulesRNG.new(1)
        r:restoreData(json.decode(json.encode(data("1", "2147483646", "2147483646"))))
        r:random(); equal(r:snapshot().rolls, MAX); equal(r:snapshot().state, 2147466840)
        local record = json.decode(json.encode(r:toData()))
        equal(record.rolls, "2147483647")
        local restored = RulesRNG.new(1); restored:restoreData(record)
        same(restored:snapshot(), r:snapshot())
        rejectUnchanged(restored, function() restored:random() end)
    end)

    test("Counter exhaustion during rejection sampling commits no partial advance", function()
        local r = RulesRNG.new(1)
        -- First next state is2147483646 and is rejected for interval size2^30.
        -- The second advance would exceed the native counter limit.
        r:restoreData(data("1", "739806647", "2147483646"))
        rejectUnchanged(r, function() r:random(0, 1073741823) end)
    end)

    test("Production singleton persistence seam restores exact next draw independently", function()
        RulesRNG.seed(42.0)
        local wire = json.decode(json.encode(RulesRNG.toData()))
        local first = RulesRNG.random(1, 100)
        RulesRNG.random(); RulesRNG.restoreData(wire)
        equal(RulesRNG.random(1, 100), first)
        equal(RulesRNG.snapshot().state, 705894)
    end)

    RulesRNG.restore(saved)
    return report
end
