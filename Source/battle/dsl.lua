-- battle/dsl.lua — Composable battle DSL
--
-- Inspired by "Rebuilding Pokémon with Object Oriented Programming"
-- (Christopher Okhravi): moves are composed from small, orthogonal objects
-- instead of special-cased code. Four vocabularies:
--
--   Targets    — selectors: given a battle, pick a battler.
--                The battle carries directionality (attacker/defender flip
--                every turn), so effects are written once, not per side.
--   Numbers    — lazy values: evaluate(battle) -> number. Constants, random
--                ranges, weighted rolls, arithmetic and battler-derived
--                numbers compose freely (Product(MaxHPOf(ATTACKER), 0.5)).
--   Conditions — predicates: check(battle) -> bool. Chance, And/Or/Not, and
--                battler predicates lifted to battle level with For(target).
--   Effects    — mutations: apply(battle). Combinators (EffectSeq, When,
--                NoEffect as the null object) plus leaves (damage, status,
--                stat stages, healing). Effects run inside the battle's
--                resolution coroutine, so they narrate themselves with
--                battle:say(...).
--
-- moveData in moves.lua composes these directly, e.g.:
--   When(Chance(30), ApplyStatus(DEFENDER, "paralyze"))
--   ModifyStat(ATTACKER, "atk", 2)

-- ============================================================
-- TARGETS
-- ============================================================

Class("Target")

function Target:init(side)
    self.side = side
end

function Target:resolve(battle)
    if self.side == "attacker" then
        return battle.attacker
    end
    return battle.defender
end

ATTACKER = Target("attacker")
DEFENDER = Target("defender")

-- Accepts a Target or the strings "attacker"/"defender" (legacy data format)
function Target.from(value)
    if value == "attacker" then return ATTACKER end
    if value == "defender" then return DEFENDER end
    return value
end

-- ============================================================
-- NUMBERS — evaluate(battle) -> number
-- ============================================================

Num = {}

-- Coerce raw Lua numbers into the DSL so call sites can write either
function Num.of(value)
    if type(value) == "number" then
        return Exactly(value)
    end
    return value
end

Class("Exactly")
function Exactly:init(value) self.value = value end
function Exactly:evaluate(_battle) return self.value end

Class("Between")
function Between:init(min, max) self.min = min; self.max = max end
function Between:evaluate(_battle) return RulesRNG.random(self.min, self.max) end

-- Weighted{ {value=2, weight=375}, {value=3, weight=375}, ... }
Class("Weighted")
function Weighted:init(entries)
    self.entries = entries
    local total = 0
    for _, e in ipairs(entries) do total = total + e.weight end
    self.total = total
end

function Weighted:evaluate(_battle)
    local roll = RulesRNG.random(1, self.total)
    local sum = 0
    for _, e in ipairs(self.entries) do
        sum = sum + e.weight
        if roll <= sum then return e.value end
    end
    return self.entries[#self.entries].value
end

Class("Product")
function Product:init(a, b) self.a = Num.of(a); self.b = Num.of(b) end
function Product:evaluate(battle) return self.a:evaluate(battle) * self.b:evaluate(battle) end

Class("Sum")
function Sum:init(a, b) self.a = Num.of(a); self.b = Num.of(b) end
function Sum:evaluate(battle) return self.a:evaluate(battle) + self.b:evaluate(battle) end

Class("Quotient")
function Quotient:init(a, b) self.a = Num.of(a); self.b = Num.of(b) end
function Quotient:evaluate(battle) return self.a:evaluate(battle) / self.b:evaluate(battle) end

Class("MaxHPOf")
function MaxHPOf:init(target) self.target = Target.from(target) end
function MaxHPOf:evaluate(battle) return self.target:resolve(battle).maxHP end

Class("CurrentHPOf")
function CurrentHPOf:init(target) self.target = Target.from(target) end
function CurrentHPOf:evaluate(battle) return self.target:resolve(battle).hp end

Class("LevelOf")
function LevelOf:init(target) self.target = Target.from(target) end
function LevelOf:evaluate(battle) return self.target:resolve(battle).level end

-- Damage dealt by the most recent damaging hit in this battle
Class("LastDamage")
function LastDamage:evaluate(battle) return battle.lastDamage or 0 end

-- ============================================================
-- CONDITIONS — check(battle) -> bool
-- ============================================================

Class("Chance")
function Chance:init(percent) self.percent = percent end
function Chance:check(_battle) return RulesRNG.random(1, 100) <= self.percent end

Class("Always")
function Always:check(_battle) return true end

Class("Never")
function Never:check(_battle) return false end

Class("Not")
function Not:init(cond) self.cond = cond end
function Not:check(battle) return not self.cond:check(battle) end

Class("AllOf")
function AllOf:init(...) self.conds = { ... } end
function AllOf:check(battle)
    for _, cond in ipairs(self.conds) do
        if not cond:check(battle) then return false end
    end
    return true
end

Class("AnyOf")
function AnyOf:init(...) self.conds = { ... } end
function AnyOf:check(battle)
    for _, cond in ipairs(self.conds) do
        if cond:check(battle) then return true end
    end
    return false
end

-- Battler-level predicates: check(pokemon) -> bool. Lift them to battle
-- level with For(target, cond) — the talk's "lifting" combinator.
Class("HasType")
function HasType:init(pokemonType) self.pokemonType = pokemonType end
function HasType:check(pokemon)
    return pokemon.type == self.pokemonType or pokemon.type2 == self.pokemonType
end

Class("HasStatus")
function HasStatus:init(status) self.status = status end
function HasStatus:check(pokemon) return pokemon.status == self.status end

Class("For")
function For:init(target, cond)
    self.target = Target.from(target)
    self.cond = cond
end
function For:check(battle)
    return self.cond:check(self.target:resolve(battle))
end

-- ============================================================
-- EFFECTS — apply(battle); may battle:say(...) to narrate
-- ============================================================

Class("NoEffect")
function NoEffect:apply(_battle) end

NO_EFFECT = NoEffect()   -- shared null object

Class("EffectSeq")
function EffectSeq:init(effects) self.effects = effects end
function EffectSeq:apply(battle)
    for _, effect in ipairs(self.effects) do
        effect:apply(battle)
    end
end

Class("When")
function When:init(cond, onPass, onFail)
    self.cond = cond
    self.onPass = onPass
    self.onFail = onFail or NO_EFFECT
end
function When:apply(battle)
    if self.cond:check(battle) then
        self.onPass:apply(battle)
    else
        self.onFail:apply(battle)
    end
end

local STAT_NAMES <const> = {
    atk = "ATTACK", def = "DEFENSE", spa = "SP. ATK", spd = "SP. DEF",
    spe = "SPEED", acc = "ACCURACY", eva = "EVASIVENESS",
}

Class("ModifyStat")
function ModifyStat:init(target, stat, stages)
    self.target = Target.from(target)
    self.stat = stat
    self.stages = stages
end

function ModifyStat:apply(battle)
    local pokemon = self.target:resolve(battle)
    if battle.effects and not battle.effects:canDropStat(battle.attacker,pokemon,self.stat,self.stages) then
        battle:say(pokemon.name .. "'s Keen Eye prevents accuracy loss!");return
    end
    local oldStage = pokemon.statStages[self.stat] or 0
    local newStage = math.max(-6, math.min(6, oldStage + self.stages))
    pokemon.statStages[self.stat] = newStage
    local statName = STAT_NAMES[self.stat]
    if newStage == oldStage then
        local limit = self.stages > 0 and "higher" or "lower"
        battle:say(pokemon.name .. "'s " .. statName .. " won't go any " .. limit .. "!")
        return
    end
    local delta = newStage - oldStage
    local phrase
    if delta <= -2 then phrase = "harshly fell"
    elseif delta == -1 then phrase = "fell"
    elseif delta == 1 then phrase = "rose"
    else phrase = "rose sharply" end
    battle:say(pokemon.name .. "'s " .. statName .. " " .. phrase .. "!")
end

local STATUS_NAMES <const> = {
    burn = "was burned", poison = "was poisoned", badPoison = "was badly poisoned", paralyze = "is paralyzed",
    sleep = "fell asleep", freeze = "was frozen",
}

-- Gen V type immunities to major status
local function immuneToStatus(pokemon, status)
    local function hasType(t)
        return pokemon.type == t or pokemon.type2 == t
    end
    if status == "burn" then return hasType("fire") end
    if status == "poison" or status == "badPoison" then return hasType("poison") or hasType("steel") end
    if status == "freeze" then return hasType("ice") end
    return false
end

Class("ApplyStatus")
function ApplyStatus:init(target, status)
    self.target = Target.from(target)
    self.status = status
end

function ApplyStatus:apply(battle)
    local pokemon = self.target:resolve(battle)

    if not pokemon:isAlive() then return end
    -- Volatile conditions live next to the major status, not in it
    if self.status == "flinch" then
        pokemon.flinched = true   -- consumed by the engine on the next half-turn
        return
    end
    if self.status == "confuse" then
        if pokemon.confusion then return end
        pokemon.confusion = RulesRNG.random(1, 4)   -- attacking turns of confusion
        battle:say(pokemon.name .. " became confused!")
        return
    end

    if pokemon.status then
        if self.status=="badPoison" then battle:say("But it failed!") end
        return
    end
    if immuneToStatus(pokemon, self.status) then
        if self.status=="badPoison" then battle:say("It doesn't affect "..pokemon.name.."...") end
        return
    end
    -- Sample before committing durable fields; RNG exhaustion cannot leave an
    -- asleep Pokemon without its original duration.
    local duration = self.status == "sleep" and RulesRNG.random(1, 3) or 0
    if battle.conditions then battle.conditions:of(pokemon).toxic=nil end
    pokemon.status = self.status
    pokemon.statusTurns = duration
    pokemon.sleepDuration = duration
    battle:say(pokemon.name .. " " .. (STATUS_NAMES[self.status] or "was afflicted") .. "!")
end

-- Fixed damage that bypasses the Gen I formula entirely
Class("DirectDamage")
function DirectDamage:init(target, amount)
    self.target = Target.from(target)
    self.amount = Num.of(amount)
end

function DirectDamage:apply(battle)
    local pokemon = self.target:resolve(battle)
    local move = battle.currentMove
    if pokemon == battle.defender and move and move.category ~= "status" and not move.typeless
        and TypeChart.getMatchup(move.type, pokemon.type, pokemon.type2) == 0 then
        battle.lastDamage = 0
        battle:say("It doesn't affect " .. pokemon.name .. "...")
        return
    end
    local damage = math.max(1, math.floor(self.amount:evaluate(battle)))
    local before = pokemon.hp
    local receipt=battle.effects and battle.effects:hit(battle.attacker,pokemon,move,damage)
    if not receipt then pokemon:takeDamage(damage) end
    battle.lastDamage = before - pokemon.hp
    if battle.conditions and pokemon==battle.defender and battle.lastDamage>0 then battle.conditions:rageHit(pokemon) end
    battle:say(pokemon.name .. " took " .. battle.lastDamage .. " damage!")
    if receipt then battle.effects:announceEndure(receipt);battle.effects:afterHit(receipt) end
end

Class("Heal")
function Heal:init(target, amount)
    self.target = Target.from(target)
    self.amount = Num.of(amount)
end

function Heal:apply(battle)
    local pokemon = self.target:resolve(battle)
    pokemon:heal(math.max(1, math.floor(self.amount:evaluate(battle))))
    battle:say(pokemon.name .. " regained health!")
end


-- Gen V Psywave: uniform integer percent50..150 times level, floored, min1.
-- This fixed damage ignores STAB/critical/resistance but respects immunity.
-- Primary implementation: pinned Pokemon Showdown moves.ts + gen5 accuracy80.
Class("PsywaveDamage")
function PsywaveDamage:apply(battle)
    local attacker, defender = battle.attacker, battle.defender
    if TypeChart.getMatchup("psychic", defender.type, defender.type2) == 0 then
        battle.lastDamage = 0
        battle:say("It doesn't affect " .. defender.name .. "...")
        return
    end
    local amount = math.max(1, math.floor(RulesRNG.random(50, 150) * attacker.level / 100))
    local before = defender.hp
    local receipt=battle.effects and battle.effects:hit(attacker,defender,battle.currentMove,amount)
    if not receipt then defender:takeDamage(amount) end
    battle.lastDamage = before - defender.hp
    if battle.conditions and battle.lastDamage>0 then battle.conditions:rageHit(defender) end
    battle.isFlashing, battle.flashTimer = true, 6
    battle:say(defender.name .. " took " .. battle.lastDamage .. " damage!")
    if receipt then battle.effects:announceEndure(receipt);battle.effects:afterHit(receipt) end
end

-- Dedicated effects delegate transient ownership to this battle only.
Class("MudSportEffect")
function MudSportEffect:apply(battle) battle.conditions:mudSport() end
Class("CurseEffect")
function CurseEffect:apply(battle) battle.conditions:curse() end
Class("RageEffect")
function RageEffect:apply(battle) if battle.attacker:isAlive() then battle.conditions:of(battle.attacker).rage=true end end
Class("DefenseCurlEffect")
function DefenseCurlEffect:apply(battle) battle.conditions:of(battle.attacker).defenseCurl=true end
Class("RapidSpinEffect")
function RapidSpinEffect:apply(battle) battle.conditions:rapidSpin() end
Class("LeechSeedEffect")
function LeechSeedEffect:apply(battle) battle.conditions:leechSeed() end
Class("PartialTrapEffect")
function PartialTrapEffect:apply(battle) battle.conditions:trap() end
Class("EntryHazardEffect")
function EntryHazardEffect:init(kind) self.kind=kind end
function EntryHazardEffect:apply(battle) battle.conditions:hazard(self.kind) end

-- Explicit generated secondary provenance. Eligibility precedes chance evaluation.
Class("SecondaryEffect")
function SecondaryEffect:init(target,effect) self.target=Target.from(target);self.effect=effect end
function SecondaryEffect:apply(battle)
    local target=self.target:resolve(battle)
    if battle.effects and not battle.effects:allowsSecondary(battle.attacker,target) then return end
    self.effect:apply(battle)
end
Class("SandstormEffect")
function SandstormEffect:apply(battle) battle.effects:setSandstorm() end

Class("RandomMajorStatusEffect")
function RandomMajorStatusEffect:init(target,statuses) self.target=Target.from(target);self.statuses=statuses end
function RandomMajorStatusEffect:apply(battle)
    ApplyStatus(self.target,self.statuses[RulesRNG.random(1,#self.statuses)]):apply(battle)
end
Class("WeatherHealEffect")
function WeatherHealEffect:apply(battle)
    local mon=battle.attacker
    mon:heal(battle.effects:weatherHeal(mon));battle:say(mon.name .. " regained health!")
end
