BattleItemContracts={}
local contexts={}
local function eq(a,b) assert(a==b,"expected "..tostring(b)..", got "..tostring(a)) end
local function same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    if getmetatable(a) or getmetatable(b) then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end;return true
end
local function settle(b)
    for _=1,150 do
        if b:phase()~="script" then return end
        b.machine:get("script"):advance()
    end
    error("bounded medicine script did not settle")
end
local function setup()
    local g=GameContext();contexts[#contexts+1]=g
    local p,bench=Pokemon("charmander",5),Pokemon("squirtle",5)
    assert(g:recruit(p));assert(g:recruit(bench))
    assert(g.session:setIntro({stage="done",starter="charmander",rivalStarter="squirtle",rivalOutcome=true}))
    assert(g.session:activateRNG())
    local sub=StateMachine();sub:register("explore",{});sub:change("explore")
    g.machine:register("overworld",{sub=sub})
    local state=BattleState(g);g.machine:register("battle",state)
    g.machine:register("party",PartyState(g));g.machine:register("bag",BagState(g))
    local enemy=Pokemon("magikarp",5)
    g.machine:change("battle",p,enemy)
    settle(state.battle)
    for _=1,21 do state.scene:update() end
    state.scene:enter()
    return g,state,state.battle,p,bench,enemy
end
local function payload(g,b)
    return {owners={session=g.session,party=g.session:party(),inventory=g.session:inventory(),active=b.player,enemy=b.enemy},session=assert(SessionCodec.encode(g.session,{root="overworld",overworld="explore",settled=true})),
        rng=RulesRNG.toData(),phase=b:phase(),selection=b.selectionKind or "none",message=b.message,
        enemy=assert(PokemonCodec.encode(b.enemy)),conditions=b:getConditionsSnapshot()}
end
local function openBag(g,state)
    assert(state.scene:requestSelection("bag"));state:openSelection();eq(g.machine:getCurrent(),"bag")
    return g.machine:get("bag")
end
local function choose(g,index)
    eq(g.machine:getCurrent(),"party");g.machine:get("party"):close(index)
end
function BattleItemContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)
        local rng,owner,story,zone=RulesRNG.toData(),GameSession.activeRNGSession(),Story.currentContext(),currentZone
        local sprites={};for _,sprite in ipairs(playdate.graphics.sprite.getAllSprites()) do sprites[#sprites+1]={sprite=sprite,visible=sprite:isVisible(),enabled=sprite:updatesEnabled()} end
        contexts={};local ok,problem=pcall(fn)
        for _,g in ipairs(contexts) do pcall(g.machine.change,g.machine,"overworld") end
        -- BattleState.enter legitimately removes every sprite; restore the exact
        -- original instances/flags after isolated controller tests, even on fail.
        playdate.graphics.sprite.removeAll()
        for _,row in ipairs(sprites) do row.sprite:add();row.sprite:setVisible(row.visible);row.sprite:setUpdatesEnabled(row.enabled) end
        local active=GameSession.activeRNGSession();if active then active:deactivateRNG() end
        if owner then owner:activateRNG() end
        RulesRNG.restoreData(rng);Story.bind(story);currentZone=zone
        playdate.graphics.sprite.addDirtyRect(0,0,400,240)
        report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(problem) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("Potion commits once then exactly one enemy action and one residual without player attack",function()
        local g,state,b,p,bench,enemy=setup();local bag,party=g.session:inventory(),g.session:party()
        assert(bag:add("potion",2));p.hp=1;p.status="poison"
        local pp=p.pp[p.moves[1]];local enemyPP=enemy.pp.splash
        assert(b:beginSelection("bag"));local ok,plan=b:useItem("potion",1);assert(ok)
        eq(p.hp,plan.hpAfter);eq(bag:quantity("potion"),1);eq(b:phase(),"script");eq(b.selectionKind,nil)
        local after=payload(g,b);eq(b:useItem("potion",1),false);assert(same(after,payload(g,b)))
        settle(b);eq(b:phase(),"command");eq(enemy.pp.splash,enemyPP-1)
        eq(p.hp,plan.hpAfter-math.max(1,p.maxHP//8));eq(p.pp[p.moves[1]],pp)
        eq(g.session:inventory(),bag);eq(g.session:party(),party);eq(party:get(1),p);eq(party:get(2),bench)
    end)
    test("Existing cures Revive and single/all-move PP medicines each spend one enemy action",function()
        for _,id in ipairs({"antidote","fullRestore","revive","maxRevive","ether","maxEther","elixir","maxElixir"}) do
            local g,state,b,p,bench,enemy=setup();assert(g.session:inventory():add(id,1))
            local index,slot=1,nil
            if id=="revive" or id=="maxRevive" then index=2;bench.hp=0
            elseif id=="antidote" then p.status="poison"
            elseif id=="fullRestore" then p.hp=1;p.status="poison";p.confusion=2
            else p.pp[p.moves[1]]=0;if not ItemData.definitions[id].allMoves then slot=1 end end
            local target=g.session:party():get(index);local plan=assert(Items.planUse(id,target,slot))
            local pp=enemy.pp.splash;assert(b:useItem(id,index,slot));eq(target.hp,plan.hpAfter)
            if plan.clearStatus then eq(target.status,nil) end
            for _,change in ipairs(plan.ppChanges) do eq(target.pp[change.move],change.after) end
            settle(b);eq(enemy.pp.splash,pp-1);eq(g.session:inventory():quantity(id),0);eq(b:phase(),"command")
            if index==2 then eq(b.player,p);eq(g.session:party():active(),p) end
        end
    end)
    test("No effect no item invalid target or PP slot and unsupported items fail atomically",function()
        local g,state,b,p=setup();assert(g.session:inventory():add("potion",1));assert(b:beginSelection("bag"))
        local before=payload(g,b);local ok,reason=b:useItem("potion",1);eq(ok,false);eq(reason,"no-effect");assert(same(before,payload(g,b)))
        p.hp=1;assert(g.session:inventory():consume("potion",1));before=payload(g,b)
        ok,reason=b:useItem("potion",1);eq(ok,false);eq(reason,"insufficient-items");assert(same(before,payload(g,b)))
        for _,entry in ipairs({{"potion",0},{"potion",3},{"potion",1.5},{"potion","1"},{"ether",1,9},{"potion",1,1},{"fireStone",1},{"pokeBall",1},{"townMap",1}}) do
            before=payload(g,b);eq(b:useItem(table.unpack(entry)),false);assert(same(before,payload(g,b)))
        end
    end)
    test("Wrong phase forced replacement foreign active session and party lock reject before mutation",function()
        local g,state,b,p,bench=setup();p.hp=1;assert(g.session:inventory():add("potion",1))
        assert(b:beginSelection("party"));local before=payload(g,b);eq(b:useItem("potion",1),false);assert(same(before,payload(g,b)));assert(b:cancelSelection())
        b:runScript(function() b:say("Waiting") end);before=payload(g,b);eq(b:useItem("potion",1),false);assert(same(before,payload(g,b)));settle(b)
        p.hp=0;b:runScript(function() return b:finishRound() end);settle(b);eq(b:needsForcedSwitch(),true)
        before=payload(g,b);eq(b:beginSelection("bag"),false);eq(b:useItem("revive",1),false);assert(same(before,payload(g,b)))
        g,state,b,p=setup();p.hp=1;assert(g.session:inventory():add("potion",1));assert(g.session:deactivateRNG())
        before=payload(g,b);local ok,reason=b:useItem("potion",1);eq(ok,false);eq(reason,"stale-session");assert(same(before,payload(g,b)))
    end)
    test("Party and Ether move previews pause real BattleState; cancellations consume no item or turn",function()
        local g,state,b,p=setup();assert(g.session:inventory():add("ether",1));p.pp[p.moves[1]]=0
        local bag=openBag(g,state);local before=payload(g,b);bag:chooseBattleTarget("ether");eq(g.machine:getCurrent(),"party")
        for _=1,24 do g.machine:update() end;assert(same(before,payload(g,b)))
        g.machine:get("party"):close();eq(g.machine:getCurrent(),"bag");eq(bag.phase,"list");assert(same(before,payload(g,b)))
        bag:chooseBattleTarget("ether");choose(g,1);eq(bag.phase,"move")
        for _=1,24 do g.machine:update() end;assert(same(before,payload(g,b)))
        bag.menu.onCancel();eq(bag.phase,"list");assert(same(before,payload(g,b)))
        assert(bag.options.tryCancel());g.machine:pop();eq(g.machine:getCurrent(),"battle");eq(b.selectionKind,nil)
        eq(p.pp[p.moves[1]],0);eq(g.session:inventory():quantity("ether"),1)
    end)
    test("Guarded UI medicine dispatch uses authoritative chosen bench and exact PP move",function()
        local g,state,b,p,bench,enemy=setup();assert(g.session:inventory():add("revive",1));bench.hp=0
        local bag=openBag(g,state);bag:chooseBattleTarget("revive");choose(g,2)
        eq(g.machine:getCurrent(),"battle");eq(bench.hp,math.max(1,bench.maxHP//2));eq(b.player,p);eq(state.scene.selectionOpen,false)
        local pp=enemy.pp.splash;settle(b);eq(enemy.pp.splash,pp-1)
        assert(g.session:inventory():add("ether",1));p.pp[p.moves[2]]=0
        bag=openBag(g,state);bag:chooseBattleTarget("ether");choose(g,1);eq(bag.phase,"move")
        local untouched=p.pp[p.moves[1]];bag.menu.onSelect(2);eq(g.machine:getCurrent(),"battle")
        eq(p.pp[p.moves[2]],math.min(10,moveData[p.moves[2]].maxPP));eq(p.pp[p.moves[1]],untouched)
        settle(b)
    end)
    test("Stale roster index and PP move identities cannot redirect a retained callback",function()
        local g,state,b,p=setup();assert(g.session:inventory():add("potion",1));p.hp=1
        local bag=openBag(g,state);bag:chooseBattleTarget("potion");local callback=g.machine:get("party").options.onSelect
        assert(g.session:party():swap(1,2));g.machine:pop();local before=payload(g,b);callback(1)
        eq(bag.phase,"message");assert(same(before,payload(g,b)))
        assert(bag.options.tryCancel());g.machine:pop()
        assert(g.session:inventory():add("ether",1));p.pp[p.moves[1]]=0
        bag=openBag(g,state);bag:chooseBattleTarget("ether");choose(g,2);local selected=bag.menu.onSelect
        p.moves[1],p.moves[2]=p.moves[2],p.moves[1];before=payload(g,b);selected(1)
        eq(bag.phase,"message");assert(same(before,payload(g,b)))
    end)
    test("Exit reentry session replacement and controller scene replacement invalidate old target callbacks",function()
        local g,state,b,p=setup();assert(g.session:inventory():add("potion",1));p.hp=1
        local bag=openBag(g,state);bag:chooseBattleTarget("potion");local stale=g.machine:get("party").options.onSelect
        g.machine:pop();assert(bag.options.tryCancel());g.machine:pop();bag=openBag(g,state)
        local before=payload(g,b);stale(1);eq(bag.phase,"list");assert(same(before,payload(g,b)))
        bag:chooseBattleTarget("potion");local callback=g.machine:get("party").options.onSelect;g.machine:pop()
        state.scene=BattleScene(b);before=payload(g,b);callback(1);eq(bag.phase,"message");assert(same(before,payload(g,b)))
        -- An old visit callback may not mutate a replacement authoritative session.
        local original=g.session;g.session=GameContext().session
        local rng=RulesRNG.toData();callback(1);assert(same(rng,RulesRNG.toData()));eq(original:inventory():quantity("potion"),1)
        g.session=original
    end)
    test("Capture controller capability remains ball-only when no medicine target is supplied",function()
        local g,state,b,p=setup();assert(g.session:inventory():add("masterBall",1));local bag=openBag(g,state)
        local ok,result=bag.options.trySelect("masterBall");assert(ok);assert(result.caught);g.machine:pop();settle(b)
        eq(b.outcome,"caught");eq(g.session:inventory():quantity("masterBall"),0);eq(g.session:party():count(),3)
    end)
    return report
end
