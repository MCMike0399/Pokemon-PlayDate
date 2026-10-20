-- Staged SDK tests. Import after production modules; root runtime owner executes.
LearnsetContracts = {}
local function equal(actual, wanted, label)
    assert(actual == wanted, (label or "value") .. ": expected " .. tostring(wanted) .. ", got " .. tostring(actual))
end
local function moves(mon, expected) equal(table.concat(mon.moves, ","), expected, mon.species .. " moves") end
local function rejects(fn) local ok = pcall(fn); assert(not ok, "expected rejection") end
local function settle(battle)
    local count = 0
    while battle:phase() == "script" do
        count = count + 1; assert(count < 200, "battle failed to settle")
        battle.machine:get("script"):advance()
    end
end
local function perform(battle, move)
    battle:setDirection("player")
    battle:runScript(function() return battle:performMove(move) end)
    settle(battle)
end

function LearnsetContracts.run()
    local snapshot = RulesRNG.snapshot()
    local report = {ok = true, passed = 0, failed = 0, tests = {}}
    local function test(name, fn)
        local ok, problem = pcall(fn)
        report.tests[#report.tests + 1] = {name = name, ok = ok, error = not ok and tostring(problem) or nil}
        if ok then report.passed = report.passed + 1 else report.failed = report.failed + 1; report.ok = false end
    end

    test("Lv5 starters preserve protected intro moves through ordinary initialization", function()
        moves(Pokemon("bulbasaur", 5), "tackle,growl")
        moves(Pokemon("charmander", 5), "scratch,growl")
        moves(Pokemon("squirtle", 5), "tackle,tailWhip")
        moves(Pokemon("charmander", 6), "scratch,growl")
        moves(Pokemon("charmander", 7), "scratch,growl,ember")
        moves(Pokemon("squirtle", 7), "tackle,tailWhip,bubble")
        moves(Pokemon("bulbasaur", 7), "tackle,growl,leechSeed")
    end)

    test("Abra and Magikarp respect actual low-level learnsets", function()
        moves(Pokemon("abra", 5), "teleport")
        moves(Pokemon("abra", 100), "teleport")
        moves(Pokemon("magikarp", 14), "splash")
        moves(Pokemon("magikarp", 15), "splash,tackle")
        moves(Pokemon("magikarp", 29), "splash,tackle")
        moves(Pokemon("magikarp", 30), "splash,tackle,flail")
    end)

    test("Known duplicates do not reorder slots and same-level order is preserved", function()
        moves(Pokemon("poliwhirl", 1), "waterSport,bubble,hypnosis")
        moves(Pokemon("poliwhirl", 5), "waterSport,bubble,hypnosis")
        moves(Pokemon("poliwhirl", 8), "waterSport,bubble,hypnosis")
        moves(Pokemon("bulbasaur", 13), "leechSeed,vineWhip,poisonPowder,sleepPowder")
    end)

    test("Every species constructs valid distinct move slots at representative levels", function()
        local species = 0
        for key in pairs(pokemonData) do
            species = species + 1
            for _, level in ipairs({1, 5, 25, 100}) do
                local p, seen = Pokemon(key, level), {}
                assert(#p.moves >= 1 and #p.moves <= 4, key .. " move-slot count")
                for _, move in ipairs(p.moves) do
                    assert(not seen[move], key .. " duplicate slot " .. move); seen[move] = true
                    equal(p.pp[move], moveData[move].maxPP, key .. " initial PP")
                    local eligible = false
                    for _, row in ipairs(pokemonData[key].learnset) do
                        if row.move == move and row.level >= 1 and row.level <= level then eligible = true end
                    end
                    assert(eligible, key .. " ineligible initial move " .. move)
                end
            end
        end
        equal(species, 151)
        rejects(function() Pokemon("abra", 0) end)
        rejects(function() Pokemon("abra", 101) end)
        rejects(function() Pokemon("abra", 5.5) end)
    end)

    test("Level-up offers new move without silently changing known moves or PP", function()
        local p = Pokemon("charmander", 6)
        p:usePP("scratch")
        local pp = p.pp.scratch
        local leveled, result = p:gainXP(p:xpForLevel(7) - p.xp)
        equal(leveled, true); equal(result.fromLevel, 6); equal(result.toLevel, 7)
        equal(#result.moveChoices, 1); equal(result.moveChoices[1].move, "ember")
        moves(p, "scratch,growl"); equal(p.pp.scratch, pp)
        local choices = p:getPendingMoveChoices(); choices[1].move = "corrupt"
        equal(p:getPendingMoveChoices()[1].move, "ember", "detached queue snapshot")
        result.moveChoices[1].move = "corrupt"
        equal(p:getPendingMoveChoices()[1].move, "ember", "detached gainXP result")
        local learned = p:resolveMoveChoice(choices[1].id, "learn")
        equal(learned.kind, "learned"); moves(p, "scratch,growl,ember")
        equal(p.pp.ember, moveData.ember.maxPP); equal(p.pp.scratch, pp)
        rejects(function() p:resolveMoveChoice(choices[1].id, "learn") end)
    end)

    test("Four-move learning requires explicit replacement and correct PP cleanup", function()
        local p = Pokemon("charmander", 15)
        p:usePP("growl"); local growlPP = p.pp.growl
        local _, result = p:gainXP(p:xpForLevel(16) - p.xp)
        equal(result.moveChoices[1].move, "dragonRage")
        local id = result.moveChoices[1].id
        rejects(function() p:resolveMoveChoice(id, "learn") end)
        rejects(function() p:resolveMoveChoice(id, "learn", 0) end)
        equal(#p:getPendingMoveChoices(), 1, "rejected choice remains pending")
        moves(p, "scratch,growl,ember,smokescreen")
        local result = p:resolveMoveChoice(id, "learn", 1)
        equal(result.forgotten, "scratch"); equal(result.slot, 1)
        moves(p, "dragonRage,growl,ember,smokescreen")
        equal(p.pp.scratch, nil); equal(p.pp.dragonRage, moveData.dragonRage.maxPP)
        equal(p.pp.growl, growlPP, "unrelated PP preserved")
    end)

    test("Same-level choices remain ordered and decline is explicit", function()
        local p = Pokemon("bulbasaur", 12)
        local _, result = p:gainXP(p:xpForLevel(13) - p.xp)
        equal(#result.moveChoices, 2)
        equal(result.moveChoices[1].move, "poisonPowder"); equal(result.moveChoices[1].sourceOrder, 1)
        equal(result.moveChoices[2].move, "sleepPowder"); equal(result.moveChoices[2].sourceOrder, 2)
        local before = table.concat(p.moves, ",")
        p:resolveMoveChoice(result.moveChoices[1].id, "decline")
        equal(table.concat(p.moves, ","), before)
        equal(p:getPendingMoveChoices()[1].move, "sleepPowder")
        p:resolveMoveChoice(result.moveChoices[2].id, "learn", 1)
        equal(p.moves[1], "sleepPowder")
    end)

    test("Multiple levels return chronological choices, duplicates and level cap are safe", function()
        local p = Pokemon("charmander", 5)
        local _, result = p:gainXP(p:xpForLevel(16) - p.xp)
        equal(table.concat(result.levels, ","), "6,7,8,9,10,11,12,13,14,15,16")
        local names = {}; for _, row in ipairs(result.moveChoices) do names[#names + 1] = row.move end
        equal(table.concat(names, ","), "ember,smokescreen,dragonRage")
        moves(p, "scratch,growl")
        local same, empty = p:gainXP(0); equal(same, false); equal(#empty.moveChoices, 0)
        equal(#p:getPendingMoveChoices(), 3)
        local duplicate = Pokemon("poliwhirl", 4)
        local _, result = duplicate:gainXP(duplicate:xpForLevel(8) - duplicate.xp)
        equal(#result.moveChoices, 0, "already-known repeated events do not prompt")
        local cap = Pokemon("charmander", 100)
        local grew, result = cap:gainXP(1000000); equal(grew, false); equal(result.toLevel, 100); equal(#result.moveChoices, 0)
        rejects(function() cap:gainXP(-1) end)
    end)

    test("Relearning queries preserve player choices and return detached eligible records", function()
        local p = Pokemon("bulbasaur", 20)
        local before = table.concat(p.moves, ",")
        local options = p:getRelearnableMoves()
        assert(#options > 0); equal(options[1].move, "tackle")
        options[1].move = "corrupt"
        equal(p:getRelearnableMoves()[1].move, "tackle")
        equal(table.concat(p.moves, ","), before)
        equal(#p:getPendingMoveChoices(), 0, "query must not enqueue unsolicited learning")
    end)

    test("Charm uses actual GenV Normal typing and defender Attack reduction", function()
        local b = Battle(Pokemon("bulbasaur", 20), Pokemon("squirtle", 20))
        settle(b); local hp = b.enemy.hp
        equal(moveData.charm.type, "normal"); equal(moveData.charm.accuracy, 100); equal(moveData.charm.maxPP, 20)
        perform(b, moveData.charm)
        equal(b.enemy.statStages.atk, -2); equal(b.player.statStages.atk, 0); equal(b.enemy.hp, hp)
        b.enemy.statStages.atk = -5; perform(b, moveData.charm); equal(b.enemy.statStages.atk, -6)
    end)

    test("Psywave uses GenV damage interval and ignores resistance, STAB and crit", function()
        equal(moveData.psywave.accuracy, 80); equal(moveData.psywave.maxPP, 15)
        for _, level in ipairs({1, 5, 50, 100}) do
            local b = Battle(Pokemon("abra", level), Pokemon("snorlax", 100)); settle(b); b:setDirection("player")
            local expected = math.max(1, math.floor(RulesRNG.new(197):random(50, 150) * level / 100))
            RulesRNG.seed(197)
            local before = b.enemy.hp
            b:runScript(function() PsywaveDamage():apply(b) end); settle(b)
            equal(before - b.enemy.hp, expected, "Psywave level " .. level)
            equal(b.lastDamage, expected); equal(RulesRNG.snapshot().rolls, 1)
            b.enemy:fullRestore(); b.enemy.type = "psychic" -- resistance does not scale fixed damage
            RulesRNG.seed(197); before = b.enemy.hp
            b:runScript(function() PsywaveDamage():apply(b) end); settle(b)
            equal(before - b.enemy.hp, expected, "Psywave resistance")
        end
    end)

    test("Psywave respects type immunity, accuracy and actual HP removed", function()
        local b = Battle(Pokemon("abra", 50), Pokemon("snorlax", 100)); settle(b); b:setDirection("player")
        b.enemy.type = "dark" -- isolated domain fixture, not a changed species definition
        RulesRNG.seed(92); local hp = b.enemy.hp
        b:runScript(function() PsywaveDamage():apply(b) end); settle(b)
        equal(b.enemy.hp, hp); equal(b.lastDamage, 0); equal(RulesRNG.snapshot().rolls, 0)
        b.enemy.type = "normal"; b.enemy.hp = 1
        b:runScript(function() PsywaveDamage():apply(b) end); settle(b)
        equal(b.lastDamage, 1); equal(b.enemy.hp, 0)
        b.enemy:fullRestore()
        local seed
        for n = 1, 1000 do if RulesRNG.new(n):random(1, 100) > 80 then seed = n; break end end
        assert(seed, "could not select deterministic miss fixture")
        RulesRNG.seed(seed); hp = b.enemy.hp; perform(b, moveData.psywave)
        equal(b.enemy.hp, hp, "80 accuracy miss must prevent damage")
        equal(RulesRNG.snapshot().rolls, 1, "miss must not roll damage")
    end)

    test("Psywave fainting reaches the correct terminal outcome exactly once", function()
        local b = Battle(Pokemon("abra", 50), Pokemon("snorlax", 5)); settle(b)
        local xp = b.player.xp
        b.enemy.hp = 1
        RulesRNG.seed(1); perform(b, moveData.psywave)
        equal(b.enemy.hp, 0); equal(b.lastDamage, 1)
        equal(b:phase(), "ended"); equal(b.machine:get("ended").won, true)
        assert(b.player.xp > xp, "victory must award XP")
        local awarded = b.player.xp; b:update(); equal(b.player.xp, awarded, "ended update must not award twice")
        local lost = Battle(Pokemon("snorlax", 5), Pokemon("abra", 50)); settle(lost)
        lost.player.hp = 1; lost:setDirection("enemy"); RulesRNG.seed(1)
        lost:runScript(function() return lost:performMove(moveData.psywave) end); settle(lost)
        equal(lost.player.hp, 0); equal(lost:phase(), "ended")
        equal(lost.machine:get("ended").won, false)
    end)

    test("Storm Throw is40-power forcedcrit and ignores unfavorable stages", function()
        equal(moveData.stormThrow.power, 40); equal(moveData.stormThrow.type, "fighting")
        equal(moveData.stormThrow.maxPP, 10); equal(moveData.stormThrow.willCrit, true)
        local a, d = Pokemon("machop", 50), Pokemon("rattata", 50)
        for seed = 1, 64 do
            RulesRNG.seed(seed); local hit = calcDamage(a, d, moveData.stormThrow)
            equal(hit.isCrit, true, "forcedcrit seed " .. seed)
            equal(RulesRNG.snapshot().rolls, 1, "only variance draw for forcedcrit")
            a.statStages.atk, d.statStages.def = -6, 6
            RulesRNG.seed(seed); local ignored = calcDamage(a, d, moveData.stormThrow)
            equal(ignored.damage, hit.damage, "crit ignores unfavorable stages")
            a.statStages.atk, d.statStages.def = 0, 0
        end
    end)

    RulesRNG.restore(snapshot)
    return report
end
