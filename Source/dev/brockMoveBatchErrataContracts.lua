BrockMoveBatchErrataContracts={}
function BrockMoveBatchErrataContracts.run()
    local saved=RulesRNG.snapshot();local report={ok=true,passed=0,failed=0,tests={}}
    local ok,why=pcall(function()
        local p,e=Pokemon("pikachu",100),Pokemon("rattata",100)
        local before=RulesRNG.snapshot()
        for _,power in ipairs({0,-1})do
            local result=calcDamage(p,e,moveData.dragonRage,power)
            assert(result.damage==0,"fixed explicit nonpositive effective power expected0, got "..tostring(result.damage))
            assert(not result.isCrit,"fixed power must not sample critical")
        end
        assert(RulesRNG.snapshot().state==before.state and RulesRNG.snapshot().rolls==before.rolls,"fixed nonpositive must not draw")
        RulesRNG.seed(2)
        local result=calcDamage(p,e,moveData.electroBall,40)
        -- Direct calculator starts at crit, then variance: seed2 crit14/16,
        -- variance86%, base49 thenSTAB →63. This is positive effective power.
        assert(result.damage==63,"variable effective40 expected63, got "..tostring(result.damage))
        assert(RulesRNG.snapshot().rolls==2,"variable positive needs crit+variance")
    end)
    report.ok=ok;report.passed=ok and 1 or 0;report.failed=ok and 0 or 1
    report.tests[1]={name="Explicit nonpositive fixed power stays0/inert while positive Electro power executes",ok=ok,error=not ok and tostring(why)or nil}
    RulesRNG.restore(saved);return report
end
