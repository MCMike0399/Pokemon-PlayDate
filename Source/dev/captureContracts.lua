-- Actual SDK rules/data/RNG contracts; no bag/battle or replacement SDK.
CaptureContracts = {}
local function equal(actual,wanted,label)
    assert(actual==wanted,(label or "value") .. ": expected " .. tostring(wanted) .. ", got " .. tostring(actual))
end
local function context(species,hp,maximum,status)
    local mon=Pokemon(species or "rattata",5)
    mon.hp=hp or mon.maxHP;mon.maxHP=maximum or mon.maxHP
    mon.status=status;mon.statusTurns=status=="sleep" and 2 or 0;mon.sleepDuration=status=="sleep" and 3 or 0
    return {pokemon=mon,wild=true}
end
local function same(a,b)
    for _,key in ipairs({"algorithm","seed","state","rolls"}) do equal(a[key],b[key],key) end
end
local function rejected(ctx,ball,count,why)
    local rng=RulesRNG.new(42);local before=rng:snapshot()
    local result,problem=Capture.attempt(ctx,ball,count,rng)
    equal(result,nil);equal(problem,why);same(rng:snapshot(),before)
end
function CaptureContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local originalRNG=RulesRNG.snapshot()
    local function test(name,fn)
        local ok,problem=pcall(fn)
        report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(problem) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("All151 species have valid pinned B2W2 catch rates",function()
        local total=0
        for _,data in pairs(pokemonData) do
            local rate=CaptureData[data.dex]
            assert(type(rate)=="number" and rate>=1 and rate<=255,"missing catch rate dex" .. data.dex)
            total=total+1
        end
        equal(total,151);equal(CaptureData[1],45);equal(CaptureData[25],190)
        equal(CaptureData[113],30);equal(CaptureData[143],25)
        for _,dex in ipairs({144,145,146,150}) do equal(CaptureData[dex],3) end
    end)
    test("Trainer and absent ownership context reject before RNG",function()
        rejected({pokemon=Pokemon("rattata",5),wild=false},"masterBall",151,"not-wild-target")
        rejected({pokemon=Pokemon("rattata",5)},"pokeBall",0,"not-wild-target")
        rejected(nil,"pokeBall",0,"invalid-capture-context")
        rejected(Pokemon("rattata",5),"pokeBall",0,"invalid-capture-context")
    end)
    test("Unsupported terrain bonuses and context flags cannot silently degrade",function()
        for _,changes in ipairs({{terrain="thickGrass"},{capturePower=110},{safari=true},{doubleBattle=true}}) do
            local ctx=context();for key,value in pairs(changes) do ctx[key]=value end
            rejected(ctx,"pokeBall",0,"unsupported-capture-context")
        end
        local ctx=context();ctx.terrain="ordinary";ctx.capturePower=100
        assert(Capture.attempt(ctx,"masterBall",0,RulesRNG.new(1)))
    end)
    test("Only original four normal ball types are supported",function()
        for _,ball in ipairs({"safariBall","dreamBall","potion","unknown"}) do rejected(context(),ball,0,"unsupported-ball") end
    end)
    test("Invalid target object species types HP and status reject unchanged RNG",function()
        rejected({pokemon={},wild=true},"pokeBall",0,"invalid-pokemon")
        for _,hp in ipairs({0,-1,65536,1.5}) do local ctx=context();ctx.pokemon.hp=hp;rejected(ctx,"pokeBall",0,"invalid-target-hp") end
        local ctx=context();ctx.pokemon.type="fairy";rejected(ctx,"pokeBall",0,"invalid-pokemon")
        ctx=context();ctx.pokemon.dex=999;rejected(ctx,"pokeBall",0,"invalid-pokemon")
        ctx=context();ctx.pokemon.status="unknownStatus";rejected(ctx,"pokeBall",0,"invalid-target-status")
        ctx=context();ctx.pokemon.statusTurns=1;rejected(ctx,"pokeBall",0,"invalid-target-status")
    end)
    test("Caught count is distinct original-roster species0 through151",function()
        for _,count in ipairs({-1,152,649,1.5,"31"}) do rejected(context(),"pokeBall",count,"invalid-caught-count") end
        local ctx=context("rattata",20,20)
        local zero=assert(Capture.parameters(ctx,"pokeBall",30))
        local half=assert(Capture.parameters(ctx,"pokeBall",31))
        local lastHalf=assert(Capture.parameters(ctx,"pokeBall",150))
        local full=assert(Capture.parameters(ctx,"pokeBall",151))
        equal(zero.criticalThreshold,0);equal(half.criticalThreshold,7);equal(lastHalf.criticalThreshold,7);equal(full.criticalThreshold,14)
    end)
    test("Master Ball guarantees valid wild target without RNG even at exhausted counter",function()
        local ctx=context("mewtwo",1,300,"sleep")
        local rng=RulesRNG.new(42);local before=rng:snapshot();before.rolls=2147483647;rng:restore(before)
        local result=assert(Capture.attempt(ctx,"masterBall",151,rng))
        equal(result.caught,true);equal(result.guaranteed,true);equal(result.guarantee,"master-ball")
        equal(result.checks,0);equal(result.randomCalls,0);equal(result.critical,false);same(rng:snapshot(),before)
    end)
    test("Modified rate automatic capture skips checks and RNG",function()
        local rng=RulesRNG.new(42);local before=rng:snapshot()
        local result=assert(Capture.attempt(context("rattata",1,20,"sleep"),"ultraBall",151,rng))
        equal(result.guarantee,"modified-rate");equal(result.modifiedRate4096,1044480)
        equal(result.caught,true);equal(result.checks,0);same(rng:snapshot(),before)
    end)
    test("RNG exhaustion after critical trial rolls back entire attempt",function()
        local ctx=context("rattata",20,20)
        local rng=RulesRNG.new(42);local before=rng:snapshot();before.rolls=2147483646;rng:restore(before)
        local result,problem=Capture.attempt(ctx,"pokeBall",30,rng)
        equal(result,nil);equal(problem,"rng-exhausted");same(rng:snapshot(),before)
        equal(ctx.pokemon.hp,20)
    end)
    test("Malformed RNG is rejected without target mutation",function()
        local ctx=context();local hp=ctx.pokemon.hp
        local result,problem=Capture.attempt(ctx,"pokeBall",0,{})
        equal(result,nil);equal(problem,"invalid-rng");equal(ctx.pokemon.hp,hp)
    end)
    test("Native float integer inputs normalize with identical results",function()
        local a,b=context("rattata",20,20),context("rattata",20.0,20.0)
        local r1,r2=RulesRNG.new(42),RulesRNG.new(42)
        local first=assert(Capture.attempt(a,"pokeBall",31,r1))
        local second=assert(Capture.attempt(b,"pokeBall",31.0,r2))
        for _,key in ipairs({"modifiedRate4096","shakeThreshold","criticalThreshold","checks","caught","critical"}) do equal(second[key],first[key],key) end
        same(r1:snapshot(),r2:snapshot())
    end)
    test("Capturing never mutates target HP status learned moves PP or identity",function()
        local ctx=context("pikachu",1,30,"sleep");local p=ctx.pokemon
        local pp,moves=p.pp,p.moves;local xp=p.xp
        assert(Capture.attempt(ctx,"ultraBall",151,RulesRNG.new(1)))
        equal(ctx.pokemon,p);equal(p.hp,1);equal(p.maxHP,30);equal(p.status,"sleep");equal(p.statusTurns,2)
        equal(p.pp,pp);equal(p.moves,moves);equal(p.xp,xp)
    end)
    test("Cosmetic random cadence cannot change injected rules replay",function()
        local ctx=context("pikachu",1,30);local r1,r2=RulesRNG.new(42),RulesRNG.new(42)
        local first=assert(Capture.attempt(ctx,"pokeBall",31,r1))
        for _=1,100 do math.random() end
        local second=assert(Capture.attempt(ctx,"pokeBall",31,r2))
        equal(second.caught,first.caught);equal(second.critical,first.critical);equal(second.checks,first.checks)
        same(r1:snapshot(),r2:snapshot())
    end)
    test("Active global RNG facade and explicit streams share replay semantics",function()
        RulesRNG.seed(42)
        local ctx=context("rattata",20,20);local rng=RulesRNG.new(42)
        local first=assert(Capture.attempt(ctx,"pokeBall",31,RulesRNG))
        local second=assert(Capture.attempt(ctx,"pokeBall",31,rng))
        equal(first.caught,second.caught);equal(first.checks,second.checks);same(RulesRNG.snapshot(),rng:snapshot())
    end)
    test("64 independent Decimal and primary calculator Q12 vectors",function()
        local vectors={
            {species="rattata",hp=20,maximum=20,status=nil,ball="pokeBall",count=30,modifiedRate4096=348160,shakeThreshold=49802,criticalThreshold=0},
            {species="mewtwo",hp=20,maximum=20,status=nil,ball="pokeBall",count=151,modifiedRate4096=4096,shakeThreshold=16400,criticalThreshold=0},
            {species="pikachu",hp=1,maximum=137,status="sleep",ball="greatBall",count=31,modifiedRate4096=1044480,shakeThreshold=65536,criticalThreshold=0},
            {species="chansey",hp=101,maximum=201,status="paralyze",ball="ultraBall",count=151,modifiedRate4096=245148,shakeThreshold=45613,criticalThreshold=9},
            {species="bulbasaur",hp=21,maximum=22,status=nil,ball="greatBall",count=150,modifiedRate4096=100538,shakeThreshold=36501,criticalThreshold=2},
            {species="magikarp",hp=1,maximum=20,status="freeze",ball="ultraBall",count=151,modifiedRate4096=1044480,shakeThreshold=65536,criticalThreshold=0},
            {species="kabuto",hp=7629,maximum=63831,status="burn",ball="greatBall",count=30,modifiedRate4096=381675,shakeThreshold=50955,criticalThreshold=0},
            {species="sandslash",hp=4561,maximum=9442,status="sleep",ball="greatBall",count=0,modifiedRate4096=937215,shakeThreshold=63791,criticalThreshold=0},
            {species="golduck",hp=16075,maximum=52158,status="burn",ball="greatBall",count=150,modifiedRate4096=549182,shakeThreshold=55807,criticalThreshold=11},
            {species="nidorino",hp=17941,maximum=35416,status="sleep",ball="pokeBall",count=0,modifiedRate4096=813810,shakeThreshold=61567,criticalThreshold=0},
            {species="moltres",hp=1814,maximum=4282,status="paralyze",ball="pokeBall",count=31,modifiedRate4096=13226,shakeThreshold=21984,criticalThreshold=0},
            {species="sandshrew",hp=18970,maximum=36814,status=nil,ball="ultraBall",count=30,modifiedRate4096=1044480,shakeThreshold=65536,criticalThreshold=0},
            {species="magikarp",hp=9232,maximum=18584,status=nil,ball="greatBall",count=31,modifiedRate4096=1044480,shakeThreshold=65536,criticalThreshold=0},
            {species="oddish",hp=9491,maximum=19538,status=nil,ball="greatBall",count=150,modifiedRate4096=1044480,shakeThreshold=65536,criticalThreshold=0},
            {species="sandshrew",hp=6491,maximum=23466,status="poison",ball="pokeBall",count=31,modifiedRate4096=1044480,shakeThreshold=65536,criticalThreshold=0},
            {species="raichu",hp=8387,maximum=14926,status="poison",ball="greatBall",count=151,modifiedRate4096=432273,shakeThreshold=52562,criticalThreshold=17},
            {species="pinsir",hp=15307,maximum=31576,status="paralyze",ball="pokeBall",count=31,modifiedRate4096=187127,shakeThreshold=42635,criticalThreshold=3},
            {species="voltorb",hp=35966,maximum=49129,status="burn",ball="pokeBall",count=151,modifiedRate4096=597632,shakeThreshold=56992,criticalThreshold=24},
            {species="lapras",hp=3845,maximum=53557,status="freeze",ball="greatBall",count=150,modifiedRate4096=658118,shakeThreshold=58393,criticalThreshold=13},
            {species="onix",hp=8239,maximum=13131,status="freeze",ball="pokeBall",count=150,modifiedRate4096=268048,shakeThreshold=46643,criticalThreshold=5},
            {species="ninetales",hp=50063,maximum=60196,status="sleep",ball="ultraBall",count=31,modifiedRate4096=684373,shakeThreshold=58957,criticalThreshold=13},
            {species="primeape",hp=19407,maximum=33951,status=nil,ball="ultraBall",count=31,modifiedRate4096=380265,shakeThreshold=50907,criticalThreshold=7},
            {species="golem",hp=4366,maximum=8961,status=nil,ball="greatBall",count=151,modifiedRate4096=186675,shakeThreshold=42608,criticalThreshold=7},
            {species="machamp",hp=20048,maximum=54916,status="poison",ball="pokeBall",count=0,modifiedRate4096=209190,shakeThreshold=43840,criticalThreshold=0},
            {species="haunter",hp=16520,maximum=17512,status="burn",ball="pokeBall",count=31,modifiedRate4096=205202,shakeThreshold=43633,criticalThreshold=4},
            {species="venusaur",hp=5708,maximum=29721,status=nil,ball="pokeBall",count=151,modifiedRate4096=160720,shakeThreshold=41045,criticalThreshold=6},
            {species="poliwag",hp=27494,maximum=43094,status="freeze",ball="pokeBall",count=31,modifiedRate4096=1044480,shakeThreshold=65536,criticalThreshold=0},
            {species="raticate",hp=10122,maximum=17338,status="sleep",ball="greatBall",count=151,modifiedRate4096=1044480,shakeThreshold=65536,criticalThreshold=0},
            {species="nidoranF",hp=232,maximum=664,status="burn",ball="pokeBall",count=31,modifiedRate4096=1044480,shakeThreshold=65536,criticalThreshold=0},
            {species="magneton",hp=23464,maximum=35862,status=nil,ball="ultraBall",count=0,modifiedRate4096=277123,shakeThreshold=47036,criticalThreshold=0},
            {species="poliwrath",hp=4077,maximum=20663,status="sleep",ball="pokeBall",count=31,modifiedRate4096=400185,shakeThreshold=51562,criticalThreshold=8},
            {species="cubone",hp=20325,maximum=30193,status="sleep",ball="ultraBall",count=30,modifiedRate4096=1044480,shakeThreshold=65536,criticalThreshold=0},
            {species="rapidash",hp=30102,maximum=38553,status="poison",ball="ultraBall",count=0,modifiedRate4096=353504,shakeThreshold=49987,criticalThreshold=0},
            {species="machamp",hp=28238,maximum=54035,status="freeze",ball="ultraBall",count=150,modifiedRate4096=600520,shakeThreshold=57065,criticalThreshold=12},
            {species="pikachu",hp=41975,maximum=51771,status=nil,ball="ultraBall",count=31,modifiedRate4096=715169,shakeThreshold=59612,criticalThreshold=14},
            {species="staryu",hp=55502,maximum=55796,status="paralyze",ball="greatBall",count=30,modifiedRate4096=698484,shakeThreshold=59257,criticalThreshold=0},
            {species="mewtwo",hp=38657,maximum=57079,status=nil,ball="ultraBall",count=31,modifiedRate4096=13479,shakeThreshold=22087,criticalThreshold=0},
            {species="golem",hp=43473,maximum=57019,status="poison",ball="pokeBall",count=0,modifiedRate4096=135948,shakeThreshold=39365,criticalThreshold=0},
            {species="rhyhorn",hp=7902,maximum=14515,status=nil,ball="pokeBall",count=0,modifiedRate4096=313130,shakeThreshold=48489,criticalThreshold=0},
            {species="fearow",hp=11946,maximum=32752,status="freeze",ball="pokeBall",count=31,modifiedRate4096=697503,shakeThreshold=59244,criticalThreshold=14},
            {species="exeggutor",hp=27365,maximum=59011,status="sleep",ball="pokeBall",count=31,modifiedRate4096=318343,shakeThreshold=48691,criticalThreshold=6},
            {species="drowzee",hp=4024,maximum=60666,status="freeze",ball="greatBall",count=151,modifiedRate4096=1044480,shakeThreshold=65536,criticalThreshold=0},
            {species="jolteon",hp=598,maximum=7006,status="burn",ball="greatBall",count=30,modifiedRate4096=391121,shakeThreshold=51267,criticalThreshold=0},
            {species="onix",hp=51031,maximum=64543,status="freeze",ball="greatBall",count=31,modifiedRate4096=326868,shakeThreshold=49020,criticalThreshold=6},
            {species="nidoqueen",hp=52843,maximum=53909,status="freeze",ball="ultraBall",count=30,modifiedRate4096=319348,shakeThreshold=48735,criticalThreshold=0},
            {species="gastly",hp=2453,maximum=31695,status="freeze",ball="greatBall",count=31,modifiedRate4096=1044480,shakeThreshold=65536,criticalThreshold=0},
            {species="meowth",hp=9928,maximum=12434,status="sleep",ball="pokeBall",count=151,modifiedRate4096=1044480,shakeThreshold=65536,criticalThreshold=0},
            {species="muk",hp=10315,maximum=25513,status="sleep",ball="pokeBall",count=150,modifiedRate4096=560995,shakeThreshold=56099,criticalThreshold=11},
            {species="magikarp",hp=28691,maximum=61792,status="sleep",ball="pokeBall",count=31,modifiedRate4096=1044480,shakeThreshold=65536,criticalThreshold=0},
            {species="goldeen",hp=20790,maximum=41302,status="freeze",ball="pokeBall",count=0,modifiedRate4096=1044480,shakeThreshold=65536,criticalThreshold=0},
            {species="pidgeotto",hp=5128,maximum=27628,status="paralyze",ball="ultraBall",count=0,modifiedRate4096=1044480,shakeThreshold=65536,criticalThreshold=0},
            {species="tangela",hp=6493,maximum=51395,status="poison",ball="ultraBall",count=31,modifiedRate4096=506387,shakeThreshold=54693,criticalThreshold=10},
            {species="electabuzz",hp=3861,maximum=28492,status="paralyze",ball="greatBall",count=30,modifiedRate4096=377253,shakeThreshold=50811,criticalThreshold=0},
            {species="tauros",hp=4522,maximum=22523,status="poison",ball="ultraBall",count=151,modifiedRate4096=478947,shakeThreshold=53924,criticalThreshold=19},
            {species="machamp",hp=9102,maximum=31653,status="paralyze",ball="pokeBall",count=30,modifiedRate4096=223478,shakeThreshold=44575,criticalThreshold=0},
            {species="magnemite",hp=47560,maximum=56151,status="sleep",ball="greatBall",count=31,modifiedRate4096=1044480,shakeThreshold=65536,criticalThreshold=0},
            {species="rhyhorn",hp=1679,maximum=3019,status=nil,ball="greatBall",count=30,modifiedRate4096=463923,shakeThreshold=53505,criticalThreshold=0},
            {species="scyther",hp=2,maximum=5,status="paralyze",ball="pokeBall",count=31,modifiedRate4096=202752,shakeThreshold=43499,criticalThreshold=4},
            {species="zubat",hp=2827,maximum=53252,status="sleep",ball="greatBall",count=31,modifiedRate4096=1044480,shakeThreshold=65536,criticalThreshold=0},
            {species="omanyte",hp=2407,maximum=15347,status="freeze",ball="pokeBall",count=0,modifiedRate4096=412618,shakeThreshold=51951,criticalThreshold=0},
            {species="omanyte",hp=28012,maximum=51820,status="sleep",ball="ultraBall",count=30,modifiedRate4096=589478,shakeThreshold=56799,criticalThreshold=0},
            {species="nidoking",hp=38624,maximum=41980,status="burn",ball="pokeBall",count=0,modifiedRate4096=106895,shakeThreshold=37066,criticalThreshold=0},
            {species="rapidash",hp=31258,maximum=53563,status="burn",ball="ultraBall",count=0,modifiedRate4096=450441,shakeThreshold=53113,criticalThreshold=0},
            {species="zubat",hp=15098,maximum=54312,status=nil,ball="greatBall",count=151,modifiedRate4096=1044480,shakeThreshold=65536,criticalThreshold=0},
        }
        for i,v in ipairs(vectors) do
            local p=assert(Capture.parameters(context(v.species,v.hp,v.maximum,v.status),v.ball,v.count))
            for _,key in ipairs({"modifiedRate4096","shakeThreshold","criticalThreshold"}) do equal(p[key],v[key],"Q12 vector" .. i .. " " .. key) end
        end
    end)
    test("25 literal seeded replays including exact shake and critical threshold boundaries",function()
        local vectors={
            {species="rattata",hp=20,maximum=20,status=nil,ball="pokeBall",count=30,seed=1,caught=true,critical=false,checks=3,displayShakes=3,rngRolls=4,state=984943658,criticalRoll=166,shakeRolls={15088,44248,3113}},
            {species="rattata",hp=20,maximum=20,status=nil,ball="pokeBall",count=30,seed=42,caught=false,critical=false,checks=3,displayShakes=3,rngRolls=4,state=565444343,criticalRoll=101,shakeRolls={43918,23480,65270}},
            {species="rattata",hp=20,maximum=20,status=nil,ball="pokeBall",count=30,seed=525,caught=false,critical=false,checks=1,displayShakes=0,rngRolls=2,state=123134082,criticalRoll=122,shakeRolls={57473}},
            {species="rattata",hp=20,maximum=20,status=nil,ball="pokeBall",count=30,seed=7777,caught=true,critical=false,checks=3,displayShakes=3,rngRolls=4,state=1980143064,criticalRoll=70,shakeRolls={38734,812,38359}},
            {species="mewtwo",hp=20,maximum=20,status=nil,ball="pokeBall",count=151,seed=1,caught=false,critical=false,checks=2,displayShakes=1,rngRolls=3,state=1622650073,criticalRoll=166,shakeRolls={15088,44248}},
            {species="mewtwo",hp=20,maximum=20,status=nil,ball="pokeBall",count=151,seed=42,caught=false,critical=false,checks=1,displayShakes=0,rngRolls=2,state=1126542223,criticalRoll=101,shakeRolls={43918}},
            {species="mewtwo",hp=20,maximum=20,status=nil,ball="pokeBall",count=151,seed=525,caught=false,critical=false,checks=1,displayShakes=0,rngRolls=2,state=123134082,criticalRoll=122,shakeRolls={57473}},
            {species="mewtwo",hp=20,maximum=20,status=nil,ball="pokeBall",count=151,seed=7777,caught=false,critical=false,checks=1,displayShakes=0,rngRolls=2,state=2081724239,criticalRoll=70,shakeRolls={38734}},
            {species="pikachu",hp=1,maximum=137,status="sleep",ball="greatBall",count=31,seed=1,caught=true,critical=false,checks=0,displayShakes=3,rngRolls=0,state=1,criticalRoll=nil,shakeRolls={}},
            {species="pikachu",hp=1,maximum=137,status="sleep",ball="greatBall",count=31,seed=42,caught=true,critical=false,checks=0,displayShakes=3,rngRolls=0,state=42,criticalRoll=nil,shakeRolls={}},
            {species="pikachu",hp=1,maximum=137,status="sleep",ball="greatBall",count=31,seed=525,caught=true,critical=false,checks=0,displayShakes=3,rngRolls=0,state=525,criticalRoll=nil,shakeRolls={}},
            {species="pikachu",hp=1,maximum=137,status="sleep",ball="greatBall",count=31,seed=7777,caught=true,critical=false,checks=0,displayShakes=3,rngRolls=0,state=7777,criticalRoll=nil,shakeRolls={}},
            {species="chansey",hp=101,maximum=201,status="paralyze",ball="ultraBall",count=151,seed=1,caught=true,critical=false,checks=3,displayShakes=3,rngRolls=4,state=984943658,criticalRoll=166,shakeRolls={15088,44248,3113}},
            {species="chansey",hp=101,maximum=201,status="paralyze",ball="ultraBall",count=151,seed=42,caught=false,critical=false,checks=3,displayShakes=3,rngRolls=4,state=565444343,criticalRoll=101,shakeRolls={43918,23480,65270}},
            {species="chansey",hp=101,maximum=201,status="paralyze",ball="ultraBall",count=151,seed=525,caught=false,critical=false,checks=1,displayShakes=0,rngRolls=2,state=123134082,criticalRoll=122,shakeRolls={57473}},
            {species="chansey",hp=101,maximum=201,status="paralyze",ball="ultraBall",count=151,seed=7777,caught=true,critical=false,checks=3,displayShakes=3,rngRolls=4,state=1980143064,criticalRoll=70,shakeRolls={38734,812,38359}},
            {species="bulbasaur",hp=21,maximum=22,status=nil,ball="greatBall",count=150,seed=1,caught=false,critical=false,checks=2,displayShakes=1,rngRolls=3,state=1622650073,criticalRoll=166,shakeRolls={15088,44248}},
            {species="bulbasaur",hp=21,maximum=22,status=nil,ball="greatBall",count=150,seed=42,caught=false,critical=false,checks=1,displayShakes=0,rngRolls=2,state=1126542223,criticalRoll=101,shakeRolls={43918}},
            {species="bulbasaur",hp=21,maximum=22,status=nil,ball="greatBall",count=150,seed=525,caught=false,critical=false,checks=1,displayShakes=0,rngRolls=2,state=123134082,criticalRoll=122,shakeRolls={57473}},
            {species="bulbasaur",hp=21,maximum=22,status=nil,ball="greatBall",count=150,seed=7777,caught=false,critical=false,checks=1,displayShakes=0,rngRolls=2,state=2081724239,criticalRoll=70,shakeRolls={38734}},
            {species="rattata",hp=20,maximum=20,status=nil,ball="pokeBall",count=30,seed=15917,caught=true,critical=false,checks=3,displayShakes=3,rngRolls=4,state=717581286,criticalRoll=90,shakeRolls={49801,7966,27621}},
            {species="rattata",hp=20,maximum=20,status=nil,ball="pokeBall",count=30,seed=62594,caught=false,critical=false,checks=1,displayShakes=0,rngRolls=2,state=1022870155,criticalRoll=205,shakeRolls={49802}},
            {species="rattata",hp=20,maximum=20,status=nil,ball="pokeBall",count=31,seed=161,caught=true,critical=true,checks=1,displayShakes=1,rngRolls=2,state=381358502,criticalRoll=6,shakeRolls={4517}},
            {species="rattata",hp=20,maximum=20,status=nil,ball="pokeBall",count=31,seed=184,caught=true,critical=false,checks=3,displayShakes=3,rngRolls=4,state=841006724,criticalRoll=7,shakeRolls={23887,15490,48771}},
            {species="rattata",hp=20,maximum=20,status=nil,ball="pokeBall",count=31,seed=69,caught=false,critical=true,checks=1,displayShakes=1,rngRolls=2,state=163439358,criticalRoll=2,shakeRolls={58109}},
        }
        for i,v in ipairs(vectors) do
            local rng=RulesRNG.new(v.seed)
            local result=assert(Capture.attempt(context(v.species,v.hp,v.maximum,v.status),v.ball,v.count,rng))
            for _,key in ipairs({"caught","critical","checks","displayShakes","rngRolls","criticalRoll"}) do equal(result[key],v[key],"replay" .. i .. " " .. key) end
            equal(rng:snapshot().state,v.state,"replay" .. i .. " final RNG")
            equal(#result.shakeRolls,#v.shakeRolls)
            for j,roll in ipairs(v.shakeRolls) do equal(result.shakeRolls[j],roll,"shake" .. j) end
        end
    end)
    RulesRNG.restore(originalRNG)
    return report
end
