import "battle/moveSupport"

import "battle/conditions"
import "battle/effects"
import "battle/rewards"
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
-- Current battle types, distinct from durable specimen identity.
local function typeHas(battle,pokemon,kind)
    if battle then return battle:hasType(pokemon,kind) end
    return pokemon.type==kind or pokemon.type2==kind
end
local function typeMatchup(battle,kind,pokemon)
    if battle then return battle:typeMatchup(kind,pokemon) end
    return TypeChart.getMatchup(kind,pokemon.type,pokemon.type2)
end
function calcDamage(attacker, defender, move, effectivePower, effects)
    if move.power == 0 and (not effectivePower or effectivePower <= 0) then return { damage = 0, effectiveness = 1, isCrit = false, isSTAB = false } end

    -- Gen V critical stages0..4:1/16,1/8,1/4,1/3,1/2. Focus Energy
    -- is a battle-owned+2; move metadata supplies the inherent stage.
    local stage=effects and effects:criticalStage(attacker,move) or (move.critStage or 0)
    local isCrit = move.willCrit or RulesRNG.random(1, BattleEffects.criticalDenominator(stage)) == 1
    if isCrit and effects then isCrit=effects:criticalAllowed(defender) end

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
    if effects then
        atkStat=effects:attackStat(attacker,move,atkStat)
        defStat=effects:defenseStat(defender,move,defStat)
    end

    -- STAB (Same Type Attack Bonus)
    local isSTAB = not move.typeless and typeHas(effects and effects.battle,attacker,move.type)

    -- Type effectiveness
    local effectiveness = move.typeless and 1 or typeMatchup(effects and effects.battle,move.type,defender)

    -- Base damage
    local level = attacker.level
    local damage = math.floor(math.floor(
        math.floor(2 * level / 5 + 2) * (effectivePower or move.power) * atkStat / defStat
    ) / 50) + 2

    -- GenV weather damage modifier precedes crit/random/STAB.
    if effects then damage=effects:weatherDamage(move,damage) end
    -- Modifier chain (Gen V order, floor after each step)
    if isCrit then
        damage = damage * 2
    end
    damage = math.floor(damage * RulesRNG.random(85, 100) / 100)
    if isSTAB then
        damage = math.floor(damage * 1.5)
    end
    damage = math.floor(damage * effectiveness)
    if attacker.status == "burn" and move.category == "physical" and not (effects and effects:ignoresBurn(attacker)) then
        damage = math.floor(damage / 2)
    end

    damage = math.max(1, damage)
    -- GenV final screen modifier follows minimum1, so a real hit may do0.
    if effects then
        damage=effects.battle.conditions:screenDamage(attacker,defender,move,damage,isCrit)
        damage=effects:finalDamage(attacker,damage,isCrit)
    end

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
-- Pure ordinary-move observer shared by rules and diagnostics. OHKO has a
-- separate level/ability/accuracy path; never advertise this as its chance.
function accuracyThreshold(move, attacker, defender, effects)
    if move.ohko then return nil,"ohko" end
    if move.accuracy == 0 or (effects and effects.accuracyBypassesCheck and effects:accuracyBypassesCheck(move,attacker,defender)) then return 100 end
    local evasion = defender.statStages.eva
    if effects then evasion = effects.battle.conditions:evasionStage(defender) end
    local stage = attacker.statStages.acc - evasion
    local base=effects and effects:accuracy(attacker,defender,move) or move.accuracy
    return math.max(0,math.min(100,math.floor(base * accStageMult(stage))))
end
function checkAccuracy(move, attacker, defender, effects)
    if move.accuracy == 0 or (effects and effects.accuracyBypassesCheck and effects:accuracyBypassesCheck(move,attacker,defender)) then return true end
    local threshold,reason=accuracyThreshold(move,attacker,defender,effects)
    assert(threshold,reason)
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

local commitFight,commitActiveMember
local MESSAGE_MIN_FRAMES <const> = 10
-- Opaque receipts bind one learning overlay to one suspended production script.
local learningReceipts = setmetatable({}, {__mode = "k"})

function BattleScriptPhase:init(battle)
    BattleScriptPhase.super.init(self, "script")
    self.battle = battle
end

function BattleScriptPhase:enter(co)
    self.co = co
    self.cancelled = false
    self.waiting = false
    self.messageTimer = 0
    self:advance()
end

function BattleScriptPhase:exit()
    self.battle.effects:endRound()
    self.battle:cancelPendingLearning()
end

function BattleScriptPhase:advance()
    if self.cancelled then return false, "script-cancelled" end
    if self.battle.pendingLearning then return false, "learning-pending" end
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
        return true
    end

    if kind == "say" then
        self.battle.message = value
        self.messageTimer = 0
        self.waiting = true
    elseif kind == "learning" then
        assert(value and value:is("Pokemon") and #value:getPendingMoveChoices() > 0, "invalid learning yield")
        local receipt = {}
        learningReceipts[receipt] = {battle=self.battle, script=self, co=self.co, pokemon=value, claimed=false}
        self.battle.pendingLearning = receipt
        self.waiting = false
    else
        error("unknown battle script event: " .. tostring(kind))
    end
    return true
end

function BattleScriptPhase:update()
    if self.cancelled or self.battle.pendingLearning then return end
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
    self.conditions = BattleConditions(self)
    self.effects = BattleEffects(self)
    self.awardedEnemies = {}
    self.participantSets = {[enemyPokemon]={[playerPokemon]=true}}
    self.participants = self.participantSets[enemyPokemon]
    self.phazeResult = nil
    BattleRewards.attach(self)

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
            self:opponentEntered()
        else
            self:opponentEntered()
        end
        self.effects:initialEntries()
        if not self.player:isAlive() then return self:hasUsablePlayer() and "forcedSwitch" or "defeat" end
    end)
end

-- Discovery belongs to actual opponent entry, never team construction/bench.
-- Mark immediately before its visible announcement, including replacements.
function Battle:opponentEntered(cause)
    assert(cause==nil or cause=="phaze","invalid opponent-entry cause")
    if self.enemyParty then assert(self.enemyParty:active()==self.enemy,"opponent entry active mismatch") end
    if self.session then assert(self.session:markSeen(self.enemy.species)) end
    if cause=="phaze" then self:say(self.enemy.name.." was dragged out!")
    elseif self.trainerName then self:say(self.trainerName .. " sent out " .. self.enemy.name .. "!")
    else self:say("A wild " .. self.enemy.name .. " appeared!") end
end

function Battle:update()
    self.machine:update()
    local locked=self.conditions:locked(self.player)
    if self:isAwaitingCommand() and locked and self.player:isAlive() and self.enemy:isAlive() then
        local key=self.conditions:lockedKey(self.player);local index
        for i,owned in ipairs(self.player.moves) do if owned==key then index=i end end
        if index then assert(self:selectMove(index))
        else
            -- A real learning choice may replace the slot while the volatile
            -- stores the move identity. Continue without forging a learned slot.
            assert(moveData[key],"locked move definition missing")
            commitFight(self,{side="player",actor=self.player,move=moveData[key],key=key,continuation=true})
        end
    end
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

-- Only the owner may claim once, present LearningState, then resume this exact
-- coroutine. Rejections never advance rules or consume RNG.
function Battle:takeLearningRequest()
    local receipt = self.pendingLearning
    local data = receipt and learningReceipts[receipt]
    if not data or data.claimed or self:phase() ~= "script" or data.script.cancelled then return nil end
    data.claimed = true
    return receipt, data.pokemon
end

function Battle:resumeLearning(receipt)
    local data = learningReceipts[receipt]
    if not data or data.battle ~= self or self.pendingLearning ~= receipt or not data.claimed
       or self:phase() ~= "script" or self.machine:current() ~= data.script
       or data.script.co ~= data.co or data.script.cancelled then return false, "stale-learning" end
    if #data.pokemon:getPendingMoveChoices() > 0 then return false, "learning-pending" end
    self.pendingLearning = nil
    learningReceipts[receipt] = nil
    data.script:advance()
    return true
end

function Battle:cancelPendingLearning()
    if self.pendingLearning then learningReceipts[self.pendingLearning] = nil end
    self.pendingLearning = nil
    local script = self.machine and self.machine:get("script")
    if script then script.cancelled = true; script.waiting = false end
end

function Battle:getLearningSnapshot()
    local data = self.pendingLearning and learningReceipts[self.pendingLearning]
    return {pending=data~=nil, claimed=data and data.claimed or false,
        species=data and data.pokemon.species or "", remaining=data and #data.pokemon:getPendingMoveChoices() or 0}
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
local function effectiveSpeed(pokemon, conditions, effects)
    local speed = applyStageMod(pokemon.spe, pokemon.statStages.spe)
    if conditions then speed=conditions:speed(pokemon,speed) end
    if effects then
        speed = effects:speed(pokemon, speed)
    end
    if pokemon.status == "paralyze" then
        speed = math.floor(speed / 4)
    end
    return math.max(1,speed)
end
function Battle:effectiveSpeed(pokemon)
    return effectiveSpeed(pokemon, self.conditions, self.effects)
end
-- Pure current-state power observation; shares the production pipeline.
function Battle:effectiveMovePower(move,attacker,defender)
    if move.category=="status" or (move.power==0 and not move.powerRule) then return 0 end
    local power=self.effects:movePower(move,move.power,attacker,defender)
    return self.effects:basePower(move,self.conditions:rawPower(attacker,move,power),attacker,defender)
end


-- Read-only choices. Struggle is a runtime fallback, never a learned PP slot.
function Battle:availableMoves(pokemon)
    local choices = {}
    for index, key in ipairs(pokemon.moves) do
        local move = moveData[key]
        if move and not move.noPP and pokemon:hasPP(key) and self.conditions:moveAllowed(pokemon,key) then
            choices[#choices + 1] = {index = index, key = key, move = move}
        end
    end
    return choices
end

function Battle:needsStruggle(pokemon)
    if self.conditions:locked(pokemon or self.player) then return false end
    return #self:availableMoves(pokemon or self.player) == 0
end

function Battle:emitEnd()
    if not self.outcome then return false, "not-ended" end
    if self.endEmitted then return false, "already-emitted" end
    assert(self:flushRewards()) -- Canonical field stats before any return/evolution/rest callback.
    self.endEmitted = true
    self.emittingEnd = true
    local ok, problem = pcall(self.emit, self, "battleEnd", self.outcome == "victory", self.outcome)
    self.emittingEnd = false
    self:clearListeners()
    self:clearVolatiles()
    if not ok then error(problem, 0) end
    return true
end

function Battle:flushRewards()return BattleRewards.flush(self)end
function Battle:getRewardSnapshot()return BattleRewards.snapshot(self)end
function Battle:presentationVitals(mon)return BattleRewards.presentationVitals(self,mon)end
function Battle:clearVolatiles()
    assert(BattleRewards.close(self))
    self:cancelPendingLearning()
    self.conditions:clearAll()
    self.effects:close()
end
function Battle:enemyTurn()
    local locked=self.conditions:lockedKey(self.enemy)
    if locked then return {side="enemy",actor=self.enemy,move=moveData[locked],key=locked,continuation=true} end
    local choices = self:availableMoves(self.enemy)
    if #choices == 0 then return {side = "enemy", actor=self.enemy, move = moveData.struggle} end
    local choice = choices[RulesRNG.random(1, #choices)]
    return {side = "enemy", actor=self.enemy, move = choice.move, key = choice.key}
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
    local locked=self.conditions:locked(self.player)
    if locked and self.player.moves[moveIndex]~=self.conditions:lockedKey(self.player) then return false,"locked-move" end
    local playerMove, key
    if moveIndex == 0 then
        if not self:needsStruggle() then return false, "moves-available" end
        playerMove = moveData.struggle
    else
        key = self.player.moves[moveIndex]
        if moveIndex < 1 or not key then return false, "invalid-index" end
        playerMove = moveData[key]
        if not playerMove or playerMove.noPP then return false, "unknown-move" end
        if not locked and not self.conditions:moveAllowed(self.player,key) then return false,"disabled-move" end
        if not locked and not self.player:hasPP(key) then return false, "no-pp" end
    end
    assert(playerMove, "Struggle definition must be generated")
    local playerTurn = {side = "player", actor=self.player, move = playerMove, key = key, continuation=locked~=nil}
    return commitFight(self,playerTurn)
end

-- Lexically private: public selectMove has completed its index/PP/phase guards;
-- the only other caller is update's actual stored locked continuation.
commitFight=function(self,playerTurn)
    assert(self:isAwaitingCommand() and not self.outcome and not self.selectionKind
        and self.player:isAlive() and self.enemy:isAlive(),"invalid fight commit")
    local playerMove=playerTurn.move
    local enemyTurn = self:enemyTurn()
    local playerFirst
    if playerMove.priority ~= enemyTurn.move.priority then
        playerFirst = playerMove.priority > enemyTurn.move.priority
    else
        local playerSpeed,enemySpeed=self:effectiveSpeed(self.player),self:effectiveSpeed(self.enemy)
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
    if self.conditions:locked(self.player) then return false,"locked-move" end
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
-- One non-yielding active-member commit shared by voluntary choice, faint
-- replacement and random phazing. Callers own their distinct phase/turn rules.
commitActiveMember = function(self, side, index)
    local party
    if side == "player" then party = self.party else party = self.enemyParty end
    local old = self[side]
    assert((side == "player" or side == "enemy") and party and party:active() == old, "active party mismatch")
    local chosen = assert(party:get(index))
    assert(chosen ~= old and chosen:isAlive() and validSwitchSleep(old) and validSwitchSleep(chosen), "invalid active replacement")
    assert(party:switch(index))
    ContactAbilities.withdraw(self.effects,old)
    self.conditions:clear(old)
    self.effects:clear(old)
    old:onSwitchOut()
    self[side] = chosen
    chosen:resetStages()
    if side == "enemy" then
        self.participantSets[chosen] = self.participantSets[chosen] or {}
        self.participants = self.participantSets[chosen]
        self.xpAwarded = self.awardedEnemies[chosen] == true
    end
    if self.player:isAlive() then self.participants[self.player] = true end
    self.faintAnnounced[side] = nil
    self.selectionKind = nil
    self:clearHitPresentation()
    return old, chosen
end

-- Pure stable-order bench query. Voluntary lock/trap rules intentionally do
-- not apply to forced displacement. No fake Substitute/Ingrain producer state.
function Battle:eligibleForcedReplacements(target)
    if type(target) ~= "table" or type(target.is) ~= "function" or not target:is("Pokemon") then
        return nil, "invalid-target"
    end
    if self.outcome or self.effects.closed or not target:isAlive() then return nil, "inactive-target" end
    local side = target == self.player and "player" or (target == self.enemy and "enemy" or nil)
    if not side then return nil, "foreign-target" end
    if not validSwitchSleep(target) then return nil, "invalid-sleep-duration" end
    local party
    if side == "player" then party = self.party else party = self.enemyParty end
    if not party then return {}, side end
    if party:active() ~= target then return nil, "active-party-mismatch" end
    local choices = {}
    for index, mon in ipairs(party:members()) do
        if mon ~= target and mon:isAlive() then
            if not validSwitchSleep(mon) then return nil, "invalid-sleep-duration" end
            choices[#choices + 1] = index
        end
    end
    return choices, side
end

function Battle:getForceSwitchSnapshot()
    if not self.phazeResult then return { present = false } end
    local copy = { present = true }
    for key, value in pairs(self.phazeResult) do copy[key] = value end
    return copy
end

-- Only the current owned script can apply this typed effect. Terminal return
-- is nil|'run'; no generic effect boolean becomes a battle outcome.
function Battle:forceSwitch(target)
    local script = self.machine:current()
    local source, sourceSide = self.attacker, self.attackerSide
    if self:phase() ~= "script" or script.cancelled or script.co ~= coroutine.running()
        or self.outcome or self.effects.closed or not source or not source:isAlive()
        or (sourceSide ~= "player" and sourceSide ~= "enemy") or self[sourceSide] ~= source
        or target ~= self.defender or target ~= self[sourceSide == "player" and "enemy" or "player"] then
        return nil
    end
    local choices, targetSide = self:eligibleForcedReplacements(target)
    if not choices then
        self:say("But it failed!")
        return nil
    end
    local result = {
        cause = "phaze", sourceSide = sourceSide, targetSide = targetSide,
        outgoing = target.species, incoming = "", index = 0, wild = self.trainerName == nil,
    }
    self.phazeResult = result
    if not self.trainerName then
        if target.level > source.level then
            result.success, result.reason = false, "higher-level"
            self:say("But it failed!")
            return nil
        end
        result.success, result.reason = true, "wild-escape"
        self:say(target.name .. " was blown away!")
        return "run"
    end
    if #choices == 0 then
        result.success, result.reason = false, "no-reserve"
        self:say("But it failed!")
        return nil
    end
    local index = choices[RulesRNG.random(1, #choices)]
    local _, incoming = commitActiveMember(self, targetSide, index)
    result.success, result.reason = true, "trainer-replacement"
    result.incoming, result.index = incoming.species, index
    if targetSide == "enemy" then
        self:opponentEntered("phaze")
    else
        self:say(incoming.name .. " was dragged out!")
    end
    self.conditions:entry(incoming, targetSide)
    self.effects:entry(incoming)
    -- Keep the original move's source orientation for actual faint/XP handling.
    self:setDirection(sourceSide)
    return nil
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
    if not forced and self.conditions:locked(self.player) then return false,"locked-move" end
    if not forced and (self.conditions:trapped(self.player) or self.effects:withdrawBlocked(self.player)) then return false,"trapped" end
    local old=self.player
    local enemyTurn=not forced and self:enemyTurn() or nil
    self.effects:beginRound(enemyTurn and {enemyTurn} or nil)
    local pursuit=enemyTurn and enemyTurn.key=="pursuit"
    if not pursuit then commitActiveMember(self,"player",index) end
    self:runScript(function()
        if pursuit then
            -- The opponent's one selected action attacks the outgoing identity.
            self.effects.round.withdrawing=old
            local outcome=self:resolveTurn(enemyTurn)
            self.effects.round.withdrawing=nil
            if outcome and outcome~="replacement" then return outcome end
            if not old:isAlive() then return self:finishRound() end
            commitActiveMember(self,"player",index)
        end
        if not forced then self:say(old.name .. ", come back!") end
        self:say("Go! " .. chosen.name .. "!")
        self.conditions:entry(chosen,"player")
        self.effects:entry(chosen)
        if not chosen:isAlive() then
            self:setDirection("enemy")
            local outcome=self:handleFaint("player")
            if outcome~="replacement" then return outcome end
            return self:finishRound()
        end
        if forced then return "command" end
        local outcome=not pursuit and self:resolveTurn(enemyTurn) or nil
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
    if self.conditions:locked(self.player) then return false,"locked-move" end
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
    self.effects:beginRound()
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
    if self:isAwaitingCommand() and self.conditions:locked(self.player) then return false,"locked-move" end
    if self:isAwaitingCommand() and not self.effects:sureEscape(self.player)
       and (self.conditions:trapped(self.player) or self.effects:withdrawBlocked(self.player)) then return false,"trapped" end
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

    local playerSpe,enemySpe=self.player.spe,math.max(1,self.enemy.spe)
    local chance=((playerSpe*4096)//enemySpe)*128//4096 + 30*self.runAttempts
    local escaped=self.effects:sureEscape(self.player) or playerSpe>enemySpe
    if not escaped then escaped=RulesRNG.random(0,255)<chance end
    if escaped then
        self:runScript(function()
            if self.effects:sureEscape(self.player) then self:say(self.player.name .. "'s Run Away!") end
            self:say("Got away safely!")
            return "run"
        end)
    else
        self.runAttempts=self.runAttempts+1
        self.effects:beginRound()
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
    self.effects:beginRound(turns)
    for _, turn in ipairs(turns) do
        local outcome = self:resolveTurn(turn)
        if outcome and outcome ~= "replacement" then return outcome end
    end
    return self:finishRound()
end

function Battle:resolveTurn(turn)
    assert(type(turn)=="table" and (turn.side=="player" or turn.side=="enemy")
        and turn.actor and turn.actor:is("Pokemon"),"actual queued actor required")
    -- Displaced actors never lend their action to a replacement, and are
    -- rejected before direction/context/status/PP/RNG changes.
    if turn.actor~=self[turn.side] or self.outcome or self.effects.closed then return nil end
    self:setDirection(turn.side)
    local attacker = self.attacker
    local key = turn.key
    if not key then
        for _,owned in ipairs(attacker.moves) do if moveData[owned]==turn.move then key=owned;break end end
    end
    -- Override a queued selection too, when Encore lands before this action.
    -- This is an ordinary use with ordinary PP, never a locked continuation.
    local queuedTurn = turn
    local encore = self.conditions:encoreKey(attacker)
    if encore and turn.move ~= moveData.struggle and not self.conditions:locked(attacker) then
        key = attacker:hasPP(encore) and encore or nil
        turn = {side=turn.side, actor=attacker, key=key,
            move=key and moveData[key] or moveData.struggle}
    end
    self.effects:beginAction(queuedTurn,attacker)

    -- Fainted by the earlier half-turn: skip
    if not attacker:isAlive() then return nil end

    -- Rage ends before the next attempt, even if sleep/flinch/paralysis stops it.
    self.conditions:of(attacker).rage=nil
    local function interrupted()
        self.conditions:abortMove(attacker)
        return nil
    end
    -- Major status gates (Gen V)
    if attacker.status == "sleep" then
        if attacker.statusTurns > 0 then
            attacker.statusTurns = attacker.statusTurns - 1
            self:say(attacker.name .. " is fast asleep!")
            return interrupted()
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
            return interrupted()
        end
    end

    if attacker.flinched then
        attacker.flinched = false
        self:say(attacker.name .. " flinched and couldn't move!")
        return interrupted()
    end

    -- Disable BeforeMove precedes confusion/paralysis and never spends PP.
    if self.conditions:disabled(attacker,key) then
        self:say(attacker.name.."'s "..turn.move.name.." is disabled!")
        return interrupted()
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
                self.effects:damage(attacker,damage,"confusion")
                self:say("It hurt itself in its confusion!")
                if not attacker:isAlive() then
                    self:setDirection(turn.side == "player" and "enemy" or "player")
                    return self:handleFaint()
                end
                return interrupted()
            end
        end
    end

    if self.conditions:infatuationBlocks(attacker) then return interrupted() end

    if attacker.status == "paralyze" and RulesRNG.random(1, 4) == 1 then
        self:say(attacker.name .. " is paralyzed! It can't move!")
        return interrupted()
    end
    if not turn.move.noPP and not turn.continuation then
        if not key or not attacker:usePP(key) then
            self:say(attacker.name .. " has no PP left for that move!")
            return interrupted()
        end
    end
    self.conditions:of(attacker).lastMove=key or "struggle"
    return self:performMove(turn.move)
end

-- Pinned PokeAPI Gen V target IDs. Only singles are currently supported.
-- Opponent-targeted moves need the still-living opposing active battler.
-- User/user-or-ally and side/field targets remain valid without that battler.
local opponentTargets = {[1]=true,[2]=true,[8]=true,[9]=true,[10]=true,[11]=true}
function Battle:moveHasTarget(move)
    if move.curse and not self:hasType(self.attacker,"ghost") then return true end
    local target=move.targetId or 10
    if target==3 or target==15 then return false end -- No other ally in singles.
    if opponentTargets[target] then return self.defender:isAlive() end
    return target==4 or target==5 or target==6 or target==7 or target==12 or target==13 or target==14
end

-- Keep a bounded, transient diagnostic in addition to the Simulator dev log.
-- Neither this receipt nor the support inventory owns battle outcomes or saves.
function Battle:recordMoveGap(key, reason)
    local entry = { move = key, reason = reason, side = self.attackerSide }
    self.moveGaps = self.moveGaps or {}
    self.moveGaps[#self.moveGaps + 1] = entry
    if #self.moveGaps > 12 then table.remove(self.moveGaps, 1) end
    print("[move-gap] " .. key .. ": " .. reason)
end

-- Bounded callback diagnostics for abilities with genuinely unknown inputs.
function Battle:recordAbilityGap(id,reason,actor)
    self.abilityGaps=self.abilityGaps or {}
    self.abilityGaps[#self.abilityGaps+1]={ability=id,reason=reason,species=actor.species}
    if #self.abilityGaps>12 then table.remove(self.abilityGaps,1) end
    print("[ability-gap] "..id..": "..reason)
end

function Battle:getMoveGaps()
    local copy = {}
    for i, entry in ipairs(self.moveGaps or {}) do
        copy[i] = { move = entry.move, reason = entry.reason, side = entry.side }
    end
    return copy
end

function Battle:performMove(move)
    local attacker, defender = self.attacker, self.defender
    self.currentMove = move
    self.currentMoveKey = nil
    for key, definition in pairs(moveData) do
        if definition == move then self.currentMoveKey = key; break end
    end
    self.lastDamage = 0

    local handler = self.currentMoveKey and MoveSupport.handlers[self.currentMoveKey]
    local gap = self.currentMoveKey and MoveSupport.gaps[self.currentMoveKey]
    if not handler then
        gap = gap or "unreviewed move dispatch"
    elseif move.category == "status" and handler ~= "intentional-no-effect"
        and handler ~= "singles-no-target" and handler ~= "wild-escape"
        and handler ~= "battle-condition" and not move.attemptRule then
        local concrete = false
        for _, effect in ipairs(move.effects or {}) do
            if not effect:is("NoEffect") then concrete = true end
        end
        if not concrete then gap = "missing status effect" end
    end
    if gap then
        self:recordMoveGap(self.currentMoveKey or move.name, gap)
        self:say(attacker.name .. " used " .. move.name .. "!")
        self:say("But it failed!")
        self.conditions:moveFinished(move, false)
        return nil
    end

    if move.damageRule=="bide" then return self.conditions:bide() end

    -- Showdown 9b136a8 gen5 inherits Magnitude's ModifyMove selection.
    -- Keep it local to this use, before immunity/protection/accuracy and damage.
    local magnitude
    if self.currentMoveKey == "magnitude" then
        local roll = RulesRNG.random(100)
        local thresholds = { 5, 15, 35, 65, 85, 95, 100 }
        local powers = { 10, 30, 50, 70, 90, 110, 150 }
        for index, threshold in ipairs(thresholds) do
            if roll <= threshold then
                magnitude = index + 3
                -- Active-use copy: damage receipts and modifiers must see a
                -- damaging move, while the registry keeps its zero base power.
                local activeMove = {}
                for key, value in pairs(move) do activeMove[key] = value end
                activeMove.power = powers[index]
                move = activeMove
                self.currentMove = move
                break
            end
        end
    end

    self:say(attacker.name .. " used " .. move.name .. "!")
    if magnitude then self:say("Magnitude " .. magnitude .. "!") end
    if handler == "wild-escape" then
        -- Showdown 9b136a8's gen7 override is inherited by gen5: priority
        -- zero, no selfSwitch, trainer failure even with a usable reserve.
        -- Wild encounters extend that trainer-only oracle with self escape.
        local escaped = self.trainerName == nil
        self.conditions:moveFinished(move, escaped)
        if not escaped then
            self:say("But it failed!")
            return nil
        end
        self:say(attacker.name .. " fled!")
        return "run"
    end
    -- Charging is a TryMove stage before target/type/accuracy. Skull Bash can
    -- prepare against Ghost, then fail its Normal release without an accuracy roll.
    if move.chargeRule and self.conditions:charge(move) then return nil end
    -- BeforeMove gates and PP already ran. A queued move can reach this point
    -- after the opponent self-KOs; do not damage or debuff a fainted target.
    if not self:moveHasTarget(move) then
        if move.rollout then self.conditions:of(attacker).rollout=nil end
        self:say("But there was no target!")
        self.conditions:moveFinished(move,false)
        return nil
    end

    -- Gen V C execution2097/PS hitStepTypeImmunity precedes accuracy.
    -- Ordinary status moves ignore type charts; the generated explicit flag
    -- enables Thunder Wave's type immunity without changing generic status.
    if (move.category~="status" or move.typeImmunity) and not move.typeless
       and opponentTargets[move.targetId or 10]
       and (self:typeMatchup(move.type,defender)==0
            or self.effects:groundImmune(attacker, defender, move)) then
        if move.rollout then self.conditions:of(attacker).rollout=nil end
        self:say("It doesn't affect " .. defender.name .. "...")
        self.conditions:moveFinished(move,false)
        return nil
    end

    -- GenV TryHit protection follows type immunity, before move-specific
    -- gates/accuracy/HP/effects. A blocked attempt has no contact receipt.
    if self.conditions:blocks(move,attacker,defender) then
        if move.rollout then self.conditions:of(attacker).rollout=nil end
        self.conditions:moveFinished(move,false)
        return nil
    end

    if opponentTargets[move.targetId or 10] and self.effects:absorbsMove(attacker,defender,move) then
        self.conditions:moveFinished(move,false)
        return nil
    end

    -- Move-specific failure after type immunity, before accuracy. PP has been
    -- consumed at the actual attempt, and no failure here samples damage RNG.
    local permitted,attemptReason=self.effects:canAttempt(move,attacker,defender)
    if not permitted then
        if attemptReason == "soundproof" then
            self:say(defender.name .. " is protected by Soundproof!")
        else
            self:say(attemptReason=="oblivious" and (defender.name.." is protected by Oblivious!") or "But it failed!")
        end
        self.conditions:moveFinished(move,false)
        return nil
    end

    -- One accuracy roll for the whole move (Gen V) — status moves miss too
    if move.ohko then
        local hit,reason=self.effects:ohko(attacker,defender,move)
        if not hit then
            self:say(reason=="sturdy" and (defender.name .. " is protected by Sturdy!") or "But it failed!")
            return nil
        end
        local receipt=self.effects:hit(attacker,defender,move,defender.hp)
        self.lastDamage=receipt.removed
        self:say("It's a one-hit KO!")
        ContactAbilities.secondaries(self.effects,attacker,defender,move)
        self.effects:afterHit(receipt)
        return self:handleFaint()
    end
    if not checkAccuracy(move, attacker, defender, self.effects) then
        if move.rollout then self.conditions:of(attacker).rollout=nil end
        self:say(attacker.name .. "'s attack missed!")
        self.conditions:moveFinished(move,false)
        return nil
    end

    if handler=="battle-condition" then
        if self.currentMoveKey=="disable" then self.conditions:disable()
        elseif self.currentMoveKey=="camouflage" then self.conditions:camouflage()
        elseif self.currentMoveKey=="encore" then self.conditions:encore()
        elseif self.currentMoveKey=="waterSport" then self.conditions:waterSport()
        elseif self.currentMoveKey=="odorSleuth" then self.conditions:odorSleuth()
        else error("unsupported battle-condition move") end
        return nil
    end

    self.conditions:breakProtection(move,defender)
    local fixed=self.effects:fixedDamage(move,attacker,defender)
    if fixed then
        DirectDamage(DEFENDER,fixed):apply(self)
        if not defender:isAlive() then return self:handleFaint() end
        return nil
    end
    if move.power > 0 or move.powerRule then
        local effectiveness = move.typeless and 1 or self:typeMatchup(move.type,defender)

        -- Multi-hit: one accuracy roll, independent damage/crit per hit.
        -- Gen V 2-5 distribution: 35/35/15/15 percent.
        local hits = self:hitCount(move)

        if move.rollout and not self.conditions:locked(attacker) then self.conditions:of(attacker).rollout={hits=0} end
        local power=self:effectiveMovePower(move,attacker,defender)
        local total, landed, anyCrit = 0, 0, false
        for hitNumber = 1, hits do
            local result = calcDamage(attacker, defender, move, power,self.effects)
            local receipt=self.effects:hit(attacker,defender,move,result.damage,hitNumber)
            self.conditions:landedMove(move)
            ContactAbilities.onHit(self.effects,receipt,result.isCrit)
            local before=receipt.before
            total=total+receipt.removed
            landed = landed + 1
            anyCrit = anyCrit or result.isCrit
            self:say(defender.name .. " took " .. receipt.removed .. " damage!")
            if result.isCrit then self:say("A critical hit!") end
            self.conditions:rageHit(defender)
            self.effects:announceEndure(receipt)
            -- C DamageListCore: drain, secondary effects, contact reactions;
            -- whole-move recoil follows DamageMultiHit, before terminal verdict.
            if receipt.removed>0 and move.drain and move.drain>0 then
                self.effects:drainHit(receipt)
                self:say(defender.name .. " had its energy drained!")
            end
            self:applyMoveSecondaries(move)
            self.effects:afterHit(receipt)
            if not defender:isAlive() or not attacker:isAlive() then break end
        end
        if move.rollout then
            local state=self.conditions:of(attacker);state.rollout.hits=state.rollout.hits+1
            if state.rollout.hits>=5 then state.rollout=nil end
        end
        self.lastDamage = total
        self.isFlashing = true
        self.flashTimer = 6
        if anyCrit then
            self.shakeTimer = 8
            self.shakeIntensity = 3
        end

        if landed > 1 then
            self:say("Hit " .. landed .. " times!")
        end
        if effectiveness > 1 then
            self:say("It's super effective!")
        elseif effectiveness < 1 then
            self:say("It's not very effective...")
        end

        -- Drain / recoil: % of damage dealt (negative = recoil)
        if attacker:isAlive() and move.struggleRecoil then
            self.effects:damage(attacker,math.max(1, math.floor(attacker.maxHP / 4 + 0.5)),"struggle-recoil")
            self:say(attacker.name .. " is damaged by recoil!")
        elseif attacker:isAlive() and total>0 and move.drain and move.drain < 0 and not self.effects:recoilBlocked(attacker,move) then
            self.effects:damage(attacker,math.max(1, math.floor(total * -move.drain / 100 + 0.5)),"recoil")
            self:say(attacker.name .. " is damaged by recoil!")
        end

        local effectOutcome=self:applyMoveEffects(move)
        if effectOutcome=="run" then return effectOutcome end
        self.conditions:moveFinished(move,true)

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
        if self.currentMoveKey == "splash" then self:say("But nothing happened!") end
        local effectOutcome=self:applyMoveEffects(move)
        if effectOutcome=="run" then return effectOutcome end
        -- A force-switch payload may have replaced the old local defender.
        -- Entry-hazard faints use the actual current identity and rewards owner.
        if not self.defender:isAlive() then return self:handleFaint() end
        if not self.attacker:isAlive() then
            self:setDirection(self.attackerSide=="player" and "enemy" or "player")
            return self:handleFaint()
        end
    end

    return nil
end

function Battle:hitCount(move)
    local maximum=self.effects:multiHitMaximum(self.attacker,move)
    if maximum then return maximum end
    if not move.minHits or not move.maxHits or move.maxHits<=1 then return 1 end
    if move.minHits==2 and move.maxHits==5 then
        local roll=RulesRNG.random(0,99)
        return roll<35 and 2 or (roll<70 and 3 or (roll<85 and 4 or 5))
    end
    if move.minHits==move.maxHits then return move.minHits end
    return RulesRNG.random(move.minHits,move.maxHits)
end

function Battle:applyMoveSecondaries(move)
    for _,effect in ipairs(move.secondaries or {}) do effect:apply(self) end
    ContactAbilities.secondaries(self.effects,self.attacker,self.defender,move)
end

function Battle:applyMoveEffects(move)
    if not move.effects then return end
    for _, effect in ipairs(move.effects) do
        local outcome=effect:apply(self) -- DSL effects narrate via battle:say.
        if outcome=="run" then return outcome end
    end
end

-- Gen V singles faint order: when both sides fall, the side of the last
-- fainted battler wins. Recoil follows target damage; no competitive Self-KO
-- clause is added. A campaign win and local blackout can coexist.
function Battle:_registerFaints(lastFaintedSide)
    if not self.player:isAlive() then self.conditions:clear(self.player);self.effects:clear(self.player) end
    if not self.enemy:isAlive() then self.conditions:clear(self.enemy);self.effects:clear(self.enemy) end
    if self.outcome then return self.outcome end
    local playerAlive, enemyAlive = self.player:isAlive(), self.enemy:isAlive()
    if playerAlive and enemyAlive then return nil end
    local defenderSide = self.attackerSide == "player" and "enemy" or "player"
    lastFaintedSide = lastFaintedSide or defenderSide
    local order = lastFaintedSide == "player" and {"enemy", "player"} or {"player", "enemy"}
    local changed=false
    for _, side in ipairs(order) do
        local pokemon = side == "player" and self.player or self.enemy
        if not pokemon:isAlive() and not self.faintAnnounced[side] then
            self.faintAnnounced[side] = true
            changed=true
            self:say(pokemon.name .. " fainted!")
        end
    end
    return lastFaintedSide,changed
end

function Battle:_resolveFaintCheckpoint(lastFaintedSide)
    if self.outcome then return self.outcome end
    local playerAlive,enemyAlive=self.player:isAlive(),self.enemy:isAlive()
    if playerAlive and enemyAlive then return nil end
    -- Every opposing identity awards at most once, including a nonfinal team
    -- member. Fainted recipients remain ineligible and never revive through XP.
    if not enemyAlive and not self.awardedEnemies[self.enemy] then
        local plan,why=BattleRewards.prepare(self,self.enemy);assert(plan,why)
        local accepted,receipt=BattleRewards.commit(self,plan);assert(accepted,receipt)
        local awarded={}
        for _,row in ipairs(receipt.rows)do
            awarded[#awarded+1]={mon=self.party and assert(self.party:get(row.index))or self.player,row=row}
        end
        for _,entry in ipairs(awarded)do
            local mon,row=entry.mon,entry.row
            if row.xp>0 then
                self:say(mon.name .. " gained " .. row.xp .. " EXP!")
                local shown,why=BattleRewards.acknowledge(self,receipt.id,row.index);assert(shown,why)
                if row.leveled then self:say(mon.name .. " grew to Lv" .. mon.level .. "!")end
                if #mon:getPendingMoveChoices()>0 then coroutine.yield("learning",mon)end
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

-- Direct moves and completed weather cohorts retain their immediate checkpoint.
function Battle:handleFaint(lastFaintedSide)
    local last=self:_registerFaints(lastFaintedSide)
    if self.outcome then return self.outcome end
    if not last then return nil end
    return self:_resolveFaintCheckpoint(last)
end

function Battle:finishRound()
    local outcome = self:endOfRoundStatus()
    self.conditions:endRound()
    if outcome and outcome ~= "replacement" then return outcome end
    -- Gen V replaces fainted battlers after residual effects, not mid-move.
    while not self.enemy:isAlive() and self.enemyParty and self.enemyParty:firstUsable() do
        local index = self.enemyParty:firstUsable()
        if index then
            commitActiveMember(self,"enemy",index)
            self:opponentEntered()
            self.conditions:entry(self.enemy,"enemy")
            self.effects:entry(self.enemy)
            if not self.enemy:isAlive() then
                self:setDirection("player")
                local result=self:handleFaint("enemy")
                if result~="replacement" then return result end
            end
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
    local events=self.conditions:events()
    for _,event in ipairs(self.effects:events()) do events[#events+1]=event end
    local tie,sideTie={},{}
    local tiedSide
    local function eventSpeed(event) return event.pokemon and self:effectiveSpeed(event.pokemon) or 0 end
    local function sub(event) return event.suborder or 0 end
    local function sideKey(event) return tostring(event.order)..":"..tostring(sub(event)) end
    for _,a in ipairs(events) do
        for _,b in ipairs(events) do
            if a.side=="player" and b.side=="enemy" and a.order==b.order and sub(a)==sub(b) and eventSpeed(a)==eventSpeed(b) then
                if a.kind=="sideTimer" and b.kind=="sideTimer" then
                    local key=sideKey(a);if not sideTie[key] then sideTie[key]=RulesRNG.random(1,2) end
                elseif not tie[a.order] then
                    tiedSide=tiedSide or RulesRNG.random(1,2);tie[a.order]=tiedSide
                end
            end
        end
    end
    table.sort(events,function(a,b)
        if a==b then return false end
        if a.order~=b.order then return a.order<b.order end
        if sub(a)~=sub(b) then return sub(a)<sub(b) end
        local sa,sb=eventSpeed(a),eventSpeed(b)
        if sa~=sb then return sa>sb end
        local orientation=a.kind=="sideTimer" and sideTie[sideKey(a)] or tie[a.order]
        return a.side~="enemy" and orientation~=2 or a.side=="enemy" and orientation==2
    end)
    -- Existing project event order is retained: weather0/1, ShedSkin5,
    -- member conditions8..25 (including Roost), side timers26, rampage1000.
    -- Native condition EXP waits until ALL callbacks or matchup between cohorts.
    local function conditionStage(event)
        return event and event.owner~="effects" and event.pokemon~=nil and event.order>=8 and event.order<=25
    end
    local weatherFaint,conditionFaint
    for index,event in ipairs(events)do
        local condition=conditionStage(event)
        local reflectedFaintSide
        if event.owner == "effects" then
            self.effects:residual(event)
        else
            reflectedFaintSide = self.conditions:residual(event)
        end
        if event.pokemon and (not event.pokemon:isAlive() or reflectedFaintSide) then
            if event.kind=="sand"then weatherFaint=event.side
            elseif condition then
                self:setDirection(event.side=="player"and "enemy"or "player")
                local last,changed=self:_registerFaints(reflectedFaintSide or event.side)
                if changed then conditionFaint=last end
            else
                self:setDirection(event.side=="player"and "enemy"or "player")
                local outcome=self:handleFaint(event.side)
                if outcome~="replacement"then return outcome end
            end
        end
        local nextEvent=events[index+1]
        -- Weather remains its separate, already accepted whole-field cohort.
        if weatherFaint and (not nextEvent or nextEvent.kind~="sand")then
            self:setDirection(weatherFaint=="player"and "enemy"or "player")
            local outcome=self:handleFaint(weatherFaint);weatherFaint=nil
            if outcome~="replacement"then return outcome end
        end
        if condition and conditionFaint then
            local stageEnd=not conditionStage(nextEvent)
            local cohortEnd=stageEnd or nextEvent.order~=event.order or sub(nextEvent)~=sub(event)
            if cohortEnd and (stageEnd or not self:hasUsablePlayer()or not self:hasUsableEnemy())then
                self:setDirection(conditionFaint=="player"and "enemy"or "player")
                local outcome=self:_resolveFaintCheckpoint(conditionFaint);conditionFaint=nil
                if outcome~="replacement"then return outcome end
            end
        end
    end
    return nil
end

function Battle:applyStatusDamage(pokemon)
    if not pokemon:isAlive() or ContactAbilities.preventDamage(self.effects,pokemon,"status") then return end

    if pokemon.status == "burn" then
        self.effects:damage(pokemon,math.max(1, math.floor(pokemon.maxHP / 8)),"status")
        self:say(pokemon.name .. " is hurt by its burn!")
    elseif pokemon.status == "poison" then
        self.effects:damage(pokemon,math.max(1, math.floor(pokemon.maxHP / 8)),"status")
        self:say(pokemon.name .. " is hurt by poison!")
    end
end

-- Read-only diagnostics for concrete transient mechanics, never save data.
function Battle:effectiveTypes(mon) return self.conditions:types(mon) end
function Battle:hasType(mon,kind)
    local first,second=self:effectiveTypes(mon)
    return first==kind or second==kind
end
function Battle:typeMatchup(kind,mon)
    local held = self.effects and PickupHeld.matchup(self.effects, kind, mon)
    if held ~= nil then return held end
    local first,second=self:effectiveTypes(mon)
    if self.conditions:identified(mon) and (kind == "normal" or kind == "fighting") then
        -- Negate only Ghost immunity; the other type still contributes.
        if first == "ghost" then first = nil end
        if second == "ghost" then second = nil end
    end
    return TypeChart.getMatchup(kind,first,second)
end

function Battle:getConditionsSnapshot()
    local out={sides={}}
    for _,side in ipairs({"player","enemy"}) do
        local state=self.conditions.members[self[side]] or {};local hazards=self.conditions.sides[side]
        out[side]={roost=state.roost~=nil,protect=state.protect==true,stall_counter=state.stall and state.stall.counter or 0,stall_remaining=state.stall and state.stall.remaining or 0,charge_key=state.charge and state.charge.key or "",rampage_key=state.rampage and state.rampage.key or "",rampage_remaining=state.rampage and state.rampage.remaining or 0,rampage_total=state.rampage and state.rampage.total or 0,bide_turns=state.bide and state.bide.turns or 0,bide_damage=state.bide and state.bide.total or 0,focus_energy=state.focusEnergy==true,mud_sport=state.mudSport==true,cursed=state.curse==true,rage=state.rage==true,
            defense_curl=state.defenseCurl==true,rollout_hits=state.rollout and state.rollout.hits or 0,
            seeded=state.seed~=nil,trapped=self.conditions:trapped(self[side]),trap_turns=state.trap and state.trap.remaining or 0,
            toxic_counter=self[side].status=="badPoison" and (state.toxic or 0) or 0}
        out.sides[side]={spikes=hazards.spikes or 0,toxic_spikes=hazards.toxicSpikes or 0,stealth_rock=hazards.stealthRock or 0,light_screen=hazards.lightScreen and hazards.lightScreen.turns or 0,safeguard=hazards.safeguard and hazards.safeguard.turns or 0,tailwind=hazards.tailwind and hazards.tailwind.turns or 0}
    end
    return out
end

-- Successful medicine replaces the player's action, then resolves one enemy
-- action and the normal residual boundary. Invalid commands are entirely inert.
function Battle:useItem(id,partyIndex,moveSlot)
    if self.outcome or not self:isAwaitingCommand() or self:needsForcedSwitch() then return false,"wrong-phase" end
    if self.selectionKind and self.selectionKind~="bag" then return false,"selection-open" end
    if not self.session or not self.party then return false,"bag-unavailable" end
    if GameSession.activeRNGSession()~=self.session or self.session:party()~=self.party
        or self.party:active()~=self.player then return false,"stale-session" end
    if not self.player:isAlive() or not self.enemy:isAlive() then return false,"fainted" end
    if self.conditions:locked(self.player) then return false,"locked-move" end
    local item=type(id)=="string" and ItemData.definitions[id] or nil
    local legal={heal=true,fullRestore=true,cure=true,revive=true,pp=true}
    if not item or not legal[item.effect] then return false,"unsupported-item-use" end
    partyIndex=type(partyIndex)=="number" and math.tointeger(partyIndex) or nil
    if not partyIndex then return false,"invalid-index" end
    local target,problem=self.party:get(partyIndex)
    if not target then return false,problem end
    if Party._owner(target)~=self.party then return false,"stale-target" end
    local ok,result=Items.use(self.session:inventory(),id,target,moveSlot)
    if not ok then return false,result end
    self.effects:beginRound()
    self.selectionKind=nil
    self:clearHitPresentation()
    self:runScript(function()
        self:say("RED used "..item.name.." on "..target.name.."!")
        local outcome=self:resolveTurn(self:enemyTurn())
        if outcome and outcome~="replacement" then return outcome end
        return self:finishRound()
    end)
    return true,result
end
