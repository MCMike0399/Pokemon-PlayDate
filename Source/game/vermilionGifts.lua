-- Four Blue source gifts, one choice controller and the shared item transaction.
-- Import after KantoServices; install after the ordinary source package.
VermilionGifts = {}
local CONTENT <const> = "vermilionGifts"
local REVISION <const> = "af519899719f0754965776faac0e836a3b906e6d"
local cached, texts
local function definitions()
    if not cached then
        local value = assert(json.decodeFile("data/vermilionGifts/events.json"))
        assert(value.schema == 1 and value.source_revision == REVISION, "unverified gift data")
        cached = value.events
    end
    return cached
end
function VermilionGifts.descriptors() return GameSession._copy(definitions()) end
function VermilionGifts.text(label)
    if not texts then
        local value = assert(json.decodeFile("data/vermilionPreparation/dialogue.json"))
        assert(value.schema == 1 and value.source_revision == REVISION, "unverified prepared text")
        texts = value.texts
    end
    return GameSession._copy(assert(texts[label], "missing prepared gift text"))
end
-- Catalog/actor registration needs no visibility exemptions or mutable context.
function VermilionGifts.actorMetadata(id)
    return {visibility={}}
end
function VermilionGifts.install()
    local events = VermilionGifts.descriptors()
    for id in pairs(events) do
        assert(not SourceEvents.has(id) and not SourceEventHandlers[id], "duplicate source gift")
    end
    for id in pairs(events) do
        SourceEventHandlers[id] = function()
            return {status="ready", scene="vermilion-gift", service="quest-gift", steps={}}
        end
    end
    SourceEvents.registerEventSource(CONTENT, events)
    SourceEvents.registerTextSource(CONTENT, VermilionGifts.text)
end
-- Actual owners supply detached observations, including unique owned species.
-- Seen, party size, current box and duplicate specimens cannot satisfy an aide.
function VermilionGifts.observe(session)
    local bag, items, canAdd = session:inventory(), {}, {}
    local ids = {}
    for _, d in pairs(definitions()) do
        ids[d.item] = true
        for _, id in ipairs(d.blocks or {}) do ids[id] = true end
    end
    for id in pairs(ids) do
        items[id] = assert(bag:quantity(id))
        local probe = assert(Inventory.fromData(ItemData.definitions, bag:toData()))
        canAdd[id] = probe:add(id, 1) == true
    end
    local owned = 0
    for _, value in pairs(session:pokedex().owned) do if value then owned = owned + 1 end end
    return {intro=session:getIntro().stage, flags=session:flags().quest,
        items=items, can_add=canAdd, owned=owned}
end
-- Decision nil offers a choice. The controller observes again after YES, like
-- CountSetBits in OaksAideScript; no durable effects or random draws occur here.
function VermilionGifts.plan(id, observation, decision)
    local d = assert(definitions()[id], "unknown source gift")
    local s = GameSession._copy(observation)
    assert(s.intro == "done" and Party._integer(s.owned, 0, 151), "settled source gift observation required")
    assert(decision == nil or type(decision) == "boolean", "explicit gift decision required")
    local result = {status="ready", before={}, success={}, full=GameSession._copy(d.full),
        ram={wStringBuffer=assert(ItemData.definitions[d.item]).name,
            wOaksAideRewardItemName=ItemData.definitions[d.item].name,
            hOaksAideRequirement=d.threshold or 0, hOaksAideNumMonsOwned=s.owned}}
    local complete = s.flags[d.flag] == true
    for _, item in ipairs(d.blocks or {}) do complete = complete or s.items[item] > 0 end
    if complete then
        result.status, result.before = "already-complete", GameSession._copy(d.completed)
    elseif decision == nil then
        result.status, result.before = "choice", GameSession._copy(d.prompt)
    elseif not decision then
        result.status, result.before = "declined", GameSession._copy(d.declined)
    elseif d.threshold and s.owned < d.threshold then
        result.status, result.before = "insufficient-owned", GameSession._copy(d.insufficient)
    else
        -- Reuse the ordinary program compiler rather than a second grant owner.
        local tx = SourceEvents.compile({kind="program",steps={
            {op="give-item",id=d.item,quantity=1}, {op="set-flag",id=d.flag,value=true},
        }}, s, id)
        for _, item in ipairs(d.blocks or {}) do tx.expected.items[item] = s.items[item] end
        result.expected, result.changes = tx.expected, tx.changes
        result.owned = d.threshold and s.owned or nil
        result.before, result.success = GameSession._copy(d.before), GameSession._copy(d.success)
    end
    return result
end
function VermilionGifts.commit(session, plan)
    assert(plan.expected and plan.changes, "gift transaction required")
    if plan.owned ~= nil and VermilionGifts.observe(session).owned ~= plan.owned then
        return false, "stale-owned"
    end
    -- No yield between the owned guard and the optimistic owner transaction.
    return session:transact(plan.expected, plan.changes)
end

Class("VermilionGiftsState"):extends(KantoServicesState)
function VermilionGiftsState:enter(id, options)
    self.giftStarted = false
    VermilionGiftsState.super.enter(self, id, options)
end
function VermilionGiftsState:advance()
    if not self.plan or self.plan.scene ~= "vermilion-gift" then
        return VermilionGiftsState.super.advance(self)
    end
    if not self:valid() or not self:isTop() then return end
    if self.giftStarted then self:finish(); return end
    self.giftStarted = true
    self:giftDecision(nil)
end
function VermilionGiftsState:giftDecision(decision)
    local plan = VermilionGifts.plan(self.id, VermilionGifts.observe(self.session), decision)
    self.plan.ram = plan.ram
    local continue = function()
        if plan.status == "choice" then
            -- Inherit the guarded YES/NO controller, including B=NO and epoch /
            -- serial invalidation. EventState remains the only pipeline.
            self:serviceChoice({"YES", "NO"}, function(yes) self:giftDecision(yes) end)
        elseif plan.expected then
            local ok, reason = VermilionGifts.commit(self.session, plan)
            if ok then
                self.committed = true
                self:serviceText(plan.success)
            elseif reason == "bag-full" or reason == "unique-key-item" then
                self:serviceText(plan.full)
            else self:fail(reason) end
        else self:finish() end
    end
    if #plan.before > 0 then self:serviceText(plan.before, continue) else continue() end
end
