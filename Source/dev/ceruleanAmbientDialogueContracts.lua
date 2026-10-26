-- Prepared real-SDK witness. Root registers/runs after its Source freeze.
-- Uses the existing native imported-map fixture, then the ordinary EventState.
import "dev/ceruleanSceneContracts"
CeruleanAmbientDialogueContracts = {}
local CITY <const> = "pokered:CERULEAN_CITY:objects:"
local function same(a,b)
    assert(type(a)==type(b),"type differs")
    if type(a)~="table" then assert(a==b,tostring(a).." ~= "..tostring(b));return end
    for k,v in pairs(b) do same(a[k],v) end
    for k in pairs(a) do assert(b[k]~=nil,"extra field: "..tostring(k)) end
end
local function seedByte(g,byte)
    -- 23 is the inverse of 16807 modulo 256. These small seeds never wrap
    -- the Park-Miller modulus or enter rejection sampling on the first draw.
    local seed=((byte+1)*23)%256
    if seed==0 then seed=256 end
    g.session:_installWorldMotion({version=1,rng=RulesRNG.new(seed):toData(),actors=g.session:actorData()})
    return seed
end
local function drain(g)
    for _=1,256 do
        if g.machine:getCurrent()~="dialog" then
            assert(g.machine:getCurrent()=="overworld","dialog did not return to exploration")
            return
        end
        local state=g.machine:get("dialog")
        state.dialog:advance();state:handleInput()
    end
    error("bounded real dialog did not settle")
end
local function scene(fn)
    CeruleanSceneContracts.withScene("CeruleanCity",{x=29,y=27,facing="up"},function(g)
        g.machine:register("event",EventState(g))
        fn(g,g.machine:get("event"))
    end)
end
local function npcFor(g,id)
    for _,npc in ipairs(g.npcManager.npcs) do
        if npc.def and npc.def.source_event_id==id then return npc end
    end
    error("actual source actor missing")
end
function CeruleanAmbientDialogueContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)
        local ok,problem=pcall(fn)
        report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(problem) or nil}
        if ok then report.passed=report.passed+1 else report.ok=false;report.failed=report.failed+1 end
    end
    local function label(index,byte)
        if index==7 then
            return "_CeruleanCityCooltrainerF1"..(byte>=180 and "SlowbroUseSonicboomText"
                or byte>=100 and "SlowbroPunchText" or "SlowbroWithdrawText")
        end
        return "_CeruleanCitySlowbro"..(byte>=180 and "TookASnoozeText"
            or byte>=120 and "IsLoafingAroundText" or byte>=60 and "TurnedAwayText" or "IgnoredOrdersText")
    end
    for _,index in ipairs({7,8}) do
        for _,byte in ipairs({0,59,60,99,100,119,120,179,180,255}) do
            test("actual ambient interaction "..index.." byte boundary "..byte,function()
                scene(function(g,event)
                    local id=CITY..index
                    local npc=npcFor(g,id)
                    local originalFacing=g.npcManager.motion:actor(npc).facing
                    g.player.gridX,g.player.gridY=npc.gridX,npc.gridY+1
                    local seed=seedByte(g,byte)
                    local world,rules,flags=g.session:worldRngData(),RulesRNG.toData(),g.session:flags()
                    local inventory=g.session:inventory():toData()
                    for _=1,3 do
                        local observation=EventState.observe(g,id)
                        local untouched=GameSession._copy(observation)
                        local d=SourceEvents.descriptor(id)
                        local plan=SourceEvents.plan(id,observation)
                        same(SourceEvents.compile(d,observation,id),plan)
                        same(observation,untouched)
                        local detached=plan.steps[1].choices[1].labels
                        detached[1]="_Invalid"
                        assert(SourceEvents.plan(id,observation).steps[1].choices[1].labels[1]~="_Invalid")
                        SourceEvents.pages(id,{label(index,byte)})
                        event:getSnapshot();g.npcManager.motion:snapshot()
                    end
                    same(g.session:worldRngData(),world);same(RulesRNG.toData(),rules)
                    assert(SourceActors.interact(g,npc,id))
                    assert(g.machine:getCurrent()=="dialog")
                    same(event.waiting,label(index,byte))
                    same(g.session:worldRngData().state,tostring(16807*seed))
                    same(g.session:worldRngData().rolls,"1")
                    local selected=g.session:worldRngData()
                    for _=1,3 do
                        EventState.observe(g,id);event:getSnapshot();event:draw()
                    end
                    same(g.session:worldRngData(),selected)
                    local stale=g.machine:get("dialog").onComplete
                    drain(g)
                    same(npc.facing,originalFacing)
                    local pose=npc.facing
                    stale();event:advance()
                    same(npc.facing,pose)
                    same(g.session:worldRngData(),selected);same(RulesRNG.toData(),rules)
                    same(g.session:flags(),flags);same(g.session:inventory():toData(),inventory)
                end)
            end)
        end
    end
    test("cancelled ambient interaction restores its tracked facing without another draw",function()
        scene(function(g)
            local npc=npcFor(g,CITY..7)
            local original=g.npcManager.motion:actor(npc).facing
            seedByte(g,180)
            assert(SourceActors.interact(g,npc,CITY..7))
            assert(npc.facing~=original,"fixture must turn the actual STAY actor")
            local callback=g.machine:get("dialog").onComplete
            local before,rules=g.session:worldRngData(),RulesRNG.toData()
            g.machine:change("overworld")
            same(npc.facing,original)
            callback()
            same(npc.facing,original)
            same(g.session:worldRngData(),before);same(RulesRNG.toData(),rules)
        end)
    end)
    test("one world-byte request retains the owner's rejection sampling count",function()
        scene(function(g,event)
            -- First Park-Miller value 2147483646 exceeds the unbiased byte
            -- limit; the accepted second value 2147466840 yields byte 87.
            g.session:_installWorldMotion({version=1,rng=RulesRNG.new(739806647):toData(),actors=g.session:actorData()})
            local rules=RulesRNG.toData()
            SourceEvents.dispatch(g,CITY..8)
            same(event.waiting,label(8,87))
            same(g.session:worldRngData().rolls,"2")
            same(g.session:worldRngData().state,"2147466840")
            drain(g);same(RulesRNG.toData(),rules)
        end)
    end)
    test("operation draws only after preceding real dialog completes; cancellation draws zero",function()
        SourceEvents._withSources(function()
            local id=CITY..99
            local descriptor=SourceEvents.descriptor(CITY..7)
            descriptor.content="ambient-contract"
            table.insert(descriptor.steps,1,{op="dialog",labels={"_CeruleanCityGuardText"}})
            SourceEvents.registerEventSource("ambient-contract",{[id]=descriptor})
            SourceEvents.registerTextSource("ambient-contract",CeruleanContent.text)
            scene(function(g,event)
                seedByte(g,180)
                local before,rules=g.session:worldRngData(),RulesRNG.toData()
                SourceEvents.dispatch(g,id)
                same(g.session:worldRngData(),before)
                local stale=g.machine:get("dialog").onComplete
                g.machine:change("overworld");stale()
                same(g.session:worldRngData(),before)
                SourceEvents.dispatch(g,id)
                local first=g.machine:get("dialog")
                for _=1,128 do
                    if event.waiting~="_CeruleanCityGuardText" then break end
                    first.dialog:advance();first:handleInput()
                end
                same(event.waiting,label(7,180))
                same(g.session:worldRngData().rolls,"1")
                drain(g);same(RulesRNG.toData(),rules)
            end)
        end)
    end)
    for _,replacement in ipairs({"session","player","zone","cancel"}) do
        test("stale ambient dialog callback after "..replacement.." cannot advance/draw",function()
            scene(function(g,event)
                seedByte(g,100);SourceEvents.dispatch(g,CITY..7)
                local callback=g.machine:get("dialog").onComplete
                local session,player,zone=g.session,g.player,currentZone
                local before,rules=session:worldRngData(),RulesRNG.toData()
                if replacement=="session" then g.session=GameContext().session
                elseif replacement=="player" then g.player=nil
                elseif replacement=="zone" then currentZone=nil
                else g.machine:change("overworld") end
                callback();event:advance()
                same(session:worldRngData(),before);same(RulesRNG.toData(),rules)
                g.session,g.player,currentZone=session,player,zone
                g.machine:change("overworld")
            end)
        end)
    end
    test("random dialog rejects empty, sparse, overlapping, incomplete and excessive partitions",function()
        local good=SourceEvents.descriptor(CITY..8).steps[1]
        local invalid={
            {op="random-dialog",choices={}},
            {op="random-dialog",choices={[2]=good.choices[2]}},
        }
        for _,change in ipairs({"gap","overlap","end","fraction","labels","many"}) do
            local step=GameSession._copy(good)
            if change=="gap" then step.choices[2].min=61
            elseif change=="overlap" then step.choices[2].min=59
            elseif change=="end" then step.choices[#step.choices].max=254
            elseif change=="fraction" then step.choices[1].max=59.5
            elseif change=="labels" then step.choices[1].labels={}
            else for _=1,17 do step.choices[#step.choices+1]=step.choices[1] end end
            invalid[#invalid+1]=step
        end
        SourceEvents.validateStep(good)
        for _,step in ipairs(invalid) do assert(not pcall(SourceEvents.validateStep,step)) end
    end)
    return report
end
