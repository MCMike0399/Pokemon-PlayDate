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
                TutorialEscort.dispatch(g,"pokered:PEWTER_CITY:objects:5")
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
                eq(g.machine:getCurrent(),"dialog")
                eq(s.waiting,"_PewterCityYoungsterGoTakeOnBrockText")
                eq(g.player.gridX,10); eq(g.player.gridY,18)
                eq(actor.gridX,12); eq(actor.gridY,18); eq(actor.facing,"left")
                closeDialog(g)
                for _=1,100 do if g.machine:getCurrent()=="overworld" then break end; s:update() end
                eq(g.machine:getCurrent(),"overworld")
                same(m:actor(actor),home)
                eq(actor:isVisible(),true)
                eq(m:updateScript(token),false)
                same(durable(g),before)
                -- Brock removes the trigger without starting another scene.
                assert(g.session:setTrainerDefeated(TrainerEvents.BROCK,true))
                eq(TutorialEscort.trigger(g),nil)
            end)
        end)
    end
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
