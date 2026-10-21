-- Mandatory composed dependency proof; never skip when OwnTempo isn't installed.
ChargeOwnTempoContracts={}
function ChargeOwnTempoContracts.run()
 local saved=RulesRNG.snapshot();local ok,why=pcall(function()
  local p=Pokemon("slowpoke",100,{natureId=0,abilitySlot="second",heldItem="none"});assert(p:ability()==20)
  local e=Pokemon("snorlax",100);p.moves={"petalDance"};p.pp={petalDance=10};e.moves={"harden"};e.pp={harden=30}
  local b=Battle(p,e);local function settle()local n=0;while b:phase()=="script"do n=n+1;assert(n<100);b.machine:get("script"):advance()end end;settle()
  RulesRNG.seed(2);assert(b:selectMove(1));settle();assert(b.conditions:lockedKey(p)=="petalDance")
  -- End a real installed rampage through its sourced fatigue effect. The pure
  -- predicate and DSL guard must both be present; no fixture writes confusion.
  assert(b.effects:statusImmunity(p,"confuse")=="Own Tempo");local before=RulesRNG.snapshot()
  b:runScript(function()b.conditions:endRampage(p,true)end);settle()
  assert(p.confusion==nil,"Own Tempo must prevent fatigue");assert(b.conditions:lockedKey(p)==nil)
  local after=RulesRNG.snapshot();assert(after.state==before.state and after.rolls==before.rolls,"immune fatigue must not sample duration")
 end);RulesRNG.restore(saved)
 return {ok=ok,passed=ok and 1 or 0,failed=ok and 0 or 1,tests={{name="Actual rampage fatigue uses composed OwnTempo20 before duration RNG",ok=ok,error=not ok and tostring(why)or nil}}}
end
