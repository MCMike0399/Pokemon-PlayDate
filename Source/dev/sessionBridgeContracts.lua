-- Real domain/controller/SDK contracts; native input/save-menu journeys are separate.
SessionBridgeContracts={}
local gate={root="overworld",overworld="explore",settled=true}
local function equal(a,b) assert(a==b,"expected "..tostring(b)..", got "..tostring(a)) end
local function model(game,seed)
    return GameSession.newSession(game:getSessionDependencies(),{seed=seed or 7,
        location={zone_id="reds_house_2f",x=5,y=3,facing="up"}})
end
local function controlled(game,enter)
    -- Real StateMachine callback seam isolates renderer rebuilds; no fake SDK.
    local sub=StateMachine();sub:register("explore",{});sub:change("explore")
    game.machine:register("overworld",{sub=sub,enter=enter or function() end})
    game.machine:register("learning",LearningState(game))
    game.machine:change("overworld")
end
function SessionBridgeContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)
        local old={world=WorldDeltas.export(),zone=currentZone,rng=RulesRNG.toData(),owner=GameSession.activeRNGSession(),story=Story.currentContext()}
        local ok,problem=pcall(fn)
        local active=GameSession.activeRNGSession()
        if active then active:deactivateRNG() end
        if old.owner then old.owner:activateRNG() end
        RulesRNG.restoreData(old.rng);Story.bind(old.story);currentZone=old.zone
        local restored,restoreError=pcall(WorldDeltas.apply,old.world)
        if not restored then ok=false;problem=tostring(problem).." restore: "..tostring(restoreError) end
        report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(problem) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("Context construction keeps live RNG/Story owner and creates Blue initial inventory",function()
        local owner,story=GameSession.activeRNGSession(),Story.currentContext()
        local before=RulesRNG.toData();local game=GameContext({seed=314159})
        equal(game.session:party():count(),0);equal(game:getPlayerPokemon(),nil)
        equal(game.session:inventory():money(),3000);equal(game.session:inventory():count(),0)
        equal(game.session:location().zone_id,"reds_house_2f")
        local checkpoint=game.session:checkpoint()
        equal(checkpoint.zone_id,"pallet_town");equal(checkpoint.x,5);equal(checkpoint.y,6);equal(checkpoint.facing,"down")
        equal(GameSession.activeRNGSession(),owner);equal(Story.currentContext(),story)
        equal(RulesRNG.toData().state,before.state);equal(RulesRNG.toData().rolls,before.rolls)
    end)
    test("Active Pokemon is exactly Party owner and follows switching",function()
        local game=GameContext();local a,b=Pokemon("squirtle",5),Pokemon("bulbasaur",5)
        assert(game:recruit(a));assert(game:recruit(b));equal(game:getPlayerPokemon(),a)
        assert(game.session:party():switch(2));equal(game:getPlayerPokemon(),b)
        equal(rawget(game,"playerPokemon"),nil)
    end)
    test("Story tuple delegates explicit context and facade rejects durable writes",function()
        local a,b=GameContext(),GameContext()
        assert(a.session:setIntro({stage="rival_fight",starter="squirtle",rivalStarter="bulbasaur"}))
        Story.bind(a);Story.notifyBattleEnd(b,true,"victory")
        equal(Story.stage,"rival_fight");Story.notifyBattleEnd(a,false,"defeat")
        equal(Story.stage,"goodbye");equal(Story.rivalOutcome,false)
        equal(b.session:getIntro().stage,"pre_oak")
        equal(pcall(function() Story.stage="done" end),false)
    end)
    test("NPC rebuild reads durable trainer flag without mutating authored definition",function()
        local game=GameContext();local def={source_event_id="contract:trainer"}
        local function npc()
            local value=NPC(1000,1000,"TEST",{"before"},nil,"rival");value:remove();value.def=def
            value.postBattleLines={"after"};game.npcManager:addNPC(value);return value
        end
        local first=npc();first:markInteracted();equal(def.interacted,nil)
        game.npcManager:clear();local rebuilt=npc()
        equal(rebuilt:hasInteracted(),true);equal(rebuilt:getDialogLines()[1],"after")
        rebuilt:resetInteracted();equal(game.session:trainerDefeated("contract:trainer"),false)
        equal(def.interacted,nil);game.npcManager:clear()
    end)
    test("Save capture rejects modal/moving state and accepts real settled Player",function()
        local game=GameContext();controlled(game)
        equal(game:captureSession(),nil)
        switchZone("reds_house_2f")
        local player=Player(5,3,currentZone.collision,game.npcManager);player:remove();game.player=player
        player.facing="up";player.isMoving=true;equal(game:captureSession(),nil)
        player.isMoving=false;player.stepJustFinished=false
        local data=assert(game:captureSession());equal(data.location.zone_id,"reds_house_2f");equal(data.location.x,5)
        game.machine:register("modal",{});game.machine:push("modal");equal(game:captureSession(),nil)
    end)
    test("Install validates before mutation and publishes session/RNG before renderer entry",function()
        local game=GameContext();controlled(game)
        local candidate=model(game,16777217);local mon=Pokemon("charmander",5);assert(candidate:recruit(mon));assert(candidate:setIntro({stage="done",starter="charmander",rivalStarter="squirtle"}))
        local entered=false
        game.machine:get("overworld").enter=function(_,options)
            entered=true;equal(game.session,candidate);equal(Story.currentContext(),game)
            equal(GameSession.activeRNGSession(),candidate);equal(RulesRNG.toData().state,candidate:rngData().state)
            equal(currentZone.stableID,"reds_house_2f");equal(options.entry.x,5)
        end
        assert(game:installSession(candidate));equal(entered,true);equal(game:getPlayerPokemon(),mon)
        local before=RulesRNG.toData();equal(game:installSession({}),false)
        equal(game.session,candidate);equal(RulesRNG.toData().state,before.state)
    end)
    test("Failed renderer installation rolls back session/world/RNG owners",function()
        local game=GameContext();controlled(game);assert(game:installSession(game.session))
        local original=game.session;local before=RulesRNG.toData();local candidate=model(game,99)
        game.machine:get("overworld").enter=function() error("controlled renderer rejection") end
        local ok,reason=game:installSession(candidate)
        equal(ok,false);assert(reason:find("controlled renderer rejection",1,true))
        equal(game.session,original);equal(GameSession.activeRNGSession(),original)
        equal(RulesRNG.toData().state,before.state);equal(Story.currentContext(),game)
    end)
    test("Ordinary full-party blackout heals all and routes default Pallet checkpoint",function()
        local game=GameContext();local options;controlled(game,function(_,value) options=value end)
        local a,b=Pokemon("charmander",5),Pokemon("squirtle",5)
        assert(game:recruit(a));assert(game:recruit(b));a.hp=0;b.hp=0
        local state=BattleState(game);game.machine:register("battle",state)
        assert(game.session:setIntro({stage="done",starter="charmander",rivalStarter="squirtle"}))
        state.battle=Battle(a,Pokemon("pidgey",3),nil,{party=game.session:party(),session=game.session});state:finish(false,"defeat")
        equal(game.lastBattleOutcome.blackout,true);equal(a.hp,a.maxHP);equal(b.hp,b.maxHP)
        equal(currentZone.stableID,"pallet_town");equal(options.entry.x,5);equal(options.entry.y,6);equal(options.entry.facing,"down")
        equal(game.session:party():activeIndex(),1);state.battle:clearVolatiles()
    end)
    test("Usable bench prevents false blackout and remains unhealed during transitional return",function()
        local game=GameContext();local options;controlled(game,function(_,value) options=value end)
        local a,b=Pokemon("charmander",5),Pokemon("squirtle",5)
        assert(game:recruit(a));assert(game:recruit(b));a.hp=0;b.hp=b.maxHP-2
        local state=BattleState(game);game.machine:register("battle",state)
        assert(game.session:setIntro({stage="done",starter="charmander",rivalStarter="squirtle"}))
        state.battle=Battle(a,Pokemon("pidgey",3),nil,{party=game.session:party(),session=game.session});state:finish(false,"defeat")
        equal(game.lastBattleOutcome.blackout,false);equal(a.hp,0);equal(b.hp,b.maxHP-2)
        equal(game:getPlayerPokemon(),b);equal(options,nil);state.battle:clearVolatiles()
    end)
    return report
end
