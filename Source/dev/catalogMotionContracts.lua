CatalogMotionContracts={}
local function rejected(fn)
    local ok,problem=pcall(fn);assert(not ok,"world motion mutation must reject")
    local message=tostring(problem)
    assert(message:find("catalog exporter side effect",1,true),message)
    assert(message:find("supported live state restored",1,true),message)
    assert(not message:find("unrestored/unsupported",1,true),message)
end
function CatalogMotionContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)
        local ok,problem=pcall(fn);report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(problem)or nil}
        if ok then report.passed=report.passed+1 else report.ok=false;report.failed=report.failed+1 end
    end
    test("Actual worldRandom mutation rejects and restores exact independent stream without rules draws",function()
        local before=CatalogRuntime.snapshot();local session=game.session
        local world=session:worldRngData();local rules=RulesRNG.toData();local captured=session:actorData()
        rejected(function()CatalogRuntime.guard(function()
            session:worldRandom(0,255)
            assert(not CatalogRuntime.same(world,session:worldRngData()),"controlled draw failed to advance independent stream")
            return true
        end)end)
        assert(CatalogRuntime.same(world,session:worldRngData()),"world continuation not restored")
        assert(CatalogRuntime.same(captured,session:actorData()),"captured actor values changed")
        assert(CatalogRuntime.same(rules,RulesRNG.toData()),"rules stream changed")
        assert(CatalogRuntime.same(before,CatalogRuntime.snapshot()),"supported world stream mutation leaked")
    end)
    test("Captured source actor DTO is observed defensively and restored through session owner",function()
        local original=CatalogRuntime.snapshot();local previous=game.session
        local ok,problem=pcall(function()
            local world=WorldDeltas.export();local location={zone_id="pokered:PEWTER_MART",x=5,y=6,facing="up"}
            local session=GameSession.newSession(game:getSessionDependencies(),{location=location,world=world,checkpoint=previous:checkpoint(),seed=42})
            local descriptor=assert(SourceActors.describe(location.zone_id,world))
            local actors=WorldMotionData.reconcile(nil,descriptor,session:flags())
            session:_installWorldMotion({version=1,rng=session:worldRngData(),actors=actors})
            game.session=session
            local before=CatalogRuntime.snapshot();local changed=Party._primitive(actors);local chosen
            for _,value in ipairs(changed.actors)do
                for _,spec in ipairs(descriptor.actors)do if spec.id==value.id and spec.random then chosen=value;break end end
                if chosen then break end
            end
            assert(chosen,"real source random actor fixture required")
            chosen.phase="delay";chosen.delay_raw=1;chosen.delay_left=WorldMotionData.delay(1)
            rejected(function()CatalogRuntime.guard(function()
                session:_installWorldMotion({version=1,rng=session:worldRngData(),actors=changed})
                assert(not CatalogRuntime.same(actors,session:actorData()),"actor DTO mutation fixture ineffective")
                return true
            end)end)
            assert(CatalogRuntime.same(actors,session:actorData()),"captured actor DTO was not restored")
            assert(CatalogRuntime.same(before,CatalogRuntime.snapshot()),"captured source values leaked")
        end)
        game.session=previous
        assert(CatalogRuntime.same(original,CatalogRuntime.snapshot()),"detached actor fixture leaked into live scene")
        assert(ok,problem)
    end)
    return report
end
