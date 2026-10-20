-- Lifecycle/controller contracts on real SDK State/Dialog/BattleMenu/Pokemon.
-- Input-driven rendering acceptance remains in the harness learning scenarios.
LearningContracts = {}
local function equal(actual, wanted, label)
    assert(actual == wanted, (label or "value") .. ": expected " .. tostring(wanted) .. ", got " .. tostring(actual))
end
local function unchanged(pokemon, moves, pp)
    equal(table.concat(pokemon.moves, ","), moves, "known moves preserved")
    for key, value in pairs(pp) do equal(pokemon.pp[key], value, key .. " PP preserved") end
end
local function copyPP(pokemon)
    local copy = {}; for key, value in pairs(pokemon.pp) do copy[key] = value end; return copy
end
local function pending(species, level, target)
    local pokemon = Pokemon(species, level)
    pokemon:gainXP(pokemon:xpForLevel(target) - pokemon.xp)
    return pokemon
end
local function setup(pokemon, callback)
    local game = {machine = StateMachine()}
    local state = LearningState(game)
    game.machine:register("world", {})
    game.machine:register("learning", state)
    game.machine:change("world")
    if pokemon then LearningState.open(game, pokemon, callback) end
    return game, state
end
local function messageComplete(state)
    assert(state.dialog.isActive and state.dialog.onComplete, "active Dialog completion callback required")
    -- Dispatch the actual view's completion event. Native A/typewriter timing
    -- is independently exercised through physical-style SDK harness input.
    state.dialog.onComplete()
    state:handleInput()
end

function LearningContracts.run()
    local report = {ok = true, passed = 0, failed = 0, tests = {}}
    local function test(name, fn)
        local ok, problem = pcall(fn)
        report.tests[#report.tests + 1] = {name = name, ok = ok, error = not ok and tostring(problem) or nil}
        if ok then report.passed = report.passed + 1 else report.failed = report.failed + 1; report.ok = false end
    end

    test("Learning skips empty queue without lifecycle or callback side effects", function()
        local game, state = setup()
        local called = false
        equal(LearningState.open(game, Pokemon("charmander", 5), function() called = true end), false)
        equal(game.machine:stackNames(), "world"); equal(state.active, false); equal(called, false)
    end)

    test("Free slot learns visibly, preserves PP and returns control after message", function()
        local p = pending("charmander", 5, 7)
        p:usePP("scratch"); local pp = p.pp.scratch
        local result, resumed = nil, false
        local game, state = setup()
        game.machine:get("world").resume = function() resumed = true end
        LearningState.open(game, p, function(value)
            equal(game.machine:getCurrent(), "world", "callback after overlay exit")
            result = value
        end)
        equal(state.phase, "message"); equal(state.messageKind, "learned")
        equal(table.concat(p.moves, ","), "scratch,growl,ember")
        equal(p.pp.ember, moveData.ember.maxPP); equal(p.pp.scratch, pp)
        equal(#p:getPendingMoveChoices(), 0)
        equal(game.machine:depth(), 2, "message retains input ownership")
        messageComplete(state)
        equal(resumed, true); equal(result.kind, "complete"); equal(result.pending, 0)
        equal(result.results[1].move, "ember"); equal(state.active, false)
    end)

    test("Full set and both back paths preserve every move and PP", function()
        local p = pending("charmander", 15, 16)
        p:usePP("scratch"); p:usePP("growl")
        local before, pp = table.concat(p.moves, ","), copyPP(p)
        local game, state = setup(p)
        equal(state.phase, "ask"); unchanged(p, before, pp)
        state.menu.onSelect(1); equal(state.phase, "replace")
        state.menu.onSelect(3); equal(state.phase, "confirm"); unchanged(p, before, pp)
        state.menu.onCancel(); equal(state.phase, "replace"); equal(state.menu.selectedIndex, 3)
        unchanged(p, before, pp)
        state.menu.onCancel(); equal(state.phase, "ask"); unchanged(p, before, pp)
        equal(#p:getPendingMoveChoices(), 1)
        game.machine:pop()
    end)

    test("Replacement is committed only after explicit confirmation", function()
        local p = pending("charmander", 15, 16)
        p:usePP("scratch"); local scratchPP = p.pp.scratch
        local game, state = setup(p)
        state.menu.onSelect(1); state.menu.onSelect(2)
        equal(state.phase, "confirm"); equal(p.moves[2], "growl")
        state.menu.onSelect(2); equal(state.phase, "replace", "BACK option")
        equal(state.menu.selectedIndex, 2); equal(p.moves[2], "growl")
        state.menu.onSelect(2); state.menu.onSelect(1)
        equal(state.phase, "message"); equal(p.moves[2], "dragonRage")
        equal(p.pp.growl, nil); equal(p.pp.dragonRage, moveData.dragonRage.maxPP)
        equal(p.pp.scratch, scratchPP); equal(#p:getPendingMoveChoices(), 0)
        equal(#state.dialog.lines, 2, "forgot/learned narration")
        messageComplete(state); equal(game.machine:getCurrent(), "world")
    end)

    test("Explicit decline consumes exactly one pending choice and narrates it", function()
        local p = pending("bulbasaur", 12, 13)
        local before, pp = table.concat(p.moves, ","), copyPP(p)
        local game, state = setup(p)
        equal(state.pendingMove, "poisonPowder")
        state.menu.onSelect(2); equal(state.phase, "stop"); state.menu.onSelect(1)
        equal(state.messageKind, "declined"); unchanged(p, before, pp)
        equal(#p:getPendingMoveChoices(), 1); equal(p:getPendingMoveChoices()[1].move, "sleepPowder")
        messageComplete(state)
        equal(state.phase, "ask"); equal(state.pendingMove, "sleepPowder")
        state.menu.onSelect(2); state.menu.onSelect(1); messageComplete(state)
        equal(game.machine:getCurrent(), "world"); equal(#p:getPendingMoveChoices(), 0)
        unchanged(p, before, pp)
    end)

    test("Ask cancel confirms stopping; NO and B preserve moves and pending offer", function()
        local p = pending("charmander", 15, 16)
        local before, pp = table.concat(p.moves, ","), copyPP(p)
        local result
        local game, state = setup(p, function(value) result = value end)
        state.menu.onCancel(); equal(state.phase, "stop")
        equal(#p:getPendingMoveChoices(), 1); unchanged(p, before, pp)
        state.menu.onCancel(); equal(state.phase, "ask"); equal(result, nil)
        state.menu.onCancel(); state.menu.onSelect(2); equal(state.phase, "ask")
        equal(#p:getPendingMoveChoices(), 1); unchanged(p, before, pp)
        state.menu.onCancel(); state.menu.onSelect(1); equal(state.messageKind, "declined")
        messageComplete(state)
        equal(result.kind, "complete"); equal(result.pending, 0)
        equal(game.machine:getCurrent(), "world"); unchanged(p, before, pp)
    end)

    test("External exit clears listeners and stale callbacks cannot mutate on reentry", function()
        local p = pending("charmander", 15, 16)
        local called = false
        local game, state = setup(p, function() called = true end)
        state.menu.onSelect(1); state.menu.onSelect(1)
        local stale = state.menu.onSelect
        local before, pp = table.concat(p.moves, ","), copyPP(p)
        game.machine:change("world")
        equal(state.menu.onSelect, nil); equal(state.menu.onCancel, nil); equal(state.dialog.onComplete, nil)
        stale(1); unchanged(p, before, pp); equal(called, false)
        LearningState.open(game, p)
        stale(1); unchanged(p, before, pp); equal(state.phase, "ask")
        game.machine:pop()
    end)

    test("Callbacks from a previous view cannot skip confirmation or consume the next event", function()
        local p = pending("bulbasaur", 12, 13)
        local game, state = setup(p)
        local oldAsk = state.menu.onSelect
        state.menu.onSelect(1)
        oldAsk(2); equal(state.phase, "replace", "old ask must not open stop confirmation")
        state.menu.onSelect(1)
        local oldConfirm = state.menu.onSelect
        state.menu.onCancel(); oldConfirm(1)
        equal(state.phase, "replace"); equal(#p:getPendingMoveChoices(), 2)
        state.menu.onCancel(); state.menu.onSelect(2); state.menu.onSelect(1)
        local oldMessage = state.dialog.onComplete
        messageComplete(state)
        equal(state.pendingMove, "sleepPowder"); equal(state.phase, "ask")
        oldConfirm(1); oldMessage()
        equal(#p:getPendingMoveChoices(), 1); equal(state.phase, "ask")
        game.machine:pop()
    end)

    test("Multiple choices autoappend before explicit replacement without dropping events", function()
        local p = pending("charmander", 5, 16)
        local game, state = setup(p)
        equal(state.pendingMove, "ember"); equal(state.phase, "message")
        messageComplete(state)
        equal(state.pendingMove, "smokescreen"); equal(state.phase, "message")
        messageComplete(state)
        equal(state.pendingMove, "dragonRage"); equal(state.phase, "ask")
        equal(table.concat(p.moves, ","), "scratch,growl,ember,smokescreen")
        equal(#p:getPendingMoveChoices(), 1)
        state.menu.onSelect(2); state.menu.onSelect(1); messageComplete(state)
        equal(#p:getPendingMoveChoices(), 0); equal(game.machine:getCurrent(), "world")
    end)

    test("Known pending duplicate does not refill PP or prompt unnecessary replacement", function()
        local p = pending("charmander", 5, 7)
        p.moves[#p.moves + 1] = "ember"; p.pp.ember = 1
        local game, state = setup(p)
        equal(p.pp.ember, 1); equal(#p:getPendingMoveChoices(), 0)
        state:update(); equal(game.machine:getCurrent(), "world")
    end)

    test("Reentrant completion may open a new session after cleanup", function()
        local first, second = pending("charmander", 5, 7), pending("squirtle", 5, 7)
        local game, state = setup()
        local callbacks = 0
        LearningState.open(game, first, function()
            callbacks = callbacks + 1
            LearningState.open(game, second)
        end)
        messageComplete(state)
        equal(callbacks, 1); equal(state.pokemon, second); equal(state.pendingMove, "bubble")
        equal(state.phase, "message"); equal(game.machine:depth(), 2)
        messageComplete(state); equal(game.machine:getCurrent(), "world")
    end)

    test("Repeated draw is read-only and restores SDK draw offset", function()
        local p = pending("charmander", 15, 16)
        local game, state = setup(p)
        local image = playdate.graphics.image.new(400, 240)
        local pp, before = copyPP(p), table.concat(p.moves, ",")
        local function draw()
            playdate.graphics.pushContext(image)
            playdate.graphics.setDrawOffset(9, 17)
            local ok, problem = pcall(function()
                for _ = 1, 4 do state:draw() end
                local x, y = playdate.graphics.getDrawOffset(); equal(x, 9); equal(y, 17)
            end)
            playdate.graphics.popContext()
            if not ok then error(problem) end
        end
        draw(); equal(state.phase, "ask"); equal(state.menu.selectedIndex, 1)
        state.menu.onSelect(1); draw(); equal(state.phase, "replace")
        state.menu.onSelect(1); draw(); equal(state.phase, "confirm")
        unchanged(p, before, pp); equal(#p:getPendingMoveChoices(), 1)
        game.machine:pop()
    end)

    return report
end
