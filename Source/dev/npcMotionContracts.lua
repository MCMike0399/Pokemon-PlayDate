NPCMotionContracts={}
local gfx=playdate.graphics
local function eq(a,b)assert(a==b,"expected "..tostring(b)..", got "..tostring(a))end
local function same(a,b,path)
    path=path or "record"
    assert(type(a)==type(b),path.." type expected "..type(b)..", got "..type(a))
    if type(a)~="table"then assert(a==b,path.." expected "..tostring(b)..", got "..tostring(a));return end
    for k,v in pairs(a)do same(v,b[k],path.."."..tostring(k))end
    for k in pairs(b)do assert(a[k]~=nil,path.." missing "..tostring(k))end
end
local function rejects(fn)local ok=pcall(fn);assert(not ok,"expected rejection")end
local function flags()return {quest={},trainers={}}end
local function mart()
    local world=WorldDeltas.export();local d=assert(SourceActors.describe("pokered:PEWTER_MART",world))
    local record=WorldMotionData.reconcile(nil,d,flags());return d,record,{zone_id=d.zone_id,x=5,y=6,facing="up"},world
end
local function fresh()
    local g=GameContext({sessionLocationPolicy=PewterWorld.locationPolicy()});assert(g:recruit(Pokemon("squirtle",5)))
    assert(g.session:setIntro({stage="done",starter="squirtle",rivalStarter="bulbasaur"}));return g
end
local function clear(machine)for i=#machine.stack,1,-1 do machine.stack[i]:exit();machine.stack[i]=nil end end
local function scene(fn)
    local oldZone=currentZone;local oldRng=RulesRNG.toData();local oldStory=Story.currentContext();local oldOwner=GameSession.activeRNGSession()
    local count=gfx.sprite.spriteCount();local ids=WorldTiles:maxID();local x,y=gfx.getDrawOffset();local g
    local ok,problem=pcall(function()
        g=fresh();currentZone=PewterWorld.isolated("PewterMart");PewterSprites.installFor(PewterSlice.padded("PewterMart"))
        g.player=Player(5,6,currentZone.collision,g.npcManager);currentZone:spawnNPCs(g.npcManager)
        local sub=StateMachine();sub:register("explore",{});sub:change("explore")
        g.machine:register("overworld",{sub=sub});g.machine:register("pause",{})
        g.machine:register("event",EventState(g));g.machine:register("dialog",DialogState(g));g.machine:change("overworld")
        g.npcManager.motion:attach(g,currentZone)
        fn(g,g.npcManager.motion)
    end)
    if g then clear(g.machine);g.npcManager:clear();if g.player then g.player:remove();g.player.grassOverlay:remove();g.player.exitArrow:remove()end end
    currentZone=oldZone;Story.bind(oldStory)
    if oldOwner then oldOwner:activateRNG()end;RulesRNG.restoreData(oldRng);gfx.setDrawOffset(x,y)
    local finalSprites=gfx.sprite.spriteCount();local finalIDs=WorldTiles:maxID()
    if not ok then error(tostring(problem).."; cleanup sprites="..finalSprites.." expected="..count.." ids="..finalIDs.." expected="..ids,0)end
    eq(finalSprites,count);eq(finalIDs,ids)
end
function NPCMotionContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)
        local ok,error=pcall(fn);report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(error)or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("world source direction vectors and zero delay adapt without drawing either RNG",function()
        local before=RulesRNG.toData();local any={up=0,down=0,left=0,right=0};local vertical={up=0,down=0};local horizontal={left=0,right=0}
        for byte=0,255 do
            local a=WorldMotionData.direction("ANY_DIR",byte);any[a]=any[a]+1
            a=WorldMotionData.direction("UP_DOWN",byte);vertical[a]=vertical[a]+1
            a=WorldMotionData.direction("LEFT_RIGHT",byte);horizontal[a]=horizontal[a]+1
            eq(WorldMotionData.direction("RIGHT",byte),"right")
        end
        for _,n in pairs(any)do eq(n,64)end;eq(vertical.up,128);eq(vertical.down,128);eq(horizontal.left,128);eq(horizontal.right,128)
        eq(WorldMotionData.delay(0),128);eq(WorldMotionData.delay(1),1);eq(WorldMotionData.delay(127),64)
        rejects(function()WorldMotionData.direction("unknown",0)end);rejects(function()WorldMotionData.delay(128)end)
        same(RulesRNG.toData(),before)
    end)
    test("independent initialized session world stream does not change rules or specimen RNG",function()
        local g=fresh();local before=g.session:rngData();local live=RulesRNG.toData();local world=g.session:worldRngData()
        eq(world.rolls,"0");g.session:worldRandom(0,255);eq(g.session:worldRngData().rolls,"1")
        same(g.session:rngData(),before);same(RulesRNG.toData(),live)
        local copy=g.session:worldRngData();copy.state="1";assert(g.session:worldRngData().state~="1")
    end)
    test("legacy valid SessionCodec1 without worldMotion migrates seed with zero rolls",function()
        local g=fresh();g.session:worldRandom(0,255);local wire=assert(SessionCodec.encode(g.session,{root="overworld",overworld="explore",settled=true}))
        wire.worldMotion=nil;local rng=RulesRNG.toData();local ids=WorldTiles:maxID();local zones=#zoneList
        local restored=assert(SessionCodec.decode(wire,g:getSessionDependencies()))
        eq(restored:worldRngData().seed,wire.rng.seed);eq(restored:worldRngData().rolls,"0");same(restored:actorData(),WorldMotionData.empty())
        eq(WorldTiles:maxID(),ids);eq(#zoneList,zones);same(RulesRNG.toData(),rng)
    end)
    test("all eight actor descriptors remain pure and describe exactly three source walkers",function()
        local ids, zones = WorldTiles:maxID(), #zoneList
        local rng = RulesRNG.toData()
        local world = WorldDeltas.export()
        local beforeWorld = Party._primitive(world)
        local count, walkers = 0, 0
        -- The unified map provider also contains legacy Viridian maps. Motion
        -- descriptors still belong to the eight reviewed Pewter-profile maps.
        local names = SourceMaps.names("pewter")
        eq(#names, 8)
        for _, name in ipairs(names) do
            local entry = SourceMaps.entry(name)
            local descriptor = assert(SourceActors.describe(entry.id, world), name)
            eq(descriptor.zone_id, entry.id)
            for _, spec in ipairs(descriptor.actors) do
                count = count + 1
                if spec.random and spec.movement == "WALK" then walkers = walkers + 1 end
            end
        end
        local legacy = SourceMaps.names("viridian")
        eq(#legacy, 4)
        for _, name in ipairs(legacy) do
            eq(SourceActors.describe(SourceMaps.entry(name).id, world), nil)
        end
        eq(count, 29)
        eq(walkers, 3)
        eq(WorldTiles:maxID(), ids)
        eq(#zoneList, zones)
        same(RulesRNG.toData(), rng)
        same(world, beforeWorld)
    end)
    test("current actor values validate moving pose timers home bounds and protected Mart exit",function()
        local d,record,location=mart();local value=record.actors[2]
        value.phase="moving";value.facing="down";value.x,value.y=5,4;value.origin_x,value.origin_y=5,3;value.target_x,value.target_y=5,4;value.tick=3
        local normalized=WorldMotionData.normalize(record,d,location,flags());eq(normalized.actors[2].tick,3)
        value.target_y=7;value.y=7;rejects(function()WorldMotionData.normalize(record,d,location,flags())end)
        eq(d.canStand(d.actors[2],5,7),false);eq(d.canStand(d.actors[2],6,3),false)
    end)
    test("invalid hidden duplicate missing actor and reservation payloads reject without mutation",function()
        local d,record,location,world=mart();local before=WorldTiles:maxID();local rng=RulesRNG.toData()
        local bad=Party._primitive(record);bad.actors[2].id="unknown:actor";rejects(function()SourceActors.validate(bad,world,location,flags())end)
        bad=Party._primitive(record);bad.actors[2].tick=8;rejects(function()SourceActors.validate(bad,world,location,flags())end)
        bad=Party._primitive(record);bad.actors[2].extra=true;rejects(function()SourceActors.validate(bad,world,location,flags())end)
        bad=Party._primitive(record);bad.actors[2]=Party._primitive(bad.actors[1]);rejects(function()SourceActors.validate(bad,world,location,flags())end)
        bad=Party._primitive(record);table.remove(bad.actors);bad.count=bad.count-1;rejects(function()SourceActors.validate(bad,world,location,flags())end)
        local occupied={zone_id=d.zone_id,x=5,y=3,facing="up"};rejects(function()SourceActors.validate(record,world,occupied,flags())end)
        local forest=SourceActors.describe("pokered:VIRIDIAN_FOREST",world);local f=flags();local all=WorldMotionData.reconcile(nil,forest,f)
        f.quest[PewterEvents.pickupFlag("pokered:VIRIDIAN_FOREST:objects:5")]=true
        rejects(function()WorldMotionData.normalize(all,forest,{zone_id=forest.zone_id,x=17,y=47,facing="up"},f)end)
        eq(WorldTiles:maxID(),before);same(RulesRNG.toData(),rng)
    end)
    test("new motion envelope rejects unknown versions and malformed independent RNG",function()
        local g=fresh();local wire=assert(SessionCodec.encode(g.session,{root="overworld",overworld="explore",settled=true}))
        wire.worldMotion.version=2;eq(SessionCodec.validate(wire,g:getSessionDependencies()),false)
        wire.worldMotion.version=1;wire.worldMotion.rng.rolls="01";eq(SessionCodec.validate(wire,g:getSessionDependencies()),false)
    end)
    test("native midstep actor reserves both cells and overlays freeze world and rules RNG",function()
        scene(function(g,m)
            local npc=g.npcManager.npcs[2];local before=RulesRNG.toData();m:tick();local value=assert(m:actor(npc));eq(value.phase,"moving");eq(value.tick,1)
            eq(g.npcManager:getNPCAt(value.origin_x,value.origin_y),npc);eq(g.npcManager:getNPCAt(value.target_x,value.target_y),npc)
            local world=g.session:worldRngData();local x,y=npc.x,npc.y;g.machine:push("pause")
            for _=1,20 do m:tick()end
            eq(npc.x,x);eq(npc.y,y);same(g.session:worldRngData(),world);same(RulesRNG.toData(),before);g.machine:pop()
        end)
    end)
    test("actual Codec stores midstep image position timers and replaying next updates is exact",function()
        scene(function(g,m)
            m:tick();local npc=g.npcManager.npcs[2];local x,y,image=npc.x,npc.y,npc:getImage()
            local position={zone_id=currentZone.stableID,x=g.player.gridX,y=g.player.gridY,facing=g.player.facing}
            assert(g.session:captureTraversal({location=position,world=WorldDeltas.export(),actors=m:snapshot()}))
            local wire=assert(SessionCodec.encode(g.session,{root="overworld",overworld="explore",settled=true}))
            for _=1,7 do m:tick()end
            local expected,expectedRNG=m:snapshot(),g.session:worldRngData();local expectedImage=npc:getImage()
            local restored=assert(SessionCodec.decode(wire,g:getSessionDependencies()));g.session=restored;m:attach(g,currentZone,restored:actorData())
            eq(npc.x,x);eq(npc.y,y);eq(npc:getImage(),image)
            for _=1,7 do m:tick()end
            same(m:snapshot(),expected);same(g.session:worldRngData(),expectedRNG);eq(npc:getImage(),expectedImage)
        end)
    end)
    test("invalid native attachment preserves current actor pose reservations and independent RNG",function()
        scene(function(g,m)
            m:tick();local before=m:snapshot();local rng=g.session:worldRngData();local bad=Party._primitive(before);bad.actors[1].id="unknown:actor"
            rejects(function()m:attach(g,currentZone,bad)end);same(m:snapshot(),before);same(g.session:worldRngData(),rng)
        end)
    end)
    test("actual session installation failure restores native actor pose cache and both RNG owners",function()
        scene(function(g,m)
            m:tick();local before=m:snapshot();local beforeWorldRNG=g.session:worldRngData();local beforeRules=RulesRNG.toData()
            local position={zone_id=currentZone.stableID,x=g.player.gridX,y=g.player.gridY,facing=g.player.facing}
            assert(g.session:captureTraversal({location=position,world=WorldDeltas.export(),actors=before}))
            local wire=assert(SessionCodec.encode(g.session,{root="overworld",overworld="explore",settled=true}))
            local candidate=assert(SessionCodec.decode(wire,g:getSessionDependencies()));local previous=g.session
            local previousZone=currentZone;local ids=WorldTiles:maxID();local failedView,restoredView
            local world=g.machine:get("overworld")
            world.enter=function(_,options)
                currentZone:spawnNPCs(g.npcManager);m:attach(g,currentZone,options.actors)
                local view=WorldView(currentZone,{attach=false})
                if currentZone.registry==WorldTiles then failedView=view;error("controlled actor controller install failure")end
                restoredView=view
            end
            local ok,problem=g:installSession(candidate)
            assert(not ok and tostring(problem):find("controlled actor controller install failure",1,true),"actual install must reject")
            assert(g.session==previous,"rollback session identity");assert(currentZone==previousZone,"rollback zone identity");same(m:snapshot(),before)
            same(g.session:worldRngData(),beforeWorldRNG);same(RulesRNG.toData(),beforeRules);assert(WorldTiles:maxID()==ids,"rollback tile IDs expected "..ids.." got "..WorldTiles:maxID())
            assert(failedView and failedView.disposed,"failed native view not disposed")
            assert(restoredView and not restoredView.disposed,"previous native actor view not rebuilt")
            restoredView:dispose();world.enter=nil
        end)
    end)
    test("repeated real Overworld draws cannot advance moving Player actors or either RNG",function()
        scene(function(g,m)
            local controller=OverworldState(g);controller.sub:change("explore")
            g.player:tryMove(1,0);eq(g.player.isMoving,true)
            for frame=1,8 do
                m:tick();g.player:update()
                local before={x=g.player.x,y=g.player.y,frames=g.player.moveFrames,toggle=g.player.walkToggle,rustle=g.player.rustleFrames,
                    actors=m:snapshot(),world=g.session:worldRngData(),rules=RulesRNG.toData()}
                for _=1,7 do controller:draw()end
                eq(g.player.x,before.x);eq(g.player.y,before.y);eq(g.player.moveFrames,before.frames)
                eq(g.player.walkToggle,before.toggle);eq(g.player.rustleFrames,before.rustle)
                same(m:snapshot(),before.actors);same(g.session:worldRngData(),before.world);same(RulesRNG.toData(),before.rules)
                eq(g.player.isMoving,frame<8)
            end
            eq(g.player.gridX,6);eq(g.player.gridY,6)
        end)
    end)
    test("real Player cannot enter moving NPC origin or reserved destination",function()
        scene(function(g,m)
            m:tick();local npc=g.npcManager.npcs[2];local value=m:actor(npc);eq(value.phase,"moving")
            for _,point in ipairs({{value.origin_x,value.origin_y},{value.target_x,value.target_y}})do
                g.player.gridX,g.player.gridY=point[1]-1,point[2];g.player:moveTo(g.player.gridX*TILE_SIZE,g.player.gridY*TILE_SIZE)
                assert(currentZone.collision[point[2]+1][point[1]]==0,"source fixture approach must be passable")
                g.player:tryMove(1,0);eq(g.player.isMoving,false);eq(g.player.gridX,point[1]-1);eq(g.player.gridY,point[2])
            end
        end)
    end)
    test("moving NPC interaction queues once and actual Event exit restores prior facing",function()
        scene(function(g,m)
            m:tick();local npc=g.npcManager.npcs[2];local value=m:actor(npc);eq(value.phase,"moving")
            g.player.gridX,g.player.gridY=value.target_x-1,value.target_y;g.player.facing="right"
            g.player:moveTo(g.player.gridX*TILE_SIZE,g.player.gridY*TILE_SIZE)
            assert(currentZone.collision[g.player.gridY+1][g.player.gridX+1]==0,"source queue fixture must be passable")
            eq(m:requestInteraction(npc,npc.def.source_event_id),true)
            local original=value.facing
            for _=1,8 do m:tick()end
            eq(g.machine:getCurrent(),"dialog");eq(npc.facing,"left")
            local before=g.session:worldRngData();for _=1,10 do m:tick()end;same(g.session:worldRngData(),before)
            clear(g.machine);eq(npc.facing,original);g.machine:change("overworld")
            for _=1,2 do m:tick()end;eq(g.machine:getCurrent(),"overworld")
        end)
    end)
    test("changed player intent and actor teardown invalidate queued interaction",function()
        scene(function(g,m)
            m:tick();local npc=g.npcManager.npcs[2];local value=m:actor(npc)
            g.player.gridX,g.player.gridY=value.target_x-1,value.target_y;g.player.facing="right"
            assert(m:requestInteraction(npc,npc.def.source_event_id));g.player.facing="left"
            for _=1,12 do m:tick()end;eq(g.machine:getCurrent(),"overworld")
            m:clear();same(m:snapshot(),WorldMotionData.empty());eq(m:occupantAt(value.origin_x,value.origin_y),nil)
        end)
    end)
    return report
end
