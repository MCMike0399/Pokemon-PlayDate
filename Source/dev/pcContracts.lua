-- Production StateMachine, Player, domain codecs and isolated SDK file storage.
PCContracts={}
local invocation=0
local created={}
local gate={root="overworld",overworld="explore",settled=true}
local function eq(a,b) assert(a==b,"expected "..tostring(b)..", got "..tostring(a)) end
local function same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for key,value in pairs(a) do if not same(value,b[key]) then return false end end
    for key in pairs(b) do if a[key]==nil then return false end end;return true
end
local function data(game) return assert(SessionCodec.encode(game.session,gate)) end
local function native(image,name)
    if HarnessBuild and HarnessBuild.enabled and playdate.simulator then
        playdate.simulator.writeToFile(image,HarnessBuild.output_dir..name..".png")
    end
end
local function buttons(pc,...)
    for _,button in ipairs({...}) do pc:handleButton(button) end
end
local function setup(callback)
    local game=GameContext({seed=16777217});created[#created+1]=game
    local sub=StateMachine();sub:register("explore",{});sub:change("explore")
    game.machine:register("overworld",{sub=sub})
    game.machine:register("pc",PCState(game))
    game.machine:register("itemPC",ItemPCState(game))
    game.machine:change("overworld")
    switchZone("reds_house_2f")
    game.player=Player(5,3,currentZone.collision,game.npcManager);game.player:remove();game.player.facing="up"
    assert(game:recruit(Pokemon("charmander",5)));assert(game:recruit(Pokemon("squirtle",5)))
    assert(game.session:setIntro({stage="done",starter="charmander",rivalStarter="squirtle",rivalOutcome=true}))
    game.machine:push("pc",{onComplete=callback})
    return game,game.machine:get("pc")
end
local function boxed(game,count,lastLevel)
    for i=1,count or 1 do
        local mon=Pokemon("pidgey",i==count and lastLevel or 4)
        local ok,result=game.session:recruit(mon);assert(ok,result)
        if result.destination=="party" then assert(game.session:storage():deposit(game.session:party(),result.index)) end
    end
end
function PCContracts.run()
    invocation=invocation+1
    local report={ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)
        local oldZone,oldRNG=currentZone,RulesRNG.toData()
        local oldOwner,oldStory=GameSession.activeRNGSession(),Story.currentContext()
        local sprites={};for _,sprite in ipairs(playdate.graphics.sprite.getAllSprites()) do
            sprites[sprite]={visible=sprite:isVisible(),enabled=sprite:updatesEnabled()}
        end
        created={}
        local ok,problem=pcall(fn)
        for _,game in ipairs(created) do pcall(game.machine.change,game.machine,"overworld") end
        for _,sprite in ipairs(playdate.graphics.sprite.getAllSprites()) do if not sprites[sprite] then sprite:remove() end end
        for sprite,state in pairs(sprites) do sprite:setVisible(state.visible);sprite:setUpdatesEnabled(state.enabled) end
        currentZone=oldZone
        if GameSession.activeRNGSession()~=oldOwner or not same(oldRNG,RulesRNG.toData()) then
            ok=false;problem="PC changed global rules RNG/owner"
            local owner=GameSession.activeRNGSession();if owner and owner~=oldOwner then owner:deactivateRNG() end
            if oldOwner and GameSession.activeRNGSession()~=oldOwner then oldOwner:activateRNG() end
            RulesRNG.restoreData(oldRNG)
        end
        if Story.currentContext()~=oldStory then ok=false;problem="PC changed Story context owner";Story.bind(oldStory) end
        playdate.graphics.sprite.addDirtyRect(0,0,400,240)
        report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(problem) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("PC exact source terminal coordinates/facing are pure and defensive",function()
        for _,zone in ipairs({"pokered:VIRIDIAN_POKECENTER","pokered:PEWTER_POKECENTER"}) do
            local location={zone_id=zone,x=13,y=4,facing="up"}
            local result=assert(PCTerminals.query(location));eq(result.id,zone..":hidden:2");eq(result.y,3)
            result.id="tampered";eq(PCTerminals.query(location).id,zone..":hidden:2")
            for _,dir in ipairs({"down","left","right"}) do location.facing=dir;eq(PCTerminals.query(location),nil) end
            location.facing="up";location.y=3;eq(PCTerminals.query(location),nil)
        end
        eq(PCTerminals.query({zone_id="reds_house_2f",x=13,y=4,facing="up"}),nil)
    end)
    test("PC source names delegate flags, RED opens real item service and Oak remains unsupported",function()
        local game,pc=setup();eq(pc.menu.options[1],"SOMEONE'S PC")
        local before=data(game);buttons(pc,"down","a")
        eq(game.machine:getCurrent(),"itemPC");eq(game.machine:get("itemPC").phase,"menu");assert(same(before,data(game)))
        game.machine:get("itemPC"):handleButton("b");eq(game.machine:getCurrent(),"pc");eq(pc.phase,"top")
        assert(game.session:setQuestFlag("EVENT_MET_BILL",true));assert(game.session:setQuestFlag("EVENT_GOT_POKEDEX",true));pc:top()
        eq(pc.menu.options[1],"BILL'S PC");eq(pc.menu.options[3],"PROF.OAK'S PC")
        before=data(game);buttons(pc,"down","down","a");eq(pc.result.reason,"unavailable");assert(same(before,data(game)))
        buttons(pc,"b");eq(pc.phase,"top")
        local snapshot=pc:getSnapshot();snapshot.menu.options[1]="tampered";eq(pc.menu.options[1],"BILL'S PC")
    end)
    test("PC deposit then withdraw preserves identical object HP status zeroPP and choices",function()
        local game,pc=setup();local party,storage=game.session:party(),game.session:storage();local mon=party:get(1)
        mon.hp=3;mon.status="sleep";mon.statusTurns=0;mon.sleepDuration=3;mon.pp[mon.moves[1]]=0
        local before=assert(PokemonCodec.encode(mon))
        buttons(pc,"a","down","a","a","a");eq(pc.result.ok,true);eq(storage:get(1),mon);eq(party:count(),1)
        assert(same(before,assert(PokemonCodec.encode(mon))))
        buttons(pc,"a","b","a","a","a");eq(pc.result.ok,true);eq(party:get(2),mon);eq(storage:count(),0)
        assert(same(before,assert(PokemonCodec.encode(mon))))
    end)
    test("PC full current box and last member/last usable deposit failures are atomic",function()
        local game,pc=setup();boxed(game,20);local before=data(game)
        buttons(pc,"a","down","a","a","a");eq(pc.result.reason,"box-full");assert(same(before,data(game)))
        game,pc=setup();assert(game.session:storage():deposit(game.session:party(),2));before=data(game)
        buttons(pc,"a","down","a","a","a");eq(pc.result.reason,"last-member");assert(same(before,data(game)))
        game,pc=setup();game.session:party():get(2).hp=0;before=data(game)
        buttons(pc,"a","down","a","a","a");eq(pc.result.reason,"last-usable");assert(same(before,data(game)))
    end)
    test("PC full party withdrawal fails unchanged and selected box never overflows",function()
        local game,pc=setup();for i=3,6 do assert(game:recruit(Pokemon("rattata",3))) end;boxed(game)
        local before=data(game);buttons(pc,"a","a","a","a");eq(pc.result.reason,"party-full");assert(same(before,data(game)))
        eq(game.session:storage():count(2),0)
    end)
    test("PC release requires explicit YES default NO and clears ownership exactly once",function()
        local game,pc=setup();boxed(game);local storage=game.session:storage();local mon=storage:get(1);local before=data(game)
        buttons(pc,"a","down","down","a","a");eq(pc.phase,"release-confirm");eq(pc.menu.selectedIndex,2)
        buttons(pc,"a");eq(pc.phase,"list");assert(same(before,data(game)))
        buttons(pc,"a");local stale=pc.menu.onSelect;buttons(pc,"up","a");eq(pc.result.ok,true);eq(storage:count(),0)
        eq(Party._owner(mon),nil);stale(1);eq(storage:count(),0)
        assert(game.session:party():add(mon));eq(game.session:party():get(3),mon)
    end)
    test("PC stale identity/index/box selection cannot transfer or release another mon",function()
        for _,operation in ipairs({"withdraw","release"}) do
            local game,pc=setup();boxed(game,2);pc.operation=operation;pc:list();pc:chooseMon()
            local storage=game.session:storage();local first=storage:get(1)
            assert(storage:move(1,2));local before=data(game)
            if operation=="release" then pc.menu.onSelect(1) else pc.menu.onSelect(1) end
            eq(pc.result.reason,"stale-selection");assert(same(before,data(game)));eq(storage:get(1,2),first)
        end
    end)
    test("PC exit/reentry invalidates callbacks; close completes once after pop",function()
        local count=0;local game,pc
        game,pc=setup(function() count=count+1;eq(game.machine:getCurrent(),"overworld") end)
        local staleSelect,staleCancel=pc.menu.onSelect,pc.menu.onCancel
        buttons(pc,"b");eq(count,1);game.machine:push("pc")
        staleSelect(1);staleCancel();eq(pc.phase,"top");eq(count,1)
        boxed(game);pc.operation="release";pc:list();pc:chooseMon();local staleRelease=pc.menu.onSelect
        game.machine:pop();game.machine:push("pc");local before=data(game);staleRelease(1);assert(same(before,data(game)))
    end)
    test("Trusted PC capture rejects ordinary overlays fake instances stale epochs and event parent",function()
        local game,pc=setup();local epoch=pc.epoch
        eq(game:captureSession(),nil);assert(game:captureSessionFromPC(pc,epoch))
        for _,outsider in ipairs({false,1,"pc"}) do eq(game:captureSessionFromPC(outsider,epoch),nil) end
        eq(game:captureSessionFromPC({},epoch),nil);eq(game:captureSessionFromPC(pc,epoch-1),nil);eq(game:captureSessionFromPC(pc,nil),nil)
        game.machine:register("event",{});game.machine:push("event");eq(game:captureSessionFromPC(pc,epoch),nil)
        game.machine:pop();game.machine:pop();game.machine:push("event");game.machine:push("pc")
        eq(game:captureSessionFromPC(pc,pc.epoch),nil)
        game.machine:change("overworld");game.machine:push("pc")
        for _,field in ipairs({"isMoving","pendingEdgeDoor","pendingConnection","stepJustFinished","isJumping"}) do
            game.player[field]=true;eq(game:captureSessionFromPC(pc,pc.epoch),nil);game.player[field]=false
        end
        game.machine:pop();assert(game:captureSession())
    end)
    test("PC detail and twenty-slot lists draw through SDK preserving caller state",function()
        local game,pc=setup();boxed(game,20,40);buttons(pc,"a","a")
        for i=1,19 do buttons(pc,"down") end;eq(pc.selected,20)
        local gfx=playdate.graphics;local image=gfx.image.new(400,240,gfx.kColorWhite)
        gfx.pushContext(image);gfx.setDrawOffset(17,-13);pc:draw();local x,y=gfx.getDrawOffset();gfx.popContext();eq(x,17);eq(y,-13);native(image,"pc-ui-full-box")
        buttons(pc,"a","down","a");eq(pc.phase,"detail");gfx.pushContext(image);pc:draw();gfx.popContext();native(image,"pc-ui-detail")
        local mon=pc.selection.mon;eq(#mon.moves,4)
        local fourth=mon.moves[4]
        local function visibleText(text,left,top)
            gfx.pushContext();gfx.setFont(pc.font);local width,height=gfx.getTextSize(text);gfx.popContext()
            assert(top+height<=188,"text crosses footer: "..text)
            local expected=gfx.image.new(width,height,gfx.kColorWhite)
            gfx.pushContext(expected);gfx.setDrawOffset(0,0);gfx.setFont(pc.font);gfx.setImageDrawMode(gfx.kDrawModeCopy);gfx.drawText(text,0,0);gfx.popContext()
            local ink=0
            for y=0,height-1 do for x=0,width-1 do
                local pixel=expected:sample(x,y)
                assert(image:sample(left+x,top+y)==pixel,"visible text clipped or overwritten: "..text)
                if pixel==gfx.kColorBlack then ink=ink+1 end
            end end
            assert(ink>0,"text evidence requires rendered glyphs")
        end
        local rowHeight=pc:rowHeight()
        local fourthTop=188-rowHeight
        if HarnessBuild and HarnessBuild.enabled then
            gfx.pushContext();gfx.setFont(gfx.getSystemFont());local sw,sh=gfx.getTextSize("ROOST");gfx.setFont(pc.font);local pw,ph=gfx.getTextSize("ROOST");gfx.popContext()
            json.encodeToFile("pc-font-metrics-"..HarnessBuild.session_id..".json",true,{system={height=gfx.getSystemFont():getHeight(),text_width=sw,text_height=sh},chosen={path="/System/Fonts/Asheville-Sans-14-Bold",height=pc.font:getHeight(),text_width=pw,text_height=ph,row_height=rowHeight},fourth_move={top=fourthTop,bottom=fourthTop+ph,footer_top=188}})
        end
        assert(rowHeight<=21,"chosen font row height "..rowHeight.." cannot fit detail metadata and four rows")
        visibleText(moveData[fourth].name,18,fourthTop)
        visibleText("PP "..mon.pp[fourth].."/"..moveData[fourth].maxPP,274,fourthTop)
        buttons(pc,"b","b");eq(pc.phase,"storage")
        gfx.pushContext(image);pc:draw();gfx.popContext();native(image,"pc-ui-storage-menu")
        buttons(pc,"down","down","down","a","up","a");eq(pc.phase,"boxes")
        gfx.pushContext(image);pc:draw();gfx.popContext();native(image,"pc-ui-twelve-boxes")
        visibleText("  BOX 12  0/20",208,160)
        buttons(pc,"b");pc.operation="release";pc:list();pc:chooseMon()
        gfx.pushContext(image);pc:draw();gfx.popContext();native(image,"pc-ui-release-no")
    end)
    local private=HarnessBuild and HarnessBuild.enabled and type(HarnessBuild.bundle_id)=="string" and HarnessBuild.bundle_id:match("^com%.poc%.pokemon%.harness%.")
    if not private then test("PC save cases require private harness Data",function() error("private harness bundle required; no files touched") end);return report end
    local serial=0;local fs=SaveStore.sdkFilesystem()
    local function saving(game,overrides)
        serial=serial+1;local prefix="pc-contract-"..HarnessBuild.session_id.."-"..invocation.."-"..serial
        local adapter={read=overrides and overrides.read or fs.read,write=overrides and overrides.write or fs.write,rename=overrides and overrides.rename or fs.rename}
        game.saves=GameSaves(game,prefix);game.saves.store=SessionCodec.store(prefix,game:getSessionDependencies(),adapter)
        return game.saves,prefix
    end
    test("ChangeBox saves all twelve choices via actual SDK slots and preserves owners",function()
        local game,pc=setup();boxed(game);local saves=saving(game)
        local session,party,storage,bag=game.session,game.session:party(),game.session:storage(),game.session:inventory()
        for box=1,12 do
            assert(saves:changeBoxFromPC(pc,box,pc.epoch));eq(storage:activeBox(),box)
            local loaded=assert(saves:inspect());eq(loaded:storage():activeBox(),box)
        end
        eq(game.session,session);eq(session:party(),party);eq(session:storage(),storage);eq(session:inventory(),bag)
    end)
    test("ChangeBox returned write failure and raised store error rollback full aggregate/owners",function()
        for _,kind in ipairs({"returned","raised"}) do
            local game,pc=setup();local saves=saving(game,{write=function() return false,"controlled write failure" end})
            if kind=="raised" then saves.store.save=function() error("controlled store error") end end
            local session,party,storage,bag=game.session,game.session:party(),game.session:storage(),game.session:inventory()
            local before=data(game);local ok,metadata=saves:changeBoxFromPC(pc,12,pc.epoch);eq(ok,false);assert(metadata.reason)
            assert(same(before,data(game)));eq(game.session,session);eq(session:party(),party);eq(session:storage(),storage);eq(session:inventory(),bag)
            pc.box=12;pc:saveBox();eq(pc.result.ok,false);assert(pc.result.message:find("not confirmed",1,true))
        end
    end)
    test("ChangeBox rejects invalid/stale/foreign/depth3 boundaries before any file writes",function()
        local game,pc=setup();local writes=0;local saves=saving(game,{write=function() writes=writes+1;return false,"unexpected" end})
        local before=data(game)
        for _,index in ipairs({0,13,1.5,"2"}) do eq(saves:changeBoxFromPC(pc,index,pc.epoch),false) end
        eq(saves:changeBoxFromPC(pc,2,pc.epoch-1),false);eq(saves:changeBoxFromPC({},2,pc.epoch),false)
        game.machine:register("modal",{});game.machine:push("modal");eq(saves:changeBoxFromPC(pc,2,pc.epoch),false)
        eq(writes,0);assert(same(before,data(game)))
    end)
    test("ChangeBox rename failure retains recoverable candidate without false UI success",function()
        local game,pc=setup();local saves,prefix=saving(game)
        assert(saves:changeBoxFromPC(pc,1,pc.epoch));local old=assert(fs.read(prefix..".a.json"))
        saves.store=SessionCodec.store(prefix,game:getSessionDependencies(),{read=fs.read,write=fs.write,rename=function() return false,"controlled rename failure" end})
        local before=data(game);pc.box=2;pc:saveBox();eq(pc.result.ok,false);eq(game.session:storage():activeBox(),1)
        assert(same(before,data(game)));eq(fs.read(prefix..".a.json"),old)
        local loaded,metadata=saves:inspect();assert(loaded);eq(loaded:storage():activeBox(),1);eq(metadata.pendingCandidate,true)
    end)
    test("ChangeBox post-rename failure reports ambiguity and leaves old live selection",function()
        local game,pc=setup();local saves,prefix=saving(game);assert(saves:changeBoxFromPC(pc,1,pc.epoch))
        saves.store=SessionCodec.store(prefix,game:getSessionDependencies(),{read=fs.read,write=fs.write,rename=function(from,to) assert(fs.rename(from,to));return false,"controlled after publish" end})
        local before=data(game);local ok,metadata=saves:changeBoxFromPC(pc,2,pc.epoch);eq(ok,false);eq(metadata.reason,"publication-failed")
        assert(same(before,data(game)))
        local loaded=assert(saves:inspect());eq(loaded:storage():activeBox(),2) -- disk may have committed despite failed acknowledgment
    end)
    test("PC transfer and box save decode independently without healing or shared identities",function()
        local game,pc=setup();local mon=game.session:party():get(1);mon.hp=1;mon.status="poison";mon.pp[mon.moves[1]]=0
        assert(game.session:storage():deposit(game.session:party(),1));local saves=saving(game)
        assert(saves:changeBoxFromPC(pc,12,pc.epoch));local restored=assert(saves:inspect())
        local loaded=restored:storage():get(1,1);eq(loaded.hp,1);eq(loaded.status,"poison");eq(loaded.pp[loaded.moves[1]],0);assert(loaded~=mon)
        eq(restored:storage():activeBox(),12);eq(restored:party():count(),1)
    end)
    test("installed source Centers open their original storage PC", function()
        local definitions = assert(json.decodeFile("data/pcTerminals.json")).terminals
        for id, terminal in pairs(definitions) do
            local name = SourceMaps.nameForID(id)
            if name then
                local padding = SourceMaps.entry(name).padding
                local position = {zone_id=id, x=terminal.x + padding,
                    y=terminal.y + 1, facing="up"}
                eq(assert(PCTerminals.query(position)).id, terminal.id)
                position.facing = "down"
                eq(PCTerminals.query(position), nil)
            end
        end
        VermilionStoryFixture.withScene("CeruleanPokecenter", {x=13, y=4, facing="up"}, function(g)
            g.machine:register("pc", PCState(g))
            assert(PCTerminals.tryInteract(g))
            eq(g.machine:getCurrent(), "pc")
            eq(g.machine:get("pc").phase, "top")
        end)
    end)
    return report
end
