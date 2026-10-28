-- Prepared real-SDK cases. Root supplies an ACTUAL provider-owned imported map
-- fixture with VermilionStoryState, active session, actor metadata and cleanup.
-- Missing integrations fail, never skip or fall back to emulated Lua/SDK.
VermilionStoryContracts = {}
local V <const> = VermilionStory
local PENDING <const> = "VERMILION_SCENE_V1_DEPARTURE_PENDING"
local function eq(a,b) assert(a==b,"expected "..tostring(b)..", got "..tostring(a)) end
local function same(a,b)
    eq(type(a),type(b))
    if type(a)~="table" then eq(a,b);return end
    for k,v in pairs(a) do same(v,b[k]) end
    for k in pairs(b) do assert(a[k]~=nil,"unexpected value "..tostring(k)) end
end
local function drain(g)
    local dialog=g.machine:get("dialog")
    local generation=dialog.generation
    for _=1,512 do
        if g.machine:getCurrent()~="dialog" or dialog.generation~=generation then return end
        dialog.dialog:advance();dialog:handleInput()
    end
    error("Vermilion dialogue did not settle")
end
local function settle(g)
    for _=1,512 do
        if g.machine:getCurrent()=="overworld" then return end
        local event=g.machine:get("event")
        assert(event.phase~="failed",event.waiting)
        if g.machine:getCurrent()=="dialog" then drain(g) else g.machine:update() end
    end
    error("Vermilion scene did not settle")
end
local function fill(g,excluded)
    local discard
    for id,d in pairs(ItemData.definitions) do
        if not d.keyItem and id~=excluded and g.session:inventory():count()<Inventory.CAPACITY then
            assert(g.session:inventory():add(id,1));discard=id
        end
    end
    eq(g.session:inventory():count(),Inventory.CAPACITY)
    return discard
end
local function roundTrip(g)
    local p=g.player
    assert(g.session:captureTraversal({world=WorldDeltas.export(),actors=g.npcManager.motion:snapshot(),
        location={zone_id=currentZone.stableID,x=p.gridX,y=p.gridY,facing=p.facing}}))
    local wire=assert(SessionCodec.encode(g.session,{root="overworld",overworld="explore",settled=true}))
    return assert(SessionCodec.decode(wire,g:getSessionDependencies()))
end
local function find(g,id)
    for _,npc in ipairs(g.npcManager.npcs) do if npc.def and npc.def.source_event_id==id then return npc end end
end
local function ready(g,id)
    if id==V.RIVAL then assert(V.check(g)) else SourceEvents.dispatch(g,id) end
    local event=g.machine:get("event")
    for _=1,512 do
        assert(event.phase~="failed",event.waiting)
        if g.machine:getCurrent()=="dialog" and event.trainerToken then
            g.machine:pop() -- Keep real lease/token; do not fire the UI launch callback.
            eq(g.trainers:snapshot().phase,"ready")
            return event,event.trainerToken
        end
        if g.machine:getCurrent()=="dialog" then drain(g) else g.machine:update() end
    end
    error("source trainer did not approach")
end
local function launch(g,event,token)
    local team=assert(g.trainers:launch(token))
    event.trainerLaunching=true
    local npc=assert(find(g,event.id))
    local battle=Battle(g:getPlayerPokemon(),team:active(),npc.name,
        {party=g.session:party(),session=g.session,enemyParty=team})
    assert(g.trainers:attachBattle(token,battle))
    return team,battle
end
local function terminal(g,token,battle,team,won)
    for _,mon in ipairs((won and team or g.session:party()):members()) do mon:takeDamage(mon.maxHP) end
    local kind=won and "victory" or "defeat"
    battle:runScript(function() return kind end)
    local accepted,receipt
    battle:on("battleEnd",function(result,outcome) accepted,receipt=g.trainers:resolve(token,result,outcome) end)
    assert(battle:emitEnd());assert(accepted,receipt)
    return receipt
end
local function location(g)
    return {zone_id=currentZone.stableID,x=g.player.gridX,y=g.player.gridY,facing=g.player.facing}
end
function VermilionStoryContracts.run(withScene)
    assert(type(withScene)=="function","root provider-owned Vermilion SDK fixture required")
    local report={ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)
        local ok,problem=pcall(fn)
        report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(problem) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    local function scene(name,options,fn)
        withScene(name,options,function(g)
            assert(g.machine:get("event"):is("VermilionStoryState"),"single composed scene controller required")
            assert(WorldDeltas.definitionProvider():owns(currentZone),"actual provider-owned terrain fixture required")
            eq(GameSession.activeRNGSession(),g.session)
            fn(g)
        end)
    end
    test("boarding without ticket backs up once and can retry after Bill ticket",function()
        scene("VermilionCity",{x=18,y=30,facing="down"},function(g)
            g.player.stepJustFinished=true;assert(V.check(g));settle(g)
            eq(g.player.gridY,29);eq(g.session:inventory():quantity("ssTicket"),0)
            assert(g.session:inventory():add("ssTicket",1))
            g.player:tryMove(0,1)
            for _=1,16 do if g.player.isMoving then g.player:update() end end
            g.player.stepJustFinished=true;assert(V.check(g));settle(g)
            eq(g.player.gridY,30);eq(g.session:inventory():quantity("ssTicket"),1)
            eq(V.check(g),false) -- settled gate does not re-open dialogue every frame
        end)
    end)
    test("departed ship refuses boarding even with retained ticket",function()
        scene("VermilionCity",{x=18,y=30,facing="down",quest={EVENT_SS_ANNE_LEFT=true}},function(g)
            assert(g.session:inventory():add("ssTicket",1))
            SourceEvents.dispatch(g,V.GUARD);settle(g)
            eq(g.player.gridY,29)
            eq(V.allowDoor(g,{to=SourceMaps.entry("VermilionDock").key}),false)
        end)
    end)
    for _,starter in ipairs({"charmander","squirtle","bulbasaur"}) do
        local chosen=starter
        for _,x in ipairs({36,37}) do
            local trigger=x
            test("Anne "..chosen.." source approach/team/frozen token/departure at "..trigger,function()
                scene("SSAnne2F",{x=trigger,y=8,facing="up",starter=chosen},function(g)
                    local event,token=ready(g,V.RIVAL)
                    local snapshot=g.trainers:snapshot()
                    local expected=V.trainers()[V.RIVAL].rival_parties[chosen]
                    same(snapshot.party,expected.party);eq(snapshot.payout,1300)
                    local changed=chosen=="squirtle" and "charmander" or "squirtle"
                    local counters={charmander="squirtle",squirtle="bulbasaur",bulbasaur="charmander"}
                    -- Change history only after acquiring that starter. The
                    -- trainer token must keep the team selected before this.
                    assert(g:recruit(Pokemon(changed, 5)))
                    assert(g.session:setIntro({stage="done",starter=changed,rivalStarter=counters[changed]}))
                    same(g.trainers:snapshot().party,expected.party)
                    local team,battle=launch(g,event,token)
                    for i,mon in ipairs(team:members()) do eq(mon.species,expected.party[i].species);eq(mon.level,expected.party[i].level) end
                    local before=g.session:inventory():money()
                    terminal(g,token,battle,team,true)
                    eq(g.session:inventory():money(),before+1300)
                    eq(g.session:questFlag("EVENT_BEAT_SS_ANNE_RIVAL"),true)
                    g.machine:change("overworld")
                    SourceEvents.dispatch(g,V.RIVAL);settle(g)
                    eq(find(g,V.RIVAL),nil)
                    eq(g.trainers:peekReceipt(V.RIVAL),nil)
                    local restored=roundTrip(g)
                    eq(restored:trainerDefeated(V.RIVAL),true)
                    eq(restored:questFlag("EVENT_BEAT_SS_ANNE_RIVAL"),true)
                end)
            end)
        end
    end
    test("Anne loss commits no victory/payout/hide and remains retryable",function()
        scene("SSAnne2F",{x=36,y=8,starter="bulbasaur"},function(g)
            local event,token=ready(g,V.RIVAL)
            local team,battle=launch(g,event,token)
            local money=g.session:inventory():money()
            terminal(g,token,battle,team,false)
            eq(g.session:trainerDefeated(V.RIVAL),false)
            eq(g.session:questFlag("EVENT_BEAT_SS_ANNE_RIVAL"),false)
            eq(g.session:inventory():money(),money)
            eq(g.trainers:peekReceipt(V.RIVAL),nil)
            eq(V.plan(V.RIVAL,EventState.observe(g,V.RIVAL)).scene_script,"rival")
        end)
    end)
    test("leased rival uses eight frames then cancellation restores source pose and rejects token",function()
        scene("SSAnne2F",{x=36,y=8},function(g)
            assert(V.check(g))
            local event=g.machine:get("event")
            local npc=assert(find(g,V.RIVAL))
            local lease=assert(event.npcLeases[V.RIVAL])
            local before=g.session:worldRngData();local rules=RulesRNG.toData()
            for _=1,7 do g.machine:update() end
            eq(npc.gridY,4)
            g.machine:update();eq(npc.gridY,5)
            local callback=event:guard(function() error("cancelled Anne callback executed") end)
            g.machine:change("overworld");callback()
            eq(npc.gridY,4)
            eq(g.npcManager.motion:updateScript(lease),false)
            same(g.session:worldRngData(),before);same(RulesRNG.toData(),rules)
            eq(g.session:trainerDefeated(V.RIVAL),false)
        end)
    end)
    test("Captain full bag preserves rubbed flag only; retry grants HM once and codec retains it",function()
        scene("SSAnneCaptainsRoom",{x=4,y=3,facing="up"},function(g)
            local discard=fill(g,"hm01")
            SourceEvents.dispatch(g,V.CAPTAIN);settle(g)
            eq(g.session:questFlag("EVENT_RUBBED_CAPTAINS_BACK"),true)
            eq(g.session:questFlag("EVENT_GOT_HM01"),false)
            eq(g.session:inventory():quantity("hm01"),0)
            local restored=roundTrip(g)
            eq(restored:questFlag("EVENT_RUBBED_CAPTAINS_BACK"),true)
            eq(restored:questFlag("EVENT_GOT_HM01"),false)
            assert(g.session:inventory():consume(discard,1))
            SourceEvents.dispatch(g,V.CAPTAIN);settle(g)
            SourceEvents.dispatch(g,V.CAPTAIN);settle(g)
            eq(g.session:inventory():quantity("hm01"),1)
            eq(roundTrip(g):questFlag("EVENT_GOT_HM01"),true)
        end)
    end)
    test("stale Captain dialogue after cancellation cannot rub or grant",function()
        scene("SSAnneCaptainsRoom",{x=4,y=3,facing="up"},function(g)
            SourceEvents.dispatch(g,V.CAPTAIN)
            local old=g.machine:get("dialog").onComplete
            g.machine:change("overworld");old()
            eq(g.session:questFlag("EVENT_RUBBED_CAPTAINS_BACK"),false)
            eq(g.session:inventory():quantity("hm01"),0)
        end)
    end)
    test("puzzle observation/planning/cancelled detached intent draws no live RNG",function()
        scene("VermilionGym",{x=4,y=15},function(g)
            local before=g.session:worldRngData();local rules=RulesRNG.toData();local world=WorldDeltas.export()
            for _=1,8 do V.puzzle(g.session);SourceEvents.plan("pokered:VERMILION_GYM:hidden_events:4",EventState.observe(g,V.SURGE)) end
            V.intent(g.session,"entry",nil,world,location(g)) -- discard before commit
            same(g.session:worldRngData(),before);same(RulesRNG.toData(),rules);same(WorldDeltas.export(),world)
        end)
    end)
    test("wrong first / first switch / wrong second reset are owner-atomic and source-count bounded",function()
        scene("VermilionGym",{x=4,y=15},function(g)
            assert(V.commitIntent(g,"entry"))
            local p=V.puzzle(g.session);eq(p.first%2,0);assert(p.first<=14)
            local rng=g.session:worldRngData();local rules=RulesRNG.toData();local world=WorldDeltas.export()
            local ok,label=V.commitIntent(g,"trash",(p.first+1)%15);assert(ok);eq(label,"_VermilionGymTrashText")
            same(g.session:worldRngData(),rng);same(WorldDeltas.export(),world)
            assert(V.commitIntent(g,"trash",p.first))
            p=V.puzzle(g.session);eq(p.first_open,true);eq(p.solved,false)
            assert(V.commitIntent(g,"trash",(p.second+1)%15))
            p=V.puzzle(g.session);eq(p.first_open,false);eq(p.solved,false);eq(p.first%2,0)
            same(RulesRNG.toData(),rules)
            local pad=V.padding(currentZone.stableID)
            eq(currentZone.collision[5][5+pad],1)
        end)
    end)
    test("correct second opens terrain and source flags together; solved puzzle is inert",function()
        scene("VermilionGym",{x=4,y=15},function(g)
            assert(V.commitIntent(g,"entry"));assert(V.commitIntent(g,"trash",V.puzzle(g.session).first))
            local p=V.puzzle(g.session)
            assert(V.commitIntent(g,"trash",p.second));eq(g.session:questFlag("EVENT_2ND_LOCK_OPENED"),true)
            local pad=V.padding(currentZone.stableID)
            eq(currentZone.collision[5][5+pad],0)
            local rng=g.session:worldRngData();eq(V.commitIntent(g,"trash",0),false);same(g.session:worldRngData(),rng)
            local restored=roundTrip(g);eq(restored:questFlag("EVENT_2ND_LOCK_OPENED"),true)
            same(restored:worldData(),WorldDeltas.export());same(restored:worldRngData(),rng)
        end)
    end)
    test("opaque scene intent rejects ABA replay after two reversible no-roll searches",function()
        scene("VermilionGym",{x=4,y=15},function(g)
            assert(V.commitIntent(g,"entry"))
            local wrong=(V.puzzle(g.session).first+1)%15
            local world=WorldDeltas.export();local rng=g.session:worldRngData();local flags=g.session:flags()
            local old=assert(V.intent(g.session,"trash",wrong,world,location(g)))
            assert(V.commitIntent(g,"trash",wrong));assert(V.commitIntent(g,"trash",wrong))
            same(g.session:flags(),flags);same(g.session:worldRngData(),rng);same(WorldDeltas.export(),world)
            eq(g.session:transactScene(old.expected,old.changes,old.scene),false)
            same(g.session:flags(),flags);same(g.session:worldRngData(),rng)
        end)
    end)
    test("rejected solving transaction rolls actual opened terrain back with flags and RNG",function()
        scene("VermilionGym",{x=4,y=15},function(g)
            assert(V.commitIntent(g,"entry"));assert(V.commitIntent(g,"trash",V.puzzle(g.session).first))
            local world=WorldDeltas.export();local rng=g.session:worldRngData();local flags=g.session:flags()
            local plan=assert(V.intent(g.session,"trash",V.puzzle(g.session).second,world,location(g)))
            plan.expected.flags.EVENT_2ND_LOCK_OPENED=true -- Deliberately stale after detached world validation.
            eq(g.session:transactScene(plan.expected,plan.changes,plan.scene),false)
            same(WorldDeltas.export(),world);same(g.session:flags(),flags);same(g.session:worldRngData(),rng)
            eq(currentZone.collision[5][5+V.padding(currentZone.stableID)],1)
        end)
    end)
    test("trainer tokens reject changed session and cancellation before battle construction",function()
        scene("SSAnne2F",{x=36,y=8},function(g)
            assert(V.check(g))
            local event=g.machine:get("event");local npc=assert(find(g,V.RIVAL))
            local lease=assert(event.npcLeases[V.RIVAL])
            local original=g.session
            local replacement=GameContext({sessionLocationPolicy=PewterWorld.locationPolicy()})
            g.session=replacement.session
            eq(g.npcManager.motion:updateScript(lease),false)
            g.session=original
            g.machine:change("overworld")
            local nextEvent,token=ready(g,V.RIVAL)
            eq(g.trainers:resolve(token,true,"victory"),false)
            g.session=replacement.session
            eq(g.trainers:launch(token),nil)
            g.session=original
            assert(g.trainers:cancel(token));eq(g.trainers:launch(token),nil)
            eq(g.session:trainerDefeated(V.RIVAL),false)
            eq(g.session:inventory():money(),3000)
        end)
    end)
    test("source-mask second selector preserves both normal adjacency and rare can-zero bug",function()
        eq(V.secondCan(4,0),0) -- actual pinned underflow, intentionally nonadjacent
        eq(V.secondCan(4,64),7) -- swap $40 -> $04, table offset3
        eq(V.secondCan(0,32),3) -- swap $20 -> $02, table offset1
        for first=0,14 do for byte=0,255 do
            local second=V.secondCan(first,byte)
            assert(second>=0 and second<15)
        end end
    end)
    test("entry reset samples only on actual city entry; Continue and solved Gym retain state",function()
        scene("VermilionCity",{x=18,y=29},function(g)
            local rng=g.session:worldRngData()
            SourceEvents.worldHook("onEnter",g,{})
            same(g.session:worldRngData(),rng)
            SourceEvents.worldHook("onEnter",g,{fromDoor=true})
            assert(not pcall(same,g.session:worldRngData(),rng))
            eq(V.puzzle(g.session).initialized,true)
            rng=g.session:worldRngData()
            assert(g.session:setQuestFlag("EVENT_2ND_LOCK_OPENED",true))
            SourceEvents.worldHook("onEnter",g,{fromDoor=true})
            same(g.session:worldRngData(),rng)
            eq(g.session:questFlag("EVENT_2ND_LOCK_OPENED"),true)
        end)
    end)
    test("stale world RNG / stale flags / invalid terrain cannot publish puzzle rolls or flags",function()
        scene("VermilionGym",{x=4,y=15},function(g)
            local plan=assert(V.intent(g.session,"entry",nil,WorldDeltas.export(),location(g)))
            g.session:worldRandom(0,255)
            local rng=g.session:worldRngData();local flags=g.session:flags();local world=WorldDeltas.export()
            eq(g.session:transactScene(plan.expected,plan.changes,plan.scene),false)
            same(g.session:worldRngData(),rng);same(g.session:flags(),flags);same(WorldDeltas.export(),world)
            plan=assert(V.intent(g.session,"entry",nil,world,location(g)))
            plan.expected.flags.EVENT_1ST_LOCK_OPENED=true
            eq(g.session:transactScene(plan.expected,plan.changes,plan.scene),false)
            same(g.session:flags(),flags);same(g.session:worldRngData(),rng);same(WorldDeltas.export(),world)
            plan=assert(V.intent(g.session,"entry",nil,world,location(g)))
            plan.scene.world={schema=1,zones={{zone_id="unregistered"}},zone_count=1}
            eq(g.session:transactScene(plan.expected,plan.changes,plan.scene),false)
            same(g.session:flags(),flags);same(g.session:worldRngData(),rng);same(WorldDeltas.export(),world)
        end)
    end)
    test("Surge confirmed badge/payout survives full TM bag and reward retry is exactly once",function()
        scene("VermilionGym",{x=5,y=2,facing="up",quest={EVENT_2ND_LOCK_OPENED=true}},function(g)
            local discard=fill(g,"tm24")
            local event,token=ready(g,V.SURGE)
            local team,battle=launch(g,event,token)
            terminal(g,token,battle,team,true)
            eq(g.session:questFlag("BADGE_THUNDER"),true)
            eq(g.session:questFlag("EVENT_BEAT_LT_SURGE"),true)
            for i=2,4 do eq(g.session:trainerDefeated("pokered:VERMILION_GYM:objects:"..i),true) end
            g.machine:change("overworld");SourceEvents.dispatch(g,V.SURGE);settle(g)
            eq(g.session:inventory():quantity("tm24"),0);eq(g.session:questFlag("EVENT_GOT_TM24"),false)
            local restored=roundTrip(g);eq(restored:questFlag("BADGE_THUNDER"),true)
            assert(g.session:inventory():consume(discard,1))
            SourceEvents.dispatch(g,V.SURGE);settle(g)
            SourceEvents.dispatch(g,V.SURGE);settle(g)
            eq(g.session:inventory():quantity("tm24"),1);eq(g.session:questFlag("EVENT_GOT_TM24"),true)
        end)
    end)
    test("HM possession or arbitrary dock entry never implies actual ship departure",function()
        scene("VermilionDock",{x=14,y=1,quest={EVENT_GOT_HM01=true}},function(g)
            eq(V.check(g),false);eq(g.session:questFlag("EVENT_SS_ANNE_LEFT"),false)
            local before=WorldDeltas.export()
            eq(V.commitIntent(g,"departure"),false)
            same(WorldDeltas.export(),before);eq(g.session:questFlag("EVENT_SS_ANNE_LEFT"),false)
        end)
    end)
    test("only either actual ship exit with HM01 arms the dock scene",function()
        for _,x in ipairs({26,27}) do
            local sourceX=x
            scene("SSAnne1F",{x=sourceX,y=0,quest={EVENT_GOT_HM01=true}},function(g)
                local door=assert(currentZone:getDoorAt(g.player.gridX,g.player.gridY))
                eq(V.departureExit(g,"pokered:VERMILION_CITY",door),false)
                eq(V.departureExit(g,"pokered:VERMILION_DOCK",nil),nil)
                eq(V.departureExit(g,"pokered:VERMILION_DOCK",door),true)
                SourceEvents.worldHook("onLeave",g,"pokered:VERMILION_DOCK",door)
                eq(g.session:questFlag(PENDING),true);eq(g.session:questFlag("EVENT_SS_ANNE_LEFT"),false)
            end)
        end
    end)
    test("cancelling armed departure before its delay ends rejects old callback without terrain writes",function()
        scene("VermilionDock",{x=14,y=1,quest={EVENT_GOT_HM01=true,[PENDING]=true}},function(g)
            local world=WorldDeltas.export();local rng=g.session:worldRngData()
            SourceEvents.dispatch(g,V.DOCK)
            local event=g.machine:get("event")
            eq(event.phase,"vermilion-departure")
            for _=1,10 do g.machine:update() end
            local old=event:guard(function() error("cancelled departure callback ran") end)
            g.machine:change("overworld");old()
            eq(g.session:questFlag("EVENT_SS_ANNE_LEFT"),false)
            eq(g.session:questFlag(PENDING),true)
            same(WorldDeltas.export(),world);same(g.session:worldRngData(),rng)
        end)
    end)
    test("armed departure commits ship terrain/flag/barrier together and codec retains it",function()
        scene("VermilionDock",{x=14,y=1,quest={EVENT_GOT_HM01=true,[PENDING]=true}},function(g)
            assert(V.commitIntent(g,"departure"))
            eq(g.session:questFlag("EVENT_SS_ANNE_LEFT"),true)
            eq(V.allowDoor(g,{to=SourceMaps.entry("SSAnne1F").key}),false)
            local pad=V.padding(currentZone.stableID)
            eq(currentZone.collision[5][11+pad],1) -- source lower-ship block becomes water
            local restored=roundTrip(g)
            eq(restored:questFlag("EVENT_SS_ANNE_LEFT"),true)
            same(restored:worldData(),WorldDeltas.export())
            eq(V.commitIntent(g,"departure"),false)
        end)
    end)
    return report
end
