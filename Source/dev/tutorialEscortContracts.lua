-- Root-run SDK witnesses, not natural journeys. Production classes, source
-- geometry/art, real player, NPCMotion and session owners; no emulated SDK.
import "game/tutorialEscort"
TutorialEscortContracts = {}
local gfx <const> = playdate.graphics
local function eq(a,b) assert(a == b, "expected " .. tostring(b) .. ", got " .. tostring(a)) end
local function same(a,b)
    eq(type(a),type(b))
    if type(a) ~= "table" then eq(a,b); return end
    for key,value in pairs(a) do same(value,b[key]) end
    for key in pairs(b) do assert(a[key] ~= nil, "unexpected field " .. tostring(key)) end
end
local function durable(g)
    return assert(SessionCodec.encode(g.session, {root="overworld",overworld="explore",settled=true}))
end
local function closeDialog(g)
    eq(g.machine:getCurrent(), "dialog")
    local dialog = g.machine:get("dialog")
    dialog.dialog.onComplete()
    dialog:handleInput()
end
-- Capture before fixture teardown discards the live controller and leases.
-- In particular, a route timeout must identify the inner stopping point rather
-- than only rethrowing "expected dialog" from the scene wrapper.
local function routeContext(g, s)
    local function pose(actor)
        if not actor then return "absent" end
        return {x=actor.gridX,y=actor.gridY,moving=actor.isMoving == true,
            pixelX=actor.x,pixelY=actor.y,facing=actor.facing}
    end
    local function nextCell(actor, route, index)
        local direction = route and route[index]
        local d = ({up={0,-1},down={0,1},left={-1,0},right={1,0}})[direction]
        if not actor or not d then return {direction=direction or "done"} end
        local x,y = actor.gridX+d[1],actor.gridY+d[2]
        local occupant = g.npcManager:getNPCAt(x,y)
        return {direction=direction,x=x,y=y,
            collision=s.zone.collision[y+1] and s.zone.collision[y+1][x+1] or "outside",
            occupant=occupant and occupant.def and occupant.def.source_event_id or (occupant and "unnamed" or "none")}
    end
    return json.encode({root=g.machine:getCurrent(),phase=s.phase,waiting=s.waiting,
        valid=s:valid() == true,top=s:isTop() == true,retryPhase=s.retryPhase or "none",
        blockedTicks=s.blockedTicks,playerIndex=s.playerIndex,npcIndex=s.npcIndex,
        playerMoving=s.playerMoving,npcMoving=s.npcMoving,
        player=pose(g.player),guide=pose(s.actor),playerFrames=g.player.moveFrames,
        playerOriginX=g.player.startPixelX,playerOriginY=g.player.startPixelY,
        playerNext=nextCell(g.player,s.playerRoute,s.playerIndex),
        guideNext=nextCell(s.actor,s.npcRoute,s.npcIndex)})
end
local function expectRouteRoot(g,s,expected,point)
    assert(g.machine:getCurrent() == expected,
        point .. ": expected " .. expected .. "; escort-context=" .. routeContext(g,s))
end
local function scene(map, x, y, fn)
    local oldZone, oldStory, oldOwner = currentZone, Story.currentContext(), GameSession.activeRNGSession()
    local rng, count, original = RulesRNG.toData(), gfx.sprite.spriteCount(), SourceEvents.actorPositions
    local ox,oy = gfx.getDrawOffset()
    local g
    local ok,problem = pcall(function()
        -- Metadata adapter is confined to this SDK fixture. Campaign metadata
        -- stays untouched until root installs the supplied integration patch.
        SourceEvents.actorPositions = function(id)
            if id == "pokered:PEWTER_CITY:objects:5" then return TutorialEscortData.actorPositions(id) end
            return original(id)
        end
        g = GameContext({sessionLocationPolicy=PewterWorld.locationPolicy()})
        assert(g:recruit(Pokemon("squirtle",5)))
        assert(g.session:setIntro({stage="done",starter="squirtle",rivalStarter="bulbasaur"}))
        currentZone = SourceMaps.isolated(map)
        if map == "PewterCity" then PewterSprites.installFor(SourceMaps.padded(map)) else SliceSprites.install() end
        g.player = Player(x,y,currentZone.collision,g.npcManager)
        g.player:setUpdatesEnabled(false)
        currentZone:spawnNPCs(g.npcManager)
        local sub = StateMachine()
        sub:register("explore",{}); sub:change("explore")
        g.machine:register("overworld",{sub=sub})
        g.machine:register("dialog",DialogState(g))
        g.machine:register("pause",{})
        g.machine:register("tutorial-escort",TutorialEscortState(g))
        g.machine:change("overworld")
        g.npcManager.motion:attach(g,currentZone)
        fn(g,g.machine:get("tutorial-escort"),g.npcManager.motion)
    end)
    if g then
        g.machine:change("overworld")
        g.npcManager:clear()
        g.player:remove(); g.player.grassOverlay:remove(); g.player.exitArrow:remove()
    end
    SourceEvents.actorPositions = original
    currentZone = oldZone
    Story.bind(oldStory)
    if oldOwner then oldOwner:activateRNG() end
    RulesRNG.restoreData(rng)
    gfx.setDrawOffset(ox,oy)
    assert(ok,problem)
    eq(gfx.sprite.spriteCount(),count)
end
function TutorialEscortContracts.run()
    local report = {ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)
        local ok,problem = pcall(fn)
        report.tests[#report.tests+1] = {name=name,ok=ok,error=not ok and tostring(problem) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("YES means hurry; NO demonstrates exact Weedle without any durable or RNG write",function()
        scene("ViridianCity",17,6,function(g,s)
            assert(g.session:setQuestFlag("EVENT_GOT_POKEDEX",true))
            local before = durable(g)
            TutorialEscort.dispatch(g,"pokered:VIRIDIAN_CITY:objects:7")
            closeDialog(g)
            eq(s.phase,"hurry-choice")
            s.menu.onSelect(1)
            eq(s.demo,nil)
            closeDialog(g)
            eq(g.machine:getCurrent(),"overworld")
            same(durable(g),before)
            TutorialEscort.dispatch(g,"pokered:VIRIDIAN_CITY:objects:7")
            closeDialog(g)
            s.menu.onSelect(2)
            closeDialog(g)
            eq(s.phase,"tutorial-demo")
            eq(s.demo.species,"weedle"); eq(s.demo.level,5)
            for _=1,400 do s:update(); s:draw() end
            eq(s.demo.phase,"caught")
            eq(s.demo.animation.caught,true)
            s:handleButton("a")
            closeDialog(g)
            eq(g.machine:getCurrent(),"overworld")
            same(durable(g),before)
        end)
    end)
    test("old man Pokedex gate, sleepy pushback and girl before/after source pages",function()
        scene("ViridianCity",19,9,function(g,s)
            eq(TutorialEscort.trigger(g),"pokered:VIRIDIAN_CITY:objects:5")
            TutorialEscort.dispatch(g,"pokered:VIRIDIAN_CITY:objects:7")
            eq(g.machine:getCurrent(),"overworld")
            TutorialEscort.dispatch(g,"pokered:VIRIDIAN_CITY:objects:5")
            eq(s.waiting,"_ViridianCityOldManSleepyPrivatePropertyText")
            closeDialog(g)
            for _=1,10 do s:update() end
            eq(g.machine:getCurrent(),"overworld")
            eq(g.player.gridY,10)
            TutorialEscort.dispatch(g,"pokered:VIRIDIAN_CITY:objects:4")
            eq(s.waiting,"_ViridianCityGirlHasntHadHisCoffeeYetText")
            closeDialog(g)
            assert(g.session:setQuestFlag("EVENT_GOT_POKEDEX",true))
            eq(TutorialEscort.trigger(g),nil)
            TutorialEscort.dispatch(g,"pokered:VIRIDIAN_CITY:objects:4")
            eq(s.waiting,"_ViridianCityGirlWhenIGoShopText")
            closeDialog(g)
        end)
    end)
    test("overlay freezes demo, stale choice cannot reenter, replaced context rejects callback",function()
        scene("ViridianCity",17,6,function(g,s)
            assert(g.session:setQuestFlag("EVENT_GOT_POKEDEX",true))
            TutorialEscort.dispatch(g,"pokered:VIRIDIAN_CITY:objects:7")
            closeDialog(g)
            local stale = s.menu.onSelect
            stale(2); closeDialog(g)
            local tick = s.demo.tick
            g.machine:push("pause")
            s:update(); stale(1)
            eq(s.demo.tick,tick)
            g.machine:pop()
            s:update(); eq(s.demo.tick,tick+1)
            g.machine:change("overworld")
            stale(2)
            eq(g.machine:getCurrent(),"overworld")
            TutorialEscort.dispatch(g,"pokered:VIRIDIAN_CITY:objects:7")
            closeDialog(g)
            local callback = s.menu.onSelect
            local session = g.session
            g.session = {}
            callback(2)
            eq(s.demo,nil)
            s:update()
            eq(g.machine:getCurrent(),"overworld")
            g.session = session
        end)
    end)
    for _,cell in ipairs({{34,16},{35,17},{36,17},{37,18},{37,19}}) do
        test("exact leased escort route and reset from " .. cell[1] .. "," .. cell[2],function()
            scene("PewterCity",cell[1],cell[2],function(g,s,m)
                assert(type(m.faceScript)=="function" and type(m.resetScript)=="function", "apply root NPCMotion patch first")
                local before = durable(g)
                local beforeMotion = m:snapshot()
                -- This actual source STAY actor at (8,15) caused all five
                -- native failures. Never remove or relocate it for the route.
                local blocker = assert(g.npcManager:getNPCAt(8,15))
                eq(blocker.def.source_event_id,"pokered:PEWTER_CITY:objects:1")
                local blockerPose = TutorialEscortPlayer.capture(blocker)
                local walked, frames, tryMove, update = {},{},g.player.tryMove,g.player.update
                g.player.tryMove = function(player,dx,dy,intent)
                    local wasMoving = player.isMoving
                    if player.gridX == 8 and player.gridY == 14 and dx == 0 and dy == 1 then
                        tryMove(player,dx,dy) -- ordinary movement still collides
                        eq(player.isMoving,false); eq(player.gridY,14)
                    end
                    tryMove(player,dx,dy,intent)
                    if not wasMoving and player.isMoving then
                        walked[#walked+1] = {dx,dy}
                        frames[#walked] = 0
                    end
                end
                g.player.update = function(player)
                    if player.isMoving then frames[#walked] = frames[#walked]+1 end
                    update(player)
                end
                TutorialEscort.dispatch(g,"pokered:PEWTER_CITY:objects:5")
                expectRouteRoot(g,s,"dialog","initial source invitation")
                closeDialog(g)
                local actor, token = s.actor,s.token
                local home = m:actor(actor)
                -- First update reserves a real cell before interpolation.
                s:update()
                eq(g.npcManager:getNPCAt(35,16),actor)
                if cell[1] ~= 35 or cell[2] ~= 17 then eq(g.npcManager:getNPCAt(35,17),actor) end
                for _=1,2000 do
                    if g.machine:getCurrent()=="dialog" then break end
                    s:update()
                end
                expectRouteRoot(g,s,"dialog","arrival after at most 2001 route updates")
                eq(s.waiting,"_PewterCityYoungsterGoTakeOnBrockText")
                eq(g.player.gridX,10); eq(g.player.gridY,18)
                eq(actor.gridX,12); eq(actor.gridY,18); eq(actor.facing,"left")
                local expected = {}
                local directions = {up={0,-1},down={0,1},left={-1,0},right={1,0}}
                for _,direction in ipairs(TutorialEscortData.get().escort.player_routes[cell[1] .. "," .. cell[2]]) do
                    if direction ~= "wait" then expected[#expected+1] = directions[direction] end
                end
                same(walked,expected)
                for _,ticks in ipairs(frames) do eq(ticks,8) end
                eq(s.playerIndex,#s.playerRoute+1)
                eq(g.npcManager:getNPCAt(8,15),blocker)
                same(TutorialEscortPlayer.capture(blocker),blockerPose)
                closeDialog(g)
                for _=1,100 do if g.machine:getCurrent()=="overworld" then break end; s:update() end
                expectRouteRoot(g,s,"overworld","departure/reset after at most 100 route updates")
                same(m:actor(actor),home)
                same(m:snapshot(),beforeMotion)
                eq(actor:isVisible(),true)
                eq(m:updateScript(token),false)
                same(durable(g),before)
                -- Brock removes the trigger without starting another scene.
                assert(g.session:setTrainerDefeated(TrainerEvents.BROCK,true))
                eq(TutorialEscort.trigger(g),nil)
            end)
        end)
    end
    test("escort intent rejects forgery, wrong route cell, overlays, stale sessions and reuse after cancel",function()
        scene("PewterCity",37,19,function(g,s,m)
            local before, motion = durable(g),m:snapshot()
            TutorialEscort.dispatch(g,"pokered:PEWTER_CITY:objects:5"); closeDialog(g)
            local intent = assert(s.playerIntent)
            -- First source input here is left. A right input cannot use the
            -- permission, even though that adjacent cell is on the same map.
            g.player:tryMove(1,0,intent); eq(g.player.isMoving,false)
            g.player:tryMove(-1,0,{}); eq(g.player.isMoving,false)
            eq(TutorialEscortPlayer.permits(intent,g.player,-1,0),true)
            g.machine:push("pause")
            g.player:tryMove(-1,0,intent); eq(g.player.isMoving,false)
            g.machine:pop()
            local session = g.session; g.session = {}
            g.player:tryMove(-1,0,intent); eq(g.player.isMoving,false)
            g.session = session
            local route = s.playerRoute; s.playerRoute = {"right"}
            g.player:tryMove(-1,0,intent); eq(g.player.isMoving,false)
            s.playerRoute = route
            -- Terrain still wins even for the exact authorized source cell.
            local old = currentZone.collision[20][37]
            currentZone.collision[20][37] = 1
            g.player:tryMove(-1,0,intent); eq(g.player.isMoving,false)
            currentZone.collision[20][37] = old
            s:update()
            eq(g.player.isMoving,true)
            for _=1,3 do s:update() end
            eq(g.player.moveFrames,3)
            s:handleButton("b")
            expectRouteRoot(g,s,"overworld","cancel during authorized interpolation")
            eq(g.player.gridX,37); eq(g.player.gridY,19); eq(g.player.isMoving,false)
            g.player:tryMove(-1,0,intent); eq(g.player.isMoving,false)
            same(m:snapshot(),motion); same(durable(g),before)
            TutorialEscort.dispatch(g,"pokered:PEWTER_CITY:objects:5"); closeDialog(g)
            g.player:tryMove(-1,0,intent); eq(g.player.isMoving,false)
            s:cancel()
        end)
    end)
    test("cancelled coordinate trigger permits walking out and rearms only after leaving trigger cells",function()
        scene("PewterCity",37,18,function(g,s,m)
            local before, motion = durable(g),m:snapshot()
            eq(TutorialEscort.trigger(g),"pokered:PEWTER_CITY:objects:5")
            TutorialEscort.dispatch(g,TutorialEscort.trigger(g)); closeDialog(g)
            s:update(); s:handleButton("b")
            eq(TutorialEscort.trigger(g),nil)
            for _=1,5 do s:update(); eq(TutorialEscort.trigger(g),nil) end
            -- Remain suppressed across the adjacent source trigger (37,19).
            g.player:tryMove(0,1); eq(g.player.isMoving,true)
            for _=1,8 do g.player:update() end
            eq(TutorialEscort.trigger(g),nil)
            g.player:tryMove(-1,0); eq(g.player.isMoving,true)
            for _=1,8 do g.player:update() end
            eq(TutorialEscort.trigger(g),nil) -- outside the trigger set; rearm
            g.player:tryMove(1,0); eq(g.player.isMoving,true)
            for _=1,8 do g.player:update() end
            eq(TutorialEscort.trigger(g),"pokered:PEWTER_CITY:objects:5")
            same(m:snapshot(),motion); same(durable(g),before)
        end)
    end)
    test("different occupant overlaps only on source route without changing its pose or either RNG",function()
        scene("PewterCity",37,19,function(g,s,m)
            local extra = NPC(8,16,"BLOCKER",{},nil,"mom","down")
            extra.def = {source_event_id="contract:escort:other-occupant"}
            extra:setUpdatesEnabled(false); g.npcManager:addNPC(extra)
            local pose, before = TutorialEscortPlayer.capture(extra),durable(g)
            TutorialEscort.dispatch(g,"pokered:PEWTER_CITY:objects:5"); closeDialog(g)
            for _=1,2000 do if g.machine:getCurrent()=="dialog" then break end; s:update() end
            expectRouteRoot(g,s,"dialog","different occupant arrival")
            eq(g.player.gridX,10); eq(g.player.gridY,18)
            eq(s.waiting,"_PewterCityYoungsterGoTakeOnBrockText")
            same(TutorialEscortPlayer.capture(extra),pose)
            eq(g.npcManager:getNPCAt(8,16),extra)
            closeDialog(g)
            for _=1,100 do if g.machine:getCurrent()=="overworld" then break end; s:update() end
            expectRouteRoot(g,s,"overworld","different occupant reset")
            same(durable(g),before)
        end)
    end)
    test("already midstep WALK actor and its reservations remain frozen throughout escort",function()
        scene("PewterCity",37,19,function(g,s,m)
            -- Valid saved tick-three source WALK, restored through its real
            -- owner. This actor is not moved aside or settled by the scene.
            local payload = m:snapshot()
            local walker
            for _,v in ipairs(payload.actors) do
                if v.id == "pokered:PEWTER_CITY:objects:4" then walker = v end
            end
            assert(walker)
            walker.phase,walker.facing,walker.tick = "moving","right",3
            walker.x,walker.y,walker.origin_x,walker.origin_y = 27,25,26,25
            walker.target_x,walker.target_y = 27,25
            walker.delay_raw,walker.delay_left = 0,0
            m:attach(g,currentZone,payload)
            local npc = assert(g.npcManager:getNPCAt(26,25))
            eq(g.npcManager:getNPCAt(27,25),npc)
            local pose, motion, before = TutorialEscortPlayer.capture(npc),m:snapshot(),durable(g)
            local px,py = npc.x,npc.y
            TutorialEscort.dispatch(g,"pokered:PEWTER_CITY:objects:5"); closeDialog(g)
            for _=1,2000 do
                if g.machine:getCurrent()=="dialog" then break end
                s:update(); m:tick()
                same(TutorialEscortPlayer.capture(npc),pose)
                eq(npc.x,px); eq(npc.y,py)
            end
            expectRouteRoot(g,s,"dialog","midstep actor arrival")
            eq(g.player.gridX,10); eq(g.player.gridY,18)
            closeDialog(g)
            for _=1,100 do if g.machine:getCurrent()=="overworld" then break end; s:update() end
            expectRouteRoot(g,s,"overworld","midstep actor reset")
            same(m:snapshot(),motion); same(durable(g),before)
            eq(g.npcManager:getNPCAt(26,25),npc); eq(g.npcManager:getNPCAt(27,25),npc)
        end)
    end)
    test("replaced attachment revokes player intent even after guide has finished its route",function()
        scene("PewterCity",37,19,function(g,s,m)
            TutorialEscort.dispatch(g,"pokered:PEWTER_CITY:objects:5"); closeDialog(g)
            for _=1,2000 do
                if not s.npcMoving and s.npcIndex > #s.npcRoute then break end
                s:update()
            end
            eq(s.phase,"escort-walk"); eq(s.npcMoving,false)
            assert(s.npcIndex > #s.npcRoute)
            -- Stop on an ordinary completed cell without changing coordinates.
            for _=1,8 do if not g.player.isMoving then break end; g.player:update() end
            eq(g.player.isMoving,false)
            local intent, token = s.playerIntent,s.token
            eq(m:isScriptOwner(token,s),true)
            m:attach(g,currentZone,m:snapshot())
            eq(m:isScriptOwner(token,s),false)
            local x,y = g.player.gridX,g.player.gridY
            g.player:tryMove(0,1,intent)
            eq(g.player.isMoving,false); eq(g.player.gridX,x); eq(g.player.gridY,y)
            s:update(); eq(s.phase,"failed"); eq(s.waiting,"stale-script-token")
            s:handleButton("b"); eq(g.machine:getCurrent(),"overworld")
        end)
    end)
    test("only the source guide can transit the arrival; actual door and autonomous paths stay protected",function()
        scene("PewterCity",37,18,function(g,s,m)
            local descriptor = SourceActors.describe(currentZone.stableID,WorldDeltas.export())
            local spec
            for _, actor in ipairs(descriptor.actors) do
                if actor.id == "pokered:PEWTER_CITY:objects:5" then spec = actor end
            end
            local arrival = 18*descriptor.width+16+1
            local door = 17*descriptor.width+16+1
            assert(descriptor.protected[arrival] and descriptor.protected[door])
            assert(spec.script_transit[arrival])
            eq(spec.script_transit[door],nil)
            eq(descriptor.canStep(spec,15,18,16,18,currentZone),true)
            eq(descriptor.canWanderStep(spec,15,18,16,18,currentZone),false)
            eq(descriptor.canStep(spec,16,18,16,17,currentZone),false)
            local martArrival = 18*descriptor.width+23+1
            local martDoor = 17*descriptor.width+23+1
            assert(descriptor.protected[martArrival] and descriptor.protected[martDoor])
            assert(spec.script_transit[martArrival])
            eq(spec.script_transit[martDoor],nil)
            eq(descriptor.canStep(spec,24,18,23,18,currentZone),true)
            eq(descriptor.canWanderStep(spec,24,18,23,18,currentZone),false)
            eq(descriptor.canStep(spec,23,18,23,17,currentZone),false)
            for _, actor in ipairs(descriptor.actors) do
                if actor ~= spec then
                    eq(actor.script_transit and actor.script_transit[arrival],nil)
                    eq(actor.script_transit and actor.script_transit[martArrival],nil)
                    eq(descriptor.canStand(actor,16,18,currentZone),false)
                    eq(descriptor.canStand(actor,23,18,currentZone),false)
                end
            end
            eq(TutorialEscortData.transitAllowed("pokered:PEWTER_CITY:objects:4",16,18),false)
        end)
    end)
    test("leased escort freezes under overlays and rejects replaced attachments",function()
        scene("PewterCity",37,18,function(g,s,m)
            TutorialEscort.dispatch(g,"pokered:PEWTER_CITY:objects:5")
            closeDialog(g)
            s:update(); s:update()
            local token, actor, y = s.token,s.actor,s.actor.y
            g.machine:push("pause")
            for _=1,20 do s:update() end
            eq(actor.y,y)
            eq(m:updateScript(token),false)
            g.machine:pop()
            s:update()
            assert(actor.y>y)
            local saved = m:snapshot()
            -- A fresh attachment is a new owner epoch, even in the same map.
            m:attach(g,currentZone,saved)
            eq(m:updateScript(token),false)
            s:update()
            eq(s.phase,"failed")
            s:handleButton("b")
            eq(g.machine:getCurrent(),"overworld")
        end)
    end)
    test("real eight-frame art, reservation, cancellation restores both scene poses and rejects old lease",function()
        scene("PewterCity",37,18,function(g,s,m)
            TutorialEscort.dispatch(g,"pokered:PEWTER_CITY:objects:5")
            closeDialog(g)
            local actor,token = s.actor,s.token
            local home = m:actor(actor)
            s:update() -- claim first cell, no interpolation yet
            for tick=1,4 do
                s:update()
                eq(actor.gridY,16)
                eq(actor.y,(16+tick/8)*TILE_SIZE-8)
                eq(actor:getImage(),PewterSprites.stepImage("SPRITE_YOUNGSTER","down",tick))
                eq(g.npcManager:getNPCAt(35,16),actor)
                eq(g.npcManager:getNPCAt(35,17),actor)
            end
            s:handleButton("b")
            eq(g.machine:getCurrent(),"overworld")
            same(m:actor(actor),home)
            eq(g.player.gridX,37); eq(g.player.gridY,18)
            eq(m:updateScript(token),false)
            TutorialEscort.dispatch(g,"pokered:PEWTER_CITY:objects:5")
            closeDialog(g)
            eq(s.phase,"escort-walk")
            s:cancel()
        end)
    end)
    test("blocked cell stops, permits retry and cannot strand input",function()
        scene("PewterCity",37,18,function(g,s,m)
            TutorialEscort.dispatch(g,"pokered:PEWTER_CITY:objects:5")
            closeDialog(g)
            -- Real collision surface blocks the first guide cell. Player
            -- eventually waits behind him; no script can bypass that cell.
            local old = currentZone.collision[18][36]
            currentZone.collision[18][36] = 1
            for _=1,1200 do s:update(); if s.phase=="blocked" then break end end
            eq(s.phase,"blocked")
            eq(s.actor.gridY,16)
            currentZone.collision[18][36] = old
            s:handleButton("a")
            eq(s.phase,"escort-walk")
            for _=1,20 do s:update() end
            assert(s.actor.gridY>16)
            s:cancel()
            eq(g.machine:getCurrent(),"overworld")
        end)
    end)
    return report
end
