HealingCompositionContracts={}
local gfx <const> = playdate.graphics
local function eq(a,b) assert(a==b,"expected "..tostring(b)..", got "..tostring(a)) end
local function same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end;return true
end
local games,views={},{}
local function setup(count,name)
    name=name or "ViridianPokecenter"
    SliceSprites.install()
    local zone
    if name=="PewterPokecenter" then
        PewterSprites.installFor(PewterSlice.padded(name));zone=PewterWorld.isolated(name)
    else zone=KantoSlice.create(name,{registry=TileRegistry(),dispatch=function() error("unexpected source dispatch") end,questFlag=function() return false end}) end
    for key,existing in pairs(zoneRegistry) do if existing.stableID==zone.stableID then zoneRegistry[key]=nil end end
    zoneRegistry.healing_contract_center=zone
    local game=GameContext({sessionLocationPolicy=name=="PewterPokecenter" and PewterWorld.locationPolicy() or KantoWorld.locationPolicy()});games[#games+1]=game
    game.session=GameSession.newSession(game:getSessionDependencies(),{seed=42,location={zone_id=zone.stableID,x=3,y=3,facing="up"}})
    for i=1,count do assert(game:recruit(Pokemon(i==1 and "squirtle" or "charmander",5))) end
    assert(game.session:setIntro({stage="done",starter="squirtle",rivalStarter="bulbasaur"}))
    currentZone=zone
    game.player=Player(3,3,zone.collision,game.npcManager);game.player.facing="up";game.player:updateSprite();game.player:setUpdatesEnabled(false)
    zone:spawnNPCs(game.npcManager)
    for _,npc in ipairs(game.npcManager.npcs) do npc:setUpdatesEnabled(false) end
    local view=WorldView(zone);views[#views+1]=view
    game.machine:register("overworld",{});game.machine:register("event",EventState(game));game.machine:register("dialog",DialogState(game));game.machine:change("overworld")
    return game,game.machine:get("event"),view
end
local function completeDialog(game)
    eq(game.machine:getCurrent(),"dialog")
    local dialog=game.machine:get("dialog");dialog.dialog.onComplete();dialog:handleInput()
end
local function begin(game,event)
    game.machine:push("event",currentZone.stableID..":objects:1")
    completeDialog(game);eq(event.phase,"heal-confirm");event:handleButton("a");completeDialog(game);eq(event.phase,"heal-animation")
end
-- Independent source OAM constants. Do not call production layout/draw here.
local function expected(game,view,count,balls,animation)
    local image=gfx.image.new(400,240,gfx.kColorWhite)
    local map=view:render()
    gfx.pushContext(image);game.camera:apply();gfx.clearClipRect();gfx.clearStencil();gfx.setImageDrawMode(gfx.kDrawModeCopy)
    map:draw(0,0)
    for _,npc in ipairs(game.npcManager.npcs) do npc:getImage():draw(npc.x,npc.y) end
    game.player:getImage():draw(game.player.x,game.player.y)
    if animation then
        local monitor,ball=EventArt.healing();monitor:draw(56,8)
        if balls then
            local positions={{48,22},{64,22},{48,32},{64,32},{48,42},{64,42}}
            for i=1,count do local p=positions[i];ball:draw(p[1],p[2],i%2==0 and gfx.kImageFlippedX or gfx.kImageUnflipped) end
        end
    end
    gfx.popContext();return image
end
local function pixels(actual,oracle)
    for y=0,239 do for x=0,399 do
        assert(actual:sample(x,y)==oracle:sample(x,y),"native composition differs at "..x..","..y)
    end end
end
local function write(image,name)
    if HarnessBuild and HarnessBuild.enabled and playdate.simulator then
        playdate.simulator.writeToFile(image,HarnessBuild.output_dir..name..".png")
    end
end
function HealingCompositionContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)
        local oldZone,oldRegistry,oldRNG=currentZone,zoneRegistry,RulesRNG.toData()
        local ox,oy=gfx.getDrawOffset();local oldSprites,sets={},{}
        for _,sprite in ipairs(gfx.sprite.getAllSprites()) do oldSprites[sprite]={visible=sprite:isVisible(),enabled=sprite:updatesEnabled()};sprite:setVisible(false);sprite:setUpdatesEnabled(false) end
        for key,value in pairs(SpriteFactory.npc) do sets[key]=value end
        local isolated={};for key,value in pairs(zoneRegistry) do isolated[key]=value end;zoneRegistry=isolated;games,views={},{}
        local ok,problem=pcall(fn)
        for _,game in ipairs(games) do pcall(game.machine.change,game.machine,"overworld") end
        for _,view in ipairs(views) do pcall(view.dispose,view) end
        for _,sprite in ipairs(gfx.sprite.getAllSprites()) do if not oldSprites[sprite] then sprite:remove() end end
        for sprite,state in pairs(oldSprites) do sprite:setVisible(state.visible);sprite:setUpdatesEnabled(state.enabled) end
        for key in pairs(SpriteFactory.npc) do if not sets[key] then SpriteFactory.npc[key]=nil end end
        for key,value in pairs(sets) do SpriteFactory.npc[key]=value end
        if not same(oldRNG,RulesRNG.toData()) then ok=false;problem="healing composition changed rules RNG";RulesRNG.restoreData(oldRNG) end
        zoneRegistry,currentZone=oldRegistry,oldZone;gfx.setDrawOffset(ox,oy);gfx.sprite.addDirtyRect(0,0,400,240);EventState.redrawSprites()
        report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(problem) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("Healing layout uses pinned OAM offsets/flips and unchanged source masks",function()
        local game=setup(1);local layout=HealingComposition.layout(currentZone)
        eq(layout.monitor.x,56);eq(layout.monitor.y,8)
        local positions={{48,22},{64,22},{48,32},{64,32},{48,42},{64,42}}
        for i,p in ipairs(positions) do eq(layout.balls[i].x,p[1]);eq(layout.balls[i].y,p[2]);eq(layout.balls[i].flip_x,i%2==0) end
        layout.monitor.x=999;eq(HealingComposition.layout(currentZone).monitor.x,56)
        local monitor,ball=EventArt.healing()
        local masks={{image=monitor,rows={0,0,126,126,126,0,0,0}},{image=ball,rows={0,0,12,30,63,63,30,12}}}
        for _,entry in ipairs(masks) do
            local mask=assert(entry.image:getMaskImage())
            for y=0,15 do for x=0,15 do
                local opaque=(entry.rows[y//2+1]&(1<<(7-x//2)))~=0
                eq(mask:sample(x,y),opaque and gfx.kColorWhite or gfx.kColorBlack)
            end end
        end
        local original=assert(json.decodeFile("data/event-art.json"));eq(original.source_revision,"af519899719f0754965776faac0e836a3b906e6d")
    end)
    test("Native1/2/6-party compositions match source OAM over actual map and translated camera",function()
        for _,count in ipairs({1,2,6}) do
            local game,event,view=setup(count);begin(game,event)
            event.healClock=15*(count-1)
            for _,offset in ipairs({{0,0},{32,16}}) do
                game.camera.x,game.camera.y=offset[1],offset[2];game.camera:apply()
                local beforeClock=event.healClock;event:draw();eq(event.healClock,beforeClock)
                pixels(gfx.getWorkingImage(),expected(game,view,count,true,true))
                local actual=gfx.getWorkingImage():copy()
                local label="healing-party-"..count.."-camera-"..offset[1].."-"..offset[2]
                write(actual,label)
                local annotated=actual:copy();gfx.pushContext(annotated);gfx.setDrawOffset(0,0);gfx.setFont(gfx.getSystemFont())
                gfx.setColor(gfx.kColorWhite);gfx.fillRect(8,204,384,30);gfx.setColor(gfx.kColorBlack)
                gfx.drawText("PARTY "..count.." / source OAM / camera "..offset[1]..","..offset[2],14,210)
                gfx.drawRect(48-offset[1],8-offset[2],32,50);gfx.popContext();write(annotated,label.."-labeled")
            end
            game.machine:change("overworld");view:dispose()
            game.player:remove();game.npcManager:clear()
        end
    end)
    test("Flash-off redraw restores actual machine pixels without moving actors or consuming RNG",function()
        local game,event,view=setup(6);begin(game,event);game.camera.x,game.camera.y=0,0;game.camera:apply()
        event.healClock=75;event:draw();local on=gfx.getWorkingImage():copy()
        event.healClock=95;event:draw();pixels(gfx.getWorkingImage(),expected(game,view,6,false,true))
        local changed=0;for y=0,80 do for x=0,100 do if on:sample(x,y)~=gfx.getWorkingImage():sample(x,y) then changed=changed+1 end end end
        assert(changed>0,"flash-off must erase previously drawn balls through map redraw")
        eq(game.player.gridX,3);eq(game.player.gridY,3);write(gfx.getWorkingImage():copy(),"healing-six-flash-off")
    end)
    test("Cancel restores nurse/map and preserves party/checkpoint; guarded completion remains atomic",function()
        local game,event,view=setup(2);local a,b=game.session:party():get(1),game.session:party():get(2)
        a.hp,b.hp=1,0;a.pp[a.moves[1]]=0;a.status="poison"
        local nurse=game.npcManager:findByName("TEXT_VIRIDIANPOKECENTER_NURSE");assert(nurse)
        local oldFacing=nurse.facing;local before=assert(SessionCodec.encode(game.session,{root="overworld",overworld="explore",settled=true}))
        begin(game,event);eq(nurse.facing,"left");event.healClock=20;event:draw()
        game.machine:change("overworld");eq(nurse.facing,oldFacing)
        assert(same(before,assert(SessionCodec.encode(game.session,{root="overworld",overworld="explore",settled=true}))))
        gfx.sprite.addDirtyRect(0,0,400,240);game.camera:apply();EventState.redrawSprites();pixels(gfx.getWorkingImage(),expected(game,view,2,false,false))
        write(gfx.getWorkingImage():copy(),"healing-cancel-restored")
        begin(game,event);event.healClock=84;event:update();eq(a.hp,1);eq(b.hp,0);event:update()
        eq(a.hp,a.maxHP);eq(b.hp,b.maxHP);eq(a.status,nil);eq(a.pp[a.moves[1]],moveData[a.moves[1]].maxPP)
        eq(nurse.facing,oldFacing);eq(game.session:checkpoint().zone_id,"pokered:VIRIDIAN_CITY")
    end)
    test("Pewter Center uses its pinned matching machine and outdoor checkpoint",function()
        local game,event,view=setup(2,"PewterPokecenter")
        begin(game,event);game.camera.x,game.camera.y=0,0;event.healClock=15;event:draw()
        pixels(gfx.getWorkingImage(),expected(game,view,2,true,true))
        write(gfx.getWorkingImage():copy(),"healing-pewter-party-2")
        event.healClock=84;event:update();event:update()
        local checkpoint=game.session:checkpoint()
        eq(checkpoint.zone_id,"pokered:PEWTER_CITY");eq(checkpoint.x,13);eq(checkpoint.y,26);eq(checkpoint.facing,"down")
    end)
    test("installed standard source Centers share the pinned machine layout", function()
        for _, name in ipairs({"ViridianPokecenter", "PewterPokecenter", "CeruleanPokecenter", "MtMoonPokecenter"}) do
            local zone = SourceMaps.isolated(name)
            local layout = HealingComposition.layout(zone)
            eq(layout.monitor.x,56); eq(layout.monitor.y,8)
            eq(#layout.balls,6)
        end
        local ok = pcall(HealingComposition.layout, SourceMaps.isolated("BillsHouse"))
        eq(ok,false)
    end)
    return report
end
