-- Actual production owner/controller interfaces. No private receipt injection.
EventReceiptContracts={}
local function eq(a,b)assert(a==b,"expected "..tostring(b)..", got "..tostring(a))end
local function clear(machine)
    for i=#machine.stack,1,-1 do machine.stack[i]:exit();machine.stack[i]=nil end
end
function EventReceiptContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local oldZone=currentZone;local oldStory=Story.currentContext();local oldRng=RulesRNG.toData();local oldOwner=GameSession.activeRNGSession()
    local oldSprites=playdate.graphics.sprite.spriteCount();local drawX,drawY=playdate.graphics.getDrawOffset()
    local game
    local ok,problem=pcall(function()
        game=GameContext();assert(game:recruit(Pokemon("squirtle",5)));assert(game.session:activateRNG())
        assert(game.session:setIntro({stage="done",starter="squirtle",rivalStarter="bulbasaur"}))
        local id="pokered:VIRIDIAN_FOREST:objects:2";local def=assert(PewterSlice.trainer(id));local rows={}
        for y=1,8 do rows[y]={};for x=1,13 do rows[y][x]=25 end end
        currentZone=Zone({id=def.map_id,name="native receipt contract plane",tiles=rows,width=13,height=8})
        game.player=Player(3,4,currentZone.collision,game.npcManager)
        SliceSprites.install();local npc=NPC(6,4,def.name,{},nil,SliceSprites.key("SPRITE_YOUNGSTER"),"left")
        npc.def={source_event_id=id};game.npcManager:addNPC(npc)
        game.trainers=TrainerEvents(game);local owner=game.trainers
        local token=assert(owner:prepare(npc,"sight"))
        for tick=1,16 do owner:updateApproach(token)end
        local enemies=assert(owner:launch(token))
        local battle=Battle(game:getPlayerPokemon(),enemies:active(),npc.name,{party=game.session:party(),session=game.session,enemyParty=enemies})
        assert(owner:attachBattle(token,battle))
        for _,mon in ipairs(enemies:members())do mon:takeDamage(mon.maxHP)end
        battle:runScript(function()return "victory"end)
        local accepted,receipt
        battle:on("battleEnd",function(won,kind)accepted,receipt=owner:resolve(token,won,kind)end)
        assert(battle:emitEnd());assert(accepted,receipt);eq(receipt.payout,60)
        local bag=game.session:inventory();local money=bag:money();eq(money,3060)
        local pending=assert(owner:peekReceipt(id));pending.payout=-1;eq(owner:peekReceipt(id).payout,60)
        local before=RulesRNG.toData()
        local first=EventState.observe(game,id,{mode="talk"})
        local second=EventState.observe(game,id,{mode="talk"})
        EventState.observe(game,"unrelated:source:id")
        eq(first.receipt,nil);eq(second.receipt,nil);eq(owner:peekReceipt(id).payout,60)
        eq(owner:peekReceipt("unrelated:source:id"),nil);eq(owner:peekReceipt(id).id,id)
        eq(bag:money(),money);eq(game.session:inventory(),bag);eq(game.session:trainerDefeated(id),true)
        local after=RulesRNG.toData();eq(after.seed,before.seed);eq(after.state,before.state);eq(after.rolls,before.rolls)
        game.machine:register("overworld",{})
        game.machine:register("dialog",DialogState(game));local event=game.machine:register("event",EventState(game))
        game.machine:change("overworld");game.machine:push("event",id)
        eq(game.machine:getCurrent(),"dialog");eq(owner:peekReceipt(id),nil)
        eq(event.plan.steps[1].op,"confirmed-dialog");eq(event.plan.steps[2].op,"confirmed-dialog")
        eq(owner:takeReceipt(id),nil);eq(bag:money(),money)
        EventState.observe(game,id);EventState.observe(game,id);eq(owner:peekReceipt(id),nil)
        -- Cancel native overlays without invoking presentation callbacks, then
        -- reenter through the real controller. Only ordinary after-talk remains.
        clear(game.machine);game.machine:change("overworld");game.machine:push("event",id)
        eq(event.plan.steps[1].op,"dialog")
        for _,step in ipairs(event.plan.steps)do assert(step.op~="confirmed-dialog"and step.op~="trainer","repeat duplicated receipt or battle")end
        eq(bag:money(),money);eq(game.session:trainerDefeated(id),true);eq(owner:takeReceipt(id),nil)
    end)
    if game then
        clear(game.machine);game.npcManager:clear()
        if game.player then game.player:remove();game.player.grassOverlay:remove();game.player.exitArrow:remove()end
    end
    local active=GameSession.activeRNGSession();if active then assert(active:deactivateRNG()) end
    if oldOwner then assert(oldOwner:activateRNG()) end
    currentZone=oldZone;Story.bind(oldStory);RulesRNG.restoreData(oldRng);playdate.graphics.setDrawOffset(drawX,drawY)
    if playdate.graphics.sprite.spriteCount()~=oldSprites then ok=false;problem="receipt contract leaked native sprites"end
    report.ok=ok;report.passed=ok and 1 or 0;report.failed=ok and 0 or 1
    report.tests[1]={name="pure observations preserve pending source victory receipt and Event entry claims presentation once",ok=ok,error=not ok and tostring(problem)or nil}
    return report
end
