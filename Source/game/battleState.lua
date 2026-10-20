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

function BattleState:init(game)
    BattleState.super.init(self, "battle")
    self.game = game
    self.npc = nil
    self.battle = nil
    self.scene = nil
end

function BattleState:enter(playerPokemon, enemyPokemon, npc, enemyParty)
    self.npc = npc
    playdate.graphics.sprite.removeAll()
    self.game.camera:reset()
    playerPokemon:resetStages()

    self.battle = Battle(playerPokemon, enemyPokemon, npc and npc.name,
        {party = self.game.session:party(), session = self.game.session, enemyParty = enemyParty})
    self.scene = BattleScene(self.battle)

    self.battle:on("battleEnd", function(won, kind)
        self:finish(won, kind)
    end)
    assert(self.game.session:markSeen(enemyPokemon.species))
end

function BattleState:finish(won, kind)
    local game = self.game
    kind = kind or (self.battle and self.battle.outcome) or (won and "victory" or "defeat")
    local pokemon = game:getPlayerPokemon()
    local party=game.session:party()
    local blackout=party:allFainted()
    local introRival=Story.get(game).stage=="rival_fight"
    game.lastBattleOutcome = {kind = kind, won = won, blackout = blackout,
        player_hp = pokemon.hp, enemy_hp = self.battle and self.battle.enemy.hp or nil}
    if won and self.npc then
        self.npc:markInteracted()
    end
    Story.notifyBattleEnd(game, won, kind)

    pokemon:resetStages()
    if self.battle then self.battle.enemy:resetStages() end

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
    game:offerPartyLearning()
end

function BattleState:exit()
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
    self:openSelection()
end

function BattleState:handleInput()
    if self.scene then self.scene:handleInput() end
    self:openSelection()
end

function BattleState:draw()
    if self.scene then self.scene:draw() end
end

function BattleState:openSelection()
    if not self:isTop() or not self.scene then return end
    local request = self.scene:takeSelectionRequest()
    if not request then return end
    local battle, scene, session = self.battle, self.scene, self.game.session
    local function current()
        return self.battle == battle and self.scene == scene and self.game.session == session
    end
    local function select(value)
        if not current() then return false, "stale-selection" end
        local ok, reason
        if request.kind == "party" then ok, reason = battle:chooseParty(value)
        else ok, reason = battle:throwBall(value) end
        if ok then assert(scene:completeSelection()) end
        return ok, reason
    end
    local function cancel()
        if not current() then return false, "stale-selection" end
        return scene:completeSelection(true)
    end
    self.machine:push(request.kind == "party" and "party" or "bag",
        {prompt = "Choose a POKEMON!", allowCancel = not request.forced, trySelect = select, tryCancel = cancel})
end
