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

function BattleState:enter(playerPokemon, enemyPokemon, npc)
    self.npc = npc
    playdate.graphics.sprite.removeAll()
    self.game.camera:reset()
    playerPokemon:resetStages()

    self.battle = Battle(playerPokemon, enemyPokemon, npc and npc.name)
    self.scene = BattleScene(self.battle)

    self.battle:on("battleEnd", function(won, kind)
        self:finish(won, kind)
    end)
end

function BattleState:finish(won, kind)
    local game = self.game
    kind = kind or (self.battle and self.battle.outcome) or (won and "victory" or "defeat")
    local pokemon = game.playerPokemon
    game.lastBattleOutcome = {kind = kind, won = won, blackout = not pokemon:isAlive(),
        player_hp = pokemon.hp, enemy_hp = self.battle and self.battle.enemy.hp or nil}
    if won and self.npc then
        self.npc:markInteracted()
    end
    Story.notifyBattleEnd(won, kind)

    pokemon:resetStages()
    if self.battle then self.battle.enemy:resetStages() end

    if not pokemon:isAlive() then
        -- Blacked out: classic Pokemon behavior — heal up, respawn at spawn
        pokemon:fullRestore()
        self.machine:change("overworld", { respawn = true })
    else
        self.machine:change("overworld")
    end
    game:offerLearning(pokemon)
end

function BattleState:exit()
    playdate.display.setOffset(0, 0)
    if self.battle then
        self.battle.player:resetStages()
        self.battle.enemy:resetStages()
        if not self.battle.emittingEnd then self.battle:clearListeners() end
    end
    self.battle = nil
    self.scene = nil
    self.npc = nil
end

function BattleState:update()
    self.battle:update()
    if self.scene then self.scene:update() end
end

function BattleState:handleInput()
    self.scene:handleInput()
end

function BattleState:draw()
    self.scene:draw()
end
