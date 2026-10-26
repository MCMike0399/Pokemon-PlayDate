PewterProviderContracts={}
local gfx=playdate.graphics
local function eq(a,b)assert(a==b,"expected "..tostring(b)..", got "..tostring(a))end
local function rejects(fn)local ok=pcall(fn);assert(not ok,"expected rejection")end
local function same(a,b)
    eq(type(a),type(b));if type(a)~="table" then eq(a,b);return end
    for key,value in pairs(a) do same(value,b[key]) end
    for key in pairs(b) do assert(a[key]~=nil,"unexpected field") end
end
local function sourceKey(name,x,y)
    local data=PewterSlice.compact();local d=data.maps[name]
    return d.palette[assert(tonumber(d.tile_rows[y+1]:sub(x*2+1,x*2+2),16))]
end
local function scope(fn)
    local oldRegistry,oldList,oldZone=zoneRegistry,zoneList,currentZone
    local oldStory,oldOwner,oldRng=Story.currentContext(),GameSession.activeRNGSession(),RulesRNG.toData()
    local oldWorld=WorldDeltas.export();local oldProvider=WorldDeltas.definitionProvider()
    local oldX,oldY=gfx.getDrawOffset();local sprites=gfx.sprite.spriteCount();local globalIDs=WorldTiles:maxID()
    local game=GameContext({sessionLocationPolicy=PewterWorld.locationPolicy()});assert(game:recruit(Pokemon("squirtle",5)))
    assert(game.session:setIntro({stage="done",starter="squirtle",rivalStarter="bulbasaur"}))
    local registry=TileRegistry();local provider=PewterWorld.createProvider(game,registry)
    zoneRegistry,zoneList={},{}
    for _,key in ipairs(oldList) do local zone=oldRegistry[key]
        if not oldProvider or not oldProvider:owns(zone) then zoneRegistry[key]=zone;zoneList[#zoneList+1]=key end
    end
    currentZone=oldZone
    local ok,problem=pcall(function() WorldDeltas._withDefinitionProvider(provider,function()fn(game,provider,registry)end) end)
    if game.player then game.player:remove();game.player.grassOverlay:remove();game.player.exitArrow:remove();game.player=nil end
    game.npcManager:clear();provider:disposeCache()
    if GameSession.activeRNGSession()==game.session then game.session:deactivateRNG() end
    if oldOwner then oldOwner:activateRNG() else RulesRNG.restoreData(oldRng) end
    zoneRegistry,zoneList,currentZone=oldRegistry,oldList,oldZone;Story.bind(oldStory)
    WorldDeltas.apply(oldWorld);gfx.setDrawOffset(oldX,oldY)
    eq(WorldTiles:maxID(),globalIDs);eq(gfx.sprite.spriteCount(),sprites)
    if not ok then error(problem,0) end
end
function PewterProviderContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)
        local ok,err=pcall(fn);report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(err) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("imported factory rejects mismatched registries and invalid isolation flags before native allocation",function()
        local globalIDs=WorldTiles:maxID();local registry=TileRegistry();local localIDs=registry:maxID()
        local d=PewterSlice.padded("Route2")
        local function reject(actual,claimed,isolated,expected)
            local ok,problem=pcall(Zone.fromMapDefinition,d,actual,{registry=claimed,isolatedCatalog=isolated})
            assert(not ok and tostring(problem):find(expected,1,true),"wrong factory rejection: "..tostring(problem))
            eq(WorldTiles:maxID(),globalIDs);eq(registry:maxID(),localIDs)
        end
        reject(WorldTiles,registry,true,"registry option must match actual registry")
        reject(WorldTiles,WorldTiles,true,"isolated catalog requires actual private registry")
        reject(registry,registry,"yes","isolated catalog flag must be boolean")
        reject(registry,WorldTiles,false,"registry option must match actual registry")
    end)
    test("eight actual source Zone definitions validate with private numeric registry and compact terrain",function()
        local count=#zoneList;local ids=WorldTiles:maxID()
        for _,name in ipairs(PewterSlice.names()) do
            local zone=PewterWorld.isolated(name);local d=PewterSlice.descriptor(name)
            eq(zone.stableID,d.id);eq(zone.width,d.width);eq(zone.height,d.height);eq(zone:isSliceReady(),true);eq(zone:isCampaignReady(),false)
            local sample=zone:terrainAt(0,0);sample.land_passable=not sample.land_passable
            assert(zone:terrainAt(0,0).land_passable~=sample.land_passable)
        end
        eq(WorldTiles:maxID(),ids);eq(#zoneList,count)
    end)
    test("gate door-foot auto-step and bottom outward mats preserve source projections",function()
        local d=PewterSlice.padded("Route2");local north=PewterSlice.warpSpec("Route2",d.events.warps[2])
        eq(north.toX,6);eq(north.toY,1);eq(north.facing,"down");eq(north.arrival_advance,1)
        d=PewterSlice.padded("ViridianForestNorthGate");local exit=PewterSlice.warpSpec("ViridianForestNorthGate",d.events.warps[2])
        eq(exit.toX,3);eq(exit.toY,11);eq(exit.arrival_advance,0);eq(exit.preserveFacing,true)
        local south=PewterWorld.isolated("ViridianForestSouthGate");local door=assert(south:getEdgeDoorAt(5,7,"down"))
        eq(door.toX,3);eq(door.toY,44);eq(door.facing,"down");eq(south:getDoorAt(5,7),nil)
        local gym=PewterWorld.isolated("PewterGym");eq(gym:getEdgeDoorAt(5,13,"down").toY,18)
    end)
    test("unimplemented source exits remain physical blockers and no NPC uses Oak fallback",function()
        local route=PewterWorld.isolated("Route2");eq(route.collision[10][13],1);local ok,problem=pcall(route.getDoorAt,route,12,9);assert(not ok and tostring(problem):find("unresolved source warp: pokered:ROUTE_2:warps:1",1,true))
        local city=PewterWorld.isolated("PewterCity");eq(city.collision[8][15],1);ok,problem=pcall(city.getDoorAt,city,14,7);assert(not ok and tostring(problem):find("unresolved source warp: pokered:PEWTER_CITY:warps:1",1,true))
        for _,name in ipairs(PewterSlice.names()) do for _,def in ipairs(PewterWorld.isolated(name).npcDefs) do
            assert(def.sprite~="oak" and def.source_sprite and def.source_event_id,"missing explicit source NPC art/identity")
        end end
    end)
    test("unloaded checkpoint validation and inventory allocate no global or private render IDs",function()
        scope(function(g,p,registry)
            local before=registry:maxID();eq(#p:inventory(),12);eq(#p:snapshot().cached,0)
            local location={zone_id="pokered:PEWTER_CITY",x=13,y=26,facing="down"}
            same(WorldDeltas.resolveLocation(location,{schema=1,zone_count=0,zones={}},g.sessionLocationPolicy),location)
            eq(registry:maxID(),before);eq(#p:snapshot().cached,0)
            rejects(function()WorldDeltas.resolveLocation(location,{schema=1,zone_count=0,zones={}},{sliceZones={}})end)
        end)
    end)
    test("LRU has two Zones pins current actors and retains sparse mutation after eviction",function()
        scope(function(g,p,registry)
            local route=p:ensure("kanto_route2");currentZone=route
            route:setTile(8,70,"adapter:pewter:void");eq(route.collision[71][9],1)
            local gate=p:ensure("kanto_forest_south_gate");currentZone=gate
            local release=p:pin(route)
            rejects(function()p:ensure("kanto_viridian_forest")end);eq(#p:snapshot().cached,2)
            release();local forest=p:ensure("kanto_viridian_forest");eq(#p:snapshot().cached,2);eq(zoneRegistry.kanto_route2,nil)
            currentZone=forest;local reload=p:ensure("kanto_route2")
            eq(reload.collision[71][9],1);eq(reload.registry:key(reload.tiles[71][9]),"adapter:pewter:void")
            eq(p:export().zone_count,1);eq(p:export().zones[1].tile_count,1)
            reload:setTile(8,70,sourceKey("Route2",8,70));eq(p:export().zone_count,0)
        end)
    end)
    test("mutate evict encode decode apply reload keeps exact sparse state and checkpoint cold",function()
        scope(function(g,p,registry)
            local route=p:ensure("kanto_route2");currentZone=route;route:setTile(8,70,"adapter:pewter:void")
            local gate=p:ensure("kanto_forest_south_gate");currentZone=gate;p:ensure("kanto_viridian_forest")
            local world=WorldDeltas.export();local location={zone_id="pokered:ROUTE_2",x=8,y=71,facing="up"}
            assert(g.session:captureTraversal({world=world,location=location,checkpoint={zone_id="pokered:PEWTER_CITY",x=13,y=26,facing="down"}}))
            local wire=assert(SessionCodec.encode(g.session,{root="overworld",overworld="explore",settled=true}))
            local before=registry:maxID();local cached=p:snapshot().cached
            local restored=assert(SessionCodec.decode(wire,g:getSessionDependencies()))
            eq(registry:maxID(),before);same(p:snapshot().cached,cached);same(restored:worldData(),world)
            eq(zoneRegistry.kanto_pewter_city,nil)
            WorldDeltas.reset();eq(p:export().zone_count,0);WorldDeltas.apply(restored:worldData())
            currentZone=zoneRegistry.kanto_viridian_forest
            local reload=p:ensure("kanto_route2");eq(reload.registry:key(reload.tiles[71][9]),"adapter:pewter:void")
        end)
    end)
    test("invalid world payloads fail pure validation without cache ID ledger or quest mutation",function()
        scope(function(g,p,registry)
            local beforeIDs=registry:maxID();local before=p:snapshot();local flags=g.session:flags()
            local record={schema=1,zone_id="pokered:ROUTE_2",definition_revision="af519899719f0754965776faac0e836a3b906e6d",tile_count=1,tiles={{x=8,y=70,key="unknown:tile"}}}
            rejects(function()WorldDeltas.validate({schema=1,zone_count=1,zones={record}})end)
            record.tiles[1].key="base:25";record.extra=true
            rejects(function()WorldDeltas.validate({schema=1,zone_count=1,zones={record}})end);record.extra=nil
            record.tiles[1].x=20;rejects(function()WorldDeltas.validate({schema=1,zone_count=1,zones={record}})end)
            eq(registry:maxID(),beforeIDs);same(p:snapshot(),before);same(g.session:flags(),flags);eq(p:export().zone_count,0)
        end)
    end)
    test("native view rejection rolls back collision ledger and newly allocated registry keys",function()
        scope(function(g,p,registry)
            local route=p:ensure("kanto_route2");currentZone=route;local before=registry:maxID();local key=route.registry:key(route.tiles[71][9])
            rejects(function()route:setTile(8,70,"unknown:tile")end)
            rejects(function()route:setTile(8,70,-1)end)
            eq(registry:maxID(),before);eq(p:export().zone_count,0)
            local fault={applyTiles=function()error("controlled native view rejection")end}
            route:attachView(fault)
            rejects(function()route:setTile(8,70,"adapter:pewter:void")end)
            route:detachView(fault)
            eq(route.registry:key(route.tiles[71][9]),key);eq(route.collision[71][9],0);eq(p:export().zone_count,0);eq(registry:maxID(),before)
        end)
    end)
    test("provider reset clears durable ledger then safely disposes later-loaded cached Zones",function()
        scope(function(g,p,registry)
            local route=p:ensure("kanto_route2");currentZone=route;route:setTile(8,70,"adapter:pewter:void")
            local view=WorldView(route,{attach=false});assert(not view.disposed)
            WorldDeltas.reset();eq(p:export().zone_count,0);WorldDeltas.disposeImportedCache()
            eq(view.disposed,true);eq(#p:snapshot().cached,0);eq(zoneRegistry.kanto_route2,nil)
            currentZone=zoneRegistry.reds_house_2f
            local fresh=p:ensure("kanto_route2");eq(fresh.collision[71][9],0)
        end)
    end)
    test("Pewter source text coverage includes real badge TM receipts and original trainer money",function()
        local pages=PewterEvents.pages({"_PewterGymBrockReceivedBoulderBadgeText","_PewterGymBrockBoulderBadgeInfoText","_PewterGymReceivedTM34Text","_TM34ExplanationText"})
        assert(#pages>=4)
        local money=PewterEvents.pages({"_MoneyForWinningText"},{wAmountMoneyWon=1386})
        assert(money[1].text:find("1386",1,true))
        local found=PewterEvents.pages({"_FoundItemText"},{wStringBuffer="POTION"});assert(found[1].text:find("POTION",1,true))
    end)
    return report
end
