HomeLeadContracts={}
local gfx=playdate.graphics
local function eq(a,b)assert(a==b,"expected "..tostring(b)..", got "..tostring(a))end
local function same(a,b)
    if type(a)~=type(b)then return false end;if type(a)~="table"then return a==b end
    for k,v in pairs(a)do if not same(v,b[k])then return false end end
    for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local function write(name)if HarnessBuild and HarnessBuild.enabled and playdate.simulator then playdate.simulator.writeToFile(gfx.getWorkingImage(),HarnessBuild.output_dir..name..".png")end end
local function closeDialog(g)
    eq(g.machine:getCurrent(),"dialog");local callback=g.machine:get("dialog").onComplete
    g.machine:pop();if callback then return callback()end
end
local function scene(name,fn)
    local oldZone,oldStory,oldOwner,oldRng=currentZone,Story.currentContext(),GameSession.activeRNGSession(),RulesRNG.toData()
    local undo=WorldDeltas.checkpointRuntime();local sprites,sets={},{};local count,ids=gfx.sprite.spriteCount(),WorldTiles:maxID()
    local ox,oy=gfx.getDrawOffset();local screen=gfx.getWorkingImage():copy();local g
    for _,s in ipairs(gfx.sprite.getAllSprites())do sprites[s]={visible=s:isVisible(),enabled=s:updatesEnabled()}end
    for k,v in pairs(SpriteFactory.npc)do sets[k]=v end
    local ok,problem=pcall(function()
        g=GameContext({sessionLocationPolicy=PewterWorld.locationPolicy()});assert(g:recruit(Pokemon("squirtle",16)))
        assert(g.session:setIntro({stage="done",starter="squirtle",rivalStarter="bulbasaur"}));Story.bind(g)
        if name=="forest"then
            currentZone=PewterWorld.isolated("ViridianForest");PewterSprites.installFor(PewterSlice.padded("ViridianForest"))
        else currentZone=zoneRegistry.reds_house end
        g.machine:register("overworld",OverworldState(g));g.machine:register("bag",BagState(g));g.machine:register("pause",PauseState(g))
        g.machine:register("dialog",DialogState(g));g.machine:register("townMap",TownMapState(g));g.machine:register("homeRest",HomeRestState(g))
        local entry=name=="forest"and{x=25,y=33,facing="up"}or{x=5,y=5,facing="up"}
        g.machine:change("overworld",{entry=entry})
        assert(g.session:captureTraversal({location={zone_id=currentZone.stableID,x=entry.x,y=entry.y,facing=entry.facing},
            world=WorldDeltas.export(),actors=g.npcManager.motion:snapshot(),checkpoint={zone_id="pallet_town",x=9,y=0,facing="up"}}))
        fn(g)
    end)
    if g then
        while #g.machine.stack>0 do local state=table.remove(g.machine.stack);pcall(state.exit,state)end
        g.npcManager:clear();if g.player then g.player:remove();g.player.grassOverlay:remove();g.player.exitArrow:remove();if g.player.jumpShadow then g.player.jumpShadow:remove()end end
    end
    undo()
    for _,s in ipairs(gfx.sprite.getAllSprites())do if not sprites[s]then s:remove()end end
    local present={};for _,s in ipairs(gfx.sprite.getAllSprites())do present[s]=true end
    for s,v in pairs(sprites)do if not present[s]then s:add()end;s:setVisible(v.visible);s:setUpdatesEnabled(v.enabled)end
    for k in pairs(SpriteFactory.npc)do if not sets[k]then SpriteFactory.npc[k]=nil end end;for k,v in pairs(sets)do SpriteFactory.npc[k]=v end
    currentZone=oldZone;Story.bind(oldStory)
    local owner=GameSession.activeRNGSession();if owner~=oldOwner then if owner then owner:deactivateRNG()end;if oldOwner then oldOwner:activateRNG()end end
    RulesRNG.restoreData(oldRng);gfx.setDrawOffset(0,0);screen:draw(0,0);gfx.setDrawOffset(ox,oy)
    eq(gfx.sprite.spriteCount(),count);eq(WorldTiles:maxID(),ids)
    if not ok then error(problem,0)end
end
local function model()
    local g=GameContext({sessionLocationPolicy=PewterWorld.locationPolicy()})
    local a,b=Pokemon("squirtle",16),Pokemon("pidgey",8)
    assert(g:recruit(a));assert(g:recruit(b));assert(g.session:party():switch(2))
    return g,a,b
end
function HomeLeadContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)
        local ok,error=pcall(fn);report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(error)or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("new field entry uses physical first conscious, retaining roster identities and last outcome",function()
        local g,a,b=model();local party=g.session:party();local last={kind="victory"};g.lastBattleOutcome=last
        local plan=assert(FieldBattle.prepare(g,b,Pokemon("rattata",3)))
        local battle=FieldBattle.construct(plan);eq(battle.player,a);eq(party:active(),a);eq(party:get(1),a);eq(party:get(2),b);eq(g.lastBattleOutcome,last)
        assert(party:switch(2));a.hp=0
        plan=assert(FieldBattle.prepare(g,b,Pokemon("rattata",3)));battle=FieldBattle.construct(plan);eq(battle.player,b);eq(party:get(1),a)
    end)
    test("actual controller entry selects first conscious once; pause/resume never resets switched battler",function()
        scene("home",function(g)
            local first=g:getPlayerPokemon();local reserve=Pokemon("pidgey",8);assert(g:recruit(reserve));assert(g.session:party():switch(2))
            g.machine:register("battle",BattleState(g))
            assert(FieldBattle.start(g,reserve,Pokemon("rattata",3)))
            local owner=g.machine:get("battle");eq(owner.battle.player,first)
            assert(g.session:party():switch(2));owner.battle.player=reserve
            owner:pause();owner:resume();eq(owner.battle.player,reserve);eq(g.session:party():active(),reserve)
            eq(g.session:party():get(1),first);eq(g.session:party():get(2),reserve)
        end)
    end)
    test("fainted persisted active is replaced only at actual new field admission",function()
        local g,a,b=model();b.hp=0;eq(g.session:party():active(),b)
        local plan=assert(FieldBattle.prepare(g,b,Pokemon("rattata",3)));eq(g.session:party():active(),b)
        local battle=FieldBattle.construct(plan);eq(battle.player,a);eq(g.session:party():active(),a)
    end)
    test("pure rejected field admission leaves stack, roster, stages, discovery and rules unchanged",function()
        local g,a,b=model();g.machine:register("battle",BattleState(g));g.machine:register("idle",State("idle"));g.machine:change("idle")
        a.hp=0;b.hp=0;a.statStages.acc=-3;local generation=g.machine._generation;local dex=g.session:pokedex();local rng=RulesRNG.toData()
        eq(FieldBattle.start(g,b,Pokemon("rattata",3)),false);eq(g.machine:getCurrent(),"idle");eq(g.machine._generation,generation)
        eq(g.session:party():active(),b);eq(a.statStages.acc,-3);assert(same(dex,g.session:pokedex()));assert(same(rng,RulesRNG.toData()))
        a.hp=1;eq(FieldBattle.prepare(g,a,Pokemon("rattata",3)),nil);eq(FieldBattle.prepare(g,b,{}),nil)
    end)
    test("constructor rejection restores previously fainted active, exact stage table and discovery",function()
        local g,a,b=model();b.hp=0;a.statStages.acc=-4
        local stages=a.statStages;local dex=g.session:pokedex();local old=BattleScene;local rng=RulesRNG.toData()
        local plan=assert(FieldBattle.prepare(g,b,Pokemon("rattata",3)))
        BattleScene=function()error("controlled scene admission failure")end
        local ok,error=pcall(FieldBattle.construct,plan);BattleScene=old
        eq(ok,false);assert(tostring(error):find("controlled scene admission failure",1,true))
        eq(g.session:party():active(),b);eq(a.statStages,stages);eq(a.statStages.acc,-4);assert(same(dex,g.session:pokedex()));assert(same(rng,RulesRNG.toData()))
    end)
    test("standalone rules and trainer replacement retain chosen active and physical order",function()
        local g,a,b=model();local enemies=Party();local e1,e2=Pokemon("diglett",11),Pokemon("sandshrew",11)
        assert(enemies:add(e1));assert(enemies:add(e2))
        local raw=Battle(b,e1,"TEST",{party=g.session:party(),session=g.session,enemyParty=enemies})
        eq(raw.player,b);eq(g.session:party():active(),b)
        assert(enemies:switch(2));raw.enemy=e2;raw:runScript(function()raw:opponentEntered()end)
        eq(raw.player,b);eq(g.session:party():get(1),a);eq(g.session:party():get(2),b)
    end)
    test("only new game checkpoint is Pallet5,6; existing valid saved checkpoints survive decode",function()
        local g=model()
        -- The fixture recruited a real starter/reserve; keep its persisted intro
        -- tuple valid before exercising the unchanged production codec gate.
        assert(g.session:setIntro({stage="done",starter="squirtle",rivalStarter="bulbasaur"}))
        local cp=g.session:checkpoint();eq(cp.zone_id,"pallet_town");eq(cp.x,5);eq(cp.y,6);eq(cp.facing,"down")
        eq(g.session:location().zone_id,"reds_house_2f");eq(g.session:location().x,5);eq(g.session:location().y,3)
        assert(g.session:captureTraversal({location=g.session:location(),world=WorldDeltas.export(),actors=WorldMotionData.empty(),checkpoint={zone_id="reds_house_2f",x=5,y=3,facing="up"}}))
        local encoded=assert(SessionCodec.encode(g.session,{root="overworld",overworld="explore",settled=true}))
        local decoded=assert(SessionCodec.decode(encoded,g:getSessionDependencies()));eq(decoded:checkpoint().zone_id,"reds_house_2f");eq(decoded:checkpoint().y,3)
    end)
    test("MOM before starter only gives original wake-up text and never heals",function()
        scene("home",function(g)
            local mon=g:getPlayerPokemon();mon.hp=1;assert(g.session:setIntro({stage="pre_oak"}))
            assert(HomeRest.tryInteract(g));eq(g.machine:getCurrent(),"dialog")
            assert(g.machine:get("dialog").dialog.lines[1]:find("All boys leave",1,true))
            closeDialog(g);eq(g.machine:getCurrent(),"overworld");eq(mon.hp,1)
        end)
    end)
    test("actual MOM rest heals all once at white, no checkpoint or stream/economy effects",function()
        scene("home",function(g)
            local first=g:getPlayerPokemon();local reserve=Pokemon("pidgey",8);assert(g:recruit(reserve));assert(g.session:party():switch(2))
            first.hp=0;first.status="poison";reserve.hp=1;reserve.pp[reserve.moves[1]]=0
            local cp=g.session:checkpoint();local flags=g.session:flags();local money=g.session:inventory():money();local rules=RulesRNG.toData();local world=g.session:worldRngData()
            assert(HomeRest.tryInteract(g));closeDialog(g);local rest=g.machine:get("homeRest")
            for i=1,11 do rest:update()end;eq(first.hp,0);eq(rest.healed,false)
            rest:update();eq(rest.phase,"white");eq(first.hp,first.maxHP);eq(first.status,nil);eq(reserve.hp,reserve.maxHP);assert(reserve.pp[reserve.moves[1]]>0)
            local tick=rest.tick;g.machine:get("overworld"):flushPendingPresentation();g.machine:draw();write("home-mom-white");rest:draw();rest:draw();eq(rest.tick,tick)
            for i=1,24 do rest:update()end;eq(g.machine:getCurrent(),"dialog")
            assert(g.machine:get("dialog").dialog.lines[1]:find("looking great",1,true));closeDialog(g)
            eq(g.machine:getCurrent(),"overworld");eq(g.session:party():active(),reserve)
            assert(same(cp,g.session:checkpoint()));assert(same(flags,g.session:flags()));eq(g.session:inventory():money(),money)
            assert(same(rules,RulesRNG.toData()));assert(same(world,g.session:worldRngData()))
            g.machine:get("overworld"):flushPendingPresentation();g.machine:draw();write("home-mom-rested")
        end)
    end)
    test("Mom abort and stale completed-dialog callback cannot heal or reopen overlay",function()
        scene("home",function(g)
            local mon=g:getPlayerPokemon();mon.hp=1;assert(HomeRest.tryInteract(g))
            local callback=g.machine:get("dialog").onComplete;g.machine:pop();g.machine:pop();callback()
            eq(mon.hp,1);eq(g.machine:getCurrent(),"overworld")
            assert(HomeRest.tryInteract(g));closeDialog(g);local rest=g.machine:get("homeRest");for i=1,5 do rest:update()end
            g.machine:pop();eq(mon.hp,1);eq(rest.active,false)
        end)
    end)
    test("Mom interaction requires actual adjacent authored NPC; empty tile never heals",function()
        scene("home",function(g)
            local npc=g.npcManager:getNPCAt(5,4);assert(npc and npc.name=="MOM")
            local old=g.npcManager.getNPCAt;g.npcManager.getNPCAt=function()return nil end
            eq(HomeRest.tryInteract(g),false);g.npcManager.getNPCAt=old;eq(g.machine:getCurrent(),"overworld")
        end)
    end)
    return report
end
