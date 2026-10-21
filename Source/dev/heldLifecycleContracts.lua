HeldLifecycleContracts={}
local function eq(a,b)assert(a==b,"expected "..tostring(b)..", got "..tostring(a))end
local function setup()
    local g=GameContext();local p=Pokemon("charmander",12);assert(g:recruit(p));assert(g.session:setIntro({stage="done",starter="charmander",rivalStarter="squirtle"}));assert(g.session:inventory():add("potion",2))
    g.machine:register("base",State("base"));local party=PartyState(g);local bag=BagState(g);g.machine:register("party",party);g.machine:register("bag",bag);g.machine:change("base");g.machine:push("party")
    party:actions();party.menu.onSelect(3);party.menu.onSelect(1);eq(g.machine:getCurrent(),"bag");return g,p,party,bag
end
function HeldLifecycleContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)local ok,why=pcall(fn);report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(why)or nil};if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end end
    test("Forced held-Bag pop recovers Parent menu without mutating either item owner",function()
        local g,p,party,bag=setup();local before=RulesRNG.snapshot();local select=bag.options.trySelect
        g.machine:pop();eq(party.phase,"held-wait");g.machine:update();eq(party.phase,"held-actions");eq(g.machine:getCurrent(),"party")
        eq(p.heldItem,"none");eq(g.session:inventory():quantity("potion"),2);eq(select("potion"),false);eq(RulesRNG.snapshot().state,before.state);eq(RulesRNG.snapshot().rolls,before.rolls)
    end)
    test("Forced pop cannot accept forged completion and actual success still reports once",function()
        local g,p,party,bag=setup();local completion=bag.options.onComplete;g.machine:pop()
        eq(completion({partyIndex=1,heldItem="potion"}),false);eq(p.heldItem,"none");eq(party.phase,"held-wait")
        g.machine:update();party.menu.onSelect(1);local actual=bag.options.onComplete;assert(bag:selectHeld("potion"));eq(party.phase,"held-message");eq(p.heldItem,"potion");eq(g.session:inventory():quantity("potion"),1)
        eq(actual(bag.heldReceipt),false);eq(g.session:inventory():quantity("potion"),1)
    end)
    return report
end
