-- Actual SDK/domain round paths for six explicitly exposed GenV moves.
BrockMoveBatchContracts={}
local function eq(a,b,label)assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a))end
local function unchanged(before)local now=RulesRNG.snapshot();eq(now.state,before.state,"RNG state");eq(now.rolls,before.rolls,"RNG rolls")end
local function settle(b)
    local messages={};local n=0
    while b:phase()=="script" do
        n=n+1;assert(n<300,"script stuck: "..tostring(b.message));assert(not b.pendingLearning,"unexpected learning")
        messages[#messages+1]=b.message;b.machine:get("script"):advance()
    end
    return table.concat(messages,"|")
end
local function own(p,keys)p.moves={};p.pp={};for _,key in ipairs(keys)do p.moves[#p.moves+1]=key;p.pp[key]=moveData[key].pp end end
local function fresh(p,e)local b=Battle(p or Pokemon("rattata",100),e or Pokemon("rattata",100));settle(b);return b end
local function turn(b,side,key)return {side=side,actor=b[side],key=key,move=moveData[key]}end
local function use(b,key,side)
    local p=side=="enemy"and b.enemy or b.player;own(p,{key})
    b:runScript(function()return b:resolveTurn(turn(b,side or "player",key))end);return settle(b)
end
local function findSeed(predicate)
    for n=1,10000 do if predicate(RulesRNG.new(n))then return n end end;error("bounded seed not found")
end
function BrockMoveBatchContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}};local saved=RulesRNG.snapshot();local priorOwner=GameSession.activeRNGSession();local contexts={}
    local function test(name,fn)
        Autopilot.resetControls();local ok,why=pcall(fn);Autopilot.resetControls()
        report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(why)or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("Generated six-row semantics preserve original GenV scalars",function()
        eq(moveData.electroBall.power,0);eq(moveData.electroBall.powerRule,"electroBall");eq(moveData.electroBall.pp,10)
        eq(moveData.endeavor.power,0);eq(moveData.endeavor.damageRule,"endeavor");eq(moveData.endeavor.contact,true)
        eq(moveData.assurance.power,50);eq(moveData.assurance.powerRule,"assurance")
        eq(moveData.suckerPunch.power,80);eq(moveData.suckerPunch.attemptRule,"suckerPunch");eq(moveData.suckerPunch.priority,1)
        eq(moveData.ragePowder.attemptRule,"singlesRedirect");eq(moveData.ragePowder.priority,3)
    end)
    test("Electro Ball literal Speed-ratio endpoints use40,60,80,120,150 without RNG",function()
        local b=fresh(Pokemon("pikachu",100));b:setDirection("player");b.enemy.spe=100;local before=RulesRNG.snapshot()
        for _,v in ipairs({{1,40},{99,40},{100,60},{199,60},{200,80},{299,80},{300,120},{399,120},{400,150},{1000,150}})do
            b.player.spe=v[1];eq(b:effectiveMovePower(moveData.electroBall,b.player,b.enemy),v[2],"speed"..v[1])
        end
        unchanged(before)
    end)
    test("Electro Ball uses same effective stage/paralysis Speed and minimum1 as order",function()
        local b=fresh(Pokemon("pikachu",100));b:setDirection("player");local p,e=b.player,b.enemy;p.spe,e.spe=100,100
        local before=RulesRNG.snapshot();p.statStages.spe=2;eq(b:effectiveSpeed(p),200);eq(b:effectiveMovePower(moveData.electroBall,b.player,b.enemy),80)
        p.status="paralyze";eq(b:effectiveSpeed(p),50);eq(b:effectiveMovePower(moveData.electroBall,b.player,b.enemy),40)
        p.spe,e.spe=5,5;p.statStages.spe,e.statStages.spe=-6,-6;e.status="paralyze"
        eq(b:effectiveSpeed(p),1);eq(b:effectiveSpeed(e),1);eq(b:effectiveMovePower(moveData.electroBall,b.player,b.enemy),60);unchanged(before)
    end)
    test("Actual Electro Ball traverses scalar0 gate and literal seed2 damage63",function()
        local b=fresh(Pokemon("pikachu",100));b.player.spe,b.enemy.spe=99,100;local hp=b.enemy.hp;RulesRNG.seed(2)
        use(b,"electroBall");eq(hp-b.enemy.hp,63);eq(b.lastDamage,63);eq(b.player.pp.electroBall,9);eq(RulesRNG.snapshot().rolls,3)
    end)
    test("Electro Ball effective power150 still caps actual removed HP",function()
        local b=fresh(Pokemon("pikachu",100));b.player.spe,b.enemy.spe=400,100;RulesRNG.seed(2)
        use(b,"electroBall");eq(b.enemy.hp,0);eq(b.lastDamage,170);eq(RulesRNG.snapshot().rolls,3)
    end)
    test("Electro Ball Ground immunity consumes PP without accuracy/damage RNG",function()
        local b=fresh(Pokemon("pikachu",100),Pokemon("sandshrew",100));local hp=b.enemy.hp;local before=RulesRNG.snapshot()
        local text=use(b,"electroBall");eq(b.enemy.hp,hp);eq(b.player.pp.electroBall,9);assert(text:find("doesn't affect",1,true));unchanged(before)
    end)
    test("Electro Ball missed accuracy samples once without damage or contact",function()
        local b=fresh(Pokemon("pikachu",100));b.player.statStages.acc=-6;b.enemy.statStages.eva=6;local hp=b.enemy.hp
        RulesRNG.seed(findSeed(function(r)return r:random(1,100)>33 end));use(b,"electroBall")
        eq(b.enemy.hp,hp);eq(b.player.pp.electroBall,9);eq(RulesRNG.snapshot().rolls,1)
    end)
    test("Endeavor positive HP difference is fixed50 independent of stages/type resistance/crit",function()
        local b=fresh(Pokemon("rattata",100),Pokemon("geodude",100));b.player.hp,b.enemy.hp=30,80
        b.player.statStages.atk=-6;b.enemy.statStages.def=6;RulesRNG.seed(1)
        use(b,"endeavor");eq(b.enemy.hp,30);eq(b.lastDamage,50);eq(b.player.pp.endeavor,4);eq(RulesRNG.snapshot().rolls,1)
    end)
    test("Endeavor cannot crit/trigger Sturdy when target fullHP because userHPpositive",function()
        local e=Pokemon("geodude",100,{natureId=0,abilitySlot="second",heldItem="none"});local b=fresh(nil,e);b.player.hp=1;RulesRNG.seed(1)
        local text=use(b,"endeavor");eq(e.hp,1);eq(RulesRNG.snapshot().rolls,1);assert(not text:find("Sturdy",1,true));assert(not text:find("critical",1,true))
    end)
    test("Endeavor equal or negative HPdiff fails with PP spent and zero draws",function()
        for _,hp in ipairs({40,41})do local b=fresh();b.player.hp,b.enemy.hp=hp,40;local before=RulesRNG.snapshot()
            local text=use(b,"endeavor");eq(b.enemy.hp,40);eq(b.player.pp.endeavor,4);assert(text:find("But it failed!",1,true));unchanged(before)
        end
    end)
    test("Endeavor Ghost immunity precedes accuracy and HPdiff effect",function()
        local b=fresh(nil,Pokemon("gastly",100));b.player.hp=1;local hp=b.enemy.hp;local before=RulesRNG.snapshot()
        local text=use(b,"endeavor");eq(b.enemy.hp,hp);eq(b.player.pp.endeavor,4);assert(text:find("doesn't affect",1,true));unchanged(before)
    end)
    test("Endeavor contact uses real Static receipt after fixed damage",function()
        local b=fresh(nil,Pokemon("pikachu",100));b.player.hp,b.enemy.hp=30,80
        RulesRNG.seed(findSeed(function(r)r:random(1,100);return r:random(0,99)<30 end))
        use(b,"endeavor");eq(b.enemy.hp,30);eq(b.player.status,"paralyze");eq(RulesRNG.snapshot().rolls,2)
    end)
    test("Endeavor miss has one accuracy draw and no contact reaction",function()
        local b=fresh(nil,Pokemon("pikachu",100));b.player.hp,b.enemy.hp=30,80;b.player.statStages.acc=-6;b.enemy.statStages.eva=6
        RulesRNG.seed(findSeed(function(r)return r:random(1,100)>33 end));use(b,"endeavor")
        eq(b.enemy.hp,80);eq(b.player.status,nil);eq(b.player.pp.endeavor,4);eq(RulesRNG.snapshot().rolls,1)
    end)
    test("Sucker Punch public round hits pending damaging selection even slower",function()
        local b=fresh();own(b.player,{"suckerPunch"});own(b.enemy,{"tackle"});b.player.spe,b.enemy.spe=10,100;local hp=b.enemy.hp;RulesRNG.seed(2)
        assert(b:selectMove(1));local text=settle(b);assert(b.enemy.hp<hp);eq(b.player.pp.suckerPunch,4);eq(b.enemy.pp.tackle,34)
        assert(text:find("used SUCKER PUNCH!",1,true)<text:find("used TACKLE!",1,true));eq(b.effects.round,nil)
    end)
    test("Sucker Punch status-selected failure uses no accuracy/contact draws",function()
        local b=fresh();own(b.player,{"suckerPunch"});own(b.enemy,{"harden"});local hp=b.enemy.hp;RulesRNG.seed(2)
        assert(b:selectMove(1));local text=settle(b);eq(b.enemy.hp,hp);eq(b.player.pp.suckerPunch,4);eq(b.enemy.pp.harden,29)
        assert(text:find("But it failed!",1,true));eq(RulesRNG.snapshot().rolls,1);eq(b.effects.round,nil)
    end)
    test("Sucker Punch fails after faster equal-priority Quick Attack already executes",function()
        local b=fresh();own(b.player,{"suckerPunch"});own(b.enemy,{"quickAttack"});b.player.spe,b.enemy.spe=10,100;local hp=b.enemy.hp;RulesRNG.seed(2)
        assert(b:selectMove(1));local text=settle(b);eq(b.enemy.hp,hp);eq(b.player.pp.suckerPunch,4);eq(b.enemy.pp.quickAttack,29)
        assert(text:find("used QUICK ATTACK!",1,true)<text:find("used SUCKER PUNCH!",1,true));eq(RulesRNG.snapshot().rolls,4)
    end)
    test("Sucker Punch tests selected action not predicted sleep success",function()
        local b=fresh();own(b.player,{"suckerPunch"});own(b.enemy,{"tackle"});b.enemy.status,b.enemy.statusTurns,b.enemy.sleepDuration="sleep",1,1
        local hp=b.enemy.hp;RulesRNG.seed(2);assert(b:selectMove(1));settle(b);assert(b.enemy.hp<hp);eq(b.enemy.pp.tackle,35);eq(b.player.pp.suckerPunch,4)
    end)
    test("Sucker Punch no pending target action fails, doesn't reuse prior turn",function()
        local b=fresh();local before=RulesRNG.snapshot();local text=use(b,"suckerPunch");eq(b.enemy.hp,b.enemy.maxHP);eq(b.player.pp.suckerPunch,4)
        assert(text:find("But it failed!",1,true));unchanged(before);eq(b.effects.round,nil)
    end)
    test("Sucker Punch sleeping user never spends PP or removes target pending action",function()
        local b=fresh();own(b.player,{"suckerPunch"});own(b.enemy,{"harden"});b.player.status,b.player.statusTurns,b.player.sleepDuration="sleep",1,1
        RulesRNG.seed(2);assert(b:selectMove(1));settle(b);eq(b.player.pp.suckerPunch,5);eq(b.enemy.pp.harden,29);eq(RulesRNG.snapshot().rolls,1)
    end)
    test("Assurance literal damage after faster TakeDown recoil doubles50to100",function()
        local b=fresh();own(b.player,{"assurance"});own(b.enemy,{"takeDown"});RulesRNG.seed(2)
        b:runScript(function()return b:resolveRound({turn(b,"enemy","takeDown"),turn(b,"player","assurance")})end);settle(b)
        eq(b.player.hp,16);eq(b.enemy.hp,0);eq(b.lastDamage,131);eq(b.player.pp.assurance,9);eq(b.enemy.pp.takeDown,19);eq(RulesRNG.snapshot().rolls,6);eq(b.effects.round,nil)
    end)
    test("Assurance own hit doesn't double itself and preexisting injury isn't this-turn damage",function()
        local b=fresh();b.enemy.hp=100;b:setDirection("player");local before=RulesRNG.snapshot();eq(b:effectiveMovePower(moveData.assurance,b.player,b.enemy),50);unchanged(before)
        RulesRNG.seed(2);use(b,"assurance");eq(b.lastDamage,58);eq(b.enemy.hp,42);eq(RulesRNG.snapshot().rolls,3)
    end)
    test("Assurance confusion self-hit counts as actual same-turn damage",function()
        local b=fresh();own(b.player,{"assurance"});own(b.enemy,{"tackle"});b.enemy.confusion=2;RulesRNG.seed(1)
        b:runScript(function()return b:resolveRound({turn(b,"enemy","tackle"),turn(b,"player","assurance")})end);local text=settle(b)
        assert(text:find("hurt itself",1,true));eq(b.enemy.pp.tackle,35);eq(b.lastDamage,114);eq(b.enemy.hp,11);eq(b.effects.round,nil)
    end)
    test("Assurance ledger retains damage through healing, ignores zero and cost provenance",function()
        local b=fresh();b:setDirection("player");b.effects:beginRound();local before=RulesRNG.snapshot()
        eq(b.effects:damage(b.enemy,0,"condition"),0);eq(b:effectiveMovePower(moveData.assurance,b.player,b.enemy),50)
        b.effects:damage(b.enemy,1,"cost");eq(b:effectiveMovePower(moveData.assurance,b.player,b.enemy),50)
        b.effects:damage(b.enemy,1,"struggle-recoil");eq(b:effectiveMovePower(moveData.assurance,b.player,b.enemy),50)
        b.effects:damage(b.enemy,1,"condition");b.enemy:heal();eq(b:effectiveMovePower(moveData.assurance,b.player,b.enemy),100)
        b.effects:endRound();eq(b:effectiveMovePower(moveData.assurance,b.player,b.enemy),50);unchanged(before)
    end)
    test("Entry hazard loss belongs to switched-in identity and round, never outgoing",function()
        local b=fresh();b.effects:beginRound();b.conditions.sides.enemy={stealthRock=1,order={"stealthRock"}}
        b:runScript(function()b.conditions:entry(b.enemy,"enemy");b:setDirection("player");eq(b:effectiveMovePower(moveData.assurance,b.player,b.enemy),100)end);settle(b)
        eq(b.effects.round,nil);eq(b.effects:damagedThisRound(b.enemy),false)
    end)
    test("Sweet Scent actually lowers one GenV evasion stage, respects cap and PP",function()
        local b=fresh();RulesRNG.seed(2);use(b,"sweetScent");eq(b.enemy.statStages.eva,-1);eq(b.player.pp.sweetScent,19);eq(RulesRNG.snapshot().rolls,1)
        b.enemy.statStages.eva=-6;RulesRNG.seed(2);use(b,"sweetScent");eq(b.enemy.statStages.eva,-6);eq(RulesRNG.snapshot().rolls,1)
    end)
    test("Rage Powder explicitly fails singles after PP without accuracy or random draws",function()
        local b=fresh(Pokemon("butterfree",100));local before=RulesRNG.snapshot();local text=use(b,"ragePowder")
        assert(text:find("But it failed!",1,true));eq(b.player.pp.ragePowder,19);eq(b.enemy.hp,b.enemy.maxHP);unchanged(before);eq(b.effects.round,nil)
    end)
    test("Shared effective-power observer includes MudSport and never allocates/changes direction",function()
        local b=fresh(Pokemon("pikachu",100));b.player.spe,b.enemy.spe=100,100
        local attacker,defender=b.attacker,b.defender;local before=RulesRNG.snapshot();eq(b.conditions.members[b.player],nil)
        eq(b:effectiveMovePower(moveData.electroBall,b.player,b.enemy),60);eq(b.conditions.members[b.player],nil)
        b.conditions:of(b.enemy).mudSport=true
        -- PML power pipeline: variable power must precede the field modifier.
        eq(b:effectiveMovePower(moveData.electroBall,b.player,b.enemy),20)
        eq(b.attacker,attacker);eq(b.defender,defender);unchanged(before)
    end)
    test("Invalid noPP/index commands preserve context identity and RNG",function()
        local b=fresh();own(b.player,{"suckerPunch"});b.player.pp.suckerPunch=0;local before=RulesRNG.snapshot();local phase=b:phase()
        eq(b:selectMove(1),false);eq(b:selectMove(99),false);eq(b:phase(),phase);eq(b.effects.round,nil);unchanged(before)
    end)
    test("Round queries and repeated draws are inert; forced exit invalidates context",function()
        local b=fresh();local pending=turn(b,"enemy","tackle");b.effects:beginRound({pending});local context=b.effects.round;local before=RulesRNG.snapshot()
        local scene=BattleScene(b);scene:enter();for _=1,20 do scene:draw();eq(b.effects:pendingMove(b.enemy),moveData.tackle)end
        eq(b.effects.round,context);unchanged(before);scene:exit();b:clearVolatiles();eq(b.effects.round,nil);eq(b.effects:pendingMove(b.enemy),nil)
    end)
    test("Failed run response has no pending player attack and resets damaged ledger",function()
        local b=fresh(Pokemon("charmander",100));own(b.enemy,{"suckerPunch"});b.player.spe,b.enemy.spe=1,100;local hp=b.player.hp
        b.effects:beginRound();b.effects:damage(b.player,1,"condition");b.player:heal();RulesRNG.seed(1)
        assert(b:tryRun());local text=settle(b);eq(b.player.hp,hp);eq(b.enemy.pp.suckerPunch,4);eq(RulesRNG.snapshot().rolls,2)
        assert(text:find("But it failed!",1,true));eq(b.effects.round,nil)
    end)
    test("Voluntary switch response fails Sucker Punch against a nonmove choice",function()
        local p,q=Pokemon("charmander",100),Pokemon("pidgey",100);local party=Party();assert(party:add(p));assert(party:add(q))
        local b=Battle(p,Pokemon("rattata",100),nil,{party=party});settle(b);own(b.enemy,{"suckerPunch"});local hp=q.hp;RulesRNG.seed(2)
        assert(b:chooseParty(2));local text=settle(b);eq(b.player,q);eq(q.hp,hp);eq(b.enemy.pp.suckerPunch,4)
        assert(text:find("But it failed!",1,true));eq(RulesRNG.snapshot().rolls,1);eq(b.effects.round,nil)
    end)
    test("Real switch entry hazard doubles later enemy Assurance in same response",function()
        local p,q=Pokemon("charmander",100),Pokemon("pidgey",100);local party=Party();assert(party:add(p));assert(party:add(q))
        local b=Battle(p,Pokemon("rattata",100),nil,{party=party});settle(b);own(b.enemy,{"assurance"})
        b.conditions.sides.player={stealthRock=1,order={"stealthRock"}};local observed;local power=b.effects.basePower
        b.effects.basePower=function(owner,move,value)local result=power(owner,move,value);if move==moveData.assurance then observed=result end;return result end
        RulesRNG.seed(2);assert(b:chooseParty(2));settle(b);eq(observed,100);eq(b.effects.round,nil)
    end)
    test("Pending and damaged identities clear on withdraw, never leak to replacement",function()
        local b=fresh();local action=turn(b,"enemy","tackle");b.effects:beginRound({action});b.effects:damage(b.enemy,1,"hit")
        eq(b.effects:pendingMove(b.enemy),moveData.tackle);eq(b.effects:damagedThisRound(b.enemy),true);b.effects:clear(b.enemy)
        eq(b.effects:pendingMove(b.enemy),nil);eq(b.effects:damagedThisRound(b.enemy),false);b.effects:endRound()
    end)
    test("Medicine response fails Sucker Punch and consumes exactly one Potion",function()
        local g=GameContext();contexts[#contexts+1]=g;local p=Pokemon("charmander",100);assert(g:recruit(p))
        assert(g.session:setIntro({stage="done",starter="charmander",rivalStarter="squirtle",rivalOutcome=true}))
        local bag=g.session:inventory();assert(bag:add("potion",1));p.hp=p.maxHP-30
        local e=Pokemon("rattata",100);own(e,{"suckerPunch"});local b=Battle(p,e,nil,{party=g.session:party(),session=g.session});settle(b)
        -- Production medicine intentionally rejects an inactive session. Prove
        -- that preflight, then activate this actual owner before the positive use.
        eq(GameSession.activeRNGSession()==g.session,false);local before=RulesRNG.snapshot();local hp=p.hp
        local rejected,reason=b:useItem("potion",1);eq(rejected,false);eq(reason,"stale-session");eq(p.hp,hp);eq(bag:quantity("potion"),1);unchanged(before)
        assert(g.session:activateRNG())
        RulesRNG.seed(2);assert(b:useItem("potion",1));local text=settle(b);eq(p.hp,p.maxHP-10);eq(bag:quantity("potion"),0);eq(e.pp.suckerPunch,4)
        assert(text:find("But it failed!",1,true));eq(RulesRNG.snapshot().rolls,1);eq(b.effects.round,nil)
    end)
    test("Failed capture response has no pending player move, preserves exact capture RNG continuation",function()
        local g=GameContext();contexts[#contexts+1]=g;local p=Pokemon("charmander",100);assert(g:recruit(p))
        assert(g.session:setIntro({stage="done",starter="charmander",rivalStarter="squirtle",rivalOutcome=true}))
        assert(g.session:inventory():add("pokeBall",1));local e=Pokemon("rattata",100);own(e,{"suckerPunch"});local b=Battle(p,e,nil,{party=g.session:party(),session=g.session});settle(b)
        local chosen,rolls
        for n=1,1000 do local r=RulesRNG.new(n);local result=assert(Capture.attempt({pokemon=e,wild=true},"pokeBall",1,r))
            if not result.caught then chosen,rolls=n,r:snapshot().rolls;break end
        end
        assert(chosen,"bounded failed capture seed");RulesRNG.seed(chosen);local hp=p.hp;assert(b:throwBall("pokeBall"));local text=settle(b)
        eq(p.hp,hp);eq(e.pp.suckerPunch,4);eq(g.session:inventory():quantity("pokeBall"),0);eq(RulesRNG.snapshot().rolls,rolls+1)
        assert(text:find("But it failed!",1,true));eq(b.effects.round,nil)
    end)
    test("Round context survives actual BattleScript learning overlay, then ends before enemy2 command",function()
        local g=GameContext();contexts[#contexts+1]=g;local p=Pokemon("squirtle",6);assert(g:recruit(p))
        assert(g.session:setIntro({stage="done",starter="squirtle",rivalStarter="bulbasaur",rivalOutcome=true}));p.xp=p:xpForLevel(7)-1
        local e,reserve=Pokemon("rattata",1),Pokemon("geodude",5);e.hp=1;own(e,{"growl"});own(reserve,{"defenseCurl"})
        local enemies=Party();assert(enemies:add(e));assert(enemies:add(reserve))
        g.machine:register("overworld",State("overworld"));g.machine:register("learning",LearningState(g));local owner=BattleState(g);g.machine:register("battle",owner)
        g.machine:change("battle",p,e,{name="ROUND TEST",markInteracted=function()end},enemies);local b=owner.battle;settle(b);RulesRNG.seed(2);assert(b:selectMove(1))
        local steps=0;while b:phase()=="script"and not b.pendingLearning do steps=steps+1;assert(steps<100);b.machine:get("script"):advance()end
        assert(b.pendingLearning,"real EXP learning yield");local context=b.effects.round;assert(context);local co=b.machine:get("script").co;local rng=RulesRNG.snapshot()
        assert(owner:openPendingLearning());local learning=g.machine:get("learning");eq(learning.phase,"message");assert(p:hasMove("bubble"))
        for _=1,20 do g.machine:update();g.machine:draw()end;eq(b.effects.round,context);eq(b.machine:get("script").co,co);unchanged(rng)
        learning:handleInput();assert(learning.dialog.onComplete)();learning:handleInput();eq(g.machine:getCurrent(),"battle")
        settle(b);eq(b.enemy,reserve);eq(b:phase(),"command");eq(b.effects.round,nil)
    end)
    for _,g in ipairs(contexts)do pcall(function()if g.machine:get("overworld")then g.machine:change("overworld")end end)end
    local currentOwner=GameSession.activeRNGSession();if currentOwner and currentOwner~=priorOwner then assert(currentOwner:deactivateRNG())end
    if priorOwner then assert(priorOwner:activateRNG())end
    RulesRNG.restore(saved);return report
end
