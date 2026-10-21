-- Production session, menu, source descriptors and real native views; no Lua shim.
FieldItemContracts={}
local gfx=playdate.graphics
local function eq(a,b)assert(a==b,"expected "..tostring(b)..", got "..tostring(a))end
local function same(a,b)
    if type(a)~=type(b)then return false end;if type(a)~="table"then return a==b end
    for k,v in pairs(a)do if not same(v,b[k])then return false end end
    for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local function write(name)if HarnessBuild and HarnessBuild.enabled and playdate.simulator then playdate.simulator.writeToFile(gfx.getWorkingImage(),HarnessBuild.output_dir..name..".png")end end
local function closeDialog(g)
    eq(g.machine:getCurrent(),"dialog");local callback=g.machine:get("dialog").onComplete
    g.machine:pop();if callback then return callback()end
end
local function scene(name,fn)
    local oldZone,oldStory,oldOwner,oldRng=currentZone,Story.currentContext(),GameSession.activeRNGSession(),RulesRNG.toData()
    local undo=WorldDeltas.checkpointRuntime();local sprites,sets={},{};local count,ids=gfx.sprite.spriteCount(),WorldTiles:maxID()
    local ox,oy=gfx.getDrawOffset();local screen=gfx.getWorkingImage():copy();local g
    for _,s in ipairs(gfx.sprite.getAllSprites())do sprites[s]={visible=s:isVisible(),enabled=s:updatesEnabled()}end
    for k,v in pairs(SpriteFactory.npc)do sets[k]=v end
    local ok,problem=pcall(function()
        g=GameContext({sessionLocationPolicy=PewterWorld.locationPolicy()});assert(g:recruit(Pokemon("squirtle",16)))
        assert(g.session:setIntro({stage="done",starter="squirtle",rivalStarter="bulbasaur"}));Story.bind(g)
        if name=="forest"then
            currentZone=PewterWorld.isolated("ViridianForest");PewterSprites.installFor(PewterSlice.padded("ViridianForest"))
        else currentZone=zoneRegistry.blues_house end
        g.machine:register("overworld",OverworldState(g));g.machine:register("bag",BagState(g));g.machine:register("pause",PauseState(g))
        g.machine:register("dialog",DialogState(g));g.machine:register("townMap",TownMapState(g))
        local entry=name=="forest"and{x=25,y=33,facing="up"}or{x=6,y=5,facing="up"}
        g.machine:change("overworld",{entry=entry})
        assert(g.session:captureTraversal({location={zone_id=currentZone.stableID,x=entry.x,y=entry.y,facing=entry.facing},
            world=WorldDeltas.export(),actors=g.npcManager.motion:snapshot(),checkpoint={zone_id="pallet_town",x=9,y=0,facing="up"}}))
        fn(g)
    end)
    if g then
        while #g.machine.stack>0 do local state=table.remove(g.machine.stack);pcall(state.exit,state)end
        g.npcManager:clear();if g.player then g.player:remove();g.player.grassOverlay:remove();g.player.exitArrow:remove();if g.player.jumpShadow then g.player.jumpShadow:remove()end end
    end
    undo()
    for _,s in ipairs(gfx.sprite.getAllSprites())do if not sprites[s]then s:remove()end end
    local present={};for _,s in ipairs(gfx.sprite.getAllSprites())do present[s]=true end
    for s,v in pairs(sprites)do if not present[s]then s:add()end;s:setVisible(v.visible);s:setUpdatesEnabled(v.enabled)end
    for k in pairs(SpriteFactory.npc)do if not sets[k]then SpriteFactory.npc[k]=nil end end;for k,v in pairs(sets)do SpriteFactory.npc[k]=v end
    currentZone=oldZone;Story.bind(oldStory)
    local owner=GameSession.activeRNGSession();if owner~=oldOwner then if owner then owner:deactivateRNG()end;if oldOwner then oldOwner:activateRNG()end end
    RulesRNG.restoreData(oldRng);gfx.setDrawOffset(0,0);screen:draw(0,0);gfx.setDrawOffset(ox,oy)
    eq(gfx.sprite.spriteCount(),count);eq(WorldTiles:maxID(),ids)
    if not ok then error(problem,0)end
end
local function bag(g)
    assert(g.session:inventory():add("escapeRope",2));g.machine:push("bag");return g.machine:get("bag")
end
function FieldItemContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)
        local ok,error=pcall(fn);report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(error)or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("pinned Forest escape allowance rejects outdoors, shops, gyms, authored rooms, Agatha and unknowns",function()
        eq(FieldItems.canEscape("pokered:VIRIDIAN_FOREST"),true)
        for _,id in ipairs({"pokered:ROUTE_2","pokered:PEWTER_MART","pokered:PEWTER_GYM","blues_house","pokered:AGATHAS_ROOM","unknown"})do eq(FieldItems.canEscape(id),false)end
        eq(FieldItems.canEscape(false),false)
    end)
    test("opaque Rope cancellation and stale Bag visit never consume or move",function()
        scene("forest",function(g)
            local b=bag(g);local before=g.session:inventory():toData();local actors=g.npcManager.motion:snapshot()
            local request=assert(FieldItems.prepareEscape(g,b));assert(FieldItems.cancel(request));eq(FieldItems.useEscape(g,request),false)
            request=assert(FieldItems.prepareEscape(g,b));g.machine:pop();g.machine:push("bag");eq(FieldItems.useEscape(g,request),false)
            eq(FieldItems.useEscape(g,{}),false);assert(same(before,g.session:inventory():toData()));assert(same(actors,g.npcManager.motion:snapshot()))
        end)
    end)
    test("changed Rope stock and invalid pure checkpoint reject before reconstruction",function()
        scene("forest",function(g)
            local b=bag(g);local request=assert(FieldItems.prepareEscape(g,b));assert(g.session:inventory():consume("escapeRope",1))
            eq(FieldItems.useEscape(g,request),false);eq(currentZone.stableID,"pokered:VIRIDIAN_FOREST")
            local original=g.getSessionDependencies;g.getSessionDependencies=function(self)local d=original(self);d.resolveLocation=function()error("controlled invalid checkpoint")end;return d end
            eq(FieldItems.prepareEscape(g,b),nil);eq(g.session:inventory():quantity("escapeRope"),1)
        end)
    end)
    test("successful actual native reconstruction consumes exactly one, preserves party/bag identities and both streams",function()
        scene("forest",function(g)
            local b=bag(g);local inventory,party,mon=g.session:inventory(),g.session:party(),g:getPlayerPokemon()
            local monData=assert(PokemonCodec.encode(mon));local money=inventory:money();local rng,world=RulesRNG.toData(),g.session:worldRngData()
            assert(FieldItems.confirmEscape(b));eq(b.phase,"field-confirm");local request=b.fieldRequest
            eq(g.session:useEscapeRope(request),false)
            local rejected=false
            g.machine:on("changed",function(kind,from,to)
                if to=="overworld"then local ok,reason=g.session:useEscapeRope(request);eq(ok,false);eq(reason,"stale-selection");rejected=true end
            end)
            b.menu.onSelect(2);eq(rejected,true)
            eq(g.lastFieldItem.kind,"escape-rope")
            eq(currentZone.stableID,"pallet_town");eq(g.player.gridX,9);eq(g.player.gridY,0);eq(g.player.facing,"up")
            eq(inventory:quantity("escapeRope"),1);eq(inventory:money(),money);eq(g.session:inventory(),inventory);eq(g.session:party(),party);eq(g:getPlayerPokemon(),mon)
            assert(same(PokemonCodec.encode(mon),monData));assert(same(RulesRNG.toData(),rng));assert(same(g.session:worldRngData(),world))
            eq(FieldItems.useEscape(g,request),false);eq(inventory:quantity("escapeRope"),1)
            eq(g.session:location().zone_id,"pallet_town")
            local encoded=assert(SessionCodec.encode(g.session,{root="overworld",overworld="explore",settled=true}))
            local decoded=assert(SessionCodec.decode(encoded,g:getSessionDependencies()))
            eq(decoded:inventory():quantity("escapeRope"),1);eq(decoded:location().zone_id,"pallet_town")
            g.machine:get("overworld"):flushPendingPresentation();g.machine:draw();write("field-rope-arrival")
        end)
    end)
    test("actual post-build failure restores source position/actors, retained bag and sprite membership without charge",function()
        scene("forest",function(g)
            local b=bag(g);local request=assert(FieldItems.prepareEscape(g,b));local before=g.npcManager.motion:snapshot();local inventory=g.session:inventory()
            local rng,world=RulesRNG.toData(),g.session:worldRngData();local w=g.machine:get("overworld");local enter=w.enter;local injected=false
            w.enter=function(self,options)
                enter(self,options)
                if currentZone.stableID=="pallet_town"and not injected then injected=true;error("controlled rejection after real target view build")end
            end
            eq(FieldItems.useEscape(g,request),false);assert(injected);eq(currentZone.stableID,"pokered:VIRIDIAN_FOREST")
            eq(g.player.gridX,25);eq(g.player.gridY,33);eq(inventory:quantity("escapeRope"),2);eq(g.session:inventory(),inventory)
            assert(same(g.npcManager.motion:snapshot(),before));assert(same(RulesRNG.toData(),rng));assert(same(g.session:worldRngData(),world))
        end)
    end)
    test("Daisy requires actual Pokedex flag, full-bag retries, grants once and repeat advice cannot duplicate",function()
        scene("daisy",function(g)
            assert(FieldItems.tryDaisy(g));closeDialog(g);eq(g.session:inventory():quantity("townMap"),0)
            assert(g.session:setQuestFlag("EVENT_GOT_POKEDEX",true))
            local ids={};for id,item in pairs(ItemData.definitions)do if id~="townMap"and not item.keyItem then ids[#ids+1]=id end end;table.sort(ids)
            for i=1,20 do assert(g.session:inventory():add(ids[i],1))end
            assert(FieldItems.tryDaisy(g));closeDialog(g);eq(g.session:questFlag("EVENT_GOT_TOWN_MAP"),false);eq(g.session:inventory():quantity("townMap"),0);closeDialog(g)
            assert(g.session:inventory():consume(ids[1],1));assert(FieldItems.tryDaisy(g));closeDialog(g)
            eq(g.session:questFlag("EVENT_GOT_TOWN_MAP"),true);eq(g.session:inventory():quantity("townMap"),1);closeDialog(g)
            assert(FieldItems.tryDaisy(g));closeDialog(g);eq(g.session:inventory():quantity("townMap"),1)
        end)
    end)
    test("Daisy completion from an expired quest state cannot award a map",function()
        scene("daisy",function(g)
            assert(g.session:setQuestFlag("EVENT_GOT_POKEDEX",true));assert(FieldItems.tryDaisy(g));assert(g.session:setQuestFlag("EVENT_GOT_POKEDEX",false))
            eq(closeDialog(g),false);eq(g.session:inventory():quantity("townMap"),0);eq(g.session:questFlag("EVENT_GOT_TOWN_MAP"),false)
        end)
    end)
    test("Town Map original grid/order/locations and native paused rendering do not consume either RNG or actors",function()
        scene("forest",function(g)
            local b=bag(g);eq(TownMapState.open(g),false);assert(g.session:inventory():add("townMap",1));assert(TownMapState.open(g))
            local m=g.machine:get("townMap");local d=TownMapData.get();eq(#d.cells,360);eq(#d.order,47);eq(d.locations.PALLET_TOWN.x,2);eq(d.locations.VIRIDIAN_FOREST.y,4)
            local rng,world,actors=RulesRNG.toData(),g.session:worldRngData(),g.npcManager.motion:snapshot()
            for _=1,11 do m:draw()end;write("field-town-map-forest");m.browsing=true;m.selected=1;m:draw();write("field-town-map-pallet-selected")
            assert(same(RulesRNG.toData(),rng));assert(same(g.session:worldRngData(),world));assert(same(g.npcManager.motion:snapshot(),actors))
            g.machine:pop();eq(g.machine:current(),b);eq(g.session:inventory():quantity("townMap"),1)
        end)
    end)
    return report
end
