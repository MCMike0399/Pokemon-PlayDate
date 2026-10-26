-- Root-only native SDK witnesses. These use currently tracked source sprites,
-- the real event overlay and the real session codec; workers never run them.
ScriptedNPCContracts = {}
local gfx = playdate.graphics
local function eq(a,b) assert(a==b,"expected "..tostring(b)..", got "..tostring(a)) end
local function same(a,b)
    assert(type(a)==type(b),"different value types")
    if type(a)~="table" then eq(a,b);return end
    for key,value in pairs(a) do same(value,b[key]) end
    for key in pairs(b) do assert(a[key]~=nil,"missing field "..tostring(key)) end
end
local function scene(fn, positions)
    local oldZone,oldStory,oldOwner = currentZone,Story.currentContext(),GameSession.activeRNGSession()
    local rules,count = RulesRNG.toData(),gfx.sprite.spriteCount()
    local offsetX,offsetY = gfx.getDrawOffset()
    local originalPositions = SourceEvents.actorPositions
    local g
    local ok,problem = pcall(function()
        -- A test-only source metadata adapter declares a STAY position. Shipped
        -- descriptors remain untouched and contain no newly authored story.
        if positions then
            SourceEvents.actorPositions = function(id)
                if id=="pokered:PEWTER_MART:objects:3" then
                    return SourceEvents.validateActorPositions(id,positions)
                end
                return originalPositions(id)
            end
        end
        g=GameContext({sessionLocationPolicy=PewterWorld.locationPolicy()})
        assert(g:recruit(Pokemon("squirtle",5)))
        assert(g.session:setIntro({stage="done",starter="squirtle",rivalStarter="bulbasaur"}))
        currentZone=PewterWorld.isolated("PewterMart")
        PewterSprites.installFor(PewterSlice.padded("PewterMart"))
        g.player=Player(5,6,currentZone.collision,g.npcManager)
        currentZone:spawnNPCs(g.npcManager)
        local sub=StateMachine();sub:register("explore",{});sub:change("explore")
        g.machine:register("overworld",{sub=sub})
        g.machine:register("event",EventState(g));g.machine:register("dialog",DialogState(g))
        g.machine:change("overworld");g.npcManager.motion:attach(g,currentZone)
        fn(g,g.npcManager.motion)
    end)
    if g then
        for i=#g.machine.stack,1,-1 do g.machine.stack[i]:exit();g.machine.stack[i]=nil end
        g.npcManager:clear()
        if g.player then g.player:remove();g.player.grassOverlay:remove();g.player.exitArrow:remove() end
    end
    SourceEvents.actorPositions=originalPositions
    currentZone=oldZone;Story.bind(oldStory)
    if oldOwner then oldOwner:activateRNG() end
    RulesRNG.restoreData(rules);gfx.setDrawOffset(offsetX,offsetY)
    assert(ok,problem);eq(gfx.sprite.spriteCount(),count)
end
local function start(g,id,direction,count)
    g.machine:push("event","pokered:PEWTER_MART:objects:2")
    local event=g.machine:get("event")
    eq(g.machine:getCurrent(),"dialog")
    event.ops={};event.index=1
    for _=1,count or 1 do event.ops[#event.ops+1]={op="move-npc",id=id,direction=direction} end
    local dialog=g.machine:get("dialog")
    dialog.dialog.onComplete();dialog:handleInput()
    return event
end
local function persist(g,m,npc)
    local location={zone_id=currentZone.stableID,x=g.player.gridX,y=g.player.gridY,facing=g.player.facing}
    local expected=m:snapshot()
    assert(g.session:captureTraversal({location=location,world=WorldDeltas.export(),actors=expected}))
    local wire=assert(SessionCodec.encode(g.session,{root="overworld",overworld="explore",settled=true}))
    local restored=assert(SessionCodec.decode(wire,g:getSessionDependencies()))
    g.session=restored;m:attach(g,currentZone,restored:actorData())
    same(m:snapshot(),expected)
    eq(npc.x,npc.gridX*TILE_SIZE);eq(npc.y,npc.gridY*TILE_SIZE-8)
end
function ScriptedNPCContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)
        local ok,problem=pcall(fn)
        report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(problem) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    local walker="pokered:PEWTER_MART:objects:2"
    test("script position metadata is detached, bounded and scoped to a stable source object",function()
        local positions={{x=7,y=6}}
        local result=SourceEvents.validateActorPositions("pokered:PEWTER_MART:objects:3",positions)
        result[1].x=1;eq(positions[1].x,7)
        for _,bad in ipairs({{{x=true,y=6}},{{x=-1,y=6}},{{x=7,y=1024}},
            {{x=7,y=6,bypass=true}},{{x=7,y=6},{x=7,y=6}}}) do
            eq(pcall(SourceEvents.validateActorPositions,walker,bad),false)
        end
        eq(pcall(SourceEvents.validateActorPositions,"pokered:PEWTER_MART:script:escort",positions),false)
    end)
    test("tracked WALK event uses eight source-art frames, reserves both cells and persists final pose without RNG",function()
        scene(function(g,m)
            local npc=g.npcManager.npcs[2]
            eq(npc.def.source_event_id,walker);eq(m:actor(npc).phase,"ready")
            local world,rules=g.session:worldRngData(),RulesRNG.toData()
            local event=start(g,walker,"down",2)
            eq(event.phase,"move-npc")
            for frame=1,16 do
                local origin=frame<=8 and 3 or 4
                eq(g.npcManager:getNPCAt(5,origin),npc)
                eq(g.npcManager:getNPCAt(5,origin+1),npc)
                event:update();if frame<16 then m:tick() end
                if frame<16 then eq(g.machine:getCurrent(),"event") end
                if frame%8~=0 then
                    eq(npc.gridY,origin)
                    eq(npc.y,(origin+(frame%8)/8)*TILE_SIZE-8)
                    eq(npc:getImage(),PewterSprites.stepImage("SPRITE_YOUNGSTER","down",frame%8))
                end
            end
            eq(npc.gridY,5);eq(npc.isMoving,false);eq(g.machine:getCurrent(),"overworld")
            -- Do not tick exploration after the last frame: autonomy is allowed
            -- to draw its normal RNG once the script has returned control.
            same(g.session:worldRngData(),world);same(RulesRNG.toData(),rules)
            persist(g,m,npc)
        end)
    end)
    test("cancel retains completed cell, rolls back incomplete cell and rejects old event token",function()
        scene(function(g,m)
            local npc=g.npcManager.npcs[2]
            local event=start(g,walker,"down",2)
            for _=1,8 do event:update() end
            local token=event.npcMove.token
            for _=1,4 do event:update() end
            eq(npc.y,4.5*TILE_SIZE-8)
            g.machine:change("overworld")
            eq(npc.gridY,4);eq(npc.y,4*TILE_SIZE-8);eq(npc.isMoving,false)
            eq(m:updateScript(token),false);eq(m:startScriptStep(token,"up"),false)
            eq(m:releaseScript(token),false)
            persist(g,m,npc)
            local rolls=g.session:worldRngData().rolls
            m:tick();assert(g.session:worldRngData().rolls~=rolls,"autonomous owner did not resume")
        end)
    end)
    test("attachment epoch and session identity invalidate script advancement",function()
        scene(function(g,m)
            local event=start(g,walker,"down",1)
            local token=event.npcMove.token
            local zone=currentZone;currentZone={}
            eq(m:updateScript(token),false);currentZone=zone
            local saved=m:snapshot()
            m:attach(g,currentZone,saved)
            eq(m:updateScript(token),false);eq(m:releaseScript(token),false)
            eq(g.npcManager.npcs[2].gridY,3)
            g.machine:change("overworld")
            event=start(g,walker,"down",1);token=event.npcMove.token
            local session=g.session;g.session={}
            eq(m:updateScript(token),false)
            g.session=session;g.machine:change("overworld")
        end)
    end)
    test("script blocks player, source collision, other actors, home escape and protected warp cells",function()
        scene(function(g,m)
            local npc=g.npcManager.npcs[2]
            local event=start(g,walker,"down",1)
            assert(m:releaseScript(event.npcMove.token))
            local token=assert(m:claimScript(npc,event))
            event.npcLeases[walker]=token
            local blocker=NPC(5,2,"BLOCKER",{},nil,"rival","down")
            blocker.def={source_event_id="contract:script-blocker"};g.npcManager:addNPC(blocker)
            eq(m:startScriptStep(token,"up"),false)
            g.npcManager:removeNPC(blocker)
            eq(m:startScriptStep(token,"left"),false) -- UP_DOWN home policy
            assert(m:startScriptStep(token,"up"))
            for _=1,8 do m:updateScript(token) end
            eq(npc.gridY,2)
            eq(m:startScriptStep(token,"up"),false) -- counter collision
            for target=3,5 do
                assert(m:startScriptStep(token,"down"))
                for _=1,8 do m:updateScript(token) end
                eq(npc.gridY,target)
            end
            eq(m:startScriptStep(token,"down"),false) -- player at 5,6
            g.player.gridX=4;g.player:moveTo(4*TILE_SIZE,6*TILE_SIZE)
            assert(m:startScriptStep(token,"down"))
            for _=1,8 do m:updateScript(token) end
            eq(npc.gridY,6)
            eq(m:startScriptStep(token,"down"),false) -- protected exit at 5,7
            eq(npc.gridY,6)

        end)
    end)
    test("STAY metadata permits only explicit legal positions and preserves settled codec policy",function()
        scene(function(g,m)
            local d=SourceActors.describe(currentZone.stableID,WorldDeltas.export())
            local spec=d.actors[3]
            eq(spec.movement,"STAY")
            assert(spec.script_positions[6*d.width+7+1])
            eq(d.canStand(spec,7,6,currentZone),true)
            eq(d.canWanderStep(spec,spec.x,spec.y,7,6,currentZone),false)
            local event=start(g,spec.id,"down",1)
            eq(event.phase,"move-npc")
            for _=1,8 do event:update() end
            local npc=g.npcManager.npcs[3]
            eq(npc.gridY,6);persist(g,m,npc)
            event=start(g,spec.id,"left",1)
            eq(event.phase,"failed");eq(npc.gridX,7);eq(npc.gridY,6)
        end,{{x=7,y=6}})
    end)
    return report
end
