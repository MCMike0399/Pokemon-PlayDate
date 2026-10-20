-- Production Inventory/Pokemon medicine and Blue economy contracts.
ItemContracts = {}
local function equal(actual,wanted,label)
    assert(actual==wanted,(label or "value") .. ": expected " .. tostring(wanted) .. ", got " .. tostring(actual))
end
local function bag(id,quantity,money)
    local inventory=Inventory(ItemData.definitions)
    if id then assert(inventory:add(id,quantity or 1)) end
    if money then assert(inventory:credit(money)) end
    return inventory
end
local function sameBag(inventory,before)
    equal(inventory:money(),before.money,"money unchanged")
    local slots=inventory:slots();equal(#slots,#before.slots,"slot count unchanged")
    for i,slot in ipairs(slots) do equal(slot.id,before.slots[i].id);equal(slot.quantity,before.slots[i].quantity) end
end
local function failsUnchanged(inventory,fn,wanted)
    local before=inventory:toData();local ok,problem=fn()
    equal(ok,false);equal(problem,wanted);sameBag(inventory,before)
end
function ItemContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)
        local ok,problem=pcall(fn)
        report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(problem) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("Blue canonical IDs symbols prices and category boundaries",function()
        equal(ItemData.bySymbol.POKE_BALL,"pokeBall");equal(ItemData.bySymbol.OAKS_PARCEL,"oaksParcel")
        equal(ItemData.bySymbol.TOWN_MAP,"townMap");equal(ItemData.bySymbol.TM_MEGA_PUNCH,"tm01")
        equal(ItemData.bySymbol.HM_CUT,"hm01");equal(ItemData.definitions.tm01.category,"tm")
        equal(ItemData.definitions.hm01.category,"hm");equal(ItemData.definitions.hm01.keyItem,true)
        equal(ItemData.definitions.potion.numericId,20);equal(ItemData.definitions.potion.price,300)
        equal(ItemData.definitions.pokeBall.price,200);equal(ItemData.definitions.parlyzHeal.price,200)
        equal(ItemData.definitions.nugget.sellPrice,5000);equal(ItemData.definitions.tm01.price,3000)
        for _,symbol in ipairs({"SURFBOARD","ITEM_2C","ITEM_32","COIN","POKEDEX","BOULDERBADGE","SAFARI_BALL"}) do equal(ItemData.bySymbol[symbol],nil,symbol) end
        local count=0;for _ in pairs(ItemData.definitions) do count=count+1 end;equal(count,124)
    end)
    test("Blue Viridian stock does not invent a Potion shelf",function()
        equal(table.concat(ItemData.marts.viridianMartClerkText,","),"pokeBall,antidote,parlyzHeal,burnHeal")
        local inventory=bag(nil,nil,1000)
        failsUnchanged(inventory,function() return Items.buy(inventory,"viridianMartClerkText","potion",1) end,"not-stocked")
    end)
    test("GenV HP medicines heal20 50 200 and drinks50 60 80",function()
        for _,v in ipairs({{"potion",20},{"superPotion",50},{"hyperPotion",200},{"freshWater",50},{"sodaPop",60},{"lemonade",80}}) do
            local p=Pokemon("chansey",100);p.hp=1
            local inventory=bag(v[1]);local ok,result=Items.use(inventory,v[1],p)
            equal(ok,true);equal(p.hp,1+v[2],v[1]);equal(result.hpRestored,v[2]);equal(inventory:quantity(v[1]),0)
        end
    end)
    test("HP medicines cap to max and preserve status PP and XP",function()
        local p=Pokemon("charmander",5);p.hp=p.maxHP-2;p.status="burn";p:usePP("scratch")
        local xp,pp=p.xp,p.pp.scratch;local inventory=bag("potion")
        local ok,result=Items.use(inventory,"potion",p)
        equal(ok,true);equal(result.hpRestored,2);equal(p.hp,p.maxHP);equal(p.status,"burn")
        equal(p.statusTurns,0);equal(p.pp.scratch,pp);equal(p.xp,xp)
    end)
    test("Max Potion fully heals without being Full Restore",function()
        local p=Pokemon("chansey",100);p.hp=1;p.status="poison"
        local inventory=bag("maxPotion");equal(Items.use(inventory,"maxPotion",p),true)
        equal(p.hp,p.maxHP);equal(p.status,"poison")
    end)
    test("No-effect full HP never consumes a medicine",function()
        local p=Pokemon("charmander",5);local inventory=bag("potion",2)
        failsUnchanged(inventory,function() return Items.use(inventory,"potion",p) end,"no-effect")
        equal(p.hp,p.maxHP)
    end)
    test("Potions and cures never revive a fainted target",function()
        for _,id in ipairs({"potion","superPotion","hyperPotion","maxPotion","fullRestore","fullHeal","antidote"}) do
            local p=Pokemon("charmander",5);p.hp=0;p.status="poison"
            local inventory=bag(id)
            failsUnchanged(inventory,function() return Items.use(inventory,id,p) end,"no-effect")
            equal(p.hp,0);equal(p.status,"poison")
        end
    end)
    test("Specific cures require matching status and reset sleep counters",function()
        for _,v in ipairs({{"antidote","poison"},{"burnHeal","burn"},{"iceHeal","freeze"},{"awakening","sleep"},{"parlyzHeal","paralyze"}}) do
            local p=Pokemon("charmander",5);p.status=v[2];p.statusTurns=v[2]=="sleep" and 3 or 0;p.sleepDuration=v[2]=="sleep" and 3 or 0
            local inventory=bag(v[1]);equal(Items.use(inventory,v[1],p),true)
            equal(p.status,nil);equal(p.statusTurns,0)
        end
        local p=Pokemon("charmander",5);p.status="burn";local inventory=bag("antidote")
        failsUnchanged(inventory,function() return Items.use(inventory,"antidote",p) end,"no-effect");equal(p.status,"burn")
    end)
    test("Full Heal cures major status or confusion without healing HP",function()
        local p=Pokemon("charmander",5);p.hp=1;p.status="sleep";p.statusTurns=0;p.sleepDuration=3;p.confusion=3
        local inventory=bag("fullHeal",2);equal(Items.use(inventory,"fullHeal",p),true)
        equal(p.hp,1);equal(p.status,nil);equal(p.statusTurns,0);equal(p.confusion,nil)
        p.confusion=2;equal(Items.use(inventory,"fullHeal",p),true);equal(p.confusion,nil)
    end)
    test("Full Restore clears HP status and confusion even at full HP",function()
        local p=Pokemon("charmander",5);p.status="sleep";p.statusTurns=2;p.sleepDuration=3;p.confusion=1
        local inventory=bag("fullRestore",2);equal(Items.use(inventory,"fullRestore",p),true)
        equal(p.hp,p.maxHP);equal(p.status,nil);equal(p.statusTurns,0);equal(p.confusion,nil)
        failsUnchanged(inventory,function() return Items.use(inventory,"fullRestore",p) end,"no-effect")
    end)
    test("Revive restores floor half HP; Max Revive fully restores without PP",function()
        for _,id in ipairs({"revive","maxRevive"}) do
            local p=Pokemon("charmander",6);p.hp=0;p.status="sleep";p.statusTurns=2;p.sleepDuration=3;p:usePP("scratch")
            local pp=p.pp.scratch;local inventory=bag(id)
            local ok,result=Items.use(inventory,id,p);equal(ok,true);equal(result.revived,true)
            equal(p.hp,id=="revive" and p.maxHP//2 or p.maxHP);equal(p.status,nil);equal(p.statusTurns,0);equal(p.pp.scratch,pp)
        end
        local p=Pokemon("charmander",5);local inventory=bag("revive")
        failsUnchanged(inventory,function() return Items.use(inventory,"revive",p) end,"no-effect")
    end)
    test("Ether restores selected learned move only and caps PP",function()
        local p=Pokemon("charmander",5);p.pp.scratch=1;p.pp.growl=moveData.growl.maxPP-2
        local inventory=bag("ether",2);local ok,result=Items.use(inventory,"ether",p,1)
        equal(ok,true);equal(p.pp.scratch,11);equal(result.ppRestored,10);equal(p.pp.growl,moveData.growl.maxPP-2)
        equal(Items.use(inventory,"ether",p,2),true);equal(p.pp.growl,moveData.growl.maxPP)
    end)
    test("PP targets must be actual move slots; failures do not consume",function()
        local p=Pokemon("charmander",5);p.pp.scratch=1;local inventory=bag("ether",2)
        for _,slot in ipairs({0,3,1.5,"ember"}) do
            failsUnchanged(inventory,function() return Items.use(inventory,"ether",p,slot) end,"invalid-move-slot")
            equal(p.pp.scratch,1)
        end
        failsUnchanged(inventory,function() return Items.use(inventory,"ether",p) end,"invalid-move-slot")
    end)
    test("Max Ether and both Elixirs cap PP with no-effect protection",function()
        local p=Pokemon("charmander",5);p.pp.scratch=0;local inventory=bag("maxEther",2)
        equal(Items.use(inventory,"maxEther",p,1),true);equal(p.pp.scratch,moveData.scratch.maxPP)
        failsUnchanged(inventory,function() return Items.use(inventory,"maxEther",p,1) end,"no-effect")
        p.pp.scratch=0;p.pp.growl=1;inventory=bag("elixir")
        local ok,result=Items.use(inventory,"elixir",p);equal(ok,true);equal(result.ppRestored,20)
        equal(p.pp.scratch,10);equal(p.pp.growl,11)
        inventory=bag("maxElixir",2);equal(Items.use(inventory,"maxElixir",p),true)
        equal(p.pp.scratch,moveData.scratch.maxPP);equal(p.pp.growl,moveData.growl.maxPP)
        failsUnchanged(inventory,function() return Items.use(inventory,"maxElixir",p) end,"no-effect")
    end)
    test("PP medicines can restore a fainted mon without reviving",function()
        local p=Pokemon("charmander",5);p.hp=0;p.pp.scratch=0
        equal(Items.use(bag("ether"),"ether",p,1),true);equal(p.hp,0);equal(p.pp.scratch,10)
    end)
    test("Preview is detached; immediate use replans changed targets",function()
        local p=Pokemon("charmander",5);p.hp=1;local inventory=bag("potion",2)
        local preview=assert(Items.planUse("potion",p));preview.hpAfter=9999
        equal(p.hp,1);equal(inventory:quantity("potion"),2)
        p.hp=p.maxHP
        failsUnchanged(inventory,function() return Items.use(inventory,"potion",p) end,"no-effect")
        p.hp=1;local ok,result=Items.use(inventory,"potion",p)
        equal(ok,true);equal(p.hp,p.maxHP);assert(result.hpAfter~=9999)
    end)
    test("Missing bag stock leaves Pokemon unchanged",function()
        local p=Pokemon("charmander",5);p.hp=1;local inventory=bag()
        failsUnchanged(inventory,function() return Items.use(inventory,"potion",p) end,"insufficient-items");equal(p.hp,1)
    end)
    test("Unsupported item effects explicitly fail without consuming",function()
        local p=Pokemon("charmander",5)
        for _,id in ipairs({"pokeBall","tm01","hm01","ppUp","rareCandy","townMap","oaksParcel","fireStone"}) do
            local inventory=bag(id)
            failsUnchanged(inventory,function() return Items.use(inventory,id,p) end,"unsupported-item-use")
        end
    end)
    test("Purchase debits exact Blue price and retains bag owner",function()
        local inventory=bag(nil,nil,1000);local identity=inventory
        local ok,result=Items.buy(inventory,"pewterMartClerkText","potion",2)
        equal(ok,true);equal(result.total,600);equal(inventory:quantity("potion"),2);equal(inventory:money(),400);equal(inventory,identity)
    end)
    test("Purchase invalid quantity stock money and bag-full failures are atomic",function()
        local inventory=bag(nil,nil,1000)
        for _,qty in ipairs({0,-1,100,1.5,"1"}) do failsUnchanged(inventory,function() return Items.buy(inventory,"pewterMartClerkText","potion",qty) end,"invalid-quantity") end
        failsUnchanged(inventory,function() return Items.buy(inventory,"pewterMartClerkText","potion",4) end,"insufficient-money")
        failsUnchanged(inventory,function() return Items.buy(inventory,"missing","potion",1) end,"unknown-mart")
        failsUnchanged(inventory,function() return Items.buy(inventory,"pewterMartClerkText","missing",1) end,"unknown-item")
        inventory=bag(nil,nil,100000)
        for _=1,20 do assert(inventory:add("pokeBall",99)) end
        failsUnchanged(inventory,function() return Items.buy(inventory,"pewterMartClerkText","potion",1) end,"bag-full")
        failsUnchanged(inventory,function() return Items.buy(inventory,"pewterMartClerkText","pokeBall",1) end,"bag-full")
    end)
    test("Partial stacks fill before capacity and failed split purchases roll back",function()
        local inventory=bag("pokeBall",98,10000)
        for _=1,19 do assert(inventory:add("antidote",99)) end
        failsUnchanged(inventory,function() return Items.buy(inventory,"viridianMartClerkText","pokeBall",2) end,"bag-full")
        equal(inventory:quantity("pokeBall"),98)
        equal(Items.buy(inventory,"viridianMartClerkText","pokeBall",1),true);equal(inventory:quantity("pokeBall"),99)
        failsUnchanged(inventory,function() return Items.buy(inventory,"viridianMartClerkText","pokeBall",2) end,"bag-full")
    end)
    test("Sale halves Blue price and atomically refuses maxmoney overflow",function()
        local inventory=bag("potion",3,100);local ok,result=Items.sell(inventory,"potion",2)
        equal(ok,true);equal(result.total,300);equal(inventory:money(),400);equal(inventory:quantity("potion"),1)
        inventory=bag("nugget",1,999000)
        failsUnchanged(inventory,function() return Items.sell(inventory,"nugget",1) end,"money-limit")
        equal(inventory:quantity("nugget"),1)
    end)
    test("Selling key items HMs missing stock and invalid quantities fails unchanged",function()
        for _,id in ipairs({"townMap","oaksParcel","hm01"}) do
            local inventory=bag(id);failsUnchanged(inventory,function() return Items.sell(inventory,id,1) end,"unsellable-item")
        end
        local inventory=bag("potion",1)
        failsUnchanged(inventory,function() return Items.sell(inventory,"potion",2) end,"insufficient-items")
        failsUnchanged(inventory,function() return Items.sell(inventory,"potion",0) end,"invalid-quantity")
        failsUnchanged(inventory,function() return Items.sell(inventory,"missing",1) end,"unknown-item")
    end)
    test("Zero-priced non-key items retain explicit Blue zero-value sale behavior",function()
        local inventory=bag("ether");local ok,result=Items.sell(inventory,"ether",1)
        equal(ok,true);equal(result.total,0);equal(inventory:money(),0);equal(inventory:quantity("ether"),0)
    end)
    test("Parcel handoff stays an explicit Inventory key-item operation",function()
        local inventory=bag("oaksParcel")
        local ok,problem=inventory:consume("oaksParcel",1);equal(ok,false);equal(problem,"key-item")
        equal(inventory:quantity("oaksParcel"),1)
        equal(inventory:handoffKey("oaksParcel"),true);equal(inventory:quantity("oaksParcel"),0)
        equal(inventory:handoffKey("oaksParcel"),false)
    end)
    return report
end
