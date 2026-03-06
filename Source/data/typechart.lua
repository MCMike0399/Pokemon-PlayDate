-- Gen 5 type effectiveness matrix (17 types: normal through dark)
-- 0 = immune, 0.5 = not very effective, 1 = neutral, 2 = super effective
-- Auto-generated from veekun/pokedex data

TypeChart = {}

local chart = {
    normal = { ghost = 0.0, rock = 0.5, steel = 0.5 },
    fire = { bug = 2.0, dragon = 0.5, fire = 0.5, grass = 2.0, ice = 2.0, rock = 0.5, steel = 2.0, water = 0.5 },
    water = { dragon = 0.5, fire = 2.0, grass = 0.5, ground = 2.0, rock = 2.0, water = 0.5 },
    electric = { dragon = 0.5, electric = 0.5, flying = 2.0, grass = 0.5, ground = 0.0, water = 2.0 },
    grass = { bug = 0.5, dragon = 0.5, fire = 0.5, flying = 0.5, grass = 0.5, ground = 2.0, poison = 0.5, rock = 2.0, steel = 0.5, water = 2.0 },
    ice = { dragon = 2.0, fire = 0.5, flying = 2.0, grass = 2.0, ground = 2.0, ice = 0.5, steel = 0.5, water = 0.5 },
    fighting = { bug = 0.5, dark = 2.0, flying = 0.5, ghost = 0.0, ice = 2.0, normal = 2.0, poison = 0.5, psychic = 0.5, rock = 2.0, steel = 2.0 },
    poison = { ghost = 0.5, grass = 2.0, ground = 0.5, poison = 0.5, rock = 0.5, steel = 0.0 },
    ground = { bug = 0.5, electric = 2.0, fire = 2.0, flying = 0.0, grass = 0.5, poison = 2.0, rock = 2.0, steel = 2.0 },
    flying = { bug = 2.0, electric = 0.5, fighting = 2.0, grass = 2.0, rock = 0.5, steel = 0.5 },
    psychic = { dark = 0.0, fighting = 2.0, poison = 2.0, psychic = 0.5, steel = 0.5 },
    bug = { dark = 2.0, fighting = 0.5, fire = 0.5, flying = 0.5, ghost = 0.5, grass = 2.0, poison = 0.5, psychic = 2.0, steel = 0.5 },
    rock = { bug = 2.0, fighting = 0.5, fire = 2.0, flying = 2.0, ground = 0.5, ice = 2.0, steel = 0.5 },
    ghost = { dark = 0.5, ghost = 2.0, normal = 0.0, psychic = 2.0 },
    dragon = { dragon = 2.0, steel = 0.5 },
    dark = { dark = 0.5, fighting = 0.5, ghost = 2.0, psychic = 2.0 },
    steel = { electric = 0.5, fire = 0.5, ice = 2.0, rock = 2.0, steel = 0.5, water = 0.5 },
}

function TypeChart.getEffectiveness(atkType, defType)
    if chart[atkType] and chart[atkType][defType] then
        return chart[atkType][defType]
    end
    return 1.0
end

function TypeChart.getMatchup(atkType, defType1, defType2)
    local mult = TypeChart.getEffectiveness(atkType, defType1)
    if defType2 then
        mult = mult * TypeChart.getEffectiveness(atkType, defType2)
    end
    return mult
end

function TypeChart.icon(mult)
    if mult == 0 then return "X"
    elseif mult < 1 then return "-"
    elseif mult > 1 then return "!"
    else return "" end
end
