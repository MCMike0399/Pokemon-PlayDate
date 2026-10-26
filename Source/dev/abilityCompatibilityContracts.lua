AbilityCompatibilityContracts={}
local function eq(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function mon(species,slot) return Pokemon(species,100,{natureId=0,abilitySlot=slot or "first",heldItem="none"}) end
local function settle(b)
    local messages={};local n=0
    while b:phase()=="script" do n=n+1;assert(n<200);assert(not b.pendingLearning);messages[#messages+1]=b.message;b.machine:get("script"):advance() end
    return table.concat(messages,"|")
end
local function fresh(p,e) local b=Battle(p,e);settle(b);return b end
local function effect(b,fn) b:runScript(fn);return settle(b) end
local function attempt(b,key)
    local p=b.player;p.moves={key};p.pp={[key]=moveData[key].pp}
    b:runScript(function() return b:resolveTurn({side="player",actor=b.player,key=key,move=moveData[key]}) end);return settle(b)
end
local function unchanged(r) local now=RulesRNG.snapshot();eq(now.state,r.state,"RNG state");eq(now.rolls,r.rolls,"RNG rolls") end
local function seed(low,high,value) for i=1,100000 do if RulesRNG.new(i):random(low,high)==value then return i end end;error("no fixture seed") end
function AbilityCompatibilityContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}};local saved=RulesRNG.snapshot()
    local function test(name,fn)
        local ok,why=pcall(fn);report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(why) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("Public Psywave DSL without currentMove retains Psychic immunity and one damage draw",function()
        local p,e=mon("abra"),mon("snorlax");local b=fresh(p,e);b:setDirection("player");eq(b.currentMove,nil)
        RulesRNG.seed(197);local expected=math.max(1,math.floor(RulesRNG.new(197):random(50,150)*p.level/100));local hp=e.hp
        effect(b,function() PsywaveDamage():apply(b) end);eq(hp-e.hp,expected);eq(b.lastDamage,expected);eq(RulesRNG.snapshot().rolls,1)
        e.type="dark";local before=RulesRNG.snapshot();hp=e.hp;effect(b,function() PsywaveDamage():apply(b) end);eq(e.hp,hp);unchanged(before)
    end)
    test("Generic nil-move direct DSL stays type-independent and uses actual HP receipt",function()
        local p,e=mon("abra"),mon("pikachu");local b=fresh(p,e);b:setDirection("player");e.type="ghost"
        local hp=e.hp;local before=RulesRNG.snapshot();effect(b,function() DirectDamage(DEFENDER,20):apply(b) end)
        eq(hp-e.hp,20);eq(b.lastDamage,20);eq(p.status,nil);unchanged(before);eq(b.currentMove,nil)
    end)
    test("Nil-move fixed receipt remains contactfalse fixed cause and Sturdy leaves1HP",function()
        local p,e=mon("abra"),mon("geodude","second");local b=fresh(p,e);e.maxHP,e.hp=28,28
        local receipt=b.effects:hit(p,e,nil,40);eq(receipt.move,nil);eq(receipt.cause,"fixed");eq(receipt.contact,false);eq(receipt.removed,27);eq(e.hp,1)
        local before=RulesRNG.snapshot();effect(b,function() assert(b.effects:afterHit(receipt)) end);unchanged(before)
    end)
    test("Public DirectDamage with absent move still triggers fullHP Sturdy",function()
        local p,e=mon("abra"),mon("geodude","second");local b=fresh(p,e);b:setDirection("player");e.maxHP,e.hp=28,28
        local text=effect(b,function() DirectDamage(DEFENDER,40):apply(b) end);eq(e.hp,1);eq(b.lastDamage,27);assert(text:find("Sturdy",1,true))
    end)
    test("Generated ThunderWave type-immunity flag is exact and generic status has none",function()
        eq(moveData.thunderWave.typeImmunity,true)
        for key,move in pairs(moveData) do if key~="thunderWave" then eq(move.typeImmunity,false,key) end end
    end)
    test("Ground ThunderWave consumes PP at attempt but no accuracy/status/RNG mutation",function()
        local p,e=mon("pikachu"),mon("sandshrew");local b=fresh(p,e);local hp=e.hp;local before=RulesRNG.snapshot()
        local text=attempt(b,"thunderWave");eq(p.pp.thunderWave,moveData.thunderWave.pp-1);eq(e.hp,hp);eq(e.status,nil);unchanged(before);assert(text:find("doesn't affect",1,true))
    end)
    test("Gen5 Electric target receives primary ThunderWave and Ground receives ability paralysis",function()
        local p,e=mon("pikachu"),mon("pikachu");local b=fresh(p,e);RulesRNG.seed(seed(1,100,1));attempt(b,"thunderWave");eq(e.status,"paralyze")
        p,e=mon("sandshrew"),mon("pikachu");b=fresh(p,e);RulesRNG.seed(seed(0,99,29))
        effect(b,function() assert(b.effects:afterHit(b.effects:hit(p,e,moveData.tackle,1))) end);eq(p.status,"paralyze")
    end)
    test("Primary Glare ignores Ghost type immunity rather than blanket status blocking",function()
        local p,e=mon("arbok"),mon("gastly");local b=fresh(p,e);RulesRNG.seed(seed(1,100,1));attempt(b,"glare");eq(e.status,"paralyze")
    end)
    test("Miss-plus-immune contact target resolves immunity first with zero rolls and one PP",function()
        local p,e=mon("rattata"),mon("pikachu");local b=fresh(p,e);e.type="ghost";RulesRNG.seed(seed(1,100,100));local before=RulesRNG.snapshot();local hp=e.hp
        local text=attempt(b,"slam");eq(p.pp.slam,moveData.slam.pp-1);eq(e.hp,hp);eq(p.status,nil);unchanged(before)
        assert(text:find("doesn't affect",1,true));assert(not text:find("missed",1,true))
    end)
    test("Nonimmune missed contact still rolls accuracy once and never damage/contact",function()
        local p,e=mon("rattata"),mon("pikachu");local b=fresh(p,e);RulesRNG.seed(seed(1,100,100));local before=RulesRNG.snapshot().rolls;local hp=e.hp
        local text=attempt(b,"slam");eq(RulesRNG.snapshot().rolls-before,1);eq(e.hp,hp);eq(p.status,nil);assert(text:find("missed",1,true))
    end)
    test("Fixed typed SonicBoom immunity precedes accuracy while direct nil context stays generic",function()
        local p,e=mon("rattata"),mon("gastly");local b=fresh(p,e);RulesRNG.seed(seed(1,100,100));local before=RulesRNG.snapshot();local hp=e.hp
        attempt(b,"sonicBoom");eq(e.hp,hp);eq(p.pp.sonicBoom,moveData.sonicBoom.pp-1);unchanged(before)
        b:setDirection("player");b.currentMove=nil;effect(b,function() DirectDamage(DEFENDER,20):apply(b) end);eq(hp-e.hp,20);unchanged(before)
    end)
    test("Typeless Struggle still bypasses Ghost immunity and never has an accuracy draw",function()
        local p,e=mon("rattata"),mon("gastly");local b=fresh(p,e);local hp=e.hp;RulesRNG.seed(1);local before=RulesRNG.snapshot().rolls
        attempt(b,"struggle");assert(e.hp<hp);eq(RulesRNG.snapshot().rolls-before,2)
    end)
    RulesRNG.restore(saved);return report
end
