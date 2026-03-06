-- Gen I 15-type effectiveness matrix
-- 0 = immune, 0.5 = not very effective, 1 = neutral, 2 = super effective

TypeChart = {}

local chart = {
    normal   = { rock = 0.5, ghost = 0 },
    fire     = { fire = 0.5, water = 0.5, grass = 2, ice = 2, bug = 2, rock = 0.5, dragon = 0.5 },
    water    = { fire = 2, water = 0.5, grass = 0.5, ground = 2, rock = 2, dragon = 0.5 },
    electric = { water = 2, electric = 0.5, grass = 0.5, ground = 0, flying = 2, dragon = 0.5 },
    grass    = { fire = 0.5, water = 2, grass = 0.5, poison = 0.5, ground = 2, flying = 0.5, bug = 0.5, rock = 2, dragon = 0.5 },
    ice      = { fire = 0.5, water = 0.5, grass = 2, ice = 0.5, ground = 2, flying = 2, dragon = 2 },
    fighting = { normal = 2, ice = 2, rock = 2, poison = 0.5, flying = 0.5, psychic = 0.5, bug = 0.5, ghost = 0 },
    poison   = { grass = 2, poison = 0.5, ground = 0.5, rock = 0.5, ghost = 0.5, bug = 2 },
    ground   = { fire = 2, electric = 2, grass = 0.5, poison = 2, flying = 0, rock = 2, bug = 0.5 },
    flying   = { electric = 0.5, grass = 2, fighting = 2, bug = 2, rock = 0.5 },
    psychic  = { fighting = 2, poison = 2, psychic = 0.5 },
    bug      = { fire = 0.5, grass = 2, fighting = 0.5, flying = 0.5, poison = 2, ghost = 0.5, psychic = 2 },
    rock     = { fire = 2, ice = 2, fighting = 0.5, ground = 0.5, flying = 2, bug = 2 },
    ghost    = { normal = 0, ghost = 2, psychic = 0 },
    dragon   = { dragon = 2 },
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
