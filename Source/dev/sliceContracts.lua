SliceContracts = {}
local function eq(a,b) assert(a==b,"expected "..tostring(b)..", got "..tostring(a)) end
local function rejects(fn) local ok=pcall(fn);assert(not ok,"expected rejection") end
local function state() return {intro="done",flags={},items={potion=0,oaksParcel=0},can_add={potion=true,oaksParcel=true}} end
local function options(registry) return {registry=registry or TileRegistry(),dispatch=function(id) error("SDK contract does not execute UI: "..id) end,questFlag=function() return false end} end
local function sprites(fn)
    local before={};for key,value in pairs(SpriteFactory.npc) do before[key]=value end
    SliceSprites.install()
    local ok,problem=pcall(fn)
    for key in pairs(SpriteFactory.npc) do if before[key]==nil then SpriteFactory.npc[key]=nil end end
    for key,value in pairs(before) do SpriteFactory.npc[key]=value end
    if not ok then error(problem,0) end
end
function SliceContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)
        local ok,problem=pcall(fn);report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(problem) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("new sprite phase0 mixed shades preserve exact independent pixels mask and flip",function()
        local gfx=playdate.graphics;local rows={}
        for y=0,15 do
            local row={}
            for x=0,15 do
                if x==0 or y==0 or x==15 or y==15 then row[x+1]="."
                elseif x==1 or y==1 or x==14 or y==14 then row[x+1]="#"
                else local codes={".","1","2","#"};row[x+1]=codes[(x+3*y)%4+1] end
            end
            rows[y+1]=table.concat(row)
        end
        local image=SpriteFactory.makeSprite(rows,{0,0});local mask=image:getMaskImage()
        local light={0xBB,0xFF,0xEE,0xFF,0xBB,0xFF,0xEE,0xFF};local dark={0x55,0xAA,0x55,0xAA,0x55,0xAA,0x55,0xAA}
        for y=0,31 do for x=0,31 do
            local sx,sy=x//2,y//2;local opaque=sx>=1 and sx<=14 and sy>=1 and sy<=14
            eq(mask:sample(x,y),opaque and gfx.kColorWhite or gfx.kColorBlack)
            if opaque then
                local code=rows[sy+1]:sub(sx+1,sx+1);local white=code=="."
                if code=="1" or code=="2" then local bytes=code=="1" and light or dark;white=(bytes[y%8+1] & (0x80>>(x%8)))~=0 end
                eq(image:sample(x,y),white and gfx.kColorWhite or gfx.kColorBlack)
            end
        end end
        local right=SpriteFactory.flipped(image);local rightMask=right:getMaskImage()
        for y=0,31 do for x=0,31 do
            eq(rightMask:sample(x,y),mask:sample(31-x,y))
            if mask:sample(31-x,y)==gfx.kColorWhite then eq(right:sample(x,y),image:sample(31-x,y)) end
        end end
    end)
    test("slice sprite install is idempotent rejects conflicts atomically and restores cleared keys",function() sprites(function()
        local first=SpriteFactory.npc.kantoClerk;local second=SpriteFactory.npc.kantoYoungster
        SliceSprites.install();eq(SpriteFactory.npc.kantoClerk,first)
        SpriteFactory.npc.kantoClerk=nil;SliceSprites.install();eq(SpriteFactory.npc.kantoClerk,first)
        SpriteFactory.npc.kantoClerk={};SpriteFactory.npc.kantoYoungster=nil
        rejects(function() SliceSprites.install() end);eq(SpriteFactory.npc.kantoYoungster,nil)
        SpriteFactory.npc.kantoClerk=first;SliceSprites.install();eq(SpriteFactory.npc.kantoYoungster,second)
    end) end)
    test("source binding IDs reject before registry allocation",function() sprites(function()
        local definitions={};for _,name in ipairs({"Route1","ViridianCity","ViridianMart","ViridianPokecenter"}) do definitions[name]=KantoSlice.padded(name) end
        local registry=TileRegistry();local opts=options(registry);opts.sliceBindings=KantoSlice.specs("Route1",definitions)
        opts.sliceBindings["invented:id"]={status="bound"}
        rejects(function() Zone.fromMapDefinition(definitions.Route1,registry,opts) end);eq(registry:maxID(),37)
        opts.sliceBindings["invented:id"]=nil;opts.sliceBindings["pokered:ROUTE_1:objects:1"]=nil
        rejects(function() Zone.fromMapDefinition(definitions.Route1,registry,opts) end);eq(registry:maxID(),37)
        opts.sliceBindings=KantoSlice.specs("Route1",definitions)
        definitions.Route1.events.objects[1].x=999
        rejects(function() Zone.fromMapDefinition(definitions.Route1,registry,opts) end);eq(registry:maxID(),37)
        definitions.Route1.events.objects[1].x=5
        opts.sliceBindings=KantoSlice.specs("Route1",definitions);opts.dispatch=function(id) return {id} end
        local plan=MapBindings.prepare(definitions.Route1,opts.sliceBindings,opts)
        opts.sliceBindings["pokered:ROUTE_1:objects:1"].status="blocked"
        eq(plan.npcs[1].dialog()[1],"pokered:ROUTE_1:objects:1")
    end) end)
    test("original NPC identities geometry and padded Mart warp arrivals bind",function() sprites(function()
        local zone=KantoSlice.create("ViridianMart",options());eq(zone.width,13);eq(zone.height,8);eq(zone.imported,true);eq(zone:isSliceReady(),true);eq(zone:isCampaignReady(),false)
        eq(#zone.npcDefs,3);eq(zone.npcDefs[1].gridX,2);eq(zone.npcDefs[1].gridY,5);eq(zone.npcDefs[1].sprite,"kantoClerk")
        eq(zone.npcDefs[1].source_event_id,"pokered:VIRIDIAN_MART:objects:1")
        eq(zone:getDoorAt(5,7),nil);local door=zone:getEdgeDoorAt(5,7,"down");eq(door.to,"kanto_viridian_city");eq(door.toX,29);eq(door.toY,20)
        eq(#zone:sourceEventsAt(2,5),1);zone:assertEnterable()
    end) end)
    test("Viridian unsupported source exits remain blocked and explicitly unfinished",function() sprites(function()
        local zone=KantoSlice.create("ViridianCity",options());eq(zone:isSliceReady(),true);eq(zone:isCampaignReady(),false)
        eq(zone.collision[16][22],1);eq(zone:bindingAt(21,15).id,"pokered:VIRIDIAN_CITY:warps:3")
        rejects(function() zone:getDoorAt(21,15) end)
        local northBlocked, westBlocked = false, false
        for _, issue in ipairs(zone:getBindingIssues()) do
            if issue.id == "north:ROUTE_2" then northBlocked = true end
            if issue.id == "west:ROUTE_22" then westBlocked = true end
        end
        eq(northBlocked, false)
        eq(westBlocked, true)
    end) end)
    test("conditional original NPC visibility owns occupancy without permanent collision",function() sprites(function()
        local gotDex=false;local opts=options();opts.questFlag=function() return gotDex end
        local zone=KantoSlice.create("ViridianCity",opts);local manager=NPCManager()
        local ok,problem=pcall(function()
            eq(zone.collision[10][19],0)
            zone:spawnNPCs(manager);assert(manager:getNPCAt(18,9));eq(manager:getNPCAt(17,5),nil)
            gotDex=true;zone:spawnNPCs(manager);eq(manager:getNPCAt(18,9),nil);assert(manager:getNPCAt(17,5))
            eq(zone.collision[10][19],0);eq(zone.collision[16][22],1)
        end)
        manager:clear();if not ok then error(problem,0) end
    end) end)
    test("generic location resolver stays strict and only explicitly named slice is allowed",function() sprites(function()
        local zone=KantoSlice.create("ViridianCity",options());local beforeRegistry,beforeList=zoneRegistry,zoneList
        local ok,problem=pcall(function()
            zoneRegistry,zoneList={city=zone},{"city"}
            local location={zone_id=zone.stableID,x=20,y=35,facing="up"};local world={schema=1,zone_count=0,zones={}}
            rejects(function() WorldDeltas.resolveLocation(location,world) end)
            local resolved=WorldDeltas.resolveLocation(location,world,{sliceZones={[zone.stableID]=true}});eq(resolved.zone_id,zone.stableID)
            rejects(function() WorldDeltas.resolveLocation(location,world,{sliceZones={other=true}}) end)
        end)
        zoneRegistry,zoneList=beforeRegistry,beforeList;if not ok then error(problem,0) end
    end) end)
    test("original ledge is a two cell one way rule with validated landing",function() sprites(function()
        local zone=KantoSlice.create("Route1",options());local rule=zone:movementRule(4,4,"down")
        eq(rule.kind,"ledge");eq(rule.cells,2);eq(rule.x,4);eq(rule.y,6)
        eq(zone:movementRule(4,6,"up").kind,"blocked")
        zone:setTile(4,6,"base:26");eq(zone:movementRule(4,4,"down").kind,"blocked")
    end) end)
    test("connection offsets round trip and original intro gates customized Pallet",function()
        for _,x in ipairs({9,10}) do
            local north=KantoSlice.connection("pallet_town",x,0,"up","done");eq(north.x,x+1)
            local south=KantoSlice.connection("Route1",north.x,north.y,"down","done");eq(south.x,x);eq(south.y,0)
        end
        for x=0,19 do
            local n=KantoSlice.connection("Route1",x,0,"up","done");local s=KantoSlice.connection("ViridianCity",n.x,n.y,"down","done");eq(s.x,x);eq(s.y,0)
        end
        rejects(function() KantoSlice.connection("pallet_town",9,0,"up","pre_oak") end)
        rejects(function() KantoSlice.connection("ViridianCity",0,0,"up","done") end)
    end)
    test("parcel reward plans are pure guarded retryable and ordered as actual Blue movement",function()
        local current=state();local plan=SliceEvents.plan("pokered:VIRIDIAN_MART:script:entry",current)
        eq(plan.steps[2].direction,"up");eq(plan.steps[2].count,2);eq(plan.steps[3].direction,"left")
        eq(plan.expected.flags.EVENT_GOT_OAKS_PARCEL,false);eq(plan.changes.items[1].id,"oaksParcel");eq(current.flags.EVENT_GOT_OAKS_PARCEL,nil)
        current.can_add.oaksParcel=false;plan=SliceEvents.plan("pokered:VIRIDIAN_MART:objects:1",current);eq(plan.status,"bag-full");eq(plan.changes,nil)
        local fullEntry=SliceEvents.plan("pokered:VIRIDIAN_MART:script:entry",current)
        eq(fullEntry.status,"bag-full");eq(fullEntry.steps[1].op,"dialog");eq(fullEntry.steps[2].direction,"up");eq(fullEntry.steps[2].count,2);eq(fullEntry.steps[3].direction,"left");eq(fullEntry.steps[4].op,"dialog");eq(fullEntry.changes,nil)
        current.can_add.oaksParcel=true;current.flags.EVENT_GOT_OAKS_PARCEL=true;current.items.oaksParcel=1
        plan=SliceEvents.plan("pokered:VIRIDIAN_MART:objects:1",current);eq(plan.changes,nil)
        current.intro="choose";rejects(function() SliceEvents.plan("pokered:VIRIDIAN_MART:objects:1",current) end)
    end)
    test("Oak handoff removes parcel only with Pokédex flags and repeats cannot duplicate",function()
        local current=state();local id="pokered:OAKS_LAB:script:parcel-handoff"
        eq(SliceEvents.plan(id,current).status,"no-item")
        current.flags.EVENT_GOT_OAKS_PARCEL=true;current.items.oaksParcel=1
        local plan=SliceEvents.plan(id,current);eq(plan.changes.items[1].op,"handoff");eq(plan.changes.flags.EVENT_GOT_POKEDEX,true);eq(plan.changes.flags.EVENT_OAK_GOT_PARCEL,true)
        current.flags.EVENT_GOT_POKEDEX=true;current.flags.EVENT_OAK_GOT_PARCEL=true;current.items.oaksParcel=0
        eq(SliceEvents.plan(id,current).changes,nil)
        local shop=SliceEvents.plan("pokered:VIRIDIAN_MART:objects:1",current);eq(shop.steps[1].op,"shop");eq(#shop.steps[1].stock,4)
    end)
    test("potion bag full leaves eligibility and healing requests real confirmation state",function()
        local current=state();current.can_add.potion=false
        local p=SliceEvents.plan("pokered:ROUTE_1:objects:1",current);eq(p.status,"bag-full");eq(p.changes,nil);eq(current.flags.EVENT_GOT_POTION_SAMPLE,nil)
        current.can_add.potion=true;p=SliceEvents.plan("pokered:ROUTE_1:objects:1",current);eq(p.changes.flags.EVENT_GOT_POTION_SAMPLE,true)
        local heal=SliceEvents.plan("pokered:VIRIDIAN_POKECENTER:objects:1",current);eq(heal.steps[1].op,"heal");eq(heal.changes,nil)
    end)
    test("simple city signs and source dialogue bind without enabling missing mechanics",function()
        local current=state();local p=SliceEvents.plan("pokered:VIRIDIAN_CITY:background_events:4",current);eq(p.steps[1].labels[1],"_MartSignText")
        p=SliceEvents.plan("pokered:VIRIDIAN_CITY:objects:4",current);eq(p.steps[1].labels[1],"_ViridianCityGirlHasntHadHisCoffeeYetText")
        current.flags.EVENT_GOT_POKEDEX=true;p=SliceEvents.plan("pokered:VIRIDIAN_CITY:objects:4",current);eq(p.steps[1].labels[1],"_ViridianCityGirlWhenIGoShopText")
        eq(SliceEvents.has("pokered:VIRIDIAN_CITY:objects:6"),false);eq(SliceEvents.has("pokered:VIRIDIAN_CITY:objects:7"),false)
    end)
    if HarnessBuild and HarnessBuild.enabled then
        test("all staged map and original NPC candidates export through actual SDK",function() sprites(function()
            local catalog=SliceCatalog.write(HarnessBuild.output_dir);eq(#catalog.images,100)
        end) end)
    end
    return report
end
