-- Three exposed charge/rampage moves through production SDK battle lifecycle.
ChargeLockContracts={}
local function eq(a,b,label)assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a))end
local function sameRNG(before)local now=RulesRNG.snapshot();eq(now.state,before.state,"RNG state");eq(now.rolls,before.rolls,"RNG rolls")end
local function own(p,keys)p.moves,p.pp={},{};for _,key in ipairs(keys)do p.moves[#p.moves+1]=key;p.pp[key]=moveData[key].pp end end
local function settle(b)
    local lines,n={},0
    while b:phase()=="script"do n=n+1;assert(n<300,"stuck script: "..tostring(b.message));assert(not b.pendingLearning,"unexpected learning")
        lines[#lines+1]=b.message;b.machine:get("script"):advance()
    end
    return table.concat(lines,"|")
end
local function fresh(key,p,e)
    local b=Battle(p or Pokemon("venusaur",100),e or Pokemon("snorlax",100));settle(b);own(b.player,{key});own(b.enemy,{"harden"});return b
end
local function auto(b)eq(b:phase(),"command");b:update();eq(b:phase(),"script");return settle(b)end
local function findSeed(fn)for i=1,10000 do if fn(RulesRNG.new(i))then return i end end;error("no bounded seed")end
local function missSeed()return findSeed(function(r)r:random(1,1);return r:random(1,100)>33 end)end
local function startRampage(total)
    local b=fresh("petalDance");RulesRNG.seed(total==2 and 2 or 1);assert(b:selectMove(1));settle(b)
    eq(b:getConditionsSnapshot().player.rampage_total,total);eq(b:getConditionsSnapshot().player.rampage_remaining,total-1);return b
end
function ChargeLockContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}};local saved=RulesRNG.snapshot();local prior=GameSession.activeRNGSession();local contexts={}
    local function test(name,fn)
        Autopilot.resetControls();local ok,why=pcall(fn);Autopilot.resetControls();report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(why)or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("Exact three rule fields retain GenV scalars/targets/contact",function()
        eq(moveData.solarBeam.chargeRule,"solarBeam");eq(moveData.solarBeam.power,120);eq(moveData.solarBeam.pp,10);eq(moveData.solarBeam.sandWeakened,true)
        eq(moveData.skullBash.chargeRule,"skullBash");eq(moveData.skullBash.power,100);eq(moveData.skullBash.pp,15);eq(moveData.skullBash.contact,true)
        eq(moveData.petalDance.lockRule,"rampage");eq(moveData.petalDance.power,120);eq(moveData.petalDance.targetId,8);eq(moveData.petalDance.contact,true)
    end)
    test("Solar Beam charge then ordinary release123 spends once and only release samples damage",function()
        local b=fresh("solarBeam");RulesRNG.seed(2);assert(b:selectMove(1));settle(b)
        eq(b:getConditionsSnapshot().player.charge_key,"solarBeam");eq(b.enemy.hp,430);eq(b.player.pp.solarBeam,9);eq(RulesRNG.snapshot().rolls,1)
        auto(b);eq(b:getConditionsSnapshot().player.charge_key,"");eq(b.enemy.hp,307);eq(b.player.pp.solarBeam,9);eq(RulesRNG.snapshot().rolls,5)
    end)
    test("Skull Bash initial Defense+1 protects same turn and is not repeated on release",function()
        local b=fresh("skullBash",Pokemon("squirtle",100),Pokemon("rattata",100));own(b.enemy,{"tackle"});b.player.statStages.spe=2;RulesRNG.seed(2)
        assert(b:selectMove(1));settle(b);eq(b.player.statStages.def,1);eq(b.player.hp,165);eq(b.player.pp.skullBash,14);eq(b.enemy.hp,170)
        auto(b);eq(b.player.statStages.def,1);eq(b.enemy.hp,59);eq(b.player.hp,126);eq(b.player.pp.skullBash,14);eq(RulesRNG.snapshot().rolls,11)
    end)
    test("Skull Bash at Defense cap still charges without duplicate effect",function()
        local b=fresh("skullBash");b.player.statStages.def=6;RulesRNG.seed(2);assert(b:selectMove(1));settle(b)
        eq(b.player.statStages.def,6);eq(b:getConditionsSnapshot().player.charge_key,"skullBash");eq(b.player.pp.skullBash,14)
    end)
    test("Charge begins against Ghost; Normal Skull release immunity spends no accuracy RNG",function()
        local b=fresh("skullBash",nil,Pokemon("gastly",100));RulesRNG.seed(2);assert(b:selectMove(1));settle(b)
        eq(b.player.statStages.def,1);eq(b:getConditionsSnapshot().player.charge_key,"skullBash");local hp=b.enemy.hp
        -- Venusaur100 and Gastly100 both have165 Speed: one actual tie draw
        -- per round, in addition to each enemy AI choice. Neither release
        -- immunity nor charging samples accuracy/critical/variance.
        eq(b:effectiveSpeed(b.player),165);eq(b:effectiveSpeed(b.enemy),165);eq(RulesRNG.snapshot().rolls,2);eq(RulesRNG.snapshot().state,564950498)
        local text=auto(b);assert(text:find("doesn't affect",1,true));eq(b.enemy.hp,hp);eq(b.player.pp.skullBash,14);eq(RulesRNG.snapshot().rolls,4);eq(RulesRNG.snapshot().state,1969887316);eq(b.conditions:lockedKey(b.player),nil)
    end)
    test("Ghost Skull immunity with explicit unequal Speed needs only two enemy AI draws",function()
        local b=fresh("skullBash",nil,Pokemon("gastly",100));b.player.statStages.spe=1
        assert(b:effectiveSpeed(b.player)>b:effectiveSpeed(b.enemy));RulesRNG.seed(2);assert(b:selectMove(1));settle(b);eq(RulesRNG.snapshot().rolls,1);eq(RulesRNG.snapshot().state,33614)
        local hp=b.enemy.hp;local text=auto(b);assert(text:find("doesn't affect",1,true));eq(b.enemy.hp,hp);eq(b.player.pp.skullBash,14);eq(RulesRNG.snapshot().rolls,2);eq(RulesRNG.snapshot().state,564950498);eq(b.conditions:lockedKey(b.player),nil)
    end)
    test("Missed release clears charge with only enemy choice and accuracy draws",function()
        local b=fresh("solarBeam");RulesRNG.seed(2);assert(b:selectMove(1));settle(b)
        b.player.statStages.acc=-6;b.enemy.statStages.eva=6;RulesRNG.seed(missSeed());local hp=b.enemy.hp;local text=auto(b)
        assert(text:find("attack missed",1,true));eq(b.enemy.hp,hp);eq(b.conditions:lockedKey(b.player),nil);eq(b.player.pp.solarBeam,9);eq(RulesRNG.snapshot().rolls,2)
    end)
    test("Solar policy literal GenV Sun skip/full and RainSandHail half is pure",function()
        local before=RulesRNG.snapshot()
        for _,v in ipairs({{"none",false,4096},{"sunnyday",true,4096},{"raindance",false,2048},{"sandstorm",false,2048},{"hail",false,2048}})do
            local skip,ratio=BattleEffects.solarPolicy(v[1]);eq(skip,v[2]);eq(ratio,v[3])
        end
        eq(pcall(BattleEffects.solarPolicy,"snowscape"),false);eq(pcall(BattleEffects.solarPolicy,"desolateland"),false);sameRNG(before)
    end)
    test("Controlled Sun query seam skips charge with full power; no Sun producer is created",function()
        local b=fresh("solarBeam");b.effects.weatherId=function()return "sunnyday"end;eq(b.effects.weather,nil)
        RulesRNG.seed(2);assert(b:selectMove(1));settle(b);eq(b.conditions:lockedKey(b.player),nil);eq(b.enemy.hp,309);eq(b.player.pp.solarBeam,9);eq(RulesRNG.snapshot().rolls,4)
        eq(b.effects.weather,nil)
    end)
    test("Actual supported Sandstorm producer halves Solar power at release",function()
        local b=fresh("solarBeam");own(b.enemy,{"sandstorm"});RulesRNG.seed(2);assert(b:selectMove(1));settle(b)
        eq(b.effects:weatherId(),"sandstorm");eq(b:effectiveMovePower(moveData.solarBeam,b.player,b.enemy),60)
        auto(b);eq(b.enemy.hp,317);eq(b.player.hp,238);eq(b.effects:snapshot().turns,3);eq(RulesRNG.snapshot().rolls,5)
    end)
    test("Weather expiring while charging changes release back to full power",function()
        local b=fresh("solarBeam");own(b.player,{"harden","solarBeam"});own(b.enemy,{"sandstorm"})
        RulesRNG.seed(2);assert(b:selectMove(1));settle(b);own(b.enemy,{"harden"})
        for _=1,3 do assert(b:selectMove(1));settle(b)end;eq(b.effects:snapshot().turns,1);local hp=b.enemy.hp
        RulesRNG.seed(2);assert(b:selectMove(2));settle(b);eq(b.effects:weatherId(),"none");auto(b)
        eq(hp-b.enemy.hp,123);eq(b.player.pp.solarBeam,9);eq(RulesRNG.snapshot().rolls,5)
    end)
    test("Sleep aborts stored charge with no extra PP but keeps Skull Defense stage",function()
        local b=fresh("skullBash");assert(b:selectMove(1));settle(b);b.player.status,b.player.statusTurns,b.player.sleepDuration="sleep",1,1
        RulesRNG.seed(2);auto(b);eq(b.conditions:lockedKey(b.player),nil);eq(b.player.pp.skullBash,14);eq(b.player.statStages.def,1);eq(RulesRNG.snapshot().rolls,1)
    end)
    test("Full paralysis/freeze/flinch abort charge before release accuracy",function()
        for _,kind in ipairs({"paralyze","freeze","flinch"})do
            local b=fresh("solarBeam");assert(b:selectMove(1));settle(b)
            if kind=="flinch"then b.player.flinched=true;RulesRNG.seed(2)
            else b.player.status=kind;RulesRNG.seed(findSeed(function(r)r:random(1,1);local n=r:random(1,100);return kind=="paralyze"and n<=25 or kind=="freeze"and n>20 end))end
            auto(b);eq(b.conditions:lockedKey(b.player),nil);eq(b.enemy.hp,430);eq(b.player.pp.solarBeam,9);eq(RulesRNG.snapshot().rolls,kind=="flinch"and 1 or 2)
        end
    end)
    test("Interrupted initial charge doesn't create a lock, boost or consume first PP",function()
        local b=fresh("skullBash");b.player.flinched=true;RulesRNG.seed(2);assert(b:selectMove(1));settle(b)
        eq(b.conditions:lockedKey(b.player),nil);eq(b.player.statStages.def,0);eq(b.player.pp.skullBash,15);eq(RulesRNG.snapshot().rolls,1)
    end)
    test("Enemy charge continuation uses stored identity and no new AI/PP draw",function()
        local b=fresh("harden");own(b.enemy,{"solarBeam"});b.enemy.pp.solarBeam=1;RulesRNG.seed(2)
        assert(b:selectMove(1));settle(b);eq(b:getConditionsSnapshot().enemy.charge_key,"solarBeam");eq(b.enemy.pp.solarBeam,0);eq(RulesRNG.snapshot().rolls,1)
        assert(b:selectMove(1));settle(b);eq(b.conditions:lockedKey(b.enemy),nil);eq(b.enemy.pp.solarBeam,0);eq(RulesRNG.snapshot().rolls,4)
    end)
    test("Last PP charge continues; alternate/forged slots/run/selection reject unchanged",function()
        local b=fresh("solarBeam");own(b.player,{"solarBeam","tackle"});b.player.pp.solarBeam=1;assert(b:selectMove(1));settle(b);local before=RulesRNG.snapshot()
        for _,i in ipairs({0,2,-1,99,"solarBeam",{key="solarBeam"}})do eq(b:selectMove(i),false)end
        eq(b:tryRun(),false);eq(b:beginSelection("party"),false);eq(b:beginSelection("bag"),false);eq(b:needsStruggle(),false);sameRNG(before)
        auto(b);eq(b.player.pp.solarBeam,0);eq(b.conditions:lockedKey(b.player),nil)
    end)
    test("Petal Dance literal duration2 ends with fatigue3 after121+126 damage",function()
        local b=startRampage(2);eq(b.enemy.hp,309);eq(b.player.pp.petalDance,9);eq(RulesRNG.snapshot().rolls,5)
        auto(b);eq(b.enemy.hp,183);eq(b.player.confusion,3);eq(b.conditions:lockedKey(b.player),nil);eq(b.player.pp.petalDance,9);eq(RulesRNG.snapshot().rolls,10)
    end)
    test("Petal Dance duration3 continues three actual attacks with one PP attempt",function()
        local b=startRampage(3);auto(b);eq(b:getConditionsSnapshot().player.rampage_remaining,1);eq(b.player.confusion,nil)
        auto(b);eq(b.conditions:lockedKey(b.player),nil);assert(b.player.confusion and b.player.confusion>=1 and b.player.confusion<=4);eq(b.player.pp.petalDance,9)
    end)
    test("First Petal Dance miss has no duration draw or lingering lock",function()
        local b=fresh("petalDance");b.player.statStages.acc=-6;b.enemy.statStages.eva=6;RulesRNG.seed(missSeed());assert(b:selectMove(1));settle(b)
        eq(b.enemy.hp,430);eq(b.conditions:lockedKey(b.player),nil);eq(b.player.confusion,nil);eq(b.player.pp.petalDance,9);eq(RulesRNG.snapshot().rolls,2)
    end)
    test("Final-turn Petal miss fatigues, early miss calmly cancels, matching actual PS",function()
        for _,total in ipairs({2,3})do
            local b=startRampage(total);b.player.statStages.acc=-6;b.enemy.statStages.eva=6;local hp=b.enemy.hp;RulesRNG.seed(missSeed());auto(b)
            eq(b.enemy.hp,hp);eq(b.conditions:lockedKey(b.player),nil);eq(b.player.pp.petalDance,9)
            if total==2 then assert(b.player.confusion);eq(RulesRNG.snapshot().rolls,3)else eq(b.player.confusion,nil);eq(RulesRNG.snapshot().rolls,2)end
        end
    end)
    test("Final/early flinch or sleep distinguish fatigue at residual without extra PP",function()
        for _,kind in ipairs({"flinch","sleep"})do for _,total in ipairs({2,3})do
            local b=startRampage(total)
            if kind=="flinch"then b.player.flinched=true else b.player.status,b.player.statusTurns,b.player.sleepDuration="sleep",1,1 end
            RulesRNG.seed(2);auto(b);eq(b.conditions:lockedKey(b.player),nil);eq(b.player.pp.petalDance,9)
            if total==2 then assert(b.player.confusion);eq(RulesRNG.snapshot().rolls,2)else eq(b.player.confusion,nil);eq(RulesRNG.snapshot().rolls,1)end
        end end
    end)
    test("Final/early full paralysis or freeze match residual fatigue timing",function()
        for _,kind in ipairs({"paralyze","freeze"})do for _,total in ipairs({2,3})do
            local b=startRampage(total);b.player.status=kind
            RulesRNG.seed(findSeed(function(r)r:random(1,1);local n=r:random(1,100);return kind=="paralyze"and n<=25 or kind=="freeze"and n>20 end));auto(b)
            eq(b.conditions:lockedKey(b.player),nil);eq(b.player.pp.petalDance,9)
            if total==2 then assert(b.player.confusion);eq(RulesRNG.snapshot().rolls,3)else eq(b.player.confusion,nil);eq(RulesRNG.snapshot().rolls,2)end
        end end
    end)
    test("Final blocked rampage fatigue is after actual Sand residual cohort",function()
        local b=fresh("petalDance");own(b.enemy,{"sandstorm"});RulesRNG.seed(2);assert(b:selectMove(1));settle(b);b.player.flinched=true;RulesRNG.seed(2)
        local text=auto(b);local weather=text:find("buffeted by the sandstorm",1,true);local confusion=text:find("became confused",1,true)
        assert(weather and confusion and weather<confusion,"weather must precede interrupted fatigue");eq(b.player.hp,238);eq(b.player.confusion~=nil,true);eq(RulesRNG.snapshot().rolls,2)
    end)
    test("Sleep received after successful first Petal hit clears quietly at residual",function()
        local b=fresh("petalDance");own(b.enemy,{"sleepPowder"});RulesRNG.seed(2);assert(b:selectMove(1));local text=settle(b)
        -- AI1, Petal accuracy/crit/variance, duration, enemy accuracy44, sleep3.
        eq(b.player.status,"sleep");eq(b.conditions:lockedKey(b.player),nil);eq(b.player.confusion,nil);eq(b.player.pp.petalDance,9)
        assert(not text:find("became confused",1,true));eq(RulesRNG.snapshot().rolls,7)
    end)
    test("Damage before first Petal action cannot start lock after target selfKO",function()
        local p=Pokemon("venusaur",100);local e,reserve=Pokemon("rattata",100),Pokemon("metapod",100);e.hp=1;own(e,{"takeDown"});own(reserve,{"harden"});own(p,{"petalDance"});p.spe=1
        local enemies=Party();assert(enemies:add(e));assert(enemies:add(reserve));local b=Battle(p,e,"NO TARGET",{enemyParty=enemies});settle(b);RulesRNG.seed(1)
        assert(b:selectMove(1));local text=settle(b);assert(text:find("no target",1,true));eq(b.enemy,reserve);eq(b.conditions:lockedKey(p),nil);eq(p.confusion,nil);eq(p.pp.petalDance,9);eq(RulesRNG.snapshot().rolls,4)
    end)
    test("Public Petal lock rejection preserves state and RNG",function()
        local b=startRampage(2);own(b.player,{"petalDance","tackle"});local before=RulesRNG.snapshot();local remaining=b:getConditionsSnapshot().player.rampage_remaining
        for _,i in ipairs({0,2,99,"petalDance",{key="petalDance"}})do eq(b:selectMove(i),false)end
        eq(b:tryRun(),false);eq(b:beginSelection("bag"),false);eq(b:beginSelection("party"),false);eq(b:getConditionsSnapshot().player.rampage_remaining,remaining);sameRNG(before)
    end)
    test("Scene draws cannot advance charge/rampage; exit/codec have no stored moves",function()
        for _,key in ipairs({"solarBeam","petalDance"})do
            local b=fresh(key);RulesRNG.seed(2);assert(b:selectMove(1));settle(b);local lock=b.conditions:lockedKey(b.player);local before=RulesRNG.snapshot();local pp=b.player.pp[key]
            local scene=BattleScene(b);scene:enter();for _=1,30 do scene:draw();eq(b.conditions:lockedKey(b.player),lock);eq(b.player.pp[key],pp)end;sameRNG(before)
            local data=assert(PokemonCodec.encode(b.player));eq(data.charge,nil);eq(data.rampage,nil);scene:exit();b:clearVolatiles();eq(b.conditions:lockedKey(b.player),nil)
        end
    end)
    test("Pure observer retains zero for status/fixed moves under MudSport without allocation",function()
        local b=fresh("solarBeam");b.conditions:clearAll();b.conditions:of(b.enemy).mudSport=true;b.player.spe=100;b.enemy.spe=100;local before=RulesRNG.snapshot();eq(b.conditions.members[b.player],nil)
        for _,key in ipairs({"thunderWave","endeavor","dragonRage","bide"})do eq(b:effectiveMovePower(moveData[key],b.player,b.enemy),0,key)end
        eq(b.conditions.members[b.player],nil);eq(b:effectiveMovePower(moveData.electroBall,b.player,b.enemy),20);sameRNG(before)
    end)
    test("Charge and rampage faint/forced-switch/withdraw leave no stale lock",function()
        for _,key in ipairs({"solarBeam","petalDance"})do
            local p,q=Pokemon("venusaur",100),Pokemon("pidgey",100);local party=Party();assert(party:add(p));assert(party:add(q))
            local b=Battle(p,Pokemon("snorlax",100),nil,{party=party});settle(b);own(p,{key});own(b.enemy,{"harden"});RulesRNG.seed(2);assert(b:selectMove(1));settle(b);assert(b.conditions:lockedKey(p))
            p.hp=0;b:runScript(function()b:setDirection("enemy");local outcome=b:handleFaint("player");eq(outcome,"replacement");return b:finishRound()end);settle(b);eq(b:phase(),"forcedSwitch");eq(b.conditions:lockedKey(p),nil)
            assert(b:chooseParty(2));settle(b);eq(b.player,q);eq(b.conditions:lockedKey(q),nil);eq(p.hp,0)
        end
    end)
    test("Actual learning forgets Solar Beam during charge without creating a fake durable move",function()
        local g=GameContext();contexts[#contexts+1]=g;local p=Pokemon("bulbasaur",6);assert(g:recruit(p));own(p,{"solarBeam","tackle","growl","vineWhip"})
        assert(g.session:setIntro({stage="done",starter="bulbasaur",rivalStarter="charmander",rivalOutcome=true}));p.xp=p:xpForLevel(7)-1
        local e,reserve=Pokemon("rattata",1),Pokemon("metapod",5);e.hp=1;own(e,{"takeDown"});own(reserve,{"harden"});local enemies=Party();assert(enemies:add(e));assert(enemies:add(reserve))
        g.machine:register("overworld",State("overworld"));g.machine:register("learning",LearningState(g));local owner=BattleState(g);g.machine:register("battle",owner)
        g.machine:change("battle",p,e,{name="CHARGE LEARN",markInteracted=function()end},enemies);local b=owner.battle;settle(b);RulesRNG.seed(1);assert(b:selectMove(1))
        local n=0;while b:phase()=="script"and not b.pendingLearning do n=n+1;assert(n<100);b.machine:get("script"):advance()end
        assert(b.pendingLearning,"actual XP Leech Seed choice");eq(b.conditions:lockedKey(p),"solarBeam");local receipt=b.effects.round;local before=RulesRNG.snapshot()
        assert(owner:openPendingLearning());local l=g.machine:get("learning");l:handleInput();eq(l.phase,"ask");l.menu.onSelect(1);l.menu.onSelect(1);l.menu.onSelect(1)
        eq(p.moves[1],"leechSeed");eq(p.pp.solarBeam,nil);for _=1,10 do g.machine:update();g.machine:draw()end;eq(b.effects.round,receipt);sameRNG(before)
        assert(l.dialog.onComplete)();l:handleInput();settle(b);eq(b.enemy,reserve);auto(b)
        eq(b.conditions:lockedKey(p),nil);eq(p:hasMove("solarBeam"),false);eq(p.moves[1],"leechSeed");eq(p.pp.leechSeed,10);eq(p.pp.solarBeam,nil);eq(#p.moves,4)
    end)
    test("Actual learning forgets Petal Dance during rampage; stored identity attacks replacement once",function()
        local g=GameContext();contexts[#contexts+1]=g;local p=Pokemon("venusaur",38);assert(g:recruit(p));assert(g:recruit(Pokemon("bulbasaur",5)))
        own(p,{"petalDance","razorLeaf","sweetScent","growth"});p.statStages.spa=-6;p.xp=p:xpForLevel(39)-1
        assert(g.session:setIntro({stage="done",starter="bulbasaur",rivalStarter="charmander",rivalOutcome=true}))
        local e,reserve=Pokemon("rattata",40),Pokemon("metapod",40);e.hp=34;own(e,{"takeDown"});own(reserve,{"harden"});local enemies=Party();assert(enemies:add(e));assert(enemies:add(reserve))
        g.machine:register("overworld",State("overworld"));g.machine:register("learning",LearningState(g));local owner=BattleState(g);g.machine:register("battle",owner)
        g.machine:change("battle",p,e,{name="RAMPAGE LEARN",markInteracted=function()end},enemies);local b=owner.battle;settle(b);p.statStages.spa=-6;RulesRNG.seed(2);assert(b:selectMove(1))
        local n=0;while b:phase()=="script"and not b.pendingLearning do n=n+1;assert(n<100);b.machine:get("script"):advance()end
        assert(b.pendingLearning,"actual XP Worry Seed choice");eq(p.level,39);eq(b:getConditionsSnapshot().player.rampage_remaining,1)
        local receipt=b.effects.round;local before=RulesRNG.snapshot();assert(owner:openPendingLearning());local l=g.machine:get("learning");l:handleInput();eq(l.phase,"ask")
        l.menu.onSelect(1);l.menu.onSelect(1);l.menu.onSelect(1);eq(p.moves[1],"worrySeed");eq(p.pp.petalDance,nil)
        for _=1,10 do g.machine:update();g.machine:draw()end;eq(b.effects.round,receipt);sameRNG(before);assert(l.dialog.onComplete)();l:handleInput();settle(b);eq(b.enemy,reserve)
        auto(b);eq(reserve.hp,66);eq(b.conditions:lockedKey(p),nil);assert(p.confusion);eq(p:hasMove("petalDance"),false);eq(p.moves[1],"worrySeed");eq(p.pp.worrySeed,10);eq(#p.moves,4)
    end)
    for _,g in ipairs(contexts)do pcall(function()if g.machine:get("overworld")then g.machine:change("overworld")end end)end
    local current=GameSession.activeRNGSession();if current and current~=prior then assert(current:deactivateRNG())end
    if prior then assert(prior:activateRNG())end
    RulesRNG.restore(saved);return report
end
