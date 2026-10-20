-- battle/battle.lua — Battle rules engine
--
-- The Battle owns a nested StateMachine with three phases:
--
--   command — waiting for the player (BattleScene shows FIGHT/RUN menus)
--   script  — a coroutine resolves the round; battle:say(msg) yields until
--             the player presses A, so turn logic reads as linear prose
--             instead of a callback pyramid
--   ended   — victory/defeat shown; A emits the "battleEnd" signal
--
-- Directionality (the attacker/defender "turn" idea from the OOP talk):
-- before each half-turn the battle sets attacker/defender, and every DSL
-- Target/Number/Condition/Effect resolves against that orientation, so each
-- effect is written once instead of once per side.

local stageMultipliers = {
    [-6] = 2/8, [-5] = 2/7, [-4] = 2/6, [-3] = 2/5, [-2] = 2/4, [-1] = 2/3,
    [0] = 2/2,
    [1] = 3/2, [2] = 4/2, [3] = 5/2, [4] = 6/2, [5] = 7/2, [6] = 8/2
}

function applyStageMod(stat, stage)
    stage = math.max(-6, math.min(6, stage))
    return math.floor(stat * stageMultipliers[stage])
end

-- Full Gen V (Black/White) damage formula. Differences from Gen I:
--   * physical/special is per MOVE (move.category from PokeAPI damage
--     classes), not per type
--   * crit is a x2 modifier applied to the finished base damage (Gen I
--     doubled the level term instead) and ignores stat stages that would
--     hurt the attacker (attacker's negative offensive / defender's
--     positive defensive stages)
--   * modifier order with flooring at each step:
--     crit -> random 85-100% -> STAB -> type -> burn
--   * burn halves physical damage
function calcDamage(attacker, defender, move)
    if move.power == 0 then return { damage = 0, effectiveness = 1, isCrit = false, isSTAB = false } end

    -- Crit roll first: it changes which stat stages count (1/16 base rate)
    local isCrit = move.willCrit or RulesRNG.random(1, 16) == 1

    -- Pick offensive/defensive stats per the move's damage class
    local atkBase, defBase, atkStage, defStage
    if move.category == "special" then
        atkBase, defBase = attacker.spa, defender.spd
        atkStage, defStage = attacker.statStages.spa, defender.statStages.spd
    else
        atkBase, defBase = attacker.atk, defender.def
        atkStage, defStage = attacker.statStages.atk, defender.statStages.def
    end

    -- Crits ignore stages unfavorable to the attacker
    if isCrit then
        if atkStage < 0 then atkStage = 0 end
        if defStage > 0 then defStage = 0 end
    end
    local atkStat = applyStageMod(atkBase, atkStage)
    local defStat = applyStageMod(defBase, defStage)

    -- STAB (Same Type Attack Bonus)
    local isSTAB = not move.typeless and (attacker.type == move.type or attacker.type2 == move.type)

    -- Type effectiveness
    local effectiveness = move.typeless and 1 or TypeChart.getMatchup(move.type, defender.type, defender.type2)

    -- Base damage
    local level = attacker.level
    local damage = math.floor(math.floor(
        math.floor(2 * level / 5 + 2) * move.power * atkStat / defStat
    ) / 50) + 2

    -- Modifier chain (Gen V order, floor after each step)
    if isCrit then
        damage = damage * 2
    end
    damage = math.floor(damage * RulesRNG.random(85, 100) / 100)
    if isSTAB then
        damage = math.floor(damage * 1.5)
    end
    damage = math.floor(damage * effectiveness)
    if attacker.status == "burn" and move.category == "physical" then
        damage = math.floor(damage / 2)
    end

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

-- Accuracy/evasion stage multipliers are 3-based (unlike the 2-based
-- regular stat stages)
local function accStageMult(stage)
    stage = math.max(-6, math.min(6, stage))
    if stage >= 0 then
        return (3 + stage) / 3
    end
    return 3 / (3 - stage)
end

-- Accuracy check: move accuracy scaled by attacker accuracy vs defender
-- evasion stages. accuracy == 0 means the move never misses (Swift etc.)
function checkAccuracy(move, attacker, defender)
    if move.accuracy == 0 then return true end
    local stage = attacker.statStages.acc - defender.statStages.eva
    local threshold = move.accuracy * accStageMult(stage)
    return RulesRNG.random(1, 100) <= threshold
end

-- ============================================================
-- BATTLE PHASE STATES
-- ============================================================

-- command: nothing to do here — BattleScene owns the menus and calls
-- battle:selectMove()/battle:tryRun() when the player picks
Class("BattleCommandPhase"):extends(State)
Class("BattleForcedSwitchPhase"):extends(State)

-- script: drives the resolution coroutine. Each battle:say() yield parks
-- the script on a message until the player confirms with A.
Class("BattleScriptPhase"):extends(State)

local MESSAGE_MIN_FRAMES <const> = 10

function BattleScriptPhase:init(battle)
    BattleScriptPhase.super.init(self, "script")
    self.battle = battle
end

function BattleScriptPhase:enter(co)
    self.co = co
    self.waiting = false
    self.messageTimer = 0
    self:advance()
end

function BattleScriptPhase:advance()
    local ok, kind, value = coroutine.resume(self.co)
    if not ok then
        error("battle script error: " .. tostring(kind))
    end

    if coroutine.status(self.co) == "dead" then
        -- Script finished; its return value names the next phase
        local outcome = kind or "command"
        if outcome == "victory" or outcome == "defeat" or outcome == "run" or outcome == "caught" then
            self.battle.outcome = outcome
            self.machine:change("ended", outcome)
            if outcome == "run" then self.battle:emitEnd() end
        elseif outcome == "forcedSwitch" then
            self.machine:change("forcedSwitch")
        else
            self.machine:change("command")
        end
        return
    end

    if kind == "say" then
        self.battle.message = value
        self.messageTimer = 0
        self.waiting = true
    end
end

function BattleScriptPhase:update()
    self.messageTimer = self.messageTimer + 1
end

function BattleScriptPhase:handleInput()
    if self.waiting and self.messageTimer > MESSAGE_MIN_FRAMES
       and playdate.buttonJustPressed(playdate.kButtonA) then
        self.waiting = false
        self:advance()
    end
end

-- ended: terminal message ("You won the battle!" / "You blacked out...");
-- A hands control back to whoever owns the battle via the battleEnd signal
Class("BattleEndedPhase"):extends(State)

function BattleEndedPhase:init(battle)
    BattleEndedPhase.super.init(self, "ended")
    self.battle = battle
end

function BattleEndedPhase:enter(kind)
    self.kind = kind
    self.won = kind == "victory"
end

function BattleEndedPhase:handleInput()
    if playdate.buttonJustPressed(playdate.kButtonA) then
        self.battle:emitEnd()
    end
end

-- ============================================================
-- BATTLE
-- ============================================================

Class("Battle"):includes(Signal)

-- trainerName (optional) makes this a trainer battle: intro messages
-- name the trainer and running is forbidden (Gen 1 rules)
function Battle:init(playerPokemon, enemyPokemon, trainerName, dependencies)
    dependencies = dependencies or {}
    assert(type(dependencies) == "table", "battle dependencies required")
    for key in pairs(dependencies) do assert(key == "party" or key == "session" or key == "enemyParty", "unsupported battle dependency") end
    self.session = dependencies.session
    self.party = dependencies.party or (self.session and self.session:party())
    self.enemyParty = dependencies.enemyParty
    if self.party then assert(self.party:is("Party") and self.party:active() == playerPokemon, "active player party mismatch") end
    if self.session then assert(self.session:is("GameSession") and self.session:party() == self.party, "battle session party mismatch") end
    if self.enemyParty then assert(trainerName and self.enemyParty:is("Party") and self.enemyParty:active() == enemyPokemon, "active trainer party mismatch") end
    self.player = playerPokemon
    self.enemy = enemyPokemon
    self.trainerName = trainerName
    self.selectionKind = nil
    self.captureResult = nil
    self.awardedEnemies = {}
    self.participants = {[playerPokemon]=true}

    -- Directionality: set per half-turn, consumed by the DSL
    self.attacker = nil
    self.defender = nil
    self.attackerSide = nil   -- "player" | "enemy"
    self.lastDamage = 0
    self.currentMove = nil
    self.currentMoveKey = nil
    self.outcome = nil
    self.endEmitted = false
    self.emittingEnd = false
    self.xpAwarded = false
    self.faintAnnounced = {}

    -- Scene-facing presentation state
    self.message = ""
    self.flashTimer = 0
    self.isFlashing = false
    self.shakeTimer = 0
    self.shakeIntensity = 0

    self.runAttempts = 0

    self.machine = StateMachine()
    self.machine:register("command", BattleCommandPhase("command"))
    self.machine:register("forcedSwitch", BattleForcedSwitchPhase("forcedSwitch"))
    self.machine:register("script", BattleScriptPhase(self))
    self.machine:register("ended", BattleEndedPhase(self))

    self:runScript(function()
        if self.trainerName then
            self:say(self.trainerName .. " wants to battle!")
            self:say(self.trainerName .. " sent out " .. self.enemy.name .. "!")
        else
            self:say("A wild " .. self.enemy.name .. " appeared!")
        end
        if not self.player:isAlive() then return self:hasUsablePlayer() and "forcedSwitch" or "defeat" end
    end)
end

function Battle:update()
    self.machine:update()
end

function Battle:handleInput()
    self.machine:handleInput()
end

function Battle:phase()
    return self.machine:getCurrent()
end

function Battle:isAwaitingCommand()
    return self.machine:is("command")
end

-- Start a resolution script. The function runs as a coroutine; battle:say()
-- inside it suspends until the player confirms the message.
function Battle:runScript(fn)
    self.machine:change("script", coroutine.create(fn))
end

-- Only callable from inside a script coroutine
function Battle:say(text)
    coroutine.yield("say", text)
end

function Battle:setDirection(side)
    self.attackerSide = side
    if side == "player" then
        self.attacker, self.defender = self.player, self.enemy
    else
        self.attacker, self.defender = self.enemy, self.player
    end
end

-- ============================================================
-- COMMANDS (called by BattleScene from the command phase)
-- ============================================================

-- Effective speed: stage-modified, quartered by paralysis (Gen V)
local function effectiveSpeed(pokemon)
    local speed = applyStageMod(pokemon.spe, pokemon.statStages.spe)
    if pokemon.status == "paralyze" then
        speed = math.floor(speed / 4)
    end
    return speed
end

-- Read-only choices. Struggle is a runtime fallback, never a learned PP slot.
function Battle:availableMoves(pokemon)
    local choices = {}
    for index, key in ipairs(pokemon.moves) do
        local move = moveData[key]
        if move and not move.noPP and pokemon:hasPP(key) then
            choices[#choices + 1] = {index = index, key = key, move = move}
        end
    end
    return choices
end

function Battle:needsStruggle(pokemon)
    return #self:availableMoves(pokemon or self.player) == 0
end

function Battle:emitEnd()
    if not self.outcome then return false, "not-ended" end
    if self.endEmitted then return false, "already-emitted" end
    self.endEmitted = true
    self.emittingEnd = true
    local ok, problem = pcall(self.emit, self, "battleEnd", self.outcome == "victory", self.outcome)
    self.emittingEnd = false
    self:clearListeners()
    if not ok then error(problem, 0) end
    return true
end

function Battle:enemyTurn()
    local choices = self:availableMoves(self.enemy)
    if #choices == 0 then return {side = "enemy", move = moveData.struggle} end
    local choice = choices[RulesRNG.random(1, #choices)]
    return {side = "enemy", move = choice.move, key = choice.key}
end

function Battle:selectStruggle()
    return self:selectMove(0)
end

function Battle:selectMove(moveIndex)
    -- All rejection paths precede every mutation and RNG draw.
    if not self:isAwaitingCommand() or self.outcome then return false, "wrong-phase" end
    if self.selectionKind then return false, "selection-open" end
    if not self.player:isAlive() or not self.enemy:isAlive() then return false, "fainted" end
    if type(moveIndex) ~= "number" or moveIndex ~= moveIndex or moveIndex < 0
        or moveIndex > #self.player.moves or moveIndex ~= math.floor(moveIndex) then return false, "invalid-index" end
    local playerMove, key
    if moveIndex == 0 then
        if not self:needsStruggle() then return false, "moves-available" end
        playerMove = moveData.struggle
    else
        key = self.player.moves[moveIndex]
        if moveIndex < 1 or not key then return false, "invalid-index" end
        playerMove = moveData[key]
        if not playerMove or playerMove.noPP then return false, "unknown-move" end
        if not self.player:hasPP(key) then return false, "no-pp" end
    end
    assert(playerMove, "Struggle definition must be generated")
    local playerTurn = {side = "player", move = playerMove, key = key}
    local enemyTurn = self:enemyTurn()
    local playerFirst
    if playerMove.priority ~= enemyTurn.move.priority then
        playerFirst = playerMove.priority > enemyTurn.move.priority
    else
        local playerSpeed, enemySpeed = effectiveSpeed(self.player), effectiveSpeed(self.enemy)
        if playerSpeed == enemySpeed then playerFirst = RulesRNG.random(1, 2) == 1
        else playerFirst = playerSpeed > enemySpeed end
    end
    local turns = playerFirst and {playerTurn, enemyTurn} or {enemyTurn, playerTurn}
    self:runScript(function() return self:resolveRound(turns) end)
    return true
end

-- Authoritative roster/selection commands. Rejections do not mutate or draw RNG.
function Battle:hasUsablePlayer()
    return self.party and self.party:firstUsable() ~= nil or self.player:isAlive()
end
function Battle:hasUsableEnemy()
    return self.enemyParty and self.enemyParty:firstUsable() ~= nil or self.enemy:isAlive()
end
function Battle:needsForcedSwitch()
    return self.machine:is("forcedSwitch")
end
function Battle:clearHitPresentation()
    self.attacker,self.defender,self.attackerSide=nil,nil,nil
    self.currentMove,self.currentMoveKey,self.lastDamage=nil,nil,0
    self.flashTimer,self.isFlashing,self.shakeTimer,self.shakeIntensity=0,false,0,0
end
function Battle:beginSelection(kind)
    if self.outcome or (not self:isAwaitingCommand() and not self:needsForcedSwitch()) then return false,"wrong-phase" end
    if self.selectionKind then return false,"selection-open" end
    if kind == "party" then
        if not self.party then return false,"party-unavailable" end
    elseif kind == "bag" then
        if self:needsForcedSwitch() then return false,"forced-switch" end
        if not self.session then return false,"bag-unavailable" end
    else return false,"unknown-selection" end
    self.selectionKind=kind
    return true
end
function Battle:cancelSelection()
    if self:needsForcedSwitch() then return false,"forced-switch" end
    if not self.selectionKind then return false,"no-selection" end
    self.selectionKind=nil
    return true
end
local function validSwitchSleep(mon)
    local remaining=type(mon.statusTurns)=="number" and math.tointeger(mon.statusTurns) or nil
    if mon.status ~= "sleep" then return mon.sleepDuration == 0 and remaining == 0 end
    local duration=type(mon.sleepDuration)=="number" and math.tointeger(mon.sleepDuration) or nil
    return duration and remaining and duration>=1 and duration<=3 and remaining>=0 and remaining<=duration
end
function Battle:chooseParty(index)
    local forced=self:needsForcedSwitch()
    if self.outcome or (not forced and not self:isAwaitingCommand()) then return false,"wrong-phase" end
    if self.selectionKind and self.selectionKind~="party" then return false,"selection-open" end
    if not self.party then return false,"party-unavailable" end
    index=type(index)=="number" and math.tointeger(index) or nil
    if not index then return false,"invalid-index" end
    local chosen,problem=self.party:get(index)
    if not chosen then return false,problem end
    if chosen==self.player then return false,"already-active" end
    if not chosen:isAlive() then return false,"fainted" end
    if not validSwitchSleep(self.player) or not validSwitchSleep(chosen) then return false,"invalid-sleep-duration" end
    if forced and self.player:isAlive() then return false,"replacement-not-required" end
    if not forced and (not self.player:isAlive() or not self.enemy:isAlive()) then return false,"fainted" end
    local old=self.player
    assert(self.party:switch(index))
    old:onSwitchOut()
    self.player=chosen
    chosen:resetStages()
    self.participants[chosen]=true
    self.faintAnnounced.player=nil
    self.selectionKind=nil
    self:clearHitPresentation()
    self:runScript(function()
        if not forced then self:say(old.name .. ", come back!") end
        self:say("Go! " .. chosen.name .. "!")
        if forced then return "command" end
        local outcome=self:resolveTurn(self:enemyTurn())
        if outcome and outcome~="replacement" then return outcome end
        return self:finishRound()
    end)
    return true
end
function Battle:availableBalls()
    local choices={}
    if not self.session then return choices end
    local inventory=self.session:inventory()
    for _,id in ipairs({"pokeBall","greatBall","ultraBall","masterBall"}) do
        local quantity=Inventory.quantity(inventory,id)
        if quantity and quantity>0 then choices[#choices+1]={id=id,quantity=quantity} end
    end
    return choices
end
function Battle:throwBall(ballId)
    if self.outcome or not self:isAwaitingCommand() then return false,"wrong-phase" end
    if self.selectionKind and self.selectionKind~="bag" then return false,"selection-open" end
    if self.trainerName then return false,"trainer-battle" end
    if not self.session then return false,"bag-unavailable" end
    if not self.player:isAlive() or not self.enemy:isAlive() then return false,"fainted" end
    if Party._owner(self.enemy) then return false,"already-owned-target" end
    local context={pokemon=self.enemy,wild=true}
    local dex=self.session:pokedex()
    local caughtCount=0;for _,owned in pairs(dex.owned) do if owned then caughtCount=caughtCount+1 end end
    local parameters,problem=Capture.parameters(context,ballId,caughtCount)
    if not parameters then return false,problem end
    local storage=self.session:storage()
    if self.party:count()>=Party.CAPACITY and storage:count()>=Storage.BOX_CAPACITY then return false,"storage-full" end
    local inventory=self.session:inventory()
    local quantity,why=Inventory.quantity(inventory,ballId)
    if not quantity or quantity<1 then return false,why or "insufficient-items" end
    local result,captureError=Capture.attempt(context,ballId,caughtCount,RulesRNG)
    if not result then return false,captureError end
    -- No yield/callback between preflight, trial RNG completion and these
    -- synchronous production commits. Same enemy identity enters the session.
    assert(Inventory.consume(inventory,ballId,1),"capture ball consumption invariant")
    if result.caught then
        self.enemy:resetStages()
        self:clearHitPresentation()
        local recruited,destination=GameSession.recruit(self.session,self.enemy)
        assert(recruited,"capture recruitment invariant: " .. tostring(destination))
        result.destination=destination
        self.caughtPokemon=self.enemy
    end
    self.captureResult=result
    self.selectionKind=nil
    local definition=ItemData.definitions[ballId]
    self:runScript(function()
        self:say("RED threw a " .. definition.name .. "!")
        if result.caught then
            self:say("Gotcha! " .. self.enemy.name .. " was caught!")
            self.message=self.enemy.name .. " was caught!"
            return "caught" -- Catching grants no XP in Gen V.
        end
        local message=result.displayShakes==0 and "Oh no! The POKEMON broke free!"
            or (result.displayShakes==1 and "Aww! It appeared to be caught!" or "Aargh! Almost had it!")
        self:say(message)
        local outcome=self:resolveTurn(self:enemyTurn())
        if outcome and outcome~="replacement" then return outcome end
        return self:finishRound()
    end)
    return true,result
end

function Battle:tryRun()
    if not self:isAwaitingCommand() or self.outcome then return false, "wrong-phase" end
    if self.selectionKind then return false, "selection-open" end
    if not self.player:isAlive() or not self.enemy:isAlive() then return false, "fainted" end
    -- Gen 1: no running from a trainer battle
    if self.trainerName then
        self:runScript(function()
            self:say("No! There's no running from a trainer battle!")
            return "command"
        end)
        return true
    end

    self.runAttempts = self.runAttempts + 1

    -- Gen III-V run formula: F = (A*128/B + 30*attempts) mod 256,
    -- escape if rand(0,255) < F
    local playerSpe = self.player.spe
    local enemySpe = math.max(1, self.enemy.spe)
    local runChance = math.floor(playerSpe * 128 / enemySpe + 30 * self.runAttempts) % 256

    if RulesRNG.random(0, 255) < runChance then
        self:runScript(function()
            self:say("Got away safely!")
            return "run"
        end)
    else
        self:runScript(function()
            self:say("Can't escape!")
            -- Enemy gets a free turn
            local outcome = self:resolveTurn(self:enemyTurn())
            if outcome and outcome ~= "replacement" then return outcome end
            return self:finishRound()
        end)
    end
    return true
end

-- ============================================================
-- ROUND RESOLUTION (runs inside the script coroutine)
-- Functions return nil to continue, or a terminal outcome:
-- "victory" | "defeat" | "command"
-- ============================================================

function Battle:resolveRound(turns)
    for _, turn in ipairs(turns) do
        local outcome = self:resolveTurn(turn)
        if outcome and outcome ~= "replacement" then return outcome end
    end
    return self:finishRound()
end

function Battle:resolveTurn(turn)
    self:setDirection(turn.side)
    local attacker = self.attacker

    -- Fainted by the earlier half-turn: skip
    if not attacker:isAlive() then return nil end

    -- Major status gates (Gen V)
    if attacker.status == "sleep" then
        if attacker.statusTurns > 0 then
            attacker.statusTurns = attacker.statusTurns - 1
            self:say(attacker.name .. " is fast asleep!")
            return nil
        end
        attacker.status, attacker.statusTurns, attacker.sleepDuration = nil, 0, 0
        self:say(attacker.name .. " woke up!")
    elseif attacker.status == "freeze" then
        if RulesRNG.random(1, 5) == 1 then
            attacker.status = nil
            attacker.statusTurns = 0
            attacker.sleepDuration = 0
            self:say(attacker.name .. " thawed out!")
            -- thawing lets the attack proceed
        else
            self:say(attacker.name .. " is frozen solid!")
            return nil
        end
    end

    if attacker.flinched then
        attacker.flinched = false
        self:say(attacker.name .. " flinched and couldn't move!")
        return nil
    end

    -- Confusion (volatile, decrements per attacking turn; 50% self-hit
    -- with a 40-power typeless physical attack)
    if attacker.confusion then
        if attacker.confusion <= 0 then
            attacker.confusion = nil
            self:say(attacker.name .. " snapped out of its confusion!")
        else
            attacker.confusion = attacker.confusion - 1
            self:say(attacker.name .. " is confused!")
            if RulesRNG.random(1, 2) == 1 then
                local atkStat = applyStageMod(attacker.atk, attacker.statStages.atk)
                local defStat = applyStageMod(attacker.def, attacker.statStages.def)
                local damage = math.floor(math.floor(
                    math.floor(2 * attacker.level / 5 + 2) * 40 * atkStat / defStat
                ) / 50) + 2
                damage = math.max(1, math.floor(damage * RulesRNG.random(85, 100) / 100))
                attacker:takeDamage(damage)
                self:say("It hurt itself in its confusion!")
                if not attacker:isAlive() then
                    self:setDirection(turn.side == "player" and "enemy" or "player")
                    return self:handleFaint()
                end
                return nil
            end
        end
    end

    if attacker.status == "paralyze" and RulesRNG.random(1, 4) == 1 then
        self:say(attacker.name .. " is paralyzed! It can't move!")
        return nil
    end
    if not turn.move.noPP then
        local key = turn.key
        if not key then
            for _, owned in ipairs(attacker.moves) do if moveData[owned] == turn.move then key = owned; break end end
        end
        if not key or not attacker:usePP(key) then
            self:say(attacker.name .. " has no PP left for that move!")
            return nil
        end
    end
    return self:performMove(turn.move)
end

-- Pinned PokeAPI Gen V target IDs. Only singles are currently supported.
-- Opponent-targeted moves need the still-living opposing active battler.
-- User/user-or-ally and side/field targets remain valid without that battler.
local opponentTargets = {[1]=true,[2]=true,[8]=true,[9]=true,[10]=true,[11]=true}
function Battle:moveHasTarget(move)
    local target=move.targetId or 10
    if target==3 or target==15 then return false end -- No other ally in singles.
    if opponentTargets[target] then return self.defender:isAlive() end
    return target==4 or target==5 or target==6 or target==7 or target==12 or target==13 or target==14
end

function Battle:performMove(move)
    local attacker, defender = self.attacker, self.defender
    self.currentMove = move
    self.currentMoveKey = nil
    for key, definition in pairs(moveData) do
        if definition == move then self.currentMoveKey = key; break end
    end
    self.lastDamage = 0

    self:say(attacker.name .. " used " .. move.name .. "!")
    -- BeforeMove gates and PP already ran. A queued move can reach this point
    -- after the opponent self-KOs; do not damage or debuff a fainted target.
    if not self:moveHasTarget(move) then
        self:say("But there was no target!")
        return nil
    end

    -- One accuracy roll for the whole move (Gen V) — status moves miss too
    if not checkAccuracy(move, attacker, defender) then
        self:say(attacker.name .. "'s attack missed!")
        return nil
    end

    if move.power > 0 then
        local effectiveness = move.typeless and 1 or TypeChart.getMatchup(move.type, defender.type, defender.type2)
        if effectiveness == 0 then
            self:say("It doesn't affect " .. defender.name .. "...")
            return nil
        end

        -- Multi-hit: one accuracy roll, independent damage/crit per hit.
        -- Gen V 2-5 distribution: 2 or 3 hits 1/3 each, 4 or 5 hits 1/6 each
        local hits = 1
        if move.minHits and move.maxHits and move.maxHits > 1 then
            if move.minHits == 2 and move.maxHits == 5 then
                local roll = RulesRNG.random(6)
                if roll <= 2 then hits = 2
                elseif roll <= 4 then hits = 3
                elseif roll == 5 then hits = 4
                else hits = 5 end
            else
                hits = RulesRNG.random(move.minHits, move.maxHits)
            end
        end

        local total, landed, anyCrit = 0, 0, false
        for _ = 1, hits do
            local result = calcDamage(attacker, defender, move)
            local before = defender.hp
            defender:takeDamage(result.damage)
            total = total + before - defender.hp
            landed = landed + 1
            anyCrit = anyCrit or result.isCrit
            if not defender:isAlive() then break end
        end
        self.lastDamage = total
        self.isFlashing = true
        self.flashTimer = 6
        if anyCrit then
            self.shakeTimer = 8
            self.shakeIntensity = 3
        end

        self:say(defender.name .. " took " .. total .. " damage!")
        if landed > 1 then
            self:say("Hit " .. landed .. " times!")
        end
        if effectiveness > 1 then
            self:say("It's super effective!")
        elseif effectiveness < 1 then
            self:say("It's not very effective...")
        end
        if anyCrit then
            self:say("A critical hit!")
        end

        -- Drain / recoil: % of damage dealt (negative = recoil)
        if move.drain and move.drain > 0 then
            attacker:heal(math.max(1, math.floor(total * move.drain / 100 + 0.5)))
            self:say(defender.name .. " had its energy drained!")
        elseif move.struggleRecoil then
            attacker:takeDamage(math.max(1, math.floor(attacker.maxHP / 4 + 0.5)))
            self:say(attacker.name .. " is damaged by recoil!")
        elseif move.drain and move.drain < 0 then
            attacker:takeDamage(math.max(1, math.floor(total * -move.drain / 100 + 0.5)))
            self:say(attacker.name .. " is damaged by recoil!")
        end

        self:applyMoveEffects(move)

        if not defender:isAlive() then
            return self:handleFaint(not attacker:isAlive() and self.attackerSide or nil)
        end
        if not attacker:isAlive() then
            -- recoil (or a self-effect) felled the attacker
            self:setDirection(self.attackerSide == "player" and "enemy" or "player")
            return self:handleFaint()
        end
    else
        -- Status / fixed-damage move: effects carry the whole payload
        self:applyMoveEffects(move)
        if not defender:isAlive() then
            return self:handleFaint()
        end
    end

    return nil
end

function Battle:applyMoveEffects(move)
    if not move.effects then return end
    for _, effect in ipairs(move.effects) do
        effect:apply(self)   -- DSL effects narrate themselves via battle:say
    end
end

-- Gen V singles faint order: when both sides fall, the side of the last
-- fainted battler wins. Recoil follows target damage; no competitive Self-KO
-- clause is added. A campaign win and local blackout can coexist.
function Battle:handleFaint(lastFaintedSide)
    if self.outcome then return self.outcome end
    local playerAlive, enemyAlive = self.player:isAlive(), self.enemy:isAlive()
    if playerAlive and enemyAlive then return nil end
    local defenderSide = self.attackerSide == "player" and "enemy" or "player"
    lastFaintedSide = lastFaintedSide or defenderSide
    local order = lastFaintedSide == "player" and {"enemy", "player"} or {"player", "enemy"}
    for _, side in ipairs(order) do
        local pokemon = side == "player" and self.player or self.enemy
        if not pokemon:isAlive() and not self.faintAnnounced[side] then
            self.faintAnnounced[side] = true
            self:say(pokemon.name .. " fainted!")
        end
    end
    -- Every opposing identity awards at most once, including a nonfinal team
    -- member. Fainted recipients remain ineligible and never revive through XP.
    if not enemyAlive and not self.awardedEnemies[self.enemy] then
        self.awardedEnemies[self.enemy] = true
        self.xpAwarded = true
        local recipients={}
        if self.party then
            for _,mon in ipairs(self.party:members()) do
                if self.participants[mon] and mon:isAlive() then recipients[#recipients+1]=mon end
            end
        elseif playerAlive then recipients[1]=self.player end
        for _,mon in ipairs(recipients) do
            local xpGained=mon:calcExpGain(self.enemy,self.trainerName~=nil,#recipients)
            if xpGained>0 then
                self:say(mon.name .. " gained " .. xpGained .. " EXP!")
                if mon:gainXP(xpGained) then self:say(mon.name .. " grew to Lv" .. mon.level .. "!") end
            end
        end
    end
    local playerTeamAlive, enemyTeamAlive = self:hasUsablePlayer(), self:hasUsableEnemy()
    local won = not enemyTeamAlive and (playerTeamAlive or lastFaintedSide == "player")
    if won then
        self.message = self.trainerName and ("You defeated " .. self.trainerName .. "!") or "You won the battle!"
        return "victory"
    end
    if not playerTeamAlive then
        self.message = self.trainerName and "You lost the battle!" or "You blacked out..."
        return "defeat"
    end
    return "replacement"
end

function Battle:finishRound()
    local outcome = self:endOfRoundStatus()
    if outcome and outcome ~= "replacement" then return outcome end
    -- Gen V replaces fainted battlers after residual effects, not mid-move.
    if not self.enemy:isAlive() and self.enemyParty then
        local index = self.enemyParty:firstUsable()
        if index then
            local old = self.enemy
            old:onSwitchOut()
            assert(self.enemyParty:switch(index))
            self.enemy = self.enemyParty:active()
            self.enemy:resetStages()
            self.awardedEnemies[self.enemy]=nil
            self.participants={}
            if self.player:isAlive() then self.participants[self.player]=true end
            self.faintAnnounced.enemy = nil
            self.xpAwarded = false
            self:clearHitPresentation()
            self:say(self.trainerName .. " sent out " .. self.enemy.name .. "!")
        end
    end
    if not self.player:isAlive() then
        self.message = "Choose a POKEMON!"
        return "forcedSwitch"
    end
    return "command"
end

function Battle:endOfRoundStatus()
    self.player.flinched, self.enemy.flinched = false, false
    local events = {}
    for _, side in ipairs({"player", "enemy"}) do
        local pokemon = side == "player" and self.player or self.enemy
        if pokemon:isAlive() and (pokemon.status == "poison" or pokemon.status == "burn") then
            events[#events + 1] = {side = side, pokemon = pokemon, order = pokemon.status == "poison" and 9 or 10}
        end
    end
    if #events == 2 then
        local a, b = events[1], events[2]
        local swap
        if a.order ~= b.order then swap = b.order < a.order
        else
            local aSpeed, bSpeed = effectiveSpeed(a.pokemon), effectiveSpeed(b.pokemon)
            swap = bSpeed > aSpeed or (aSpeed == bSpeed and RulesRNG.random(1, 2) == 1)
        end
        if swap then events[1], events[2] = b, a end
    end
    for _, event in ipairs(events) do
        self:applyStatusDamage(event.pokemon)
        if not event.pokemon:isAlive() then
            self:setDirection(event.side == "player" and "enemy" or "player")
            local outcome = self:handleFaint(event.side)
            if outcome ~= "replacement" then return outcome end
        end
    end
    return nil
end

function Battle:applyStatusDamage(pokemon)
    if not pokemon:isAlive() then return end

    if pokemon.status == "burn" then
        pokemon:takeDamage(math.max(1, math.floor(pokemon.maxHP / 8)))
        self:say(pokemon.name .. " is hurt by its burn!")
    elseif pokemon.status == "poison" then
        pokemon:takeDamage(math.max(1, math.floor(pokemon.maxHP / 8)))
        self:say(pokemon.name .. " is hurt by poison!")
    end
end
