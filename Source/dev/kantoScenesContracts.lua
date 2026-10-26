-- Root-run native integration witnesses. Requires installed KantoScenes and the
-- promoted real map manifest; missing composition fails rather than skipping.
KantoScenesContracts = {}
local BILL <const> = "pokered:BILLS_HOUSE:objects:1"
local function eq(a,b) assert(a==b,"expected "..tostring(b)..", got "..tostring(a)) end
local function find(g,id)
    for _, npc in ipairs(g.npcManager.npcs) do
        if npc.def and npc.def.source_event_id == id then return npc end
    end
end
local function scene(fn)
    CeruleanSceneContracts.withScene("BillsHouse",{x=6,y=6,facing="up"},fn)
end
local function frozenBattle(g,id)
    SourceEvents.dispatch(g,id)
    local event = g.machine:get("event")
    for _=1,512 do
        assert(event.phase ~= "failed",event.waiting)
        if event.trainerToken and g.machine:getCurrent()=="dialog" then break end
        if g.machine:getCurrent()=="dialog" then
            local dialog = g.machine:get("dialog")
            dialog.dialog:advance(); dialog:handleInput()
        else g.machine:update() end
    end
    local token = assert(event.trainerToken,"scene did not prepare its trainer")
    g.machine:pop() -- Hold the real token before its launch callback.
    local selected = g.trainers:snapshot()
    local firstSpecies = selected.party[1].species
    selected.party[1].species = "rattata"
    eq(g.trainers:snapshot().party[1].species,firstSpecies)
    selected.party[1].species = firstSpecies
    local party = assert(g.trainers:launch(token))
    local battle = Battle(g:getPlayerPokemon(),party:active(),assert(find(g,id)).name,
        {party=g.session:party(),session=g.session,enemyParty=party})
    assert(g.trainers:attachBattle(token,battle))
    for _, mon in ipairs(party:members()) do mon:takeDamage(mon.maxHP) end
    battle:runScript(function() return "victory" end)
    local receipt
    battle:on("battleEnd",function(won,kind)
        local ok,result = g.trainers:resolve(token,won,kind)
        assert(ok,result); receipt=result
    end)
    assert(battle:emitEnd())
    assert(receipt)
    g.machine:pop() -- Return to actual fixture overworld, with receipt unclaimed.
    return selected,receipt
end
function KantoScenesContracts.run()
    local report = {ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)
        local ok,problem = pcall(fn)
        report.tests[#report.tests+1] = {name=name,ok=ok,error=not ok and tostring(problem) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1; report.ok=false end
    end
    test("world boundaries preserve registration order and first claim",function()
        scene(function(g)
            SourceEvents._withWorldHooks(function()
                local seen = {}
                SourceEvents.registerWorldHooks(BILL,{
                    beforeSpawn=function() seen[#seen+1]="spawn" end,
                    onEnter=function() seen[#seen+1]="enter" end,
                    explore=function() seen[#seen+1]="first"; return true end,
                    onLeave=function(_,to) seen[#seen+1]=to end,
                })
                SourceEvents.registerWorldHooks("pokered:BILLS_HOUSE:objects:2",{
                    explore=function() error("second scene claimed the same frame") end})
                SourceEvents.worldHook("beforeSpawn",g,{})
                SourceEvents.worldHook("onEnter",g)
                eq(SourceEvents.worldHook("explore",g),true)
                SourceEvents.worldHook("onLeave",g,"pokered:ROUTE_25")
                eq(table.concat(seen,","),"spawn,enter,first,pokered:ROUTE_25")
                assert(not pcall(SourceEvents.registerWorldHooks,BILL,{}))
            end)
        end)
    end)
    test("movement traversal and overlays exclude world triggers",function()
        scene(function(g)
            SourceEvents._withWorldHooks(function()
                SourceEvents.registerWorldHooks(BILL,{explore=function() error("unsettled trigger") end})
                g.player.isMoving=true; eq(SourceEvents.worldHook("explore",g),false);g.player.isMoving=false
                g.player.pendingConnection={};eq(SourceEvents.worldHook("explore",g),false);g.player.pendingConnection=nil
                g.player.pendingEdgeDoor={};eq(SourceEvents.worldHook("explore",g),false);g.player.pendingEdgeDoor=nil
                g.machine:push("dialog",{"Overlay guard"})
                eq(SourceEvents.worldHook("explore",g),false)
                g.machine:pop()
            end)
        end)
    end)
    test("an overlay claims the hook boundary even without a return value",function()
        scene(function(g)
            SourceEvents._withWorldHooks(function()
                SourceEvents.registerWorldHooks(BILL,{interact=function() g.machine:push("dialog",{"Claim"}) end})
                SourceEvents.registerWorldHooks("pokered:BILLS_HOUSE:objects:2",{
                    interact=function() error("double dispatch") end})
                eq(SourceEvents.worldHook("interact",g),true)
                g.machine:pop()
            end)
        end)
    end)
    test("lease facing reset restores claim origin and stale attachments reject it",function()
        scene(function(g)
            SourceEvents.dispatch(g,BILL)
            g.machine:pop() -- A real scene owner remains below its dialog.
            local owner, motion = g.machine:get("event"), g.npcManager.motion
            local npc = assert(find(g,BILL))
            local x,y,facing = npc.gridX,npc.gridY,npc.facing
            local lease = assert(motion:claimScript(npc,owner))
            assert(motion:placeScript(lease,x,y-1,"up"))
            assert(motion:resetScript(lease))
            eq(npc.gridX,x);eq(npc.gridY,y);eq(npc.facing,facing)
            g.machine:push("dialog",{"Lease guard"})
            eq(motion:faceScript(lease,"left"),false)
            g.machine:pop()
            assert(motion:releaseScript(lease))
            local nextLease = assert(motion:claimScript(npc,owner))
            eq(motion:resetScript(lease),false)
            assert(motion:releaseScript(nextLease))
            local stale = assert(motion:claimScript(npc,owner))
            motion:attach(g,currentZone,motion:snapshot())
            eq(motion:resetScript(stale),false)
        end)
    end)
    test("fixture content namespace restores exact production art after an error",function()
        local before = SourceActors.stepImage("SPRITE_BLUE","down",1,"source")
        local fixture = playdate.graphics.image.new(32,32)
        local resolver = {sprite=function() end,key=function() end,
            install=function() end,stepImage=function() return fixture end}
        local ok,problem = pcall(function()
            SourceActors._withContent(function()
                SourceActors.registerContent("source",resolver)
                eq(SourceActors.stepImage("SPRITE_BLUE","down",1,"source"),fixture)
                assert(not pcall(SourceActors.registerContent,"source",resolver))
                error("expected fixture failure")
            end)
        end)
        eq(ok,false)
        assert(tostring(problem):find("expected fixture failure",1,true),problem)
        eq(SourceActors.stepImage("SPRITE_BLUE","down",1,"source"),before)
        assert(not pcall(SourceActors.registerContent,"source",resolver))
    end)
    test("ordinary actor rebuild preserves saved timers and both RNG streams",function()
        CeruleanRoutesContracts.withScene("CeruleanCity",{x=19,y=18},function(g)
            local function same(a,b)
                eq(type(a),type(b))
                if type(a) ~= "table" then eq(a,b);return end
                for key,value in pairs(a) do same(value,b[key]) end
                for key in pairs(b) do assert(a[key] ~= nil,"unexpected actor field") end
            end
            local before = g.npcManager.motion:snapshot()
            local rng = RulesRNG.toData()
            local worldRng = g.session:worldRngData()
            KantoScenes.reconcileActors(g)
            same(before,g.npcManager.motion:snapshot())
            same(rng,RulesRNG.toData())
            same(worldRng,g.session:worldRngData())
        end)
    end)
    test("receipt rebuild restores rival pose while static metadata stays pure",function()
        local scenes = CeruleanRoutes.scenes()
        local trigger = scenes.triggers.cerulean[1]
        CeruleanRoutesContracts.withScene("CeruleanCity",{x=trigger.x,y=trigger.y},function(g)
            local id = CeruleanRoutes.RIVAL
            SourceActors.refresh(g,currentZone)
            local selected, receipt = frozenBattle(g,id)
            eq(selected.id,id);eq(selected.payout,receipt.payout)
            assert(#selected.party > 1)
            local def,event = {},{id=id}
            eq(#KantoScenes.actorMetadata(def,event,g).visibility,0)
            local oldStory = Story
            Story = setmetatable({},{__index=function() error("pure metadata read live Story") end})
            local ok,static = pcall(KantoScenes.actorMetadata,def,event)
            Story = oldStory
            assert(ok,static)
            eq(static.visibility[1].group,"trainers")
            eq(static.visibility[1].equals,false)
            KantoScenes.reconcileActors(g)
            assert(find(g,id))
            assert(g.trainers:restoreReturnedTrainer())
            local npc = assert(find(g,id))
            eq(npc.gridX,receipt.position.x);eq(npc.gridY,receipt.position.y);eq(npc.facing,receipt.position.facing)
            eq(g.trainers:peekReceipt(id).id,id) -- Observation/rebuild never claims it.
            SourceEvents.dispatch(g,id) -- Only EventState entry consumes the receipt.
            eq(g.trainers:peekReceipt(id),nil)
            -- Abort presentation, then an explicit rebuild follows durable flags.
            while g.machine:getCurrent()~="overworld" do g.machine:pop() end
            KantoScenes.reconcileActors(g)
            eq(find(g,id),nil)
        end)
    end)
    return report
end
