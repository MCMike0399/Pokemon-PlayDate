-- Pure source-script planner. Stable IDs select data, never map array positions.
-- EventState executes the result; session/trainer owners alone commit effects.
import "game/sourceEventHandlers"
SourceEvents = {}
local REVISION <const> = "af519899719f0754965776faac0e836a3b906e6d"
local cached
local textSources, trainerSources = {}, {}
local directions = { up = true, down = true, left = true, right = true }
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end
local function definitions()
    if not cached then
        local data = assert(json.decodeFile("data/sourceEvents.json"), "source event data missing")
        assert(data.schema == 1 and data.source_revision == REVISION, "unverified source events")
        cached = data.events
    end
    return cached
end
local function dialog(labels, op)
    return { op = op or "dialog", labels = copy(labels) }
end
local function append(steps, values)
    for _, step in ipairs(values or {}) do steps[#steps + 1] = copy(step) end
end
local function matches(condition, state)
    for id, value in pairs(condition.flags or {}) do
        if (state.flags[id] == true) ~= value then return false end
    end
    for id, value in pairs(condition.items_equal or {}) do
        if (state.items[id] or 0) ~= value then return false end
    end
    for id, value in pairs(condition.items_min or {}) do
        if (state.items[id] or 0) < value then return false end
    end
    if condition.any then
        for _, choice in ipairs(condition.any) do
            if matches(choice, state) then return true end
        end
        return false
    end
    return true
end
local function reward(item, flag, state, trainer, defaultZero)
    local quantity = state.items[item]
    if defaultZero then quantity = quantity or 0 end
    local expected = { flags = { [flag] = false }, items = { [item] = quantity } }
    local changes = { flags = { [flag] = true }, items = { { op = "add", id = item, quantity = 1 } } }
    if trainer then
        expected.trainers = { [trainer] = true }
        changes.trainers = {}
    end
    return expected, changes
end
local function gift(d, state)
    local plan = { status = "ready", steps = {} }
    if state.flags[d.flag] == true then
        plan.status = "already-complete"
        plan.steps[1] = dialog(d.completed)
    else
        append(plan.steps, d.prefix)
        if state.can_add[d.item] ~= true then
            plan.status, plan.retry = "bag-full", true
            if d.full then plan.steps[#plan.steps + 1] = dialog(d.full) end
        else
            plan.steps[#plan.steps + 1] = dialog(d.success)
            plan.expected, plan.changes = reward(d.item, d.flag, state, nil, true)
        end
    end
    return plan
end
local function pickup(d, state, id)
    local plan = { status = "ready", steps = {} }
    if state.flags[d.flag] then
        plan.status = "already-complete"
    elseif not state.can_add[d.item] then
        plan.status = "pickup-full"
        plan.steps[1] = dialog(d.full)
    else
        plan.expected, plan.changes = reward(d.item, d.flag, state)
        plan.ram = { wStringBuffer = assert(ItemData.definitions[d.item]).name }
        plan.steps[1] = dialog(d.success, "receipt")
        plan.failure_labels, plan.pickup = copy(d.full), id
    end
    return plan
end
local function trainer(d, state, id)
    local plan = { status = "ready", steps = {} }
    if state.receipt then
        plan.steps[#plan.steps + 1] = dialog(d.won, "confirmed-dialog")
        plan.ram = { wAmountMoneyWon = state.receipt.payout }
        plan.steps[#plan.steps + 1] = dialog({ "_MoneyForWinningText" }, "confirmed-dialog")
    end
    if not state.trainers[id] then
        plan.status = "trainer-battle"
        plan.steps[#plan.steps + 1] = { op = "trainer", id = id, before = copy(d.before), mode = state.mode or "talk" }
    elseif d.reward and not state.flags[d.reward.flag] then
        local r = d.reward
        plan.steps[#plan.steps + 1] = dialog(r.before)
        if state.can_add[r.item] then
            plan.expected, plan.changes = reward(r.item, r.flag, state, id)
            plan.steps[#plan.steps + 1] = dialog(r.success, "receipt")
            plan.failure_labels = copy(r.full)
        else
            plan.steps[#plan.steps + 1] = dialog(r.full)
            plan.status = r.full_status
        end
    elseif not state.receipt then
        plan.steps[#plan.steps + 1] = dialog(d.after)
    end
    return plan
end
local function boundedInteger(value, low, high)
    return type(value) == "number" and value % 1 == 0 and value >= low and value <= high
end
function SourceEvents.validateStep(step)
    assert(type(step) == "table", "source operation required")
    local op = step.op
    if op == "dialog" or op == "receipt" or op == "confirmed-dialog" then
        assert(type(step.labels) == "table" and #step.labels > 0 and #step.labels <= 12, "bounded source labels required")
        for _, label in ipairs(step.labels) do assert(type(label) == "string" and #label <= 128, "source label required") end
    elseif op == "move" or op == "move-npc" then
        assert(directions[step.direction] and boundedInteger(step.count, 1, 8), "bounded movement required")
        if op == "move-npc" then assert(type(step.id) == "string", "stable source actor ID required") end
    elseif op == "give-item" then
        assert(type(step.id) == "string" and boundedInteger(step.quantity, 1, 99), "bounded item grant required")
    elseif op == "set-flag" then
        assert(type(step.id) == "string" and type(step.value) == "boolean", "explicit flag operation required")
    elseif op == "trainer" or op == "battle" then
        assert(type(step.id) == "string" and (step.mode == "talk" or step.mode == "sight"), "source trainer operation required")
        SourceEvents.validateStep({ op = "dialog", labels = step.before })
    elseif op == "shop" then
        assert(type(step.id) == "string", "source shop ID required")
    elseif op == "heal" then
        assert(type(step.id) == "string", "source Center ID required")
        for _, key in ipairs({ "welcome", "prompt", "before", "after", "farewell" }) do
            assert(type(step[key]) == "string", "source healing labels required")
        end
    elseif op == "warp" then
        assert(type(step.to) == "string" and boundedInteger(step.toX, 0, 1023) and boundedInteger(step.toY, 0, 1023)
            and directions[step.facing], "bounded warp destination required")
    else
        error("unsupported source operation: " .. tostring(op))
    end
end
local function program(d, state)
    local plan = { status = d.status or "ready", steps = {} }
    assert(type(d.steps) == "table" and #d.steps <= 16, "source program step limit")
    local hasBattle = false
    for index, sourceStep in ipairs(d.steps) do
        local step = copy(sourceStep)
        SourceEvents.validateStep(step)
        if step.op == "give-item" or step.op == "set-flag" then
            -- All durable program effects share one optimistic session transaction.
            plan.expected = plan.expected or { flags = {}, items = {} }
            plan.changes = plan.changes or { flags = {}, items = {} }
            if step.op == "give-item" then
                assert(not plan.expected.items[step.id], "duplicate program item grant")
                plan.expected.items[step.id] = state.items[step.id] or 0
                plan.changes.items[#plan.changes.items + 1] = { op = "add", id = step.id, quantity = step.quantity }
            else
                assert(plan.expected.flags[step.id] == nil, "duplicate program flag write")
                plan.expected.flags[step.id] = state.flags[step.id] == true
                plan.changes.flags[step.id] = step.value
            end
        else
            if step.op == "battle" then step.op = "trainer" end
            if step.op == "trainer" then
                assert(index == #d.steps, "battle must terminate source program")
                hasBattle = true
            end
            if step.op == "warp" then assert(index == #d.steps, "warp must terminate source program") end
            plan.steps[#plan.steps + 1] = step
        end
    end
    assert(not hasBattle or not plan.expected, "battle return owns subsequent durable effects")
    return plan
end
local function compile(d, state, id, depth)
    assert(depth <= 8, "source branch depth limit")
    local plan
    if d.kind == "cases" then
        assert(#d.cases <= 16, "source branch count limit")
        local selected = d.otherwise
        for _, branch in ipairs(d.cases) do
            if matches(branch.when, state) then selected = branch["then"]; break end
        end
        plan = compile(assert(selected), state, id, depth + 1)
    elseif d.kind == "gift" then plan = gift(d, state)
    elseif d.kind == "pickup" then plan = pickup(d, state, id)
    elseif d.kind == "trainer" then plan = trainer(d, state, id)
    elseif d.kind == "program" then plan = program(d, state)
    elseif d.kind == "bespoke" then plan = assert(SourceEventHandlers[id], "unimplemented bespoke source script")(copy(state))
    else error("unknown source descriptor kind: " .. tostring(d.kind)) end
    for _, key in ipairs({ "source", "fidelity" }) do
        if d[key] then plan[key] = d[key] end
    end
    return plan
end
-- Also used by SDK contracts and upcoming map content; it never installs data.
function SourceEvents.compile(descriptor, state, id)
    assert(type(state) == "table" and type(state.flags) == "table" and type(state.items) == "table"
        and type(state.can_add) == "table", "explicit read-only event observation required")
    assert(state.intro == "done", "source events require completed intro/rival sequence")
    local plan = compile(descriptor, state, id, 1)
    plan.id = id
    if descriptor.content and descriptor.content ~= "viridian" then plan.source_content = descriptor.content end
    assert(type(plan.steps) == "table" and #plan.steps <= 16, "event step limit")
    for _, step in ipairs(plan.steps) do
        SourceEvents.validateStep(step)
        if step.op == "trainer" then assert(step.id == id, "event must own its trainer encounter") end
    end
    return plan
end
-- Discover inventory observations from descriptors rather than a regional list.
function SourceEvents.itemIDs()
    local found = {}
    local function visit(value)
        if type(value) ~= "table" then return end
        if value.item then found[value.item] = true end
        if value.op == "give-item" then found[value.id] = true end
        for _, child in pairs(value) do visit(child) end
    end
    visit(definitions())
    local ids = {}
    for id in pairs(found) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids
end
function SourceEvents.descriptor(id) return copy(definitions()[id]) end
function SourceEvents.has(id, content)
    local d = definitions()[id]
    return d ~= nil and (content == nil or d.content == content)
end
function SourceEvents.plan(id, state)
    assert(type(id) == "string" and SourceEvents.has(id), "unimplemented source event: " .. tostring(id))
    return SourceEvents.compile(definitions()[id], state, id)
end
function SourceEvents.isPickup(id)
    local d = definitions()[id]
    return d ~= nil and d.kind == "pickup"
end
function SourceEvents.pickupFlag(id)
    assert(SourceEvents.isPickup(id), "unknown source pickup")
    return definitions()[id].flag
end
-- New regions register immutable data resolvers, not per-event Lua handlers.
function SourceEvents.registerTextSource(name, resolver)
    assert(type(name) == "string" and type(resolver) == "function", "named text source required")
    assert(name ~= "viridian" and name ~= "pewter", "reviewed text source cannot be replaced")
    assert(not textSources[name] or textSources[name] == resolver, "source text resolver replaced")
    textSources[name] = resolver
end
function SourceEvents.pages(id, labels, ram)
    local content = assert(definitions()[id]).content
    if content == "viridian" then return EventText.pages(labels) end
    local resolver = content == "pewter" and PewterSlice.text or textSources[content]
    return EventText.pagesFrom(labels, assert(resolver, "source text resolver missing"), ram)
end
function SourceEvents.afterCommit(game, plan)
    if plan.pickup then
        for _, npc in ipairs(game.npcManager.npcs) do
            if npc.def and npc.def.source_event_id == plan.pickup then
                game.npcManager:removeNPC(npc)
                break
            end
        end
    end
end
function SourceEvents.registerTrainerSource(name, resolver)
    assert(type(name) == "string" and type(resolver) == "function", "named trainer source required")
    assert(not trainerSources[name] or trainerSources[name] == resolver, "source trainer resolver replaced")
    trainerSources[name] = resolver
end
function SourceEvents.trainerDefinitions()
    local result = PewterSlice.trainers()
    for _, resolver in pairs(trainerSources) do
        for id, definition in pairs(resolver()) do
            assert(not result[id] and definition.id == id, "duplicate or unstable source trainer")
            result[id] = copy(definition)
        end
    end
    return result
end
function SourceEvents.rewardPlan(id, state)
    local d = definitions()[id]
    if not d or not d.reward or not state.trainers[id] or state.flags[d.reward.flag] then return nil, "no-pending-tm-reward" end
    local expected, changes = reward(d.reward.item, d.reward.flag, state, id)
    return { expected = expected, changes = changes }
end
-- TrainerEvents calls this only inside its confirmed-victory transaction.
function SourceEvents.victoryChanges(id, session, expected, changes)
    local d = definitions()[id]
    if not d or not d.victory then return end
    for trainerID, value in pairs(d.victory.trainers or {}) do
        expected.trainers[trainerID] = session:trainerDefeated(trainerID)
        changes.trainers[trainerID] = value
    end
    for _, flag in ipairs(d.victory.guard_flags or {}) do expected.flags[flag] = session:questFlag(flag) end
    for flag, value in pairs(d.victory.flags or {}) do changes.flags[flag] = value end
end
function SourceEvents.dispatch(game, id, options)
    assert(game.session:getIntro().stage == "done", "Kanto events require completed original intro")
    assert(SourceEvents.has(id), "unimplemented source event: " .. tostring(id))
    assert(not game.player or not game.player.isMoving and not game.player.pendingEdgeDoor, "source event requires settled player")
    assert(game.machine:getCurrent() == "overworld" and game.machine:get("event"), "root event executor required")
    game.machine:push("event", id, options)
    return true
end
