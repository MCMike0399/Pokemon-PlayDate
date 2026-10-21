RoostPredicateContracts={}
local function eq(a,b)assert(a==b,"expected "..tostring(b)..", got "..tostring(a))end
local function settle(b)local n=0;while b:phase()=="script"do n=n+1;assert(n<100);b.machine:get("script"):advance()end end
local function setup()local b=Battle(Pokemon("pidgey",42),Pokemon("squirtle",100));settle(b);b:setDirection("player");return b end
function RoostPredicateContracts.run()
 local report={ok=true,passed=0,failed=0,tests={}};local saved=RulesRNG.snapshot()
 local function test(name,fn)local ok,why=pcall(fn);report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(why)or nil};if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end end
 test("Nested Not and doubleNot preserve actual For Battle types",function()
  local b=setup();local absent=For(ATTACKER,Not(HasType("flying")));local present=For(ATTACKER,Not(Not(HasType("flying"))));eq(absent:check(b),false);eq(present:check(b),true)
  b.player.hp=1;b:runScript(function()b:setDirection("player");RoostEffect():apply(b)end);settle(b);eq(absent:check(b),true);eq(present:check(b),false);eq(Not(HasType("flying")):check(b.player),false)
 end)
 test("Nested AllOf AnyOf carry battle context and preserve intrinsic direct checks",function()
  local b=setup();local predicate=AllOf(HasType("normal"),Not(HasType("flying")),AnyOf(HasType("water"),Not(Not(HasType("normal")))));eq(For(ATTACKER,predicate):check(b),false)
  b.player.hp=1;b:runScript(function()b:setDirection("player");RoostEffect():apply(b)end);settle(b);eq(For(ATTACKER,predicate):check(b),true);eq(predicate:check(b.player),false)
  eq(For(ATTACKER,AnyOf(HasType("flying"),HasType("water"))):check(b),false);eq(For(DEFENDER,AnyOf(HasType("flying"),HasType("water"))):check(b),true)
 end)
 test("Existing Battle-level combinations around For and shortcircuit RNG stay unchanged",function()
  local b=setup();local before=RulesRNG.snapshot();eq(AllOf(For(ATTACKER,HasType("normal")),Not(For(DEFENDER,HasType("flying")))):check(b),true)
  eq(AnyOf(For(ATTACKER,HasType("flying")),Chance(100)):check(b),true);eq(AllOf(Never(),Chance(100)):check(b),false);eq(RulesRNG.snapshot().rolls,before.rolls);eq(RulesRNG.snapshot().state,before.state)
 end)
 test("Actual Roost expiry restores nested predicates without raw type mutation",function()
  local b=setup();b.player.hp=1;b:runScript(function()b:setDirection("player");RoostEffect():apply(b)end);settle(b);local pred=For(ATTACKER,Not(HasType("flying")));eq(pred:check(b),true)
  b:runScript(function()return b:finishRound()end);settle(b);eq(pred:check(b),false);eq(b.player.type,"normal");eq(b.player.type2,"flying")
 end)
 RulesRNG.restore(saved);return report
end
