-- Run in the real SDK after production Pokemon/Battle/Codec imports.
GrowthContracts = {}
local function equal(actual, wanted, label)
    assert(actual == wanted, (label or "value") .. ": expected " .. tostring(wanted) .. ", got " .. tostring(actual))
end
local function rejected(fn)
    equal(pcall(fn), false, "invalid input rejected")
end
local function settle(b)
    local text, count = {}, 0
    while b:phase() == "script" do
        count = count + 1; assert(count < 100, "battle narration stalled")
        text[#text + 1] = b.message
        b.machine:get("script"):advance()
    end
    return table.concat(text, "|")
end
function GrowthContracts.run()
    local report = {ok = true, passed = 0, failed = 0, tests = {}}
    local function test(name, fn)
        local ok, problem = pcall(fn)
        report.tests[#report.tests + 1] = {name = name, ok = ok, error = not ok and tostring(problem) or nil}
        if ok then report.passed = report.passed + 1 else report.failed = report.failed + 1; report.ok = false end
    end
    test("Six growth families preserve cartridge boundary thresholds", function()
        local maxima = {1000000,600000,1640000,1059860,800000,1250000}
        for group = 0, 5 do
            equal(Growth.threshold(group, 1), 0)
            equal(Growth.threshold(group, 100), maxima[group + 1])
            for level = 2, 100 do assert(Growth.threshold(group, level) > Growth.threshold(group, level - 1)) end
        end
        equal(Growth.threshold(1, 68), 257834); equal(Growth.threshold(1, 69), 267406)
        equal(Growth.threshold(2, 15), 1957); equal(Growth.threshold(2, 16), 2457)
        equal(Growth.threshold(3, 5), 135); equal(Growth.threshold(3, 6), 179); equal(Growth.threshold(3, 7), 236)
    end)
    test("All151 production records have B2W2 growth and yield metadata", function()
        local counts, count = {}, 0
        for key, data in pairs(pokemonData) do
            local group, yield = Growth.species(data.dex)
            equal(data.baseExp, yield, key .. " base EXP")
            counts[group] = (counts[group] or 0) + 1; count = count + 1
            local p = Pokemon(key, 50)
            equal(p.xp, Growth.threshold(group, 50), key .. " level50")
            equal(p:xpForLevel(100), Growth.threshold(group, 100))
        end
        equal(count, 151); equal(counts[0],80); equal(counts[3],40); equal(counts[4],5); equal(counts[5],26)
        equal(baseExpYield("pikachu"),105); equal(baseExpYield("butterfree"),173)
    end)
    test("Species thresholds are required; no hidden medium-fast fallback", function()
        equal(Pokemon("charmander",5):xpForLevel(5),135)
        equal(Pokemon("clefairy",5):xpForLevel(5),100)
        equal(Pokemon("magikarp",5):xpForLevel(5),156)
        equal(Pokemon("rattata",5):xpForLevel(5),125)
        rejected(function() xpForLevel(5) end)
        rejected(function() xpForLevel(5,"missing") end)
        rejected(function() Growth.threshold(0,101) end)
    end)
    test("Exact level boundaries preserve bool return and learning queue", function()
        local p = Pokemon("charmander",5)
        local leveled, result = p:gainXP(43)
        equal(leveled,false); equal(p.level,5); equal(result.gained,43)
        leveled, result = p:gainXP(1)
        equal(leveled,true); equal(p.level,6); equal(#result.moveChoices,0)
        leveled, result = p:gainXP(57)
        equal(leveled,true); equal(p.level,7); equal(#result.moveChoices,1)
        equal(result.moveChoices[1].move,"ember"); equal(p:hasMove("ember"),false)
        equal(p:getPendingMoveChoices()[1].move,"ember")
    end)
    test("Exhausted learning IDs reject before XP stats PP or existing choices mutate", function()
        local p = Pokemon("charmander",6)
        p:gainXP(p:xpForLevel(7)-p.xp) -- Real pending Ember choice.
        p.nextMoveChoiceId = 2147483647
        assert(PokemonCodec.encode(p), "MAX counter must remain codec-valid")
        p:usePP("scratch")
        local pending, choice, moves, pp = p.pendingMoveChoices,p.pendingMoveChoices[1],p.moves,p.pp
        local before = {}
        for _, key in ipairs({"xp","xpToNext","level","hp","maxHP","atk","def","spa","spd","spe","nextMoveChoiceId"}) do before[key]=p[key] end
        local scratchPP = p.pp.scratch
        local ok, problem = pcall(function() p:gainXP(p:xpForLevel(10)-p.xp) end)
        equal(ok,false); assert(tostring(problem):find("move%-choice%-id%-exhausted"),tostring(problem))
        for key, value in pairs(before) do equal(p[key],value,"transactional " .. key) end
        equal(p.pendingMoveChoices,pending); equal(#pending,1); equal(pending[1],choice)
        equal(choice.id,1); equal(choice.move,"ember"); equal(p.moves,moves); equal(p.pp,pp); equal(p.pp.scratch,scratchPP)
        -- No learning allocation is needed at8, so an exhausted counter is legal.
        p:gainXP(p:xpForLevel(8)-p.xp); equal(p.level,8); equal(p.nextMoveChoiceId,2147483647)
        -- Exactly one remaining representable increment is accepted.
        p.nextMoveChoiceId=2147483646
        p:gainXP(p:xpForLevel(10)-p.xp)
        equal(p.level,10); equal(p.nextMoveChoiceId,2147483647)
        equal(#pending,2); equal(pending[2].id,2147483646); equal(pending[2].move,"smokescreen")
    end)
    test("Maximum native grant saturates without signed overflow", function()
        for _, species in ipairs({"rattata","clefairy","charmander","magikarp"}) do
            local p = Pokemon(species,99)
            local initial, max = p.xp,p:xpForLevel(100)
            local leveled, result = p:gainXP(2147483647)
            equal(leveled,true); equal(p.level,100); equal(p.xp,max); equal(p.xpToNext,max)
            equal(result.gained,max-initial); equal(result.totalXP,max); equal(result.capped,true)
            local _, again = p:gainXP(1); equal(again.gained,0); equal(p.xp,max)
        end
    end)
    test("Float-valued integer grants normalize; invalid grants are transactional", function()
        local p = Pokemon("charmander",5)
        p:gainXP(1.0); equal(math.type(p.xp),"integer"); local xp = p.xp
        for _, value in ipairs({-1,1.5,math.huge}) do rejected(function() p:gainXP(value) end); equal(p.xp,xp) end
        rejected(function() p:gainXP("5") end); equal(p.xp,xp)
    end)
    test("Fainted participants and level100 earn no XP or stat resurrection", function()
        local p, enemy = Pokemon("charmander",5),Pokemon("squirtle",5)
        local xp = p.xp; p.hp = 0
        equal(p:calcExpGain(enemy,true),0)
        local leveled, result = p:gainXP(2147483647)
        equal(leveled,false); equal(result.gained,0); equal(p.xp,xp); equal(p.hp,0)
        p = Pokemon("charmander",100); equal(p:calcExpGain(enemy,true),0)
        equal(Growth.battleAward(395,100,100,true),0)
    end)
    test("First-rival three matchups award trainer XP and reach only level6", function()
        for _, vector in ipairs({{"charmander","squirtle",95,230},{"squirtle","bulbasaur",97,232},{"bulbasaur","charmander",94,229}}) do
            local p, enemy = Pokemon(vector[1],5),Pokemon(vector[2],5)
            equal(p:calcExpGain(enemy,true),vector[3]); p:gainXP(vector[3])
            equal(p.level,6); equal(p.xp,vector[4]); equal(#p:getPendingMoveChoices(),0)
        end
    end)
    test("Real Battle passes trainer modifier and narrates actual accepted award once", function()
        local p, enemy = Pokemon("charmander",5),Pokemon("squirtle",5)
        local b = Battle(p,enemy,"RIVAL"); settle(b); enemy.hp = 0
        b:runScript(function() return b:handleFaint() end)
        local text = settle(b)
        equal(p.xp,230); equal(p.level,6)
        assert(text:find("gained 95 EXP!",1,true),"trainer award narration: " .. text)
        equal(b:handleFaint(),"victory"); equal(p.xp,230,"repeated outcome cannot award twice")
    end)
    test("Level100 battle victory suppresses zero-award narration", function()
        local p, enemy = Pokemon("charmander",100),Pokemon("squirtle",100)
        local b = Battle(p,enemy); settle(b); enemy.hp=0
        b:runScript(function() return b:handleFaint() end)
        local text=settle(b); equal(p.xp,1059860)
        assert(not text:find("EXP",1,true),"level100 must not narrate fabricated XP: " .. text)
    end)
    test("Codec respects species range and level100 maximum", function()
        for _, species in ipairs({"charmander","magikarp","clefairy","rattata"}) do
            local p=Pokemon(species,100); local record=PokemonCodec.encode(p)
            local restored=PokemonCodec.decode(record); equal(restored.xp,p:xpForLevel(100))
            record.xp=record.xp+1; local decoded, problem=PokemonCodec.decode(record)
            equal(decoded,nil); assert(problem:find("invalid%-xp"))
        end
        local record=PokemonCodec.encode(Pokemon("magikarp",5));record.xp=125
        local decoded, problem=PokemonCodec.decode(record); equal(decoded,nil); assert(problem:find("invalid%-xp"))
    end)
    test("Unreleased codec1 records reject explicitly instead of guessing XP migration", function()
        local record=PokemonCodec.encode(Pokemon("charmander",5));record.version=1
        local decoded, problem=PokemonCodec.decode(record)
        equal(decoded,nil); assert(problem:find("unsupported%-pokemon%-record%-version"),tostring(problem))
    end)
    -- Literal independent Decimal/Q12 oracle vectors appended below.
    test("58 independent Q12 scaled-XP vectors cover rounding and high-level products", function()
        local vectors = {
            {64,5,5,false,65},
            {64,5,5,true,97},
            {62,6,5,true,125},
            {63,7,20,true,45},
            {395,100,1,true,58340},
            {395,99,99,true,11732},
            {182,62,55,false,2580},
            {64,50,5,false,2385},
            {64,5,50,false,4},
            {105,99,98,true,3156},
            {105,32,36,false,590},
            {64,72,98,false,624},
            {62,71,6,true,5326},
            {173,24,28,true,1054},
            {62,100,92,false,1367},
            {105,22,9,false,920},
            {105,12,94,false,12},
            {173,52,28,false,3249},
            {105,86,53,true,4468},
            {64,100,46,false,2692},
            {395,94,98,false,7064},
            {173,27,9,false,2133},
            {182,87,85,true,4881},
            {62,86,58,false,1619},
            {395,42,36,true,5870},
            {182,62,64,true,3262},
            {64,26,87,false,60},
            {64,98,37,true,4526},
            {182,12,92,true,32},
            {64,35,3,true,2410},
            {182,64,77,false,1860},
            {105,15,70,false,37},
            {62,49,79,true,494},
            {173,68,82,false,1871},
            {62,30,3,false,1258},
            {62,26,17,true,715},
            {62,30,67,true,194},
            {62,8,75,true,7},
            {173,1,78,false,1},
            {64,37,89,false,142},
            {395,88,85,true,10861},
            {62,24,86,false,49},
            {62,69,6,false,3421},
            {395,95,80,false,9120},
            {62,85,58,true,2374},
            {173,1,84,true,1},
            {182,86,38,false,6730},
            {62,22,48,true,153},
            {395,69,59,true,9739},
            {173,99,96,false,3552},
            {173,93,43,true,10076},
            {105,92,7,true,12248},
            {182,47,42,false,1935},
            {62,92,36,false,2672},
            {182,22,43,false,352},
            {173,45,17,true,5309},
            {182,84,57,true,6918},
            {173,8,75,false,12},
        }
        for i,v in ipairs(vectors) do
            equal(Growth.battleAward(v[1],v[2],v[3],v[4]),v[5],"scaled vector " .. i)
        end
    end)
    return report
end
