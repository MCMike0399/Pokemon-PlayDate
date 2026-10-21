EventContracts={}
local gfx <const> = playdate.graphics
local function eq(a,b) assert(a==b,"expected "..tostring(b)..", got "..tostring(a)) end
local games={}
-- Independent host flood-fill mask oracle from the checksum-verified source grids.
local expectedMasks={
    blue_down={0,960,32752,32760,16380,16380,32766,32766,32766,32764,32764,16380,4088,4088,4016,1792},
    blue_up={0,960,4094,8190,16380,16380,32766,32766,32766,32764,32764,16382,8190,4092,4032,1792},
    blue_left={0,960,32752,32760,16380,16380,8188,8184,8184,8176,4088,2040,8184,16380,8188,3608},
    pokedex={0,0,0,15934,32767,32767,32767,32767,32767,32767,32767,32767,32767,32767,0,0},
    monitor={0,0,32256,32256,32256,0,0,0,0,0,0,0,0,0,0,0},
    ball={0,0,3072,7680,16128,16128,7680,3072,0,0,0,0,0,0,0,0},
}
local function fingerprint(game)
    local bag=game.session:inventory();local out={tostring(bag:money())}
    for _,slot in ipairs(bag:slots()) do out[#out+1]=slot.id..":"..slot.quantity end
    local flags=game.session:flags().quest;local names={};for key in pairs(flags) do names[#names+1]=key end;table.sort(names)
    for _,key in ipairs(names) do out[#out+1]=key..":"..tostring(flags[key]) end
    local rng=RulesRNG.toData();out[#out+1]=rng.state;out[#out+1]=rng.rolls
    return table.concat(out,"|")
end
local function setup(name,x,y)
    SliceSprites.install() -- real, idempotent production installation before map binding
    local policy={sliceZones={}}
    for _,n in ipairs({"ViridianMart","ViridianCity","ViridianPokecenter"}) do
        local zone=KantoSlice.create(n,{registry=TileRegistry(),dispatch=function() error("unexpected source dispatch") end,questFlag=function() return false end})
        for key,existing in pairs(zoneRegistry) do if existing.stableID==zone.stableID then zoneRegistry[key]=nil end end
        zoneRegistry["contract_"..n]=zone;policy.sliceZones[zone.stableID]=true
    end
    local zone=zoneRegistry[name] or zoneRegistry["contract_"..name]
    local game=GameContext({sessionLocationPolicy=policy});games[#games+1]=game
    game.session=GameSession.newSession(game:getSessionDependencies(),{seed=42,location={zone_id=zone.stableID,x=x,y=y,facing="up"}})
    assert(game:recruit(Pokemon("squirtle",5)));assert(game.session:setIntro({stage="done",starter="squirtle",rivalStarter="bulbasaur"}))
    currentZone=zone;game.player=Player(x,y,zone.collision,game.npcManager);game.player.facing="up";game.player:setUpdatesEnabled(false)
    game.machine:register("overworld",{});game.machine:register("dialog",DialogState(game))
    game.machine:register("event",EventState(game));game.machine:register("shop",ShopState(game));game.machine:change("overworld")
    return game,game.machine:get("event")
end
local function completeDialog(game)
    eq(game.machine:getCurrent(),"dialog")
    local state=game.machine:get("dialog")
    -- Actual Dialog completion event/controller lifecycle, no SDK replacement.
    state.dialog.onComplete();state:handleInput()
end
local function drain(game,limit)
    for _=1,limit or 200 do
        local root=game.machine:getCurrent()
        if root=="overworld" then return end
        if root=="dialog" then completeDialog(game)
        elseif root=="event" then game.machine:get("event"):update()
        else error("unexpected event overlay: "..tostring(root)) end
    end
    error("bounded event did not settle")
end
local function fillBag(game,excluded)
    local ids={};for id in pairs(ItemData.definitions) do if id~=excluded then ids[#ids+1]=id end end;table.sort(ids)
    for _,id in ipairs(ids) do if game.session:inventory():count()>=20 then return end;assert(game.session:inventory():add(id,1)) end
end
-- Compare real working framebuffer pixels, not just model coordinates.
local function renderedAfterManualStep(sprite,step,draw,clock,offsetY)
    local states={};local ox,oy=gfx.getDrawOffset()
    for _,item in ipairs(gfx.sprite.getAllSprites()) do
        states[#states+1]={sprite=item,visible=item:isVisible(),enabled=item:updatesEnabled()}
        item:setVisible(false);item:setUpdatesEnabled(false)
    end
    local paper=gfx.image.new(400,240,gfx.kColorWhite);local background=gfx.sprite.new(paper)
    background:setCenter(0,0);background:setIgnoresDrawOffset(true);background:setZIndex(-32768);background:moveTo(0,0);background:add()
    local calls=0;local sentinel=gfx.sprite.new();sentinel:setSize(1,1);sentinel:setVisible(false)
    sentinel.update=function() calls=calls+1 end;sentinel:add()
    local ok,problem=pcall(function()
        sprite:setVisible(true);gfx.setDrawOffset(0,offsetY);gfx.sprite.addDirtyRect(0,0,400,240)
        gfx.sprite.update() -- normal lower-world update/draw happens FIRST
        eq(calls,1);local before=gfx.getWorkingImage():copy()
        step();local tick=clock();gfx.setDrawOffset(0,offsetY)
        local expected=gfx.image.new(400,240,gfx.kColorWhite)
        gfx.pushContext(expected);gfx.setDrawOffset(0,0);gfx.setImageDrawMode(gfx.kDrawModeCopy)
        sprite:getImage():draw(sprite.x,sprite.y+offsetY);gfx.popContext()
        draw();eq(clock(),tick);eq(calls,1);eq(sentinel:updatesEnabled(),true)
        local actual=gfx.getWorkingImage();local changed=0
        for y=0,239 do for x=0,399 do
            eq(actual:sample(x,y),expected:sample(x,y))
            if actual:sample(x,y)~=before:sample(x,y) then changed=changed+1 end
        end end
        assert(changed>0,"framebuffer must change at the current manual position")
    end)
    sentinel:remove();background:remove()
    for _,state in ipairs(states) do state.sprite:setVisible(state.visible);state.sprite:setUpdatesEnabled(state.enabled) end
    gfx.setDrawOffset(ox,oy);gfx.sprite.addDirtyRect(0,0,400,240);EventState.redrawSprites()
    assert(ok,problem)
end
function EventContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)
        local registry,zone=zoneRegistry,currentZone;local ox,oy=gfx.getDrawOffset();local old={};for _,s in ipairs(gfx.sprite.getAllSprites()) do old[s]=true end
        local spriteSets={};for key,value in pairs(SpriteFactory.npc) do spriteSets[key]=value end
        local isolated={};for k,v in pairs(registry) do isolated[k]=v end;zoneRegistry=isolated;games={}
        local ok,problem=pcall(fn)
        for _,game in ipairs(games) do pcall(game.machine.change,game.machine,"overworld") end
        for _,s in ipairs(playdate.graphics.sprite.getAllSprites()) do if not old[s] then s:remove() end end
        for key in pairs(SpriteFactory.npc) do if not spriteSets[key] then SpriteFactory.npc[key]=nil end end
        for key,value in pairs(spriteSets) do SpriteFactory.npc[key]=value end
        zoneRegistry,currentZone=registry,zone;gfx.setDrawOffset(ox,oy)
        gfx.sprite.addDirtyRect(0,0,400,240);EventState.redrawSprites()
        report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(problem) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("Source paragraphs expand only declared names/items and identify gated receipts",function()
        local pages=EventText.pages({"_Route1Youngster1GotPotionText"});eq(#pages,1)
        eq(pages[1].text,"RED got POTION!");eq(pages[1].receipt,true)
        local delivered=EventText.pages({"_OaksLabOak1DeliverParcelText"});eq(delivered[#delivered].receipt,true)
        assert(delivered[#delivered].text:find("RED delivered OAK's PARCEL",1,true))
        eq(pcall(EventText.pages,{"_UnknownMadeUpText"}),false)
    end)
    test("Pinned BLUE stride keeps protected standing hair phase and restores graphics offset",function()
        local source=assert(json.decodeFile("data/event-art.json"));local images=SpriteFactory.npc.rival
        local ox,oy=gfx.getDrawOffset();gfx.setDrawOffset(17,-13);local walking=EventArt.walking()
        local x,y=gfx.getDrawOffset();gfx.setDrawOffset(ox,oy);eq(x,17);eq(y,-13)
        for _,dir in ipairs({"down","up","left"}) do
            local grid,standing=source.blue_walk[dir].grid,SpriteFactory.grids.rival[dir];local shared=0
            for py=0,31 do for px=0,31 do
                if grid[py//2+1]:sub(px//2+1,px//2+1)=="2" and standing[py//2+1]:sub(px//2+1,px//2+1)=="2" then
                    shared=shared+1;eq(walking[dir]:sample(px,py),images[dir]:sample(px,py))
                end
            end end
            assert(shared>0,"shared protected BLUE hair samples required")
            eq(SpriteFactory.npc.rival[dir],images[dir])
        end
    end)
    test("New event masks match the independent pinned-source opacity oracle at every pixel",function()
        local walking=EventArt.walking();local monitor,ball=EventArt.healing()
        local images={blue_down=walking.down,blue_up=walking.up,blue_left=walking.left,pokedex=EventArt.pokedex(),monitor=monitor,ball=ball}
        for name,image in pairs(images) do
            local mask=assert(image:getMaskImage(),"source mask required: "..name);local width,height=image:getSize()
            for y=0,height-1 do for x=0,width-1 do
                local opaque=((expectedMasks[name][y//2+1]>>(15-x//2))&1)==1
                eq(mask:sample(x,y),opaque and gfx.kColorWhite or gfx.kColorBlack)
            end end
        end
        local left,right=walking.left:getMaskImage(),walking.right:getMaskImage()
        for y=0,31 do for x=0,31 do eq(right:sample(x,y),left:sample(31-x,y)) end end
    end)
    test("Read-only event observation preflights detached Inventory and actual quest flags",function()
        local game=setup("ViridianMart",5,7);fillBag(game,"oaksParcel")
        assert(game.session:setQuestFlag("EVENT_TEST",true));local before=fingerprint(game)
        local observation=EventState.observe(game);eq(observation.flags.EVENT_TEST,true);eq(observation.can_add.oaksParcel,false)
        observation.flags.EVENT_TEST=false;eq(game.session:questFlag("EVENT_TEST"),true);eq(fingerprint(game),before)
    end)
    test("Event draw renders current manual Player pixels without a second actor/update tick",function()
        local game,event=setup("ViridianMart",5,7)
        game.machine:push("event","pokered:VIRIDIAN_MART:script:entry");completeDialog(game);eq(event.phase,"move")
        renderedAfterManualStep(game.player,function() event:update() end,function() event:draw() end,
            function() return game.player.moveFrames end,0)
        eq(game.player.moveFrames,1)
    end)
    test("Event draw renders current manual BLUE pixels without advancing any enabled callback",function()
        local game,event=setup("oaks_lab",5,4)
        local oak=NPC(5,3,"OAK",{},nil,"oak","down");oak.def={source_event_id="contract:oak"};game.npcManager:addNPC(oak)
        assert(game.session:inventory():add("oaksParcel",1));assert(game.session:setQuestFlag("EVENT_GOT_OAKS_PARCEL",true))
        game.machine:push("event","pokered:OAKS_LAB:script:parcel-handoff")
        for _=1,10 do if event.phase=="oak-arrival" then break end;completeDialog(game) end
        eq(event.phase,"oak-arrival")
        renderedAfterManualStep(event.rival,function() event:updateRival() end,function() event:draw() end,
            function() return event.rivalFrame end,-120)
        eq(event.rivalFrame,1)
    end)
    test("Partial move abort restores original facing/standing image and clears traversal queues",function()
        local game,event=setup("ViridianMart",5,7);local player=game.player
        player.facing="right";player:updateSprite();player.walkToggle=false;player.rustleFrames=7
        local image=player:getImage()
        game.machine:push("event","pokered:VIRIDIAN_MART:script:entry");completeDialog(game);event:update()
        player.pendingEdgeDoor={to="stale"};player.pendingConnection={to="stale"}
        game.machine:change("overworld")
        eq(player.facing,"right");eq(player:getImage(),image);eq(player.walkToggle,false);eq(player.rustleFrames,7)
        eq(player.gridX,5);eq(player.gridY,7);eq(player.x,160);eq(player.y,216)
        eq(player.isMoving,false);eq(player.isJumping,false);eq(player.jumpOffset,0)
        eq(player.pendingEdgeDoor,nil);eq(player.pendingConnection,nil);eq(player.stepJustFinished,false)
    end)
    test("Adapted BLUE speech faces actual RED from every Oak interaction side",function()
        for _,position in ipairs({{5,4},{4,3},{6,3},{5,2}}) do
            local game,event=setup("oaks_lab",position[1],position[2])
            local oak=NPC(5,3,"OAK",{},nil,"oak","down");oak.def={source_event_id="contract:oak"};game.npcManager:addNPC(oak)
            assert(game.session:inventory():add("oaksParcel",1));assert(game.session:setQuestFlag("EVENT_GOT_OAKS_PARCEL",true))
            game.machine:push("event","pokered:OAKS_LAB:script:parcel-handoff")
            for _=1,180 do
                if game.machine:getCurrent()=="dialog" and event.waiting=="_OaksLabRivalLeaveItAllToMeText" then break end
                if game.machine:getCurrent()=="dialog" then completeDialog(game) else event:update() end
            end
            eq(event.waiting,"_OaksLabRivalLeaveItAllToMeText");eq(game.machine:getCurrent(),"dialog")
            local expected=(position[1]==6 or position[2]==2) and "up" or "left"
            eq(event.rival.facing,expected);eq(game.session:questFlag("EVENT_GOT_POKEDEX"),false)
            game.machine:change("overworld")
        end
    end)
    test("Real Player scripted Mart UP2 LEFT1 uses eight updates per cell without trigger residue",function()
        local game,event=setup("ViridianMart",5,7)
        game.machine:push("event","pokered:VIRIDIAN_MART:script:entry");completeDialog(game)
        eq(event.phase,"move");eq(game.player.gridY,6);eq(game.player.moveFrames,0)
        for frame=1,7 do event:update();eq(game.player.moveFrames,frame);eq(game.player.isMoving,true) end
        event:update();eq(game.player.gridY,5);eq(game.player.isMoving,true);eq(game.player.moveFrames,0)
        for _=1,8 do event:update() end;eq(game.player.gridX,4)
        for _=1,8 do event:update() end
        eq(game.player.gridX,4);eq(game.player.gridY,5);eq(game.player.isMoving,false)
        eq(game.player.stepJustFinished,false);eq(game.player.pendingEdgeDoor,nil)
        drain(game);eq(game.session:inventory():quantity("oaksParcel"),1)
    end)
    test("Aborting real movement restores its previous cell and stale dialogue callback cannot reward",function()
        local game,event=setup("ViridianMart",5,7);game.machine:push("event","pokered:VIRIDIAN_MART:script:entry")
        local stale=game.machine:get("dialog").onComplete;completeDialog(game);event:update();event:update()
        game.machine:change("overworld");eq(game.player.gridX,5);eq(game.player.gridY,7);eq(game.player.isMoving,false)
        stale();eq(game.session:inventory():quantity("oaksParcel"),0);eq(game.session:questFlag("EVENT_GOT_OAKS_PARCEL"),false)
    end)
    test("Reward commits once before receipt; repeat and stale completion cannot duplicate",function()
        local game,event=setup("reds_house_2f",5,3)
        game.machine:push("event","pokered:ROUTE_1:objects:1")
        local stale=game.machine:get("dialog").onComplete
        eq(game.session:inventory():quantity("potion"),0);completeDialog(game)
        eq(event.phase,"receipt");eq(game.session:inventory():quantity("potion"),1)
        local before=fingerprint(game);stale();eq(fingerprint(game),before)
        completeDialog(game);eq(game.machine:getCurrent(),"overworld")
        game.machine:push("event","pokered:ROUTE_1:objects:1");drain(game)
        eq(game.session:inventory():quantity("potion"),1);eq(game.session:questFlag("EVENT_GOT_POTION_SAMPLE"),true)
    end)
    test("Stale capacity failure displays no receipt and preserves full bag/eligibility",function()
        local game,event=setup("reds_house_2f",5,3)
        game.machine:push("event","pokered:ROUTE_1:objects:1");fillBag(game,"potion");local before=fingerprint(game)
        completeDialog(game);eq(event.phase,"dialog");eq(game.session:inventory():quantity("potion"),0)
        eq(game.session:questFlag("EVENT_GOT_POTION_SAMPLE"),false);eq(fingerprint(game),before)
        for _,line in ipairs(game.machine:get("dialog").dialog.lines) do assert(not line:find("RED got",1,true)) end
        drain(game);eq(fingerprint(game),before)
    end)
    test("Full-bag Mart entry preserves greeting/walk and never displays successful parcel receipt",function()
        local game,event=setup("ViridianMart",5,7);fillBag(game,"oaksParcel");local before=fingerprint(game)
        game.machine:push("event","pokered:VIRIDIAN_MART:script:entry")
        for _=1,100 do
            if game.machine:getCurrent()=="overworld" then break end
            if game.machine:getCurrent()=="dialog" then
                for _,line in ipairs(game.machine:get("dialog").dialog.lines) do assert(not line:find("RED got",1,true)) end
                completeDialog(game)
            else event:update() end
        end
        eq(game.machine:getCurrent(),"overworld");eq(game.player.gridX,4);eq(game.player.gridY,5)
        eq(game.session:inventory():quantity("oaksParcel"),0);eq(game.session:questFlag("EVENT_GOT_OAKS_PARCEL"),false);eq(fingerprint(game),before)
    end)
    test("Shop callback pops first, resumes event exactly once and stale callback cannot reenter",function()
        local game,event=setup("ViridianMart",4,5);assert(game.session:setQuestFlag("EVENT_OAK_GOT_PARCEL",true))
        game.machine:push("event","pokered:VIRIDIAN_MART:objects:1");eq(game.machine:getCurrent(),"shop")
        local shop=game.machine:get("shop");local stale=shop.onComplete
        shop:handleButton("b");eq(game.machine:getCurrent(),"overworld");stale();eq(game.machine:getCurrent(),"overworld")
    end)
    test("Heal decline leaves all Pokemon and checkpoint unchanged",function()
        local game,event=setup("ViridianPokecenter",3,3);local mon=game:getPlayerPokemon();mon.hp=1;mon.pp.tackle=0;mon.status,mon.statusTurns="poison",0
        local old=game.session:checkpoint();game.machine:push("event","pokered:VIRIDIAN_POKECENTER:objects:1");completeDialog(game)
        eq(event.phase,"heal-confirm");event:handleButton("b");drain(game)
        eq(mon.hp,1);eq(mon.pp.tackle,0);eq(mon.status,"poison");eq(game.session:checkpoint().zone_id,old.zone_id)
    end)
    test("Heal animation commits full-party restoration and outdoor checkpoint only when complete",function()
        local game,event=setup("ViridianPokecenter",3,3);local a=game:getPlayerPokemon();local b=Pokemon("charmander",5);assert(game:recruit(b))
        a.hp,b.hp=1,0;a.pp.tackle=0;b.pp.scratch=0;a.status,a.statusTurns="poison",0
        game.machine:push("event","pokered:VIRIDIAN_POKECENTER:objects:1");completeDialog(game);event:handleButton("a");completeDialog(game)
        eq(event.phase,"heal-animation");for _=1,85 do event:update() end
        eq(a.hp,1);eq(b.hp,0);event:update();eq(a.hp,a.maxHP);eq(b.hp,b.maxHP);eq(a.status,nil)
        eq(a.pp.tackle,moveData.tackle.maxPP);eq(b.pp.scratch,moveData.scratch.maxPP)
        local checkpoint=game.session:checkpoint();eq(checkpoint.zone_id,"pokered:VIRIDIAN_CITY");eq(checkpoint.x,23);eq(checkpoint.y,26);eq(checkpoint.facing,"down")
        drain(game)
    end)
    test("Healing abort and stale YES callback cannot restore party or change checkpoint",function()
        local game,event=setup("ViridianPokecenter",3,3);local mon=game:getPlayerPokemon();mon.hp=1;local old=game.session:checkpoint()
        game.machine:push("event","pokered:VIRIDIAN_POKECENTER:objects:1");completeDialog(game);local stale=event.menu.onSelect
        event:handleButton("a");completeDialog(game);event:update();game.machine:change("overworld");stale(1)
        eq(mon.hp,1);eq(game.session:checkpoint().zone_id,old.zone_id)
    end)
    test("Oak scene uses bounded occupied-cell routes, deferred ownership and unchanged permanent tiles",function()
        local game,event=setup("oaks_lab",5,4)
        local oak=NPC(5,3,"OAK",{},nil,"oak","down");oak.def={source_event_id="contract:oak"};game.npcManager:addNPC(oak)
        assert(game.session:inventory():add("oaksParcel",1));assert(game.session:setQuestFlag("EVENT_GOT_OAKS_PARCEL",true))
        local before={};for y,row in ipairs(currentZone.tiles) do before[y]=table.concat(row,",") end
        game.machine:push("event","pokered:OAKS_LAB:script:parcel-handoff")
        eq(event.aisle,6);eq(#event.books,2)
        for _=1,200 do
            if event.phase=="receipt" then break end
            if game.machine:getCurrent()=="dialog" then
                for _,line in ipairs(game.machine:get("dialog").dialog.lines) do assert(not line:find("RED got",1,true) and not line:find("RED delivered",1,true)) end
                completeDialog(game)
            else event:update() end
        end
        eq(event.phase,"receipt");eq(game.session:inventory():quantity("oaksParcel"),0);eq(game.session:questFlag("EVENT_GOT_POKEDEX"),true)
        eq(game.npcManager:findByName("BLUE"),nil);eq(#event.books,0)
        for y,row in ipairs(currentZone.tiles) do eq(table.concat(row,","),before[y]) end
        completeDialog(game)
    end)
    test("Occupied Oak aisles fail boundedly without overlapping actors or granting flags",function()
        local game,event=setup("oaks_lab",5,4)
        for _,row in ipairs({{5,3,"OAK","oak"},{6,6,"BLOCKER","rival"}}) do
            local npc=NPC(row[1],row[2],row[3],{},nil,row[4],"down")
            npc.def={source_event_id="contract:"..row[3]};game.npcManager:addNPC(npc)
        end
        assert(game.session:inventory():add("oaksParcel",1));assert(game.session:setQuestFlag("EVENT_GOT_OAKS_PARCEL",true))
        local before=fingerprint(game);game.machine:push("event","pokered:OAKS_LAB:script:parcel-handoff")
        eq(event.phase,"failed");eq(event.waiting,"blocked-rival-route");eq(#event.books,0)
        eq(game.npcManager:findByName("BLUE"),nil);eq(fingerprint(game),before)
        event:handleButton("a");eq(game.machine:getCurrent(),"overworld")
    end)
    test("Oak precommit abort removes temporary actors/books and leaves parcel/flags unchanged",function()
        local game,event=setup("oaks_lab",6,4)
        local oak=NPC(5,3,"OAK",{},nil,"oak","down");oak.def={source_event_id="contract:oak"};game.npcManager:addNPC(oak)
        assert(game.session:inventory():add("oaksParcel",1));assert(game.session:setQuestFlag("EVENT_GOT_OAKS_PARCEL",true))
        game.machine:push("event","pokered:OAKS_LAB:script:parcel-handoff");eq(event.aisle,5)
        local stale=game.machine:get("dialog").onComplete;game.machine:change("overworld");stale()
        eq(#event.books,0);eq(game.npcManager:findByName("BLUE"),nil);eq(game.session:inventory():quantity("oaksParcel"),1)
        eq(game.session:questFlag("EVENT_GOT_POKEDEX"),false)
    end)
    return report
end
