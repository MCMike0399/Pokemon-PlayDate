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

    self.battle:on("battleEnd", function(won)
        self:finish(won)
    end)
end

function BattleState:finish(won)
    local game = self.game
    if won and self.npc then
        self.npc:markInteracted()
    end
    Story.notifyBattleEnd(won)

    local pokemon = game.playerPokemon
    pokemon.status = nil
    pokemon.statusTurns = 0
    pokemon.confusion = nil
    pokemon.flinched = false

    if not pokemon:isAlive() then
        -- Blacked out: classic Pokemon behavior — heal up, respawn at spawn
        pokemon:fullRestore()
        self.machine:change("overworld", { respawn = true })
    else
        self.machine:change("overworld")
    end
end

function BattleState:exit()
    playdate.display.setOffset(0, 0)
    self.battle = nil
    self.scene = nil
    self.npc = nil
end

function BattleState:update()
    self.battle:update()
end

function BattleState:handleInput()
    self.scene:handleInput()
end

function BattleState:draw()
    self.scene:draw()
end
