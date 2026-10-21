-- Additional semantic witness: a missing checkpoint must fail an explicit
-- invariant, independently of the older nil-receipt dereference.
WeatherRewardWitness={}
function WeatherRewardWitness.run()
    local rng=RulesRNG.snapshot();local b
    local ok,why=pcall(function()
        local p,q,e,z=Pokemon("squirtle",6),Pokemon("charmander",5),Pokemon("pidgey",6),Pokemon("rattata",5)
        p.xp=p:xpForLevel(7)-1
        local party,foes=Party(),Party();assert(party:add(p));assert(party:add(q));assert(foes:add(e));assert(foes:add(z))
        for _,mon in ipairs({p,q,e,z})do mon.moves={"growl"};mon.pp={growl=moveData.growl.maxPP};assert(PokemonCodec.encode(mon))end
        b=Battle(p,e,"WEATHER CHECKPOINT",{party=party,enemyParty=foes})
        local function settle()
            local steps=0
            while b:phase()=="script"do
                steps=steps+1;assert(steps<100,"weather witness script must settle")
                assert(not b:getLearningSnapshot().pending,"dead recipients must not learn")
                assert(b.machine:get("script"):advance())
            end
        end
        settle();p.hp,e.hp=1,1;local xp=p.xp
        b:runScript(function()assert(b.effects:setSandstorm())end);settle()
        b:runScript(function()return b:finishRound()end);settle()
        local rewards=b:getRewardSnapshot()
        assert(rewards.awards==1,"whole weather cohort must commit one reward checkpoint even with zero eligible recipients")
        assert(rewards.latest~=nil,"weather checkpoint must publish its receipt")
        assert(rewards.latest.eligible==0 and #rewards.latest.rows==0,"sand-fainted recipients must be ineligible")
        assert(p.hp==0 and e.hp==0 and p.xp==xp,"weather cannot revive or award a fainted active")
        for _,value in pairs(p.evs)do assert(value==0,"weather cannot grant dead active EVs")end
        assert(b:phase()=="forcedSwitch" and b.enemy==z,"weather checkpoint precedes actual replacement")
    end)
    if b then b:clearVolatiles()end;RulesRNG.restore(rng)
    return {ok=ok,passed=ok and 1 or 0,failed=ok and 0 or 1,tests={{name="whole weather cohort commits exactly once with an explicit empty-recipient receipt",ok=ok,error=not ok and tostring(why)or nil}}}
end
