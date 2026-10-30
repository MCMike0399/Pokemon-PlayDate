-- Prepared native SDK contracts. No execution claim; root registers/runs these.
import "dev/sessionFixture"
VermilionGiftsContracts = {}
local gate <const> = {root="overworld",overworld="explore",settled=true}
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function same(a,b)
    if type(a)~="table" or type(b)~="table" then eq(a,b);return end
    for k,v in pairs(a) do same(v,b[k]) end
    for k in pairs(b) do assert(a[k]~=nil,"extra field: "..tostring(k)) end
end
local function plan(s,id,decision) return VermilionGifts.plan(id,VermilionGifts.observe(s),decision) end
local function fresh()
    local g=GameContext({sessionLocationPolicy=PewterWorld.locationPolicy()})
    assert(g:recruit(Pokemon("squirtle", 5)))
    assert(g.session:setIntro({stage="done",starter="squirtle",rivalStarter="bulbasaur"}))
    return g
end
local function owned(s,count)
    -- Count the starter already recruited by both fresh and native scenes.
    -- Put existing ownership first so ids[count + 1] is still a new species.
    local dex <const> = s:pokedex()
    local ids <const> = {}
    local remaining <const> = {}
    for id in pairs(pokemonData) do
        if dex.owned[id] then
            ids[#ids + 1] = id
        else
            remaining[#remaining + 1] = id
        end
    end
    table.sort(ids)
    table.sort(remaining)
    local existing <const> = #ids
    assert(existing <= count, "fixture already exceeds owned threshold")
    for _, id in ipairs(remaining) do
        ids[#ids + 1] = id
    end
    for i = existing + 1, count do
        if s:party():count() == Party.CAPACITY and s:storage():count() == Storage.BOX_CAPACITY then
            assert(s:storage():selectBox(s:storage():activeBox() + 1))
        end
        assert(s:recruit(Pokemon(ids[i], 5)))
    end
    -- More seen than owned. Duplicate specimens do not increase this count.
    for i=count+1,math.min(count+10,#ids) do assert(s:markSeen(ids[i])) end
    eq(VermilionGifts.observe(s).owned, count)
    return ids
end
local function full(s)
    local discard
    for id,d in pairs(ItemData.definitions) do
        if not d.keyItem and s:inventory():count()<Inventory.CAPACITY then
            assert(s:inventory():add(id,1));discard=id
        end
    end
    eq(s:inventory():count(),Inventory.CAPACITY)
    return discard
end
local function roundtrip(g)
    local wire=assert(SessionCodec.encode(g.session,gate))
    -- Exercise the actual SDK JSON and codec. This is not process restart proof.
    return assert(SessionCodec.decode(json.decode(json.encode(wire)),g:getSessionDependencies()))
end
local function drain(g)
    for _=1,512 do
        if g.machine:getCurrent()~="dialog" then return end
        local dialog=g.machine:get("dialog")
        dialog.dialog:advance();dialog:handleInput()
    end
    error("gift dialog did not settle")
end
local function settle(g)
    drain(g)
    eq(g.machine:getCurrent(),"overworld")
end
local function scene(name,fn)
    -- Real maps, NPCMotion, Player, dialogs and sprites from the existing SDK
    -- fixture. Root must activate the prepared maps in its integration tree.
    KantoServicesContracts.withScene(name,{x=2,y=5},function(g)
        g.machine:register("event",VermilionGiftsState(g))
        fn(g)
    end)
end
local function offer(g,id)
    assert(SourceEvents.dispatch(g,id));drain(g)
    eq(g.machine:get("event").phase,"service-choice")
end
function VermilionGiftsContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)
        local ok,err=pcall(fn)
        report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(err) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    local descriptors=VermilionGifts.descriptors()
    for id,d in pairs(descriptors) do
        if d.threshold then
            for _,n in ipairs({d.threshold-1,d.threshold}) do
                test(id.." owned threshold "..n.." ignores seen and duplicates",function()
                    local g=fresh();local s=g.session
                    local ids=owned(s,n)
                    assert(s:recruit(Pokemon(ids[1],5)))
                    local rng,world=RulesRNG.toData(),s:worldRngData()
                    local before=assert(SessionCodec.encode(s,gate))
                    local observation=VermilionGifts.observe(s)
                    eq(observation.owned,n)
                    local p=VermilionGifts.plan(id,observation,true)
                    same(observation,VermilionGifts.observe(s))
                    same(before,assert(SessionCodec.encode(s,gate)))
                    if n<d.threshold then
                        eq(p.status,"insufficient-owned");eq(p.expected,nil)
                        eq(p.ram.hOaksAideNumMonsOwned,n)
                    else
                        assert(VermilionGifts.commit(s,p))
                        eq(s:inventory():quantity(d.item),1)
                        eq(s:questFlag(d.flag),true)
                        eq(VermilionGifts.commit(s,p),false)
                        local restored=roundtrip(g)
                        eq(restored:inventory():quantity(d.item),1)
                        eq(plan(restored,id,true).status,"already-complete")
                    end
                    same(RulesRNG.toData(),rng);same(s:worldRngData(),world)
                end)
            end
        end
        test(id.." capacity retry, once, item and codec",function()
            local g=fresh();local s=g.session
            if d.threshold then owned(s,d.threshold) end
            local discard=full(s)
            local rng,world=RulesRNG.toData(),s:worldRngData()
            local p=plan(s,id,true)
            local before=assert(SessionCodec.encode(s,gate))
            local ok,reason=VermilionGifts.commit(s,p)
            eq(ok,false);eq(reason,"bag-full")
            same(before,assert(SessionCodec.encode(s,gate)))
            s=roundtrip(g);g.session=s
            assert(s:inventory():consume(discard,1))
            local retry=plan(s,id,true)
            assert(VermilionGifts.commit(s,retry))
            eq(s:inventory():quantity(d.item),1);eq(s:questFlag(d.flag),true)
            eq(VermilionGifts.commit(s,retry),false)
            local restored=roundtrip(g)
            eq(restored:inventory():quantity(d.item),1);eq(restored:questFlag(d.flag),true)
            eq(plan(restored,id,true).status,"already-complete")
            same(RulesRNG.toData(),rng);same(s:worldRngData(),world)
        end)
        test(id.." NO is pure and produces no transaction",function()
            local g=fresh();local s=g.session
            local before=assert(SessionCodec.encode(s,gate))
            local p=plan(s,id,false)
            eq(p.status,"declined");eq(p.expected,nil)
            same(before,assert(SessionCodec.encode(s,gate)))
        end)
        test(id.." stale item guard rejects atomically",function()
            local g=fresh();local s=g.session
            if d.threshold then owned(s,d.threshold) end
            local p=plan(s,id,true)
            assert(s:inventory():add(d.item,1))
            local before=assert(SessionCodec.encode(s,gate))
            eq(VermilionGifts.commit(s,p),false)
            same(before,assert(SessionCodec.encode(s,gate)))
        end)
    end
    test("aide rejects changed owned observation before commit",function()
        local g=fresh();local s=g.session
        local ids=owned(s,10)
        local id="pokered:ROUTE_2_GATE:objects:1"
        local p=plan(s,id,true)
        assert(s:recruit(Pokemon(ids[11],5)))
        local before=assert(SessionCodec.encode(s,gate))
        local ok,reason=VermilionGifts.commit(s,p)
        eq(ok,false);eq(reason,"stale-owned")
        same(before,assert(SessionCodec.encode(s,gate)))
    end)
    test("shared planner and text previews are detached and preserve all owners",function()
        local g=fresh();local s=g.session
        local id="pokered:POKEMON_FAN_CLUB:objects:5"
        local before=assert(SessionCodec.encode(s,gate))
        local rng=RulesRNG.toData()
        local observation=VermilionGifts.observe(s)
        for _=1,3 do
            local p=plan(s,id,true)
            local pointer=SourceEvents.plan(id,observation)
            eq(pointer.scene,"vermilion-gift")
            assert(#SourceEvents.pages(id,p.before,p.ram)>0)
            assert(#SourceEvents.pages(id,p.success,p.ram)>0)
            p.changes.items[1].id="potion"
            eq(plan(s,id,true).changes.items[1].id,"bikeVoucher")
        end
        same(before,assert(SessionCodec.encode(s,gate)));same(rng,RulesRNG.toData())
    end)
    test("flag capacity failure cannot publish item or receipt",function()
        local g=fresh();local s=g.session
        for i = 1, 4096 do
            assert(s:setQuestFlag("GIFT_CAPACITY:" .. i, false))
            SessionFixture.collectPreparationGarbage(i)
        end
        local p=plan(s,"pokered:POKEMON_FAN_CLUB:objects:5",true)
        local before=assert(SessionCodec.encode(s,gate))
        eq(VermilionGifts.commit(s,p),false)
        same(before,assert(SessionCodec.encode(s,gate)))
    end)
    local club="pokered:POKEMON_FAN_CLUB:objects:5"
    for _,item in ipairs({"bicycle","bikeVoucher"}) do
        test("chairman source bag condition "..item.." without completion flag",function()
            local g=fresh();assert(g.session:inventory():add(item,1))
            eq(plan(g.session,club,nil).status,"already-complete")
            eq(g.session:questFlag("EVENT_GOT_BIKE_VOUCHER"),false)
        end)
    end
    test("chairman source voucher flag outlasts handed-off item",function()
        local g=fresh();assert(g.session:setQuestFlag("EVENT_GOT_BIKE_VOUCHER",true))
        eq(plan(g.session,club,nil).status,"already-complete")
    end)
    for _,case in ipairs({
        {map="PokemonFanClub",id=club},
        {map="VermilionOldRodHouse",id="pokered:VERMILION_OLD_ROD_HOUSE:objects:1"},
        {map="Route2Gate",id="pokered:ROUTE_2_GATE:objects:1"},
        {map="Route11Gate2F",id="pokered:ROUTE_11_GATE_2F:objects:2"},
    }) do
        test(case.id.." replaced session rejects pre-choice dialog callback",function()
            scene(case.map,function(g)
                local original=g.session
                assert(SourceEvents.dispatch(g,case.id))
                eq(g.machine:getCurrent(),"dialog")
                local stale=g.machine:get("dialog").onComplete
                g.machine:pop()
                local replacement=fresh().session
                g.session=replacement
                local old=assert(SessionCodec.encode(original,gate))
                local new=assert(SessionCodec.encode(replacement,gate))
                stale()
                same(old,assert(SessionCodec.encode(original,gate)))
                same(new,assert(SessionCodec.encode(replacement,gate)))
                eq(g.machine:get("event").menu.isActive,false)
                g.machine:change("overworld")
            end)
        end)
        test(case.id.." native cancellation, stale epoch, full retry, receipt, revisit",function()
            scene(case.map,function(g)
                local s=g.session;local d=descriptors[case.id]
                if d.threshold then owned(s,d.threshold) end
                local rng,world=RulesRNG.toData(),s:worldRngData()
                offer(g,case.id)
                local event=g.machine:get("event")
                local beforeDraw=assert(SessionCodec.encode(s,gate))
                g.machine:draw()
                same(beforeDraw,assert(SessionCodec.encode(s,gate)))
                same(RulesRNG.toData(),rng)
                local stale=event.menu.onSelect
                g.machine:change("overworld")
                offer(g,case.id)
                stale(1);eq(s:inventory():quantity(d.item),0)
                event:handleButton("b");settle(g)
                eq(s:questFlag(d.flag),false)
                local discard=full(s)
                offer(g,case.id);event:handleButton("a");settle(g)
                eq(s:inventory():quantity(d.item),0);eq(s:questFlag(d.flag),false)
                assert(s:inventory():consume(discard,1))
                offer(g,case.id)
                local selected=event.menu.onSelect
                selected(1);selected(1);settle(g)
                eq(s:inventory():quantity(d.item),1);eq(s:questFlag(d.flag),true)
                assert(SourceEvents.dispatch(g,case.id));settle(g)
                eq(s:inventory():quantity(d.item),1)
                same(RulesRNG.toData(),rng);same(s:worldRngData(),world)
            end)
        end)
    end
    return report
end
