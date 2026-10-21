TrainerContracts={}
local function eq(a,b) assert(a==b,"expected "..tostring(b)..", got "..tostring(a)) end
local function fresh()
    local g=GameContext();assert(g:recruit(Pokemon("squirtle",5)))
    assert(g.session:setIntro({stage="done",starter="squirtle",rivalStarter="bulbasaur"}))
    return g
end
local function transaction(session,id,amount)
    local money=session:inventory():money()
    return session:transact({flags={},items={},trainers={[id]=false},money=money},
        {flags={},items={},trainers={[id]=true},money={op="credit",amount=amount}})
end
-- Native motion contracts use a deliberately blank collision test plane;
-- source-map integration/visual assertions are separate subsequent cases.
local function actors(id,fn)
    local previous=currentZone;local g=fresh();local tiles={}
    for y=1,8 do tiles[y]={};for x=1,13 do tiles[y][x]=25 end end
    local def=PewterSlice.trainer(id);currentZone=Zone({id=def.map_id,name="trainer contract plane",tiles=tiles,width=13,height=8})
    g.player=Player(3,4,currentZone.collision,g.npcManager)
    SliceSprites.install();local npc=NPC(6,4,def.name,{},nil,SliceSprites.key("SPRITE_YOUNGSTER"),"left")
    npc.def={source_event_id=id};g.npcManager:addNPC(npc)
    local c=TrainerEvents(g);local previousOwner,previousRNG=GameSession.activeRNGSession(),RulesRNG.snapshot()
    assert(g.session:activateRNG())
    local ok,problem=pcall(fn,g,c,npc)
    local active=GameSession.activeRNGSession();if active then assert(active:deactivateRNG()) end
    if previousOwner then assert(previousOwner:activateRNG()) end
    RulesRNG.restore(previousRNG)
    g.npcManager:clear();g.player:remove();g.player.grassOverlay:remove();g.player.exitArrow:remove();currentZone=previous
    if not ok then error(problem,0) end
end
local function ready(c,npc)
    local token=assert(c:prepare(npc,"sight"))
    for tick=1,16 do local done,reason=c:updateApproach(token);eq(done,tick==16);if tick<16 then eq(reason,"moving") end end
    return token
end
local function terminal(c,token,battle,kind)
    battle:runScript(function() return kind end)
    local accepted,receipt
    battle:on("battleEnd",function(won,result) accepted,receipt=c:resolve(token,won,result) end)
    assert(battle:emitEnd());return accepted,receipt
end
function TrainerContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)
        local ok,err=pcall(fn);report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(err) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("trainer payout is one atomic saturating credit preserving Inventory identity",function()
        local g=fresh();local bag=g.session:inventory();assert(bag:credit(Inventory.MONEY_LIMIT-bag:money()-10))
        assert(transaction(g.session,"test:trainer",60));eq(g.session:inventory(),bag);eq(bag:money(),999999);eq(g.session:trainerDefeated("test:trainer"),true)
        eq(transaction(g.session,"test:trainer",60),false);eq(bag:money(),999999)
    end)
    test("invalid or stale money and trainer writes roll back every outcome field",function()
        local g=fresh();local bag=g.session:inventory();local money=bag:money()
        local expected={flags={TEST_REWARD=false},items={},trainers={a=false},money=money+1}
        local changes={flags={TEST_REWARD=true},items={{op="add",id="potion",quantity=1}},trainers={a=true},money={op="credit",amount=60}}
        eq(g.session:transact(expected,changes),false);eq(bag:quantity("potion"),0);eq(bag:money(),money);eq(g.session:questFlag("TEST_REWARD"),false);eq(g.session:trainerDefeated("a"),false)
        expected.money=money;changes.money.amount=-1
        eq(g.session:transact(expected,changes),false);eq(bag:quantity("potion"),0);eq(g.session:trainerDefeated("a"),false)
        changes.money.amount=60;expected.trainers.a=true
        eq(g.session:transact(expected,changes),false);eq(bag:money(),money)
    end)
    test("source blackout halves odd money with compare-and-set and keeps bag reference",function()
        local g=fresh();local bag=g.session:inventory();assert(bag:credit(1))
        eq(bag:money(),3001);assert(g.session:halveMoneyOnBlackout(3001));eq(bag:money(),1500);eq(g.session:inventory(),bag)
        eq(g.session:halveMoneyOnBlackout(3001),false);eq(bag:money(),1500)
        assert(bag:spend(1500));assert(g.session:halveMoneyOnBlackout(0));eq(bag:money(),0)
    end)
    test("five original teams and source flags are defensive and not duplicate quest owners",function()
        local g=fresh();local c=TrainerEvents(g);local defs=PewterSlice.trainers();local n=0
        for id,d in pairs(defs) do n=n+1;local copy=c:definition(id);eq(copy.id,id);eq(copy.payout,d.payout)
            copy.party[1].level=100;eq(c:definition(id).party[1].level,d.party[1].level)
        end
        eq(n,5);assert(g.session:setTrainerDefeated(TrainerEvents.BROCK,true))
        eq(c:sourceFlag("EVENT_BEAT_BROCK"),true);eq(g.session:questFlag("EVENT_BEAT_BROCK"),false);eq(g.session:hasBadge("boulder"),false)
    end)
    test("Brock full-bag TM retry and badge trainer flags survive authoritative codec",function()
        local g=fresh();local s=g.session;local money=s:inventory():money()
        assert(s:transact({flags={},items={},trainers={[TrainerEvents.BROCK]=false,[TrainerEvents.JR]=false},money=money},
          {flags={BADGE_BOULDER=true},items={},trainers={[TrainerEvents.BROCK]=true,[TrainerEvents.JR]=true},money={op="credit",amount=1386}}))
        eq(s:hasBadge("boulder"),true);eq(s:inventory():money(),4386)
        local discard
        for id,item in pairs(ItemData.definitions) do
            if not item.keyItem and id~="tm34" and s:inventory():count()<20 then assert(s:inventory():add(id,1));discard=id end
        end
        eq(s:inventory():count(),20);local c=TrainerEvents(g);local plan=assert(c:rewardPlan(TrainerEvents.BROCK))
        eq(s:transact(plan.expected,plan.changes),false);eq(s:questFlag("EVENT_GOT_TM34"),false);eq(s:trainerDefeated(TrainerEvents.JR),true);eq(s:inventory():money(),4386)
        assert(s:inventory():consume(discard,1));plan=assert(c:rewardPlan(TrainerEvents.BROCK));assert(s:transact(plan.expected,plan.changes))
        eq(s:inventory():quantity("tm34"),1);eq(s:transact(plan.expected,plan.changes),false);eq(s:inventory():money(),4386)
        local wire=assert(SessionCodec.encode(s,{root="overworld",overworld="explore",settled=true}));local restored=assert(SessionCodec.decode(wire,g:getSessionDependencies()))
        eq(restored:hasBadge("boulder"),true);eq(restored:trainerDefeated(TrainerEvents.BROCK),true);eq(restored:trainerDefeated(TrainerEvents.JR),true);eq(restored:questFlag("EVENT_GOT_TM34"),true);eq(restored:inventory():money(),4386)
    end)
    test("raw Pewter data descriptor access does not register eight maps",function()
        local count=#zoneList;local d=PewterSlice.descriptor("Route2");eq(d.width,20);eq(d.height,72)
        d.width=1;eq(PewterSlice.descriptor("Route2").width,20)
        local map=PewterSlice.definition("PewterGym");eq(map.dimensions.cells[1],10);map.tile_ids[1][1]=-1
        assert(PewterSlice.definition("PewterGym").tile_ids[1][1]>0);eq(#zoneList,count)
    end)
    test("source sight runs real native two-step approach in eight updates per cell",function()
        actors("pokered:VIRIDIAN_FOREST:objects:2",function(g,c,npc)
            local token=assert(c:prepare(npc,"sight"));eq(c:snapshot().total_steps,2)
            for tick=1,16 do
                local done=c:updateApproach(token);eq(npc.x,192-tick*4);eq(npc.y,120);eq(done,tick==16)
            end
            eq(npc.gridX,4);eq(npc.gridY,4);eq(g.player.gridX,3)
            local party=assert(c:launch(token));eq(party:count(),2);eq(party:get(1).species,"weedle");eq(party:get(2).level,6)
            assert(c:abortBattle(token));eq(g.session:trainerDefeated("pokered:VIRIDIAN_FOREST:objects:2"),false)
        end)
    end)
    test("sight wrong-facing occupancy collision and cancellation cannot grant outcomes",function()
        actors("pokered:VIRIDIAN_FOREST:objects:2",function(g,c,npc)
            npc:setFacing("right");eq(c:prepare(npc,"sight"),nil);npc:setFacing("left")
            currentZone.collision[5][6]=1;eq(c:prepare(npc,"sight"),nil);currentZone.collision[5][6]=0
            local blocker={gridX=5,gridY=4,remove=function()end};g.npcManager:addNPC(blocker)
            eq(c:prepare(npc,"sight"),nil);g.npcManager:removeNPC(blocker)
            local token=assert(c:prepare(npc,"sight"));for tick=1,4 do c:updateApproach(token) end
            eq(npc.x,176);assert(c:cancel(token));eq(npc.x,192);eq(npc.gridX,6)
            eq(g.session:inventory():money(),3000);eq(g.session:trainerDefeated("pokered:VIRIDIAN_FOREST:objects:2"),false)
            eq(c:resolve(token,true,"victory"),false)
        end)
    end)
    test("only actual terminal victory signal with fainted source party grants trainer money once",function()
        actors("pokered:VIRIDIAN_FOREST:objects:2",function(g,c,npc)
            local token=ready(c,npc);local enemies=assert(c:launch(token));local battle=Battle(g:getPlayerPokemon(),enemies:active(),npc.name,{party=g.session:party(),session=g.session,enemyParty=enemies})
            assert(c:attachBattle(token,battle));eq(c:resolve(token,true,"victory"),false);eq(g.session:inventory():money(),3000)
            for _,mon in ipairs(enemies:members()) do mon:takeDamage(mon.maxHP) end
            local ok,receipt=terminal(c,token,battle,"victory");assert(ok,receipt);eq(receipt.payout,60);eq(g.session:inventory():money(),3060)
            eq(g.session:trainerDefeated("pokered:VIRIDIAN_FOREST:objects:2"),true);eq(c:resolve(token,true,"victory"),false)
            eq(c:prepare(npc,"sight"),nil);eq(g.session:inventory():money(),3060)
        end)
    end)
    test("confirmed source trainer loss or aborted battle grants no defeat flag or reward",function()
        actors("pokered:VIRIDIAN_FOREST:objects:2",function(g,c,npc)
            local token=ready(c,npc);local enemies=assert(c:launch(token));local battle=Battle(g:getPlayerPokemon(),enemies:active(),npc.name,{party=g.session:party(),session=g.session,enemyParty=enemies})
            assert(c:attachBattle(token,battle));g:getPlayerPokemon():takeDamage(g:getPlayerPokemon().maxHP)
            local ok=terminal(c,token,battle,"defeat");assert(ok);eq(g.session:trainerDefeated("pokered:VIRIDIAN_FOREST:objects:2"),false);eq(g.session:inventory():money(),3000)
            g.session:party():healAll();npc.gridX,npc.gridY=6,4;npc:moveTo(192,120)
            token=ready(c,npc);enemies=assert(c:launch(token));assert(c:abortBattle(token));eq(c:resolve(token,true,"victory"),false);eq(g.session:inventory():money(),3000)
        end)
    end)
    return report
end
