local stageMultipliers = {
    [-6] = 2/8, [-5] = 2/7, [-4] = 2/6, [-3] = 2/5, [-2] = 2/4, [-1] = 2/3,
    [0] = 2/2,
    [1] = 3/2, [2] = 4/2, [3] = 5/2, [4] = 6/2, [5] = 7/2, [6] = 8/2
}

function applyStageMod(stat, stage)
    stage = math.max(-6, math.min(6, stage))
    return math.floor(stat * stageMultipliers[stage])
end

function calcDamage(attacker, defender, move)
    if move.power == 0 then return 0 end
    local atkStat = applyStageMod(attacker.atk, attacker.statStages.atk)
    local defStat = applyStageMod(defender.def, defender.statStages.def)
    local damage = math.floor((((2 * attacker.level / 5 + 2) * move.power * atkStat / defStat) / 50) + 2)
    damage = math.floor(damage * (math.random(85, 100) / 100))
    return math.max(1, damage)
end

Class("Battle"):includes(Signal)

-- Battle sub-states
local BSTATE_INTRO = "intro"
local BSTATE_MENU = "menu"
local BSTATE_MOVE_SELECT = "moveSelect"
local BSTATE_EXECUTE_TURN = "executeTurn"
local BSTATE_SHOW_MESSAGE = "showMessage"
local BSTATE_VICTORY = "victory"
local BSTATE_DEFEAT = "defeat"

function Battle:init(playerPokemon, enemyPokemon)
    self.player = playerPokemon
    self.enemy = enemyPokemon
    self.state = BSTATE_SHOW_MESSAGE
    self.message = ""
    self.messageTimer = 0
    self.messageCallback = nil
    self.turnQueue = {}
    self.turnIndex = 0
    self.flashTimer = 0
    self.isFlashing = false
    self.message = "A wild " .. self.enemy.name .. " appeared!"
    self.messageCallback = function()
        self.state = BSTATE_MENU
    end
end

function Battle:showMessage(msg, callback)
    self.state = BSTATE_SHOW_MESSAGE
    self.message = msg
    self.messageTimer = 0
    self.messageCallback = callback
end

function Battle:handleInput()
    if self.state == BSTATE_SHOW_MESSAGE then
        self.messageTimer = self.messageTimer + 1
        if playdate.buttonJustPressed(playdate.kButtonA) and self.messageTimer > 10 then
            if self.messageCallback then
                self.messageCallback()
            end
        end
        return
    end

    if self.state == BSTATE_VICTORY or self.state == BSTATE_DEFEAT then
        if playdate.buttonJustPressed(playdate.kButtonA) then
            self:emit("battleEnd", self.state == BSTATE_VICTORY)
        end
        return
    end

    -- Menu and move select handled by battleScene
end

function Battle:selectMove(moveIndex)
    local playerMove = moveData[self.player.moves[moveIndex]]
    local enemyMoveKey = self.enemy.moves[math.random(1, #self.enemy.moves)]
    local enemyMove = moveData[enemyMoveKey]

    -- Determine turn order by speed
    local playerSpd = applyStageMod(self.player.spd, self.player.statStages.atk) -- speed not affected by stages in this simplified version
    local enemySpd = applyStageMod(self.enemy.spd, self.enemy.statStages.atk)

    self.turnQueue = {}

    if playerSpd >= enemySpd then
        table.insert(self.turnQueue, { attacker = "player", move = playerMove, moveKey = self.player.moves[moveIndex] })
        table.insert(self.turnQueue, { attacker = "enemy", move = enemyMove, moveKey = enemyMoveKey })
    else
        table.insert(self.turnQueue, { attacker = "enemy", move = enemyMove, moveKey = enemyMoveKey })
        table.insert(self.turnQueue, { attacker = "player", move = playerMove, moveKey = self.player.moves[moveIndex] })
    end

    self.turnIndex = 0
    self:executeNextTurn()
end

function Battle:executeNextTurn()
    self.turnIndex = self.turnIndex + 1
    if self.turnIndex > #self.turnQueue then
        self.state = BSTATE_MENU
        return
    end

    local turn = self.turnQueue[self.turnIndex]
    local attacker, defender
    local attackerName, defenderName

    if turn.attacker == "player" then
        attacker = self.player
        defender = self.enemy
        attackerName = self.player.name
        defenderName = self.enemy.name
    else
        attacker = self.enemy
        defender = self.player
        attackerName = self.enemy.name
        defenderName = self.player.name
    end

    local move = turn.move

    self:showMessage(attackerName .. " used " .. move.name .. "!", function()
        if move.power > 0 then
            -- Damage move
            local damage = calcDamage(attacker, defender, move)
            defender:takeDamage(damage)
            self.isFlashing = true
            self.flashTimer = 6

            self:showMessage(defenderName .. " took " .. damage .. " damage!", function()
                if not defender:isAlive() then
                    self:showMessage(defenderName .. " fainted!", function()
                        if turn.attacker == "player" then
                            self.state = BSTATE_VICTORY
                            self.message = "You won the battle!"
                        else
                            self.state = BSTATE_DEFEAT
                            self.message = "You blacked out..."
                        end
                    end)
                else
                    self:executeNextTurn()
                end
            end)
        elseif move.effect then
            -- Stat effect move
            local target
            local targetName
            if move.effect.target == "enemy" then
                if turn.attacker == "player" then
                    target = self.enemy
                    targetName = "Enemy " .. self.enemy.name
                else
                    target = self.player
                    targetName = self.player.name
                end
            else
                if turn.attacker == "player" then
                    target = self.player
                    targetName = self.player.name
                else
                    target = self.enemy
                    targetName = "Enemy " .. self.enemy.name
                end
            end

            local stat = move.effect.stat
            target.statStages[stat] = math.max(-6, math.min(6, target.statStages[stat] + move.effect.stages))

            local statNames = { atk = "ATTACK", def = "DEFENSE" }
            local direction = move.effect.stages < 0 and "fell" or "rose"

            self:showMessage(targetName .. "'s " .. statNames[stat] .. " " .. direction .. "!", function()
                self:executeNextTurn()
            end)
        else
            self:executeNextTurn()
        end
    end)
end

function Battle:tryRun()
    self:showMessage("Can't escape!", function()
        -- Enemy gets a free turn
        local enemyMoveKey = self.enemy.moves[math.random(1, #self.enemy.moves)]
        local enemyMove = moveData[enemyMoveKey]
        self.turnQueue = {{ attacker = "enemy", move = enemyMove, moveKey = enemyMoveKey }}
        self.turnIndex = 0
        self:executeNextTurn()
    end)
end
