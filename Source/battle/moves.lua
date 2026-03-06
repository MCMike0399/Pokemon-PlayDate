-- Gen I physical vs special split (determined by type)
local specialTypes <const> = {
    fire = true, water = true, electric = true,
    grass = true, ice = true, psychic = true, dragon = true,
}

function getMoveCategory(moveType)
    return specialTypes[moveType] and "special" or "physical"
end

-- ============================================================
-- EFFECT CLASSES — composable battle effects
-- ============================================================

-- StatChange: modify a target's stat stages
Class("StatChange")
function StatChange:init(target, stat, stages)
    self.target = target   -- "attacker" or "defender"
    self.stat = stat       -- "atk", "def", "spd", "spc"
    self.stages = stages   -- integer, negative = lower
end

function StatChange:apply(attacker, defender)
    local target = self.target == "attacker" and attacker or defender
    local oldStage = target.statStages[self.stat] or 0
    local newStage = math.max(-6, math.min(6, oldStage + self.stages))
    target.statStages[self.stat] = newStage
    local changed = newStage - oldStage
    return { type = "statChange", target = self.target, stat = self.stat, stages = changed, pokemon = target }
end

-- ConditionalEffect: apply an effect with a probability
Class("ConditionalEffect")
function ConditionalEffect:init(chance, effect)
    self.chance = chance   -- 0-100
    self.effect = effect
end

function ConditionalEffect:apply(attacker, defender)
    if math.random(1, 100) <= self.chance then
        return self.effect:apply(attacker, defender)
    end
    return nil
end

-- StatusEffect: apply a status condition (placeholder for future)
Class("StatusEffect")
function StatusEffect:init(target, status)
    self.target = target
    self.status = status
end

function StatusEffect:apply(attacker, defender)
    local target = self.target == "attacker" and attacker or defender
    if not target.status then
        target.status = self.status
        return { type = "status", target = self.target, status = self.status, pokemon = target }
    end
    return nil
end

-- ============================================================
-- MOVE CLASS
-- ============================================================

Class("Move")
function Move:init(name, moveType, power, accuracy, pp, effects)
    self.name = name
    self.type = moveType
    self.power = power
    self.accuracy = accuracy  -- 0-100
    self.pp = pp
    self.maxPP = pp
    self.category = power > 0 and getMoveCategory(moveType) or "status"
    self.effects = effects    -- optional table of Effect objects
end

-- ============================================================
-- MOVE DATA
-- ============================================================

moveData = {
    tackle   = Move("TACKLE",    "normal", 40, 95,  35, nil),
    scratch  = Move("SCRATCH",   "normal", 40, 100, 35, nil),
    ember    = Move("EMBER",     "fire",   40, 100, 25, {
        ConditionalEffect(10, StatusEffect("defender", "burn"))
    }),
    bubble   = Move("BUBBLE",    "water",  40, 100, 30, nil),
    tailWhip = Move("TAIL WHIP", "normal",  0, 100, 30, {
        StatChange("defender", "def", -1)
    }),
    growl    = Move("GROWL",     "normal",  0, 100, 40, {
        StatChange("defender", "atk", -1)
    }),
    leer     = Move("LEER",     "normal",  0, 100, 30, {
        StatChange("defender", "def", -1)
    }),
}
