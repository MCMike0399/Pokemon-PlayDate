local stageMultipliers = {
    [-6] = 2/8, [-5] = 2/7, [-4] = 2/6, [-3] = 2/5, [-2] = 2/4, [-1] = 2/3,
    [0] = 2/2,
    [1] = 3/2, [2] = 4/2, [3] = 5/2, [4] = 6/2, [5] = 7/2, [6] = 8/2
}

function applyStageMod(stat, stage)
    stage = math.max(-6, math.min(6, stage))
    return math.floor(stat * stageMultipliers[stage])
end

-- Full Gen I damage formula with STAB, type effectiveness, crits
function calcDamage(attacker, defender, move)
    if move.power == 0 then return { damage = 0, effectiveness = 1, isCrit = false, isSTAB = false } end

    -- Pick physical or special stats
    local atkStat, defStat
    if move.category == "special" then
        atkStat = applyStageMod(attacker.spc, attacker.statStages.spc)
        defStat = applyStageMod(defender.spc, defender.statStages.spc)
    else
        atkStat = applyStageMod(attacker.atk, attacker.statStages.atk)
        defStat = applyStageMod(defender.def, defender.statStages.def)
    end

    -- Critical hit: Gen I base rate ~6.25% (speed/512, simplified to 1/16)
    local isCrit = math.random(1, 16) == 1
    local critMult = isCrit and 2.0 or 1.0

    -- STAB (Same Type Attack Bonus)
    local isSTAB = (attacker.type == move.type) or (attacker.type2 and attacker.type2 == move.type)
    local stabMult = isSTAB and 1.5 or 1.0

    -- Type effectiveness
    local effectiveness = TypeChart.getMatchup(move.type, defender.type, defender.type2)

    -- Random factor 85-100%
    local rand = math.random(85, 100) / 100

    -- Gen I damage formula
    local level = attacker.level
    local damage = math.floor(
        (((2 * level * critMult / 5 + 2) * move.power * atkStat / defStat) / 50) + 2
    )
    damage = math.floor(damage * stabMult)
    damage = math.floor(damage * effectiveness)
    damage = math.floor(damage * rand)
    damage = math.max(1, damage)

    -- Immune = 0 damage
    if effectiveness == 0 then damage = 0 end

    return {
        damage = damage,
        effectiveness = effectiveness,
        isCrit = isCrit,
        isSTAB = isSTAB,
    }
end

-- Accuracy check
function checkAccuracy(move)
    return math.random(1, 100) <= move.accuracy
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
    self.shakeTimer = 0
    self.shakeIntensity = 0
    self.runAttempts = 0
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

    -- Determine turn order by speed (using spd stat stage)
    local playerSpd = applyStageMod(self.player.spd, self.player.statStages.spd)
    local enemySpd = applyStageMod(self.enemy.spd, self.enemy.statStages.spd)

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
            -- Accuracy check
            if not checkAccuracy(move) then
                self:showMessage(attackerName .. "'s attack missed!", function()
                    self:executeNextTurn()
                end)
                return
            end

            -- Damage move
            local result = calcDamage(attacker, defender, move)

            if result.effectiveness == 0 then
                self:showMessage("It doesn't affect " .. defenderName .. "...", function()
                    self:applyMoveEffects(move, attacker, defender, function()
                        self:executeNextTurn()
                    end)
                end)
                return
            end

            defender:takeDamage(result.damage)
            self.isFlashing = true
            self.flashTimer = 6

            -- Screen shake on crit
            if result.isCrit then
                self.shakeTimer = 8
                self.shakeIntensity = 3
            end

            -- Build message chain
            local function afterDamageMsg()
                local function afterEffectiveness()
                    local function afterCrit()
                        self:applyMoveEffects(move, attacker, defender, function()
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
                    end

                    if result.isCrit then
                        self:showMessage("A critical hit!", afterCrit)
                    else
                        afterCrit()
                    end
                end

                if result.effectiveness > 1 then
                    self:showMessage("It's super effective!", afterEffectiveness)
                elseif result.effectiveness < 1 then
                    self:showMessage("It's not very effective...", afterEffectiveness)
                else
                    afterEffectiveness()
                end
            end

            self:showMessage(defenderName .. " took " .. result.damage .. " damage!", afterDamageMsg)

        elseif move.effects then
            -- Status move: apply effects directly
            self:applyMoveEffects(move, attacker, defender, function()
                self:executeNextTurn()
            end)
        else
            self:executeNextTurn()
        end
    end)
end

-- Apply extra effects from a move (stat changes, status conditions, etc.)
function Battle:applyMoveEffects(move, attacker, defender, callback)
    if not move.effects or #move.effects == 0 then
        callback()
        return
    end

    local results = {}
    for _, effect in ipairs(move.effects) do
        local r = effect:apply(attacker, defender)
        if r then
            table.insert(results, r)
        end
    end

    self:showEffectResults(results, 1, callback)
end

function Battle:showEffectResults(results, index, callback)
    if index > #results then
        callback()
        return
    end

    local r = results[index]
    local msg = nil

    if r.type == "statChange" then
        local statNames = { atk = "ATTACK", def = "DEFENSE", spc = "SPECIAL", spd = "SPEED" }
        local direction = r.stages < 0 and "fell" or "rose"
        local targetName = r.pokemon.name
        msg = targetName .. "'s " .. statNames[r.stat] .. " " .. direction .. "!"
    elseif r.type == "status" then
        local statusNames = { burn = "was burned", poison = "was poisoned", paralysis = "is paralyzed" }
        msg = r.pokemon.name .. " " .. (statusNames[r.status] or "was afflicted") .. "!"
    end

    if msg then
        self:showMessage(msg, function()
            self:showEffectResults(results, index + 1, callback)
        end)
    else
        self:showEffectResults(results, index + 1, callback)
    end
end

function Battle:tryRun()
    self.runAttempts = self.runAttempts + 1

    -- Gen I run formula
    local playerSpd = self.player.spd
    local enemySpd = self.enemy.spd
    local runChance = math.floor((playerSpd * 32) / (math.max(1, math.floor(enemySpd / 4)) % 256) + 30 * self.runAttempts)

    if runChance > 255 or math.random(0, 255) < runChance then
        self:showMessage("Got away safely!", function()
            self:emit("battleEnd", false)
        end)
    else
        self:showMessage("Can't escape!", function()
            -- Enemy gets a free turn
            local enemyMoveKey = self.enemy.moves[math.random(1, #self.enemy.moves)]
            local enemyMove = moveData[enemyMoveKey]
            self.turnQueue = {{ attacker = "enemy", move = enemyMove, moveKey = enemyMoveKey }}
            self.turnIndex = 0
            self:executeNextTurn()
        end)
    end
end
