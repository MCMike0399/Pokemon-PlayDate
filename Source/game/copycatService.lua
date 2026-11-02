-- Copycat plans use the existing SourceEvents/EventState transaction executor.
-- Only the PC's facing-dependent text needs the existing controller delegate.
CopycatService = {}
local CONTENT <const> = "copycatService"
local REVISION <const> = "af519899719f0754965776faac0e836a3b906e6d"
local cached

function CopycatService.policy()
    if not cached then
        cached = assert(json.decodeFile("data/copycatService/service.json"))
        assert(cached.schema == 1 and cached.source_revision == REVISION,
            "unverified Copycat service")
    end
    return GameSession._copy(cached)
end

function CopycatService.text(label)
    return assert(CopycatService.policy().texts[label], "missing Copycat source text")
end

function CopycatService.descriptors()
    local policy = CopycatService.policy()
    return {
        [policy.copycat] = {
            kind = "bespoke", content = CONTENT, full = {policy.labels.full},
            observed_items = {{item = policy.payment}, {item = policy.reward}},
        },
        [policy.pc] = {kind = "bespoke", content = CONTENT},
    }
end

function CopycatService.plan(id, observation)
    local policy = CopycatService.policy()
    if id == policy.pc then
        return {status = "ready", scene = "copycat-pc", steps = {}}
    end
    assert(id == policy.copycat, "unknown Copycat service")
    local labels = policy.labels
    if observation.flags[policy.flag] then
        return {status = "already-complete", steps = {{op = "dialog", labels = {labels.completed}}}}
    end
    local plan = {status = "no-doll", steps = {{op = "dialog", labels = {labels.before}}}}
    local dolls = observation.items[policy.payment]
    local machines = observation.items[policy.reward]
    assert(Party._integer(dolls, 0, Inventory.CAPACITY * Inventory.STACK_LIMIT)
        and Party._integer(machines, 0, Inventory.CAPACITY * Inventory.STACK_LIMIT),
        "explicit Copycat inventory observation required")
    if dolls == 0 then
        return plan
    end
    plan.steps[#plan.steps + 1] = {op = "dialog", labels = {labels.offer}}
    if observation.can_add[policy.reward] ~= true then
        plan.status, plan.retry = "bag-full", true
        plan.steps[#plan.steps + 1] = {op = "dialog", labels = {labels.full}}
        return plan
    end
    plan.status = "ready"
    plan.expected = {flags = {[policy.flag] = false}, items = {
        [policy.payment] = dolls, [policy.reward] = machines,
    }}
    -- GiveItem precedes RemoveItemByID in Blue. Adding first on the detached
    -- bag preserves its capacity failure even when the last Doll frees a slot.
    plan.changes = {flags = {[policy.flag] = true}, items = {
        {op = "add", id = policy.reward, quantity = 1},
        {op = "take", id = policy.payment, quantity = 1},
    }}
    plan.ram = {wStringBuffer = assert(ItemData.definitions[policy.reward]).name}
    plan.failure_labels = {labels.full}
    plan.steps[#plan.steps + 1] = {op = "receipt", labels = {labels.received, labels.explanation}}
    return plan
end

function CopycatService.pcLabel(facing)
    assert(facing == "up" or facing == "down" or facing == "left" or facing == "right",
        "bounded Copycat PC facing required")
    local labels = CopycatService.policy().labels
    return facing == "up" and labels.pc_up or labels.pc_other
end

function CopycatService.advance(state)
    if not state.plan or state.plan.scene ~= "copycat-pc" then
        return false
    end
    if not state:valid() or not state:isTop() then
        return true
    end
    state:source({CopycatService.pcLabel(state.player.facing)}, function()
        state:finish()
    end)
    return true
end

function CopycatService.install()
    local events = CopycatService.descriptors()
    for id in pairs(events) do
        assert(not SourceEvents.has(id) and not SourceEventHandlers[id], "duplicate Copycat service")
    end
    for id in pairs(events) do
        local stableID = id
        SourceEventHandlers[id] = function(observation)
            return CopycatService.plan(stableID, observation)
        end
    end
    SourceEvents.registerEventSource(CONTENT, events)
    SourceEvents.registerTextSource(CONTENT, CopycatService.text)
end
