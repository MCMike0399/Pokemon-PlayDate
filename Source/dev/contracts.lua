-- SDK-only contracts: imports the real production objects via main.lua.
-- No replacement SDK globals, source rewriting, or synthetic rules engine.
Contracts = {}
local suites = {}

-- A bounded checkpoint survives a native SDK stall before the final reply.
function Contracts.progress(suite, name, status)
    if not HarnessBuild or not HarnessBuild.enabled then return end
    local file = assert(playdate.file.open("contract-progress.tmp", playdate.file.kFileWrite))
    file:write(json.encode({suite=suite,name=name,status=status,
        time_ms=playdate.getCurrentTimeMilliseconds(),heap_kib=collectgarbage("count")}))
    file:close()
    assert(playdate.file.rename("contract-progress.tmp","contract-progress.json"))
end

function Contracts.register(name, run)
    assert(type(name) == "string" and type(run) == "function", "contract suite requires a name and function")
    for _, suite in ipairs(suites) do assert(suite.name ~= name, "duplicate contract suite: " .. name) end
    suites[#suites + 1] = { name = name, run = run }
end
local function equal(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function truth(value, label) assert(value, label or "expected true") end
local function rejects(fn, label)
    local ok = pcall(fn)
    truth(not ok, label or "expected an error")
end
local function draw(scene, image)
    playdate.graphics.pushContext(image)
    local ok, err = pcall(scene.draw, scene)
    playdate.graphics.popContext()
    if not ok then error(err, 0) end
end
local function settle(battle)
    local count = 0
    while battle:phase() == "script" do
        count = count + 1
        truth(count < 200, "battle script failed to settle within 200 messages")
        battle.machine:get("script"):advance()
    end
end

function Contracts.run()
    local savedRNG = RulesRNG.snapshot()
    local savedOffsetX, savedOffsetY = playdate.display.getOffset()
    local report = { ok = true, passed = 0, failed = 0, tests = {}, suites = {} }
    local function test(name, fn)
        local ok, err = pcall(fn)
        report.tests[#report.tests + 1] = { name = name, ok = ok, error = not ok and tostring(err) or nil }
        if ok then report.passed = report.passed + 1
        else report.failed = report.failed + 1; report.ok = false end
    end

    test("OOP inheritance, mixin initialization and instance isolation", function()
        local parent = Class("ContractParent"):includes(Signal)
        function parent:init(n) self.n = n end
        function parent:value() return self.n end
        local child = Class("ContractChild", parent)
        local a, b = child(7), child(9)
        truth(a:is(parent) and a:is("ContractChild") and a:hasMixin(Signal), "inheritance identity")
        equal(a:value(), 7, "inherited init/method")
        local calls = 0
        a:on("event", function() calls = calls + 1 end)
        b:emit("event"); equal(calls, 0, "listeners must be per instance")
        a:emit("event"); equal(calls, 1, "inherited Signal")
    end)

    test("Signal removal, additions and nested once are stable", function()
        local e = Class("ContractEmitter"):includes(Signal)()
        local log, nested = {}, false
        local removed = function() log[#log + 1] = "removed" end
        e:once("x", function()
            log[#log + 1] = "once"
            e:off("x", removed)
            e:on("x", function() log[#log + 1] = "new" end)
            if not nested then nested = true; e:emit("x") end
        end)
        e:on("x", removed)
        e:emit("x")
        equal(table.concat(log, ","), "once,new", "mutation/reentry listener order")
        e:emit("x")
        equal(table.concat(log, ","), "once,new,new", "once removed before nested emission")
    end)

    test("Signal clear cancels in-flight callbacks and permits new listeners", function()
        local e = Class("ContractClearEmitter"):includes(Signal)()
        local log = {}
        e:on("x", function()
            log[#log + 1] = "clear"
            e:clearListeners("x")
            e:on("x", function() log[#log + 1] = "new" end)
        end)
        e:on("x", function() log[#log + 1] = "stale" end)
        e:emit("x"); e:emit("x")
        equal(table.concat(log, ","), "clear,new", "clear listener cancellation")
        e:clearListeners(); e:emit("x")
        equal(#log, 2, "clear all")
    end)

    test("Signal errors unwind emission bookkeeping", function()
        local e = Class("ContractErrorEmitter"):includes(Signal)()
        local bad = function() error("expected listener failure") end
        e:on("x", bad)
        rejects(function() e:emit("x") end)
        e:off("x", bad)
        equal(#e._listeners.x, 0, "failed emit must permit immediate listener cleanup")
        local calls = 0
        e:on("x", function() calls = calls + 1 end)
        e:emit("x"); equal(calls, 1, "emission after listener error")
    end)

    test("State overlays lifecycle order, arguments and input propagation", function()
        local m, log = StateMachine(), {}
        local function add(x) log[#log + 1] = x end
        m:register("base", {
            enter = function(_, a, b) equal(a, nil); equal(b, 4); add("enter") end,
            pause = function() add("pause") end,
            resume = function(_, a, b) equal(a, nil); equal(b, 8); add("resume") end,
            update = function() add("baseUpdate") end,
            draw = function() add("baseDraw") end,
            handleInput = function() add("baseInput") end,
            exit = function() add("baseExit") end,
        })
        local overlay = m:register("overlay", {
            enter = function() add("overlayEnter") end,
            update = function() add("overlayUpdate") end,
            draw = function() add("overlayDraw") end,
            handleInput = function() add("overlayInput") end,
            exit = function() add("overlayExit") end,
        })
        equal(m:change("base", nil, 4), m:get("base"), "change return")
        equal(m:push("overlay"), overlay, "push return")
        m:update(); m:draw(); m:handleInput()
        equal(m:pop(nil, 8), overlay, "pop return")
        m:handleInput()
        equal(table.concat(log, ","), "enter,pause,overlayEnter,baseUpdate,overlayUpdate,baseDraw,overlayDraw,overlayInput,overlayExit,resume,baseInput", "overlay lifecycle")
        equal(m:stackNames(), "base")
    end)

    test("State push during update waits for next update pass", function()
        local m, calls = StateMachine(), 0
        m:register("base", { update = function() if m:depth() == 1 then m:push("overlay") end end })
        m:register("overlay", { update = function() calls = calls + 1 end })
        m:change("base"); m:update(); equal(calls, 0, "new overlay update")
        m:update(); equal(calls, 1, "next pass overlay update")
    end)

    test("State same-state reentry invalidates the current traversal", function()
        local m, calls = StateMachine(), 0
        m:register("base", { update = function() m:change("base"); m:push("overlay") end })
        m:register("overlay", { update = function() calls = calls + 1 end })
        m:change("base"); m:update()
        equal(calls, 0, "same state transition must stop traversal")
        equal(m:stackNames(), "base>overlay")
    end)

    test("State draw transitions stop traversal and duplicate overlays fail", function()
        local m, calls = StateMachine(), 0
        m:register("base", { draw = function() if m:depth() == 1 then m:push("overlay") end end })
        m:register("overlay", { draw = function() calls = calls + 1 end })
        m:change("base"); m:draw(); equal(calls, 0, "draw must skip newly entered state")
        rejects(function() m:push("overlay") end, "duplicate active instance")
        equal(m:depth(), 2, "rejected overlay must not mutate stack")
        m:draw(); equal(calls, 1, "machine recovers after rejected transition")
    end)

    test("Lifecycle transitions serialize exit, changed, enter and resume", function()
        local m, log, queueExit = StateMachine(), {}, true
        local function add(x) log[#log + 1] = x end
        m:register("a", { exit = function() add("aExit"); if queueExit then queueExit = false; m:push("overlay") end end })
        m:register("b", { enter = function() add("bEnter") end, pause = function() add("bPause") end,
            resume = function() add("bResume"); m:change("final") end, exit = function() add("bExit") end })
        m:register("overlay", { enter = function() add("overlayEnter"); m:pop() end, exit = function() add("overlayExit") end })
        m:register("final", { enter = function() add("finalEnter") end })
        m:change("a")
        m:on("changed", function(kind, _, to) add(kind .. ":" .. tostring(to)) end)
        m:change("b")
        equal(m:getCurrent(), "final", "queued lifecycle destination")
        equal(table.concat(log, ","), "aExit,change:b,bEnter,bPause,push:overlay,overlayEnter,overlayExit,pop:b,bResume,bExit,change:final,finalEnter", "serialized lifecycle order")
    end)

    test("Changed listener transitions wait until enter completes", function()
        local m, log = StateMachine(), {}
        m:register("a", { enter = function() log[#log + 1] = "aEnter" end, exit = function() log[#log + 1] = "aExit" end })
        m:register("b", { enter = function() log[#log + 1] = "bEnter" end })
        m:on("changed", function(_, _, to) if to == "a" then m:change("b") end end)
        m:change("a")
        equal(table.concat(log, ","), "aEnter,aExit,bEnter", "changed callback reentry")
        equal(m:getCurrent(), "b")
        rejects(function() m:change("missing") end)
        equal(m:getCurrent(), "b", "unknown state must not exit current state")
    end)

    test("Nested machines retain overlay input policy and cancellation cleanup", function()
        local outer, inner, emitter = StateMachine(), StateMachine(), Class("ContractOwnedEmitter"):includes(Signal)()
        local updates, inputs, notifications = 0, 0, 0
        inner:register("explore", {update = function() updates = updates + 1 end,
            handleInput = function() inputs = inputs + 1 end})
        outer:register("world", {enter = function()
            inner:change("explore")
            emitter:on("event", function() notifications = notifications + 1 end)
        end, update = function() inner:update() end,
            handleInput = function() inner:handleInput() end,
            exit = function() emitter:clearListeners() end})
        outer:register("overlay", {})
        outer:register("other", {})
        outer:change("world"); outer:push("overlay")
        outer:update(); outer:handleInput(); emitter:emit("event")
        equal(updates, 1, "underlying nested animation update")
        equal(inputs, 0, "overlay must block nested input")
        outer:pop(); outer:handleInput(); equal(inputs, 1)
        outer:change("other"); emitter:emit("event")
        equal(notifications, 1, "exited owner must cancel listeners")
    end)

    test("Lifecycle loops are bounded and machine recovers", function()
        local m = StateMachine()
        local loop = m:register("loop", {enter = function() m:change("loop") end})
        m:register("safe", {})
        rejects(function() m:change("loop") end, "recursive enter must fail within transition budget")
        loop.enter = function() end
        m:change("safe"); equal(m:getCurrent(), "safe", "transition guard unwinds after error")
        m:pop(); equal(m:depth(), 0); equal(m:pop(), nil, "empty pop")
    end)

    test("Queued transition return values identify scheduled state", function()
        local m, queuedPush, queuedPop = StateMachine(), nil, nil
        local overlay = m:register("overlay", {enter = function() queuedPop = m:pop() end})
        local base = m:register("base", {enter = function() queuedPush = m:push("overlay") end})
        equal(m:change("base"), base, "outer change result")
        equal(queuedPush, overlay, "queued push result")
        equal(queuedPop, overlay, "queued pop result")
        equal(m:getCurrent(), "base", "queued operations drained before outer return")
    end)

    test("Rules RNG known sequence, validation, snapshot and replay", function()
        local r = RulesRNG.new(1)
        r:random(); equal(r:snapshot().state, 16807, "Park-Miller first vector")
        r:random(); equal(r:snapshot().state, 282475249, "Park-Miller second vector")
        local long = RulesRNG.new(1)
        for _ = 1, 10000 do
            local value = long:random()
            truth(value >= 0 and value < 1, "float32 unit roll outside [0,1)")
        end
        equal(long:snapshot().state, 1043618065, "Park-Miller 10000th vector")
        long:restore({ algorithm = "park-miller-16807-v1", seed = 1, state = 739806647, rolls = 0 })
        truth(long:random() < 1, "maximum state must not round unit float to 1")
        equal(long:snapshot().state, 2147483646, "maximum-state test vector")
        local saved = r:snapshot()
        local nextRoll = r:random(-10, 10)
        r:restore(saved); equal(r:random(-10, 10), nextRoll, "snapshot continuation")
        equal(r:snapshot().rolls, 3, "roll count")
        saved.state = 99
        truth(r:snapshot().state ~= 99, "snapshot must not alias stream")
        rejects(function() r:random(4, 1) end)
        rejects(function() r:seed(1.5) end)
        rejects(function() r:restore({algorithm = "unknown"}) end)
        equal(r:snapshot().rolls, 3, "invalid requests must not consume rolls")
    end)

    test("Pokemon health, PP, stages, restoration and level boundaries", function()
        local p = Pokemon("squirtle", 5)
        local move = p.moves[1]
        local pp = p.pp[move]
        truth(p:usePP(move)); equal(p.pp[move], pp - 1, "PP spent")
        p.pp[move] = 0; truth(not p:usePP(move), "zero PP must reject")
        p:takeDamage(p.maxHP + 20); equal(p.hp, 0, "damage floor")
        p:heal(p.maxHP + 20); equal(p.hp, p.maxHP, "healing cap")
        p.statStages.atk = -6; p.status = "sleep"; p.confusion = 2; p.flinched = true
        p:fullRestore(); equal(p.statStages.atk, 0); equal(p.status, nil); equal(p.confusion, nil)
        equal(p.flinched, false); equal(p.pp[move], moveData[move].maxPP)
        truth(p:gainXP(p:xpForLevel(6) - p.xp), "exact XP threshold levels")
        equal(p.level, 6, "level after exact threshold")
        local cap = Pokemon("squirtle", 100); cap:gainXP(1000000); equal(cap.level, 100)
    end)

    test("Gen V type composition and immunities", function()
        equal(TypeChart.getMatchup("electric", "water", "flying"), 4)
        equal(TypeChart.getMatchup("electric", "ground", "flying"), 0)
        equal(TypeChart.getMatchup("ghost", "steel"), 0.5, "Gen V steel resistance")
        equal(TypeChart.getMatchup("dark", "steel"), 0.5, "Gen V dark resistance")
        equal(TypeChart.getMatchup("normal", "ghost"), 0)
    end)

    test("Battle direction, DSL composition and status immunity", function()
        local b = Battle(Pokemon("charmander", 5), Pokemon("squirtle", 5))
        settle(b); b:setDirection("player")
        equal(ATTACKER:resolve(b), b.player); equal(DEFENDER:resolve(b), b.enemy)
        b:runScript(function()
            ModifyStat(DEFENDER, "atk", -20):apply(b)
            ModifyStat(DEFENDER, "atk", -1):apply(b)
            ApplyStatus(ATTACKER, "burn"):apply(b)
            ApplyStatus(DEFENDER, "sleep"):apply(b)
            ApplyStatus(DEFENDER, "poison"):apply(b)
        end)
        settle(b)
        equal(b.enemy.statStages.atk, -6, "stage clamp")
        equal(b.player.status, nil, "fire cannot burn")
        equal(b.enemy.status, "sleep", "major status cannot overwrite")
        truth(b.enemy.statusTurns >= 1 and b.enemy.statusTurns <= 3, "sleep counter range")
        b:setDirection("enemy"); equal(ATTACKER:resolve(b), b.enemy)
    end)

    test("Battle rules replay survives cosmetic RNG and repeated real SDK draws", function()
        local function run(extraDraws)
            RulesRNG.seed(824)
            local b = Battle(Pokemon("squirtle", 5), Pokemon("rattata", 3))
            local scene = BattleScene(b)
            local image = playdate.graphics.image.new(400, 240)
            for _ = 1, 21 do scene:update() end
            local messages = {}
            settle(b)
            b:selectMove(1)
            local count = 0
            while b:phase() == "script" do
                count = count + 1; truth(count <= 200, "round must finish")
                messages[#messages + 1] = b.message
                scene:update()
                if extraDraws then
                    for _ = 1, 7 do math.random(); draw(scene, image) end
                end
                b.machine:get("script"):advance()
            end
            local r = RulesRNG.snapshot()
            return table.concat({ b.player.hp, b.enemy.hp, b.player.pp[b.player.moves[1]], b:phase(), r.state, r.rolls, table.concat(messages, "|") }, ";")
        end
        equal(run(true), run(false), "round HP/PP/messages/phase/RNG replay")
    end)

    test("Battle scene draw is read-only; update preserves 20-frame iris and effects", function()
        local b = Battle(Pokemon("squirtle", 5), Pokemon("rattata", 3))
        local s = BattleScene(b)
        local image = playdate.graphics.image.new(400, 240)
        b.flashTimer, b.isFlashing, b.shakeTimer, b.shakeIntensity = 6, true, 8, 3
        RulesRNG.seed(81)
        for i = 1, 20 do
            s:update(); equal(s.introTimer, i, "iris update " .. i)
            local flash, shake, rng = b.flashTimer, b.shakeTimer, RulesRNG.snapshot()
            for _ = 1, 3 do draw(s, image) end
            equal(s.introTimer, i, "draw iris mutation")
            equal(b.flashTimer, flash, "draw flash mutation"); equal(b.shakeTimer, shake, "draw shake mutation")
            equal(RulesRNG.snapshot().rolls, rng.rolls, "draw rules RNG mutation")
        end
        equal(s.introPhase, "ready"); equal(s.irisRadius, 260)
        equal(b.shakeTimer, 8, "shake waits until iris completes")
        equal(b.isFlashing, false, "flash duration completes through update")
        s:update(); equal(b.shakeTimer, 7, "shake advances in update")
        local x, y = s.shakeX, s.shakeY
        for _ = 1, 4 do draw(s, image) end
        equal(s.shakeX, x); equal(s.shakeY, y); equal(b.shakeTimer, 7)
        equal(RulesRNG.snapshot().rolls, 0, "cosmetic shake does not consume rules RNG")
    end)

    test("Encounter selection and DSL random values replay independently", function()
        local zone = Zone({ name = "contract", tileRows = { "TG TG" }, encounters = {
            {species = "rattata", minLevel = 2, maxLevel = 4, weight = 7},
            {species = "pidgey", minLevel = 3, maxLevel = 5, weight = 3},
        } })
        local function roll(cosmetic)
            RulesRNG.seed(19)
            local values = {}
            for _ = 1, 20 do
                if cosmetic then for _ = 1, 9 do math.random() end end
                local encounter = zone:checkEncounter(0, 0)
                local p = zone:rollEncounter()
                values[#values + 1] = table.concat({tostring(encounter), p.species, p.level,
                    Between(2, 9):evaluate(), Weighted({{value = 4, weight = 2}, {value = 8, weight = 1}}):evaluate(), tostring(Chance(40):check())}, ":")
            end
            return table.concat(values, "|")
        end
        equal(roll(true), roll(false), "encounter/DSL replay")
    end)

    for _, suite in ipairs(suites) do
        local executed = { id = suite.name, ok = false, passed = 0, failed = 1 }
        if suite.name == "comprehensive-catalog" then executed.artifact_qualifier = "catalog-invariance-v1" end
        if suite.name == "brock-field-items" then executed.artifact_qualifier = "field-map-v1" end
        report.suites[#report.suites + 1] = executed
        Contracts.progress(suite.name,nil,"running")
        local ok, child = pcall(suite.run)
        Contracts.progress(suite.name,nil,"returned")
        if not ok then
            test(suite.name .. ": execution", function() error(child) end)
        elseif type(child) ~= "table" or type(child.tests) ~= "table" or #child.tests == 0 then
            test(suite.name .. ": report", function() error("missing contract results") end)
        else
            local passed, failed = 0, 0
            for _, result in ipairs(child.tests) do
                test(suite.name .. ": " .. tostring(result.name), function()
                    assert(type(result.name) == "string" and type(result.ok) == "boolean", "invalid contract result")
                    assert(result.ok, result.error or "contract failed")
                end)
                if result.ok == true then passed = passed + 1 else failed = failed + 1 end
            end
            executed.passed, executed.failed, executed.ok = passed, failed, failed == 0
            if child.passed ~= passed or child.failed ~= failed or child.ok ~= (failed == 0) then
                executed.ok = false
                test(suite.name .. ": report", function() error("inconsistent contract totals") end)
            end
        end
    end
    RulesRNG.restore(savedRNG)
    playdate.display.setOffset(savedOffsetX, savedOffsetY)
    return report
end
