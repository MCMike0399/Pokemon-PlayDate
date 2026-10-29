-- game/battleState.lua — Battle as a top-level state
--
-- Replaces the whole stack (the overworld tears down; OverworldState saves
-- the player's position and restores it afterwards). Owns a Battle (rules +
-- its own phase machine) and a BattleScene (rendering + menus).
--
-- Outcomes:
--   victory / ran away — back to the overworld where the player stood
--   defeat (blackout)  — pokemon fully restored, respawn at the zone spawn

Class("BattleState"):extends(State)

-- Bespoke registrations omit class_source; their stable identities supply
-- the source class without treating a displayed trainer name as metadata.
local bespokeTrainerClasses <const> = {
    ["authored:oaks_lab:npc:2"] = "OPP_RIVAL1",
    ["authored:pallet_town:npc:1"] = "OPP_RIVAL1",
    ["authored:test_zone:npc:2"] = "OPP_RIVAL1",
    ["pokered:ROUTE_22:objects:1"] = "OPP_RIVAL1",
    ["pokered:CERULEAN_CITY:objects:1"] = "OPP_RIVAL1",
    ["pokered:SS_ANNE_2F:objects:2"] = "OPP_RIVAL2",
    ["pokered:CERULEAN_GYM:objects:1"] = "OPP_MISTY",
    ["pokered:MT_MOON_B2F:objects:1"] = "OPP_SUPER_NERD",
    ["pokered:VERMILION_GYM:objects:1"] = "OPP_LT_SURGE",
}

function BattleState.trainerClassFor(id, definition)
    if definition and definition.class_source then
        return definition.class_source
    end
    return bespokeTrainerClasses[id]
end

function BattleState:init(game)
    BattleState.super.init(self, "battle")
    self.game = game
    self.npc = nil
    self.battle = nil
    self.scene = nil
end

function BattleState:enter(playerPokemon, enemyPokemon, npc, enemyParty)
    if BootTrace then
        BootTrace.mark("battle.start.begin")
    end
    local plan,reason=FieldBattle.prepare(self.game,playerPokemon,enemyPokemon,npc,enemyParty)
    assert(plan,reason)
    local battle,scene=FieldBattle.construct(plan)
    self.npc = npc
    if npc then
        local id = npc.trainerID or npc.def and npc.def.source_event_id
        local definition = self.game.trainers and self.game.trainers:definition(id)
        battle.trainerClass = BattleState.trainerClassFor(id, definition)
        scene.trainerClass = battle.trainerClass
    end
    self.finished=false;self.epoch=(self.epoch or 0)+1;self.trainerToken=nil
    self.battle,self.scene=battle,scene
    assert(self.game.session:beginPickupBattle(battle, npc and 1 or 0))
    playdate.graphics.sprite.removeAll()
    self.game.camera:reset()

    if self.game.trainers and npc then
        self.trainerToken=self.game.trainers:currentBattleToken(npc)
        if self.trainerToken then assert(self.game.trainers:attachBattle(self.trainerToken,self.battle))
        else local token,reason=self.game.trainers:adoptIntroBattle(npc,self.battle);assert(not reason,reason);self.trainerToken=token end
    end
    local ownedBattle,ownedSession,epoch=self.battle,self.game.session,self.epoch
    self.battle:on("battleEnd", function(won, kind)
        if self.battle==ownedBattle and self.game.session==ownedSession and self.epoch==epoch then self:finish(won,kind) end
    end)
    if BootTrace then
        BootTrace.mark("battle.start.end")
        if DEVICE_TEST_BUILD then
            BootTrace.collect("battle.live")
        end
    end
end

function BattleState:finish(won, kind)
    if self.finished then return false,"already-finished" end
    local game = self.game
    kind = kind or (self.battle and self.battle.outcome) or (won and "victory" or "defeat")
    assert(self.battle:flushRewards()) -- Before economic/learning/evolution/blackout return owners.
    local pokemon = game:getPlayerPokemon()
    local party=game.session:party()
    local blackout=party:allFainted()
    local introRival=Story.get(game).stage=="rival_fight"
    local receipt
    local beforeMoney=game.session:inventory():money()
    if game.trainers then
        assert(self.battle and self.battle.emittingEnd and self.battle.outcome==kind and won==(kind=="victory"),"confirmed terminal battle required for economic outcome")
        if self.trainerToken then
            local accepted,result=game.trainers:resolve(self.trainerToken,won,kind);assert(accepted,result);receipt=result
        end
        if blackout and not introRival and not (receipt and receipt.blackout_money_applied) then
            assert(game.session:halveMoneyOnBlackout(game.session:inventory():money()))
        end
    end
    local pickupOK, pickupReceipt = game.session:resolvePickupBattle(self.battle, won, kind)
    assert(pickupOK, pickupReceipt)
    self.finished=true
    if Evolution then assert(Evolution.afterBattle(game.session,kind)) end
    game.lastBattleOutcome = {kind = kind, won = won, blackout = blackout,
        player_hp = pokemon.hp, enemy_hp = self.battle and self.battle.enemy.hp or nil,
        pickup = pickupReceipt,
        trainer_id=receipt and receipt.id or nil,
        payout=receipt and receipt.payout or 0,money_delta=game.session:inventory():money()-beforeMoney}
    if won and self.npc and not self.trainerToken then
        self.npc:markInteracted()
    end
    Story.notifyBattleEnd(game, won, kind)

    pokemon:resetStages()
    if self.battle then self.battle.enemy:resetStages() end

    if introRival then party:healAll() end -- Original lab script heals after either result.
    if blackout then
        party:healAll()
        assert(party:switch(assert(party:firstUsable())))
        if introRival then self.machine:change("overworld",{respawn=true})
        else game:returnToCheckpoint() end
    else
        -- A final recoil victory may leave a fainted lead with usable reserves.
        if not pokemon:isAlive() then assert(party:switch(assert(party:firstUsable()))) end
        self.machine:change("overworld")
    end
    if game.trainers then game.trainers:restoreReturnedTrainer() end
    game:offerPartyLearning(function()
        if not receipt then return end
        if not receipt.won then
            local descriptor = SourceEvents.descriptor(receipt.id)
            if descriptor and descriptor.lost then
                local lines = {}
                for _, page in ipairs(SourceEvents.pages(receipt.id,descriptor.lost)) do lines[#lines+1] = page.text end
                game.machine:push("dialog",lines)
            end
            return
        end
        if receipt.initial_lab then
            if game.trainers:takeReceipt(TrainerEvents.LAB) then
                local lines={};for _,page in ipairs(PewterEvents.pages({"_MoneyForWinningText"},{wAmountMoneyWon=receipt.payout})) do lines[#lines+1]=page.text end
                game.machine:push("dialog",lines)
            end
        elseif game.machine:getCurrent()=="overworld" and currentZone.stableID==receipt.zone_id then
            KantoWorld.dispatch(game,receipt.id)
        end
    end)
end

function BattleState:exit()
    self.epoch=(self.epoch or 0)+1
    if self.trainerToken and self.game.trainers then self.game.trainers:abortBattle(self.trainerToken) end
    self.trainerToken=nil
    if self.battle then self.battle:cancelPendingLearning() end
    self.learningRequest = nil
    if self.battle and not self.battle.emittingEnd then self.battle:clearVolatiles() end
    if self.scene then self.scene:exit() end
    playdate.display.setOffset(0, 0)
    if self.battle then
        for _, mon in ipairs(self.game.session:party():members()) do mon:resetStages() end
        self.battle.enemy:resetStages()
        if not self.battle.emittingEnd then self.battle:clearListeners() end
    end
    self.battle = nil
    self.scene = nil
    self.npc = nil
end

function BattleState:update()
    if not self:isTop() or not self.battle then return end
    local battle = self.battle
    battle:update()
    if self.battle ~= battle then return end
    if self.scene then self.scene:update() end
    self:openPendingLearning()
    self:openSelection()
end

function BattleState:handleInput()
    if not self:isTop() then return end
    if self.scene then self.scene:handleInput() end
    self:openPendingLearning()
    self:openSelection()
end

function BattleState:draw()
    if self.scene then self.scene:draw() end
end

-- Present the real learning overlay without returning/replacing this battle.
function BattleState:openPendingLearning()
    if not self:isTop() or not self.battle or self.learningRequest then return false end
    local battle, session = self.battle, self.game.session
    local receipt, pokemon = battle:takeLearningRequest()
    if not receipt then return false end
    self.learningRequest = receipt
    assert(LearningState.open(self.game, pokemon, function()
        if self.learningRequest ~= receipt then return end
        if self.battle ~= battle or self.game.session ~= session or not self:isTop() then
            self.learningRequest = nil
            battle:cancelPendingLearning()
            return
        end
        self.learningRequest = nil
        assert(battle:resumeLearning(receipt))
    end, {waitForRelease=true}), "suspended battle requires pending learning")
    return true
end

function BattleState:openSelection()
    if not self:isTop() or not self.scene then return end
    local request = self.scene:takeSelectionRequest()
    if not request then return end
    local battle, scene, session = self.battle, self.scene, self.game.session
    local function current()
        return self.battle == battle and self.scene == scene and self.game.session == session
    end
    local function select(value,partyIndex,moveSlot)
        if not current() then return false, "stale-selection" end
        local ok, reason
        if request.kind == "party" then ok, reason = battle:chooseParty(value)
        elseif partyIndex~=nil then ok, reason = battle:useItem(value,partyIndex,moveSlot)
        else ok, reason = battle:throwBall(value) end
        if ok then assert(scene:completeSelection()) end
        return ok, reason
    end
    local function cancel()
        if not current() then return false, "stale-selection" end
        return scene:completeSelection(true)
    end
    self.machine:push(request.kind == "party" and "party" or "bag",
        {prompt = "Choose a POKEMON!", allowCancel = not request.forced, trySelect = select, tryCancel = cancel, battle = battle})
end
