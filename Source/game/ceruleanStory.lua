-- Bespoke Blue scenes. SourceEvents owns selection; EventState owns lifetime,
-- GameSession owns commits and NPCMotion owns every scripted actor pose.
CeruleanStory = {}
local CONTENT <const> = "ceruleanStory"
local BILL <const> = "pokered:BILLS_HOUSE:objects:"
local NERD <const> = "pokered:MT_MOON_B2F:objects:1"
local PC <const> = "pokered:BILLS_HOUSE:hidden_events:1"
local revision <const> = "af519899719f0754965776faac0e836a3b906e6d"
local data, integration
local function copy(value) return GameSession._copy(value) end
local function load()
    if not data then
        data = {}
        for _, name in ipairs({"events", "dialogue", "scenes", "trainers"}) do
            local value = assert(json.decodeFile("data/ceruleanStory/" .. name .. ".json"))
            assert(value.schema == 1 and value.source_revision == revision, "unverified Cerulean story data")
            data[name] = value
        end
    end
    return data
end
local function dialog(label) return {op="dialog", labels={label}} end
local function empty(status) return {status=status, steps={}} end
local function fossilChosen(state)
    return state.flags.EVENT_GOT_DOME_FOSSIL or state.flags.EVENT_GOT_HELIX_FOSSIL
end
local function padding(zoneID)
    local name = SourceMaps.nameForID(zoneID)
    return name and SourceMaps.entry(name).padding or 0
end
function CeruleanStory.descriptors()
    local events = copy(load().events.events)
    for id, descriptor in pairs(events) do
        local zoneID = "pokered:" .. id:match("^pokered:([^:]+):")
        for _, field in ipairs({"script_positions","script_collision_positions"}) do
            for _, position in ipairs(descriptor[field] or {}) do
                position.x = position.x + padding(zoneID)
            end
        end
    end
    return events
end
function CeruleanStory.trainers() return copy(load().trainers.trainers) end
function CeruleanStory.text(label)
    local record = assert(load().dialogue.texts[label], "missing bespoke story text")
    if CeruleanContent and record.source ~= "data/text/text_2.asm" then return CeruleanContent.text(label) end
    return copy(record)
end
function CeruleanStory.registerTrainers()
    local existing, missing = SourceEvents.trainerDefinitions(), {}
    for id, expected in pairs(CeruleanStory.trainers()) do
        local actual = existing[id]
        if actual then
            assert(actual.map_id == expected.map_id and actual.sprite_source == expected.sprite_source
                and actual.payout == expected.payout and #actual.party == #expected.party,
                "shared story trainer differs from pinned Blue source")
            for index, mon in ipairs(expected.party) do
                assert(actual.party[index].species == mon.species and actual.party[index].level == mon.level,
                    "shared story trainer roster differs from pinned Blue source")
            end
        else missing[id] = expected end
    end
    if next(missing) then SourceEvents.registerTrainerSource(CONTENT,function() return missing end) end
end
function CeruleanStory.scenes() return copy(load().scenes) end

-- Plans contain source labels and optimistic effects, never a second state owner.
function CeruleanStory.plan(id, state)
    local descriptor = assert(load().events.events[id], "unsupported Cerulean story identity")
    local script = descriptor.scene_script
    if script == "super-nerd" then
        if not state.trainers[NERD] then
            return {status="trainer-battle", steps={{op="trainer", id=id, mode=state.mode or "talk",
                before={"_MtMoonB2FSuperNerdTheyreBothMineText"}}}}
        end
        local label = fossilChosen(state) and "_MtMoonB2FSuperNerdTheresAPokemonLabText"
            or "_MtMoonB2fSuperNerdEachTakeOneText"
        local plan = {status="ready", steps={}}
        if state.receipt then
            plan.ram = {wAmountMoneyWon=state.receipt.payout}
            plan.steps = {{op="confirmed-dialog",labels={"_MtMoonB2FSuperNerdOkIllShareText"}},
                {op="confirmed-dialog",labels={"_MoneyForWinningText"}}}
        end
        plan.steps[#plan.steps+1] = dialog(label)
        return plan
    end
    if script == "bill-intro" and state.flags.EVENT_BILL_SAID_USE_CELL_SEPARATOR then
        return empty("already-complete")
    end
    if script == "bill-ticket" then
        if not state.flags.EVENT_MET_BILL then return empty("bill-not-restored") end
        if state.flags.EVENT_GOT_SS_TICKET then
            return {status="already-complete",steps={dialog("_BillsHouseBillWhyDontYouGoInsteadOfMeText")}}
        end
    end
    if script == "fossil" then
        if not state.trainers[NERD] then return empty("super-nerd-not-defeated") end
        if fossilChosen(state) then return empty("already-complete") end
    end
    return {status="ready", scene="cerulean-story", scene_script=script, steps={}}
end

function CeruleanStory.fossilReward(id, state)
    local descriptor = assert(load().events.events[id])
    assert(descriptor.scene_script == "fossil", "source fossil choice required")
    if not state.trainers[NERD] or fossilChosen(state) then return nil, "unavailable-fossil" end
    return {expected={flags={EVENT_GOT_DOME_FOSSIL=false,EVENT_GOT_HELIX_FOSSIL=false},
            trainers={[NERD]=true},items={[descriptor.item]=state.items[descriptor.item] or 0}},
        changes={flags={[descriptor.flag]=true},items={{op="add",id=descriptor.item,quantity=1}}}}
end
function CeruleanStory.ticketReward(state)
    if not state.flags.EVENT_MET_BILL or state.flags.EVENT_GOT_SS_TICKET then return nil, "unavailable-ticket" end
    return {expected={flags={EVENT_MET_BILL=true,EVENT_GOT_SS_TICKET=false},items={ssTicket=state.items.ssTicket or 0}},
        changes={flags={EVENT_GOT_SS_TICKET=true},items={{op="add",id="ssTicket",quantity=1}}}}
end
function CeruleanStory.leftHousePlan(session)
    if not session:questFlag("EVENT_MET_BILL_2") or not session:questFlag("EVENT_GOT_SS_TICKET")
        or session:questFlag("EVENT_LEFT_BILLS_HOUSE_AFTER_HELPING") then return nil end
    return {expected={flags={EVENT_MET_BILL_2=true,EVENT_GOT_SS_TICKET=true,EVENT_LEFT_BILLS_HOUSE_AFTER_HELPING=false},items={}},
        changes={flags={EVENT_LEFT_BILLS_HOUSE_AFTER_HELPING=true},items={}}}
end
-- Route25's actual map-load transition resets the pre-help setup, or switches
-- Bill's post-gift actor. The only reset is one existing domain-owned boolean;
-- the post-gift writes remain one guarded session transaction.
function CeruleanStory.onHouseExit(session)
    if not session:questFlag("EVENT_MET_BILL_2") then
        if not session:questFlag("EVENT_USED_CELL_SEPARATOR_ON_BILL") then
            return session:setQuestFlag("EVENT_BILL_SAID_USE_CELL_SEPARATOR",false)
        end
        return true -- A cancelled exit scene can safely resume from used=true.
    end
    local plan = CeruleanStory.leftHousePlan(session)
    if plan then return session:transact(plan.expected,plan.changes) end
    return true
end
-- Merge this metadata into the ordinary content worker's single actor resolver.
-- All positions are source cells; the importer applies its own padding once.
function CeruleanStory.actorMetadata(id)
    if id == "pokered:CERULEAN_CITY:objects:6" then
        return {visibility={{group="quest",id="EVENT_GOT_SS_TICKET",equals=true}}}
    elseif id == "pokered:CERULEAN_CITY:objects:11" then
        return {visibility={{group="quest",id="EVENT_GOT_SS_TICKET",equals=false}}}
    elseif id == BILL.."1" then
        return {visibility={{group="quest",id="EVENT_BILL_SAID_USE_CELL_SEPARATOR",equals=false}}}
    elseif id == BILL.."2" then
        return {visibility={{group="quest",id="EVENT_USED_CELL_SEPARATOR_ON_BILL",equals=true},
            {group="quest",id="EVENT_LEFT_BILLS_HOUSE_AFTER_HELPING",equals=false}}}
    elseif id == BILL.."3" then
        return {visibility={{group="quest",id="EVENT_LEFT_BILLS_HOUSE_AFTER_HELPING",equals=true}}}
    elseif id == "pokered:MT_MOON_B2F:objects:6" or id == "pokered:MT_MOON_B2F:objects:7" then
        return {visibility={{group="quest",id="EVENT_GOT_DOME_FOSSIL",equals=false},
            {group="quest",id="EVENT_GOT_HELIX_FOSSIL",equals=false}}}
    end
    return {}
end
function CeruleanStory.suppressEncounters(session, zoneID, x, y)
    local area = load().scenes.no_encounters_after_nerd
    return zoneID == "pokered:MT_MOON_B2F" and session:trainerDefeated(NERD)
        and x >= area.x_min + padding(zoneID) and x <= area.x_max + padding(zoneID) and y >= area.y_min and y <= area.y_max
end
function CeruleanStory.trigger(session, zoneID, x, y)
    local trigger = load().scenes.fossil_trigger
    if zoneID == "pokered:MT_MOON_B2F" and x == trigger.x + padding(zoneID) and y == trigger.y
        and not session:trainerDefeated(NERD) then return trigger.id end
end
-- Driver/export pose is in SOURCE coordinates; callers add map padding once.
-- scenes.pc retains the actual hidden-event TARGET, never a standing cell.
function CeruleanStory.pcPlayer() return copy(load().scenes.pc_player) end
function CeruleanStory.pcInteraction(zoneID, playerX, playerY, facing)
    local pc = load().scenes.pc
    if zoneID ~= "pokered:BILLS_HOUSE" or facing ~= pc.facing then return nil end
    local delta = ({up={0,-1},down={0,1},left={-1,0},right={1,0}})[facing]
    if delta and playerX + delta[1] == pc.x + padding(zoneID) and playerY + delta[2] == pc.y then return PC end
end

-- Rebuild only through the source spawner and NPCMotion.attach. Persistent
-- source flags project the completed fossil pose and interrupted Bill exit;
-- other source actors retain their normalized completed motion records.
function CeruleanStory.reconcileActors(game)
    local zone = currentZone
    local prior = game.npcManager.motion:snapshot()
    local flags = game.session:flags()
    local descriptor = assert(SourceActors.describe(zone.stableID,WorldDeltas.export()))
    local payload = WorldMotionData.reconcile(prior,descriptor,flags)
    local poses = {}
    if zone.stableID == "pokered:MT_MOON_B2F" then
        if flags.quest.EVENT_GOT_DOME_FOSSIL then poses[NERD]={x=13,y=7,facing="up"}
        elseif flags.quest.EVENT_GOT_HELIX_FOSSIL then poses[NERD]={x=12,y=7,facing="up"} end
    elseif zone.stableID == "pokered:BILLS_HOUSE" and flags.quest.EVENT_USED_CELL_SEPARATOR_ON_BILL then
        poses[BILL.."2"] = flags.quest.EVENT_MET_BILL and {x=4,y=4,facing="down"} or {x=1,y=2,facing="down"}
    end
    for _, actor in ipairs(payload.actors) do
        local pose = poses[actor.id]
        if pose then
            actor.x,actor.y,actor.facing = pose.x + padding(zone.stableID),pose.y,pose.facing
            actor.origin_x,actor.target_x,actor.origin_y,actor.target_y = actor.x,actor.x,actor.y,actor.y
            actor.phase,actor.tick,actor.delay_raw,actor.delay_left = actor.phase=="static" and "static" or "ready",0,0,0
        end
    end
    zone:spawnNPCs(game.npcManager)
    game.npcManager.motion:attach(game,zone,payload)
end

-- Install after the shared map manifest/content resolver, before contexts create
-- their TrainerEvents owner. Root may supply its equivalent actor reconciler.
function CeruleanStory.install(options)
    options = options or {reconcileActors=CeruleanStory.reconcileActors}
    assert(type(options.reconcileActors) == "function", "root source actor reconciliation required")
    assert(not integration, "Cerulean story already installed")
    integration = {reconcileActors=options.reconcileActors}
    for id, descriptor in pairs(CeruleanStory.descriptors()) do
        if descriptor.kind == "bespoke" then
            assert(not SourceEventHandlers[id], "duplicate bespoke story handler")
            local stableID = id
            SourceEventHandlers[id] = function(state) return CeruleanStory.plan(stableID,state) end
        end
    end
    SourceEvents.registerEventSource(CONTENT,CeruleanStory.descriptors())
    SourceEvents.registerTextSource(CONTENT,CeruleanStory.text)
    CeruleanStory.registerTrainers()
end

-- EventState subclass adds only scene control; ordinary plans retain its exact
-- executor, battle handoff, receipt guards, input and cancellation semantics.
Class("CeruleanEventState"):extends(EventState)
function CeruleanEventState:advance()
    if not self.plan or self.plan.scene ~= "cerulean-story" then
        return CeruleanEventState.super.advance(self)
    end
    if not self:valid() or not self:isTop() then return end
    if not self.storyQueue then
        self.storyQueue, self.storyIndex = {}, 1
        self:prepareStory()
    end
    if self.phase == "failed" then return end
    local action = self.storyQueue[self.storyIndex]
    self.storyIndex = self.storyIndex + 1
    if action then action() else self:finish() end
end
function CeruleanEventState:queue(action) self.storyQueue[#self.storyQueue+1] = action end
function CeruleanEventState:queueText(label)
    self:queue(function() self:source({label},function() self:advance() end) end)
end
function CeruleanEventState:queueMovement(id, directions)
    for _, direction in ipairs(directions) do
        local facing = direction
        self:queue(function() self:startNPCMove({id=id,direction=facing}) end)
    end
end
function CeruleanEventState:queueChoice(onChoice)
    self:queue(function()
        self.phase, self.waiting = "story-choice", "yes-no"
        local selected = self:guard(function(index)
            self.menu:hide()
            self.menu.onSelect, self.menu.onCancel = nil,nil
            onChoice(index == 1)
        end)
        self.menu:show({"YES","NO"},selected,function() selected(2) end)
    end)
end
function CeruleanEventState:storyCommit(plan)
    if not self:valid() or not self:isTop() then return false end
    local ok, reason = self.session:transact(plan.expected,plan.changes)
    if not ok then self:failureDialogue(reason); return false end
    self.committed = true
    return true
end
function CeruleanEventState:queueFlags(expected, changes)
    self:queue(function()
        if self:storyCommit({expected={flags=expected,items={}},changes={flags=changes,items={}}}) then self:advance() end
    end)
end
function CeruleanEventState:reconcileStoryActors()
    self:cancelNPCMove()
    assert(integration, "Cerulean story integration missing").reconcileActors(self.game)
end
function CeruleanEventState:queueReconcile()
    self:queue(function() self:reconcileStoryActors(); self:advance() end)
end
function CeruleanEventState:queuePlace(id, x, y)
    self:queue(function()
        local npc
        for _, actor in ipairs(self.game.npcManager.npcs) do
            if actor.def and actor.def.source_event_id == id then npc = actor; break end
        end
        if not npc then self:fail("absent-source-scene-actor"); return end
        local motion = self.game.npcManager.motion
        local token, reason = motion:claimScript(npc,self)
        if not token then self:fail(reason); return end
        self.npcLeases[id] = token
        -- Narrow root NPCMotion extension; rejects unlisted/protected cells.
        local ok
        ok, reason = motion:placeScript(token,x + padding(self.zone.stableID),y)
        if not ok then self:fail(reason); return end
        self:advance()
    end)
end
function CeruleanEventState:prepareStory()
    local script = self.plan.scene_script
    local state = EventState.observe(self.game,self.id)
    local scenes = load().scenes
    if script == "bill-intro" then
        self:queueText("_BillsHouseBillImNotAPokemonText")
        self:queueChoice(function(yes)
            -- In Blue NO is pleaded past; it still starts the separator setup.
            if not yes then
                self:source({"_BillsHouseBillNoYouGottaHelpText"},function() self:advance() end)
            else self:advance() end
        end)
        self:queueText("_BillsHouseBillUseSeparationSystemText")
        local path = self.player.facing == "down" and scenes.movement.bill_around or scenes.movement.bill_enter
        self:queueMovement(BILL.."1",path)
        self:queueFlags({EVENT_BILL_SAID_USE_CELL_SEPARATOR=false},{EVENT_BILL_SAID_USE_CELL_SEPARATOR=true})
        self:queueReconcile()
    elseif script == "bill-pc" then
        if state.flags.EVENT_LEFT_BILLS_HOUSE_AFTER_HELPING then
            self:fail("bill-pokemon-list-outside-bounded-scene"); return
        end
        if not state.flags.EVENT_BILL_SAID_USE_CELL_SEPARATOR or state.flags.EVENT_MET_BILL then
            self:queueText("_BillsHouseMonitorText")
            return
        end
        if not state.flags.EVENT_USED_CELL_SEPARATOR_ON_BILL then
            self:queueText("_BillsHouseInitiatedText")
            -- The source has 268 explicit delay frames plus audio waits. Audio
            -- is not implemented; retain its fixed duration at 30 Hz (134 ticks).
            self:queue(function() self.storyTicks=134; self.phase="story-machine"; self.waiting="cell-separator" end)
            self:queueFlags({EVENT_BILL_SAID_USE_CELL_SEPARATOR=true,EVENT_USED_CELL_SEPARATOR_ON_BILL=false},
                {EVENT_USED_CELL_SEPARATOR_ON_BILL=true})
        end
        self:queueReconcile()
        self:queuePlace(BILL.."2",1,2)
        self:queue(function() self.storyTicks=4; self.phase="story-machine"; self.waiting="bill-emerges" end)
        self:queueMovement(BILL.."2",scenes.movement.bill_exit)
        self:queueFlags({EVENT_USED_CELL_SEPARATOR_ON_BILL=true,EVENT_MET_BILL=false,EVENT_MET_BILL_2=false},
            {EVENT_MET_BILL=true,EVENT_MET_BILL_2=true})
    elseif script == "bill-ticket" then
        self:queueText("_BillsHouseBillThankYouText")
        self:queue(function()
            local plan, reason = CeruleanStory.ticketReward(EventState.observe(self.game,self.id))
            if not plan then self:fail(reason); return end
            if self:storyCommit(plan) then
                self.plan.ram = {wStringBuffer=ItemData.definitions.ssTicket.name}
                self:source({"_SSTicketReceivedText"},function() self:advance() end)
            end
        end)
        self.plan.failure_labels = {"_SSTicketNoRoomText"}
        self:queueText("_BillsHouseBillWhyDontYouGoInsteadOfMeText")
    elseif script == "fossil" then
        local d = load().events.events[self.id]
        self:queueText(d.prompt)
        self:queueChoice(function(yes)
            if not yes then self:finish(); return end
            local plan, reason = CeruleanStory.fossilReward(self.id,EventState.observe(self.game,self.id))
            if not plan then self:fail(reason); return end
            if self:storyCommit(plan) then
                self.plan.ram = {wStringBuffer=ItemData.definitions[d.item].name}
                self:source({"_MtMoonB2FReceivedFossilText"},function()
                    SourceEvents.afterCommit(self.game,{pickup=self.id})
                    self:advance()
                end)
            end
        end)
        self.plan.failure_labels = {"_MtMoonB2FYouHaveNoRoomText"}
        local dome = d.item == "domeFossil"
        self:queueMovement(NERD,dome and scenes.movement.nerd_dome or scenes.movement.nerd_helix)
        self:queueText("_MtMoonB2FSuperNerdThenThisIsMineText")
        self:queueReconcile()
    else error("unimplemented bespoke Cerulean scene") end
end
function CeruleanEventState:update()
    if self:valid() and self:isTop() and self.phase == "story-machine" then
        self.storyTicks = self.storyTicks - 1
        if self.storyTicks == 0 then self:advance() end
        return
    end
    CeruleanEventState.super.update(self)
end
function CeruleanEventState:handleButton(button)
    if self:valid() and self:isTop() and self.phase == "story-choice" then
        if button == "up" or button == "down" then self.menu.selectedIndex=3-self.menu.selectedIndex
        elseif button == "a" then self.menu.onSelect(self.menu.selectedIndex)
        elseif button == "b" then self.menu.onCancel() end
        return
    end
    CeruleanEventState.super.handleButton(self,button)
end
function CeruleanEventState:draw()
    CeruleanEventState.super.draw(self)
    if self:valid() and self.phase == "story-choice" then
        local gfx = playdate.graphics
        gfx.pushContext()
        gfx.setDrawOffset(0,0)
        self.menu:draw(244,120,140,56)
        gfx.popContext()
    end
end
function CeruleanEventState:fail(reason)
    if self.plan and self.plan.scene == "cerulean-story" then
        for _, token in pairs(self.npcLeases or {}) do
            self.game.npcManager.motion:releaseScript(token,true)
        end
        self.npcLeases = {}
    end
    CeruleanEventState.super.fail(self,reason)
end
function CeruleanEventState:exit()
    local bespoke = self.plan and self.plan.scene == "cerulean-story"
    if bespoke and self.phase ~= "complete" then
        -- Abort the whole leased path, including completed cells. A later
        -- controller must start from its source pose, not a half-finished path.
        for _, token in pairs(self.npcLeases or {}) do
            self.game.npcManager.motion:releaseScript(token,true)
        end
        self.npcLeases = {}
    end
    if bespoke and self.committed and integration and self.game.session == self.session and currentZone == self.zone then
        self:reconcileStoryActors()
    end
    self.storyQueue,self.storyIndex,self.storyTicks = nil,nil,nil
    CeruleanEventState.super.exit(self)
end
