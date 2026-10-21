-- Optional composition proof: registered only with the separately pinned evolution packet.
BattleLearningEvolutionContracts={}
local function eq(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function settle(b)
    local n=0;while b:phase()=="script" and not b:getLearningSnapshot().pending do n=n+1;assert(n<100);assert(b.machine:get("script"):advance()) end
end
local function setup(species)
    local game=GameContext();local mon=Pokemon(species,15);assert(game:recruit(mon))
    if species=="abra" then assert(game:recruit(Pokemon("charmander",5))) end
    assert(game.session:setIntro({stage="done",starter="charmander",rivalStarter="squirtle",rivalOutcome=true}))
    mon.xp=mon:xpForLevel(16)-1
    assert(SessionCodec.encode(game.session,{root="overworld",overworld="explore",settled=true}))
    game.machine:register("overworld",State("overworld"));game.machine:register("learning",LearningState(game));game.machine:register("evolution",EvolutionState(game))
    local owner=BattleState(game);game.machine:register("battle",owner)
    game.machine:change("battle",mon,Pokemon("rattata",5))
    settle(owner.battle);return game,owner,mon
end
local function evolve(game)
    local state=game.machine:get("evolution");eq(game.machine:getCurrent(),"evolution");eq(state.sub:getCurrent(),"announce")
    assert(state.dialog.onComplete)();for _=1,120 do game.machine:update() end
    eq(state.sub:getCurrent(),"result");return state
end
function BattleLearningEvolutionContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}};local rng=RulesRNG.snapshot()
    local function test(name,fn) local ok,why=pcall(fn);report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(why) or nil};if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end end
    test("Final enemy old-species learning finishes before battleEnd and actual evolution return",function()
        local game,owner,p=setup("charmander");local b=owner.battle;b.enemy.hp=0
        b:runScript(function() return b:handleFaint("enemy") end);settle(b)
        eq(b.outcome,nil);eq(b.endEmitted,false);eq(p.pendingEvolution.species,"charmander");eq(p.level,16)
        assert(owner:openPendingLearning());local learning=game.machine:get("learning");eq(learning.phase,"ask")
        learning.menu.onSelect(2);learning.menu.onSelect(1);learning:handleInput();assert(learning.dialog.onComplete)();learning:handleInput()
        eq(game.machine:getCurrent(),"battle");eq(owner.battle,b);eq(p.species,"charmander");eq(#p:getPendingMoveChoices(),0)
        settle(b);eq(b:phase(),"ended");eq(b.endEmitted,false);eq(p.pendingEvolution.level,16)
        assert(b:emitEnd());eq(game.machine:getCurrent(),"evolution");eq(owner.battle,nil);eq(game.lastBattleOutcome.kind,"victory")
        local evo=evolve(game);eq(p.species,"charmeleon");eq(p.pendingEvolution,nil);assert(evo:finish());eq(game.machine:getCurrent(),"overworld")
    end)
    test("No old-species level move still evolves after return then opens current-level new-species learning",function()
        local game,owner,p=setup("abra");local b=owner.battle;b.enemy.hp=0
        b:runScript(function() return b:handleFaint("enemy") end);settle(b)
        eq(b:getLearningSnapshot().pending,false);eq(b.outcome,"victory");eq(p.species,"abra");eq(p:hasMove("confusion"),false)
        assert(b:emitEnd());local evo=evolve(game);eq(p.species,"kadabra");eq(p:getPendingMoveChoices()[1].reason,"evolution")
        assert(evo:finish());eq(game.machine:getCurrent(),"learning");local learning=game.machine:get("learning")
        eq(learning.phase,"message");eq(p:hasMove("confusion"),true);eq(p.pp.confusion,25);eq(#p:getPendingMoveChoices(),0)
        assert(learning.dialog.onComplete)();learning:handleInput();eq(game.machine:getCurrent(),"overworld")
    end)
    RulesRNG.restore(rng);return report
end
