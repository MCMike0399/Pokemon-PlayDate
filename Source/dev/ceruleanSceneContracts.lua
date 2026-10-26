-- Requires root's actual imported-map fixture. No synthetic SDK or actor owner.
-- withScene(mapName, {x,y,facing,quest,trainers}, fn) supplies a fresh context,
-- CeruleanEventState and DialogState registrations, real source sprites,
-- NPCMotion attachment, and cleanup restoring world/RNG/provider state.
CeruleanSceneContracts = {}
local BILL <const> = "pokered:BILLS_HOUSE:objects:"
local PC <const> = "pokered:BILLS_HOUSE:hidden_events:1"
local function eq(a,b) assert(a==b,"expected "..tostring(b)..", got "..tostring(a)) end
local function drainDialog(g)
    for _=1,256 do
        if g.machine:getCurrent()~="dialog" then return end
        local state=g.machine:get("dialog")
        state.dialog:advance()
        state:handleInput()
    end
    error("source dialogue did not settle")
end
local function settle(g)
    for _=1,512 do
        if g.machine:getCurrent()=="overworld" then return end
        if g.machine:getCurrent()=="dialog" then drainDialog(g)
        else g.machine:update() end
        assert(g.machine:get("event").phase~="failed",g.machine:get("event").waiting)
    end
    error("source scene did not settle")
end
-- Default fixture uses the actual merged map registry, source actor resolver,
-- production zone constructor, real state machine and native SDK sprites.
function CeruleanSceneContracts.withScene(name, options, fn)
    local oldZone=currentZone
    local oldOwner=GameSession.activeRNGSession()
    local oldRNG=RulesRNG.snapshot()
    local restoreTiles=WorldTiles:checkpointRuntime()
    local g,zone
    local ok,problem=pcall(function()
        local entry=SourceMaps.entry(name) -- Missing integration fails, never skips.
        assert(entry.profile=="source","Cerulean source map fixture required")
        g=GameContext({sessionLocationPolicy=PewterWorld.locationPolicy()})
        assert(g:recruit(Pokemon("squirtle",5)))
        assert(g.session:setIntro({stage="done",starter="squirtle",rivalStarter="bulbasaur"}))
        for id,value in pairs(options.quest or {}) do assert(g.session:setQuestFlag(id,value)) end
        for id,value in pairs(options.trainers or {}) do assert(g.session:setTrainerDefeated(id,value)) end
        g.trainers=TrainerEvents(g)
        local profiles=SourceMaps.legacyProfiles({dispatch=function(id) return SourceEvents.dispatch(g,id) end,
            questFlag=function(id) return g.session:questFlag(id) end,
            sourceFlag=function(id) return g.trainers:sourceFlag(id) end})
        zone=SourceMaps.createZone(name,profiles.source,WorldTiles)
        currentZone=zone
        g.player=Player(options.x+entry.padding,options.y,zone.collision,g.npcManager)
        g.player.facing=options.facing
        g.player:setImage(SpriteFactory.playerStand[options.facing])
        local sub=StateMachine();sub:register("explore",{});sub:change("explore")
        g.machine:register("overworld",{sub=sub})
        g.machine:register("event",CeruleanEventState(g))
        g.machine:register("dialog",DialogState(g))
        g.machine:change("overworld")
        zone:spawnNPCs(g.npcManager)
        g.npcManager.motion:attach(g,zone)
        CeruleanStory.reconcileActors(g)
        assert(g.session:activateRNG())
        fn(g)
    end)
    if g then
        while g.machine:depth()>0 do g.machine:pop() end
        g.npcManager:clear()
        if g.player then g.player:remove();g.player.grassOverlay:remove();g.player.exitArrow:remove() end
    end
    if zone then zone:disposeView() end
    restoreTiles()
    local active=GameSession.activeRNGSession()
    if active then active:deactivateRNG() end
    if oldOwner then oldOwner:activateRNG() end
    RulesRNG.restore(oldRNG)
    currentZone=oldZone
    assert(ok,problem)
end
function CeruleanSceneContracts.run(withScene)
    withScene=withScene or CeruleanSceneContracts.withScene
    assert(type(withScene)=="function", "root imported Cerulean map fixture required; no simulated fallback")
    local report={ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)
        local ok,problem=pcall(fn)
        report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(problem) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    for _, yes in ipairs({true,false}) do
        test("Bill source "..(yes and "YES" or "NO").." input enters machine then requires separate PC interaction",function()
            withScene("BillsHouse",{x=6,y=6,facing="up"},function(g)
                SourceEvents.dispatch(g,BILL.."1")
                drainDialog(g)
                local event=g.machine:get("event")
                eq(event.phase,"story-choice")
                event:handleButton(yes and "a" or "b")
                settle(g)
                eq(g.session:questFlag("EVENT_BILL_SAID_USE_CELL_SEPARATOR"),true)
                eq(g.session:questFlag("EVENT_USED_CELL_SEPARATOR_ON_BILL"),false)
                eq(g.session:questFlag("EVENT_MET_BILL"),false)
                eq(g.session:inventory():quantity("ssTicket"),0)
            end)
        end)
    end
    test("Bill walks around a player facing down using the source five-cell route",function()
        withScene("BillsHouse",{x=6,y=4,facing="down"},function(g)
            SourceEvents.dispatch(g,BILL.."1");drainDialog(g)
            g.machine:get("event"):handleButton("a")
            settle(g)
            eq(g.session:questFlag("EVENT_BILL_SAID_USE_CELL_SEPARATOR"),true)
            eq(g.session:questFlag("EVENT_MET_BILL"),false)
        end)
    end)
    test("Bill PC player stands on walkable floor facing the blocked source target",function()
        withScene("BillsHouse",{x=1,y=5,facing="up"},function(g)
            local player = g.player
            eq(currentZone.collision[player.gridY+1][player.gridX+1],0)
            eq(currentZone.collision[player.gridY][player.gridX+1],1)
            eq(CeruleanStory.pcInteraction(currentZone.stableID,player.gridX,player.gridY,player.facing),PC)
            eq(CeruleanStory.pcInteraction(currentZone.stableID,player.gridX,player.gridY-1,"up"),nil)
            for _, facing in ipairs({"down","left","right"}) do
                eq(CeruleanStory.pcInteraction(currentZone.stableID,player.gridX,player.gridY,facing),nil)
            end
        end)
    end)
    test("cancelling the separator wait cannot restore Bill through a stale update",function()
        withScene("BillsHouse",{x=1,y=5,facing="up",quest={EVENT_BILL_SAID_USE_CELL_SEPARATOR=true}},function(g)
            -- Match from the real player cell; (1,4) is the blocked PC target.
            eq(CeruleanStory.pcInteraction(currentZone.stableID,g.player.gridX,g.player.gridY,g.player.facing),PC)
            SourceEvents.dispatch(g,PC);drainDialog(g)
            local event=g.machine:get("event")
            eq(event.phase,"story-machine")
            for _=1,20 do event:update() end
            g.machine:change("overworld")
            for _=1,160 do event:update() end
            eq(g.session:questFlag("EVENT_USED_CELL_SEPARATOR_ON_BILL"),false)
            eq(g.session:questFlag("EVENT_MET_BILL"),false)
        end)
    end)
    test("Bill PC sequence restores human without awarding Ticket before talk",function()
        withScene("BillsHouse",{x=1,y=5,facing="up",quest={EVENT_BILL_SAID_USE_CELL_SEPARATOR=true}},function(g)
            -- Match from the real player cell; (1,4) is the blocked PC target.
            eq(CeruleanStory.pcInteraction(currentZone.stableID,g.player.gridX,g.player.gridY,g.player.facing),PC)
            SourceEvents.dispatch(g,PC)
            drainDialog(g)
            local event=g.machine:get("event")
            eq(event.phase,"story-machine")
            for _=1,133 do event:update() end
            eq(g.session:questFlag("EVENT_USED_CELL_SEPARATOR_ON_BILL"),false)
            settle(g)
            eq(g.session:questFlag("EVENT_USED_CELL_SEPARATOR_ON_BILL"),true)
            eq(g.session:questFlag("EVENT_MET_BILL"),true)
            eq(g.session:questFlag("EVENT_MET_BILL_2"),true)
            eq(g.session:inventory():quantity("ssTicket"),0)
            SourceEvents.dispatch(g,BILL.."2")
            settle(g)
            eq(g.session:inventory():quantity("ssTicket"),1)
            SourceEvents.dispatch(g,BILL.."2")
            settle(g)
            eq(g.session:inventory():quantity("ssTicket"),1)
        end)
    end)
    test("persistent intermediate separator data resumes exit without repeating machine",function()
        withScene("BillsHouse",{x=1,y=5,facing="up",quest={EVENT_BILL_SAID_USE_CELL_SEPARATOR=true,
            EVENT_USED_CELL_SEPARATOR_ON_BILL=true}},function(g)
            -- Match from the real player cell; (1,4) is the blocked PC target.
            eq(CeruleanStory.pcInteraction(currentZone.stableID,g.player.gridX,g.player.gridY,g.player.facing),PC)
            SourceEvents.dispatch(g,PC)
            eq(g.machine:getCurrent(),"event")
            eq(g.machine:get("event").waiting,"bill-emerges")
            settle(g)
            eq(g.session:questFlag("EVENT_MET_BILL"),true)
            eq(g.session:inventory():quantity("ssTicket"),0)
        end)
    end)
    test("stale Bill dialogue callback cannot start machine or acquire new lease",function()
        withScene("BillsHouse",{x=6,y=6,facing="up"},function(g)
            SourceEvents.dispatch(g,BILL.."1")
            local callback=assert(g.machine:get("dialog").onComplete)
            local event=g.machine:get("event")
            g.machine:change("overworld")
            callback()
            eq(g.session:questFlag("EVENT_BILL_SAID_USE_CELL_SEPARATOR"),false)
            eq(g.session:inventory():quantity("ssTicket"),0)
            eq(event.active,false)
            eq(next(event.npcLeases),nil)
        end)
    end)
    test("cancelled Bill interpolation releases lease; stale token cannot move new owner",function()
        withScene("BillsHouse",{x=6,y=6,facing="up"},function(g)
            SourceEvents.dispatch(g,BILL.."1");drainDialog(g)
            local event=g.machine:get("event");event:handleButton("a");drainDialog(g)
            eq(event.phase,"move-npc")
            local old=assert(event.npcLeases[BILL.."1"])
            local motion=g.npcManager.motion
            local rolls=g.session:worldRngData().rolls
            for _=1,10 do event:update() end -- One completed cell and one partial cell.
            local moved=assert(g.npcManager:getNPCAt(g.player.gridX,4))
            eq(motion:actor(moved).y,4)
            g.machine:change("overworld")
            eq(motion:actor(moved).y,5)
            eq(g.session:worldRngData().rolls,rolls)
            eq(g.session:questFlag("EVENT_BILL_SAID_USE_CELL_SEPARATOR"),false)
            eq(motion:updateScript(old),false)
            SourceEvents.dispatch(g,BILL.."1");drainDialog(g)
            local npc
            for _, actor in ipairs(g.npcManager.npcs) do
                if actor.def and actor.def.source_event_id==BILL.."1" then npc=actor end
            end
            local token=assert(motion:claimScript(assert(npc),event))
            eq(motion:claimScript(npc,event),nil)
            eq(motion:startScriptStep(old,"up"),false)
            assert(motion:releaseScript(token))
        end)
    end)
    for _, choice in ipairs({{index=6,item="domeFossil",x=12,other="helixFossil"},
                              {index=7,item="helixFossil",x=13,other="domeFossil"}}) do
        test("source affirmative fossil "..choice.item.." leaves only one durable reward",function()
            withScene("MtMoonB2F",{x=choice.x,y=7,facing="up",quest={EVENT_BEAT_MT_MOON_EXIT_SUPER_NERD=true},
                trainers={["pokered:MT_MOON_B2F:objects:1"]=true}},function(g)
                SourceEvents.dispatch(g,"pokered:MT_MOON_B2F:objects:"..choice.index);drainDialog(g)
                g.machine:get("event"):handleButton("a");settle(g)
                eq(g.session:inventory():quantity(choice.item),1)
                eq(g.session:inventory():quantity(choice.other),0)
                SourceEvents.dispatch(g,"pokered:MT_MOON_B2F:objects:"..(choice.index==6 and 7 or 6));settle(g)
                eq(g.session:inventory():quantity(choice.other),0)
            end)
        end)
    end
    test("fossil NO cancels without changing bag or either completion flag",function()
        withScene("MtMoonB2F",{x=12,y=7,facing="up",quest={EVENT_BEAT_MT_MOON_EXIT_SUPER_NERD=true},
            trainers={["pokered:MT_MOON_B2F:objects:1"]=true}},function(g)
            SourceEvents.dispatch(g,"pokered:MT_MOON_B2F:objects:6");drainDialog(g)
            local event=g.machine:get("event");eq(event.phase,"story-choice")
            event:handleButton("b")
            eq(g.machine:getCurrent(),"overworld")
            eq(g.session:inventory():quantity("domeFossil"),0)
            eq(g.session:questFlag("EVENT_GOT_DOME_FOSSIL"),false)
            eq(g.session:questFlag("EVENT_GOT_HELIX_FOSSIL"),false)
        end)
    end)
    return report
end
