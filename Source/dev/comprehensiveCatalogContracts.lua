ComprehensiveCatalogContracts={}
local function eq(a,b) assert(a==b,"expected "..tostring(b)..", got "..tostring(a)) end
local function imageEqual(a,b)
    local aw,ah=a:getSize();local bw,bh=b:getSize();eq(aw,bw);eq(ah,bh)
    for y=0,ah-1 do for x=0,aw-1 do eq(a:sample(x,y),b:sample(x,y)) end end
end
local function record(stem,writer)
    return {inventory=function()return {images={{path=stem..".png",width=32,height=32,category="test",mask=false}}}end,writer=writer}
end
local function temporary(name,protocol,callback)
    local unregister=VisualCatalog.registerExporter(name,protocol)
    local values=table.pack(pcall(callback));unregister();assert(values[1],values[2]);return table.unpack(values,2,values.n)
end
local function rejected(fn,fragment)
    local ok,error=pcall(fn);assert(not ok,"expected exporter rejection")
    assert(tostring(error):find(fragment,1,true),tostring(error))
end
function ComprehensiveCatalogContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)
        local ok,error=pcall(fn);report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(error) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("Full inventory declares original1635 and859 additions with all8 unvisited maps",function()
        local inventory=VisualCatalog.expectedInventory();eq(#inventory.images,2494);eq(#inventory.exporters.pewter.images,859)
        local paths={};for _,entry in ipairs(inventory.images) do assert(not paths[entry.path]);paths[entry.path]=true end
        for _,name in ipairs(PewterSlice.names()) do
            for _,kind in ipairs({"terrain","collision","actors","events","viewport"}) do assert(paths["pewter-"..name.."-"..kind..".png"]) end
        end
        local poses=PewterCatalogExporter.poses();eq(#poses,120)
        local known={};for _,entry in ipairs(poses) do known[entry.name]=true
            for _,suffix in ipairs({"","__mask","__white","__black","__texture"}) do assert(paths[entry.name..suffix..".png"]) end
        end
    end)
    test("Named exporter protocol rejects invalid sparse unsafe and duplicate inventory",function()
        rejected(function()VisualCatalog.registerExporter("../bad",record("safe",function()end))end,"exporter name")
        rejected(function()VisualCatalog.registerExporter("sparse",{inventory=function()return {images={[2]={path="ok.png"}}}end,writer=function()end})end,"dense")
        rejected(function()VisualCatalog.registerExporter("unsafe",record("../escape",function()end))end,"unsafe")
        temporary("dupe-a",record("dupe",function()end),function()
            temporary("dupe-b",record("dupe",function()end),function()
                rejected(VisualCatalog.expectedInventory,"duplicate")
            end)
            rejected(function()VisualCatalog.registerExporter("dupe-a",record("another",function()end))end,"duplicate")
        end)
        temporary("protected-dupe",record("tile_01",function()end),function()rejected(VisualCatalog.expectedInventory,"duplicate")end)
    end)
    test("Writer rejects missing undeclared and duplicate paths before accepting a report",function()
        local image=playdate.graphics.image.new(32,32,playdate.graphics.kColorWhite)
        for _,kind in ipairs({"missing","undeclared","duplicate"}) do
            temporary("fault-"..kind,record("checked",function(sink)
                if kind=="missing" then return {} end
                sink.save(kind=="undeclared" and "outside" or "checked",image,"test",false)
                if kind=="duplicate" then sink.save("checked",image,"test",false) end
            end),function()rejected(function()VisualCatalog.runExporter("fault-"..kind,function()end)end,kind)end)
        end
    end)
    test("Faulting exporter restores supported live world palette LRU RNG and actor state",function()
        local before=CatalogRuntime.snapshot()
        temporary("mutating-fault",record("never-written",function()
            WorldDeltas.ensureZone("kanto_route2")
            local zone=zoneRegistry.test_zone;local old=zone.registry:key(zone.tiles[1][1]);zone:setTile(0,0,old=="base:1" and "base:2" or "base:1")
            currentZone=zoneRegistry.blues_house;RulesRNG.random(1,100)
            if game.player then game.player.gridX=game.player.gridX+1;game.player:moveTo(777,888) end
            game.camera.x=game.camera.x+23;game.camera.y=game.camera.y-5
            local sprite=playdate.graphics.sprite.new(playdate.graphics.image.new(1,1));sprite:add()
            error("controlled catalog fault")
        end),function()rejected(function()VisualCatalog.runExporter("mutating-fault",function()end)end,"controlled catalog fault")end)
        local after=CatalogRuntime.snapshot();assert(CatalogRuntime.same(before,after),"supported live state not restored")
        temporary("mutating-return",record("never-written",function(sink)sink.save("never-written",playdate.graphics.image.new(32,32,playdate.graphics.kColorWhite),"test",false);RulesRNG.random(1,100);return {} end),function()
            rejected(function()VisualCatalog.runExporter("mutating-return",function()end)end,"side effect")
        end)
    end)
    test("Durable mon held-item bag existing flags and nested actor values are observed and restored",function()
        local original=CatalogRuntime.snapshot();local oldSession=game.session;local oldOwner=GameSession.activeRNGSession();local oldRNG=RulesRNG.toData()
        local player=game.player;local pending=player and player.pendingEdgeDoor
        local ok,error=pcall(function()
            local session=GameSession.newSession(game:getSessionDependencies(),{location=oldSession:location(),checkpoint=oldSession:checkpoint(),world=oldSession:worldData(),seed=42})
            local mon=Pokemon("charmander",5);assert(session:recruit(mon));assert(session:setIntro({stage="done",starter="charmander",rivalStarter="squirtle",rivalOutcome=true}))
            assert(session:setQuestFlag("catalog:existing",false));game.session=session;assert(session:activateRNG())
            if player then player.pendingEdgeDoor={to="test_zone",source={marker="before"}} end
            local before=CatalogRuntime.snapshot();local moves,pp=mon.moves,mon.pp
            temporary("model-mutation",record("model-check",function(sink)
                sink.save("model-check",playdate.graphics.image.new(32,32,playdate.graphics.kColorWhite),"test",false)
                mon.hp=mon.hp-1;mon.heldItem="potion";mon.pp[mon.moves[1]]=0;mon.statStages.atk=4
                assert(session:inventory():add("potion",1));assert(session:setQuestFlag("catalog:existing",true))
                if player then player.pendingEdgeDoor.source.marker="changed-in-place" end
                return {}
            end),function()rejected(function()VisualCatalog.runExporter("model-mutation",function()end)end,"side effect")end)
            assert(CatalogRuntime.same(before,CatalogRuntime.snapshot()),"supported durable/nested values not restored")
            eq(mon.moves,moves);eq(mon.pp,pp);eq(session:inventory():quantity("potion"),0);eq(session:questFlag("catalog:existing"),false)
            temporary("unsupported-model",record("model-check",function(sink)
                sink.save("model-check",playdate.graphics.image.new(32,32,playdate.graphics.kColorWhite),"test",false)
                assert(session:setQuestFlag("catalog:new-key",true));return {}
            end),function()rejected(function()VisualCatalog.runExporter("unsupported-model",function()end)end,"unrestored/unsupported state")end)
            eq(session:questFlag("catalog:new-key"),true) -- honest unsupported-key report; fixture is discarded below
        end)
        if player then player.pendingEdgeDoor=pending end
        game.session=oldSession;local active=GameSession.activeRNGSession();if active then active:deactivateRNG() end
        if oldOwner then assert(oldOwner:activateRNG()) end;assert(RulesRNG.restoreData(oldRNG))
        assert(CatalogRuntime.same(original,CatalogRuntime.snapshot()),"model qualification fixture leaked")
        assert(ok,error)
    end)
    test("Exact sprite cadence matches real PewterSprites standing walk flip API in every direction",function()
        local sets={};for key,value in pairs(SpriteFactory.npc) do sets[key]=value end
        local ok,error=pcall(function()
            for _,name in ipairs(PewterSlice.names()) do PewterSprites.installFor(PewterSlice.padded(name)) end
            local poses=PewterCatalogExporter.poses();local bySource={}
            for _,entry in ipairs(poses) do
                local image=PewterSprites.frame(entry.source,entry.source_frame);if entry.flip_x then image=SpriteFactory.flipped(image) end
                bySource[entry.source]=bySource[entry.source] or {};bySource[entry.source][entry.pose..entry.direction]=image
            end
            local source=assert(json.decodeFile("data/pewterSlice/sprites.json"));local checked=0
            for constant,binding in pairs(source.mapping) do if next(source.sprites[binding.name].walking) then
                for _,dir in ipairs({"down","up","left","right"}) do for tick=1,8 do
                    local phase=(tick//2)%4;local pose=phase==1 and "walk" or phase==3 and "alternate" or "stand"
                    imageEqual(PewterSprites.stepImage(constant,dir,tick),bySource[constant][pose..dir]);checked=checked+1
                end end
            end end
            eq(checked,256)
        end)
        for key in pairs(SpriteFactory.npc) do SpriteFactory.npc[key]=nil end;for key,value in pairs(sets) do SpriteFactory.npc[key]=value end
        assert(ok,error)
    end)
    test("Two859-image native inventories cover visit eviction allocations for strict host RGBA comparison",function()
        local before=CatalogRuntime.snapshot();local undo=WorldDeltas.checkpointRuntime()
        local sets={};for key,value in pairs(SpriteFactory.npc) do sets[key]=value end
        local ok,error=pcall(function()
            local inventory=VisualCatalog.expectedInventory()
            assert(HarnessBuild and HarnessBuild.enabled and playdate.simulator,"private native exporter qualification required")
            local function emit(phase)
                local images={}
                local metadata=VisualCatalog.runExporter("pewter",function(stem,image,category,mask)
                    local w,h=image:getSize();local path=stem..".png"
                    playdate.simulator.writeToFile(image,HarnessBuild.output_dir.."catalog-invariance-"..phase.."/"..path)
                    images[#images+1]={path=path,width=w,height=h,category=category,mask=mask or false}
                end)
                eq(#images,859)
                json.encodeToFile("catalog-invariance-"..phase..".json",true,{schema=1,images=images,missing={},image_root=".",metadata=metadata})
                return metadata
            end
            local first=emit("before")
            for _,name in ipairs(PewterSlice.names()) do
                local d=PewterSlice.descriptor(name);WorldDeltas.ensureZone(d.key)
            end
            assert(CatalogRuntime.same(inventory,VisualCatalog.expectedInventory()),"inventory varies with LRU/global IDs")
            local visited=CatalogRuntime.snapshot()
            local second=emit("after")
            assert(CatalogRuntime.same(first,second),"exporter metadata varies with cache")
            assert(CatalogRuntime.same(visited,CatalogRuntime.snapshot()),"export touched visited world")
        end)
        currentZone=before.zone;undo()
        for key in pairs(SpriteFactory.npc) do SpriteFactory.npc[key]=nil end;for key,value in pairs(sets) do SpriteFactory.npc[key]=value end
        assert(CatalogRuntime.same(before,CatalogRuntime.snapshot()),"catalog qualification fixture did not restore live state")
        assert(ok,error)
    end)
    return report
end
