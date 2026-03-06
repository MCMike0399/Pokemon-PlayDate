pokemonData = {
    squirtle = {
        name = "SQUIRTLE", type = "water",
        baseHP = 44, baseAtk = 48, baseDef = 65, baseSpd = 43,
        moves = { "tackle", "tailWhip" }
    },
    charmander = {
        name = "CHARMANDER", type = "fire",
        baseHP = 39, baseAtk = 52, baseDef = 43, baseSpd = 65,
        moves = { "scratch", "growl" }
    }
}

function calcStat(base, level)
    return math.floor(((2 * base * level) / 100) + 5)
end

function calcHP(base, level)
    return math.floor(((2 * base * level) / 100) + level + 10)
end

function createPokemon(species, level)
    local data = pokemonData[species]
    local maxHP = calcHP(data.baseHP, level)
    return {
        species = species,
        name = data.name,
        type = data.type,
        level = level,
        hp = maxHP,
        maxHP = maxHP,
        atk = calcStat(data.baseAtk, level),
        def = calcStat(data.baseDef, level),
        spd = calcStat(data.baseSpd, level),
        statStages = { atk = 0, def = 0 },
        moves = { table.unpack(data.moves) }
    }
end
