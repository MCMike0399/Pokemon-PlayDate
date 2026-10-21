-- Bounded source handlers for the reviewed Route2/Forest/Pewter milestone.
-- Escort/tutorial/audio/link mechanics outside this milestone stay explicit.
PewterEvents={}
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
function PewterEvents.pages(labels,ram) return EventText.pagesFrom(labels,PewterSlice.text,ram) end
function PewterEvents.pickupFlag(id) assert(pickups[id],"unknown source pickup");return "PICKUP:"..id end
function PewterEvents.isPickup(id) return pickups[id]~=nil end
function PewterEvents.has(id)
    return simple[id]~=nil or pickups[id]~=nil or trainerBefore[id]~=nil or id=="pokered:PEWTER_MART:objects:1" or id=="pokered:PEWTER_POKECENTER:objects:1"
end
function PewterEvents.plan(id,state)
    assert(PewterEvents.has(id) and state.intro=="done","unsupported or gated Pewter source event")
    local plan={id=id,status="ready",steps={},source_content="pewter"}
    local function dialog(labels,confirmed) plan.steps[#plan.steps+1]={op=confirmed and "confirmed-dialog" or "dialog",labels=labels} end
    if simple[id] then dialog({simple[id]})
    elseif pickups[id] then
        local item,flag=pickups[id],PewterEvents.pickupFlag(id)
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
function PewterEvents.afterCommit(game,plan)
    if plan.pickup then
        for _,npc in ipairs(game.npcManager.npcs) do
            if npc.def and npc.def.source_event_id==plan.pickup then game.npcManager:removeNPC(npc);break end
        end
    end
end
