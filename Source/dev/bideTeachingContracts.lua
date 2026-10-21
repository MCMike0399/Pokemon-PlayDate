-- Required separate owner qualification with the real Teaching/session append.
BideTeachingContracts={}
function BideTeachingContracts.run()
    local saved=RulesRNG.snapshot();local prior=GameSession.activeRNGSession();local g
    local report={ok=true,passed=0,failed=0,tests={}}
    local ok,why=pcall(function()
        assert(Teaching and GameSession.resolveTeaching,"actual Teaching + session owner required")
        g=GameContext();local p=Pokemon("squirtle",100);assert(g:recruit(p));assert(g.session:setIntro({stage="done",starter="squirtle",rivalStarter="bulbasaur",rivalOutcome=true}))
        local bag=g.session:inventory();assert(bag:add("tm34",1));local old=p.moves[1];p.pp[old]=4
        local before=RulesRNG.snapshot();local request=assert(Teaching.prepare(g.session,p,"tm34"));local taught,result=Teaching.complete(request,"learn",1);assert(taught,result)
        assert(result.consumed and bag:quantity("tm34")==0,"TM34 consumed exactly once")
        assert(g.session:party():active()==p and g.session:inventory()==bag,"same owned/bag identities")
        assert(p.moves[1]=="bide" and p.pp.bide==4 and p.pp[old]==nil,"actual teaching slot/PP policy")
        assert(RulesRNG.snapshot().state==before.state and RulesRNG.snapshot().rolls==before.rolls,"teaching noRNG")
        local e=Pokemon("rattata",100);e.moves={"dragonRage"};e.pp={dragonRage=10}
        local b=Battle(p,e,nil,{party=g.session:party(),session=g.session})
        local function settle()
            local n=0;while b:phase()=="script"do n=n+1;assert(n<200);assert(not b.pendingLearning);b.machine:get("script"):advance()end
        end
        settle();RulesRNG.seed(2);assert(b:selectMove(1));settle();assert(p.pp.bide==3 and b:getConditionsSnapshot().player.bide_damage==40)
        b:update();settle();assert(p.pp.bide==3 and b:getConditionsSnapshot().player.bide_damage==80)
        b:update();settle();assert(e.hp==10 and p.pp.bide==3 and b.conditions:lockedKey(p)==nil,"actual taught Bide releases160 exactly once")
        assert(Teaching.complete(request,"learn",1)==false,"teaching receipt once")
        b:clearVolatiles()
    end)
    if g then g.session:deactivateRNG()end
    if prior then assert(prior:activateRNG())end
    RulesRNG.restore(saved);report.ok=ok;report.passed=ok and 1 or 0;report.failed=ok and 0 or 1
    report.tests[1]={name="Real Blue TM34 teaching preserves owners/PP then real Bide stores/releases",ok=ok,error=not ok and tostring(why)or nil};return report
end
