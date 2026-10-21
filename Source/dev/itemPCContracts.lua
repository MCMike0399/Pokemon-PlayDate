ItemPCContracts={}
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
        else currentZone=zoneRegistry.reds_house_2f end
        g.machine:register("overworld",OverworldState(g));g.machine:register("bag",BagState(g));g.machine:register("pause",PauseState(g))
        g.machine:register("dialog",DialogState(g));g.machine:register("townMap",TownMapState(g));g.machine:register("homeRest",HomeRestState(g));g.machine:register("pc",PCState(g));g.machine:register("itemPC",ItemPCState(g))
        local entry=name=="forest"and{x=25,y=33,facing="up"}or{x=7,y=3,facing="up"}
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
local gate={root="overworld",overworld="explore",settled=true}
local function fresh()
    return GameContext({sessionLocationPolicy=PewterWorld.locationPolicy()}).session
end
local function install(session,bag,pc)
    assert(session:inventory():_replaceData({version=1,money=3000,slots=bag}))
    session:itemStorage():_prepareCommit({version=1,slots=pc})()
end
local function resolve(s,op,index,n)
    local request,reason=s:selectPCItem(op,index);assert(request,reason)
    return s:resolvePCItem(request,n,"confirm")
end
local function filler(count,id,quantity)
    local out={};for i=1,count do out[i]={id=id or "potion",quantity=quantity or 99}end;return out
end
local function state(s)return {bag=s:inventory():toData(),pc=s:itemStorage():toData()}end
function ItemPCContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)
        local ok,error=pcall(fn);report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(error)or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("new actual game starts with PC Potion1 and empty bag, not an automatic reward",function()
        local s=fresh();eq(s:itemStorage():quantity("potion"),1);eq(s:itemStorage():count(),1);eq(s:inventory():count(),0)
        eq(s:inventory():money(),3000);eq(s:checkpoint().zone_id,"pallet_town")
    end)
    test("physical duplicate99+1 deposit removes only selected second bag row",function()
        local s=fresh();local bag,pc=s:inventory(),s:itemStorage()
        install(s,{{id="potion",quantity=99},{id="potion",quantity=1}},{});assert(resolve(s,"deposit",2,1))
        eq(bag:count(),1);eq(bag:slots()[1].quantity,99);eq(pc:slots()[1].quantity,1);eq(s:inventory(),bag);eq(s:itemStorage(),pc)
    end)
    test("physical duplicate99+1 withdrawal leaves the first stored row unchanged",function()
        local s=fresh();install(s,{},{{id="potion",quantity=99},{id="potion",quantity=1}});assert(resolve(s,"withdraw",2,1))
        eq(s:itemStorage():count(),1);eq(s:itemStorage():slots()[1].quantity,99);eq(s:inventory():quantity("potion"),1)
    end)
    test("Blue full50 first-overflow check precedes merge into later duplicate",function()
        local slots=filler(50);slots[50].quantity=1
        eq(ItemStorage.planAdd(slots,50,"potion",1),nil);eq(slots[1].quantity,99);eq(slots[50].quantity,1)
        slots[1].quantity=98;local result=assert(ItemStorage.planAdd(slots,50,"potion",1));eq(#result,50);eq(result[1].quantity,99);eq(result[50].quantity,1)
        slots=filler(49,"antidote");slots[1]={id="potion",quantity=98};result=assert(ItemStorage.planAdd(slots,50,"potion",2));eq(#result,50);eq(result[1].quantity,99);eq(result[50].quantity,1)
    end)
    test("fullPC rejects deposit atomically, fresh retry after real toss succeeds",function()
        local s=fresh();install(s,{{id="potion",quantity=1}},filler(50,"antidote"));local before=state(s)
        local ok,reason=resolve(s,"deposit",1,1);eq(ok,false);eq(reason,"pc-full");assert(same(before,state(s)))
        assert(resolve(s,"toss",50,99));assert(resolve(s,"deposit",1,1));eq(s:itemStorage():count(),50);eq(s:inventory():count(),0);eq(s:itemStorage():slots()[50].id,"potion")
    end)
    test("fullbag withdrawal preserves PC and retries after a physical bag row is freed",function()
        local s=fresh();install(s,filler(20,"antidote"),{{id="potion",quantity=1}});local before=state(s)
        local ok,reason=resolve(s,"withdraw",1,1);eq(ok,false);eq(reason,"bag-full");assert(same(before,state(s)))
        assert(s:inventory():consume("antidote",99));assert(resolve(s,"withdraw",1,1));eq(s:inventory():count(),20);eq(s:itemStorage():count(),0)
    end)
    test("key and HM deposits and withdrawals move one; neither can be tossed",function()
        for _,id in ipairs({"townMap","hm01"})do
            local s=fresh();install(s,{{id=id,quantity=1}},{});assert(resolve(s,"deposit",1,1))
            local request,reason=s:selectPCItem("toss",1);eq(request,nil);eq(reason,"important-item");eq(s:itemStorage():quantity(id),1)
            assert(resolve(s,"withdraw",1,1));eq(s:inventory():quantity(id),1);eq(s:itemStorage():quantity(id),0)
        end
    end)
    test("invalid quantity cannot span duplicate rows or coerce float/bool",function()
        for _,quantity in ipairs({0,-1,2,100,1.5,true})do
            local s=fresh();install(s,{},{{id="potion",quantity=1},{id="potion",quantity=99}});local before=state(s)
            local ok,reason=resolve(s,"withdraw",1,quantity);eq(ok,false);eq(reason,"invalid-quantity");assert(same(before,state(s)))
        end
    end)
    test("cancelled and committed request is one-shot; wrong owner never mutates either session",function()
        local a,b=fresh(),fresh();local request=assert(a:selectPCItem("withdraw",1));eq(b:resolvePCItem(request,1,"confirm"),false)
        eq(a:resolvePCItem(request,nil,"cancel"),false);eq(a:resolvePCItem(request,1,"confirm"),false);eq(a:itemStorage():quantity("potion"),1)
        request=assert(a:selectPCItem("withdraw",1));assert(a:resolvePCItem(request,1,"confirm"));eq(a:resolvePCItem(request,1,"confirm"),false)
        eq(a:inventory():quantity("potion"),1);eq(b:itemStorage():quantity("potion"),1)
    end)
    test("stale bag, money and selected physical-PC changes fail without transfer",function()
        for _,change in ipairs({function(s)assert(s:inventory():credit(1))end,function(s)assert(s:inventory():add("antidote",1))end,
            function(s)s:itemStorage():_prepareCommit({version=1,slots={{id="potion",quantity=2}}})()end})do
            local s=fresh();local request=assert(s:selectPCItem("withdraw",1));change(s);local before=state(s)
            local ok,reason=s:resolvePCItem(request,1,"confirm");eq(ok,false);eq(reason,"stale-selection");assert(same(before,state(s)))
        end
    end)
    test("transfers and toss retain objects and both RNG streams, flags, party and money",function()
        local s=fresh();local bag,pc=s:inventory(),s:itemStorage();local rules,world=RulesRNG.toData(),s:worldRngData();local flags=s:flags();local party=s:party()
        assert(resolve(s,"withdraw",1,1));assert(resolve(s,"deposit",1,1));assert(resolve(s,"toss",1,1))
        eq(s:inventory(),bag);eq(s:itemStorage(),pc);eq(s:party(),party);eq(bag:money(),3000);assert(same(flags,s:flags()));assert(same(rules,RulesRNG.toData()));assert(same(world,s:worldRngData()))
    end)
    test("legacy schema1 missing PC migrates empty, retains bag and never regrants across roundtrips",function()
        local s=fresh();assert(resolve(s,"withdraw",1,1));local data=assert(SessionCodec.encode(s,gate));data.itemStorage=nil
        local decoded=assert(SessionCodec.decode(data,GameSession._state(s).deps))
        eq(decoded:itemStorage():count(),0);eq(decoded:inventory():quantity("potion"),1)
        for i=1,2 do decoded=assert(SessionCodec.decode(assert(SessionCodec.encode(decoded,gate)),GameSession._state(s).deps));eq(decoded:itemStorage():count(),0);eq(decoded:inventory():quantity("potion"),1)end
    end)
    test("present PC schema rejects malformed versions/counts/rows/duplicate keys and cross-bag duplicates",function()
        local s=fresh();local base=assert(SessionCodec.encode(s,gate));local mutations={
            false,2,{version=2,slots={}},{version=1,slots=filler(51)},{version=1,slots={{id="potion",quantity=100}}},
            {version=1,slots={{id="unknown",quantity=1}}},{version=1,slots={{id="potion",quantity=1,extra=true}}},
            {version=1,slots={{id="hm01",quantity=1},{id="hm01",quantity=1}}},{version=1,slots={},money=1}}
        for _,pc in ipairs(mutations)do local bad=Party._primitive(base);bad.itemStorage=pc;eq(SessionCodec.validate(bad,GameSession._state(s).deps),false)end
        base.inventory.slots={{id="hm01",quantity=1}};base.itemStorage={version=1,slots={{id="hm01",quantity=1}}};eq(SessionCodec.validate(base,GameSession._state(s).deps),false)
    end)
    test("bedroom source terminal uses unchanged authored PC coordinate and all other facings reject",function()
        local terminal=assert(PCTerminals.query({zone_id="reds_house_2f",x=7,y=3,facing="up"}));eq(terminal.personal,true);eq(terminal.x,7);eq(terminal.y,2)
        for _,facing in ipairs({"down","left","right"})do eq(PCTerminals.query({zone_id="reds_house_2f",x=7,y=3,facing=facing}),nil)end
    end)
    test("native bedroom input opens personal PC and withdraws original Potion only after quantity A",function()
        scene("bedroom",function(g)
            assert(PCTerminals.tryInteract(g));eq(g.machine:getCurrent(),"itemPC");local pc=g.machine:get("itemPC")
            pc:draw();write("item-pc-main");pc:handleButton("a");eq(pc.phase,"list");pc:draw();write("item-pc-withdraw-list")
            pc:handleButton("a");eq(pc.phase,"quantity");eq(g.session:inventory():quantity("potion"),0);pc:draw();write("item-pc-withdraw-quantity")
            pc:handleButton("a");eq(pc.result.ok,true);eq(g.session:inventory():quantity("potion"),1);eq(g.session:itemStorage():quantity("potion"),0)
            pc:draw();write("item-pc-withdraw-result")
        end)
    end)
    test("native quantity cancel, stale callbacks and actual toss NO do not transfer",function()
        scene("bedroom",function(g)
            assert(PCTerminals.tryInteract(g));local pc=g.machine:get("itemPC");pc:handleButton("a");pc:handleButton("a");pc:handleButton("b")
            eq(g.session:itemStorage():quantity("potion"),1);eq(g.session:inventory():quantity("potion"),0)
            pc:handleButton("b");pc:handleButton("down");pc:handleButton("down");pc:handleButton("a");pc:handleButton("a");pc:handleButton("a")
            eq(pc.phase,"confirm");pc:draw();write("item-pc-toss-confirm");local stale=pc.menu.onSelect;pc:handleButton("down");pc:handleButton("a");stale(1)
            eq(g.session:itemStorage():quantity("potion"),1)
        end)
    end)
    test("generic PC RED service returns to unchanged Pokémon storage and overlay cannot save",function()
        scene("bedroom",function(g)
            local party,storage=g.session:party(),g.session:storage();g.machine:push("pc",{terminal_id="contract-parent"})
            local parent=g.machine:get("pc");parent:handleButton("down");parent:handleButton("a");eq(g.machine:getCurrent(),"itemPC")
            eq(g:captureSession(),nil);local pc=g.machine:get("itemPC");pc:handleButton("b");eq(g.machine:getCurrent(),"pc");eq(parent.phase,"top")
            parent:handleButton("up");parent:handleButton("a");eq(parent.phase,"storage");eq(g.session:party(),party);eq(g.session:storage(),storage)
        end)
    end)
    test("actual SDK published malformed-PC slot falls back to prior good slot without overwriting corruption",function()
        assert(HarnessBuild and HarnessBuild.enabled and playdate.isSimulator,"private harness required for SDK save proof")
        ItemPCContracts.invocation=(ItemPCContracts.invocation or 0)+1
        local s=fresh();local deps=GameSession._state(s).deps
        local prefix="item-pc-"..HarnessBuild.session_id.."-"..ItemPCContracts.invocation
        local store=SessionCodec.store(prefix,deps);local fs=SaveStore.sdkFilesystem()
        assert(store:save(assert(SessionCodec.encode(s,gate))));assert(resolve(s,"withdraw",1,1))
        assert(store:save(assert(SessionCodec.encode(s,gate))))
        local envelope=json.decode(assert(fs.read(prefix..".b.json")));local payload=json.decode(envelope.payload)
        payload.itemStorage={version=1,slots={{id="potion",quantity=0}}}
        envelope.payload=json.encode(payload);envelope.checksum=SaveStore._boundChecksum(envelope.schema,envelope.sequence,envelope.payload)
        local bytes=json.encode(envelope);assert(fs.write(prefix..".b.json",bytes))
        local data,meta=store:load();assert(data);eq(meta.reason,"recovered-published");eq(meta.slot,"a")
        local restored=assert(SessionCodec.decode(data,deps));eq(restored:itemStorage():quantity("potion"),1);eq(restored:inventory():quantity("potion"),0)
        eq(fs.read(prefix..".b.json"),bytes);eq(store:save(assert(SessionCodec.encode(s,gate))),false);eq(fs.read(prefix..".b.json"),bytes)
    end)
    return report
end
