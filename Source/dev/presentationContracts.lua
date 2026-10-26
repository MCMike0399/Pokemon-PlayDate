PresentationContracts={}
local gfx=playdate.graphics
local function eq(a,b,label)assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a))end
local function same(a,b)
    if type(a)~=type(b)then return false end
    if type(a)~="table"then return a==b end
    for k,v in pairs(a)do if not same(v,b[k])then return false end end
    for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local function observed(g)
    local p=g.player;local npcs={}
    for _,npc in ipairs(g.npcManager.npcs)do npcs[#npcs+1]={x=npc.x,y=npc.y,image=npc:getImage(),facing=npc.facing,enabled=npc:updatesEnabled()}end
    return {actors=g.npcManager.motion:snapshot(),world=g.session:worldRngData(),rules=RulesRNG.toData(),
        player={x=p.x,y=p.y,gx=p.gridX,gy=p.gridY,frames=p.moveFrames,moving=p.isMoving,toggle=p.walkToggle,rustle=p.rustleFrames,image=p:getImage(),enabled=p:updatesEnabled()},npcs=npcs}
end
local function oracle(g,view)
    local image=gfx.image.new(400,240,gfx.kColorWhite);local map=view:render()
    gfx.pushContext(image);gfx.clearClipRect();gfx.clearStencil();gfx.setImageDrawMode(gfx.kDrawModeCopy);g.camera:apply()
    map:draw(0,0)
    for _,npc in ipairs(g.npcManager.npcs)do npc:getImage():draw(npc.x,npc.y)end
    g.player:getImage():draw(g.player.x,g.player.y)
    gfx.popContext();return image
end
local function pixels(actual,expected)
    for y=0,239 do for x=0,399 do assert(actual:sample(x,y)==expected:sample(x,y),"native world framebuffer mismatch at "..x..","..y)end end
end
local function write(name)
    if HarnessBuild and HarnessBuild.enabled and playdate.simulator then playdate.simulator.writeToFile(gfx.getWorkingImage(),HarnessBuild.output_dir..name..".png")end
end
local function scene(fn)
    local oldZone,oldStory,oldOwner,oldRng=currentZone,Story.currentContext(),GameSession.activeRNGSession(),RulesRNG.toData()
    local ox,oy=gfx.getDrawOffset();local oldSprites,sets={},{};local count=gfx.sprite.spriteCount();local ids=WorldTiles:maxID()
    local oldScreen=gfx.getWorkingImage():copy();local g,view
    for _,sprite in ipairs(gfx.sprite.getAllSprites())do oldSprites[sprite]={visible=sprite:isVisible(),enabled=sprite:updatesEnabled()};sprite:setVisible(false);sprite:setUpdatesEnabled(false)end
    for key,value in pairs(SpriteFactory.npc)do sets[key]=value end
    local ok,problem=pcall(function()
        g=GameContext({seed=1,sessionLocationPolicy=PewterWorld.locationPolicy()});assert(g:recruit(Pokemon("squirtle",5)))
        assert(g.session:setIntro({stage="done",starter="squirtle",rivalStarter="bulbasaur"}));Story.bind(g)
        currentZone=PewterWorld.isolated("PewterMart");PewterSprites.installFor(PewterSlice.padded("PewterMart"))
        g.player=Player(5,6,currentZone.collision,g.npcManager);currentZone:spawnNPCs(g.npcManager)
        view=WorldView(currentZone)
        local w=OverworldState(g);g.machine:register("overworld",w)
        -- Use the production visit binding with an actual isolated native view;
        -- do not replace/dispose the main controller's global active WorldView.
        w.enter=function(self)
            self.builtZone=currentZone;self.sub:change("explore");self:_beginPresentationVisit(view)
        end
        g.machine:register("cover",{draw=function()g.camera:reset();gfx.setColor(gfx.kColorBlack);gfx.fillRect(0,0,400,240)end})
        g.machine:register("pause",PauseState(g));g.machine:change("overworld")
        local px,py=g.player:getPixelCenter();g.camera:snapTo(px,py,currentZone.width*TILE_SIZE,currentZone.height*TILE_SIZE)
        g.npcManager.motion:attach(g,currentZone)
        fn(g,w,view)
    end)
    if g then pcall(g.machine.change,g.machine,"cover");g.npcManager:clear();if g.player then g.player:remove();g.player.grassOverlay:remove();g.player.exitArrow:remove()end end
    if view then view:dispose()end
    for _,sprite in ipairs(gfx.sprite.getAllSprites())do if not oldSprites[sprite]then sprite:remove()end end
    for sprite,state in pairs(oldSprites)do sprite:setVisible(state.visible);sprite:setUpdatesEnabled(state.enabled)end
    for key in pairs(SpriteFactory.npc)do if not sets[key]then SpriteFactory.npc[key]=nil end end;for key,value in pairs(sets)do SpriteFactory.npc[key]=value end
    currentZone=oldZone;Story.bind(oldStory)
    local owner=GameSession.activeRNGSession();if owner~=oldOwner then if owner then owner:deactivateRNG()end;if oldOwner then oldOwner:activateRNG()end end
    RulesRNG.restoreData(oldRng);gfx.setDrawOffset(0,0);oldScreen:draw(0,0);gfx.setDrawOffset(ox,oy)
    eq(gfx.sprite.spriteCount(),count,"presentation scene cleanup sprites");eq(WorldTiles:maxID(),ids,"presentation scene cleanup registry")
    if not ok then error(problem,0)end
end
function PresentationContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)
        Contracts.progress("world-presentation",name,"running")
        local ok,problem=pcall(fn)
        Contracts.progress("world-presentation",name,"returned")
        report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(problem)or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("first entry presentation replaces actual Title framebuffer at exact decoded midstep pose without a logical tick",function()
        scene(function(g,w,view)
            local motion=g.npcManager.motion;for _=1,3 do motion:tick()end
            eq(motion:actor(g.npcManager.npcs[2]).tick,3,"source fixture midstep")
            local location={zone_id=currentZone.stableID,x=5,y=6,facing=g.player.facing}
            assert(g.session:captureTraversal({location=location,world=WorldDeltas.export(),actors=motion:snapshot()}))
            local saved=assert(SessionCodec.encode(g.session,{root="overworld",overworld="explore",settled=true}))
            g.session=assert(SessionCodec.decode(saved,g:getSessionDependencies()));motion:attach(g,currentZone,g.session:actorData());w:_beginPresentationVisit(view)
            local title=TitleState(g);title.phase="menu";title.metadata={reason="empty"};title.actions={"continue"};title.menu:show({"CONTINUE"},function()error("unexpected title selection")end);title:draw();write("presentation-title-before")
            local before=observed(g);assert(w:flushPendingPresentation());assert(same(observed(g),before),"presentation advanced saved model/native pose/RNG")
            pixels(gfx.getWorkingImage(),oracle(g,view));write("presentation-entry-midstep")
            eq(w:flushPendingPresentation(),false,"entry presents only once")
        end)
    end)
    test("actual pause and nested overlay pop repaint uncovered world before draw without advancing actors",function()
        scene(function(g,w,view)
            assert(w:flushPendingPresentation());g.machine:push("pause");g.machine:push("cover");g.machine:draw();write("presentation-overlay-before")
            local before=observed(g);g.machine:pop();eq(g.machine:getCurrent(),"pause")
            assert(w:flushPendingPresentation(),"nested overlay resume must request presentation");assert(same(observed(g),before),"nested pop render changed paused actors")
            g.machine:draw()
            local expected=oracle(g,view);gfx.pushContext(expected);g.machine:get("pause"):draw();gfx.popContext();pixels(gfx.getWorkingImage(),expected);write("presentation-nested-resume")
            g.machine:pop();before=observed(g);assert(w:flushPendingPresentation());pixels(gfx.getWorkingImage(),oracle(g,view));assert(same(observed(g),before));write("presentation-overlay-resume")
            eq(w:flushPendingPresentation(),false)
        end)
    end)
    test("normal native pass clears request and repeated draws preserve exact eight-update Player and actor cadence",function()
        scene(function(g,w)
            g.player:tryMove(1,0);eq(g.player.isMoving,true)
            for frame=1,8 do
                -- Same real native actor callback pass used by Explore, without
                -- advancing the unrelated main view's animation/frame timers.
                g.npcManager.motion:tick();g.camera:apply();gfx.sprite.update();w:_presentedWorld()
                eq(g.player.isMoving,frame<8,"eight-update player cadence")
                local before=observed(g);eq(w:flushPendingPresentation(),false,"already rendered update must not add a pass")
                for _=1,7 do w:draw();eq(w:flushPendingPresentation(),false)end
                assert(same(observed(g),before),"extra draws/presentation advanced native actors or RNG")
            end
            eq(g.player.gridX,6);eq(g.player.gridY,6)
        end)
    end)
    test("one-shot presentation suppresses callbacks and restores mixed flags on native drawing failure",function()
        scene(function(g,w)
            local calls=0;local probe=gfx.sprite.new();probe:setSize(2,2);probe:moveTo(10,20);probe:setZIndex(1000);probe:add()
            probe.update=function()calls=calls+1 end;probe.draw=function()error("controlled native presentation draw failure")end
            local playerEnabled=g.player:updatesEnabled();local npc=g.npcManager.npcs[1];npc:setUpdatesEnabled(false)
            local before=observed(g);gfx.setDrawOffset(9,11);local ok,problem=pcall(w.flushPendingPresentation,w)
            assert(not ok and tostring(problem):find("controlled native presentation draw failure",1,true));eq(calls,0)
            eq(probe:updatesEnabled(),true);eq(g.player:updatesEnabled(),playerEnabled);eq(npc:updatesEnabled(),false)
            local x,y=gfx.getDrawOffset();eq(x,9);eq(y,11);assert(same(observed(g),before),"failed presentation mutated actors/streams")
            probe:remove();assert(w.presentationVisit.pending,"failed presentation must remain reviewable/retryable")
            assert(w:flushPendingPresentation());eq(w:flushPendingPresentation(),false)
        end)
    end)
    test("disposed views replaced sessions and exited visits never flush a stale world",function()
        scene(function(g,w,view)
            local original=g.session;g.session=GameSession.newSession(g:getSessionDependencies(),{seed=9,location=original:location()})
            eq(w:flushPendingPresentation(),false);eq(w.presentationVisit.pending,false);g.session=original
            w:_beginPresentationVisit(view)
            local enabled=g.player:updatesEnabled();local npc=g.npcManager.npcs[1];npc:setUpdatesEnabled(false)
            g.machine:push("pause");eq(g.player:updatesEnabled(),false)
            g.machine:change("cover");eq(w.presentationVisit,nil);eq(w:flushPendingPresentation(),false)
            eq(g.player:updatesEnabled(),enabled,"exit restores pre-overlay player callback flag")
            eq(npc:updatesEnabled(),false,"exit preserves originally disabled NPC callback")
            g.machine:change("overworld");view:dispose();eq(w:flushPendingPresentation(),false);eq(w.presentationVisit.pending,false)
        end)
    end)
    return report
end
