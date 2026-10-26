-- Frozen 1339333 planners: SDK-only regression oracle, never production dispatch.
-- Identifier renaming isolates the original code; no SDK substitution or Lua transpilation.

-- Explicit bounded Blue event plans. No state, inventory, UI, or global mutations.
SourceEventBaselineSlice = {}
local handlers = {}
local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}; for k, v in pairs(value) do out[k] = copy(v) end; return out
end
local function flag(state, id) return state.flags[id] == true end
local function item(state, id) return state.items[id] or 0 end
local function dialogue(...)
    return { op = "dialog", labels = { ... } }
end
local function grant(state, itemID, event, before, success, full)
    if flag(state, event) then return { status = "already-complete", steps = { dialogue(before) } } end
    if state.can_add[itemID] ~= true then
        return { status = "bag-full", retry = true, steps = full and { dialogue(full) } or {} }
    end
    return { status = "ready", steps = { dialogue(success) },
        expected = { flags = { [event] = false }, items = { [itemID] = item(state, itemID) } },
        changes = { items = { { op = "add", id = itemID, quantity = 1 } }, flags = { [event] = true } } }
end
handlers["pokered:ROUTE_1:objects:1"] = function(state)
    local plan = grant(state, "potion", "EVENT_GOT_POTION_SAMPLE", "_Route1Youngster1AlsoGotPokeballsText", "_Route1Youngster1GotPotionText", "_Route1Youngster1NoRoomText")
    if plan.status ~= "already-complete" then table.insert(plan.steps, 1, dialogue("_Route1Youngster1MartSampleText")) end
    plan.source = "scripts/Route1.asm:Route1Youngster1Text"
    plan.fidelity = "intentional repair: set eligibility flag only after successful grant"
    return plan
end
handlers["pokered:ROUTE_1:objects:2"] = function() return { status = "ready", steps = { dialogue("_Route1Youngster2Text") } } end
handlers["pokered:ROUTE_1:background_events:1"] = function() return { status = "ready", steps = { dialogue("_Route1SignText") } } end
handlers["pokered:VIRIDIAN_MART:script:entry"] = function(state)
    if flag(state, "EVENT_OAK_GOT_PARCEL") then return { status = "shop-available", steps = {} } end
    if flag(state, "EVENT_GOT_OAKS_PARCEL") or item(state, "oaksParcel") > 0 then
        return { status = "already-complete", steps = {} }
    end
    local plan = grant(state, "oaksParcel", "EVENT_GOT_OAKS_PARCEL", "_ViridianMartClerkSayHiToOakText", "_ViridianMartClerkParcelQuestText")
    if plan.status == "bag-full" then
        plan.steps = { dialogue("_ViridianMartClerkParcelQuestText") }
    end
    if plan.status == "ready" or plan.status == "bag-full" then
        table.insert(plan.steps, 1, { op = "move", direction = "left", count = 1 })
        table.insert(plan.steps, 1, { op = "move", direction = "up", count = 2 })
        table.insert(plan.steps, 1, dialogue("_ViridianMartClerkYouCameFromPalletTownText"))
    end
    plan.source = "scripts/ViridianMart.asm:ViridianMartDefaultScript"
    plan.fidelity = "intentional repair: failed GiveItem does not set parcel event"
    return plan
end
handlers["pokered:VIRIDIAN_MART:objects:1"] = function(state)
    if flag(state, "EVENT_OAK_GOT_PARCEL") then
        return { status = "ready", steps = { { op = "shop", id = "viridianMartClerkText", stock = { "pokeBall", "antidote", "parlyzHeal", "burnHeal" } } } }
    end
    -- Full-bag repair can be retried by speaking to the clerk, not only re-entry.
    if not flag(state, "EVENT_GOT_OAKS_PARCEL") and item(state, "oaksParcel") == 0 then
        return grant(state, "oaksParcel", "EVENT_GOT_OAKS_PARCEL", "_ViridianMartClerkSayHiToOakText", "_ViridianMartClerkParcelQuestText")
    end
    return { status = "ready", steps = { dialogue("_ViridianMartClerkSayHiToOakText") } }
end
handlers["pokered:VIRIDIAN_MART:objects:2"] = function() return { status = "ready", steps = { dialogue("_ViridianMartYoungsterText") } } end
handlers["pokered:VIRIDIAN_MART:objects:3"] = function() return { status = "ready", steps = { dialogue("_ViridianMartCooltrainerMText") } } end
handlers["pokered:OAKS_LAB:script:parcel-handoff"] = function(state)
    if flag(state, "EVENT_GOT_POKEDEX") then
        return { status = "already-complete", steps = { dialogue("_OaksLabOak1PokemonAroundTheWorldText") } }
    end
    if item(state, "oaksParcel") == 0 then
        return { status = "no-item", steps = { dialogue("_OaksLabOak1RaiseYourYoungPokemonText") } }
    end
    assert(flag(state, "EVENT_GOT_OAKS_PARCEL") and item(state, "oaksParcel") == 1, "invalid parcel quest state")
    return { status = "ready", scene = "oak-pokedex", source = "scripts/OaksLab.asm:OaksLabOakGivesPokedexScript",
        steps = { dialogue("_OaksLabOak1DeliverParcelText", "_OaksLabOak1ParcelThanksText"),
            dialogue("_OaksLabRivalWhatDidYouCallMeForText", "_OaksLabOakIHaveARequestText", "_OaksLabOakMyInventionPokedexText", "_OaksLabOakGotPokedexText", "_OaksLabOakThatWasMyDreamText", "_OaksLabRivalLeaveItAllToMeText") },
        required_actor_sequence = "rival arrival, Oak/rival facing, Pokédex object removal, rival departure; adapted to protected authored lab by root",
        expected = { flags = { EVENT_GOT_OAKS_PARCEL = true, EVENT_OAK_GOT_PARCEL = false, EVENT_GOT_POKEDEX = false }, items = { oaksParcel = 1 } },
        changes = { items = { { op = "handoff", id = "oaksParcel", quantity = 1 } }, flags = { EVENT_OAK_GOT_PARCEL = true, EVENT_GOT_POKEDEX = true } } }
end
handlers["pokered:VIRIDIAN_POKECENTER:objects:1"] = function()
    return { status = "ready", steps = { { op = "heal", id = "viridianPokecenter", welcome = "_PokemonCenterWelcomeText", prompt = "_ShallWeHealYourPokemonText", before = "_NeedYourPokemonText", after = "_PokemonFightingFitText", farewell = "_PokemonCenterFarewellText" } },
        source = "engine/events/pokecenter.asm:DisplayPokemonCenterDialogue_" }
end
-- Plain original dialogue/sign handlers; choices, gifts, tutorial and other
-- map mechanics remain explicit gaps instead of being flattened into dialogue.
local plain = {
    ["pokered:VIRIDIAN_CITY:objects:1"] = "_ViridianCityYoungster1Text",
    ["pokered:VIRIDIAN_CITY:background_events:1"] = "_ViridianCitySignText",
    ["pokered:VIRIDIAN_CITY:background_events:2"] = "_ViridianCityTrainerTips1Text",
    ["pokered:VIRIDIAN_CITY:background_events:3"] = "_ViridianCityTrainerTips2Text",
    ["pokered:VIRIDIAN_CITY:background_events:4"] = "_MartSignText",
    ["pokered:VIRIDIAN_CITY:background_events:5"] = "_PokeCenterSignText",
    ["pokered:VIRIDIAN_CITY:background_events:6"] = "_ViridianCityGymSignText",
    ["pokered:VIRIDIAN_POKECENTER:objects:2"] = "_ViridianPokecenterGentlemanText",
    ["pokered:VIRIDIAN_POKECENTER:objects:3"] = "_ViridianPokecenterCooltrainerMText",
}
for id, label in pairs(plain) do
    local sourceLabel=label
    handlers[id]=function() return {status="ready",steps={dialogue(sourceLabel)}} end
end
handlers["pokered:VIRIDIAN_CITY:objects:4"] = function(state)
    local label=flag(state,"EVENT_GOT_POKEDEX") and "_ViridianCityGirlWhenIGoShopText" or "_ViridianCityGirlHasntHadHisCoffeeYetText"
    return {status="ready",steps={dialogue(label)},source="scripts/ViridianCity.asm:ViridianCityGirlText"}
end
function SourceEventBaselineSlice.has(id) return handlers[id] ~= nil end
function SourceEventBaselineSlice.plan(id, state)
    assert(type(id) == "string" and handlers[id], "unimplemented source event: " .. tostring(id))
    assert(type(state) == "table" and type(state.flags) == "table" and type(state.items) == "table" and type(state.can_add) == "table", "explicit read-only event observation required")
    assert(state.intro == "done", "parcel slice requires completed intro/rival sequence")
    local plan = handlers[id](copy(state)); plan.id = id
    return plan
end

-- Bounded source handlers for the reviewed Route2/Forest/Pewter milestone.
-- Escort/tutorial/audio/link mechanics outside this milestone stay explicit.
SourceEventBaselinePewter={}
local simple={
 ["pokered:ROUTE_2:background_events:1"]="_Route2SignText",
 ["pokered:ROUTE_2:background_events:2"]="_Route2DiglettsCaveSignText",
 ["pokered:VIRIDIAN_FOREST_SOUTH_GATE:objects:1"]="_ViridianForestSouthGateGirlText",
 ["pokered:VIRIDIAN_FOREST_SOUTH_GATE:objects:2"]="_ViridianForestSouthGateLittleGirlText",
 ["pokered:VIRIDIAN_FOREST_NORTH_GATE:objects:1"]="_ViridianForestNorthGateSuperNerdText",
 ["pokered:VIRIDIAN_FOREST_NORTH_GATE:objects:2"]="_ViridianForestNorthGateGrampsText",
 ["pokered:VIRIDIAN_FOREST:objects:1"]="_ViridianForestYoungster1Text",
 ["pokered:VIRIDIAN_FOREST:objects:8"]="_ViridianForestYoungster5Text",
 ["pokered:PEWTER_CITY:objects:1"]="_PewterCityCooltrainerFText",
 ["pokered:PEWTER_CITY:objects:2"]="_PewterCityCooltrainerMText",
 ["pokered:PEWTER_MART:objects:2"]="_PewterMartYoungsterText",
 ["pokered:PEWTER_MART:objects:3"]="_PewterMartSuperNerdText",
 ["pokered:PEWTER_POKECENTER:objects:2"]="_PewterPokecenterGentlemanText",
}
for index,label in ipairs({"_ViridianForestTrainerTips1Text","_ViridianForestUseAntidoteSignText","_ViridianForestTrainerTips2Text","_ViridianForestTrainerTips3Text","_ViridianForestTrainerTips4Text","_ViridianForestLeavingSignText"}) do simple["pokered:VIRIDIAN_FOREST:background_events:"..index]=label end
for index,label in ipairs({"_PewterCityTrainerTipsText","_PewterCityPoliceNoticeSignText","_MartSignText","_PokeCenterSignText","_PewterCityMuseumSignText","_PewterCityGymSignText","_PewterCitySignText"}) do simple["pokered:PEWTER_CITY:background_events:"..index]=label end
local pickups={
 ["pokered:ROUTE_2:objects:1"]="moonStone",["pokered:ROUTE_2:objects:2"]="hpUp",
 ["pokered:VIRIDIAN_FOREST:objects:5"]="antidote",["pokered:VIRIDIAN_FOREST:objects:6"]="potion",["pokered:VIRIDIAN_FOREST:objects:7"]="pokeBall",
 ["pokered:VIRIDIAN_FOREST:hidden:1"]="potion",["pokered:VIRIDIAN_FOREST:hidden:2"]="antidote",
}
local trainerBefore={
 ["pokered:VIRIDIAN_FOREST:objects:2"]="_ViridianForestYoungster2BattleText",
 ["pokered:VIRIDIAN_FOREST:objects:3"]="_ViridianForestYoungster3BattleText",
 ["pokered:VIRIDIAN_FOREST:objects:4"]="_ViridianForestYoungster4BattleText",
 ["pokered:PEWTER_GYM:objects:2"]="_PewterGymCooltrainerMBattleText",
 ["pokered:PEWTER_GYM:objects:1"]="_PewterGymBrockPreBattleText",
}
function SourceEventBaselinePewter.pages(labels,ram) return EventText.pagesFrom(labels,PewterSlice.text,ram) end
function SourceEventBaselinePewter.pickupFlag(id) assert(pickups[id],"unknown source pickup");return "PICKUP:"..id end
function SourceEventBaselinePewter.isPickup(id) return pickups[id]~=nil end
function SourceEventBaselinePewter.has(id)
    return simple[id]~=nil or pickups[id]~=nil or trainerBefore[id]~=nil or id=="pokered:PEWTER_MART:objects:1" or id=="pokered:PEWTER_POKECENTER:objects:1"
end
function SourceEventBaselinePewter.plan(id,state)
    assert(SourceEventBaselinePewter.has(id) and state.intro=="done","unsupported or gated Pewter source event")
    local plan={id=id,status="ready",steps={},source_content="pewter"}
    local function dialog(labels,confirmed) plan.steps[#plan.steps+1]={op=confirmed and "confirmed-dialog" or "dialog",labels=labels} end
    if simple[id] then dialog({simple[id]})
    elseif pickups[id] then
        local item,flag=pickups[id],SourceEventBaselinePewter.pickupFlag(id)
        if state.flags[flag] then plan.status="already-complete"
        elseif not state.can_add[item] then plan.status="pickup-full";dialog({"_NoMoreRoomForItemText"})
        else
            plan.expected={flags={[flag]=false},items={[item]=state.items[item]}}
            plan.changes={flags={[flag]=true},items={{op="add",id=item,quantity=1}}}
            plan.ram={wStringBuffer=assert(ItemData.definitions[item]).name}
            plan.steps[1]={op="receipt",labels={"_FoundItemText"}}
            plan.failure_labels={"_NoMoreRoomForItemText"};plan.pickup=id
        end
    elseif trainerBefore[id] then
        if state.receipt then
            local d=assert(PewterSlice.trainer(id))
            local won=d.id==TrainerEvents.BROCK and {"_PewterGymBrockReceivedBoulderBadgeText","_PewterGymBrockBoulderBadgeInfoText"} or {"_"..d.dialogue_script_labels.won}
            dialog(won,true);plan.ram={wAmountMoneyWon=state.receipt.payout};dialog({"_MoneyForWinningText"},true)
        end
        if not state.trainers[id] then
            plan.status="trainer-battle";plan.steps[#plan.steps+1]={op="trainer",id=id,before={trainerBefore[id]},mode=state.mode or "talk"}
        elseif id==TrainerEvents.BROCK and not state.flags.EVENT_GOT_TM34 then
            dialog({"_PewterGymBrockWaitTakeThisText"})
            if state.can_add.tm34 then
                plan.expected={flags={EVENT_GOT_TM34=false},items={tm34=state.items.tm34},trainers={[id]=true}}
                plan.changes={flags={EVENT_GOT_TM34=true},items={{op="add",id="tm34",quantity=1}},trainers={}}
                plan.steps[#plan.steps+1]={op="receipt",labels={"_PewterGymReceivedTM34Text","_TM34ExplanationText"}}
                plan.failure_labels={"_PewterGymTM34NoRoomText"}
            else dialog({"_PewterGymTM34NoRoomText"});plan.status="tm-full-retry" end
        elseif not state.receipt then
            local d=assert(PewterSlice.trainer(id));dialog({id==TrainerEvents.BROCK and "_PewterGymBrockPostBattleAdviceText" or "_"..d.dialogue_script_labels.after})
        end
    elseif id=="pokered:PEWTER_MART:objects:1" then plan.steps={{op="shop",id="pewterMartClerkText"}}
    else plan.steps={{op="heal",id="pewterPokecenter",nurse_id=id,checkpoint={zone_id="pokered:PEWTER_CITY",x=13,y=26,facing="down"},
        welcome="_PokemonCenterWelcomeText",prompt="_ShallWeHealYourPokemonText",before="_NeedYourPokemonText",after="_PokemonFightingFitText",farewell="_PokemonCenterFarewellText"}} end
    return plan
end
function SourceEventBaselinePewter.afterCommit(game,plan)
    if plan.pickup then
        for _,npc in ipairs(game.npcManager.npcs) do
            if npc.def and npc.def.source_event_id==plan.pickup then game.npcManager:removeNPC(npc);break end
        end
    end
end
