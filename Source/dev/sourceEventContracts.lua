-- Root executes these in the real SDK alongside existing event/trainer suites.
import "dev/sourceEventBaseline"
SourceEventContracts = {}
local function same(actual, expected, path)
    path = path or "plan"
    assert(type(actual) == type(expected), path .. ": type changed")
    if type(actual) ~= "table" then
        assert(actual == expected, path .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
        return
    end
    for key, value in pairs(expected) do same(actual[key],value,path .. "." .. tostring(key)) end
    for key in pairs(actual) do assert(expected[key] ~= nil,path .. ": extra field " .. tostring(key)) end
end
local function observation()
    local state = {intro="done",flags={},items={},can_add={},trainers={},mode="talk"}
    for _, id in ipairs(SourceEvents.itemIDs()) do state.items[id],state.can_add[id] = 0,true end
    return state
end
function SourceEventContracts.run()
    local report = {ok=true,passed=0,failed=0,tests={}}
    local function test(name, fn)
        local ok, problem = pcall(fn)
        report.tests[#report.tests + 1] = {name=name,ok=ok,error=not ok and tostring(problem) or nil}
        if ok then report.passed = report.passed + 1
        else report.failed = report.failed + 1; report.ok = false end
    end
    local data = assert(json.decodeFile("data/sourceEvents.json"))
    -- Compare every field, including omitted versus empty fields. Exercise
    -- success/full/repeat, parcel state combinations, sight/talk and receipts.
    for id, descriptor in pairs(data.events) do
        test("1339333 source plan parity: " .. id,function()
            local baseline = descriptor.content == "pewter" and SourceEventBaselinePewter or SourceEventBaselineSlice
            assert(baseline.has(id))
            local flags = {"EVENT_GOT_POTION_SAMPLE","EVENT_GOT_OAKS_PARCEL","EVENT_OAK_GOT_PARCEL","EVENT_GOT_POKEDEX","EVENT_GOT_TM34"}
            if descriptor.kind == "pickup" then flags[#flags + 1] = descriptor.flag end
            for bits=0,(1 << #flags)-1 do
                for variant=0,15 do
                    local state = observation()
                    for index, flag in ipairs(flags) do state.flags[flag] = (bits & (1 << (index-1))) ~= 0 end
                    for item in pairs(state.items) do
                        state.items[item] = variant & 1
                        state.can_add[item] = (variant & 2) ~= 0
                    end
                    state.trainers[id] = (variant & 4) ~= 0
                    if (variant & 8) ~= 0 then state.receipt = {id=id,won=true,payout=1386} end
                    state.mode = variant % 2 == 0 and "talk" or "sight"
                    local untouched = GameSession._copy(state)
                    local oldOK, oldPlan = pcall(baseline.plan,id,state)
                    local newOK, newPlan = pcall(SourceEvents.plan,id,state)
                    same(newOK,oldOK,id .. ": rejection")
                    if oldOK then same(newPlan,oldPlan,id) end
                    same(state,untouched,"observation")
                end
            end
        end)
    end
    test("descriptor and returned plans cannot mutate shared source data",function()
        local id = "pokered:ROUTE_1:objects:2"
        local descriptor = SourceEvents.descriptor(id)
        descriptor.steps[1].labels[1] = "_Invalid"
        local plan = SourceEvents.plan(id,observation())
        same(plan.steps[1].labels[1],"_Route1Youngster2Text")
        plan.steps[1].labels[1] = "_Invalid"
        same(SourceEvents.plan(id,observation()).steps[1].labels[1],"_Route1Youngster2Text")
    end)
    test("reusable program compiles item and flag operations into one guarded commit",function()
        local state = observation()
        state.items.potion = 3
        local descriptor = {kind="program",steps={
            {op="dialog",labels={"_Route1Youngster1MartSampleText"}},
            {op="give-item",id="potion",quantity=2},
            {op="set-flag",id="EVENT_PROGRAM_CONTRACT",value=true},
            {op="receipt",labels={"_Route1Youngster1GotPotionText"}},
            {op="warp",to="reds_house_2f",toX=5,toY=3,facing="down"},
        }}
        local untouched = GameSession._copy(state)
        local plan = SourceEvents.compile(descriptor,state,"contract:program")
        same(plan.expected,{flags={EVENT_PROGRAM_CONTRACT=false},items={potion=3}})
        same(plan.changes,{flags={EVENT_PROGRAM_CONTRACT=true},items={{op="add",id="potion",quantity=2}}})
        same(#plan.steps,3)
        same(plan.steps[3].op,"warp")
        same(state,untouched)
    end)
    test("bounded operations reject malformed movement, grants and nonterminal warps",function()
        for _, step in ipairs({{op="move-npc",id="contract:actor",direction="up",count=9},
            {op="give-item",id="potion",quantity=0},{op="set-flag",id="flag",value=1},
            {op="warp",to="room",toX=-1,toY=0,facing="up"},{op="unknown"}}) do
            same(pcall(SourceEvents.validateStep,step),false)
        end
        same(pcall(SourceEvents.compile,{kind="program",steps={
            {op="warp",to="room",toX=1,toY=1,facing="up"},
            {op="dialog",labels={"_Route1SignText"}},
        }},observation(),"contract:warp"),false)
        local state = observation(); state.intro = "choose"
        same(pcall(SourceEvents.plan,"pokered:ROUTE_1:objects:2",state),false)
    end)
    test("new source signs use the shared registry and retain detached programs", function()
        -- Synthetic metadata isolates registration semantics from installed
        -- campaign signs, whose stable IDs must never be replaced.
        local sign = {id="pokered:CONTRACT_SIGN:background_events:1"}
        SourceEvents._withSources(function()
            local name = "source-sign-contract"
            local descriptor = {kind="program", content=name,
                steps={{op="dialog", labels={"_Route1SignText"}}}}
            SourceEvents.registerEventSource(name, {[sign.id]=descriptor})
            descriptor.steps[1].labels[1] = "_ChangedAfterRegistration"
            local plan = SourceEvents.plan(sign.id, observation())
            same(plan.id, sign.id)
            same(plan.source_content, name)
            same(plan.steps[1].labels, {"_Route1SignText"})
            same(pcall(SourceEvents.registerEventSource, "duplicate-sign-contract",
                {[sign.id]={kind="program", content="duplicate-sign-contract", steps={}}}), false)
            same(pcall(SourceEvents.registerEventSource, "invalid-sign-contract",
                {["pokered:ROUTE_22:unknown:1"]={kind="program", content="invalid-sign-contract", steps={}}}), false)
        end)
        same(SourceEvents.has(sign.id), false)
    end)
    test("shared trainer reward transaction retains exact compatibility shape",function()
        local state = observation()
        local id = "pokered:PEWTER_GYM:objects:1"
        state.trainers[id] = true
        same(SourceEvents.rewardPlan(id,state),{expected={flags={EVENT_GOT_TM34=false},items={tm34=0},trainers={[id]=true}},
            changes={flags={EVENT_GOT_TM34=true},items={{op="add",id="tm34",quantity=1}},trainers={}}})
        state.flags.EVENT_GOT_TM34 = true
        same(SourceEvents.rewardPlan(id,state),nil)
    end)
    return report
end
