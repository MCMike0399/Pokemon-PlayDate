-- Run only in root's real SDK harness. No replacement RNG, Party or SDK.
FieldAcquisitionContracts = {}
local function eq(actual,expected)
    assert(actual==expected,"expected "..tostring(expected)..", got "..tostring(actual))
end
local function same(a,b)
    eq(type(a),type(b))
    if type(a)~="table" then eq(a,b);return end
    for key,value in pairs(a) do same(value,b[key]) end
    for key in pairs(b) do assert(a[key]~=nil,"extra field "..tostring(key)) end
end
local function owned(species,slot,sex)
    local game <const> = GameContext()
    local lead <const> = Pokemon(species,10,{natureId=17,abilitySlot=slot or "first",heldItem="none",sex=sex})
    local reserve <const> = Pokemon("squirtle",5)
    assert(game:recruit(lead))
    assert(game:recruit(reserve))
    assert(game.session:setIntro({stage="done",starter="squirtle",rivalStarter="bulbasaur"}))
    assert(game.session:activateRNG())
    return game,lead,reserve
end
local function zone(species,rate)
    return Zone({name="field acquisition contracts",tileRows={"TG Fo"},encounterRate=rate or 1,
        encounters={{species=species or "abra",minLevel=5,maxLevel=5,weight=1}}})
end
local function prepare(game,area)
    local token,why=FieldEncounters.prepare({session=game.session,party=game.session:party(),zone=area,x=0,y=0})
    assert(token,why)
    return token
end
local function attempt(game,area,seed)
    if seed then RulesRNG.seed(seed) end
    local ok,result=FieldEncounters.resolve(prepare(game,area))
    assert(ok,result)
    return result
end
local function settle(battle)
    local count=0
    while battle.machine:is("script") do
        count=count+1
        assert(count<100,"battle did not settle")
        battle.machine:get("script"):advance()
    end
end
function FieldAcquisitionContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local function test(name,body)
        local before <const> = RulesRNG.snapshot()
        local owner <const> = GameSession.activeRNGSession()
        local ok,why=pcall(body)
        local active <const> = GameSession.activeRNGSession()
        if active~=owner then
            if active then assert(active:deactivateRNG()) end
            if owner then assert(owner:activateRNG()) end
        end
        RulesRNG.restore(before)
        report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(why) or nil}
        if ok then report.passed=report.passed+1
        else report.failed=report.failed+1;report.ok=false end
    end
    test("Synchronize literal 49/50 gates retain the ordinary nature draw",function()
        local game <const> = owned("abra")
        local off <const> = attempt(game,zone(),50)
        eq(off.receipt.field.synchronizeRoll,49)
        eq(off.receipt.field.synchronize,false)
        eq(off.pokemon.natureId,4) -- Sixth Park-Miller sample, including rate/slot/level.
        eq(off.receipt.creation.version,4)
        eq(off.receipt.creation.draws,9)
        eq(RulesRNG.snapshot().rolls,13)
        eq(RulesRNG.snapshot().state,1177395073)
        local on <const> = attempt(game,zone(),93)
        eq(on.receipt.field.synchronizeRoll,50)
        eq(on.pokemon.natureId,17)
        eq(on.receipt.creation.draws,9)
        eq(RulesRNG.snapshot().rolls,13)
        eq(RulesRNG.snapshot().state,600816937)
    end)
    test("Cute Charm literal 66/67 gates include failure-only fallback draw",function()
        local game <const> = owned("clefairy","first","male")
        local on <const> = attempt(game,zone("clefairy"),81)
        eq(on.receipt.field.cuteCharmRoll,66)
        eq(on.receipt.field.draws,1)
        eq(on.receipt.field.fallbackRoll,nil)
        eq(on.pokemon:getSex(),"female")
        eq(on.pokemon.sexProvenance.kind,"field-cute-charm")
        eq(on.pokemon.sexProvenance.protocol,4)
        eq(on.pokemon.sexProvenance.byte,80)
        eq(on.receipt.creation.draws,10)
        eq(RulesRNG.snapshot().rolls,14)
        eq(RulesRNG.snapshot().state,1718719108)
        local off <const> = attempt(game,zone("clefairy"),24)
        eq(off.receipt.field.cuteCharmRoll,67)
        eq(off.receipt.field.fallbackRoll,34)
        eq(off.receipt.field.draws,2)
        eq(off.pokemon.sexProvenance.kind,"generated")
        eq(off.pokemon.sexProvenance.byte,223)
        eq(off.receipt.creation.draws,9)
        eq(RulesRNG.snapshot().rolls,14)
        eq(RulesRNG.snapshot().state,1781833008)
    end)
    test("Cute Charm opposite sex respects all mixed ratios and fixed-sex exclusions",function()
        for _,sex in ipairs({"male","female"}) do
            local game <const> = owned("clefairy","first",sex)
            for _,species in ipairs({"bulbasaur","growlithe","pikachu","clefairy"}) do
                local result <const> = attempt(game,zone(species),81)
                local ratio <const> = SpecimenTraits.ratios[species]
                local byte <const> = result.pokemon.sexProvenance.byte
                eq(result.pokemon:getSex(),sex=="male" and "female" or "male")
                assert(sex=="male" and byte>=1 and byte<ratio or sex=="female" and byte>=ratio and byte<=253)
                eq(RulesRNG.snapshot().rolls,14)
            end
            for _,species in ipairs({"nidoranF","nidoranM","staryu"}) do
                local result <const> = attempt(game,zone(species),81)
                eq(result.pokemon:getSex(),Specimen.defaultSex(species))
                eq(result.pokemon.sexProvenance.kind,"generated")
                eq(result.receipt.creation.draws,9)
                eq(RulesRNG.snapshot().rolls,13)
            end
        end
    end)
    test("Fainted slot one supplies nature and sex while selected active stays independent",function()
        for _,species in ipairs({"abra","clefairy"}) do
            local game,lead,reserve=owned(species,"first","male")
            lead.hp=0
            assert(game.session:party():switch(2))
            local world <const> = game.session:worldRngData()
            local result <const> = attempt(game,zone("clefairy"),93)
            eq(result.receipt.physical_lead.fainted,true)
            eq(result.receipt.physical_lead.slot,1)
            eq(game.session:party():active(),reserve)
            if species=="abra" then eq(result.pokemon.natureId,17)
            else eq(result.pokemon:getSex(),"female") end
            same(world,game.session:worldRngData())
        end
    end)
    test("Genderless lead cannot invent a Cute Charm opposite sex",function()
        local game <const> = owned("staryu")
        -- Real original151 species cannot have both genderless and Cute Charm.
        -- Reject a forged lead/token rather than adding a fake ability owner.
        eq(Specimen.create("clefairy",5,"wild",RulesRNG.new(81),{}),nil)
        local result <const> = attempt(game,zone("clefairy"),81)
        eq(result.receipt.field.ability,35)
        eq(result.pokemon.sexProvenance.kind,"generated")
    end)
    test("Rate-up dispatch uses physical Diglett Staryu and No Guard Machop without gates",function()
        for _,row in ipairs({{"diglett","second",71},{"staryu","first",35},{"machop","second",99}}) do
            local game,lead,reserve=owned(row[1],row[2])
            lead.hp=0
            assert(game.session:party():switch(2))
            local result <const> = attempt(game,zone("abra",0.3),50000)
            eq(result.receipt.ability,row[3])
            eq(result.receipt.effective_rate,0.6)
            eq(result.receipt.field.draws,0)
            eq(result.kind,"encounter")
            eq(RulesRNG.snapshot().rolls,12)
            eq(game.session:party():active(),reserve)
            eq(FieldEncounters.effectiveRate({kind="byte",value=8},row[3]),16)
            eq(FieldEncounters.effectiveRate({kind="byte",value=200},row[3]),256)
        end
    end)
    test("Native rate-down family truncates byte rates and halves unit rates purely",function()
        for _,ability in ipairs({1,73,95}) do
            eq(FieldEncounters.effectiveRate({kind="byte",value=9},ability),4)
            eq(FieldEncounters.effectiveRate({kind="unit",value=0.5},ability),0.25)
        end
        local game <const> = owned("grimer")
        local result <const> = attempt(game,zone("abra",0.6),50000)
        eq(result.receipt.ability,1)
        eq(result.receipt.field.draws,0)
        eq(result.receipt.effective_rate,0.3)
        -- First PM sample is about 0.391: base 0.6 passes, halved 0.3 fails.
        eq(result.kind,"none")
        eq(RulesRNG.snapshot().rolls,1)
        local saved <const> = RulesRNG.snapshot()
        FieldEncounters.effectiveRate({kind="unit",value=1},28)
        same(saved,RulesRNG.snapshot())
    end)
    test("Actual Blue Forest rate byte eight becomes sixteen for physical Arena Trap",function()
        local game <const> = owned("diglett","second")
        local area <const> = PewterWorld.isolated("ViridianForest")
        local x,y
        for gy=0,area.height-1 do
            for gx=0,area.width-1 do
                if area:isTallGrass(gx,gy) and area.collision[gy+1][gx+1]==0 then x,y=gx,gy;break end
            end
            if x then break end
        end
        assert(x)
        RulesRNG.seed(253)
        local token <const> = assert(FieldEncounters.prepare({session=game.session,
            party=game.session:party(),zone=area,x=x,y=y}))
        local ok,result=FieldEncounters.resolve(token)
        assert(ok,result)
        eq(result.receipt.rate.kind,"byte")
        eq(result.receipt.rate.value,8)
        eq(result.receipt.rate_roll,10)
        eq(result.receipt.effective_rate,16)
        eq(result.kind,"encounter")
        eq(RulesRNG.snapshot().rolls,12)
    end)
    test("Failure-rate attempts consume only the appropriate acquisition flag prefix",function()
        for _,row in ipairs({{"abra",50,2},{"clefairy",81,2},{"clefairy",24,3}}) do
            local game <const> = owned(row[1])
            local world <const> = game.session:worldRngData()
            local result <const> = attempt(game,zone("abra",0.00000001),row[2])
            eq(result.kind,"none")
            eq(result.reason,"rate")
            eq(RulesRNG.snapshot().rolls,row[3])
            same(world,game.session:worldRngData())
        end
    end)
    test("Session wild factory owns the same flags exactly once and detached flag reads cannot touch global RNG",function()
        for _,row in ipairs({{"abra",93,10},{"clefairy",81,11},{"clefairy",24,11}}) do
            local game <const> = owned(row[1],"first","male")
            RulesRNG.seed(row[2])
            local token <const> = assert(Specimen.planEncounter(game.session))
            local before <const> = RulesRNG.snapshot()
            eq(pcall(Specimen.rollEncounterAbilities,token,RulesRNG),false)
            same(before,RulesRNG.snapshot())
            local mon,receipt=Specimen.createForSession(game.session,"clefairy",5,"wild")
            assert(mon,receipt)
            eq(receipt.version,4)
            eq(receipt.draws,row[3])
            eq(receipt.rawRolls,row[3])
            eq(RulesRNG.snapshot().rolls,row[3])
        end
    end)
    test("Stale lead nature sex HP and roster changes reject before any extra draw",function()
        for _,change in ipairs({
            function(game,lead) lead.natureId=3 end,
            function(game,lead) lead.sex="female" end,
            function(game,lead) lead.hp=0 end,
            function(game) assert(game.session:party():swap(1,2)) end,
        }) do
            local game,lead=owned("clefairy","first","male")
            RulesRNG.seed(81)
            local token <const> = prepare(game,zone())
            change(game,lead)
            local before <const> = RulesRNG.snapshot()
            eq(FieldEncounters.resolve(token),false)
            same(before,RulesRNG.snapshot())
        end
    end)
    test("Constructor and Cute Charm fallback exhaustion roll back actual rules and world streams",function()
        local game <const> = owned("clefairy","first","male")
        RulesRNG.seed(24)
        local area <const> = zone()
        local token <const> = prepare(game,area)
        local before <const> = RulesRNG.snapshot()
        local world <const> = game.session:worldRngData()
        local original <const> = Specimen.create
        Specimen.create=function() return nil,"controlled-field-acquisition-failure" end
        local ok,why=FieldEncounters.resolve(token)
        Specimen.create=original
        eq(ok,false)
        assert(why:find("controlled-field-acquisition-failure",1,true))
        same(before,RulesRNG.snapshot())
        same(world,game.session:worldRngData())
        local exhausted=RulesRNG.snapshot()
        exhausted.rolls=2147483646
        RulesRNG.restore(exhausted)
        local exhaustedToken <const> = prepare(game,area)
        eq(FieldEncounters.resolve(exhaustedToken),false)
        same(exhausted,RulesRNG.snapshot())
        same(world,game.session:worldRngData())
    end)
    test("Actual deferred acquisition callbacks fail by name without committing draws",function()
        for _,row in ipairs({{"magnemite","first","magnet-pull-slots"},
            {"aerodactyl","second","pressure-level"},{"rattata","second","hustle-level"},
            {"mankey","first","vital-spirit-level"}}) do
            local game <const> = owned(row[1],row[2])
            -- Hustle is Rattata's hidden slot; ordinary second is Guts.
            if row[3]=="hustle-level" then game.session:party():get(1).abilitySlot="hidden" end
            RulesRNG.seed(93)
            local token <const> = assert(Specimen.planEncounter(game.session))
            eq(Specimen.encounterGap(token),row[3])
            local before <const> = RulesRNG.snapshot()
            local world <const> = game.session:worldRngData()
            local ok,why,gap=FieldEncounters.resolve(prepare(game,zone()))
            eq(ok,false)
            assert(why:find("unimplemented-field-acquisition:"..row[3],1,true),why)
            eq(gap.kind,"field-acquisition-gap")
            eq(gap.hook,row[3])
            eq(gap.leadSpecies,row[1])
            same(before,RulesRNG.snapshot())
            same(world,game.session:worldRngData())
        end
    end)
    test("Influenced capture retains identity and provenance through real Battle Session and codec",function()
        local game,lead,reserve=owned("clefairy","first","male")
        assert(game.session:party():switch(2))
        local mon <const> = attempt(game,zone("clefairy"),81).pokemon
        local attributes <const> = mon:attributes()
        local world <const> = game.session:worldRngData()
        local battle <const> = Battle(reserve,mon,nil,{party=game.session:party(),session=game.session})
        settle(battle)
        local before <const> = RulesRNG.snapshot()
        eq(battle:throwBall("masterBall"),false)
        eq(game.session:party():count(),2)
        eq(Party._owner(mon),nil)
        same(before,RulesRNG.snapshot())
        assert(game.session:inventory():add("masterBall",1))
        assert(battle:throwBall("masterBall"))
        eq(battle.caughtPokemon,mon)
        eq(game.session:party():get(3),mon)
        same(attributes,mon:attributes())
        settle(battle)
        local saved <const> = assert(SessionCodec.encode(game.session,{root="overworld",overworld="explore",settled=true}))
        local loaded <const> = assert(SessionCodec.decode(json.decode(json.encode(saved)),game:getSessionDependencies()))
        same(attributes,loaded:party():get(3):attributes())
        same(world,game.session:worldRngData())
    end)
    test("Old generated provenance and pure reads/drawing consume no acquisition RNG",function()
        local game <const> = owned("abra")
        local ordinary <const> = assert(Specimen.create("clefairy",5,"wild",RulesRNG.new(1)))
        local record <const> = assert(PokemonCodec.encode(ordinary))
        eq(record.sexProvenance.protocol,2)
        local before <const> = RulesRNG.snapshot()
        local world <const> = game.session:worldRngData()
        for i=1,3 do
            local restored <const> = assert(PokemonCodec.decode(record))
            same(record,PokemonCodec.encode(restored))
            restored:attributes()
            game.session:party():members()
            Specimen.planEncounter(game.session)
        end
        same(before,RulesRNG.snapshot())
        local battle <const> = Battle(game.session:party():active(),ordinary,nil,
            {party=game.session:party(),session=game.session})
        settle(battle)
        local drawBefore <const> = RulesRNG.snapshot()
        local image <const> = assert(playdate.graphics.image.new(400,240))
        playdate.graphics.pushContext(image)
        local ok,why=pcall(function() BattleScene(battle):draw() end)
        playdate.graphics.popContext()
        assert(ok,why)
        same(drawBefore,RulesRNG.snapshot())
        same(world,game.session:worldRngData())
        -- Entry may draw its own battle speed tie; pure reads above do not.
    end)
    return report
end
