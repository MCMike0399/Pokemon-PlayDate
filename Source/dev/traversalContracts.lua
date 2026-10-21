TraversalContracts={}
local function eq(a,b) assert(a==b,"expected "..tostring(b)..", got "..tostring(a)) end
local function rejects(fn) local ok=pcall(fn);assert(not ok,"expected rejection") end
local function scope(done)
    local value=GameContext({sessionLocationPolicy=KantoWorld.locationPolicy()})
    if done then assert(value.session:setIntro({stage="done",starter="squirtle",rivalStarter="bulbasaur",rivalOutcome=true})) end
    return value
end
local function actor(zone,x,y,fn)
    local previous=currentZone;local game=scope(true);currentZone=zone
    local p=Player(x,y,zone.collision,game.npcManager);game.player=p
    local ok,problem=pcall(fn,p,game)
    game.npcManager:clear();p:remove();p.grassOverlay:remove();p.exitArrow:remove();currentZone=previous
    if not ok then error(problem,0) end
end
local function recorder(game)
    local world=State("overworld");local event=State("event")
    function event:enter(id) self.received=id end
    game.machine:register("overworld",world);game.machine:register("event",event);game.machine:change("overworld")
    return event
end
local function keyForFoot(zone,foot)
    for id=38,zone.registry:maxID() do if zone.registry:entry(id).terrain.foot_tile==foot then return zone.registry:key(id) end end
    error("source foot tile missing: "..foot)
end
function TraversalContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)
        local ok,problem=pcall(fn);report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(problem) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("four-map installation and explicit location policy are idempotent",function()
        local count=#zoneList;local first=KantoWorld.install(game);local second=KantoWorld.install(game)
        eq(#zoneList,count);eq(first.kanto_route1,second.kanto_route1);eq(first.kanto_viridian_center.stableID,"pokered:VIRIDIAN_POKECENTER")
        first.kanto_route1=nil;eq(KantoWorld.install(game).kanto_route1,zoneRegistry.kanto_route1)
        local policy=KantoWorld.locationPolicy();policy.sliceZones["pokered:ROUTE_1"]=false
        eq(KantoWorld.locationPolicy().sliceZones["pokered:ROUTE_1"],true)
        rejects(function() KantoWorld.install(scope(true)) end)
    end)
    test("authored eight-frame motion and RED pose cadence remain unchanged",function()
        actor(zoneRegistry.reds_house_2f,5,3,function(p)
            p:tryMove(1,0);eq(p.isMoving,true);eq(p.isJumping,false)
            for tick=1,8 do p:update();eq(p.x,160+tick*4);eq(p.moveFrames,tick)
                eq(p:getImage(),tick<=4 and SpriteFactory.playerWalk1.right or SpriteFactory.playerStand.right)
                eq(p.stepJustFinished,tick==8)
            end
            eq(p.gridX,6);eq(p.gridY,3);eq(p.isMoving,false);eq(p.jumpShadow,nil)
        end)
    end)
    test("gated Pallet seam and original Route1-City offsets roundtrip through Player input API",function()
        actor(zoneRegistry.pallet_town,9,0,function(p,g)
            assert(g.session:setIntro({stage="pre_oak"}));p:tryMove(0,-1);eq(p.pendingEdgeDoor,nil);eq(p.gridX,9);eq(p.gridY,0)
            assert(g.session:setIntro({stage="done",starter="squirtle",rivalStarter="bulbasaur"}));p:tryMove(0,-1)
            eq(p.pendingEdgeDoor.to,"kanto_route1");eq(p.pendingEdgeDoor.toX,10);eq(p.pendingEdgeDoor.toY,35)
        end)
        local g=scope(true)
        local door=assert(KantoWorld.connection(g,zoneRegistry.kanto_route1,10,0,"up"));eq(door.toX,20);eq(door.toY,35)
        door=assert(KantoWorld.connection(g,zoneRegistry.kanto_viridian_city,20,35,"down"));eq(door.toX,10);eq(door.toY,0)
        door=assert(KantoWorld.connection(g,zoneRegistry.kanto_route1,10,35,"down"));eq(door.to,"pallet_town");eq(door.toX,9)
        eq(KantoWorld.connection(g,zoneRegistry.kanto_viridian_city,0,0,"up"),nil)
    end)
    test("bottom mat requires outward input and takes priority over map boundary",function()
        actor(zoneRegistry.kanto_viridian_mart,5,6,function(p)
            p:tryMove(0,1);for i=1,8 do p:update() end
            eq(p.gridY,7);eq(currentZone:getDoorAt(5,7),nil);eq(p.pendingEdgeDoor,nil)
            p:tryMove(0,1);eq(p.pendingEdgeDoor.to,"kanto_viridian_city");eq(p.pendingEdgeDoor.edge,"down");eq(p.pendingEdgeDoor.toY,20)
        end)
    end)
    test("native hop follows all original sixteen vertical samples and two-cell landing",function()
        actor(zoneRegistry.kanto_route1,4,4,function(p)
            p:tryMove(0,1);eq(p.isJumping,true);eq(p.gridY,6);eq(p.jumpShadow:isVisible(),true)
            for tick=1,16 do
                p:update();eq(p.jumpOffset,KantoJumpData.nativeOffsets[tick]);eq(p.y,128+tick*4-8+KantoJumpData.nativeOffsets[tick]);eq(p.stepJustFinished,tick==16)
                if tick<16 then local _,cy=p:getPixelCenter();eq(cy,128+tick*4+8) end
            end
            eq(p.isJumping,false);eq(p.isMoving,false);eq(p.jumpShadow:isVisible(),false)
            p:tryMove(0,-1);eq(p.isMoving,false);eq(p.gridY,6)
            if HarnessBuild and HarnessBuild.enabled then playdate.simulator.writeToFile(p.jumpShadow:getImage(),HarnessBuild.output_dir.."jump-shadow.png") end
        end)
    end)
    test("intermediate and landing NPC occupancy prevent source ledge hop",function()
        actor(zoneRegistry.kanto_route1,4,4,function(p,g)
            g.npcManager:addNPC({gridX=4,gridY=5,remove=function()end});p:tryMove(0,1);eq(p.isMoving,false);eq(p.gridY,4)
            g.npcManager:clear();g.npcManager:addNPC({gridX=4,gridY=6,remove=function()end});p:tryMove(0,1);eq(p.isMoving,false);eq(p.isJumping,false);eq(p.gridY,4)
            eq(p.lastTraversalBlock.id,"occupied-landing")
        end)
    end)
    test("original left and right ledge pairs use the same checked native hop",function()
        local zone=KantoSlice.create("ViridianCity",{registry=TileRegistry(),dispatch=function()end,questFlag=function()return false end})
        for _,case in ipairs({{dx=-1,target=0x27},{dx=1,target=0x0d}}) do
            -- Controlled metadata fixtures exercise source left/right pair rules;
            -- neither target foot occurs in the four reviewed map layouts.
            local entry=zone.registry:entry(keyForFoot(zone,0x2c))
            entry.key="contract:ledge:"..case.target;entry.terrain.foot_tile=case.target
            entry.collision=1;entry.terrain.land_passable=false
            zone.registry:registerBatch({entry})
            zone:setTile(5,5,keyForFoot(zone,0x2c));zone:setTile(5+case.dx,5,entry.key);zone:setTile(5+case.dx*2,5,keyForFoot(zone,0x2c))
            actor(zone,5,5,function(p)
                p:tryMove(case.dx,0);eq(p.isJumping,true);eq(p.gridX,5+case.dx*2)
                for i=1,16 do p:update() end;eq(p.isMoving,false)
                p:tryMove(-case.dx,0);eq(p.isMoving,false)
            end)
        end
    end)
    test("pause suspends actual native jump updates and disposal removes shadow",function()
        actor(zoneRegistry.kanto_route1,4,4,function(p,g)
            p:tryMove(0,1);p:update();local tick,offset=p.moveFrames,p.jumpOffset
            local saved={};for _,sprite in ipairs(playdate.graphics.sprite.getAllSprites()) do
                if sprite~=p then saved[#saved+1]={sprite=sprite,enabled=sprite:updatesEnabled()};sprite:setUpdatesEnabled(false) end
            end
            local world=OverworldState(g);local ok,problem=pcall(function()
                world:pause();playdate.graphics.sprite.update();eq(p.moveFrames,tick);eq(p.jumpOffset,offset)
                world:resume();playdate.graphics.sprite.update();eq(p.moveFrames,tick+1)
            end)
            world:resume();for _,item in ipairs(saved) do item.sprite:setUpdatesEnabled(item.enabled) end
            if not ok then error(problem,0) end
            local shadow=p.jumpShadow;p:remove()
            for _,sprite in ipairs(playdate.graphics.sprite.getAllSprites()) do assert(sprite~=shadow,"disposed jump shadow still active") end
            local fresh=Player(4,4,zoneRegistry.kanto_route1.collision,g.npcManager)
            eq(fresh.isJumping,false);eq(fresh.jumpOffset,0);eq(fresh.pendingEdgeDoor,nil);eq(fresh.jumpShadow,nil)
            fresh:remove();fresh.grassOverlay:remove();fresh.exitArrow:remove()
        end)
    end)
    test("source counter interaction pushes raw event ID and no nil legacy dialog",function()
        actor(zoneRegistry.kanto_viridian_center,3,3,function(p,g)
            currentZone:spawnNPCs(g.npcManager);p.facing="up";local event=recorder(g)
            eq(KantoWorld.tryInteract(g),true);eq(g.machine:getCurrent(),"event");eq(event.received,"pokered:VIRIDIAN_POKECENTER:objects:1")
        end)
    end)
    test("door-only Mart entry never replays on Continue and Center has no invented step",function()
        actor(zoneRegistry.kanto_viridian_mart,5,7,function(p,g)
            local event=recorder(g);eq(KantoWorld.onEnter(g,{entry={x=5,y=7}}),false);eq(event.received,nil)
            eq(KantoWorld.onEnter(g,{fromDoor=true}),true);eq(event.received,"pokered:VIRIDIAN_MART:script:entry")
        end)
        actor(zoneRegistry.kanto_viridian_center,3,7,function(p,g)
            local event=recorder(g);eq(KantoWorld.onEnter(g,{fromDoor=true}),false);eq(event.received,nil);eq(p.gridY,7)
        end)
    end)
    test("hidden bound source NPC cannot dispatch from an empty cell or mutate session and RNG",function()
        local zone=KantoSlice.create("Route1",{registry=TileRegistry(),dispatch=function()error("unexpected hidden NPC dispatch")end,questFlag=function()return false end})
        actor(zone,5,25,function(p,g)
            p.facing="up";local event=recorder(g)
            zone:spawnNPCs(g.npcManager);assert(g.npcManager:getNPCAt(5,24),"visible source NPC missing")
            zone.npcDefs[1].appearsIf=function()return false end
            zone:spawnNPCs(g.npcManager);eq(g.npcManager:getNPCAt(5,24),nil)
            local bound=false
            for _,entry in ipairs(zone:sourceEventsAt(5,24)) do
                if entry.kind=="objects" and entry.id=="pokered:ROUTE_1:objects:1" and entry.status=="bound" then bound=true end
            end
            assert(bound,"test requires an otherwise bound source object handler")
            local function same(a,b)
                eq(type(a),type(b));if type(a)~="table" then eq(a,b);return end
                for key,value in pairs(a) do same(value,b[key]) end
                for key in pairs(b) do assert(a[key]~=nil,"unexpected session field mutation") end
            end
            local flags=g.session:flags();local bag=g.session:inventory():toData();local rng=RulesRNG.snapshot()
            local transitions=#g.transitionLog
            eq(KantoWorld.tryInteract(g),false);eq(g.machine:getCurrent(),"overworld");eq(event.received,nil)
            eq(#g.transitionLog,transitions);same(g.session:flags(),flags);same(g.session:inventory():toData(),bag);same(RulesRNG.snapshot(),rng)
            eq(p.lastTraversalBlock,nil)
        end)
    end)
    return report
end
