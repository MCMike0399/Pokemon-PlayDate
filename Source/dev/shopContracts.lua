ShopContracts={}
local function eq(a,b) assert(a==b,"expected "..tostring(b)..", got "..tostring(a)) end
local function fingerprint(game)
    local bag=game.session:inventory();local values={tostring(bag:money())}
    for _,slot in ipairs(bag:slots()) do values[#values+1]=slot.id..":"..slot.quantity end
    local rng=RulesRNG.toData();values[#values+1]=rng.state;values[#values+1]=rng.rolls
    return table.concat(values,"|")
end
local function setup(mart,callback)
    local game={machine=StateMachine()}
    game.session=GameSession.newSession({itemDefinitions=ItemData.definitions,validateWorld=WorldDeltas.validate,
        resolveLocation=WorldDeltas.resolveLocation},{seed=42,location={zone_id="reds_house_2f",x=5,y=3,facing="up"}})
    assert(game.session:inventory():credit(3000))
    local shop=ShopState(game)
    game.machine:register("overworld",{});game.machine:register("shop",shop);game.machine:change("overworld")
    game.machine:push("shop",{martId=mart or "viridianMartClerkText",onComplete=callback})
    return game,shop
end
local function buttons(shop,...)
    for _,button in ipairs({...}) do shop:handleButton(button) end
end
function ShopContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)
        local ok,problem=pcall(fn);report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(problem) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("Shop uses exact authored stock order and derived diagnostics without changing inventory",function()
        local game,shop=setup();local before=fingerprint(game)
        eq(shop:getSnapshot().phase,"mode");eq(shop:getSnapshot().menu.selected,1)
        buttons(shop,"a");eq(shop:getSnapshot().item,"pokeBall")
        buttons(shop,"down");eq(shop:getSnapshot().item,"antidote")
        eq(shop:rows()[3].id,"parlyzHeal");eq(shop:rows()[4].id,"burnHeal")
        eq(fingerprint(game),before)
        local snap=shop:getSnapshot();snap.menu.options[1]="tamper";eq(shop.menu.options[1],"BUY")
    end)
    test("Quantity input clamps by one/ten and B returns exactly one level",function()
        local game,shop=setup();local before=fingerprint(game)
        buttons(shop,"a","a","left","down");eq(shop.quantity,1)
        buttons(shop,"right","up");eq(shop.quantity,12)
        for i=1,12 do buttons(shop,"right") end;eq(shop.quantity,99)
        buttons(shop,"a");eq(shop.phase,"confirm");eq(shop.menu.selectedIndex,1)
        buttons(shop,"b");eq(shop.phase,"quantity")
        buttons(shop,"b");eq(shop.phase,"browse")
        buttons(shop,"b");eq(shop.phase,"mode");eq(shop.menu.selectedIndex,1)
        eq(fingerprint(game),before)
    end)
    test("BUY changes real bag/money only on explicit YES and retained YES cannot repeat",function()
        local game,shop=setup();local bag=game.session:inventory();local before=fingerprint(game)
        buttons(shop,"a","a","up","a");eq(shop.phase,"confirm");eq(fingerprint(game),before)
        local yes=shop.menu.onSelect
        buttons(shop,"a");eq(shop.phase,"result");eq(bag:quantity("pokeBall"),2);eq(bag:money(),2600)
        eq(shop.result.ok,true);eq(shop.result.total,400)
        local after=fingerprint(game);yes(1);eq(fingerprint(game),after)
        buttons(shop,"a");eq(shop.phase,"browse")
    end)
    test("NO and cancelled confirmation never debit or grant items",function()
        local game,shop=setup();local before=fingerprint(game)
        buttons(shop,"a","a","a","down","a");eq(shop.phase,"quantity");eq(fingerprint(game),before)
        buttons(shop,"a","b");eq(shop.phase,"quantity");eq(fingerprint(game),before)
    end)
    test("Insufficient money returns domain failure and leaves entire bag/RNG unchanged",function()
        local game,shop=setup();assert(game.session:inventory():spend(3000));local before=fingerprint(game)
        buttons(shop,"a","a","a","a");eq(shop.phase,"result");eq(shop.result.reason,"insufficient-money")
        eq(fingerprint(game),before)
    end)
    test("Full bag purchase fails atomically and displays carry message",function()
        local game,shop=setup();local bag=game.session:inventory();local count=0
        local ids={};for id in pairs(ItemData.definitions) do ids[#ids+1]=id end;table.sort(ids)
        for _,id in ipairs(ids) do if id~="pokeBall" and count<20 then assert(bag:add(id,1));count=count+1 end end
        eq(count,20);local before=fingerprint(game)
        buttons(shop,"a","a","a","a");eq(shop.result.reason,"bag-full")
        eq(shop.result.message,"You can't carry any more items.");eq(fingerprint(game),before)
    end)
    test("SELL quantity is owned-bound and commits exact source sell price on YES",function()
        local game,shop=setup();local bag=game.session:inventory();assert(bag:add("potion",3))
        local before=fingerprint(game);buttons(shop,"down","a","a","right");eq(shop.quantity,3)
        buttons(shop,"a");eq(fingerprint(game),before);buttons(shop,"a")
        eq(bag:quantity("potion"),0);eq(bag:money(),3450);eq(shop.result.total,450)
        buttons(shop,"a");eq(shop.phase,"browse");eq(shop:getSnapshot().item,"none")
        buttons(shop,"a");eq(shop.phase,"browse")
    end)
    test("Key and HM sale refusal never consumes and zero-price sale follows Items policy",function()
        for _,id in ipairs({"townMap","hm01"}) do
            local game,shop=setup();assert(game.session:inventory():add(id,1));local before=fingerprint(game)
            buttons(shop,"down","a","a");eq(shop.phase,"result");eq(shop.result.reason,"unsellable-item")
            eq(fingerprint(game),before)
        end
        local game,shop=setup();local bag=game.session:inventory();assert(bag:add("moonStone",1))
        buttons(shop,"down","a","a","a");eq(shop.phase,"confirm");eq(bag:quantity("moonStone"),1)
        buttons(shop,"a");eq(shop.result.ok,true);eq(shop.result.total,0);eq(bag:quantity("moonStone"),0);eq(bag:money(),3000)
    end)
    test("Quoted sale revalidates removed stock and money-cap failure is atomic",function()
        local game,shop=setup();local bag=game.session:inventory();assert(bag:add("potion",2))
        buttons(shop,"down","a","a","up","a");assert(bag:consume("potion",2));local before=fingerprint(game)
        buttons(shop,"a");eq(shop.result.reason,"insufficient-items");eq(fingerprint(game),before)
        game,shop=setup();bag=game.session:inventory();assert(bag:add("potion",1));assert(bag:credit(999999-bag:money()))
        before=fingerprint(game);buttons(shop,"down","a","a","a","a")
        eq(shop.result.reason,"money-limit");eq(fingerprint(game),before)
    end)
    test("Close pops before completing once; stale callbacks cannot close a reentered shop",function()
        local count=0;local game,shop
        game,shop=setup(nil,function(result) count=count+1;eq(game.machine:getCurrent(),"overworld");eq(result.reason,"closed") end)
        local staleSelect,staleCancel=shop.menu.onSelect,shop.menu.onCancel
        buttons(shop,"b");eq(count,1);eq(shop.phase,"closed")
        game.machine:push("shop",{martId="viridianMartClerkText",onComplete=function() count=count+1 end})
        staleSelect(3);staleCancel();eq(game.machine:getCurrent(),"shop");eq(count,1)
        buttons(shop,"down","down","a");eq(count,2);eq(game.machine:getCurrent(),"overworld")
        staleCancel();eq(count,2)
    end)
    test("Stale confirmation after exit/reentry cannot mutate another session bag",function()
        local game,shop=setup();buttons(shop,"a","a","a");local stale=shop.menu.onSelect
        game.machine:pop();game.machine:push("shop",{martId="pewterMartClerkText"})
        local before=fingerprint(game);stale(1);eq(shop.phase,"mode");eq(fingerprint(game),before)
    end)
    test("Long stock/20-slot sale lists scroll and SDK drawing preserves caller offset",function()
        local game,shop=setup("lavenderMartClerkText");buttons(shop,"a")
        for i=1,8 do buttons(shop,"down") end
        eq(shop.selected,9);eq(shop:getSnapshot().item,"parlyzHeal")
        local gfx=playdate.graphics;local image=gfx.image.new(400,240,gfx.kColorWhite)
        gfx.pushContext(image);gfx.setDrawOffset(17,-13)
        shop:draw();local x,y=gfx.getDrawOffset();gfx.popContext();eq(x,17);eq(y,-13)
        local bag=game.session:inventory();local ids={};for id in pairs(ItemData.definitions) do ids[#ids+1]=id end;table.sort(ids)
        for i=1,20 do assert(bag:add(ids[i],1)) end
        buttons(shop,"b","down","a");for i=1,19 do buttons(shop,"down") end
        eq(shop.selected,20);eq(shop:getSnapshot().item,ids[20])
        gfx.pushContext(image);shop:draw();gfx.popContext()
    end)
    return report
end
