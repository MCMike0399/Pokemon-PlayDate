pokemonData = {
    squirtle = {
        name = "SQUIRTLE", type = "water", type2 = nil,
        baseHP = 44, baseAtk = 48, baseDef = 65, baseSpc = 50, baseSpd = 43,
        moves = { "tackle", "tailWhip", "bubble" }
    },
    charmander = {
        name = "CHARMANDER", type = "fire", type2 = nil,
        baseHP = 39, baseAtk = 52, baseDef = 43, baseSpc = 60, baseSpd = 65,
        moves = { "scratch", "growl", "ember", "leer" }
    }
}

function calcStat(base, level)
    return math.floor(((2 * base * level) / 100) + 5)
end

function calcHP(base, level)
    return math.floor(((2 * base * level) / 100) + level + 10)
end

Class("Pokemon")

function Pokemon:init(species, level)
    local data = pokemonData[species]
    local maxHP = calcHP(data.baseHP, level)
    self.species = species
    self.name = data.name
    self.type = data.type
    self.type2 = data.type2
    self.level = level
    self.hp = maxHP
    self.maxHP = maxHP
    self.atk = calcStat(data.baseAtk, level)
    self.def = calcStat(data.baseDef, level)
    self.spc = calcStat(data.baseSpc, level)
    self.spd = calcStat(data.baseSpd, level)
    self.statStages = { atk = 0, def = 0, spc = 0, spd = 0 }
    self.status = nil
    self.moves = { table.unpack(data.moves) }
end

function Pokemon:isAlive()
    return self.hp > 0
end

function Pokemon:takeDamage(amount)
    self.hp = math.max(0, self.hp - amount)
end

function Pokemon:heal(amount)
    if amount then
        self.hp = math.min(self.maxHP, self.hp + amount)
    else
        self.hp = self.maxHP
    end
end

function Pokemon:resetStages()
    self.statStages = { atk = 0, def = 0, spc = 0, spd = 0 }
end

function Pokemon:fullRestore()
    self:heal()
    self:resetStages()
    self.status = nil
end

function createPokemon(species, level)
    return Pokemon(species, level)
end
