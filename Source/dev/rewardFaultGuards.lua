-- Qualification-only observation at the actual faint narration yield.
RewardFaultGuards={}
function RewardFaultGuards.run()
 local rng=RulesRNG.snapshot();local battle
 local ok,why=pcall(function()
  local p,q,e,z=Pokemon("squirtle",50),Pokemon("charmander",5),Pokemon("pidgey",50),Pokemon("rattata",5)
  local party,foes=Party(),Party();assert(party:add(p));assert(party:add(q));assert(foes:add(e));assert(foes:add(z))
  for _,mon in ipairs({p,q,e,z})do mon.moves={"growl"};mon.pp={growl=moveData.growl.maxPP};assert(PokemonCodec.encode(mon))end
  battle=Battle(p,e,"FAULT GUARD",{party=party,enemyParty=foes})
  local function settle()local n=0;while battle:phase()=="script"do n=n+1;assert(n<100);assert(battle.machine:get("script"):advance())end end
  settle();battle:runScript(function()assert(battle.effects:worrySeed(p,e))end);settle()
  assert(battle.effects.abilityOverrides[e]==15)
  battle.conditions:of(e).focusEnergy=true;battle.conditions:of(p).trap={source=e,remaining=3}
  e.hp=1;e.status="poison";for _,mon in ipairs({p,q,e,z})do assert(PokemonCodec.encode(mon))end
  local xp=p.xp;local before=RulesRNG.snapshot()
  battle:runScript(function()return battle:finishRound()end)
  local n=0;while battle.message~=e.name.." fainted!"do n=n+1;assert(n<100,"missing faint announcement");assert(battle:phase()=="script");assert(battle.machine:get("script"):advance())end
  assert(battle.conditions.members[e]==nil,"dead member conditions must clear BEFORE faint narration")
  assert(battle.conditions.members[p]and battle.conditions.members[p].trap==nil,"source-owned trap must clear BEFORE faint narration")
  assert(battle.effects.abilityOverrides[e]==nil,"ability override must clear BEFORE faint narration")
  assert(battle.faintAnnounced.enemy==true);assert(battle.awardedEnemies[e]==nil,"reward precedes stage checkpoint")
  assert(p.xp==xp);for _,value in pairs(p.evs)do assert(value==0)end
 end)
 if battle then battle:clearVolatiles()end;RulesRNG.restore(rng)
 return {ok=ok,passed=ok and 1 or 0,failed=ok and 0 or 1,tests={{name="immediate faint cleanup precedes announcement without awarding before condition checkpoint",ok=ok,error=not ok and tostring(why)or nil}}}
end
