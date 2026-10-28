-- Real SDK only. Host tests do not load/transpile Lua or emulate playdate.
CeruleanStoryContracts = {}
local MISTY <const> = "pokered:CERULEAN_GYM:objects:1"
local NERD <const> = "pokered:MT_MOON_B2F:objects:1"
local DOME <const> = "pokered:MT_MOON_B2F:objects:6"
local HELIX <const> = "pokered:MT_MOON_B2F:objects:7"
local function eq(a,b) assert(a==b,"expected "..tostring(b)..", got "..tostring(a)) end
local function fresh()
    local g = GameContext()
    assert(g:recruit(Pokemon("squirtle",5)))
    assert(g.session:setIntro({stage="done",starter="squirtle",rivalStarter="bulbasaur"}))
    return g
end
local function observe(g) return EventState.observe(g,DOME) end
local function fullBag(session, excluded)
    local discard
    for id, definition in pairs(ItemData.definitions) do
        if not definition.keyItem and id~=excluded and session:inventory():count()<20 then
            assert(session:inventory():add(id,1)); discard=id
        end
    end
    eq(session:inventory():count(),20)
    return discard
end
local function restore(g)
    local wire = assert(SessionCodec.encode(g.session,{root="overworld",overworld="explore",settled=true}))
    return assert(SessionCodec.decode(wire,g:getSessionDependencies()))
end
local function scoped(fn)
    return SourceEvents._withSources(function()
        if SourceEvents.has(MISTY) then return fn() end
        SourceEvents.registerEventSource("ceruleanStory",CeruleanStory.descriptors())
        SourceEvents.registerTextSource("ceruleanStory",CeruleanStory.text)
        CeruleanStory.registerTrainers()
        return fn()
    end)
end
-- This uses a real SDK Zone/Player/NPC/Battle, not a map acceptance fixture.
local sceneFixture
local function trainerPlane(id, fn)
    if SourceMaps.nameForID(CeruleanStory.trainers()[id].map_id) then
        assert(sceneFixture,"integrated source trainer contracts require imported-map fixture")
        local d=CeruleanStory.trainers()[id]
        return sceneFixture(id==MISTY and "CeruleanGym" or "MtMoonB2F",{x=d.x,y=d.y+1,facing="up"},function(g)
            SourceEvents.dispatch(g,id)
            local event=g.machine:get("event")
            local token=assert(event.trainerToken,event.waiting)
            local c=g.trainers
            local enemies=assert(c:launch(token))
            event.trainerLaunching=true
            local battle=Battle(g:getPlayerPokemon(),enemies:active(),d.name,
                {party=g.session:party(),session=g.session,enemyParty=enemies})
            assert(c:attachBattle(token,battle))
            local ok,problem=pcall(fn,g,c,token,battle,enemies)
            c:abortBattle(token)
            assert(ok,problem)
        end)
    end
    local previousZone = currentZone
    local previousOwner = GameSession.activeRNGSession()
    local rng = RulesRNG.snapshot()
    local g, controller, token
    local ok, problem = pcall(function()
        g = fresh()
        local tiles = {}
        for y=1,8 do tiles[y]={}; for x=1,13 do tiles[y][x]=25 end end
        local d = CeruleanStory.trainers()[id]
        currentZone = Zone({id=d.map_id,name="story trainer contract plane",tiles=tiles,width=13,height=8})
        g.player = Player(3,4,currentZone.collision,g.npcManager)
        SliceSprites.install()
        local npc = NPC(4,4,d.name,{},nil,SliceSprites.key("SPRITE_YOUNGSTER"),"left")
        npc.def = {source_event_id=id}
        g.npcManager:addNPC(npc)
        controller = TrainerEvents(g)
        assert(g.session:activateRNG())
        token = assert(controller:prepare(npc,"talk"))
        assert(controller:updateApproach(token))
        local enemies = assert(controller:launch(token))
        local battle = Battle(g:getPlayerPokemon(),enemies:active(),d.name,
            {party=g.session:party(),session=g.session,enemyParty=enemies})
        assert(controller:attachBattle(token,battle))
        fn(g,controller,token,battle,enemies)
    end)
    if controller and token then controller:abortBattle(token) end
    if g then
        g.npcManager:clear()
        if g.player then g.player:remove();g.player.grassOverlay:remove();g.player.exitArrow:remove() end
    end
    local active = GameSession.activeRNGSession()
    if active then active:deactivateRNG() end
    if previousOwner then previousOwner:activateRNG() end
    RulesRNG.restore(rng)
    currentZone = previousZone
    assert(ok,problem)
end
local function terminal(c,token,battle,outcome)
    battle:runScript(function() return outcome end)
    local accepted, receipt
    battle:on("battleEnd",function(won,kind) accepted,receipt=c:resolve(token,won,kind) end)
    assert(battle:emitEnd())
    assert(accepted,receipt)
    return receipt
end
function CeruleanStoryContracts.run(withScene)
    sceneFixture=withScene
    local report = {ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)
        local ok, problem = pcall(function() scoped(fn) end)
        report.tests[#report.tests+1] = {name=name,ok=ok,error=not ok and tostring(problem) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("fossil requires confirmed Super Nerd defeat and source mutual exclusion",function()
        local g=fresh()
        eq(CeruleanStory.fossilReward(DOME,observe(g)),nil)
        assert(g.session:setTrainerDefeated(NERD,true))
        local dome=assert(CeruleanStory.fossilReward(DOME,observe(g)))
        local helix=assert(CeruleanStory.fossilReward(HELIX,observe(g)))
        assert(g.session:transact(dome.expected,dome.changes))
        eq(g.session:transact(helix.expected,helix.changes),false)
        eq(g.session:inventory():quantity("domeFossil"),1)
        eq(g.session:inventory():quantity("helixFossil"),0)
        g.session=restore(g)
        eq(CeruleanStory.fossilReward(HELIX,observe(g)),nil)
        eq(CeruleanStory.fossilReward(DOME,observe(g)),nil)
    end)
    for _, id in ipairs({DOME,HELIX}) do
        test(id.." full bag retries without setting either fossil flag",function()
            local g=fresh();assert(g.session:setTrainerDefeated(NERD,true))
            local item = id==DOME and "domeFossil" or "helixFossil"
            local discard=fullBag(g.session,item)
            local plan=assert(CeruleanStory.fossilReward(id,observe(g)))
            eq(g.session:transact(plan.expected,plan.changes),false)
            eq(g.session:questFlag("EVENT_GOT_DOME_FOSSIL"),false)
            eq(g.session:questFlag("EVENT_GOT_HELIX_FOSSIL"),false)
            g.session=restore(g)
            assert(g.session:inventory():consume(discard,1))
            plan=assert(CeruleanStory.fossilReward(id,observe(g)))
            assert(g.session:transact(plan.expected,plan.changes))
            eq(g.session:transact(plan.expected,plan.changes),false)
            eq(g.session:inventory():quantity(item),1)
        end)
    end
    test("Ticket requires restored Bill; full bag and codec preserve exact-once grant",function()
        local g=fresh();eq(CeruleanStory.ticketReward(observe(g)),nil)
        assert(g.session:setQuestFlag("EVENT_MET_BILL",true))
        local discard=fullBag(g.session,"ssTicket")
        local plan=assert(CeruleanStory.ticketReward(observe(g)))
        eq(g.session:transact(plan.expected,plan.changes),false)
        eq(g.session:questFlag("EVENT_GOT_SS_TICKET"),false)
        g.session=restore(g);assert(g.session:inventory():consume(discard,1))
        plan=assert(CeruleanStory.ticketReward(observe(g)))
        assert(g.session:transact(plan.expected,plan.changes))
        eq(g.session:transact(plan.expected,plan.changes),false)
        g.session=restore(g);eq(g.session:inventory():quantity("ssTicket"),1)
        eq(CeruleanStory.ticketReward(observe(g)),nil)
    end)
    for _, id in ipairs({MISTY,NERD}) do
        test(id.." unconfirmed victory cannot commit; actual victory pays once",function()
            trainerPlane(id,function(g,c,token,battle,enemies)
                eq(c:resolve(token,true,"victory"),false)
                eq(g.session:trainerDefeated(id),false)
                for _, mon in ipairs(enemies:members()) do mon:takeDamage(mon.maxHP) end
                local receipt=terminal(c,token,battle,"victory")
                eq(receipt.payout,id==MISTY and 2079 or 300)
                eq(g.session:trainerDefeated(id),true)
                eq(c:resolve(token,true,"victory"),false)
                if id==MISTY then
                    eq(g.session:questFlag("BADGE_CASCADE"),true)
                    eq(g.session:questFlag("EVENT_BEAT_MISTY"),true)
                    eq(g.session:trainerDefeated("pokered:CERULEAN_GYM:objects:2"),true)
                    eq(g.session:trainerDefeated("pokered:CERULEAN_GYM:objects:3"),true)
                    eq(g.session:questFlag("EVENT_GOT_TM11"),false)
                else eq(g.session:questFlag("EVENT_BEAT_MT_MOON_EXIT_SUPER_NERD"),true) end
            end)
        end)
        test(id.." actual loss leaves progression and rewards available",function()
            trainerPlane(id,function(g,c,token,battle)
                g:getPlayerPokemon():takeDamage(g:getPlayerPokemon().maxHP)
                terminal(c,token,battle,"defeat")
                eq(g.session:trainerDefeated(id),false)
                eq(g.session:questFlag("BADGE_CASCADE"),false)
                eq(g.session:questFlag("EVENT_BEAT_MT_MOON_EXIT_SUPER_NERD"),false)
            end)
        end)
    end
    test("Misty full-bag TM retry persists badge and never duplicates TM11",function()
        local g=fresh();assert(g.session:setTrainerDefeated(MISTY,true))
        assert(g.session:setQuestFlag("BADGE_CASCADE",true))
        local discard=fullBag(g.session,"tm11")
        local plan=assert(SourceEvents.rewardPlan(MISTY,observe(g)))
        eq(g.session:transact(plan.expected,plan.changes),false)
        eq(g.session:questFlag("EVENT_GOT_TM11"),false)
        g.session=restore(g);eq(g.session:questFlag("BADGE_CASCADE"),true)
        assert(g.session:inventory():consume(discard,1))
        plan=assert(SourceEvents.rewardPlan(MISTY,observe(g)))
        assert(g.session:transact(plan.expected,plan.changes))
        g.session=restore(g)
        eq(SourceEvents.rewardPlan(MISTY,observe(g)),nil)
        eq(g.session:inventory():quantity("tm11"),1)
    end)
    test("actual Bill departure preserves full-bag gift retry and resets only pre-help setup",function()
        local g=fresh()
        assert(g.session:setQuestFlag("EVENT_BILL_SAID_USE_CELL_SEPARATOR",true))
        assert(CeruleanStory.onHouseExit(g.session))
        eq(g.session:questFlag("EVENT_BILL_SAID_USE_CELL_SEPARATOR"),false)
        assert(g.session:setQuestFlag("EVENT_MET_BILL",true))
        assert(g.session:setQuestFlag("EVENT_MET_BILL_2",true))
        assert(CeruleanStory.onHouseExit(g.session))
        eq(g.session:questFlag("EVENT_LEFT_BILLS_HOUSE_AFTER_HELPING"),false)
        assert(g.session:setQuestFlag("EVENT_GOT_SS_TICKET",true))
        assert(CeruleanStory.onHouseExit(g.session))
        eq(g.session:questFlag("EVENT_LEFT_BILLS_HOUSE_AFTER_HELPING"),true)
        eq(CeruleanStory.leftHousePlan(g.session),nil)
    end)
    test("source PC projects the facing target and fossil trigger does not fire after victory",function()
        local g=fresh()
        local player = CeruleanStory.pcPlayer()
        eq(player.x,1);eq(player.y,5);eq(player.facing,"up")
        eq(player.id,"pokered:BILLS_HOUSE:hidden_events:1")
        local name = SourceMaps.nameForID("pokered:BILLS_HOUSE")
        local offset = name and SourceMaps.entry(name).padding or 0
        eq(CeruleanStory.pcInteraction("pokered:BILLS_HOUSE",player.x+offset,player.y,"up"),player.id)
        eq(CeruleanStory.pcInteraction("pokered:BILLS_HOUSE",1+offset,4,"up"),nil)
        for _, facing in ipairs({"down","left","right"}) do
            eq(CeruleanStory.pcInteraction("pokered:BILLS_HOUSE",player.x+offset,player.y,facing),nil)
        end
        eq(CeruleanStory.pcInteraction("pokered:MT_MOON_B2F",player.x,player.y,"up"),nil)
        eq(CeruleanStory.trigger(g.session,"pokered:MT_MOON_B2F",13,8),NERD)
        assert(g.session:setTrainerDefeated(NERD,true))
        eq(CeruleanStory.trigger(g.session,"pokered:MT_MOON_B2F",13,8),nil)
        eq(CeruleanStory.suppressEncounters(g.session,"pokered:MT_MOON_B2F",11,5),true)
        eq(CeruleanStory.suppressEncounters(g.session,"pokered:MT_MOON_B2F",10,5),false)
    end)
    return report
end
