-- Integrated public observations must describe the production dispatch path.
BrockIntegrationContracts={}
function BrockIntegrationContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}};local prior=RulesRNG.snapshot()
    local ok,why=pcall(function()
        local p,e=Pokemon("pikachu",18),Pokemon("pidgey",100);local b=Battle(p,e)
        local function settle()
            local n=0;while b:phase()=="script"do n=n+1;assert(n<20);b.machine:get("script"):advance()end
        end
        settle();b:runScript(function()b:setDirection("player");MudSportEffect():apply(b)end);settle()
        local before=RulesRNG.snapshot();local count=0;for _ in pairs(b.conditions.members)do count=count+1 end
        assert(b:effectiveMovePower(moveData.thunderWave,p,e)==0,"status cannot advertise damaging power under Mud Sport")
        assert(b:effectiveMovePower(moveData.sonicBoom,p,e)==0,"fixed damage cannot advertise ordinary power")
        assert(b:effectiveMovePower(moveData.electroBall,p,e)==13,"real variable electric power keeps Mud Sport")
        local after=RulesRNG.snapshot();assert(before.rolls==after.rolls and before.state==after.state,"observation consumed RNG")
        local last=0;for _ in pairs(b.conditions.members)do last=last+1 end;assert(last==count,"observation allocated condition state")
        b:clearVolatiles()
    end)
    RulesRNG.restore(prior);report.tests[1]={name="Pure integrated power observer excludes status/fixed moves and retains variable power",ok=ok,error=not ok and tostring(why)or nil}
    if ok then report.passed=1 else report.failed=1;report.ok=false end
    return report
end
