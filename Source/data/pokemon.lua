import "data/evolutionData"
import "data/pokemonNames"
import "data/growthData"
import "domain/growth"
import "data/specimenData"
import "data/specimenTraits"
import "domain/specimen"

-- Gen I species with complete B2W2 level-up learnsets (version group 14).
-- Auto-generated from veekun/pokedex data

pokemonData = {
    bulbasaur = {
        name = "BULBASAUR", dex = 1, type = "grass", type2 = "poison",
        baseHP = 45, baseAtk = 49, baseDef = 49, baseSpA = 65, baseSpD = 65, baseSpe = 45, baseExp = 64,
        moves = { "tackle", "growl", "leechSeed", "vineWhip", "poisonPowder", "sleepPowder", "takeDown", "razorLeaf", "sweetScent", "growth", "doubleEdge", "worrySeed", "synthesis", "seedBomb" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "tackle", level = 1, order = nil, id = 33 },
            { move = "growl", level = 3, order = nil, id = 45 },
            { move = "leechSeed", level = 7, order = nil, id = 73 },
            { move = "vineWhip", level = 9, order = nil, id = 22 },
            { move = "poisonPowder", level = 13, order = 1, id = 77 },
            { move = "sleepPowder", level = 13, order = 2, id = 79 },
            { move = "takeDown", level = 15, order = nil, id = 36 },
            { move = "razorLeaf", level = 19, order = nil, id = 75 },
            { move = "sweetScent", level = 21, order = nil, id = 230 },
            { move = "growth", level = 25, order = nil, id = 74 },
            { move = "doubleEdge", level = 27, order = nil, id = 38 },
            { move = "worrySeed", level = 31, order = nil, id = 388 },
            { move = "synthesis", level = 33, order = nil, id = 235 },
            { move = "seedBomb", level = 37, order = nil, id = 402 },
        }
        -- END B2W2 LEARNSET
    },
    ivysaur = {
        name = "IVYSAUR", dex = 2, type = "grass", type2 = "poison",
        baseHP = 60, baseAtk = 62, baseDef = 63, baseSpA = 80, baseSpD = 80, baseSpe = 60, baseExp = 142,
        moves = { "tackle", "growl", "leechSeed", "growl", "leechSeed", "vineWhip", "poisonPowder", "sleepPowder", "takeDown", "razorLeaf", "sweetScent", "growth", "doubleEdge", "worrySeed", "synthesis", "solarBeam" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "tackle", level = 1, order = 1, id = 33 },
            { move = "growl", level = 1, order = 2, id = 45 },
            { move = "leechSeed", level = 1, order = 3, id = 73 },
            { move = "growl", level = 3, order = nil, id = 45 },
            { move = "leechSeed", level = 7, order = nil, id = 73 },
            { move = "vineWhip", level = 9, order = nil, id = 22 },
            { move = "poisonPowder", level = 13, order = 1, id = 77 },
            { move = "sleepPowder", level = 13, order = 2, id = 79 },
            { move = "takeDown", level = 15, order = nil, id = 36 },
            { move = "razorLeaf", level = 20, order = nil, id = 75 },
            { move = "sweetScent", level = 23, order = nil, id = 230 },
            { move = "growth", level = 28, order = nil, id = 74 },
            { move = "doubleEdge", level = 31, order = nil, id = 38 },
            { move = "worrySeed", level = 36, order = nil, id = 388 },
            { move = "synthesis", level = 39, order = nil, id = 235 },
            { move = "solarBeam", level = 44, order = nil, id = 76 },
        }
        -- END B2W2 LEARNSET
    },
    venusaur = {
        name = "VENUSAUR", dex = 3, type = "grass", type2 = "poison",
        baseHP = 80, baseAtk = 82, baseDef = 83, baseSpA = 100, baseSpD = 100, baseSpe = 80, baseExp = 236,
        moves = { "tackle", "growl", "leechSeed", "vineWhip", "growl", "leechSeed", "vineWhip", "poisonPowder", "sleepPowder", "takeDown", "razorLeaf", "sweetScent", "growth", "doubleEdge", "petalDance", "worrySeed", "synthesis", "solarBeam" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "tackle", level = 1, order = 1, id = 33 },
            { move = "growl", level = 1, order = 2, id = 45 },
            { move = "leechSeed", level = 1, order = 3, id = 73 },
            { move = "vineWhip", level = 1, order = 4, id = 22 },
            { move = "growl", level = 3, order = nil, id = 45 },
            { move = "leechSeed", level = 7, order = nil, id = 73 },
            { move = "vineWhip", level = 9, order = nil, id = 22 },
            { move = "poisonPowder", level = 13, order = 1, id = 77 },
            { move = "sleepPowder", level = 13, order = 2, id = 79 },
            { move = "takeDown", level = 15, order = nil, id = 36 },
            { move = "razorLeaf", level = 20, order = nil, id = 75 },
            { move = "sweetScent", level = 23, order = nil, id = 230 },
            { move = "growth", level = 28, order = nil, id = 74 },
            { move = "doubleEdge", level = 31, order = nil, id = 38 },
            { move = "petalDance", level = 32, order = nil, id = 80 },
            { move = "worrySeed", level = 39, order = nil, id = 388 },
            { move = "synthesis", level = 45, order = nil, id = 235 },
            { move = "solarBeam", level = 53, order = nil, id = 76 },
        }
        -- END B2W2 LEARNSET
    },
    charmander = {
        name = "CHARMANDER", dex = 4, type = "fire", type2 = nil,
        baseHP = 39, baseAtk = 52, baseDef = 43, baseSpA = 60, baseSpD = 50, baseSpe = 65, baseExp = 62,
        moves = { "scratch", "growl", "ember", "smokescreen", "dragonRage", "scaryFace", "fireFang", "flameBurst", "slash", "flamethrower", "fireSpin", "inferno" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "scratch", level = 1, order = 1, id = 10 },
            { move = "growl", level = 1, order = 2, id = 45 },
            { move = "ember", level = 7, order = nil, id = 52 },
            { move = "smokescreen", level = 10, order = nil, id = 108 },
            { move = "dragonRage", level = 16, order = nil, id = 82 },
            { move = "scaryFace", level = 19, order = nil, id = 184 },
            { move = "fireFang", level = 25, order = nil, id = 424 },
            { move = "flameBurst", level = 28, order = nil, id = 481 },
            { move = "slash", level = 34, order = nil, id = 163 },
            { move = "flamethrower", level = 37, order = nil, id = 53 },
            { move = "fireSpin", level = 43, order = nil, id = 83 },
            { move = "inferno", level = 46, order = nil, id = 517 },
        }
        -- END B2W2 LEARNSET
    },
    charmeleon = {
        name = "CHARMELEON", dex = 5, type = "fire", type2 = nil,
        baseHP = 58, baseAtk = 64, baseDef = 58, baseSpA = 80, baseSpD = 65, baseSpe = 80, baseExp = 142,
        moves = { "scratch", "growl", "ember", "ember", "smokescreen", "dragonRage", "scaryFace", "fireFang", "flameBurst", "slash", "flamethrower", "fireSpin", "inferno" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "scratch", level = 1, order = 1, id = 10 },
            { move = "growl", level = 1, order = 2, id = 45 },
            { move = "ember", level = 1, order = 3, id = 52 },
            { move = "ember", level = 7, order = nil, id = 52 },
            { move = "smokescreen", level = 10, order = nil, id = 108 },
            { move = "dragonRage", level = 17, order = nil, id = 82 },
            { move = "scaryFace", level = 21, order = nil, id = 184 },
            { move = "fireFang", level = 28, order = nil, id = 424 },
            { move = "flameBurst", level = 32, order = nil, id = 481 },
            { move = "slash", level = 39, order = nil, id = 163 },
            { move = "flamethrower", level = 43, order = nil, id = 53 },
            { move = "fireSpin", level = 50, order = nil, id = 83 },
            { move = "inferno", level = 54, order = nil, id = 517 },
        }
        -- END B2W2 LEARNSET
    },
    charizard = {
        name = "CHARIZARD", dex = 6, type = "fire", type2 = "flying",
        baseHP = 78, baseAtk = 84, baseDef = 78, baseSpA = 109, baseSpD = 85, baseSpe = 100, baseExp = 240,
        moves = { "dragonClaw", "shadowClaw", "airSlash", "scratch", "growl", "ember", "smokescreen", "ember", "smokescreen", "dragonRage", "scaryFace", "fireFang", "flameBurst", "wingAttack", "slash", "flamethrower", "fireSpin", "inferno", "heatWave", "flareBlitz" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "dragonClaw", level = 1, order = 1, id = 337 },
            { move = "shadowClaw", level = 1, order = 2, id = 421 },
            { move = "airSlash", level = 1, order = 3, id = 403 },
            { move = "scratch", level = 1, order = 4, id = 10 },
            { move = "growl", level = 1, order = 5, id = 45 },
            { move = "ember", level = 1, order = 6, id = 52 },
            { move = "smokescreen", level = 1, order = 7, id = 108 },
            { move = "ember", level = 7, order = nil, id = 52 },
            { move = "smokescreen", level = 10, order = nil, id = 108 },
            { move = "dragonRage", level = 17, order = nil, id = 82 },
            { move = "scaryFace", level = 21, order = nil, id = 184 },
            { move = "fireFang", level = 28, order = nil, id = 424 },
            { move = "flameBurst", level = 32, order = nil, id = 481 },
            { move = "wingAttack", level = 36, order = nil, id = 17 },
            { move = "slash", level = 41, order = nil, id = 163 },
            { move = "flamethrower", level = 47, order = nil, id = 53 },
            { move = "fireSpin", level = 56, order = nil, id = 83 },
            { move = "inferno", level = 62, order = nil, id = 517 },
            { move = "heatWave", level = 71, order = nil, id = 257 },
            { move = "flareBlitz", level = 77, order = nil, id = 394 },
        }
        -- END B2W2 LEARNSET
    },
    squirtle = {
        name = "SQUIRTLE", dex = 7, type = "water", type2 = nil,
        baseHP = 44, baseAtk = 48, baseDef = 65, baseSpA = 50, baseSpD = 64, baseSpe = 43, baseExp = 63,
        moves = { "tackle", "tailWhip", "bubble", "withdraw", "waterGun", "bite", "rapidSpin", "protect", "waterPulse", "aquaTail", "skullBash", "ironDefense", "rainDance", "hydroPump" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "tackle", level = 1, order = nil, id = 33 },
            { move = "tailWhip", level = 4, order = nil, id = 39 },
            { move = "bubble", level = 7, order = nil, id = 145 },
            { move = "withdraw", level = 10, order = nil, id = 110 },
            { move = "waterGun", level = 13, order = nil, id = 55 },
            { move = "bite", level = 16, order = nil, id = 44 },
            { move = "rapidSpin", level = 19, order = nil, id = 229 },
            { move = "protect", level = 22, order = nil, id = 182 },
            { move = "waterPulse", level = 25, order = nil, id = 352 },
            { move = "aquaTail", level = 28, order = nil, id = 401 },
            { move = "skullBash", level = 31, order = nil, id = 130 },
            { move = "ironDefense", level = 34, order = nil, id = 334 },
            { move = "rainDance", level = 37, order = nil, id = 240 },
            { move = "hydroPump", level = 40, order = nil, id = 56 },
        }
        -- END B2W2 LEARNSET
    },
    wartortle = {
        name = "WARTORTLE", dex = 8, type = "water", type2 = nil,
        baseHP = 59, baseAtk = 63, baseDef = 80, baseSpA = 65, baseSpD = 80, baseSpe = 58, baseExp = 142,
        moves = { "tackle", "tailWhip", "bubble", "tailWhip", "bubble", "withdraw", "waterGun", "bite", "rapidSpin", "protect", "waterPulse", "aquaTail", "skullBash", "ironDefense", "rainDance", "hydroPump" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "tackle", level = 1, order = 1, id = 33 },
            { move = "tailWhip", level = 1, order = 2, id = 39 },
            { move = "bubble", level = 1, order = 3, id = 145 },
            { move = "tailWhip", level = 4, order = nil, id = 39 },
            { move = "bubble", level = 7, order = nil, id = 145 },
            { move = "withdraw", level = 10, order = nil, id = 110 },
            { move = "waterGun", level = 13, order = nil, id = 55 },
            { move = "bite", level = 16, order = nil, id = 44 },
            { move = "rapidSpin", level = 20, order = nil, id = 229 },
            { move = "protect", level = 24, order = nil, id = 182 },
            { move = "waterPulse", level = 28, order = nil, id = 352 },
            { move = "aquaTail", level = 32, order = nil, id = 401 },
            { move = "skullBash", level = 36, order = nil, id = 130 },
            { move = "ironDefense", level = 40, order = nil, id = 334 },
            { move = "rainDance", level = 44, order = nil, id = 240 },
            { move = "hydroPump", level = 48, order = nil, id = 56 },
        }
        -- END B2W2 LEARNSET
    },
    blastoise = {
        name = "BLASTOISE", dex = 9, type = "water", type2 = nil,
        baseHP = 79, baseAtk = 83, baseDef = 100, baseSpA = 85, baseSpD = 105, baseSpe = 78, baseExp = 239,
        moves = { "flashCannon", "tackle", "tailWhip", "bubble", "withdraw", "tailWhip", "bubble", "withdraw", "waterGun", "bite", "rapidSpin", "protect", "waterPulse", "aquaTail", "skullBash", "ironDefense", "rainDance", "hydroPump" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "flashCannon", level = 1, order = 1, id = 430 },
            { move = "tackle", level = 1, order = 2, id = 33 },
            { move = "tailWhip", level = 1, order = 3, id = 39 },
            { move = "bubble", level = 1, order = 4, id = 145 },
            { move = "withdraw", level = 1, order = 5, id = 110 },
            { move = "tailWhip", level = 4, order = nil, id = 39 },
            { move = "bubble", level = 7, order = nil, id = 145 },
            { move = "withdraw", level = 10, order = nil, id = 110 },
            { move = "waterGun", level = 13, order = nil, id = 55 },
            { move = "bite", level = 16, order = nil, id = 44 },
            { move = "rapidSpin", level = 20, order = nil, id = 229 },
            { move = "protect", level = 24, order = nil, id = 182 },
            { move = "waterPulse", level = 28, order = nil, id = 352 },
            { move = "aquaTail", level = 32, order = nil, id = 401 },
            { move = "skullBash", level = 39, order = nil, id = 130 },
            { move = "ironDefense", level = 46, order = nil, id = 334 },
            { move = "rainDance", level = 53, order = nil, id = 240 },
            { move = "hydroPump", level = 60, order = nil, id = 56 },
        }
        -- END B2W2 LEARNSET
    },
    caterpie = {
        name = "CATERPIE", dex = 10, type = "bug", type2 = nil,
        baseHP = 45, baseAtk = 30, baseDef = 35, baseSpA = 20, baseSpD = 20, baseSpe = 45, baseExp = 39,
        moves = { "tackle", "stringShot", "bugBite" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "tackle", level = 1, order = 1, id = 33 },
            { move = "stringShot", level = 1, order = 2, id = 81 },
            { move = "bugBite", level = 15, order = nil, id = 450 },
        }
        -- END B2W2 LEARNSET
    },
    metapod = {
        name = "METAPOD", dex = 11, type = "bug", type2 = nil,
        baseHP = 50, baseAtk = 20, baseDef = 55, baseSpA = 25, baseSpD = 25, baseSpe = 30, baseExp = 72,
        moves = { "harden", "harden" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "harden", level = 1, order = nil, id = 106 },
            { move = "harden", level = 7, order = nil, id = 106 },
        }
        -- END B2W2 LEARNSET
    },
    butterfree = {
        name = "BUTTERFREE", dex = 12, type = "bug", type2 = "flying",
        baseHP = 60, baseAtk = 45, baseDef = 50, baseSpA = 80, baseSpD = 80, baseSpe = 70, baseExp = 173,
        moves = { "confusion", "confusion", "poisonPowder", "stunSpore", "sleepPowder", "gust", "supersonic", "whirlwind", "psybeam", "silverWind", "tailwind", "ragePowder", "safeguard", "captivate", "bugBuzz", "quiverDance" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "confusion", level = 1, order = nil, id = 93 },
            { move = "confusion", level = 10, order = nil, id = 93 },
            { move = "poisonPowder", level = 12, order = 1, id = 77 },
            { move = "stunSpore", level = 12, order = 2, id = 78 },
            { move = "sleepPowder", level = 12, order = 3, id = 79 },
            { move = "gust", level = 16, order = nil, id = 16 },
            { move = "supersonic", level = 18, order = nil, id = 48 },
            { move = "whirlwind", level = 22, order = nil, id = 18 },
            { move = "psybeam", level = 24, order = nil, id = 60 },
            { move = "silverWind", level = 28, order = nil, id = 318 },
            { move = "tailwind", level = 30, order = nil, id = 366 },
            { move = "ragePowder", level = 34, order = nil, id = 476 },
            { move = "safeguard", level = 36, order = nil, id = 219 },
            { move = "captivate", level = 40, order = nil, id = 445 },
            { move = "bugBuzz", level = 42, order = nil, id = 405 },
            { move = "quiverDance", level = 46, order = nil, id = 483 },
        }
        -- END B2W2 LEARNSET
    },
    weedle = {
        name = "WEEDLE", dex = 13, type = "bug", type2 = "poison",
        baseHP = 40, baseAtk = 35, baseDef = 30, baseSpA = 20, baseSpD = 20, baseSpe = 50, baseExp = 39,
        moves = { "poisonSting", "stringShot", "bugBite" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "poisonSting", level = 1, order = 1, id = 40 },
            { move = "stringShot", level = 1, order = 2, id = 81 },
            { move = "bugBite", level = 15, order = nil, id = 450 },
        }
        -- END B2W2 LEARNSET
    },
    kakuna = {
        name = "KAKUNA", dex = 14, type = "bug", type2 = "poison",
        baseHP = 45, baseAtk = 25, baseDef = 50, baseSpA = 25, baseSpD = 25, baseSpe = 35, baseExp = 72,
        moves = { "harden", "harden" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "harden", level = 1, order = nil, id = 106 },
            { move = "harden", level = 7, order = nil, id = 106 },
        }
        -- END B2W2 LEARNSET
    },
    beedrill = {
        name = "BEEDRILL", dex = 15, type = "bug", type2 = "poison",
        baseHP = 65, baseAtk = 80, baseDef = 40, baseSpA = 45, baseSpD = 80, baseSpe = 75, baseExp = 173,
        moves = { "furyAttack", "furyAttack", "focusEnergy", "twineedle", "rage", "pursuit", "toxicSpikes", "pinMissile", "agility", "assurance", "poisonJab", "endeavor" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "furyAttack", level = 1, order = nil, id = 31 },
            { move = "furyAttack", level = 10, order = nil, id = 31 },
            { move = "focusEnergy", level = 13, order = nil, id = 116 },
            { move = "twineedle", level = 16, order = nil, id = 41 },
            { move = "rage", level = 19, order = nil, id = 99 },
            { move = "pursuit", level = 22, order = nil, id = 228 },
            { move = "toxicSpikes", level = 25, order = nil, id = 390 },
            { move = "pinMissile", level = 28, order = nil, id = 42 },
            { move = "agility", level = 31, order = nil, id = 97 },
            { move = "assurance", level = 34, order = nil, id = 372 },
            { move = "poisonJab", level = 37, order = nil, id = 398 },
            { move = "endeavor", level = 40, order = nil, id = 283 },
        }
        -- END B2W2 LEARNSET
    },
    pidgey = {
        name = "PIDGEY", dex = 16, type = "normal", type2 = "flying",
        baseHP = 40, baseAtk = 45, baseDef = 40, baseSpA = 35, baseSpD = 35, baseSpe = 56, baseExp = 50,
        moves = { "tackle", "sandAttack", "gust", "quickAttack", "whirlwind", "twister", "featherDance", "agility", "wingAttack", "roost", "tailwind", "mirrorMove", "airSlash", "hurricane" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "tackle", level = 1, order = nil, id = 33 },
            { move = "sandAttack", level = 5, order = nil, id = 28 },
            { move = "gust", level = 9, order = nil, id = 16 },
            { move = "quickAttack", level = 13, order = nil, id = 98 },
            { move = "whirlwind", level = 17, order = nil, id = 18 },
            { move = "twister", level = 21, order = nil, id = 239 },
            { move = "featherDance", level = 25, order = nil, id = 297 },
            { move = "agility", level = 29, order = nil, id = 97 },
            { move = "wingAttack", level = 33, order = nil, id = 17 },
            { move = "roost", level = 37, order = nil, id = 355 },
            { move = "tailwind", level = 41, order = nil, id = 366 },
            { move = "mirrorMove", level = 45, order = nil, id = 119 },
            { move = "airSlash", level = 49, order = nil, id = 403 },
            { move = "hurricane", level = 53, order = nil, id = 542 },
        }
        -- END B2W2 LEARNSET
    },
    pidgeotto = {
        name = "PIDGEOTTO", dex = 17, type = "normal", type2 = "flying",
        baseHP = 63, baseAtk = 60, baseDef = 55, baseSpA = 50, baseSpD = 50, baseSpe = 71, baseExp = 122,
        moves = { "tackle", "sandAttack", "gust", "sandAttack", "gust", "quickAttack", "whirlwind", "twister", "featherDance", "agility", "wingAttack", "roost", "tailwind", "mirrorMove", "airSlash", "hurricane" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "tackle", level = 1, order = 1, id = 33 },
            { move = "sandAttack", level = 1, order = 2, id = 28 },
            { move = "gust", level = 1, order = 3, id = 16 },
            { move = "sandAttack", level = 5, order = nil, id = 28 },
            { move = "gust", level = 9, order = nil, id = 16 },
            { move = "quickAttack", level = 13, order = nil, id = 98 },
            { move = "whirlwind", level = 17, order = nil, id = 18 },
            { move = "twister", level = 22, order = nil, id = 239 },
            { move = "featherDance", level = 27, order = nil, id = 297 },
            { move = "agility", level = 32, order = nil, id = 97 },
            { move = "wingAttack", level = 37, order = nil, id = 17 },
            { move = "roost", level = 42, order = nil, id = 355 },
            { move = "tailwind", level = 47, order = nil, id = 366 },
            { move = "mirrorMove", level = 52, order = nil, id = 119 },
            { move = "airSlash", level = 57, order = nil, id = 403 },
            { move = "hurricane", level = 62, order = nil, id = 542 },
        }
        -- END B2W2 LEARNSET
    },
    pidgeot = {
        name = "PIDGEOT", dex = 18, type = "normal", type2 = "flying",
        baseHP = 83, baseAtk = 80, baseDef = 75, baseSpA = 70, baseSpD = 70, baseSpe = 91, baseExp = 211,
        moves = { "tackle", "sandAttack", "gust", "quickAttack", "sandAttack", "gust", "quickAttack", "whirlwind", "twister", "featherDance", "agility", "wingAttack", "roost", "tailwind", "mirrorMove", "airSlash", "hurricane" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "tackle", level = 1, order = 1, id = 33 },
            { move = "sandAttack", level = 1, order = 2, id = 28 },
            { move = "gust", level = 1, order = 3, id = 16 },
            { move = "quickAttack", level = 1, order = 4, id = 98 },
            { move = "sandAttack", level = 5, order = nil, id = 28 },
            { move = "gust", level = 9, order = nil, id = 16 },
            { move = "quickAttack", level = 13, order = nil, id = 98 },
            { move = "whirlwind", level = 17, order = nil, id = 18 },
            { move = "twister", level = 22, order = nil, id = 239 },
            { move = "featherDance", level = 27, order = nil, id = 297 },
            { move = "agility", level = 32, order = nil, id = 97 },
            { move = "wingAttack", level = 38, order = nil, id = 17 },
            { move = "roost", level = 44, order = nil, id = 355 },
            { move = "tailwind", level = 50, order = nil, id = 366 },
            { move = "mirrorMove", level = 56, order = nil, id = 119 },
            { move = "airSlash", level = 62, order = nil, id = 403 },
            { move = "hurricane", level = 68, order = nil, id = 542 },
        }
        -- END B2W2 LEARNSET
    },
    rattata = {
        name = "RATTATA", dex = 19, type = "normal", type2 = nil,
        baseHP = 30, baseAtk = 56, baseDef = 35, baseSpA = 25, baseSpD = 35, baseSpe = 72, baseExp = 51,
        moves = { "tackle", "tailWhip", "quickAttack", "focusEnergy", "bite", "pursuit", "hyperFang", "suckerPunch", "crunch", "assurance", "superFang", "doubleEdge", "endeavor" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "tackle", level = 1, order = 1, id = 33 },
            { move = "tailWhip", level = 1, order = 2, id = 39 },
            { move = "quickAttack", level = 4, order = nil, id = 98 },
            { move = "focusEnergy", level = 7, order = nil, id = 116 },
            { move = "bite", level = 10, order = nil, id = 44 },
            { move = "pursuit", level = 13, order = nil, id = 228 },
            { move = "hyperFang", level = 16, order = nil, id = 158 },
            { move = "suckerPunch", level = 19, order = nil, id = 389 },
            { move = "crunch", level = 22, order = nil, id = 242 },
            { move = "assurance", level = 25, order = nil, id = 372 },
            { move = "superFang", level = 28, order = nil, id = 162 },
            { move = "doubleEdge", level = 31, order = nil, id = 38 },
            { move = "endeavor", level = 34, order = nil, id = 283 },
        }
        -- END B2W2 LEARNSET
    },
    raticate = {
        name = "RATICATE", dex = 20, type = "normal", type2 = nil,
        baseHP = 55, baseAtk = 81, baseDef = 60, baseSpA = 50, baseSpD = 70, baseSpe = 97, baseExp = 145,
        moves = { "swordsDance", "tackle", "tailWhip", "quickAttack", "focusEnergy", "quickAttack", "focusEnergy", "bite", "pursuit", "hyperFang", "suckerPunch", "scaryFace", "crunch", "assurance", "superFang", "doubleEdge", "endeavor" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "swordsDance", level = 1, order = 1, id = 14 },
            { move = "tackle", level = 1, order = 2, id = 33 },
            { move = "tailWhip", level = 1, order = 3, id = 39 },
            { move = "quickAttack", level = 1, order = 4, id = 98 },
            { move = "focusEnergy", level = 1, order = 5, id = 116 },
            { move = "quickAttack", level = 4, order = nil, id = 98 },
            { move = "focusEnergy", level = 7, order = nil, id = 116 },
            { move = "bite", level = 10, order = nil, id = 44 },
            { move = "pursuit", level = 13, order = nil, id = 228 },
            { move = "hyperFang", level = 16, order = nil, id = 158 },
            { move = "suckerPunch", level = 19, order = nil, id = 389 },
            { move = "scaryFace", level = 20, order = nil, id = 184 },
            { move = "crunch", level = 24, order = nil, id = 242 },
            { move = "assurance", level = 29, order = nil, id = 372 },
            { move = "superFang", level = 34, order = nil, id = 162 },
            { move = "doubleEdge", level = 39, order = nil, id = 38 },
            { move = "endeavor", level = 44, order = nil, id = 283 },
        }
        -- END B2W2 LEARNSET
    },
    spearow = {
        name = "SPEAROW", dex = 21, type = "normal", type2 = "flying",
        baseHP = 40, baseAtk = 60, baseDef = 30, baseSpA = 31, baseSpD = 31, baseSpe = 70, baseExp = 52,
        moves = { "peck", "growl", "leer", "furyAttack", "pursuit", "aerialAce", "mirrorMove", "agility", "assurance", "roost", "drillPeck" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "peck", level = 1, order = 1, id = 64 },
            { move = "growl", level = 1, order = 2, id = 45 },
            { move = "leer", level = 5, order = nil, id = 43 },
            { move = "furyAttack", level = 9, order = nil, id = 31 },
            { move = "pursuit", level = 13, order = nil, id = 228 },
            { move = "aerialAce", level = 17, order = nil, id = 332 },
            { move = "mirrorMove", level = 21, order = nil, id = 119 },
            { move = "agility", level = 25, order = nil, id = 97 },
            { move = "assurance", level = 29, order = nil, id = 372 },
            { move = "roost", level = 33, order = nil, id = 355 },
            { move = "drillPeck", level = 37, order = nil, id = 65 },
        }
        -- END B2W2 LEARNSET
    },
    fearow = {
        name = "FEAROW", dex = 22, type = "normal", type2 = "flying",
        baseHP = 65, baseAtk = 90, baseDef = 65, baseSpA = 61, baseSpD = 61, baseSpe = 100, baseExp = 155,
        moves = { "pluck", "peck", "growl", "leer", "furyAttack", "leer", "furyAttack", "pursuit", "aerialAce", "mirrorMove", "agility", "assurance", "roost", "drillPeck", "drillRun" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "pluck", level = 1, order = 1, id = 365 },
            { move = "peck", level = 1, order = 2, id = 64 },
            { move = "growl", level = 1, order = 3, id = 45 },
            { move = "leer", level = 1, order = 4, id = 43 },
            { move = "furyAttack", level = 1, order = 5, id = 31 },
            { move = "leer", level = 5, order = nil, id = 43 },
            { move = "furyAttack", level = 9, order = nil, id = 31 },
            { move = "pursuit", level = 13, order = nil, id = 228 },
            { move = "aerialAce", level = 17, order = nil, id = 332 },
            { move = "mirrorMove", level = 23, order = nil, id = 119 },
            { move = "agility", level = 29, order = nil, id = 97 },
            { move = "assurance", level = 35, order = nil, id = 372 },
            { move = "roost", level = 41, order = nil, id = 355 },
            { move = "drillPeck", level = 47, order = nil, id = 65 },
            { move = "drillRun", level = 53, order = nil, id = 529 },
        }
        -- END B2W2 LEARNSET
    },
    ekans = {
        name = "EKANS", dex = 23, type = "poison", type2 = nil,
        baseHP = 35, baseAtk = 60, baseDef = 44, baseSpA = 40, baseSpD = 54, baseSpe = 55, baseExp = 58,
        moves = { "wrap", "leer", "poisonSting", "bite", "glare", "screech", "acid", "stockpile", "swallow", "spitUp", "acidSpray", "mudBomb", "gastroAcid", "haze", "coil", "gunkShot" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "wrap", level = 1, order = 1, id = 35 },
            { move = "leer", level = 1, order = 2, id = 43 },
            { move = "poisonSting", level = 4, order = nil, id = 40 },
            { move = "bite", level = 9, order = nil, id = 44 },
            { move = "glare", level = 12, order = nil, id = 137 },
            { move = "screech", level = 17, order = nil, id = 103 },
            { move = "acid", level = 20, order = nil, id = 51 },
            { move = "stockpile", level = 25, order = 1, id = 254 },
            { move = "swallow", level = 25, order = 2, id = 256 },
            { move = "spitUp", level = 25, order = 3, id = 255 },
            { move = "acidSpray", level = 28, order = nil, id = 491 },
            { move = "mudBomb", level = 33, order = nil, id = 426 },
            { move = "gastroAcid", level = 36, order = nil, id = 380 },
            { move = "haze", level = 41, order = nil, id = 114 },
            { move = "coil", level = 44, order = nil, id = 489 },
            { move = "gunkShot", level = 49, order = nil, id = 441 },
        }
        -- END B2W2 LEARNSET
    },
    arbok = {
        name = "ARBOK", dex = 24, type = "poison", type2 = nil,
        baseHP = 60, baseAtk = 85, baseDef = 69, baseSpA = 65, baseSpD = 79, baseSpe = 80, baseExp = 153,
        moves = { "iceFang", "thunderFang", "fireFang", "wrap", "leer", "poisonSting", "bite", "poisonSting", "bite", "glare", "screech", "acid", "crunch", "stockpile", "swallow", "spitUp", "acidSpray", "mudBomb", "gastroAcid", "haze", "coil", "gunkShot" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "iceFang", level = 1, order = 1, id = 423 },
            { move = "thunderFang", level = 1, order = 2, id = 422 },
            { move = "fireFang", level = 1, order = 3, id = 424 },
            { move = "wrap", level = 1, order = 4, id = 35 },
            { move = "leer", level = 1, order = 5, id = 43 },
            { move = "poisonSting", level = 1, order = 6, id = 40 },
            { move = "bite", level = 1, order = 7, id = 44 },
            { move = "poisonSting", level = 4, order = nil, id = 40 },
            { move = "bite", level = 9, order = nil, id = 44 },
            { move = "glare", level = 12, order = nil, id = 137 },
            { move = "screech", level = 17, order = nil, id = 103 },
            { move = "acid", level = 20, order = nil, id = 51 },
            { move = "crunch", level = 22, order = nil, id = 242 },
            { move = "stockpile", level = 27, order = 1, id = 254 },
            { move = "swallow", level = 27, order = 2, id = 256 },
            { move = "spitUp", level = 27, order = 3, id = 255 },
            { move = "acidSpray", level = 32, order = nil, id = 491 },
            { move = "mudBomb", level = 39, order = nil, id = 426 },
            { move = "gastroAcid", level = 44, order = nil, id = 380 },
            { move = "haze", level = 51, order = nil, id = 114 },
            { move = "coil", level = 56, order = nil, id = 489 },
            { move = "gunkShot", level = 63, order = nil, id = 441 },
        }
        -- END B2W2 LEARNSET
    },
    pikachu = {
        name = "PIKACHU", dex = 25, type = "electric", type2 = nil,
        baseHP = 35, baseAtk = 55, baseDef = 30, baseSpA = 50, baseSpD = 40, baseSpe = 90, baseExp = 105,
        moves = { "growl", "thunderShock", "tailWhip", "thunderWave", "quickAttack", "electroBall", "doubleTeam", "slam", "thunderbolt", "feint", "agility", "discharge", "lightScreen", "thunder" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "growl", level = 1, order = 1, id = 45 },
            { move = "thunderShock", level = 1, order = 2, id = 84 },
            { move = "tailWhip", level = 5, order = nil, id = 39 },
            { move = "thunderWave", level = 10, order = nil, id = 86 },
            { move = "quickAttack", level = 13, order = nil, id = 98 },
            { move = "electroBall", level = 18, order = nil, id = 486 },
            { move = "doubleTeam", level = 21, order = nil, id = 104 },
            { move = "slam", level = 26, order = nil, id = 21 },
            { move = "thunderbolt", level = 29, order = nil, id = 85 },
            { move = "feint", level = 34, order = nil, id = 364 },
            { move = "agility", level = 37, order = nil, id = 97 },
            { move = "discharge", level = 42, order = nil, id = 435 },
            { move = "lightScreen", level = 45, order = nil, id = 113 },
            { move = "thunder", level = 50, order = nil, id = 87 },
        }
        -- END B2W2 LEARNSET
    },
    raichu = {
        name = "RAICHU", dex = 26, type = "electric", type2 = nil,
        baseHP = 60, baseAtk = 90, baseDef = 55, baseSpA = 90, baseSpD = 80, baseSpe = 100, baseExp = 214,
        moves = { "thunderShock", "tailWhip", "quickAttack", "thunderbolt" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "thunderShock", level = 1, order = 1, id = 84 },
            { move = "tailWhip", level = 1, order = 2, id = 39 },
            { move = "quickAttack", level = 1, order = 3, id = 98 },
            { move = "thunderbolt", level = 1, order = 4, id = 85 },
        }
        -- END B2W2 LEARNSET
    },
    sandshrew = {
        name = "SANDSHREW", dex = 27, type = "ground", type2 = nil,
        baseHP = 50, baseAtk = 75, baseDef = 85, baseSpA = 20, baseSpD = 30, baseSpe = 40, baseExp = 60,
        moves = { "scratch", "defenseCurl", "sandAttack", "poisonSting", "rollout", "rapidSpin", "swift", "furyCutter", "magnitude", "furySwipes", "sandTomb", "slash", "dig", "gyroBall", "swordsDance", "sandstorm", "earthquake" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "scratch", level = 1, order = 1, id = 10 },
            { move = "defenseCurl", level = 1, order = 2, id = 111 },
            { move = "sandAttack", level = 3, order = nil, id = 28 },
            { move = "poisonSting", level = 5, order = nil, id = 40 },
            { move = "rollout", level = 7, order = nil, id = 205 },
            { move = "rapidSpin", level = 9, order = nil, id = 229 },
            { move = "swift", level = 11, order = nil, id = 129 },
            { move = "furyCutter", level = 14, order = nil, id = 210 },
            { move = "magnitude", level = 17, order = nil, id = 222 },
            { move = "furySwipes", level = 20, order = nil, id = 154 },
            { move = "sandTomb", level = 23, order = nil, id = 328 },
            { move = "slash", level = 26, order = nil, id = 163 },
            { move = "dig", level = 30, order = nil, id = 91 },
            { move = "gyroBall", level = 34, order = nil, id = 360 },
            { move = "swordsDance", level = 38, order = nil, id = 14 },
            { move = "sandstorm", level = 42, order = nil, id = 201 },
            { move = "earthquake", level = 46, order = nil, id = 89 },
        }
        -- END B2W2 LEARNSET
    },
    sandslash = {
        name = "SANDSLASH", dex = 28, type = "ground", type2 = nil,
        baseHP = 75, baseAtk = 100, baseDef = 110, baseSpA = 45, baseSpD = 55, baseSpe = 65, baseExp = 158,
        moves = { "scratch", "defenseCurl", "sandAttack", "poisonSting", "sandAttack", "poisonSting", "rollout", "rapidSpin", "swift", "furyCutter", "magnitude", "furySwipes", "crushClaw", "sandTomb", "slash", "dig", "gyroBall", "swordsDance", "sandstorm", "earthquake" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "scratch", level = 1, order = 1, id = 10 },
            { move = "defenseCurl", level = 1, order = 2, id = 111 },
            { move = "sandAttack", level = 1, order = 3, id = 28 },
            { move = "poisonSting", level = 1, order = 4, id = 40 },
            { move = "sandAttack", level = 3, order = nil, id = 28 },
            { move = "poisonSting", level = 5, order = nil, id = 40 },
            { move = "rollout", level = 7, order = nil, id = 205 },
            { move = "rapidSpin", level = 9, order = nil, id = 229 },
            { move = "swift", level = 11, order = nil, id = 129 },
            { move = "furyCutter", level = 14, order = nil, id = 210 },
            { move = "magnitude", level = 17, order = nil, id = 222 },
            { move = "furySwipes", level = 20, order = nil, id = 154 },
            { move = "crushClaw", level = 22, order = nil, id = 306 },
            { move = "sandTomb", level = 23, order = nil, id = 328 },
            { move = "slash", level = 26, order = nil, id = 163 },
            { move = "dig", level = 30, order = nil, id = 91 },
            { move = "gyroBall", level = 34, order = nil, id = 360 },
            { move = "swordsDance", level = 38, order = nil, id = 14 },
            { move = "sandstorm", level = 42, order = nil, id = 201 },
            { move = "earthquake", level = 46, order = nil, id = 89 },
        }
        -- END B2W2 LEARNSET
    },
    nidoranF = {
        name = "NIDORAN F", dex = 29, type = "poison", type2 = nil,
        baseHP = 55, baseAtk = 47, baseDef = 52, baseSpA = 40, baseSpD = 40, baseSpe = 41, baseExp = 55,
        moves = { "growl", "scratch", "tailWhip", "doubleKick", "poisonSting", "furySwipes", "bite", "helpingHand", "toxicSpikes", "flatter", "crunch", "captivate", "poisonFang" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "growl", level = 1, order = 1, id = 45 },
            { move = "scratch", level = 1, order = 2, id = 10 },
            { move = "tailWhip", level = 7, order = nil, id = 39 },
            { move = "doubleKick", level = 9, order = nil, id = 24 },
            { move = "poisonSting", level = 13, order = nil, id = 40 },
            { move = "furySwipes", level = 19, order = nil, id = 154 },
            { move = "bite", level = 21, order = nil, id = 44 },
            { move = "helpingHand", level = 25, order = nil, id = 270 },
            { move = "toxicSpikes", level = 31, order = nil, id = 390 },
            { move = "flatter", level = 33, order = nil, id = 260 },
            { move = "crunch", level = 37, order = nil, id = 242 },
            { move = "captivate", level = 43, order = nil, id = 445 },
            { move = "poisonFang", level = 45, order = nil, id = 305 },
        }
        -- END B2W2 LEARNSET
    },
    nidorina = {
        name = "NIDORINA", dex = 30, type = "poison", type2 = nil,
        baseHP = 70, baseAtk = 62, baseDef = 67, baseSpA = 55, baseSpD = 55, baseSpe = 56, baseExp = 128,
        moves = { "growl", "scratch", "tailWhip", "doubleKick", "poisonSting", "furySwipes", "bite", "helpingHand", "toxicSpikes", "flatter", "crunch", "captivate", "poisonFang" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "growl", level = 1, order = 1, id = 45 },
            { move = "scratch", level = 1, order = 2, id = 10 },
            { move = "tailWhip", level = 7, order = nil, id = 39 },
            { move = "doubleKick", level = 9, order = nil, id = 24 },
            { move = "poisonSting", level = 13, order = nil, id = 40 },
            { move = "furySwipes", level = 20, order = nil, id = 154 },
            { move = "bite", level = 23, order = nil, id = 44 },
            { move = "helpingHand", level = 28, order = nil, id = 270 },
            { move = "toxicSpikes", level = 35, order = nil, id = 390 },
            { move = "flatter", level = 38, order = nil, id = 260 },
            { move = "crunch", level = 43, order = nil, id = 242 },
            { move = "captivate", level = 50, order = nil, id = 445 },
            { move = "poisonFang", level = 58, order = nil, id = 305 },
        }
        -- END B2W2 LEARNSET
    },
    nidoqueen = {
        name = "NIDOQUEEN", dex = 31, type = "poison", type2 = "ground",
        baseHP = 90, baseAtk = 82, baseDef = 87, baseSpA = 75, baseSpD = 85, baseSpe = 76, baseExp = 223,
        moves = { "scratch", "tailWhip", "doubleKick", "poisonSting", "chipAway", "bodySlam", "earthPower", "superpower" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "scratch", level = 1, order = 1, id = 10 },
            { move = "tailWhip", level = 1, order = 2, id = 39 },
            { move = "doubleKick", level = 1, order = 3, id = 24 },
            { move = "poisonSting", level = 1, order = 4, id = 40 },
            { move = "chipAway", level = 23, order = nil, id = 498 },
            { move = "bodySlam", level = 35, order = nil, id = 34 },
            { move = "earthPower", level = 43, order = nil, id = 414 },
            { move = "superpower", level = 58, order = nil, id = 276 },
        }
        -- END B2W2 LEARNSET
    },
    nidoranM = {
        name = "NIDORAN M", dex = 32, type = "poison", type2 = nil,
        baseHP = 46, baseAtk = 57, baseDef = 40, baseSpA = 40, baseSpD = 40, baseSpe = 50, baseExp = 55,
        moves = { "leer", "peck", "focusEnergy", "doubleKick", "poisonSting", "furyAttack", "hornAttack", "helpingHand", "toxicSpikes", "flatter", "poisonJab", "captivate", "hornDrill" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "leer", level = 1, order = 1, id = 43 },
            { move = "peck", level = 1, order = 2, id = 64 },
            { move = "focusEnergy", level = 7, order = nil, id = 116 },
            { move = "doubleKick", level = 9, order = nil, id = 24 },
            { move = "poisonSting", level = 13, order = nil, id = 40 },
            { move = "furyAttack", level = 19, order = nil, id = 31 },
            { move = "hornAttack", level = 21, order = nil, id = 30 },
            { move = "helpingHand", level = 25, order = nil, id = 270 },
            { move = "toxicSpikes", level = 31, order = nil, id = 390 },
            { move = "flatter", level = 33, order = nil, id = 260 },
            { move = "poisonJab", level = 37, order = nil, id = 398 },
            { move = "captivate", level = 43, order = nil, id = 445 },
            { move = "hornDrill", level = 45, order = nil, id = 32 },
        }
        -- END B2W2 LEARNSET
    },
    nidorino = {
        name = "NIDORINO", dex = 33, type = "poison", type2 = nil,
        baseHP = 61, baseAtk = 72, baseDef = 57, baseSpA = 55, baseSpD = 55, baseSpe = 65, baseExp = 128,
        moves = { "leer", "peck", "focusEnergy", "doubleKick", "poisonSting", "furyAttack", "hornAttack", "helpingHand", "toxicSpikes", "flatter", "poisonJab", "captivate", "hornDrill" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "leer", level = 1, order = 1, id = 43 },
            { move = "peck", level = 1, order = 2, id = 64 },
            { move = "focusEnergy", level = 7, order = nil, id = 116 },
            { move = "doubleKick", level = 9, order = nil, id = 24 },
            { move = "poisonSting", level = 13, order = nil, id = 40 },
            { move = "furyAttack", level = 20, order = nil, id = 31 },
            { move = "hornAttack", level = 23, order = nil, id = 30 },
            { move = "helpingHand", level = 28, order = nil, id = 270 },
            { move = "toxicSpikes", level = 35, order = nil, id = 390 },
            { move = "flatter", level = 38, order = nil, id = 260 },
            { move = "poisonJab", level = 43, order = nil, id = 398 },
            { move = "captivate", level = 50, order = nil, id = 445 },
            { move = "hornDrill", level = 58, order = nil, id = 32 },
        }
        -- END B2W2 LEARNSET
    },
    nidoking = {
        name = "NIDOKING", dex = 34, type = "poison", type2 = "ground",
        baseHP = 81, baseAtk = 92, baseDef = 77, baseSpA = 85, baseSpD = 75, baseSpe = 85, baseExp = 223,
        moves = { "peck", "focusEnergy", "doubleKick", "poisonSting", "chipAway", "thrash", "earthPower", "megahorn" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "peck", level = 1, order = 1, id = 64 },
            { move = "focusEnergy", level = 1, order = 2, id = 116 },
            { move = "doubleKick", level = 1, order = 3, id = 24 },
            { move = "poisonSting", level = 1, order = 4, id = 40 },
            { move = "chipAway", level = 23, order = nil, id = 498 },
            { move = "thrash", level = 35, order = nil, id = 37 },
            { move = "earthPower", level = 43, order = nil, id = 414 },
            { move = "megahorn", level = 58, order = nil, id = 224 },
        }
        -- END B2W2 LEARNSET
    },
    clefairy = {
        name = "CLEFAIRY", dex = 35, type = "normal", type2 = nil,
        baseHP = 70, baseAtk = 45, baseDef = 48, baseSpA = 60, baseSpD = 65, baseSpe = 35, baseExp = 113,
        moves = { "pound", "growl", "encore", "sing", "doubleSlap", "defenseCurl", "followMe", "bestow", "wakeUpSlap", "minimize", "storedPower", "metronome", "cosmicPower", "luckyChant", "bodySlam", "moonlight", "lightScreen", "gravity", "meteorMash", "healingWish", "afterYou" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "pound", level = 1, order = 1, id = 1 },
            { move = "growl", level = 1, order = 2, id = 45 },
            { move = "encore", level = 4, order = nil, id = 227 },
            { move = "sing", level = 7, order = nil, id = 47 },
            { move = "doubleSlap", level = 10, order = nil, id = 3 },
            { move = "defenseCurl", level = 13, order = nil, id = 111 },
            { move = "followMe", level = 16, order = nil, id = 266 },
            { move = "bestow", level = 19, order = nil, id = 516 },
            { move = "wakeUpSlap", level = 22, order = nil, id = 358 },
            { move = "minimize", level = 25, order = nil, id = 107 },
            { move = "storedPower", level = 28, order = nil, id = 500 },
            { move = "metronome", level = 31, order = nil, id = 118 },
            { move = "cosmicPower", level = 34, order = nil, id = 322 },
            { move = "luckyChant", level = 37, order = nil, id = 381 },
            { move = "bodySlam", level = 40, order = nil, id = 34 },
            { move = "moonlight", level = 43, order = nil, id = 236 },
            { move = "lightScreen", level = 46, order = nil, id = 113 },
            { move = "gravity", level = 49, order = nil, id = 356 },
            { move = "meteorMash", level = 52, order = nil, id = 309 },
            { move = "healingWish", level = 55, order = nil, id = 361 },
            { move = "afterYou", level = 58, order = nil, id = 495 },
        }
        -- END B2W2 LEARNSET
    },
    clefable = {
        name = "CLEFABLE", dex = 36, type = "normal", type2 = nil,
        baseHP = 95, baseAtk = 70, baseDef = 73, baseSpA = 85, baseSpD = 90, baseSpe = 60, baseExp = 213,
        moves = { "sing", "doubleSlap", "minimize", "metronome" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "sing", level = 1, order = 1, id = 47 },
            { move = "doubleSlap", level = 1, order = 2, id = 3 },
            { move = "minimize", level = 1, order = 3, id = 107 },
            { move = "metronome", level = 1, order = 4, id = 118 },
        }
        -- END B2W2 LEARNSET
    },
    vulpix = {
        name = "VULPIX", dex = 37, type = "fire", type2 = nil,
        baseHP = 38, baseAtk = 41, baseDef = 40, baseSpA = 50, baseSpD = 65, baseSpe = 65, baseExp = 60,
        moves = { "ember", "tailWhip", "roar", "quickAttack", "fireSpin", "confuseRay", "imprison", "feintAttack", "flameBurst", "willOWisp", "hex", "payback", "flamethrower", "safeguard", "extrasensory", "fireBlast", "grudge", "captivate", "inferno" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "ember", level = 1, order = nil, id = 52 },
            { move = "tailWhip", level = 4, order = nil, id = 39 },
            { move = "roar", level = 7, order = nil, id = 46 },
            { move = "quickAttack", level = 10, order = nil, id = 98 },
            { move = "fireSpin", level = 12, order = nil, id = 83 },
            { move = "confuseRay", level = 15, order = nil, id = 109 },
            { move = "imprison", level = 18, order = nil, id = 286 },
            { move = "feintAttack", level = 20, order = nil, id = 185 },
            { move = "flameBurst", level = 23, order = nil, id = 481 },
            { move = "willOWisp", level = 26, order = nil, id = 261 },
            { move = "hex", level = 28, order = nil, id = 506 },
            { move = "payback", level = 31, order = nil, id = 371 },
            { move = "flamethrower", level = 34, order = nil, id = 53 },
            { move = "safeguard", level = 36, order = nil, id = 219 },
            { move = "extrasensory", level = 39, order = nil, id = 326 },
            { move = "fireBlast", level = 42, order = nil, id = 126 },
            { move = "grudge", level = 44, order = nil, id = 288 },
            { move = "captivate", level = 47, order = nil, id = 445 },
            { move = "inferno", level = 50, order = nil, id = 517 },
        }
        -- END B2W2 LEARNSET
    },
    ninetales = {
        name = "NINETALES", dex = 38, type = "fire", type2 = nil,
        baseHP = 73, baseAtk = 76, baseDef = 75, baseSpA = 81, baseSpD = 100, baseSpe = 100, baseExp = 177,
        moves = { "nastyPlot", "ember", "quickAttack", "confuseRay", "safeguard" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "nastyPlot", level = 1, order = 1, id = 417 },
            { move = "ember", level = 1, order = 2, id = 52 },
            { move = "quickAttack", level = 1, order = 3, id = 98 },
            { move = "confuseRay", level = 1, order = 4, id = 109 },
            { move = "safeguard", level = 1, order = 5, id = 219 },
        }
        -- END B2W2 LEARNSET
    },
    jigglypuff = {
        name = "JIGGLYPUFF", dex = 39, type = "normal", type2 = nil,
        baseHP = 115, baseAtk = 45, baseDef = 20, baseSpA = 45, baseSpD = 25, baseSpe = 20, baseExp = 95,
        moves = { "sing", "defenseCurl", "pound", "disable", "round", "rollout", "doubleSlap", "rest", "bodySlam", "gyroBall", "wakeUpSlap", "mimic", "hyperVoice", "doubleEdge" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "sing", level = 1, order = nil, id = 47 },
            { move = "defenseCurl", level = 5, order = nil, id = 111 },
            { move = "pound", level = 9, order = nil, id = 1 },
            { move = "disable", level = 13, order = nil, id = 50 },
            { move = "round", level = 17, order = nil, id = 496 },
            { move = "rollout", level = 21, order = nil, id = 205 },
            { move = "doubleSlap", level = 25, order = nil, id = 3 },
            { move = "rest", level = 29, order = nil, id = 156 },
            { move = "bodySlam", level = 33, order = nil, id = 34 },
            { move = "gyroBall", level = 37, order = nil, id = 360 },
            { move = "wakeUpSlap", level = 41, order = nil, id = 358 },
            { move = "mimic", level = 45, order = nil, id = 102 },
            { move = "hyperVoice", level = 49, order = nil, id = 304 },
            { move = "doubleEdge", level = 53, order = nil, id = 38 },
        }
        -- END B2W2 LEARNSET
    },
    wigglytuff = {
        name = "WIGGLYTUFF", dex = 40, type = "normal", type2 = nil,
        baseHP = 140, baseAtk = 70, baseDef = 45, baseSpA = 75, baseSpD = 50, baseSpe = 45, baseExp = 191,
        moves = { "sing", "disable", "defenseCurl", "doubleSlap" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "sing", level = 1, order = 1, id = 47 },
            { move = "disable", level = 1, order = 2, id = 50 },
            { move = "defenseCurl", level = 1, order = 3, id = 111 },
            { move = "doubleSlap", level = 1, order = 4, id = 3 },
        }
        -- END B2W2 LEARNSET
    },
    zubat = {
        name = "ZUBAT", dex = 41, type = "poison", type2 = "flying",
        baseHP = 40, baseAtk = 45, baseDef = 35, baseSpA = 30, baseSpD = 40, baseSpe = 55, baseExp = 49,
        moves = { "leechLife", "supersonic", "astonish", "bite", "wingAttack", "confuseRay", "swift", "airCutter", "acrobatics", "meanLook", "poisonFang", "haze", "airSlash" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "leechLife", level = 1, order = nil, id = 141 },
            { move = "supersonic", level = 4, order = nil, id = 48 },
            { move = "astonish", level = 8, order = nil, id = 310 },
            { move = "bite", level = 12, order = nil, id = 44 },
            { move = "wingAttack", level = 15, order = nil, id = 17 },
            { move = "confuseRay", level = 19, order = nil, id = 109 },
            { move = "swift", level = 23, order = nil, id = 129 },
            { move = "airCutter", level = 26, order = nil, id = 314 },
            { move = "acrobatics", level = 30, order = nil, id = 512 },
            { move = "meanLook", level = 34, order = nil, id = 212 },
            { move = "poisonFang", level = 37, order = nil, id = 305 },
            { move = "haze", level = 41, order = nil, id = 114 },
            { move = "airSlash", level = 45, order = nil, id = 403 },
        }
        -- END B2W2 LEARNSET
    },
    golbat = {
        name = "GOLBAT", dex = 42, type = "poison", type2 = "flying",
        baseHP = 75, baseAtk = 80, baseDef = 70, baseSpA = 65, baseSpD = 75, baseSpe = 90, baseExp = 159,
        moves = { "screech", "leechLife", "supersonic", "astonish", "supersonic", "astonish", "bite", "wingAttack", "confuseRay", "swift", "airCutter", "acrobatics", "meanLook", "poisonFang", "haze", "airSlash" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "screech", level = 1, order = 1, id = 103 },
            { move = "leechLife", level = 1, order = 2, id = 141 },
            { move = "supersonic", level = 1, order = 3, id = 48 },
            { move = "astonish", level = 1, order = 4, id = 310 },
            { move = "supersonic", level = 4, order = nil, id = 48 },
            { move = "astonish", level = 8, order = nil, id = 310 },
            { move = "bite", level = 12, order = nil, id = 44 },
            { move = "wingAttack", level = 15, order = nil, id = 17 },
            { move = "confuseRay", level = 19, order = nil, id = 109 },
            { move = "swift", level = 24, order = nil, id = 129 },
            { move = "airCutter", level = 28, order = nil, id = 314 },
            { move = "acrobatics", level = 33, order = nil, id = 512 },
            { move = "meanLook", level = 38, order = nil, id = 212 },
            { move = "poisonFang", level = 42, order = nil, id = 305 },
            { move = "haze", level = 47, order = nil, id = 114 },
            { move = "airSlash", level = 52, order = nil, id = 403 },
        }
        -- END B2W2 LEARNSET
    },
    oddish = {
        name = "ODDISH", dex = 43, type = "grass", type2 = "poison",
        baseHP = 45, baseAtk = 50, baseDef = 55, baseSpA = 75, baseSpD = 65, baseSpe = 30, baseExp = 64,
        moves = { "absorb", "sweetScent", "acid", "poisonPowder", "stunSpore", "sleepPowder", "megaDrain", "luckyChant", "naturalGift", "moonlight", "gigaDrain", "petalDance" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "absorb", level = 1, order = nil, id = 71 },
            { move = "sweetScent", level = 5, order = nil, id = 230 },
            { move = "acid", level = 9, order = nil, id = 51 },
            { move = "poisonPowder", level = 13, order = nil, id = 77 },
            { move = "stunSpore", level = 15, order = nil, id = 78 },
            { move = "sleepPowder", level = 17, order = nil, id = 79 },
            { move = "megaDrain", level = 21, order = nil, id = 72 },
            { move = "luckyChant", level = 25, order = nil, id = 381 },
            { move = "naturalGift", level = 29, order = nil, id = 363 },
            { move = "moonlight", level = 33, order = nil, id = 236 },
            { move = "gigaDrain", level = 37, order = nil, id = 202 },
            { move = "petalDance", level = 41, order = nil, id = 80 },
        }
        -- END B2W2 LEARNSET
    },
    gloom = {
        name = "GLOOM", dex = 44, type = "grass", type2 = "poison",
        baseHP = 60, baseAtk = 65, baseDef = 70, baseSpA = 85, baseSpD = 75, baseSpe = 40, baseExp = 138,
        moves = { "absorb", "sweetScent", "acid", "sweetScent", "acid", "poisonPowder", "stunSpore", "sleepPowder", "megaDrain", "luckyChant", "naturalGift", "moonlight", "gigaDrain", "petalDance" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "absorb", level = 1, order = 1, id = 71 },
            { move = "sweetScent", level = 1, order = 2, id = 230 },
            { move = "acid", level = 1, order = 3, id = 51 },
            { move = "sweetScent", level = 5, order = nil, id = 230 },
            { move = "acid", level = 9, order = nil, id = 51 },
            { move = "poisonPowder", level = 13, order = nil, id = 77 },
            { move = "stunSpore", level = 15, order = nil, id = 78 },
            { move = "sleepPowder", level = 17, order = nil, id = 79 },
            { move = "megaDrain", level = 23, order = nil, id = 72 },
            { move = "luckyChant", level = 29, order = nil, id = 381 },
            { move = "naturalGift", level = 35, order = nil, id = 363 },
            { move = "moonlight", level = 41, order = nil, id = 236 },
            { move = "gigaDrain", level = 47, order = nil, id = 202 },
            { move = "petalDance", level = 53, order = nil, id = 80 },
        }
        -- END B2W2 LEARNSET
    },
    vileplume = {
        name = "VILEPLUME", dex = 45, type = "grass", type2 = "poison",
        baseHP = 75, baseAtk = 80, baseDef = 85, baseSpA = 100, baseSpD = 90, baseSpe = 50, baseExp = 216,
        moves = { "megaDrain", "aromatherapy", "stunSpore", "poisonPowder", "petalDance", "solarBeam" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "megaDrain", level = 1, order = 1, id = 72 },
            { move = "aromatherapy", level = 1, order = 2, id = 312 },
            { move = "stunSpore", level = 1, order = 3, id = 78 },
            { move = "poisonPowder", level = 1, order = 4, id = 77 },
            { move = "petalDance", level = 53, order = nil, id = 80 },
            { move = "solarBeam", level = 65, order = nil, id = 76 },
        }
        -- END B2W2 LEARNSET
    },
    paras = {
        name = "PARAS", dex = 46, type = "bug", type2 = "grass",
        baseHP = 35, baseAtk = 70, baseDef = 55, baseSpA = 45, baseSpD = 55, baseSpe = 25, baseExp = 57,
        moves = { "scratch", "stunSpore", "poisonPowder", "leechLife", "furyCutter", "spore", "slash", "growth", "gigaDrain", "aromatherapy", "ragePowder", "xScissor" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "scratch", level = 1, order = nil, id = 10 },
            { move = "stunSpore", level = 6, order = 1, id = 78 },
            { move = "poisonPowder", level = 6, order = 2, id = 77 },
            { move = "leechLife", level = 11, order = nil, id = 141 },
            { move = "furyCutter", level = 17, order = nil, id = 210 },
            { move = "spore", level = 22, order = nil, id = 147 },
            { move = "slash", level = 27, order = nil, id = 163 },
            { move = "growth", level = 33, order = nil, id = 74 },
            { move = "gigaDrain", level = 38, order = nil, id = 202 },
            { move = "aromatherapy", level = 43, order = nil, id = 312 },
            { move = "ragePowder", level = 49, order = nil, id = 476 },
            { move = "xScissor", level = 54, order = nil, id = 404 },
        }
        -- END B2W2 LEARNSET
    },
    parasect = {
        name = "PARASECT", dex = 47, type = "bug", type2 = "grass",
        baseHP = 60, baseAtk = 95, baseDef = 80, baseSpA = 60, baseSpD = 80, baseSpe = 30, baseExp = 142,
        moves = { "crossPoison", "scratch", "stunSpore", "poisonPowder", "leechLife", "stunSpore", "poisonPowder", "leechLife", "furyCutter", "spore", "slash", "growth", "gigaDrain", "aromatherapy", "ragePowder", "xScissor" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "crossPoison", level = 1, order = 1, id = 440 },
            { move = "scratch", level = 1, order = 2, id = 10 },
            { move = "stunSpore", level = 1, order = 3, id = 78 },
            { move = "poisonPowder", level = 1, order = 4, id = 77 },
            { move = "leechLife", level = 1, order = 5, id = 141 },
            { move = "stunSpore", level = 6, order = 1, id = 78 },
            { move = "poisonPowder", level = 6, order = 2, id = 77 },
            { move = "leechLife", level = 11, order = nil, id = 141 },
            { move = "furyCutter", level = 17, order = nil, id = 210 },
            { move = "spore", level = 22, order = nil, id = 147 },
            { move = "slash", level = 29, order = nil, id = 163 },
            { move = "growth", level = 37, order = nil, id = 74 },
            { move = "gigaDrain", level = 44, order = nil, id = 202 },
            { move = "aromatherapy", level = 51, order = nil, id = 312 },
            { move = "ragePowder", level = 59, order = nil, id = 476 },
            { move = "xScissor", level = 66, order = nil, id = 404 },
        }
        -- END B2W2 LEARNSET
    },
    venonat = {
        name = "VENONAT", dex = 48, type = "bug", type2 = "poison",
        baseHP = 60, baseAtk = 55, baseDef = 50, baseSpA = 40, baseSpD = 55, baseSpe = 45, baseExp = 61,
        moves = { "tackle", "disable", "foresight", "supersonic", "confusion", "poisonPowder", "leechLife", "stunSpore", "psybeam", "sleepPowder", "signalBeam", "zenHeadbutt", "poisonFang", "psychic" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "tackle", level = 1, order = 1, id = 33 },
            { move = "disable", level = 1, order = 2, id = 50 },
            { move = "foresight", level = 1, order = 3, id = 193 },
            { move = "supersonic", level = 5, order = nil, id = 48 },
            { move = "confusion", level = 11, order = nil, id = 93 },
            { move = "poisonPowder", level = 13, order = nil, id = 77 },
            { move = "leechLife", level = 17, order = nil, id = 141 },
            { move = "stunSpore", level = 23, order = nil, id = 78 },
            { move = "psybeam", level = 25, order = nil, id = 60 },
            { move = "sleepPowder", level = 29, order = nil, id = 79 },
            { move = "signalBeam", level = 35, order = nil, id = 324 },
            { move = "zenHeadbutt", level = 37, order = nil, id = 428 },
            { move = "poisonFang", level = 41, order = nil, id = 305 },
            { move = "psychic", level = 47, order = nil, id = 94 },
        }
        -- END B2W2 LEARNSET
    },
    venomoth = {
        name = "VENOMOTH", dex = 49, type = "bug", type2 = "poison",
        baseHP = 70, baseAtk = 65, baseDef = 60, baseSpA = 90, baseSpD = 75, baseSpe = 90, baseExp = 158,
        moves = { "silverWind", "tackle", "disable", "foresight", "supersonic", "supersonic", "confusion", "poisonPowder", "leechLife", "stunSpore", "psybeam", "sleepPowder", "gust", "signalBeam", "zenHeadbutt", "poisonFang", "psychic", "bugBuzz", "quiverDance" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "silverWind", level = 1, order = 1, id = 318 },
            { move = "tackle", level = 1, order = 2, id = 33 },
            { move = "disable", level = 1, order = 3, id = 50 },
            { move = "foresight", level = 1, order = 4, id = 193 },
            { move = "supersonic", level = 1, order = 5, id = 48 },
            { move = "supersonic", level = 5, order = nil, id = 48 },
            { move = "confusion", level = 11, order = nil, id = 93 },
            { move = "poisonPowder", level = 13, order = nil, id = 77 },
            { move = "leechLife", level = 17, order = nil, id = 141 },
            { move = "stunSpore", level = 23, order = nil, id = 78 },
            { move = "psybeam", level = 25, order = nil, id = 60 },
            { move = "sleepPowder", level = 29, order = nil, id = 79 },
            { move = "gust", level = 31, order = nil, id = 16 },
            { move = "signalBeam", level = 37, order = nil, id = 324 },
            { move = "zenHeadbutt", level = 41, order = nil, id = 428 },
            { move = "poisonFang", level = 47, order = nil, id = 305 },
            { move = "psychic", level = 55, order = nil, id = 94 },
            { move = "bugBuzz", level = 59, order = nil, id = 405 },
            { move = "quiverDance", level = 63, order = nil, id = 483 },
        }
        -- END B2W2 LEARNSET
    },
    diglett = {
        name = "DIGLETT", dex = 50, type = "ground", type2 = nil,
        baseHP = 10, baseAtk = 55, baseDef = 25, baseSpA = 35, baseSpD = 45, baseSpe = 95, baseExp = 53,
        moves = { "scratch", "sandAttack", "growl", "astonish", "mudSlap", "magnitude", "bulldoze", "suckerPunch", "mudBomb", "earthPower", "dig", "slash", "earthquake", "fissure" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "scratch", level = 1, order = 1, id = 10 },
            { move = "sandAttack", level = 1, order = 2, id = 28 },
            { move = "growl", level = 4, order = nil, id = 45 },
            { move = "astonish", level = 7, order = nil, id = 310 },
            { move = "mudSlap", level = 12, order = nil, id = 189 },
            { move = "magnitude", level = 15, order = nil, id = 222 },
            { move = "bulldoze", level = 18, order = nil, id = 523 },
            { move = "suckerPunch", level = 23, order = nil, id = 389 },
            { move = "mudBomb", level = 26, order = nil, id = 426 },
            { move = "earthPower", level = 29, order = nil, id = 414 },
            { move = "dig", level = 34, order = nil, id = 91 },
            { move = "slash", level = 37, order = nil, id = 163 },
            { move = "earthquake", level = 40, order = nil, id = 89 },
            { move = "fissure", level = 45, order = nil, id = 90 },
        }
        -- END B2W2 LEARNSET
    },
    dugtrio = {
        name = "DUGTRIO", dex = 51, type = "ground", type2 = nil,
        baseHP = 35, baseAtk = 80, baseDef = 50, baseSpA = 50, baseSpD = 70, baseSpe = 120, baseExp = 142,
        moves = { "nightSlash", "triAttack", "scratch", "sandAttack", "growl", "growl", "astonish", "mudSlap", "magnitude", "bulldoze", "suckerPunch", "sandTomb", "mudBomb", "earthPower", "dig", "slash", "earthquake", "fissure" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "nightSlash", level = 1, order = 1, id = 400 },
            { move = "triAttack", level = 1, order = 2, id = 161 },
            { move = "scratch", level = 1, order = 3, id = 10 },
            { move = "sandAttack", level = 1, order = 4, id = 28 },
            { move = "growl", level = 1, order = 5, id = 45 },
            { move = "growl", level = 4, order = nil, id = 45 },
            { move = "astonish", level = 7, order = nil, id = 310 },
            { move = "mudSlap", level = 12, order = nil, id = 189 },
            { move = "magnitude", level = 15, order = nil, id = 222 },
            { move = "bulldoze", level = 18, order = nil, id = 523 },
            { move = "suckerPunch", level = 23, order = nil, id = 389 },
            { move = "sandTomb", level = 26, order = nil, id = 328 },
            { move = "mudBomb", level = 28, order = nil, id = 426 },
            { move = "earthPower", level = 33, order = nil, id = 414 },
            { move = "dig", level = 40, order = nil, id = 91 },
            { move = "slash", level = 45, order = nil, id = 163 },
            { move = "earthquake", level = 50, order = nil, id = 89 },
            { move = "fissure", level = 57, order = nil, id = 90 },
        }
        -- END B2W2 LEARNSET
    },
    meowth = {
        name = "MEOWTH", dex = 52, type = "normal", type2 = nil,
        baseHP = 40, baseAtk = 45, baseDef = 35, baseSpA = 40, baseSpD = 40, baseSpe = 90, baseExp = 58,
        moves = { "scratch", "growl", "bite", "fakeOut", "furySwipes", "screech", "feintAttack", "taunt", "payDay", "slash", "nastyPlot", "assurance", "captivate", "nightSlash", "feint" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "scratch", level = 1, order = 1, id = 10 },
            { move = "growl", level = 1, order = 2, id = 45 },
            { move = "bite", level = 6, order = nil, id = 44 },
            { move = "fakeOut", level = 9, order = nil, id = 252 },
            { move = "furySwipes", level = 14, order = nil, id = 154 },
            { move = "screech", level = 17, order = nil, id = 103 },
            { move = "feintAttack", level = 22, order = nil, id = 185 },
            { move = "taunt", level = 25, order = nil, id = 269 },
            { move = "payDay", level = 30, order = nil, id = 6 },
            { move = "slash", level = 33, order = nil, id = 163 },
            { move = "nastyPlot", level = 38, order = nil, id = 417 },
            { move = "assurance", level = 41, order = nil, id = 372 },
            { move = "captivate", level = 46, order = nil, id = 445 },
            { move = "nightSlash", level = 49, order = nil, id = 400 },
            { move = "feint", level = 54, order = nil, id = 364 },
        }
        -- END B2W2 LEARNSET
    },
    persian = {
        name = "PERSIAN", dex = 53, type = "normal", type2 = nil,
        baseHP = 65, baseAtk = 70, baseDef = 60, baseSpA = 65, baseSpD = 65, baseSpe = 115, baseExp = 154,
        moves = { "switcheroo", "scratch", "growl", "bite", "fakeOut", "bite", "fakeOut", "furySwipes", "screech", "feintAttack", "taunt", "swift", "powerGem", "slash", "nastyPlot", "assurance", "captivate", "nightSlash", "feint" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "switcheroo", level = 1, order = 1, id = 415 },
            { move = "scratch", level = 1, order = 2, id = 10 },
            { move = "growl", level = 1, order = 3, id = 45 },
            { move = "bite", level = 1, order = 4, id = 44 },
            { move = "fakeOut", level = 1, order = 5, id = 252 },
            { move = "bite", level = 6, order = nil, id = 44 },
            { move = "fakeOut", level = 9, order = nil, id = 252 },
            { move = "furySwipes", level = 14, order = nil, id = 154 },
            { move = "screech", level = 17, order = nil, id = 103 },
            { move = "feintAttack", level = 22, order = nil, id = 185 },
            { move = "taunt", level = 25, order = nil, id = 269 },
            { move = "swift", level = 28, order = nil, id = 129 },
            { move = "powerGem", level = 32, order = nil, id = 408 },
            { move = "slash", level = 37, order = nil, id = 163 },
            { move = "nastyPlot", level = 44, order = nil, id = 417 },
            { move = "assurance", level = 49, order = nil, id = 372 },
            { move = "captivate", level = 56, order = nil, id = 445 },
            { move = "nightSlash", level = 61, order = nil, id = 400 },
            { move = "feint", level = 68, order = nil, id = 364 },
        }
        -- END B2W2 LEARNSET
    },
    psyduck = {
        name = "PSYDUCK", dex = 54, type = "water", type2 = nil,
        baseHP = 50, baseAtk = 52, baseDef = 48, baseSpA = 65, baseSpD = 50, baseSpe = 55, baseExp = 64,
        moves = { "waterSport", "scratch", "tailWhip", "waterGun", "disable", "confusion", "waterPulse", "furySwipes", "screech", "zenHeadbutt", "aquaTail", "soak", "psychUp", "amnesia", "hydroPump", "wonderRoom" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "waterSport", level = 1, order = 1, id = 346 },
            { move = "scratch", level = 1, order = 2, id = 10 },
            { move = "tailWhip", level = 4, order = nil, id = 39 },
            { move = "waterGun", level = 8, order = nil, id = 55 },
            { move = "disable", level = 11, order = nil, id = 50 },
            { move = "confusion", level = 15, order = nil, id = 93 },
            { move = "waterPulse", level = 18, order = nil, id = 352 },
            { move = "furySwipes", level = 22, order = nil, id = 154 },
            { move = "screech", level = 25, order = nil, id = 103 },
            { move = "zenHeadbutt", level = 29, order = nil, id = 428 },
            { move = "aquaTail", level = 32, order = nil, id = 401 },
            { move = "soak", level = 36, order = nil, id = 487 },
            { move = "psychUp", level = 39, order = nil, id = 244 },
            { move = "amnesia", level = 43, order = nil, id = 133 },
            { move = "hydroPump", level = 46, order = nil, id = 56 },
            { move = "wonderRoom", level = 50, order = nil, id = 472 },
        }
        -- END B2W2 LEARNSET
    },
    golduck = {
        name = "GOLDUCK", dex = 55, type = "water", type2 = nil,
        baseHP = 80, baseAtk = 82, baseDef = 78, baseSpA = 95, baseSpD = 80, baseSpe = 85, baseExp = 175,
        moves = { "aquaJet", "waterSport", "scratch", "tailWhip", "waterGun", "tailWhip", "waterGun", "disable", "confusion", "waterPulse", "furySwipes", "screech", "zenHeadbutt", "aquaTail", "soak", "psychUp", "amnesia", "hydroPump", "wonderRoom" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "aquaJet", level = 1, order = 1, id = 453 },
            { move = "waterSport", level = 1, order = 2, id = 346 },
            { move = "scratch", level = 1, order = 3, id = 10 },
            { move = "tailWhip", level = 1, order = 4, id = 39 },
            { move = "waterGun", level = 1, order = 5, id = 55 },
            { move = "tailWhip", level = 4, order = nil, id = 39 },
            { move = "waterGun", level = 8, order = nil, id = 55 },
            { move = "disable", level = 11, order = nil, id = 50 },
            { move = "confusion", level = 15, order = nil, id = 93 },
            { move = "waterPulse", level = 18, order = nil, id = 352 },
            { move = "furySwipes", level = 22, order = nil, id = 154 },
            { move = "screech", level = 25, order = nil, id = 103 },
            { move = "zenHeadbutt", level = 29, order = nil, id = 428 },
            { move = "aquaTail", level = 32, order = nil, id = 401 },
            { move = "soak", level = 38, order = nil, id = 487 },
            { move = "psychUp", level = 43, order = nil, id = 244 },
            { move = "amnesia", level = 49, order = nil, id = 133 },
            { move = "hydroPump", level = 54, order = nil, id = 56 },
            { move = "wonderRoom", level = 60, order = nil, id = 472 },
        }
        -- END B2W2 LEARNSET
    },
    mankey = {
        name = "MANKEY", dex = 56, type = "fighting", type2 = nil,
        baseHP = 40, baseAtk = 80, baseDef = 35, baseSpA = 35, baseSpD = 45, baseSpe = 70, baseExp = 61,
        moves = { "covet", "scratch", "lowKick", "leer", "focusEnergy", "furySwipes", "karateChop", "seismicToss", "screech", "assurance", "swagger", "crossChop", "thrash", "punishment", "closeCombat", "finalGambit" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "covet", level = 1, order = 1, id = 343 },
            { move = "scratch", level = 1, order = 2, id = 10 },
            { move = "lowKick", level = 1, order = 3, id = 67 },
            { move = "leer", level = 1, order = 4, id = 43 },
            { move = "focusEnergy", level = 1, order = 5, id = 116 },
            { move = "furySwipes", level = 9, order = nil, id = 154 },
            { move = "karateChop", level = 13, order = nil, id = 2 },
            { move = "seismicToss", level = 17, order = nil, id = 69 },
            { move = "screech", level = 21, order = nil, id = 103 },
            { move = "assurance", level = 25, order = nil, id = 372 },
            { move = "swagger", level = 33, order = nil, id = 207 },
            { move = "crossChop", level = 37, order = nil, id = 238 },
            { move = "thrash", level = 41, order = nil, id = 37 },
            { move = "punishment", level = 45, order = nil, id = 386 },
            { move = "closeCombat", level = 49, order = nil, id = 370 },
            { move = "finalGambit", level = 53, order = nil, id = 515 },
        }
        -- END B2W2 LEARNSET
    },
    primeape = {
        name = "PRIMEAPE", dex = 57, type = "fighting", type2 = nil,
        baseHP = 65, baseAtk = 105, baseDef = 60, baseSpA = 60, baseSpD = 70, baseSpe = 95, baseExp = 159,
        moves = { "fling", "scratch", "lowKick", "leer", "focusEnergy", "furySwipes", "karateChop", "seismicToss", "screech", "assurance", "rage", "swagger", "crossChop", "thrash", "punishment", "closeCombat", "finalGambit" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "fling", level = 1, order = 1, id = 374 },
            { move = "scratch", level = 1, order = 2, id = 10 },
            { move = "lowKick", level = 1, order = 3, id = 67 },
            { move = "leer", level = 1, order = 4, id = 43 },
            { move = "focusEnergy", level = 1, order = 5, id = 116 },
            { move = "furySwipes", level = 9, order = nil, id = 154 },
            { move = "karateChop", level = 13, order = nil, id = 2 },
            { move = "seismicToss", level = 17, order = nil, id = 69 },
            { move = "screech", level = 21, order = nil, id = 103 },
            { move = "assurance", level = 25, order = nil, id = 372 },
            { move = "rage", level = 28, order = nil, id = 99 },
            { move = "swagger", level = 35, order = nil, id = 207 },
            { move = "crossChop", level = 41, order = nil, id = 238 },
            { move = "thrash", level = 47, order = nil, id = 37 },
            { move = "punishment", level = 53, order = nil, id = 386 },
            { move = "closeCombat", level = 59, order = nil, id = 370 },
            { move = "finalGambit", level = 63, order = nil, id = 515 },
        }
        -- END B2W2 LEARNSET
    },
    growlithe = {
        name = "GROWLITHE", dex = 58, type = "fire", type2 = nil,
        baseHP = 55, baseAtk = 70, baseDef = 45, baseSpA = 70, baseSpD = 50, baseSpe = 60, baseExp = 70,
        moves = { "bite", "roar", "ember", "leer", "odorSleuth", "helpingHand", "flameWheel", "reversal", "fireFang", "takeDown", "flameBurst", "agility", "retaliate", "flamethrower", "crunch", "heatWave", "outrage", "flareBlitz" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "bite", level = 1, order = 1, id = 44 },
            { move = "roar", level = 1, order = 2, id = 46 },
            { move = "ember", level = 6, order = nil, id = 52 },
            { move = "leer", level = 8, order = nil, id = 43 },
            { move = "odorSleuth", level = 10, order = nil, id = 316 },
            { move = "helpingHand", level = 12, order = nil, id = 270 },
            { move = "flameWheel", level = 17, order = nil, id = 172 },
            { move = "reversal", level = 19, order = nil, id = 179 },
            { move = "fireFang", level = 21, order = nil, id = 424 },
            { move = "takeDown", level = 23, order = nil, id = 36 },
            { move = "flameBurst", level = 28, order = nil, id = 481 },
            { move = "agility", level = 30, order = nil, id = 97 },
            { move = "retaliate", level = 32, order = nil, id = 514 },
            { move = "flamethrower", level = 34, order = nil, id = 53 },
            { move = "crunch", level = 39, order = nil, id = 242 },
            { move = "heatWave", level = 41, order = nil, id = 257 },
            { move = "outrage", level = 43, order = nil, id = 200 },
            { move = "flareBlitz", level = 45, order = nil, id = 394 },
        }
        -- END B2W2 LEARNSET
    },
    arcanine = {
        name = "ARCANINE", dex = 59, type = "fire", type2 = nil,
        baseHP = 90, baseAtk = 110, baseDef = 80, baseSpA = 100, baseSpD = 80, baseSpe = 95, baseExp = 194,
        moves = { "thunderFang", "bite", "roar", "odorSleuth", "fireFang", "extremeSpeed" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "thunderFang", level = 1, order = 1, id = 422 },
            { move = "bite", level = 1, order = 2, id = 44 },
            { move = "roar", level = 1, order = 3, id = 46 },
            { move = "odorSleuth", level = 1, order = 4, id = 316 },
            { move = "fireFang", level = 1, order = 5, id = 424 },
            { move = "extremeSpeed", level = 34, order = nil, id = 245 },
        }
        -- END B2W2 LEARNSET
    },
    poliwag = {
        name = "POLIWAG", dex = 60, type = "water", type2 = nil,
        baseHP = 40, baseAtk = 50, baseDef = 40, baseSpA = 40, baseSpD = 40, baseSpe = 90, baseExp = 60,
        moves = { "waterSport", "bubble", "hypnosis", "waterGun", "doubleSlap", "rainDance", "bodySlam", "bubbleBeam", "mudShot", "bellyDrum", "wakeUpSlap", "hydroPump", "mudBomb" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "waterSport", level = 1, order = nil, id = 346 },
            { move = "bubble", level = 5, order = nil, id = 145 },
            { move = "hypnosis", level = 8, order = nil, id = 95 },
            { move = "waterGun", level = 11, order = nil, id = 55 },
            { move = "doubleSlap", level = 15, order = nil, id = 3 },
            { move = "rainDance", level = 18, order = nil, id = 240 },
            { move = "bodySlam", level = 21, order = nil, id = 34 },
            { move = "bubbleBeam", level = 25, order = nil, id = 61 },
            { move = "mudShot", level = 28, order = nil, id = 341 },
            { move = "bellyDrum", level = 31, order = nil, id = 187 },
            { move = "wakeUpSlap", level = 35, order = nil, id = 358 },
            { move = "hydroPump", level = 38, order = nil, id = 56 },
            { move = "mudBomb", level = 41, order = nil, id = 426 },
        }
        -- END B2W2 LEARNSET
    },
    poliwhirl = {
        name = "POLIWHIRL", dex = 61, type = "water", type2 = nil,
        baseHP = 65, baseAtk = 65, baseDef = 65, baseSpA = 50, baseSpD = 50, baseSpe = 90, baseExp = 135,
        moves = { "waterSport", "bubble", "hypnosis", "bubble", "hypnosis", "waterGun", "doubleSlap", "rainDance", "bodySlam", "bubbleBeam", "mudShot", "bellyDrum", "wakeUpSlap", "hydroPump", "mudBomb" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "waterSport", level = 1, order = 1, id = 346 },
            { move = "bubble", level = 1, order = 2, id = 145 },
            { move = "hypnosis", level = 1, order = 3, id = 95 },
            { move = "bubble", level = 5, order = nil, id = 145 },
            { move = "hypnosis", level = 8, order = nil, id = 95 },
            { move = "waterGun", level = 11, order = nil, id = 55 },
            { move = "doubleSlap", level = 15, order = nil, id = 3 },
            { move = "rainDance", level = 18, order = nil, id = 240 },
            { move = "bodySlam", level = 21, order = nil, id = 34 },
            { move = "bubbleBeam", level = 27, order = nil, id = 61 },
            { move = "mudShot", level = 32, order = nil, id = 341 },
            { move = "bellyDrum", level = 37, order = nil, id = 187 },
            { move = "wakeUpSlap", level = 43, order = nil, id = 358 },
            { move = "hydroPump", level = 48, order = nil, id = 56 },
            { move = "mudBomb", level = 53, order = nil, id = 426 },
        }
        -- END B2W2 LEARNSET
    },
    poliwrath = {
        name = "POLIWRATH", dex = 62, type = "water", type2 = "fighting",
        baseHP = 90, baseAtk = 85, baseDef = 95, baseSpA = 70, baseSpD = 90, baseSpe = 70, baseExp = 225,
        moves = { "bubbleBeam", "hypnosis", "doubleSlap", "submission", "dynamicPunch", "mindReader", "circleThrow" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "bubbleBeam", level = 1, order = 1, id = 61 },
            { move = "hypnosis", level = 1, order = 2, id = 95 },
            { move = "doubleSlap", level = 1, order = 3, id = 3 },
            { move = "submission", level = 1, order = 4, id = 66 },
            { move = "dynamicPunch", level = 32, order = nil, id = 223 },
            { move = "mindReader", level = 43, order = nil, id = 170 },
            { move = "circleThrow", level = 53, order = nil, id = 509 },
        }
        -- END B2W2 LEARNSET
    },
    abra = {
        name = "ABRA", dex = 63, type = "psychic", type2 = nil,
        baseHP = 25, baseAtk = 20, baseDef = 15, baseSpA = 105, baseSpD = 55, baseSpe = 90, baseExp = 62,
        moves = { "teleport" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "teleport", level = 1, order = nil, id = 100 },
        }
        -- END B2W2 LEARNSET
    },
    kadabra = {
        name = "KADABRA", dex = 64, type = "psychic", type2 = nil,
        baseHP = 40, baseAtk = 35, baseDef = 30, baseSpA = 120, baseSpD = 70, baseSpe = 105, baseExp = 140,
        moves = { "teleport", "kinesis", "confusion", "confusion", "disable", "miracleEye", "allySwitch", "psybeam", "reflect", "telekinesis", "recover", "psychoCut", "rolePlay", "psychic", "futureSight", "trick" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "teleport", level = 1, order = 1, id = 100 },
            { move = "kinesis", level = 1, order = 2, id = 134 },
            { move = "confusion", level = 1, order = 3, id = 93 },
            { move = "confusion", level = 16, order = nil, id = 93 },
            { move = "disable", level = 18, order = nil, id = 50 },
            { move = "miracleEye", level = 22, order = nil, id = 357 },
            { move = "allySwitch", level = 24, order = nil, id = 502 },
            { move = "psybeam", level = 28, order = nil, id = 60 },
            { move = "reflect", level = 30, order = nil, id = 115 },
            { move = "telekinesis", level = 34, order = nil, id = 477 },
            { move = "recover", level = 36, order = nil, id = 105 },
            { move = "psychoCut", level = 40, order = nil, id = 427 },
            { move = "rolePlay", level = 42, order = nil, id = 272 },
            { move = "psychic", level = 46, order = nil, id = 94 },
            { move = "futureSight", level = 48, order = nil, id = 248 },
            { move = "trick", level = 52, order = nil, id = 271 },
        }
        -- END B2W2 LEARNSET
    },
    alakazam = {
        name = "ALAKAZAM", dex = 65, type = "psychic", type2 = nil,
        baseHP = 55, baseAtk = 50, baseDef = 45, baseSpA = 135, baseSpD = 85, baseSpe = 120, baseExp = 221,
        moves = { "teleport", "kinesis", "confusion", "confusion", "disable", "miracleEye", "allySwitch", "psybeam", "reflect", "telekinesis", "recover", "psychoCut", "calmMind", "psychic", "futureSight", "trick" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "teleport", level = 1, order = 1, id = 100 },
            { move = "kinesis", level = 1, order = 2, id = 134 },
            { move = "confusion", level = 1, order = 3, id = 93 },
            { move = "confusion", level = 16, order = nil, id = 93 },
            { move = "disable", level = 18, order = nil, id = 50 },
            { move = "miracleEye", level = 22, order = nil, id = 357 },
            { move = "allySwitch", level = 24, order = nil, id = 502 },
            { move = "psybeam", level = 28, order = nil, id = 60 },
            { move = "reflect", level = 30, order = nil, id = 115 },
            { move = "telekinesis", level = 34, order = nil, id = 477 },
            { move = "recover", level = 36, order = nil, id = 105 },
            { move = "psychoCut", level = 40, order = nil, id = 427 },
            { move = "calmMind", level = 42, order = nil, id = 347 },
            { move = "psychic", level = 46, order = nil, id = 94 },
            { move = "futureSight", level = 48, order = nil, id = 248 },
            { move = "trick", level = 52, order = nil, id = 271 },
        }
        -- END B2W2 LEARNSET
    },
    machop = {
        name = "MACHOP", dex = 66, type = "fighting", type2 = nil,
        baseHP = 70, baseAtk = 80, baseDef = 50, baseSpA = 35, baseSpD = 35, baseSpe = 35, baseExp = 61,
        moves = { "lowKick", "leer", "focusEnergy", "karateChop", "lowSweep", "foresight", "seismicToss", "revenge", "vitalThrow", "submission", "wakeUpSlap", "crossChop", "scaryFace", "dynamicPunch" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "lowKick", level = 1, order = 1, id = 67 },
            { move = "leer", level = 1, order = 2, id = 43 },
            { move = "focusEnergy", level = 7, order = nil, id = 116 },
            { move = "karateChop", level = 10, order = nil, id = 2 },
            { move = "lowSweep", level = 13, order = nil, id = 490 },
            { move = "foresight", level = 19, order = nil, id = 193 },
            { move = "seismicToss", level = 22, order = nil, id = 69 },
            { move = "revenge", level = 25, order = nil, id = 279 },
            { move = "vitalThrow", level = 31, order = nil, id = 233 },
            { move = "submission", level = 34, order = nil, id = 66 },
            { move = "wakeUpSlap", level = 37, order = nil, id = 358 },
            { move = "crossChop", level = 43, order = nil, id = 238 },
            { move = "scaryFace", level = 46, order = nil, id = 184 },
            { move = "dynamicPunch", level = 49, order = nil, id = 223 },
        }
        -- END B2W2 LEARNSET
    },
    machoke = {
        name = "MACHOKE", dex = 67, type = "fighting", type2 = nil,
        baseHP = 80, baseAtk = 100, baseDef = 70, baseSpA = 50, baseSpD = 60, baseSpe = 45, baseExp = 142,
        moves = { "lowKick", "leer", "focusEnergy", "karateChop", "focusEnergy", "karateChop", "lowSweep", "foresight", "seismicToss", "revenge", "vitalThrow", "submission", "wakeUpSlap", "crossChop", "scaryFace", "dynamicPunch" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "lowKick", level = 1, order = 1, id = 67 },
            { move = "leer", level = 1, order = 2, id = 43 },
            { move = "focusEnergy", level = 1, order = 3, id = 116 },
            { move = "karateChop", level = 1, order = 4, id = 2 },
            { move = "focusEnergy", level = 7, order = nil, id = 116 },
            { move = "karateChop", level = 10, order = nil, id = 2 },
            { move = "lowSweep", level = 13, order = nil, id = 490 },
            { move = "foresight", level = 19, order = nil, id = 193 },
            { move = "seismicToss", level = 22, order = nil, id = 69 },
            { move = "revenge", level = 25, order = nil, id = 279 },
            { move = "vitalThrow", level = 32, order = nil, id = 233 },
            { move = "submission", level = 36, order = nil, id = 66 },
            { move = "wakeUpSlap", level = 40, order = nil, id = 358 },
            { move = "crossChop", level = 44, order = nil, id = 238 },
            { move = "scaryFace", level = 51, order = nil, id = 184 },
            { move = "dynamicPunch", level = 55, order = nil, id = 223 },
        }
        -- END B2W2 LEARNSET
    },
    machamp = {
        name = "MACHAMP", dex = 68, type = "fighting", type2 = nil,
        baseHP = 90, baseAtk = 130, baseDef = 80, baseSpA = 65, baseSpD = 85, baseSpe = 55, baseExp = 227,
        moves = { "wideGuard", "lowKick", "leer", "focusEnergy", "karateChop", "focusEnergy", "karateChop", "lowSweep", "foresight", "seismicToss", "revenge", "vitalThrow", "submission", "wakeUpSlap", "crossChop", "scaryFace", "dynamicPunch" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "wideGuard", level = 1, order = 1, id = 469 },
            { move = "lowKick", level = 1, order = 2, id = 67 },
            { move = "leer", level = 1, order = 3, id = 43 },
            { move = "focusEnergy", level = 1, order = 4, id = 116 },
            { move = "karateChop", level = 1, order = 5, id = 2 },
            { move = "focusEnergy", level = 7, order = nil, id = 116 },
            { move = "karateChop", level = 10, order = nil, id = 2 },
            { move = "lowSweep", level = 13, order = nil, id = 490 },
            { move = "foresight", level = 19, order = nil, id = 193 },
            { move = "seismicToss", level = 22, order = nil, id = 69 },
            { move = "revenge", level = 25, order = nil, id = 279 },
            { move = "vitalThrow", level = 32, order = nil, id = 233 },
            { move = "submission", level = 36, order = nil, id = 66 },
            { move = "wakeUpSlap", level = 40, order = nil, id = 358 },
            { move = "crossChop", level = 44, order = nil, id = 238 },
            { move = "scaryFace", level = 51, order = nil, id = 184 },
            { move = "dynamicPunch", level = 55, order = nil, id = 223 },
        }
        -- END B2W2 LEARNSET
    },
    bellsprout = {
        name = "BELLSPROUT", dex = 69, type = "grass", type2 = "poison",
        baseHP = 50, baseAtk = 75, baseDef = 35, baseSpA = 70, baseSpD = 30, baseSpe = 40, baseExp = 60,
        moves = { "vineWhip", "growth", "wrap", "sleepPowder", "poisonPowder", "stunSpore", "acid", "knockOff", "sweetScent", "gastroAcid", "razorLeaf", "slam", "wringOut" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "vineWhip", level = 1, order = nil, id = 22 },
            { move = "growth", level = 7, order = nil, id = 74 },
            { move = "wrap", level = 11, order = nil, id = 35 },
            { move = "sleepPowder", level = 13, order = nil, id = 79 },
            { move = "poisonPowder", level = 15, order = nil, id = 77 },
            { move = "stunSpore", level = 17, order = nil, id = 78 },
            { move = "acid", level = 23, order = nil, id = 51 },
            { move = "knockOff", level = 27, order = nil, id = 282 },
            { move = "sweetScent", level = 29, order = nil, id = 230 },
            { move = "gastroAcid", level = 35, order = nil, id = 380 },
            { move = "razorLeaf", level = 39, order = nil, id = 75 },
            { move = "slam", level = 41, order = nil, id = 21 },
            { move = "wringOut", level = 47, order = nil, id = 378 },
        }
        -- END B2W2 LEARNSET
    },
    weepinbell = {
        name = "WEEPINBELL", dex = 70, type = "grass", type2 = "poison",
        baseHP = 65, baseAtk = 90, baseDef = 50, baseSpA = 85, baseSpD = 45, baseSpe = 55, baseExp = 137,
        moves = { "vineWhip", "growth", "wrap", "growth", "wrap", "sleepPowder", "poisonPowder", "stunSpore", "acid", "knockOff", "sweetScent", "gastroAcid", "razorLeaf", "slam", "wringOut" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "vineWhip", level = 1, order = 1, id = 22 },
            { move = "growth", level = 1, order = 2, id = 74 },
            { move = "wrap", level = 1, order = 3, id = 35 },
            { move = "growth", level = 7, order = nil, id = 74 },
            { move = "wrap", level = 11, order = nil, id = 35 },
            { move = "sleepPowder", level = 13, order = nil, id = 79 },
            { move = "poisonPowder", level = 15, order = nil, id = 77 },
            { move = "stunSpore", level = 17, order = nil, id = 78 },
            { move = "acid", level = 23, order = nil, id = 51 },
            { move = "knockOff", level = 27, order = nil, id = 282 },
            { move = "sweetScent", level = 29, order = nil, id = 230 },
            { move = "gastroAcid", level = 35, order = nil, id = 380 },
            { move = "razorLeaf", level = 39, order = nil, id = 75 },
            { move = "slam", level = 41, order = nil, id = 21 },
            { move = "wringOut", level = 47, order = nil, id = 378 },
        }
        -- END B2W2 LEARNSET
    },
    victreebel = {
        name = "VICTREEBEL", dex = 71, type = "grass", type2 = "poison",
        baseHP = 80, baseAtk = 105, baseDef = 65, baseSpA = 100, baseSpD = 60, baseSpe = 70, baseExp = 216,
        moves = { "stockpile", "swallow", "spitUp", "vineWhip", "sleepPowder", "sweetScent", "razorLeaf", "leafTornado", "leafStorm", "leafBlade" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "stockpile", level = 1, order = 1, id = 254 },
            { move = "swallow", level = 1, order = 2, id = 256 },
            { move = "spitUp", level = 1, order = 3, id = 255 },
            { move = "vineWhip", level = 1, order = 4, id = 22 },
            { move = "sleepPowder", level = 1, order = 5, id = 79 },
            { move = "sweetScent", level = 1, order = 6, id = 230 },
            { move = "razorLeaf", level = 1, order = 7, id = 75 },
            { move = "leafTornado", level = 27, order = nil, id = 536 },
            { move = "leafStorm", level = 47, order = 1, id = 437 },
            { move = "leafBlade", level = 47, order = 2, id = 348 },
        }
        -- END B2W2 LEARNSET
    },
    tentacool = {
        name = "TENTACOOL", dex = 72, type = "water", type2 = "poison",
        baseHP = 40, baseAtk = 40, baseDef = 35, baseSpA = 50, baseSpD = 100, baseSpe = 70, baseExp = 67,
        moves = { "poisonSting", "supersonic", "constrict", "acid", "toxicSpikes", "bubbleBeam", "wrap", "acidSpray", "barrier", "waterPulse", "poisonJab", "screech", "hex", "hydroPump", "sludgeWave", "wringOut" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "poisonSting", level = 1, order = nil, id = 40 },
            { move = "supersonic", level = 5, order = nil, id = 48 },
            { move = "constrict", level = 8, order = nil, id = 132 },
            { move = "acid", level = 12, order = nil, id = 51 },
            { move = "toxicSpikes", level = 15, order = nil, id = 390 },
            { move = "bubbleBeam", level = 19, order = nil, id = 61 },
            { move = "wrap", level = 22, order = nil, id = 35 },
            { move = "acidSpray", level = 26, order = nil, id = 491 },
            { move = "barrier", level = 29, order = nil, id = 112 },
            { move = "waterPulse", level = 33, order = nil, id = 352 },
            { move = "poisonJab", level = 36, order = nil, id = 398 },
            { move = "screech", level = 40, order = nil, id = 103 },
            { move = "hex", level = 43, order = nil, id = 506 },
            { move = "hydroPump", level = 47, order = nil, id = 56 },
            { move = "sludgeWave", level = 50, order = nil, id = 482 },
            { move = "wringOut", level = 54, order = nil, id = 378 },
        }
        -- END B2W2 LEARNSET
    },
    tentacruel = {
        name = "TENTACRUEL", dex = 73, type = "water", type2 = "poison",
        baseHP = 80, baseAtk = 70, baseDef = 65, baseSpA = 80, baseSpD = 120, baseSpe = 100, baseExp = 180,
        moves = { "poisonSting", "supersonic", "constrict", "supersonic", "constrict", "acid", "toxicSpikes", "bubbleBeam", "wrap", "acidSpray", "barrier", "waterPulse", "poisonJab", "screech", "hex", "hydroPump", "sludgeWave", "wringOut" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "poisonSting", level = 1, order = 1, id = 40 },
            { move = "supersonic", level = 1, order = 2, id = 48 },
            { move = "constrict", level = 1, order = 3, id = 132 },
            { move = "supersonic", level = 5, order = nil, id = 48 },
            { move = "constrict", level = 8, order = nil, id = 132 },
            { move = "acid", level = 12, order = nil, id = 51 },
            { move = "toxicSpikes", level = 15, order = nil, id = 390 },
            { move = "bubbleBeam", level = 19, order = nil, id = 61 },
            { move = "wrap", level = 22, order = nil, id = 35 },
            { move = "acidSpray", level = 26, order = nil, id = 491 },
            { move = "barrier", level = 29, order = nil, id = 112 },
            { move = "waterPulse", level = 34, order = nil, id = 352 },
            { move = "poisonJab", level = 38, order = nil, id = 398 },
            { move = "screech", level = 43, order = nil, id = 103 },
            { move = "hex", level = 47, order = nil, id = 506 },
            { move = "hydroPump", level = 52, order = nil, id = 56 },
            { move = "sludgeWave", level = 56, order = nil, id = 482 },
            { move = "wringOut", level = 61, order = nil, id = 378 },
        }
        -- END B2W2 LEARNSET
    },
    geodude = {
        name = "GEODUDE", dex = 74, type = "rock", type2 = "ground",
        baseHP = 40, baseAtk = 80, baseDef = 100, baseSpA = 30, baseSpD = 30, baseSpe = 20, baseExp = 60,
        moves = { "tackle", "defenseCurl", "mudSport", "rockPolish", "rockThrow", "magnitude", "rollout", "rockBlast", "smackDown", "selfDestruct", "bulldoze", "stealthRock", "earthquake", "explosion", "doubleEdge", "stoneEdge" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "tackle", level = 1, order = 1, id = 33 },
            { move = "defenseCurl", level = 1, order = 2, id = 111 },
            { move = "mudSport", level = 4, order = nil, id = 300 },
            { move = "rockPolish", level = 8, order = nil, id = 397 },
            { move = "rockThrow", level = 11, order = nil, id = 88 },
            { move = "magnitude", level = 15, order = nil, id = 222 },
            { move = "rollout", level = 18, order = nil, id = 205 },
            { move = "rockBlast", level = 22, order = nil, id = 350 },
            { move = "smackDown", level = 25, order = nil, id = 479 },
            { move = "selfDestruct", level = 29, order = nil, id = 120 },
            { move = "bulldoze", level = 32, order = nil, id = 523 },
            { move = "stealthRock", level = 36, order = nil, id = 446 },
            { move = "earthquake", level = 39, order = nil, id = 89 },
            { move = "explosion", level = 43, order = nil, id = 153 },
            { move = "doubleEdge", level = 46, order = nil, id = 38 },
            { move = "stoneEdge", level = 50, order = nil, id = 444 },
        }
        -- END B2W2 LEARNSET
    },
    graveler = {
        name = "GRAVELER", dex = 75, type = "rock", type2 = "ground",
        baseHP = 55, baseAtk = 95, baseDef = 115, baseSpA = 45, baseSpD = 45, baseSpe = 35, baseExp = 137,
        moves = { "tackle", "defenseCurl", "mudSport", "rockPolish", "mudSport", "rockPolish", "rockThrow", "magnitude", "rollout", "rockBlast", "smackDown", "selfDestruct", "bulldoze", "stealthRock", "earthquake", "explosion", "doubleEdge", "stoneEdge" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "tackle", level = 1, order = 1, id = 33 },
            { move = "defenseCurl", level = 1, order = 2, id = 111 },
            { move = "mudSport", level = 1, order = 3, id = 300 },
            { move = "rockPolish", level = 1, order = 4, id = 397 },
            { move = "mudSport", level = 4, order = nil, id = 300 },
            { move = "rockPolish", level = 8, order = nil, id = 397 },
            { move = "rockThrow", level = 11, order = nil, id = 88 },
            { move = "magnitude", level = 15, order = nil, id = 222 },
            { move = "rollout", level = 18, order = nil, id = 205 },
            { move = "rockBlast", level = 22, order = nil, id = 350 },
            { move = "smackDown", level = 27, order = nil, id = 479 },
            { move = "selfDestruct", level = 31, order = nil, id = 120 },
            { move = "bulldoze", level = 36, order = nil, id = 523 },
            { move = "stealthRock", level = 42, order = nil, id = 446 },
            { move = "earthquake", level = 47, order = nil, id = 89 },
            { move = "explosion", level = 53, order = nil, id = 153 },
            { move = "doubleEdge", level = 58, order = nil, id = 38 },
            { move = "stoneEdge", level = 64, order = nil, id = 444 },
        }
        -- END B2W2 LEARNSET
    },
    golem = {
        name = "GOLEM", dex = 76, type = "rock", type2 = "ground",
        baseHP = 80, baseAtk = 110, baseDef = 130, baseSpA = 55, baseSpD = 65, baseSpe = 45, baseExp = 218,
        moves = { "tackle", "defenseCurl", "mudSport", "rockPolish", "mudSport", "rockPolish", "rockThrow", "magnitude", "steamroller", "rockBlast", "smackDown", "selfDestruct", "bulldoze", "stealthRock", "earthquake", "explosion", "doubleEdge", "stoneEdge", "heavySlam" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "tackle", level = 1, order = 1, id = 33 },
            { move = "defenseCurl", level = 1, order = 2, id = 111 },
            { move = "mudSport", level = 1, order = 3, id = 300 },
            { move = "rockPolish", level = 1, order = 4, id = 397 },
            { move = "mudSport", level = 4, order = nil, id = 300 },
            { move = "rockPolish", level = 8, order = nil, id = 397 },
            { move = "rockThrow", level = 11, order = nil, id = 88 },
            { move = "magnitude", level = 15, order = nil, id = 222 },
            { move = "steamroller", level = 18, order = nil, id = 537 },
            { move = "rockBlast", level = 22, order = nil, id = 350 },
            { move = "smackDown", level = 27, order = nil, id = 479 },
            { move = "selfDestruct", level = 31, order = nil, id = 120 },
            { move = "bulldoze", level = 36, order = nil, id = 523 },
            { move = "stealthRock", level = 42, order = nil, id = 446 },
            { move = "earthquake", level = 47, order = nil, id = 89 },
            { move = "explosion", level = 53, order = nil, id = 153 },
            { move = "doubleEdge", level = 58, order = nil, id = 38 },
            { move = "stoneEdge", level = 64, order = nil, id = 444 },
            { move = "heavySlam", level = 69, order = nil, id = 484 },
        }
        -- END B2W2 LEARNSET
    },
    ponyta = {
        name = "PONYTA", dex = 77, type = "fire", type2 = nil,
        baseHP = 50, baseAtk = 85, baseDef = 55, baseSpA = 65, baseSpD = 65, baseSpe = 90, baseExp = 82,
        moves = { "growl", "tackle", "tailWhip", "ember", "flameWheel", "stomp", "flameCharge", "fireSpin", "takeDown", "inferno", "agility", "fireBlast", "bounce", "flareBlitz" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "growl", level = 1, order = 1, id = 45 },
            { move = "tackle", level = 1, order = 2, id = 33 },
            { move = "tailWhip", level = 4, order = nil, id = 39 },
            { move = "ember", level = 9, order = nil, id = 52 },
            { move = "flameWheel", level = 13, order = nil, id = 172 },
            { move = "stomp", level = 17, order = nil, id = 23 },
            { move = "flameCharge", level = 21, order = nil, id = 488 },
            { move = "fireSpin", level = 25, order = nil, id = 83 },
            { move = "takeDown", level = 29, order = nil, id = 36 },
            { move = "inferno", level = 33, order = nil, id = 517 },
            { move = "agility", level = 37, order = nil, id = 97 },
            { move = "fireBlast", level = 41, order = nil, id = 126 },
            { move = "bounce", level = 45, order = nil, id = 340 },
            { move = "flareBlitz", level = 49, order = nil, id = 394 },
        }
        -- END B2W2 LEARNSET
    },
    rapidash = {
        name = "RAPIDASH", dex = 78, type = "fire", type2 = nil,
        baseHP = 65, baseAtk = 100, baseDef = 70, baseSpA = 80, baseSpD = 80, baseSpe = 105, baseExp = 175,
        moves = { "poisonJab", "megahorn", "growl", "quickAttack", "tailWhip", "ember", "tailWhip", "ember", "flameWheel", "stomp", "flameCharge", "fireSpin", "takeDown", "inferno", "agility", "furyAttack", "fireBlast", "bounce", "flareBlitz" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "poisonJab", level = 1, order = 1, id = 398 },
            { move = "megahorn", level = 1, order = 2, id = 224 },
            { move = "growl", level = 1, order = 3, id = 45 },
            { move = "quickAttack", level = 1, order = 4, id = 98 },
            { move = "tailWhip", level = 1, order = 5, id = 39 },
            { move = "ember", level = 1, order = 6, id = 52 },
            { move = "tailWhip", level = 4, order = nil, id = 39 },
            { move = "ember", level = 9, order = nil, id = 52 },
            { move = "flameWheel", level = 13, order = nil, id = 172 },
            { move = "stomp", level = 17, order = nil, id = 23 },
            { move = "flameCharge", level = 21, order = nil, id = 488 },
            { move = "fireSpin", level = 25, order = nil, id = 83 },
            { move = "takeDown", level = 29, order = nil, id = 36 },
            { move = "inferno", level = 33, order = nil, id = 517 },
            { move = "agility", level = 37, order = nil, id = 97 },
            { move = "furyAttack", level = 40, order = nil, id = 31 },
            { move = "fireBlast", level = 41, order = nil, id = 126 },
            { move = "bounce", level = 45, order = nil, id = 340 },
            { move = "flareBlitz", level = 49, order = nil, id = 394 },
        }
        -- END B2W2 LEARNSET
    },
    slowpoke = {
        name = "SLOWPOKE", dex = 79, type = "water", type2 = "psychic",
        baseHP = 90, baseAtk = 65, baseDef = 65, baseSpA = 40, baseSpD = 40, baseSpe = 15, baseExp = 63,
        moves = { "curse", "yawn", "tackle", "growl", "waterGun", "confusion", "disable", "headbutt", "waterPulse", "zenHeadbutt", "slackOff", "amnesia", "psychic", "rainDance", "psychUp", "healPulse" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "curse", level = 1, order = 1, id = 174 },
            { move = "yawn", level = 1, order = 2, id = 281 },
            { move = "tackle", level = 1, order = 3, id = 33 },
            { move = "growl", level = 5, order = nil, id = 45 },
            { move = "waterGun", level = 9, order = nil, id = 55 },
            { move = "confusion", level = 14, order = nil, id = 93 },
            { move = "disable", level = 19, order = nil, id = 50 },
            { move = "headbutt", level = 23, order = nil, id = 29 },
            { move = "waterPulse", level = 28, order = nil, id = 352 },
            { move = "zenHeadbutt", level = 32, order = nil, id = 428 },
            { move = "slackOff", level = 36, order = nil, id = 303 },
            { move = "amnesia", level = 41, order = nil, id = 133 },
            { move = "psychic", level = 45, order = nil, id = 94 },
            { move = "rainDance", level = 49, order = nil, id = 240 },
            { move = "psychUp", level = 54, order = nil, id = 244 },
            { move = "healPulse", level = 58, order = nil, id = 505 },
        }
        -- END B2W2 LEARNSET
    },
    slowbro = {
        name = "SLOWBRO", dex = 80, type = "water", type2 = "psychic",
        baseHP = 95, baseAtk = 75, baseDef = 110, baseSpA = 100, baseSpD = 80, baseSpe = 30, baseExp = 172,
        moves = { "curse", "yawn", "tackle", "growl", "growl", "waterGun", "confusion", "disable", "headbutt", "waterPulse", "zenHeadbutt", "slackOff", "withdraw", "amnesia", "psychic", "rainDance", "psychUp", "healPulse" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "curse", level = 1, order = 1, id = 174 },
            { move = "yawn", level = 1, order = 2, id = 281 },
            { move = "tackle", level = 1, order = 3, id = 33 },
            { move = "growl", level = 1, order = 4, id = 45 },
            { move = "growl", level = 5, order = nil, id = 45 },
            { move = "waterGun", level = 9, order = nil, id = 55 },
            { move = "confusion", level = 14, order = nil, id = 93 },
            { move = "disable", level = 19, order = nil, id = 50 },
            { move = "headbutt", level = 23, order = nil, id = 29 },
            { move = "waterPulse", level = 28, order = nil, id = 352 },
            { move = "zenHeadbutt", level = 32, order = nil, id = 428 },
            { move = "slackOff", level = 36, order = nil, id = 303 },
            { move = "withdraw", level = 37, order = nil, id = 110 },
            { move = "amnesia", level = 43, order = nil, id = 133 },
            { move = "psychic", level = 49, order = nil, id = 94 },
            { move = "rainDance", level = 55, order = nil, id = 240 },
            { move = "psychUp", level = 62, order = nil, id = 244 },
            { move = "healPulse", level = 68, order = nil, id = 505 },
        }
        -- END B2W2 LEARNSET
    },
    magnemite = {
        name = "MAGNEMITE", dex = 81, type = "electric", type2 = "steel",
        baseHP = 25, baseAtk = 35, baseDef = 70, baseSpA = 95, baseSpD = 55, baseSpe = 45, baseExp = 65,
        moves = { "tackle", "supersonic", "thunderShock", "sonicBoom", "thunderWave", "magnetBomb", "spark", "mirrorShot", "metalSound", "electroBall", "flashCannon", "screech", "discharge", "lockOn", "magnetRise", "gyroBall", "zapCannon" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "tackle", level = 1, order = nil, id = 33 },
            { move = "supersonic", level = 4, order = nil, id = 48 },
            { move = "thunderShock", level = 7, order = nil, id = 84 },
            { move = "sonicBoom", level = 11, order = nil, id = 49 },
            { move = "thunderWave", level = 15, order = nil, id = 86 },
            { move = "magnetBomb", level = 18, order = nil, id = 443 },
            { move = "spark", level = 21, order = nil, id = 209 },
            { move = "mirrorShot", level = 25, order = nil, id = 429 },
            { move = "metalSound", level = 29, order = nil, id = 319 },
            { move = "electroBall", level = 32, order = nil, id = 486 },
            { move = "flashCannon", level = 35, order = nil, id = 430 },
            { move = "screech", level = 39, order = nil, id = 103 },
            { move = "discharge", level = 43, order = nil, id = 435 },
            { move = "lockOn", level = 46, order = nil, id = 199 },
            { move = "magnetRise", level = 49, order = nil, id = 393 },
            { move = "gyroBall", level = 53, order = nil, id = 360 },
            { move = "zapCannon", level = 57, order = nil, id = 192 },
        }
        -- END B2W2 LEARNSET
    },
    magneton = {
        name = "MAGNETON", dex = 82, type = "electric", type2 = "steel",
        baseHP = 50, baseAtk = 60, baseDef = 95, baseSpA = 120, baseSpD = 70, baseSpe = 70, baseExp = 163,
        moves = { "triAttack", "tackle", "supersonic", "thunderShock", "sonicBoom", "supersonic", "thunderShock", "sonicBoom", "thunderWave", "magnetBomb", "spark", "mirrorShot", "metalSound", "electroBall", "flashCannon", "screech", "discharge", "lockOn", "magnetRise", "gyroBall", "zapCannon" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "triAttack", level = 1, order = 1, id = 161 },
            { move = "tackle", level = 1, order = 2, id = 33 },
            { move = "supersonic", level = 1, order = 3, id = 48 },
            { move = "thunderShock", level = 1, order = 4, id = 84 },
            { move = "sonicBoom", level = 1, order = 5, id = 49 },
            { move = "supersonic", level = 4, order = nil, id = 48 },
            { move = "thunderShock", level = 7, order = nil, id = 84 },
            { move = "sonicBoom", level = 11, order = nil, id = 49 },
            { move = "thunderWave", level = 15, order = nil, id = 86 },
            { move = "magnetBomb", level = 18, order = nil, id = 443 },
            { move = "spark", level = 21, order = nil, id = 209 },
            { move = "mirrorShot", level = 25, order = nil, id = 429 },
            { move = "metalSound", level = 29, order = nil, id = 319 },
            { move = "electroBall", level = 34, order = nil, id = 486 },
            { move = "flashCannon", level = 39, order = nil, id = 430 },
            { move = "screech", level = 45, order = nil, id = 103 },
            { move = "discharge", level = 51, order = nil, id = 435 },
            { move = "lockOn", level = 56, order = nil, id = 199 },
            { move = "magnetRise", level = 62, order = nil, id = 393 },
            { move = "gyroBall", level = 67, order = nil, id = 360 },
            { move = "zapCannon", level = 73, order = nil, id = 192 },
        }
        -- END B2W2 LEARNSET
    },
    farfetchd = {
        name = "FARFETCHD", dex = 83, type = "normal", type2 = "flying",
        baseHP = 52, baseAtk = 65, baseDef = 55, baseSpA = 58, baseSpD = 62, baseSpe = 60, baseExp = 123,
        moves = { "poisonJab", "peck", "sandAttack", "leer", "furyCutter", "furyAttack", "knockOff", "aerialAce", "slash", "airCutter", "swordsDance", "agility", "nightSlash", "acrobatics", "feint", "falseSwipe", "airSlash", "braveBird" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "poisonJab", level = 1, order = 1, id = 398 },
            { move = "peck", level = 1, order = 2, id = 64 },
            { move = "sandAttack", level = 1, order = 3, id = 28 },
            { move = "leer", level = 1, order = 4, id = 43 },
            { move = "furyCutter", level = 1, order = 5, id = 210 },
            { move = "furyAttack", level = 7, order = nil, id = 31 },
            { move = "knockOff", level = 9, order = nil, id = 282 },
            { move = "aerialAce", level = 13, order = nil, id = 332 },
            { move = "slash", level = 19, order = nil, id = 163 },
            { move = "airCutter", level = 21, order = nil, id = 314 },
            { move = "swordsDance", level = 25, order = nil, id = 14 },
            { move = "agility", level = 31, order = nil, id = 97 },
            { move = "nightSlash", level = 33, order = nil, id = 400 },
            { move = "acrobatics", level = 37, order = nil, id = 512 },
            { move = "feint", level = 43, order = nil, id = 364 },
            { move = "falseSwipe", level = 45, order = nil, id = 206 },
            { move = "airSlash", level = 49, order = nil, id = 403 },
            { move = "braveBird", level = 55, order = nil, id = 413 },
        }
        -- END B2W2 LEARNSET
    },
    doduo = {
        name = "DODUO", dex = 84, type = "normal", type2 = "flying",
        baseHP = 35, baseAtk = 85, baseDef = 45, baseSpA = 35, baseSpD = 35, baseSpe = 75, baseExp = 62,
        moves = { "peck", "growl", "quickAttack", "rage", "furyAttack", "pursuit", "uproar", "acupressure", "doubleHit", "agility", "drillPeck", "endeavor", "thrash" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "peck", level = 1, order = 1, id = 64 },
            { move = "growl", level = 1, order = 2, id = 45 },
            { move = "quickAttack", level = 5, order = nil, id = 98 },
            { move = "rage", level = 10, order = nil, id = 99 },
            { move = "furyAttack", level = 14, order = nil, id = 31 },
            { move = "pursuit", level = 19, order = nil, id = 228 },
            { move = "uproar", level = 23, order = nil, id = 253 },
            { move = "acupressure", level = 28, order = nil, id = 367 },
            { move = "doubleHit", level = 32, order = nil, id = 458 },
            { move = "agility", level = 37, order = nil, id = 97 },
            { move = "drillPeck", level = 41, order = nil, id = 65 },
            { move = "endeavor", level = 46, order = nil, id = 283 },
            { move = "thrash", level = 50, order = nil, id = 37 },
        }
        -- END B2W2 LEARNSET
    },
    dodrio = {
        name = "DODRIO", dex = 85, type = "normal", type2 = "flying",
        baseHP = 60, baseAtk = 110, baseDef = 70, baseSpA = 60, baseSpD = 60, baseSpe = 100, baseExp = 161,
        moves = { "pluck", "peck", "growl", "quickAttack", "rage", "quickAttack", "rage", "furyAttack", "pursuit", "uproar", "acupressure", "triAttack", "agility", "drillPeck", "endeavor", "thrash" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "pluck", level = 1, order = 1, id = 365 },
            { move = "peck", level = 1, order = 2, id = 64 },
            { move = "growl", level = 1, order = 3, id = 45 },
            { move = "quickAttack", level = 1, order = 4, id = 98 },
            { move = "rage", level = 1, order = 5, id = 99 },
            { move = "quickAttack", level = 5, order = nil, id = 98 },
            { move = "rage", level = 10, order = nil, id = 99 },
            { move = "furyAttack", level = 14, order = nil, id = 31 },
            { move = "pursuit", level = 19, order = nil, id = 228 },
            { move = "uproar", level = 23, order = nil, id = 253 },
            { move = "acupressure", level = 28, order = nil, id = 367 },
            { move = "triAttack", level = 34, order = nil, id = 161 },
            { move = "agility", level = 41, order = nil, id = 97 },
            { move = "drillPeck", level = 47, order = nil, id = 65 },
            { move = "endeavor", level = 54, order = nil, id = 283 },
            { move = "thrash", level = 60, order = nil, id = 37 },
        }
        -- END B2W2 LEARNSET
    },
    seel = {
        name = "SEEL", dex = 86, type = "water", type2 = nil,
        baseHP = 65, baseAtk = 45, baseDef = 55, baseSpA = 45, baseSpD = 70, baseSpe = 45, baseExp = 65,
        moves = { "headbutt", "growl", "waterSport", "icyWind", "encore", "iceShard", "rest", "aquaRing", "auroraBeam", "aquaJet", "brine", "takeDown", "dive", "aquaTail", "iceBeam", "safeguard", "hail" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "headbutt", level = 1, order = nil, id = 29 },
            { move = "growl", level = 3, order = nil, id = 45 },
            { move = "waterSport", level = 7, order = nil, id = 346 },
            { move = "icyWind", level = 11, order = nil, id = 196 },
            { move = "encore", level = 13, order = nil, id = 227 },
            { move = "iceShard", level = 17, order = nil, id = 420 },
            { move = "rest", level = 21, order = nil, id = 156 },
            { move = "aquaRing", level = 23, order = nil, id = 392 },
            { move = "auroraBeam", level = 27, order = nil, id = 62 },
            { move = "aquaJet", level = 31, order = nil, id = 453 },
            { move = "brine", level = 33, order = nil, id = 362 },
            { move = "takeDown", level = 37, order = nil, id = 36 },
            { move = "dive", level = 41, order = nil, id = 291 },
            { move = "aquaTail", level = 43, order = nil, id = 401 },
            { move = "iceBeam", level = 47, order = nil, id = 58 },
            { move = "safeguard", level = 51, order = nil, id = 219 },
            { move = "hail", level = 53, order = nil, id = 258 },
        }
        -- END B2W2 LEARNSET
    },
    dewgong = {
        name = "DEWGONG", dex = 87, type = "water", type2 = "ice",
        baseHP = 90, baseAtk = 70, baseDef = 80, baseSpA = 70, baseSpD = 95, baseSpe = 70, baseExp = 166,
        moves = { "headbutt", "growl", "signalBeam", "icyWind", "growl", "signalBeam", "icyWind", "encore", "iceShard", "rest", "aquaRing", "auroraBeam", "aquaJet", "brine", "sheerCold", "takeDown", "dive", "aquaTail", "iceBeam", "safeguard", "hail" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "headbutt", level = 1, order = 1, id = 29 },
            { move = "growl", level = 1, order = 2, id = 45 },
            { move = "signalBeam", level = 1, order = 3, id = 324 },
            { move = "icyWind", level = 1, order = 4, id = 196 },
            { move = "growl", level = 3, order = nil, id = 45 },
            { move = "signalBeam", level = 7, order = nil, id = 324 },
            { move = "icyWind", level = 11, order = nil, id = 196 },
            { move = "encore", level = 13, order = nil, id = 227 },
            { move = "iceShard", level = 17, order = nil, id = 420 },
            { move = "rest", level = 21, order = nil, id = 156 },
            { move = "aquaRing", level = 23, order = nil, id = 392 },
            { move = "auroraBeam", level = 27, order = nil, id = 62 },
            { move = "aquaJet", level = 31, order = nil, id = 453 },
            { move = "brine", level = 33, order = nil, id = 362 },
            { move = "sheerCold", level = 34, order = nil, id = 329 },
            { move = "takeDown", level = 39, order = nil, id = 36 },
            { move = "dive", level = 45, order = nil, id = 291 },
            { move = "aquaTail", level = 49, order = nil, id = 401 },
            { move = "iceBeam", level = 55, order = nil, id = 58 },
            { move = "safeguard", level = 61, order = nil, id = 219 },
            { move = "hail", level = 65, order = nil, id = 258 },
        }
        -- END B2W2 LEARNSET
    },
    grimer = {
        name = "GRIMER", dex = 88, type = "poison", type2 = nil,
        baseHP = 80, baseAtk = 80, baseDef = 50, baseSpA = 40, baseSpD = 50, baseSpe = 25, baseExp = 65,
        moves = { "pound", "poisonGas", "harden", "mudSlap", "disable", "sludge", "minimize", "mudBomb", "sludgeBomb", "fling", "screech", "sludgeWave", "acidArmor", "gunkShot", "memento" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "pound", level = 1, order = 1, id = 1 },
            { move = "poisonGas", level = 1, order = 2, id = 139 },
            { move = "harden", level = 4, order = nil, id = 106 },
            { move = "mudSlap", level = 7, order = nil, id = 189 },
            { move = "disable", level = 12, order = nil, id = 50 },
            { move = "sludge", level = 15, order = nil, id = 124 },
            { move = "minimize", level = 18, order = nil, id = 107 },
            { move = "mudBomb", level = 21, order = nil, id = 426 },
            { move = "sludgeBomb", level = 26, order = nil, id = 188 },
            { move = "fling", level = 29, order = nil, id = 374 },
            { move = "screech", level = 32, order = nil, id = 103 },
            { move = "sludgeWave", level = 37, order = nil, id = 482 },
            { move = "acidArmor", level = 40, order = nil, id = 151 },
            { move = "gunkShot", level = 43, order = nil, id = 441 },
            { move = "memento", level = 48, order = nil, id = 262 },
        }
        -- END B2W2 LEARNSET
    },
    muk = {
        name = "MUK", dex = 89, type = "poison", type2 = nil,
        baseHP = 105, baseAtk = 105, baseDef = 75, baseSpA = 65, baseSpD = 100, baseSpe = 50, baseExp = 175,
        moves = { "pound", "poisonGas", "harden", "mudSlap", "harden", "mudSlap", "disable", "sludge", "minimize", "mudBomb", "sludgeBomb", "fling", "screech", "sludgeWave", "acidArmor", "gunkShot", "memento" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "pound", level = 1, order = 1, id = 1 },
            { move = "poisonGas", level = 1, order = 2, id = 139 },
            { move = "harden", level = 1, order = 3, id = 106 },
            { move = "mudSlap", level = 1, order = 4, id = 189 },
            { move = "harden", level = 4, order = nil, id = 106 },
            { move = "mudSlap", level = 7, order = nil, id = 189 },
            { move = "disable", level = 12, order = nil, id = 50 },
            { move = "sludge", level = 15, order = nil, id = 124 },
            { move = "minimize", level = 18, order = nil, id = 107 },
            { move = "mudBomb", level = 21, order = nil, id = 426 },
            { move = "sludgeBomb", level = 26, order = nil, id = 188 },
            { move = "fling", level = 29, order = nil, id = 374 },
            { move = "screech", level = 32, order = nil, id = 103 },
            { move = "sludgeWave", level = 37, order = nil, id = 482 },
            { move = "acidArmor", level = 43, order = nil, id = 151 },
            { move = "gunkShot", level = 49, order = nil, id = 441 },
            { move = "memento", level = 57, order = nil, id = 262 },
        }
        -- END B2W2 LEARNSET
    },
    shellder = {
        name = "SHELLDER", dex = 90, type = "water", type2 = nil,
        baseHP = 30, baseAtk = 65, baseDef = 100, baseSpA = 45, baseSpD = 25, baseSpe = 40, baseExp = 61,
        moves = { "tackle", "withdraw", "supersonic", "icicleSpear", "protect", "leer", "clamp", "iceShard", "razorShell", "auroraBeam", "whirlpool", "brine", "ironDefense", "iceBeam", "shellSmash", "hydroPump" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "tackle", level = 1, order = nil, id = 33 },
            { move = "withdraw", level = 4, order = nil, id = 110 },
            { move = "supersonic", level = 8, order = nil, id = 48 },
            { move = "icicleSpear", level = 13, order = nil, id = 333 },
            { move = "protect", level = 16, order = nil, id = 182 },
            { move = "leer", level = 20, order = nil, id = 43 },
            { move = "clamp", level = 25, order = nil, id = 128 },
            { move = "iceShard", level = 28, order = nil, id = 420 },
            { move = "razorShell", level = 32, order = nil, id = 534 },
            { move = "auroraBeam", level = 37, order = nil, id = 62 },
            { move = "whirlpool", level = 40, order = nil, id = 250 },
            { move = "brine", level = 44, order = nil, id = 362 },
            { move = "ironDefense", level = 49, order = nil, id = 334 },
            { move = "iceBeam", level = 52, order = nil, id = 58 },
            { move = "shellSmash", level = 56, order = nil, id = 504 },
            { move = "hydroPump", level = 61, order = nil, id = 56 },
        }
        -- END B2W2 LEARNSET
    },
    cloyster = {
        name = "CLOYSTER", dex = 91, type = "water", type2 = "ice",
        baseHP = 50, baseAtk = 95, baseDef = 180, baseSpA = 85, baseSpD = 45, baseSpe = 70, baseExp = 184,
        moves = { "toxicSpikes", "withdraw", "supersonic", "protect", "auroraBeam", "spikeCannon", "spikes", "icicleCrash" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "toxicSpikes", level = 1, order = 1, id = 390 },
            { move = "withdraw", level = 1, order = 2, id = 110 },
            { move = "supersonic", level = 1, order = 3, id = 48 },
            { move = "protect", level = 1, order = 4, id = 182 },
            { move = "auroraBeam", level = 1, order = 5, id = 62 },
            { move = "spikeCannon", level = 13, order = nil, id = 131 },
            { move = "spikes", level = 28, order = nil, id = 191 },
            { move = "icicleCrash", level = 52, order = nil, id = 556 },
        }
        -- END B2W2 LEARNSET
    },
    gastly = {
        name = "GASTLY", dex = 92, type = "ghost", type2 = "poison",
        baseHP = 30, baseAtk = 35, baseDef = 30, baseSpA = 100, baseSpD = 35, baseSpe = 80, baseExp = 62,
        moves = { "hypnosis", "lick", "spite", "meanLook", "curse", "nightShade", "confuseRay", "suckerPunch", "payback", "shadowBall", "dreamEater", "darkPulse", "destinyBond", "hex", "nightmare" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "hypnosis", level = 1, order = 1, id = 95 },
            { move = "lick", level = 1, order = 2, id = 122 },
            { move = "spite", level = 5, order = nil, id = 180 },
            { move = "meanLook", level = 8, order = nil, id = 212 },
            { move = "curse", level = 12, order = nil, id = 174 },
            { move = "nightShade", level = 15, order = nil, id = 101 },
            { move = "confuseRay", level = 19, order = nil, id = 109 },
            { move = "suckerPunch", level = 22, order = nil, id = 389 },
            { move = "payback", level = 26, order = nil, id = 371 },
            { move = "shadowBall", level = 29, order = nil, id = 247 },
            { move = "dreamEater", level = 33, order = nil, id = 138 },
            { move = "darkPulse", level = 36, order = nil, id = 399 },
            { move = "destinyBond", level = 40, order = nil, id = 194 },
            { move = "hex", level = 43, order = nil, id = 506 },
            { move = "nightmare", level = 47, order = nil, id = 171 },
        }
        -- END B2W2 LEARNSET
    },
    haunter = {
        name = "HAUNTER", dex = 93, type = "ghost", type2 = "poison",
        baseHP = 45, baseAtk = 50, baseDef = 45, baseSpA = 115, baseSpD = 55, baseSpe = 95, baseExp = 142,
        moves = { "hypnosis", "lick", "spite", "spite", "meanLook", "curse", "nightShade", "confuseRay", "suckerPunch", "shadowPunch", "payback", "shadowBall", "dreamEater", "darkPulse", "destinyBond", "hex", "nightmare" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "hypnosis", level = 1, order = 1, id = 95 },
            { move = "lick", level = 1, order = 2, id = 122 },
            { move = "spite", level = 1, order = 3, id = 180 },
            { move = "spite", level = 5, order = nil, id = 180 },
            { move = "meanLook", level = 8, order = nil, id = 212 },
            { move = "curse", level = 12, order = nil, id = 174 },
            { move = "nightShade", level = 15, order = nil, id = 101 },
            { move = "confuseRay", level = 19, order = nil, id = 109 },
            { move = "suckerPunch", level = 22, order = nil, id = 389 },
            { move = "shadowPunch", level = 25, order = nil, id = 325 },
            { move = "payback", level = 28, order = nil, id = 371 },
            { move = "shadowBall", level = 33, order = nil, id = 247 },
            { move = "dreamEater", level = 39, order = nil, id = 138 },
            { move = "darkPulse", level = 44, order = nil, id = 399 },
            { move = "destinyBond", level = 50, order = nil, id = 194 },
            { move = "hex", level = 55, order = nil, id = 506 },
            { move = "nightmare", level = 61, order = nil, id = 171 },
        }
        -- END B2W2 LEARNSET
    },
    gengar = {
        name = "GENGAR", dex = 94, type = "ghost", type2 = "poison",
        baseHP = 60, baseAtk = 65, baseDef = 60, baseSpA = 130, baseSpD = 75, baseSpe = 110, baseExp = 225,
        moves = { "hypnosis", "lick", "spite", "spite", "meanLook", "curse", "nightShade", "confuseRay", "suckerPunch", "shadowPunch", "payback", "shadowBall", "dreamEater", "darkPulse", "destinyBond", "hex", "nightmare" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "hypnosis", level = 1, order = 1, id = 95 },
            { move = "lick", level = 1, order = 2, id = 122 },
            { move = "spite", level = 1, order = 3, id = 180 },
            { move = "spite", level = 5, order = nil, id = 180 },
            { move = "meanLook", level = 8, order = nil, id = 212 },
            { move = "curse", level = 12, order = nil, id = 174 },
            { move = "nightShade", level = 15, order = nil, id = 101 },
            { move = "confuseRay", level = 19, order = nil, id = 109 },
            { move = "suckerPunch", level = 22, order = nil, id = 389 },
            { move = "shadowPunch", level = 25, order = nil, id = 325 },
            { move = "payback", level = 28, order = nil, id = 371 },
            { move = "shadowBall", level = 33, order = nil, id = 247 },
            { move = "dreamEater", level = 39, order = nil, id = 138 },
            { move = "darkPulse", level = 44, order = nil, id = 399 },
            { move = "destinyBond", level = 50, order = nil, id = 194 },
            { move = "hex", level = 55, order = nil, id = 506 },
            { move = "nightmare", level = 61, order = nil, id = 171 },
        }
        -- END B2W2 LEARNSET
    },
    onix = {
        name = "ONIX", dex = 95, type = "rock", type2 = "ground",
        baseHP = 35, baseAtk = 45, baseDef = 160, baseSpA = 30, baseSpD = 45, baseSpe = 70, baseExp = 77,
        moves = { "mudSport", "tackle", "harden", "bind", "curse", "rockThrow", "rage", "rockTomb", "stealthRock", "rockPolish", "smackDown", "dragonBreath", "slam", "screech", "rockSlide", "sandTomb", "ironTail", "dig", "stoneEdge", "doubleEdge", "sandstorm" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "mudSport", level = 1, order = 1, id = 300 },
            { move = "tackle", level = 1, order = 2, id = 33 },
            { move = "harden", level = 1, order = 3, id = 106 },
            { move = "bind", level = 1, order = 4, id = 20 },
            { move = "curse", level = 4, order = nil, id = 174 },
            { move = "rockThrow", level = 7, order = nil, id = 88 },
            { move = "rage", level = 10, order = nil, id = 99 },
            { move = "rockTomb", level = 13, order = nil, id = 317 },
            { move = "stealthRock", level = 16, order = nil, id = 446 },
            { move = "rockPolish", level = 19, order = nil, id = 397 },
            { move = "smackDown", level = 22, order = nil, id = 479 },
            { move = "dragonBreath", level = 25, order = nil, id = 225 },
            { move = "slam", level = 28, order = nil, id = 21 },
            { move = "screech", level = 31, order = nil, id = 103 },
            { move = "rockSlide", level = 34, order = nil, id = 157 },
            { move = "sandTomb", level = 37, order = nil, id = 328 },
            { move = "ironTail", level = 40, order = nil, id = 231 },
            { move = "dig", level = 43, order = nil, id = 91 },
            { move = "stoneEdge", level = 46, order = nil, id = 444 },
            { move = "doubleEdge", level = 49, order = nil, id = 38 },
            { move = "sandstorm", level = 52, order = nil, id = 201 },
        }
        -- END B2W2 LEARNSET
    },
    drowzee = {
        name = "DROWZEE", dex = 96, type = "psychic", type2 = nil,
        baseHP = 60, baseAtk = 48, baseDef = 45, baseSpA = 43, baseSpD = 90, baseSpe = 42, baseExp = 66,
        moves = { "pound", "hypnosis", "disable", "confusion", "headbutt", "poisonGas", "meditate", "psybeam", "headbutt", "psychUp", "synchronoise", "zenHeadbutt", "swagger", "psychic", "nastyPlot", "psyshock", "futureSight" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "pound", level = 1, order = 1, id = 1 },
            { move = "hypnosis", level = 1, order = 2, id = 95 },
            { move = "disable", level = 5, order = nil, id = 50 },
            { move = "confusion", level = 9, order = nil, id = 93 },
            { move = "headbutt", level = 13, order = nil, id = 29 },
            { move = "poisonGas", level = 17, order = nil, id = 139 },
            { move = "meditate", level = 21, order = nil, id = 96 },
            { move = "psybeam", level = 25, order = nil, id = 60 },
            { move = "headbutt", level = 29, order = nil, id = 29 },
            { move = "psychUp", level = 33, order = nil, id = 244 },
            { move = "synchronoise", level = 37, order = nil, id = 485 },
            { move = "zenHeadbutt", level = 41, order = nil, id = 428 },
            { move = "swagger", level = 45, order = nil, id = 207 },
            { move = "psychic", level = 49, order = nil, id = 94 },
            { move = "nastyPlot", level = 53, order = nil, id = 417 },
            { move = "psyshock", level = 57, order = nil, id = 473 },
            { move = "futureSight", level = 61, order = nil, id = 248 },
        }
        -- END B2W2 LEARNSET
    },
    hypno = {
        name = "HYPNO", dex = 97, type = "psychic", type2 = nil,
        baseHP = 85, baseAtk = 73, baseDef = 70, baseSpA = 73, baseSpD = 115, baseSpe = 67, baseExp = 169,
        moves = { "nightmare", "switcheroo", "pound", "hypnosis", "disable", "confusion", "disable", "confusion", "headbutt", "poisonGas", "meditate", "psybeam", "headbutt", "psychUp", "synchronoise", "zenHeadbutt", "swagger", "psychic", "nastyPlot", "psyshock", "futureSight" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "nightmare", level = 1, order = 1, id = 171 },
            { move = "switcheroo", level = 1, order = 2, id = 415 },
            { move = "pound", level = 1, order = 3, id = 1 },
            { move = "hypnosis", level = 1, order = 4, id = 95 },
            { move = "disable", level = 1, order = 5, id = 50 },
            { move = "confusion", level = 1, order = 6, id = 93 },
            { move = "disable", level = 5, order = nil, id = 50 },
            { move = "confusion", level = 9, order = nil, id = 93 },
            { move = "headbutt", level = 13, order = nil, id = 29 },
            { move = "poisonGas", level = 17, order = nil, id = 139 },
            { move = "meditate", level = 21, order = nil, id = 96 },
            { move = "psybeam", level = 25, order = nil, id = 60 },
            { move = "headbutt", level = 29, order = nil, id = 29 },
            { move = "psychUp", level = 33, order = nil, id = 244 },
            { move = "synchronoise", level = 37, order = nil, id = 485 },
            { move = "zenHeadbutt", level = 41, order = nil, id = 428 },
            { move = "swagger", level = 45, order = nil, id = 207 },
            { move = "psychic", level = 49, order = nil, id = 94 },
            { move = "nastyPlot", level = 53, order = nil, id = 417 },
            { move = "psyshock", level = 57, order = nil, id = 473 },
            { move = "futureSight", level = 61, order = nil, id = 248 },
        }
        -- END B2W2 LEARNSET
    },
    krabby = {
        name = "KRABBY", dex = 98, type = "water", type2 = nil,
        baseHP = 30, baseAtk = 105, baseDef = 90, baseSpA = 25, baseSpD = 25, baseSpe = 50, baseExp = 65,
        moves = { "mudSport", "bubble", "viceGrip", "leer", "harden", "bubbleBeam", "mudShot", "metalClaw", "stomp", "protect", "guillotine", "slam", "brine", "crabhammer", "flail" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "mudSport", level = 1, order = 1, id = 300 },
            { move = "bubble", level = 1, order = 2, id = 145 },
            { move = "viceGrip", level = 5, order = nil, id = 11 },
            { move = "leer", level = 9, order = nil, id = 43 },
            { move = "harden", level = 11, order = nil, id = 106 },
            { move = "bubbleBeam", level = 15, order = nil, id = 61 },
            { move = "mudShot", level = 19, order = nil, id = 341 },
            { move = "metalClaw", level = 21, order = nil, id = 232 },
            { move = "stomp", level = 25, order = nil, id = 23 },
            { move = "protect", level = 29, order = nil, id = 182 },
            { move = "guillotine", level = 31, order = nil, id = 12 },
            { move = "slam", level = 35, order = nil, id = 21 },
            { move = "brine", level = 39, order = nil, id = 362 },
            { move = "crabhammer", level = 41, order = nil, id = 152 },
            { move = "flail", level = 45, order = nil, id = 175 },
        }
        -- END B2W2 LEARNSET
    },
    kingler = {
        name = "KINGLER", dex = 99, type = "water", type2 = nil,
        baseHP = 55, baseAtk = 130, baseDef = 115, baseSpA = 50, baseSpD = 50, baseSpe = 75, baseExp = 166,
        moves = { "wideGuard", "mudSport", "bubble", "viceGrip", "leer", "viceGrip", "leer", "harden", "bubbleBeam", "mudShot", "metalClaw", "stomp", "protect", "guillotine", "slam", "brine", "crabhammer", "flail" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "wideGuard", level = 1, order = 1, id = 469 },
            { move = "mudSport", level = 1, order = 2, id = 300 },
            { move = "bubble", level = 1, order = 3, id = 145 },
            { move = "viceGrip", level = 1, order = 4, id = 11 },
            { move = "leer", level = 1, order = 5, id = 43 },
            { move = "viceGrip", level = 5, order = nil, id = 11 },
            { move = "leer", level = 9, order = nil, id = 43 },
            { move = "harden", level = 11, order = nil, id = 106 },
            { move = "bubbleBeam", level = 15, order = nil, id = 61 },
            { move = "mudShot", level = 19, order = nil, id = 341 },
            { move = "metalClaw", level = 21, order = nil, id = 232 },
            { move = "stomp", level = 25, order = nil, id = 23 },
            { move = "protect", level = 32, order = nil, id = 182 },
            { move = "guillotine", level = 37, order = nil, id = 12 },
            { move = "slam", level = 44, order = nil, id = 21 },
            { move = "brine", level = 51, order = nil, id = 362 },
            { move = "crabhammer", level = 56, order = nil, id = 152 },
            { move = "flail", level = 63, order = nil, id = 175 },
        }
        -- END B2W2 LEARNSET
    },
    voltorb = {
        name = "VOLTORB", dex = 100, type = "electric", type2 = nil,
        baseHP = 40, baseAtk = 30, baseDef = 50, baseSpA = 55, baseSpD = 55, baseSpe = 100, baseExp = 66,
        moves = { "charge", "tackle", "sonicBoom", "spark", "rollout", "screech", "chargeBeam", "lightScreen", "electroBall", "selfDestruct", "swift", "magnetRise", "gyroBall", "explosion", "mirrorCoat" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "charge", level = 1, order = nil, id = 268 },
            { move = "tackle", level = 5, order = nil, id = 33 },
            { move = "sonicBoom", level = 8, order = nil, id = 49 },
            { move = "spark", level = 12, order = nil, id = 209 },
            { move = "rollout", level = 15, order = nil, id = 205 },
            { move = "screech", level = 19, order = nil, id = 103 },
            { move = "chargeBeam", level = 22, order = nil, id = 451 },
            { move = "lightScreen", level = 26, order = nil, id = 113 },
            { move = "electroBall", level = 29, order = nil, id = 486 },
            { move = "selfDestruct", level = 33, order = nil, id = 120 },
            { move = "swift", level = 36, order = nil, id = 129 },
            { move = "magnetRise", level = 40, order = nil, id = 393 },
            { move = "gyroBall", level = 43, order = nil, id = 360 },
            { move = "explosion", level = 47, order = nil, id = 153 },
            { move = "mirrorCoat", level = 50, order = nil, id = 243 },
        }
        -- END B2W2 LEARNSET
    },
    electrode = {
        name = "ELECTRODE", dex = 101, type = "electric", type2 = nil,
        baseHP = 60, baseAtk = 50, baseDef = 70, baseSpA = 80, baseSpD = 80, baseSpe = 140, baseExp = 168,
        moves = { "charge", "tackle", "sonicBoom", "spark", "tackle", "sonicBoom", "spark", "rollout", "screech", "chargeBeam", "lightScreen", "electroBall", "selfDestruct", "swift", "magnetRise", "gyroBall", "explosion", "mirrorCoat" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "charge", level = 1, order = 1, id = 268 },
            { move = "tackle", level = 1, order = 2, id = 33 },
            { move = "sonicBoom", level = 1, order = 3, id = 49 },
            { move = "spark", level = 1, order = 4, id = 209 },
            { move = "tackle", level = 5, order = nil, id = 33 },
            { move = "sonicBoom", level = 8, order = nil, id = 49 },
            { move = "spark", level = 12, order = nil, id = 209 },
            { move = "rollout", level = 15, order = nil, id = 205 },
            { move = "screech", level = 19, order = nil, id = 103 },
            { move = "chargeBeam", level = 22, order = nil, id = 451 },
            { move = "lightScreen", level = 26, order = nil, id = 113 },
            { move = "electroBall", level = 29, order = nil, id = 486 },
            { move = "selfDestruct", level = 35, order = nil, id = 120 },
            { move = "swift", level = 40, order = nil, id = 129 },
            { move = "magnetRise", level = 46, order = nil, id = 393 },
            { move = "gyroBall", level = 51, order = nil, id = 360 },
            { move = "explosion", level = 57, order = nil, id = 153 },
            { move = "mirrorCoat", level = 62, order = nil, id = 243 },
        }
        -- END B2W2 LEARNSET
    },
    exeggcute = {
        name = "EXEGGCUTE", dex = 102, type = "grass", type2 = "psychic",
        baseHP = 60, baseAtk = 40, baseDef = 80, baseSpA = 60, baseSpD = 45, baseSpe = 40, baseExp = 65,
        moves = { "barrage", "uproar", "hypnosis", "reflect", "leechSeed", "bulletSeed", "stunSpore", "poisonPowder", "sleepPowder", "confusion", "worrySeed", "naturalGift", "solarBeam", "extrasensory", "bestow" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "barrage", level = 1, order = 1, id = 140 },
            { move = "uproar", level = 1, order = 2, id = 253 },
            { move = "hypnosis", level = 1, order = 3, id = 95 },
            { move = "reflect", level = 7, order = nil, id = 115 },
            { move = "leechSeed", level = 11, order = nil, id = 73 },
            { move = "bulletSeed", level = 17, order = nil, id = 331 },
            { move = "stunSpore", level = 19, order = nil, id = 78 },
            { move = "poisonPowder", level = 21, order = nil, id = 77 },
            { move = "sleepPowder", level = 23, order = nil, id = 79 },
            { move = "confusion", level = 27, order = nil, id = 93 },
            { move = "worrySeed", level = 33, order = nil, id = 388 },
            { move = "naturalGift", level = 37, order = nil, id = 363 },
            { move = "solarBeam", level = 43, order = nil, id = 76 },
            { move = "extrasensory", level = 47, order = nil, id = 326 },
            { move = "bestow", level = 53, order = nil, id = 516 },
        }
        -- END B2W2 LEARNSET
    },
    exeggutor = {
        name = "EXEGGUTOR", dex = 103, type = "grass", type2 = "psychic",
        baseHP = 95, baseAtk = 95, baseDef = 85, baseSpA = 125, baseSpD = 65, baseSpe = 55, baseExp = 182,
        moves = { "seedBomb", "barrage", "hypnosis", "confusion", "stomp", "psyshock", "eggBomb", "woodHammer", "leafStorm" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "seedBomb", level = 1, order = 1, id = 402 },
            { move = "barrage", level = 1, order = 2, id = 140 },
            { move = "hypnosis", level = 1, order = 3, id = 95 },
            { move = "confusion", level = 1, order = 4, id = 93 },
            { move = "stomp", level = 1, order = 5, id = 23 },
            { move = "psyshock", level = 17, order = nil, id = 473 },
            { move = "eggBomb", level = 27, order = nil, id = 121 },
            { move = "woodHammer", level = 37, order = nil, id = 452 },
            { move = "leafStorm", level = 47, order = nil, id = 437 },
        }
        -- END B2W2 LEARNSET
    },
    cubone = {
        name = "CUBONE", dex = 104, type = "ground", type2 = nil,
        baseHP = 50, baseAtk = 50, baseDef = 95, baseSpA = 40, baseSpD = 50, baseSpe = 35, baseExp = 64,
        moves = { "growl", "tailWhip", "boneClub", "headbutt", "leer", "focusEnergy", "bonemerang", "rage", "falseSwipe", "thrash", "fling", "boneRush", "endeavor", "doubleEdge", "retaliate" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "growl", level = 1, order = nil, id = 45 },
            { move = "tailWhip", level = 3, order = nil, id = 39 },
            { move = "boneClub", level = 7, order = nil, id = 125 },
            { move = "headbutt", level = 11, order = nil, id = 29 },
            { move = "leer", level = 13, order = nil, id = 43 },
            { move = "focusEnergy", level = 17, order = nil, id = 116 },
            { move = "bonemerang", level = 21, order = nil, id = 155 },
            { move = "rage", level = 23, order = nil, id = 99 },
            { move = "falseSwipe", level = 27, order = nil, id = 206 },
            { move = "thrash", level = 31, order = nil, id = 37 },
            { move = "fling", level = 33, order = nil, id = 374 },
            { move = "boneRush", level = 37, order = nil, id = 198 },
            { move = "endeavor", level = 41, order = nil, id = 283 },
            { move = "doubleEdge", level = 43, order = nil, id = 38 },
            { move = "retaliate", level = 47, order = nil, id = 514 },
        }
        -- END B2W2 LEARNSET
    },
    marowak = {
        name = "MAROWAK", dex = 105, type = "ground", type2 = nil,
        baseHP = 60, baseAtk = 80, baseDef = 110, baseSpA = 50, baseSpD = 80, baseSpe = 45, baseExp = 149,
        moves = { "growl", "tailWhip", "boneClub", "headbutt", "tailWhip", "boneClub", "headbutt", "leer", "focusEnergy", "bonemerang", "rage", "falseSwipe", "thrash", "fling", "boneRush", "endeavor", "doubleEdge", "retaliate" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "growl", level = 1, order = 1, id = 45 },
            { move = "tailWhip", level = 1, order = 2, id = 39 },
            { move = "boneClub", level = 1, order = 3, id = 125 },
            { move = "headbutt", level = 1, order = 4, id = 29 },
            { move = "tailWhip", level = 3, order = nil, id = 39 },
            { move = "boneClub", level = 7, order = nil, id = 125 },
            { move = "headbutt", level = 11, order = nil, id = 29 },
            { move = "leer", level = 13, order = nil, id = 43 },
            { move = "focusEnergy", level = 17, order = nil, id = 116 },
            { move = "bonemerang", level = 21, order = nil, id = 155 },
            { move = "rage", level = 23, order = nil, id = 99 },
            { move = "falseSwipe", level = 27, order = nil, id = 206 },
            { move = "thrash", level = 33, order = nil, id = 37 },
            { move = "fling", level = 37, order = nil, id = 374 },
            { move = "boneRush", level = 43, order = nil, id = 198 },
            { move = "endeavor", level = 49, order = nil, id = 283 },
            { move = "doubleEdge", level = 53, order = nil, id = 38 },
            { move = "retaliate", level = 59, order = nil, id = 514 },
        }
        -- END B2W2 LEARNSET
    },
    hitmonlee = {
        name = "HITMONLEE", dex = 106, type = "fighting", type2 = nil,
        baseHP = 50, baseAtk = 120, baseDef = 53, baseSpA = 35, baseSpD = 110, baseSpe = 87, baseExp = 159,
        moves = { "revenge", "doubleKick", "meditate", "rollingKick", "jumpKick", "brickBreak", "focusEnergy", "feint", "highJumpKick", "mindReader", "foresight", "wideGuard", "blazeKick", "endure", "megaKick", "closeCombat", "reversal" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "revenge", level = 1, order = 1, id = 279 },
            { move = "doubleKick", level = 1, order = 2, id = 24 },
            { move = "meditate", level = 5, order = nil, id = 96 },
            { move = "rollingKick", level = 9, order = nil, id = 27 },
            { move = "jumpKick", level = 13, order = nil, id = 26 },
            { move = "brickBreak", level = 17, order = nil, id = 280 },
            { move = "focusEnergy", level = 21, order = nil, id = 116 },
            { move = "feint", level = 25, order = nil, id = 364 },
            { move = "highJumpKick", level = 29, order = nil, id = 136 },
            { move = "mindReader", level = 33, order = nil, id = 170 },
            { move = "foresight", level = 37, order = nil, id = 193 },
            { move = "wideGuard", level = 41, order = nil, id = 469 },
            { move = "blazeKick", level = 45, order = nil, id = 299 },
            { move = "endure", level = 49, order = nil, id = 203 },
            { move = "megaKick", level = 53, order = nil, id = 25 },
            { move = "closeCombat", level = 57, order = nil, id = 370 },
            { move = "reversal", level = 61, order = nil, id = 179 },
        }
        -- END B2W2 LEARNSET
    },
    hitmonchan = {
        name = "HITMONCHAN", dex = 107, type = "fighting", type2 = nil,
        baseHP = 50, baseAtk = 105, baseDef = 79, baseSpA = 35, baseSpD = 110, baseSpe = 76, baseExp = 159,
        moves = { "revenge", "cometPunch", "agility", "pursuit", "machPunch", "bulletPunch", "feint", "vacuumWave", "quickGuard", "thunderPunch", "icePunch", "firePunch", "skyUppercut", "megaPunch", "detect", "focusPunch", "counter", "closeCombat" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "revenge", level = 1, order = 1, id = 279 },
            { move = "cometPunch", level = 1, order = 2, id = 4 },
            { move = "agility", level = 6, order = nil, id = 97 },
            { move = "pursuit", level = 11, order = nil, id = 228 },
            { move = "machPunch", level = 16, order = 1, id = 183 },
            { move = "bulletPunch", level = 16, order = 2, id = 418 },
            { move = "feint", level = 21, order = nil, id = 364 },
            { move = "vacuumWave", level = 26, order = nil, id = 410 },
            { move = "quickGuard", level = 31, order = nil, id = 501 },
            { move = "thunderPunch", level = 36, order = 1, id = 9 },
            { move = "icePunch", level = 36, order = 2, id = 8 },
            { move = "firePunch", level = 36, order = 3, id = 7 },
            { move = "skyUppercut", level = 41, order = nil, id = 327 },
            { move = "megaPunch", level = 46, order = nil, id = 5 },
            { move = "detect", level = 51, order = nil, id = 197 },
            { move = "focusPunch", level = 56, order = nil, id = 264 },
            { move = "counter", level = 61, order = nil, id = 68 },
            { move = "closeCombat", level = 66, order = nil, id = 370 },
        }
        -- END B2W2 LEARNSET
    },
    lickitung = {
        name = "LICKITUNG", dex = 108, type = "normal", type2 = nil,
        baseHP = 90, baseAtk = 55, baseDef = 75, baseSpA = 60, baseSpD = 75, baseSpe = 30, baseExp = 77,
        moves = { "lick", "supersonic", "defenseCurl", "knockOff", "wrap", "stomp", "disable", "slam", "rollout", "chipAway", "meFirst", "refresh", "screech", "powerWhip", "wringOut" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "lick", level = 1, order = nil, id = 122 },
            { move = "supersonic", level = 5, order = nil, id = 48 },
            { move = "defenseCurl", level = 9, order = nil, id = 111 },
            { move = "knockOff", level = 13, order = nil, id = 282 },
            { move = "wrap", level = 17, order = nil, id = 35 },
            { move = "stomp", level = 21, order = nil, id = 23 },
            { move = "disable", level = 25, order = nil, id = 50 },
            { move = "slam", level = 29, order = nil, id = 21 },
            { move = "rollout", level = 33, order = nil, id = 205 },
            { move = "chipAway", level = 37, order = nil, id = 498 },
            { move = "meFirst", level = 41, order = nil, id = 382 },
            { move = "refresh", level = 45, order = nil, id = 287 },
            { move = "screech", level = 49, order = nil, id = 103 },
            { move = "powerWhip", level = 53, order = nil, id = 438 },
            { move = "wringOut", level = 57, order = nil, id = 378 },
        }
        -- END B2W2 LEARNSET
    },
    koffing = {
        name = "KOFFING", dex = 109, type = "poison", type2 = nil,
        baseHP = 40, baseAtk = 65, baseDef = 95, baseSpA = 60, baseSpD = 45, baseSpe = 35, baseExp = 68,
        moves = { "poisonGas", "tackle", "smog", "smokescreen", "assurance", "clearSmog", "sludge", "selfDestruct", "haze", "gyroBall", "sludgeBomb", "explosion", "destinyBond", "memento" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "poisonGas", level = 1, order = 1, id = 139 },
            { move = "tackle", level = 1, order = 2, id = 33 },
            { move = "smog", level = 4, order = nil, id = 123 },
            { move = "smokescreen", level = 7, order = nil, id = 108 },
            { move = "assurance", level = 12, order = nil, id = 372 },
            { move = "clearSmog", level = 15, order = nil, id = 499 },
            { move = "sludge", level = 18, order = nil, id = 124 },
            { move = "selfDestruct", level = 23, order = nil, id = 120 },
            { move = "haze", level = 26, order = nil, id = 114 },
            { move = "gyroBall", level = 29, order = nil, id = 360 },
            { move = "sludgeBomb", level = 34, order = nil, id = 188 },
            { move = "explosion", level = 37, order = nil, id = 153 },
            { move = "destinyBond", level = 40, order = nil, id = 194 },
            { move = "memento", level = 45, order = nil, id = 262 },
        }
        -- END B2W2 LEARNSET
    },
    weezing = {
        name = "WEEZING", dex = 110, type = "poison", type2 = nil,
        baseHP = 65, baseAtk = 90, baseDef = 120, baseSpA = 85, baseSpD = 70, baseSpe = 60, baseExp = 172,
        moves = { "poisonGas", "tackle", "smog", "smokescreen", "smog", "smokescreen", "assurance", "clearSmog", "sludge", "selfDestruct", "haze", "doubleHit", "sludgeBomb", "explosion", "destinyBond", "memento" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "poisonGas", level = 1, order = 1, id = 139 },
            { move = "tackle", level = 1, order = 2, id = 33 },
            { move = "smog", level = 1, order = 3, id = 123 },
            { move = "smokescreen", level = 1, order = 4, id = 108 },
            { move = "smog", level = 4, order = nil, id = 123 },
            { move = "smokescreen", level = 7, order = nil, id = 108 },
            { move = "assurance", level = 12, order = nil, id = 372 },
            { move = "clearSmog", level = 15, order = nil, id = 499 },
            { move = "sludge", level = 18, order = nil, id = 124 },
            { move = "selfDestruct", level = 23, order = nil, id = 120 },
            { move = "haze", level = 26, order = nil, id = 114 },
            { move = "doubleHit", level = 29, order = nil, id = 458 },
            { move = "sludgeBomb", level = 34, order = nil, id = 188 },
            { move = "explosion", level = 40, order = nil, id = 153 },
            { move = "destinyBond", level = 46, order = nil, id = 194 },
            { move = "memento", level = 54, order = nil, id = 262 },
        }
        -- END B2W2 LEARNSET
    },
    rhyhorn = {
        name = "RHYHORN", dex = 111, type = "ground", type2 = "rock",
        baseHP = 80, baseAtk = 85, baseDef = 95, baseSpA = 30, baseSpD = 30, baseSpe = 25, baseExp = 69,
        moves = { "hornAttack", "tailWhip", "stomp", "furyAttack", "scaryFace", "rockBlast", "bulldoze", "chipAway", "takeDown", "drillRun", "stoneEdge", "earthquake", "hornDrill", "megahorn" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "hornAttack", level = 1, order = 1, id = 30 },
            { move = "tailWhip", level = 1, order = 2, id = 39 },
            { move = "stomp", level = 8, order = nil, id = 23 },
            { move = "furyAttack", level = 12, order = nil, id = 31 },
            { move = "scaryFace", level = 19, order = nil, id = 184 },
            { move = "rockBlast", level = 23, order = nil, id = 350 },
            { move = "bulldoze", level = 30, order = nil, id = 523 },
            { move = "chipAway", level = 34, order = nil, id = 498 },
            { move = "takeDown", level = 41, order = nil, id = 36 },
            { move = "drillRun", level = 45, order = nil, id = 529 },
            { move = "stoneEdge", level = 52, order = nil, id = 444 },
            { move = "earthquake", level = 56, order = nil, id = 89 },
            { move = "hornDrill", level = 63, order = nil, id = 32 },
            { move = "megahorn", level = 67, order = nil, id = 224 },
        }
        -- END B2W2 LEARNSET
    },
    rhydon = {
        name = "RHYDON", dex = 112, type = "ground", type2 = "rock",
        baseHP = 105, baseAtk = 130, baseDef = 120, baseSpA = 45, baseSpD = 45, baseSpe = 40, baseExp = 170,
        moves = { "hornAttack", "tailWhip", "stomp", "furyAttack", "stomp", "furyAttack", "scaryFace", "rockBlast", "bulldoze", "chipAway", "takeDown", "hammerArm", "drillRun", "stoneEdge", "earthquake", "hornDrill", "megahorn" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "hornAttack", level = 1, order = 1, id = 30 },
            { move = "tailWhip", level = 1, order = 2, id = 39 },
            { move = "stomp", level = 1, order = 3, id = 23 },
            { move = "furyAttack", level = 1, order = 4, id = 31 },
            { move = "stomp", level = 9, order = nil, id = 23 },
            { move = "furyAttack", level = 12, order = nil, id = 31 },
            { move = "scaryFace", level = 19, order = nil, id = 184 },
            { move = "rockBlast", level = 23, order = nil, id = 350 },
            { move = "bulldoze", level = 30, order = nil, id = 523 },
            { move = "chipAway", level = 34, order = nil, id = 498 },
            { move = "takeDown", level = 41, order = nil, id = 36 },
            { move = "hammerArm", level = 42, order = nil, id = 359 },
            { move = "drillRun", level = 47, order = nil, id = 529 },
            { move = "stoneEdge", level = 56, order = nil, id = 444 },
            { move = "earthquake", level = 62, order = nil, id = 89 },
            { move = "hornDrill", level = 71, order = nil, id = 32 },
            { move = "megahorn", level = 77, order = nil, id = 224 },
        }
        -- END B2W2 LEARNSET
    },
    chansey = {
        name = "CHANSEY", dex = 113, type = "normal", type2 = nil,
        baseHP = 250, baseAtk = 5, baseDef = 5, baseSpA = 35, baseSpD = 105, baseSpe = 50, baseExp = 395,
        moves = { "defenseCurl", "pound", "growl", "tailWhip", "refresh", "doubleSlap", "softBoiled", "bestow", "minimize", "takeDown", "sing", "fling", "healPulse", "eggBomb", "lightScreen", "healingWish", "doubleEdge" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "defenseCurl", level = 1, order = 1, id = 111 },
            { move = "pound", level = 1, order = 2, id = 1 },
            { move = "growl", level = 1, order = 3, id = 45 },
            { move = "tailWhip", level = 5, order = nil, id = 39 },
            { move = "refresh", level = 9, order = nil, id = 287 },
            { move = "doubleSlap", level = 12, order = nil, id = 3 },
            { move = "softBoiled", level = 16, order = nil, id = 135 },
            { move = "bestow", level = 20, order = nil, id = 516 },
            { move = "minimize", level = 23, order = nil, id = 107 },
            { move = "takeDown", level = 27, order = nil, id = 36 },
            { move = "sing", level = 31, order = nil, id = 47 },
            { move = "fling", level = 34, order = nil, id = 374 },
            { move = "healPulse", level = 38, order = nil, id = 505 },
            { move = "eggBomb", level = 42, order = nil, id = 121 },
            { move = "lightScreen", level = 46, order = nil, id = 113 },
            { move = "healingWish", level = 50, order = nil, id = 361 },
            { move = "doubleEdge", level = 54, order = nil, id = 38 },
        }
        -- END B2W2 LEARNSET
    },
    tangela = {
        name = "TANGELA", dex = 114, type = "grass", type2 = nil,
        baseHP = 65, baseAtk = 55, baseDef = 115, baseSpA = 100, baseSpD = 40, baseSpe = 60, baseExp = 87,
        moves = { "ingrain", "constrict", "sleepPowder", "vineWhip", "absorb", "poisonPowder", "bind", "growth", "megaDrain", "knockOff", "stunSpore", "naturalGift", "gigaDrain", "ancientPower", "slam", "tickle", "wringOut", "powerWhip" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "ingrain", level = 1, order = 1, id = 275 },
            { move = "constrict", level = 1, order = 2, id = 132 },
            { move = "sleepPowder", level = 4, order = nil, id = 79 },
            { move = "vineWhip", level = 7, order = nil, id = 22 },
            { move = "absorb", level = 10, order = nil, id = 71 },
            { move = "poisonPowder", level = 14, order = nil, id = 77 },
            { move = "bind", level = 17, order = nil, id = 20 },
            { move = "growth", level = 20, order = nil, id = 74 },
            { move = "megaDrain", level = 23, order = nil, id = 72 },
            { move = "knockOff", level = 27, order = nil, id = 282 },
            { move = "stunSpore", level = 30, order = nil, id = 78 },
            { move = "naturalGift", level = 33, order = nil, id = 363 },
            { move = "gigaDrain", level = 36, order = nil, id = 202 },
            { move = "ancientPower", level = 40, order = nil, id = 246 },
            { move = "slam", level = 43, order = nil, id = 21 },
            { move = "tickle", level = 46, order = nil, id = 321 },
            { move = "wringOut", level = 49, order = nil, id = 378 },
            { move = "powerWhip", level = 53, order = nil, id = 438 },
        }
        -- END B2W2 LEARNSET
    },
    kangaskhan = {
        name = "KANGASKHAN", dex = 115, type = "normal", type2 = nil,
        baseHP = 105, baseAtk = 95, baseDef = 80, baseSpA = 40, baseSpD = 80, baseSpe = 90, baseExp = 172,
        moves = { "cometPunch", "leer", "fakeOut", "tailWhip", "bite", "doubleHit", "rage", "megaPunch", "chipAway", "dizzyPunch", "crunch", "endure", "outrage", "suckerPunch", "reversal" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "cometPunch", level = 1, order = 1, id = 4 },
            { move = "leer", level = 1, order = 2, id = 43 },
            { move = "fakeOut", level = 7, order = nil, id = 252 },
            { move = "tailWhip", level = 10, order = nil, id = 39 },
            { move = "bite", level = 13, order = nil, id = 44 },
            { move = "doubleHit", level = 19, order = nil, id = 458 },
            { move = "rage", level = 22, order = nil, id = 99 },
            { move = "megaPunch", level = 25, order = nil, id = 5 },
            { move = "chipAway", level = 31, order = nil, id = 498 },
            { move = "dizzyPunch", level = 34, order = nil, id = 146 },
            { move = "crunch", level = 37, order = nil, id = 242 },
            { move = "endure", level = 43, order = nil, id = 203 },
            { move = "outrage", level = 46, order = nil, id = 200 },
            { move = "suckerPunch", level = 49, order = nil, id = 389 },
            { move = "reversal", level = 55, order = nil, id = 179 },
        }
        -- END B2W2 LEARNSET
    },
    horsea = {
        name = "HORSEA", dex = 116, type = "water", type2 = nil,
        baseHP = 30, baseAtk = 40, baseDef = 70, baseSpA = 70, baseSpD = 25, baseSpe = 60, baseExp = 59,
        moves = { "bubble", "smokescreen", "leer", "waterGun", "focusEnergy", "bubbleBeam", "agility", "twister", "brine", "hydroPump", "dragonDance", "dragonPulse" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "bubble", level = 1, order = nil, id = 145 },
            { move = "smokescreen", level = 4, order = nil, id = 108 },
            { move = "leer", level = 8, order = nil, id = 43 },
            { move = "waterGun", level = 11, order = nil, id = 55 },
            { move = "focusEnergy", level = 14, order = nil, id = 116 },
            { move = "bubbleBeam", level = 18, order = nil, id = 61 },
            { move = "agility", level = 23, order = nil, id = 97 },
            { move = "twister", level = 26, order = nil, id = 239 },
            { move = "brine", level = 30, order = nil, id = 362 },
            { move = "hydroPump", level = 35, order = nil, id = 56 },
            { move = "dragonDance", level = 38, order = nil, id = 349 },
            { move = "dragonPulse", level = 42, order = nil, id = 406 },
        }
        -- END B2W2 LEARNSET
    },
    seadra = {
        name = "SEADRA", dex = 117, type = "water", type2 = nil,
        baseHP = 55, baseAtk = 65, baseDef = 95, baseSpA = 95, baseSpD = 45, baseSpe = 85, baseExp = 154,
        moves = { "bubble", "smokescreen", "leer", "waterGun", "smokescreen", "leer", "waterGun", "focusEnergy", "bubbleBeam", "agility", "twister", "brine", "hydroPump", "dragonDance", "dragonPulse" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "bubble", level = 1, order = 1, id = 145 },
            { move = "smokescreen", level = 1, order = 2, id = 108 },
            { move = "leer", level = 1, order = 3, id = 43 },
            { move = "waterGun", level = 1, order = 4, id = 55 },
            { move = "smokescreen", level = 4, order = nil, id = 108 },
            { move = "leer", level = 8, order = nil, id = 43 },
            { move = "waterGun", level = 11, order = nil, id = 55 },
            { move = "focusEnergy", level = 14, order = nil, id = 116 },
            { move = "bubbleBeam", level = 18, order = nil, id = 61 },
            { move = "agility", level = 23, order = nil, id = 97 },
            { move = "twister", level = 26, order = nil, id = 239 },
            { move = "brine", level = 30, order = nil, id = 362 },
            { move = "hydroPump", level = 40, order = nil, id = 56 },
            { move = "dragonDance", level = 48, order = nil, id = 349 },
            { move = "dragonPulse", level = 57, order = nil, id = 406 },
        }
        -- END B2W2 LEARNSET
    },
    goldeen = {
        name = "GOLDEEN", dex = 118, type = "water", type2 = nil,
        baseHP = 45, baseAtk = 67, baseDef = 60, baseSpA = 35, baseSpD = 50, baseSpe = 63, baseExp = 64,
        moves = { "peck", "tailWhip", "waterSport", "supersonic", "hornAttack", "waterPulse", "flail", "aquaRing", "furyAttack", "waterfall", "hornDrill", "agility", "soak", "megahorn" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "peck", level = 1, order = 1, id = 64 },
            { move = "tailWhip", level = 1, order = 2, id = 39 },
            { move = "waterSport", level = 1, order = 3, id = 346 },
            { move = "supersonic", level = 7, order = nil, id = 48 },
            { move = "hornAttack", level = 11, order = nil, id = 30 },
            { move = "waterPulse", level = 17, order = nil, id = 352 },
            { move = "flail", level = 21, order = nil, id = 175 },
            { move = "aquaRing", level = 27, order = nil, id = 392 },
            { move = "furyAttack", level = 31, order = nil, id = 31 },
            { move = "waterfall", level = 37, order = nil, id = 127 },
            { move = "hornDrill", level = 41, order = nil, id = 32 },
            { move = "agility", level = 47, order = nil, id = 97 },
            { move = "soak", level = 51, order = nil, id = 487 },
            { move = "megahorn", level = 57, order = nil, id = 224 },
        }
        -- END B2W2 LEARNSET
    },
    seaking = {
        name = "SEAKING", dex = 119, type = "water", type2 = nil,
        baseHP = 80, baseAtk = 92, baseDef = 65, baseSpA = 65, baseSpD = 80, baseSpe = 68, baseExp = 158,
        moves = { "poisonJab", "peck", "tailWhip", "waterSport", "supersonic", "supersonic", "hornAttack", "waterPulse", "flail", "aquaRing", "furyAttack", "waterfall", "hornDrill", "agility", "soak", "megahorn" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "poisonJab", level = 1, order = 1, id = 398 },
            { move = "peck", level = 1, order = 2, id = 64 },
            { move = "tailWhip", level = 1, order = 3, id = 39 },
            { move = "waterSport", level = 1, order = 4, id = 346 },
            { move = "supersonic", level = 1, order = 5, id = 48 },
            { move = "supersonic", level = 7, order = nil, id = 48 },
            { move = "hornAttack", level = 11, order = nil, id = 30 },
            { move = "waterPulse", level = 17, order = nil, id = 352 },
            { move = "flail", level = 21, order = nil, id = 175 },
            { move = "aquaRing", level = 27, order = nil, id = 392 },
            { move = "furyAttack", level = 31, order = nil, id = 31 },
            { move = "waterfall", level = 40, order = nil, id = 127 },
            { move = "hornDrill", level = 47, order = nil, id = 32 },
            { move = "agility", level = 56, order = nil, id = 97 },
            { move = "soak", level = 63, order = nil, id = 487 },
            { move = "megahorn", level = 72, order = nil, id = 224 },
        }
        -- END B2W2 LEARNSET
    },
    staryu = {
        name = "STARYU", dex = 120, type = "water", type2 = nil,
        baseHP = 30, baseAtk = 45, baseDef = 55, baseSpA = 70, baseSpD = 55, baseSpe = 85, baseExp = 68,
        moves = { "tackle", "harden", "waterGun", "rapidSpin", "recover", "camouflage", "swift", "bubbleBeam", "minimize", "gyroBall", "lightScreen", "brine", "reflectType", "powerGem", "cosmicPower", "hydroPump" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "tackle", level = 1, order = 1, id = 33 },
            { move = "harden", level = 1, order = 2, id = 106 },
            { move = "waterGun", level = 6, order = nil, id = 55 },
            { move = "rapidSpin", level = 10, order = nil, id = 229 },
            { move = "recover", level = 12, order = nil, id = 105 },
            { move = "camouflage", level = 15, order = nil, id = 293 },
            { move = "swift", level = 18, order = nil, id = 129 },
            { move = "bubbleBeam", level = 22, order = nil, id = 61 },
            { move = "minimize", level = 25, order = nil, id = 107 },
            { move = "gyroBall", level = 30, order = nil, id = 360 },
            { move = "lightScreen", level = 33, order = nil, id = 113 },
            { move = "brine", level = 36, order = nil, id = 362 },
            { move = "reflectType", level = 40, order = nil, id = 513 },
            { move = "powerGem", level = 43, order = nil, id = 408 },
            { move = "cosmicPower", level = 48, order = nil, id = 322 },
            { move = "hydroPump", level = 52, order = nil, id = 56 },
        }
        -- END B2W2 LEARNSET
    },
    starmie = {
        name = "STARMIE", dex = 121, type = "water", type2 = "psychic",
        baseHP = 60, baseAtk = 75, baseDef = 85, baseSpA = 100, baseSpD = 85, baseSpe = 115, baseExp = 182,
        moves = { "waterGun", "rapidSpin", "recover", "swift", "confuseRay" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "waterGun", level = 1, order = 1, id = 55 },
            { move = "rapidSpin", level = 1, order = 2, id = 229 },
            { move = "recover", level = 1, order = 3, id = 105 },
            { move = "swift", level = 1, order = 4, id = 129 },
            { move = "confuseRay", level = 22, order = nil, id = 109 },
        }
        -- END B2W2 LEARNSET
    },
    mr = {
        name = "MR", dex = 122, type = "psychic", type2 = nil,
        baseHP = 40, baseAtk = 45, baseDef = 65, baseSpA = 100, baseSpD = 120, baseSpe = 90, baseExp = 161,
        moves = { "magicalLeaf", "quickGuard", "wideGuard", "powerSwap", "guardSwap", "barrier", "confusion", "copycat", "meditate", "doubleSlap", "mimic", "psywave", "encore", "lightScreen", "reflect", "psybeam", "substitute", "recycle", "trick", "psychic", "rolePlay", "batonPass", "safeguard" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "magicalLeaf", level = 1, order = 1, id = 345 },
            { move = "quickGuard", level = 1, order = 2, id = 501 },
            { move = "wideGuard", level = 1, order = 3, id = 469 },
            { move = "powerSwap", level = 1, order = 4, id = 384 },
            { move = "guardSwap", level = 1, order = 5, id = 385 },
            { move = "barrier", level = 1, order = 6, id = 112 },
            { move = "confusion", level = 1, order = 7, id = 93 },
            { move = "copycat", level = 4, order = nil, id = 383 },
            { move = "meditate", level = 8, order = nil, id = 96 },
            { move = "doubleSlap", level = 11, order = nil, id = 3 },
            { move = "mimic", level = 15, order = 1, id = 102 },
            { move = "psywave", level = 15, order = 2, id = 149 },
            { move = "encore", level = 18, order = nil, id = 227 },
            { move = "lightScreen", level = 22, order = 1, id = 113 },
            { move = "reflect", level = 22, order = 2, id = 115 },
            { move = "psybeam", level = 25, order = nil, id = 60 },
            { move = "substitute", level = 29, order = nil, id = 164 },
            { move = "recycle", level = 32, order = nil, id = 278 },
            { move = "trick", level = 36, order = nil, id = 271 },
            { move = "psychic", level = 39, order = nil, id = 94 },
            { move = "rolePlay", level = 43, order = nil, id = 272 },
            { move = "batonPass", level = 46, order = nil, id = 226 },
            { move = "safeguard", level = 50, order = nil, id = 219 },
        }
        -- END B2W2 LEARNSET
    },
    scyther = {
        name = "SCYTHER", dex = 123, type = "bug", type2 = "flying",
        baseHP = 70, baseAtk = 110, baseDef = 80, baseSpA = 55, baseSpD = 80, baseSpe = 105, baseExp = 100,
        moves = { "vacuumWave", "quickAttack", "leer", "focusEnergy", "pursuit", "falseSwipe", "agility", "wingAttack", "furyCutter", "slash", "razorWind", "doubleTeam", "xScissor", "nightSlash", "doubleHit", "airSlash", "swordsDance", "feint" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "vacuumWave", level = 1, order = 1, id = 410 },
            { move = "quickAttack", level = 1, order = 2, id = 98 },
            { move = "leer", level = 1, order = 3, id = 43 },
            { move = "focusEnergy", level = 5, order = nil, id = 116 },
            { move = "pursuit", level = 9, order = nil, id = 228 },
            { move = "falseSwipe", level = 13, order = nil, id = 206 },
            { move = "agility", level = 17, order = nil, id = 97 },
            { move = "wingAttack", level = 21, order = nil, id = 17 },
            { move = "furyCutter", level = 25, order = nil, id = 210 },
            { move = "slash", level = 29, order = nil, id = 163 },
            { move = "razorWind", level = 33, order = nil, id = 13 },
            { move = "doubleTeam", level = 37, order = nil, id = 104 },
            { move = "xScissor", level = 41, order = nil, id = 404 },
            { move = "nightSlash", level = 45, order = nil, id = 400 },
            { move = "doubleHit", level = 49, order = nil, id = 458 },
            { move = "airSlash", level = 53, order = nil, id = 403 },
            { move = "swordsDance", level = 57, order = nil, id = 14 },
            { move = "feint", level = 61, order = nil, id = 364 },
        }
        -- END B2W2 LEARNSET
    },
    jynx = {
        name = "JYNX", dex = 124, type = "ice", type2 = "psychic",
        baseHP = 65, baseAtk = 50, baseDef = 35, baseSpA = 115, baseSpD = 95, baseSpe = 95, baseExp = 159,
        moves = { "pound", "lick", "lovelyKiss", "powderSnow", "lick", "lovelyKiss", "powderSnow", "doubleSlap", "icePunch", "heartStamp", "meanLook", "fakeTears", "wakeUpSlap", "avalanche", "bodySlam", "wringOut", "perishSong", "blizzard" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "pound", level = 1, order = 1, id = 1 },
            { move = "lick", level = 1, order = 2, id = 122 },
            { move = "lovelyKiss", level = 1, order = 3, id = 142 },
            { move = "powderSnow", level = 1, order = 4, id = 181 },
            { move = "lick", level = 5, order = nil, id = 122 },
            { move = "lovelyKiss", level = 8, order = nil, id = 142 },
            { move = "powderSnow", level = 11, order = nil, id = 181 },
            { move = "doubleSlap", level = 15, order = nil, id = 3 },
            { move = "icePunch", level = 18, order = nil, id = 8 },
            { move = "heartStamp", level = 21, order = nil, id = 531 },
            { move = "meanLook", level = 25, order = nil, id = 212 },
            { move = "fakeTears", level = 28, order = nil, id = 313 },
            { move = "wakeUpSlap", level = 33, order = nil, id = 358 },
            { move = "avalanche", level = 39, order = nil, id = 419 },
            { move = "bodySlam", level = 44, order = nil, id = 34 },
            { move = "wringOut", level = 49, order = nil, id = 378 },
            { move = "perishSong", level = 55, order = nil, id = 195 },
            { move = "blizzard", level = 60, order = nil, id = 59 },
        }
        -- END B2W2 LEARNSET
    },
    electabuzz = {
        name = "ELECTABUZZ", dex = 125, type = "electric", type2 = nil,
        baseHP = 65, baseAtk = 83, baseDef = 57, baseSpA = 95, baseSpD = 85, baseSpe = 105, baseExp = 172,
        moves = { "quickAttack", "leer", "thunderShock", "thunderShock", "lowKick", "swift", "shockWave", "thunderWave", "electroBall", "lightScreen", "thunderPunch", "discharge", "screech", "thunderbolt", "thunder" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "quickAttack", level = 1, order = 1, id = 98 },
            { move = "leer", level = 1, order = 2, id = 43 },
            { move = "thunderShock", level = 1, order = 3, id = 84 },
            { move = "thunderShock", level = 5, order = nil, id = 84 },
            { move = "lowKick", level = 8, order = nil, id = 67 },
            { move = "swift", level = 12, order = nil, id = 129 },
            { move = "shockWave", level = 15, order = nil, id = 351 },
            { move = "thunderWave", level = 19, order = nil, id = 86 },
            { move = "electroBall", level = 22, order = nil, id = 486 },
            { move = "lightScreen", level = 26, order = nil, id = 113 },
            { move = "thunderPunch", level = 29, order = nil, id = 9 },
            { move = "discharge", level = 36, order = nil, id = 435 },
            { move = "screech", level = 42, order = nil, id = 103 },
            { move = "thunderbolt", level = 49, order = nil, id = 85 },
            { move = "thunder", level = 55, order = nil, id = 87 },
        }
        -- END B2W2 LEARNSET
    },
    magmar = {
        name = "MAGMAR", dex = 126, type = "fire", type2 = nil,
        baseHP = 65, baseAtk = 95, baseDef = 57, baseSpA = 100, baseSpD = 85, baseSpe = 93, baseExp = 173,
        moves = { "smog", "leer", "ember", "ember", "smokescreen", "feintAttack", "fireSpin", "clearSmog", "flameBurst", "confuseRay", "firePunch", "lavaPlume", "sunnyDay", "flamethrower", "fireBlast" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "smog", level = 1, order = 1, id = 123 },
            { move = "leer", level = 1, order = 2, id = 43 },
            { move = "ember", level = 1, order = 3, id = 52 },
            { move = "ember", level = 5, order = nil, id = 52 },
            { move = "smokescreen", level = 8, order = nil, id = 108 },
            { move = "feintAttack", level = 12, order = nil, id = 185 },
            { move = "fireSpin", level = 15, order = nil, id = 83 },
            { move = "clearSmog", level = 19, order = nil, id = 499 },
            { move = "flameBurst", level = 22, order = nil, id = 481 },
            { move = "confuseRay", level = 26, order = nil, id = 109 },
            { move = "firePunch", level = 29, order = nil, id = 7 },
            { move = "lavaPlume", level = 36, order = nil, id = 436 },
            { move = "sunnyDay", level = 42, order = nil, id = 241 },
            { move = "flamethrower", level = 49, order = nil, id = 53 },
            { move = "fireBlast", level = 55, order = nil, id = 126 },
        }
        -- END B2W2 LEARNSET
    },
    pinsir = {
        name = "PINSIR", dex = 127, type = "bug", type2 = nil,
        baseHP = 65, baseAtk = 125, baseDef = 100, baseSpA = 55, baseSpD = 70, baseSpe = 85, baseExp = 175,
        moves = { "viceGrip", "focusEnergy", "bind", "seismicToss", "harden", "revenge", "brickBreak", "vitalThrow", "submission", "xScissor", "stormThrow", "thrash", "swordsDance", "superpower", "guillotine" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "viceGrip", level = 1, order = 1, id = 11 },
            { move = "focusEnergy", level = 1, order = 2, id = 116 },
            { move = "bind", level = 4, order = nil, id = 20 },
            { move = "seismicToss", level = 8, order = nil, id = 69 },
            { move = "harden", level = 11, order = nil, id = 106 },
            { move = "revenge", level = 15, order = nil, id = 279 },
            { move = "brickBreak", level = 18, order = nil, id = 280 },
            { move = "vitalThrow", level = 22, order = nil, id = 233 },
            { move = "submission", level = 26, order = nil, id = 66 },
            { move = "xScissor", level = 29, order = nil, id = 404 },
            { move = "stormThrow", level = 33, order = nil, id = 480 },
            { move = "thrash", level = 36, order = nil, id = 37 },
            { move = "swordsDance", level = 40, order = nil, id = 14 },
            { move = "superpower", level = 43, order = nil, id = 276 },
            { move = "guillotine", level = 47, order = nil, id = 12 },
        }
        -- END B2W2 LEARNSET
    },
    tauros = {
        name = "TAUROS", dex = 128, type = "normal", type2 = nil,
        baseHP = 75, baseAtk = 100, baseDef = 95, baseSpA = 40, baseSpD = 70, baseSpe = 110, baseExp = 172,
        moves = { "tackle", "tailWhip", "rage", "hornAttack", "scaryFace", "pursuit", "rest", "payback", "workUp", "zenHeadbutt", "takeDown", "swagger", "thrash", "gigaImpact" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "tackle", level = 1, order = nil, id = 33 },
            { move = "tailWhip", level = 3, order = nil, id = 39 },
            { move = "rage", level = 5, order = nil, id = 99 },
            { move = "hornAttack", level = 8, order = nil, id = 30 },
            { move = "scaryFace", level = 11, order = nil, id = 184 },
            { move = "pursuit", level = 15, order = nil, id = 228 },
            { move = "rest", level = 19, order = nil, id = 156 },
            { move = "payback", level = 24, order = nil, id = 371 },
            { move = "workUp", level = 29, order = nil, id = 526 },
            { move = "zenHeadbutt", level = 35, order = nil, id = 428 },
            { move = "takeDown", level = 41, order = nil, id = 36 },
            { move = "swagger", level = 48, order = nil, id = 207 },
            { move = "thrash", level = 55, order = nil, id = 37 },
            { move = "gigaImpact", level = 63, order = nil, id = 416 },
        }
        -- END B2W2 LEARNSET
    },
    magikarp = {
        name = "MAGIKARP", dex = 129, type = "water", type2 = nil,
        baseHP = 20, baseAtk = 10, baseDef = 55, baseSpA = 15, baseSpD = 20, baseSpe = 80, baseExp = 40,
        moves = { "splash", "tackle", "flail" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "splash", level = 1, order = nil, id = 150 },
            { move = "tackle", level = 15, order = nil, id = 33 },
            { move = "flail", level = 30, order = nil, id = 175 },
        }
        -- END B2W2 LEARNSET
    },
    gyarados = {
        name = "GYARADOS", dex = 130, type = "water", type2 = "flying",
        baseHP = 95, baseAtk = 125, baseDef = 79, baseSpA = 60, baseSpD = 100, baseSpe = 81, baseExp = 189,
        moves = { "thrash", "bite", "dragonRage", "leer", "twister", "iceFang", "aquaTail", "rainDance", "hydroPump", "dragonDance", "hyperBeam" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "thrash", level = 1, order = nil, id = 37 },
            { move = "bite", level = 20, order = nil, id = 44 },
            { move = "dragonRage", level = 23, order = nil, id = 82 },
            { move = "leer", level = 26, order = nil, id = 43 },
            { move = "twister", level = 29, order = nil, id = 239 },
            { move = "iceFang", level = 32, order = nil, id = 423 },
            { move = "aquaTail", level = 35, order = nil, id = 401 },
            { move = "rainDance", level = 38, order = nil, id = 240 },
            { move = "hydroPump", level = 41, order = nil, id = 56 },
            { move = "dragonDance", level = 44, order = nil, id = 349 },
            { move = "hyperBeam", level = 47, order = nil, id = 63 },
        }
        -- END B2W2 LEARNSET
    },
    lapras = {
        name = "LAPRAS", dex = 131, type = "water", type2 = "ice",
        baseHP = 130, baseAtk = 85, baseDef = 80, baseSpA = 85, baseSpD = 95, baseSpe = 60, baseExp = 187,
        moves = { "sing", "growl", "waterGun", "mist", "confuseRay", "iceShard", "waterPulse", "bodySlam", "rainDance", "perishSong", "iceBeam", "brine", "safeguard", "hydroPump", "sheerCold" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "sing", level = 1, order = 1, id = 47 },
            { move = "growl", level = 1, order = 2, id = 45 },
            { move = "waterGun", level = 1, order = 3, id = 55 },
            { move = "mist", level = 4, order = nil, id = 54 },
            { move = "confuseRay", level = 7, order = nil, id = 109 },
            { move = "iceShard", level = 10, order = nil, id = 420 },
            { move = "waterPulse", level = 14, order = nil, id = 352 },
            { move = "bodySlam", level = 18, order = nil, id = 34 },
            { move = "rainDance", level = 22, order = nil, id = 240 },
            { move = "perishSong", level = 27, order = nil, id = 195 },
            { move = "iceBeam", level = 32, order = nil, id = 58 },
            { move = "brine", level = 37, order = nil, id = 362 },
            { move = "safeguard", level = 43, order = nil, id = 219 },
            { move = "hydroPump", level = 49, order = nil, id = 56 },
            { move = "sheerCold", level = 55, order = nil, id = 329 },
        }
        -- END B2W2 LEARNSET
    },
    ditto = {
        name = "DITTO", dex = 132, type = "normal", type2 = nil,
        baseHP = 48, baseAtk = 48, baseDef = 48, baseSpA = 48, baseSpD = 48, baseSpe = 48, baseExp = 101,
        moves = { "transform" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "transform", level = 1, order = nil, id = 144 },
        }
        -- END B2W2 LEARNSET
    },
    eevee = {
        name = "EEVEE", dex = 133, type = "normal", type2 = nil,
        baseHP = 55, baseAtk = 55, baseDef = 50, baseSpA = 45, baseSpD = 65, baseSpe = 55, baseExp = 65,
        moves = { "helpingHand", "tackle", "tailWhip", "sandAttack", "growl", "quickAttack", "bite", "covet", "takeDown", "charm", "batonPass", "doubleEdge", "lastResort", "trumpCard" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "helpingHand", level = 1, order = 1, id = 270 },
            { move = "tackle", level = 1, order = 2, id = 33 },
            { move = "tailWhip", level = 1, order = 3, id = 39 },
            { move = "sandAttack", level = 5, order = nil, id = 28 },
            { move = "growl", level = 9, order = nil, id = 45 },
            { move = "quickAttack", level = 13, order = nil, id = 98 },
            { move = "bite", level = 17, order = nil, id = 44 },
            { move = "covet", level = 21, order = nil, id = 343 },
            { move = "takeDown", level = 25, order = nil, id = 36 },
            { move = "charm", level = 29, order = nil, id = 204 },
            { move = "batonPass", level = 33, order = nil, id = 226 },
            { move = "doubleEdge", level = 37, order = nil, id = 38 },
            { move = "lastResort", level = 41, order = nil, id = 387 },
            { move = "trumpCard", level = 45, order = nil, id = 376 },
        }
        -- END B2W2 LEARNSET
    },
    vaporeon = {
        name = "VAPOREON", dex = 134, type = "water", type2 = nil,
        baseHP = 130, baseAtk = 65, baseDef = 60, baseSpA = 110, baseSpD = 95, baseSpe = 65, baseExp = 184,
        moves = { "helpingHand", "tackle", "tailWhip", "sandAttack", "waterGun", "quickAttack", "waterPulse", "auroraBeam", "aquaRing", "acidArmor", "haze", "muddyWater", "lastResort", "hydroPump" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "helpingHand", level = 1, order = 1, id = 270 },
            { move = "tackle", level = 1, order = 2, id = 33 },
            { move = "tailWhip", level = 1, order = 3, id = 39 },
            { move = "sandAttack", level = 5, order = nil, id = 28 },
            { move = "waterGun", level = 9, order = nil, id = 55 },
            { move = "quickAttack", level = 13, order = nil, id = 98 },
            { move = "waterPulse", level = 17, order = nil, id = 352 },
            { move = "auroraBeam", level = 21, order = nil, id = 62 },
            { move = "aquaRing", level = 25, order = nil, id = 392 },
            { move = "acidArmor", level = 29, order = nil, id = 151 },
            { move = "haze", level = 33, order = nil, id = 114 },
            { move = "muddyWater", level = 37, order = nil, id = 330 },
            { move = "lastResort", level = 41, order = nil, id = 387 },
            { move = "hydroPump", level = 45, order = nil, id = 56 },
        }
        -- END B2W2 LEARNSET
    },
    jolteon = {
        name = "JOLTEON", dex = 135, type = "electric", type2 = nil,
        baseHP = 65, baseAtk = 65, baseDef = 60, baseSpA = 110, baseSpD = 95, baseSpe = 130, baseExp = 184,
        moves = { "helpingHand", "tackle", "tailWhip", "sandAttack", "thunderShock", "quickAttack", "doubleKick", "thunderFang", "pinMissile", "agility", "thunderWave", "discharge", "lastResort", "thunder" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "helpingHand", level = 1, order = 1, id = 270 },
            { move = "tackle", level = 1, order = 2, id = 33 },
            { move = "tailWhip", level = 1, order = 3, id = 39 },
            { move = "sandAttack", level = 5, order = nil, id = 28 },
            { move = "thunderShock", level = 9, order = nil, id = 84 },
            { move = "quickAttack", level = 13, order = nil, id = 98 },
            { move = "doubleKick", level = 17, order = nil, id = 24 },
            { move = "thunderFang", level = 21, order = nil, id = 422 },
            { move = "pinMissile", level = 25, order = nil, id = 42 },
            { move = "agility", level = 29, order = nil, id = 97 },
            { move = "thunderWave", level = 33, order = nil, id = 86 },
            { move = "discharge", level = 37, order = nil, id = 435 },
            { move = "lastResort", level = 41, order = nil, id = 387 },
            { move = "thunder", level = 45, order = nil, id = 87 },
        }
        -- END B2W2 LEARNSET
    },
    flareon = {
        name = "FLAREON", dex = 136, type = "fire", type2 = nil,
        baseHP = 65, baseAtk = 130, baseDef = 60, baseSpA = 95, baseSpD = 110, baseSpe = 65, baseExp = 184,
        moves = { "helpingHand", "tackle", "tailWhip", "sandAttack", "ember", "quickAttack", "bite", "fireFang", "fireSpin", "scaryFace", "smog", "lavaPlume", "lastResort", "fireBlast" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "helpingHand", level = 1, order = 1, id = 270 },
            { move = "tackle", level = 1, order = 2, id = 33 },
            { move = "tailWhip", level = 1, order = 3, id = 39 },
            { move = "sandAttack", level = 5, order = nil, id = 28 },
            { move = "ember", level = 9, order = nil, id = 52 },
            { move = "quickAttack", level = 13, order = nil, id = 98 },
            { move = "bite", level = 17, order = nil, id = 44 },
            { move = "fireFang", level = 21, order = nil, id = 424 },
            { move = "fireSpin", level = 25, order = nil, id = 83 },
            { move = "scaryFace", level = 29, order = nil, id = 184 },
            { move = "smog", level = 33, order = nil, id = 123 },
            { move = "lavaPlume", level = 37, order = nil, id = 436 },
            { move = "lastResort", level = 41, order = nil, id = 387 },
            { move = "fireBlast", level = 45, order = nil, id = 126 },
        }
        -- END B2W2 LEARNSET
    },
    porygon = {
        name = "PORYGON", dex = 137, type = "normal", type2 = nil,
        baseHP = 65, baseAtk = 60, baseDef = 70, baseSpA = 85, baseSpD = 75, baseSpe = 40, baseExp = 79,
        moves = { "conversion2", "tackle", "conversion", "sharpen", "psybeam", "agility", "recover", "magnetRise", "signalBeam", "recycle", "discharge", "lockOn", "triAttack", "magicCoat", "zapCannon" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "conversion2", level = 1, order = 1, id = 176 },
            { move = "tackle", level = 1, order = 2, id = 33 },
            { move = "conversion", level = 1, order = 3, id = 160 },
            { move = "sharpen", level = 1, order = 4, id = 159 },
            { move = "psybeam", level = 7, order = nil, id = 60 },
            { move = "agility", level = 12, order = nil, id = 97 },
            { move = "recover", level = 18, order = nil, id = 105 },
            { move = "magnetRise", level = 23, order = nil, id = 393 },
            { move = "signalBeam", level = 29, order = nil, id = 324 },
            { move = "recycle", level = 34, order = nil, id = 278 },
            { move = "discharge", level = 40, order = nil, id = 435 },
            { move = "lockOn", level = 45, order = nil, id = 199 },
            { move = "triAttack", level = 51, order = nil, id = 161 },
            { move = "magicCoat", level = 56, order = nil, id = 277 },
            { move = "zapCannon", level = 62, order = nil, id = 192 },
        }
        -- END B2W2 LEARNSET
    },
    omanyte = {
        name = "OMANYTE", dex = 138, type = "rock", type2 = "water",
        baseHP = 35, baseAtk = 40, baseDef = 100, baseSpA = 90, baseSpD = 55, baseSpe = 35, baseExp = 71,
        moves = { "constrict", "withdraw", "bite", "waterGun", "rollout", "leer", "mudShot", "brine", "protect", "ancientPower", "tickle", "rockBlast", "shellSmash", "hydroPump" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "constrict", level = 1, order = 1, id = 132 },
            { move = "withdraw", level = 1, order = 2, id = 110 },
            { move = "bite", level = 7, order = nil, id = 44 },
            { move = "waterGun", level = 10, order = nil, id = 55 },
            { move = "rollout", level = 16, order = nil, id = 205 },
            { move = "leer", level = 19, order = nil, id = 43 },
            { move = "mudShot", level = 25, order = nil, id = 341 },
            { move = "brine", level = 28, order = nil, id = 362 },
            { move = "protect", level = 34, order = nil, id = 182 },
            { move = "ancientPower", level = 37, order = nil, id = 246 },
            { move = "tickle", level = 43, order = nil, id = 321 },
            { move = "rockBlast", level = 46, order = nil, id = 350 },
            { move = "shellSmash", level = 52, order = nil, id = 504 },
            { move = "hydroPump", level = 55, order = nil, id = 56 },
        }
        -- END B2W2 LEARNSET
    },
    omastar = {
        name = "OMASTAR", dex = 139, type = "rock", type2 = "water",
        baseHP = 70, baseAtk = 60, baseDef = 125, baseSpA = 115, baseSpD = 70, baseSpe = 55, baseExp = 173,
        moves = { "constrict", "withdraw", "bite", "bite", "waterGun", "rollout", "leer", "mudShot", "brine", "protect", "ancientPower", "spikeCannon", "tickle", "rockBlast", "shellSmash", "hydroPump" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "constrict", level = 1, order = 1, id = 132 },
            { move = "withdraw", level = 1, order = 2, id = 110 },
            { move = "bite", level = 1, order = 3, id = 44 },
            { move = "bite", level = 7, order = nil, id = 44 },
            { move = "waterGun", level = 10, order = nil, id = 55 },
            { move = "rollout", level = 16, order = nil, id = 205 },
            { move = "leer", level = 19, order = nil, id = 43 },
            { move = "mudShot", level = 25, order = nil, id = 341 },
            { move = "brine", level = 28, order = nil, id = 362 },
            { move = "protect", level = 34, order = nil, id = 182 },
            { move = "ancientPower", level = 37, order = nil, id = 246 },
            { move = "spikeCannon", level = 40, order = nil, id = 131 },
            { move = "tickle", level = 48, order = nil, id = 321 },
            { move = "rockBlast", level = 56, order = nil, id = 350 },
            { move = "shellSmash", level = 67, order = nil, id = 504 },
            { move = "hydroPump", level = 75, order = nil, id = 56 },
        }
        -- END B2W2 LEARNSET
    },
    kabuto = {
        name = "KABUTO", dex = 140, type = "rock", type2 = "water",
        baseHP = 30, baseAtk = 80, baseDef = 90, baseSpA = 55, baseSpD = 45, baseSpe = 55, baseExp = 71,
        moves = { "scratch", "harden", "absorb", "leer", "mudShot", "sandAttack", "endure", "aquaJet", "megaDrain", "metalSound", "ancientPower", "wringOut" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "scratch", level = 1, order = 1, id = 10 },
            { move = "harden", level = 1, order = 2, id = 106 },
            { move = "absorb", level = 6, order = nil, id = 71 },
            { move = "leer", level = 11, order = nil, id = 43 },
            { move = "mudShot", level = 16, order = nil, id = 341 },
            { move = "sandAttack", level = 21, order = nil, id = 28 },
            { move = "endure", level = 26, order = nil, id = 203 },
            { move = "aquaJet", level = 31, order = nil, id = 453 },
            { move = "megaDrain", level = 36, order = nil, id = 72 },
            { move = "metalSound", level = 41, order = nil, id = 319 },
            { move = "ancientPower", level = 46, order = nil, id = 246 },
            { move = "wringOut", level = 51, order = nil, id = 378 },
        }
        -- END B2W2 LEARNSET
    },
    kabutops = {
        name = "KABUTOPS", dex = 141, type = "rock", type2 = "water",
        baseHP = 60, baseAtk = 115, baseDef = 105, baseSpA = 65, baseSpD = 70, baseSpe = 80, baseExp = 173,
        moves = { "feint", "scratch", "harden", "absorb", "leer", "absorb", "leer", "mudShot", "sandAttack", "endure", "aquaJet", "megaDrain", "slash", "metalSound", "ancientPower", "wringOut", "nightSlash" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "feint", level = 1, order = 1, id = 364 },
            { move = "scratch", level = 1, order = 2, id = 10 },
            { move = "harden", level = 1, order = 3, id = 106 },
            { move = "absorb", level = 1, order = 4, id = 71 },
            { move = "leer", level = 1, order = 5, id = 43 },
            { move = "absorb", level = 6, order = nil, id = 71 },
            { move = "leer", level = 11, order = nil, id = 43 },
            { move = "mudShot", level = 16, order = nil, id = 341 },
            { move = "sandAttack", level = 21, order = nil, id = 28 },
            { move = "endure", level = 26, order = nil, id = 203 },
            { move = "aquaJet", level = 31, order = nil, id = 453 },
            { move = "megaDrain", level = 36, order = nil, id = 72 },
            { move = "slash", level = 40, order = nil, id = 163 },
            { move = "metalSound", level = 45, order = nil, id = 319 },
            { move = "ancientPower", level = 54, order = nil, id = 246 },
            { move = "wringOut", level = 63, order = nil, id = 378 },
            { move = "nightSlash", level = 72, order = nil, id = 400 },
        }
        -- END B2W2 LEARNSET
    },
    aerodactyl = {
        name = "AERODACTYL", dex = 142, type = "rock", type2 = "flying",
        baseHP = 80, baseAtk = 105, baseDef = 65, baseSpA = 60, baseSpD = 75, baseSpe = 130, baseExp = 180,
        moves = { "iceFang", "fireFang", "thunderFang", "wingAttack", "supersonic", "bite", "scaryFace", "roar", "agility", "ancientPower", "crunch", "takeDown", "skyDrop", "ironHead", "hyperBeam", "rockSlide", "gigaImpact" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "iceFang", level = 1, order = 1, id = 423 },
            { move = "fireFang", level = 1, order = 2, id = 424 },
            { move = "thunderFang", level = 1, order = 3, id = 422 },
            { move = "wingAttack", level = 1, order = 4, id = 17 },
            { move = "supersonic", level = 1, order = 5, id = 48 },
            { move = "bite", level = 1, order = 6, id = 44 },
            { move = "scaryFace", level = 1, order = 7, id = 184 },
            { move = "roar", level = 9, order = nil, id = 46 },
            { move = "agility", level = 17, order = nil, id = 97 },
            { move = "ancientPower", level = 25, order = nil, id = 246 },
            { move = "crunch", level = 33, order = nil, id = 242 },
            { move = "takeDown", level = 41, order = nil, id = 36 },
            { move = "skyDrop", level = 49, order = nil, id = 507 },
            { move = "ironHead", level = 57, order = nil, id = 442 },
            { move = "hyperBeam", level = 65, order = nil, id = 63 },
            { move = "rockSlide", level = 73, order = nil, id = 157 },
            { move = "gigaImpact", level = 81, order = nil, id = 416 },
        }
        -- END B2W2 LEARNSET
    },
    snorlax = {
        name = "SNORLAX", dex = 143, type = "normal", type2 = nil,
        baseHP = 160, baseAtk = 110, baseDef = 65, baseSpA = 65, baseSpD = 110, baseSpe = 30, baseExp = 189,
        moves = { "tackle", "defenseCurl", "amnesia", "lick", "bellyDrum", "yawn", "chipAway", "rest", "snore", "sleepTalk", "bodySlam", "block", "rollout", "crunch", "heavySlam", "gigaImpact" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "tackle", level = 1, order = nil, id = 33 },
            { move = "defenseCurl", level = 4, order = nil, id = 111 },
            { move = "amnesia", level = 9, order = nil, id = 133 },
            { move = "lick", level = 12, order = nil, id = 122 },
            { move = "bellyDrum", level = 17, order = nil, id = 187 },
            { move = "yawn", level = 20, order = nil, id = 281 },
            { move = "chipAway", level = 25, order = nil, id = 498 },
            { move = "rest", level = 28, order = 1, id = 156 },
            { move = "snore", level = 28, order = 2, id = 173 },
            { move = "sleepTalk", level = 33, order = nil, id = 214 },
            { move = "bodySlam", level = 36, order = nil, id = 34 },
            { move = "block", level = 41, order = nil, id = 335 },
            { move = "rollout", level = 44, order = nil, id = 205 },
            { move = "crunch", level = 49, order = nil, id = 242 },
            { move = "heavySlam", level = 52, order = nil, id = 484 },
            { move = "gigaImpact", level = 57, order = nil, id = 416 },
        }
        -- END B2W2 LEARNSET
    },
    articuno = {
        name = "ARTICUNO", dex = 144, type = "ice", type2 = "flying",
        baseHP = 90, baseAtk = 85, baseDef = 100, baseSpA = 95, baseSpD = 125, baseSpe = 85, baseExp = 261,
        moves = { "gust", "powderSnow", "mist", "iceShard", "mindReader", "ancientPower", "agility", "iceBeam", "reflect", "roost", "tailwind", "blizzard", "sheerCold", "hail", "hurricane" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "gust", level = 1, order = 1, id = 16 },
            { move = "powderSnow", level = 1, order = 2, id = 181 },
            { move = "mist", level = 8, order = nil, id = 54 },
            { move = "iceShard", level = 15, order = nil, id = 420 },
            { move = "mindReader", level = 22, order = nil, id = 170 },
            { move = "ancientPower", level = 29, order = nil, id = 246 },
            { move = "agility", level = 36, order = nil, id = 97 },
            { move = "iceBeam", level = 43, order = nil, id = 58 },
            { move = "reflect", level = 50, order = nil, id = 115 },
            { move = "roost", level = 57, order = nil, id = 355 },
            { move = "tailwind", level = 64, order = nil, id = 366 },
            { move = "blizzard", level = 71, order = nil, id = 59 },
            { move = "sheerCold", level = 78, order = nil, id = 329 },
            { move = "hail", level = 85, order = nil, id = 258 },
            { move = "hurricane", level = 92, order = nil, id = 542 },
        }
        -- END B2W2 LEARNSET
    },
    zapdos = {
        name = "ZAPDOS", dex = 145, type = "electric", type2 = "flying",
        baseHP = 90, baseAtk = 90, baseDef = 85, baseSpA = 125, baseSpD = 90, baseSpe = 100, baseExp = 261,
        moves = { "peck", "thunderShock", "thunderWave", "detect", "pluck", "ancientPower", "charge", "agility", "discharge", "roost", "lightScreen", "drillPeck", "thunder", "rainDance", "zapCannon" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "peck", level = 1, order = 1, id = 64 },
            { move = "thunderShock", level = 1, order = 2, id = 84 },
            { move = "thunderWave", level = 8, order = nil, id = 86 },
            { move = "detect", level = 15, order = nil, id = 197 },
            { move = "pluck", level = 22, order = nil, id = 365 },
            { move = "ancientPower", level = 29, order = nil, id = 246 },
            { move = "charge", level = 36, order = nil, id = 268 },
            { move = "agility", level = 43, order = nil, id = 97 },
            { move = "discharge", level = 50, order = nil, id = 435 },
            { move = "roost", level = 57, order = nil, id = 355 },
            { move = "lightScreen", level = 64, order = nil, id = 113 },
            { move = "drillPeck", level = 71, order = nil, id = 65 },
            { move = "thunder", level = 78, order = nil, id = 87 },
            { move = "rainDance", level = 85, order = nil, id = 240 },
            { move = "zapCannon", level = 92, order = nil, id = 192 },
        }
        -- END B2W2 LEARNSET
    },
    moltres = {
        name = "MOLTRES", dex = 146, type = "fire", type2 = "flying",
        baseHP = 90, baseAtk = 100, baseDef = 90, baseSpA = 125, baseSpD = 85, baseSpe = 90, baseExp = 261,
        moves = { "wingAttack", "ember", "fireSpin", "agility", "endure", "ancientPower", "flamethrower", "safeguard", "airSlash", "roost", "heatWave", "solarBeam", "skyAttack", "sunnyDay", "hurricane" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "wingAttack", level = 1, order = 1, id = 17 },
            { move = "ember", level = 1, order = 2, id = 52 },
            { move = "fireSpin", level = 8, order = nil, id = 83 },
            { move = "agility", level = 15, order = nil, id = 97 },
            { move = "endure", level = 22, order = nil, id = 203 },
            { move = "ancientPower", level = 29, order = nil, id = 246 },
            { move = "flamethrower", level = 36, order = nil, id = 53 },
            { move = "safeguard", level = 43, order = nil, id = 219 },
            { move = "airSlash", level = 50, order = nil, id = 403 },
            { move = "roost", level = 57, order = nil, id = 355 },
            { move = "heatWave", level = 64, order = nil, id = 257 },
            { move = "solarBeam", level = 71, order = nil, id = 76 },
            { move = "skyAttack", level = 78, order = nil, id = 143 },
            { move = "sunnyDay", level = 85, order = nil, id = 241 },
            { move = "hurricane", level = 92, order = nil, id = 542 },
        }
        -- END B2W2 LEARNSET
    },
    dratini = {
        name = "DRATINI", dex = 147, type = "dragon", type2 = nil,
        baseHP = 41, baseAtk = 64, baseDef = 45, baseSpA = 50, baseSpD = 50, baseSpe = 50, baseExp = 60,
        moves = { "wrap", "leer", "thunderWave", "twister", "dragonRage", "slam", "agility", "dragonTail", "aquaTail", "dragonRush", "safeguard", "dragonDance", "outrage", "hyperBeam" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "wrap", level = 1, order = 1, id = 35 },
            { move = "leer", level = 1, order = 2, id = 43 },
            { move = "thunderWave", level = 5, order = nil, id = 86 },
            { move = "twister", level = 11, order = nil, id = 239 },
            { move = "dragonRage", level = 15, order = nil, id = 82 },
            { move = "slam", level = 21, order = nil, id = 21 },
            { move = "agility", level = 25, order = nil, id = 97 },
            { move = "dragonTail", level = 31, order = nil, id = 525 },
            { move = "aquaTail", level = 35, order = nil, id = 401 },
            { move = "dragonRush", level = 41, order = nil, id = 407 },
            { move = "safeguard", level = 45, order = nil, id = 219 },
            { move = "dragonDance", level = 51, order = nil, id = 349 },
            { move = "outrage", level = 55, order = nil, id = 200 },
            { move = "hyperBeam", level = 61, order = nil, id = 63 },
        }
        -- END B2W2 LEARNSET
    },
    dragonair = {
        name = "DRAGONAIR", dex = 148, type = "dragon", type2 = nil,
        baseHP = 61, baseAtk = 84, baseDef = 65, baseSpA = 70, baseSpD = 70, baseSpe = 70, baseExp = 147,
        moves = { "wrap", "leer", "thunderWave", "twister", "thunderWave", "twister", "dragonRage", "slam", "agility", "dragonTail", "aquaTail", "dragonRush", "safeguard", "dragonDance", "outrage", "hyperBeam" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "wrap", level = 1, order = 1, id = 35 },
            { move = "leer", level = 1, order = 2, id = 43 },
            { move = "thunderWave", level = 1, order = 3, id = 86 },
            { move = "twister", level = 1, order = 4, id = 239 },
            { move = "thunderWave", level = 5, order = nil, id = 86 },
            { move = "twister", level = 11, order = nil, id = 239 },
            { move = "dragonRage", level = 15, order = nil, id = 82 },
            { move = "slam", level = 21, order = nil, id = 21 },
            { move = "agility", level = 25, order = nil, id = 97 },
            { move = "dragonTail", level = 33, order = nil, id = 525 },
            { move = "aquaTail", level = 39, order = nil, id = 401 },
            { move = "dragonRush", level = 47, order = nil, id = 407 },
            { move = "safeguard", level = 53, order = nil, id = 219 },
            { move = "dragonDance", level = 61, order = nil, id = 349 },
            { move = "outrage", level = 67, order = nil, id = 200 },
            { move = "hyperBeam", level = 75, order = nil, id = 63 },
        }
        -- END B2W2 LEARNSET
    },
    dragonite = {
        name = "DRAGONITE", dex = 149, type = "dragon", type2 = "flying",
        baseHP = 91, baseAtk = 134, baseDef = 95, baseSpA = 100, baseSpD = 100, baseSpe = 80, baseExp = 270,
        moves = { "firePunch", "thunderPunch", "roost", "wrap", "leer", "thunderWave", "twister", "thunderWave", "twister", "dragonRage", "slam", "agility", "dragonTail", "aquaTail", "dragonRush", "safeguard", "wingAttack", "dragonDance", "outrage", "hyperBeam", "hurricane" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "firePunch", level = 1, order = 1, id = 7 },
            { move = "thunderPunch", level = 1, order = 2, id = 9 },
            { move = "roost", level = 1, order = 3, id = 355 },
            { move = "wrap", level = 1, order = 4, id = 35 },
            { move = "leer", level = 1, order = 5, id = 43 },
            { move = "thunderWave", level = 1, order = 6, id = 86 },
            { move = "twister", level = 1, order = 7, id = 239 },
            { move = "thunderWave", level = 5, order = nil, id = 86 },
            { move = "twister", level = 11, order = nil, id = 239 },
            { move = "dragonRage", level = 15, order = nil, id = 82 },
            { move = "slam", level = 21, order = nil, id = 21 },
            { move = "agility", level = 25, order = nil, id = 97 },
            { move = "dragonTail", level = 33, order = nil, id = 525 },
            { move = "aquaTail", level = 39, order = nil, id = 401 },
            { move = "dragonRush", level = 47, order = nil, id = 407 },
            { move = "safeguard", level = 53, order = nil, id = 219 },
            { move = "wingAttack", level = 55, order = nil, id = 17 },
            { move = "dragonDance", level = 61, order = nil, id = 349 },
            { move = "outrage", level = 67, order = nil, id = 200 },
            { move = "hyperBeam", level = 75, order = nil, id = 63 },
            { move = "hurricane", level = 81, order = nil, id = 542 },
        }
        -- END B2W2 LEARNSET
    },
    mewtwo = {
        name = "MEWTWO", dex = 150, type = "psychic", type2 = nil,
        baseHP = 106, baseAtk = 110, baseDef = 90, baseSpA = 154, baseSpD = 90, baseSpe = 130, baseExp = 306,
        moves = { "confusion", "disable", "barrier", "swift", "futureSight", "psychUp", "miracleEye", "mist", "psychoCut", "amnesia", "powerSwap", "guardSwap", "psychic", "meFirst", "recover", "safeguard", "auraSphere", "psystrike" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "confusion", level = 1, order = 1, id = 93 },
            { move = "disable", level = 1, order = 2, id = 50 },
            { move = "barrier", level = 1, order = 3, id = 112 },
            { move = "swift", level = 8, order = nil, id = 129 },
            { move = "futureSight", level = 15, order = nil, id = 248 },
            { move = "psychUp", level = 22, order = nil, id = 244 },
            { move = "miracleEye", level = 29, order = nil, id = 357 },
            { move = "mist", level = 36, order = nil, id = 54 },
            { move = "psychoCut", level = 43, order = nil, id = 427 },
            { move = "amnesia", level = 50, order = nil, id = 133 },
            { move = "powerSwap", level = 57, order = 1, id = 384 },
            { move = "guardSwap", level = 57, order = 2, id = 385 },
            { move = "psychic", level = 64, order = nil, id = 94 },
            { move = "meFirst", level = 71, order = nil, id = 382 },
            { move = "recover", level = 79, order = nil, id = 105 },
            { move = "safeguard", level = 86, order = nil, id = 219 },
            { move = "auraSphere", level = 93, order = nil, id = 396 },
            { move = "psystrike", level = 100, order = nil, id = 540 },
        }
        -- END B2W2 LEARNSET
    },
    mew = {
        name = "MEW", dex = 151, type = "psychic", type2 = nil,
        baseHP = 100, baseAtk = 100, baseDef = 100, baseSpA = 100, baseSpD = 100, baseSpe = 100, baseExp = 270,
        moves = { "pound", "reflectType", "transform", "megaPunch", "metronome", "psychic", "barrier", "ancientPower", "amnesia", "meFirst", "batonPass", "nastyPlot", "auraSphere" },
        -- BEGIN B2W2 LEARNSET
        learnset = {
            { move = "pound", level = 1, order = 1, id = 1 },
            { move = "reflectType", level = 1, order = 2, id = 513 },
            { move = "transform", level = 1, order = 3, id = 144 },
            { move = "megaPunch", level = 10, order = nil, id = 5 },
            { move = "metronome", level = 20, order = nil, id = 118 },
            { move = "psychic", level = 30, order = nil, id = 94 },
            { move = "barrier", level = 40, order = nil, id = 112 },
            { move = "ancientPower", level = 50, order = nil, id = 246 },
            { move = "amnesia", level = 60, order = nil, id = 133 },
            { move = "meFirst", level = 70, order = nil, id = 382 },
            { move = "batonPass", level = 80, order = nil, id = 226 },
            { move = "nastyPlot", level = 90, order = nil, id = 417 },
            { move = "auraSphere", level = 100, order = nil, id = 396 },
        }
        -- END B2W2 LEARNSET
    },
}

function calcStat(base, level)
    return math.floor(((2 * base * level) / 100) + 5)
end

function calcHP(base, level)
    return math.floor(((2 * base * level) / 100) + level + 10)
end

-- Deprecated global compatibility requires an explicit species. New code uses
-- Pokemon:xpForLevel(level), preventing an accidental medium-fast fallback.
function xpForLevel(level, species)
    assert(type(species) == "string" and pokemonData[species], "xpForLevel requires an explicit species")
    local group = Growth.species(pokemonData[species].dex)
    return Growth.threshold(group, level)
end

function baseExpYield(species)
    assert(pokemonData[species], "Unknown species: " .. tostring(species))
    local _, yield = Growth.species(pokemonData[species].dex)
    return yield
end

Class("Pokemon")

local function checkedLevel(level)
    assert(type(level) == "number" and level == math.floor(level) and level >= 1 and level <= 100, "Pokemon level must be an integer in 1..100")
end

local function moveDefinition(key)
    local move = moveData[key]
    assert(move and type(move.maxPP) == "number", "Missing production move: " .. tostring(key))
    return move
end

-- New encounters/gifts only. Evolution must preserve a Pokemon's chosen moves.
-- Forward FIFO4 mirrors PKHeX SetEncounterMoves: already-known duplicates do
-- not reorder slots; a forgotten move can be learned at a later source event.
function Pokemon.initialMovesFor(species, level)
    checkedLevel(level)
    local data = pokemonData[species]
    assert(data and data.learnset, "Missing level-aware learnset: " .. tostring(species))
    local moves = {}
    for _, entry in ipairs(data.learnset) do
        if entry.level > level then break end
        if entry.level >= 1 then
            moveDefinition(entry.move)
            local known = false
            for _, key in ipairs(moves) do if key == entry.move then known = true; break end end
            if not known then
                if #moves == 4 then table.remove(moves, 1) end
                moves[#moves + 1] = entry.move
            end
        end
    end
    assert(#moves > 0, "Pokemon has no eligible initial move: " .. species)
    return moves
end

-- Detached source events for explicit level-up/relearning/evolution owners.
-- Level0 entries are excluded from ordinary encounter and level-up learning.
function Pokemon.learnsetEntriesFor(species, minimum, maximum)
    local data = pokemonData[species]
    assert(data and data.learnset, "Missing level-aware learnset: " .. tostring(species))
    local entries = {}
    for _, entry in ipairs(data.learnset) do
        if entry.level >= minimum and entry.level <= maximum then
            entries[#entries + 1] = {move = entry.move, level = entry.level, order = entry.order, id = entry.id}
        end
    end
    return entries
end

function Pokemon:hasMove(key)
    for _, known in ipairs(self.moves) do if known == key then return true end end
    return false
end

function Pokemon:getRelearnableMoves()
    local options, seen = {}, {}
    for _, entry in ipairs(Pokemon.learnsetEntriesFor(self.species, 1, self.level)) do
        if not self:hasMove(entry.move) and not seen[entry.move] then
            options[#options + 1] = entry
            seen[entry.move] = true
        end
    end
    return options
end

local function copyChoice(choice)
    return {id = choice.id, move = choice.move, level = choice.level, sourceOrder = choice.sourceOrder,
        sourceMoveId = choice.sourceMoveId, reason = choice.reason}
end

function Pokemon:getPendingMoveChoices()
    local copy = {}
    for _, choice in ipairs(self.pendingMoveChoices) do copy[#copy + 1] = copyChoice(choice) end
    return copy
end

-- Explicit decision; never silently discards a player's selected move.
-- A full moveset requires replacement slot1..4. Decline consumes the choice.
function Pokemon:resolveMoveChoice(id, decision, replacement)
    assert(decision == "learn" or decision == "decline", "Move choice requires learn/decline")
    local choice, position
    for i, pending in ipairs(self.pendingMoveChoices) do
        if pending.id == id then choice, position = pending, i; break end
    end
    assert(choice, "Unknown or resolved move choice: " .. tostring(id))
    if decision == "decline" then
        assert(replacement == nil, "Decline cannot replace a move")
        table.remove(self.pendingMoveChoices, position)
        return {kind = "declined", move = choice.move}
    end
    if self:hasMove(choice.move) then
        table.remove(self.pendingMoveChoices, position)
        return {kind = "already-known", move = choice.move}
    end
    local definition = moveDefinition(choice.move)
    local slot = #self.moves + 1
    if #self.moves == 4 then
        assert(type(replacement) == "number" and replacement == math.floor(replacement)
            and replacement >= 1 and replacement <= 4, "Four moves require an explicit replacement slot")
        slot = replacement
    else
        assert(replacement == nil, "Open move slot does not require replacement")
    end
    local forgotten = self.moves[slot]
    self.moves[slot] = choice.move
    if forgotten then self.pp[forgotten] = nil end
    self.pp[choice.move] = definition.maxPP
    table.remove(self.pendingMoveChoices, position)
    return {kind = "learned", move = choice.move, forgotten = forgotten, slot = slot}
end

function Pokemon:init(species, level, attributes)
    checkedLevel(level)
    local attributes = Specimen.attributes(attributes,species)
    local data = assert(pokemonData[species], "unknown-species")
    Specimen.ability(species,attributes.abilitySlot)
    local stats = IndividualStats.calculate(data,level,attributes.natureId,attributes.ivs,attributes.evs)
    local maxHP = stats.maxHP
    self.natureId, self.abilitySlot, self.heldItem = attributes.natureId, attributes.abilitySlot, attributes.heldItem
    self.sex, self.sexProvenance = attributes.sex, attributes.sexProvenance
    self.ivs, self.evs = attributes.ivs, attributes.evs
    self.species = species
    self.name = assert(PokemonNames[species], "missing canonical species name")
    self.dex = data.dex
    self.type = data.type
    self.type2 = data.type2
    self.level = level
    self.hp = maxHP
    self.maxHP = maxHP
    self.atk = stats.atk
    self.def = stats.def
    self.spa = stats.spa
    self.spd = stats.spd
    self.spe = stats.spe
    self.statStages = { atk = 0, def = 0, spa = 0, spd = 0, spe = 0, acc = 0, eva = 0 }
    self.status = nil       -- major: burn/poison/paralyze/sleep/freeze
    self.statusTurns = 0    -- remaining blocked sleep attempts
    self.sleepDuration = 0  -- original Gen V sleep roll; restored on switching
    self.confusion = nil    -- volatile: remaining confused turns
    self.flinched = false   -- volatile: set by flinch effects, lasts one turn
    -- XP tracking
    self.xp = self:xpForLevel(level)
    self.xpToNext = self:xpForLevel(math.min(100, level + 1))
    self.moves = Pokemon.initialMovesFor(species, level)
    self.pp = {}
    self.pendingEvolution = nil -- Only an actual level gain can create a durable event.
    self.pendingMoveChoices = {}
    self.nextMoveChoiceId = 1
    for _, moveKey in ipairs(self.moves) do
        self.pp[moveKey] = moveDefinition(moveKey).maxPP
    end
end

function Pokemon:attributes()
    return Specimen.attributes({natureId=self.natureId,abilitySlot=self.abilitySlot,heldItem=self.heldItem,
        sex=self.sex,sexProvenance=self.sexProvenance,ivs=self.ivs,evs=self.evs},self.species)
end
function Pokemon:getSex()
    return self:attributes().sex
end
function Pokemon:ability()
    return Specimen.ability(self.species,self.abilitySlot)
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
    self.statStages = { atk = 0, def = 0, spa = 0, spd = 0, spe = 0, acc = 0, eva = 0 }
    self.confusion = nil
    self.flinched = false
end

-- Actual party withdrawal, distinct from ordinary battle-exit cleanup.
function Pokemon:onSwitchOut()
    local duration
    if self.status == "sleep" then
        duration=type(self.sleepDuration)=="number" and math.tointeger(self.sleepDuration) or nil
        assert(duration and duration>=1 and duration<=3,"invalid-sleep-duration")
    end
    self:resetStages()
    if duration then self.statusTurns=duration else self.sleepDuration=0 end
end

function Pokemon:fullRestore()
    self:heal()
    self:resetStages()
    self.status = nil
    self.statusTurns = 0
    self.sleepDuration = 0
    -- Restore all PP
    for _, moveKey in ipairs(self.moves) do
        local move = moveData[moveKey]
        self.pp[moveKey] = move and move.maxPP or 10
    end
end

function Pokemon:usePP(moveKey)
    if self.pp[moveKey] and self.pp[moveKey] > 0 then
        self.pp[moveKey] = self.pp[moveKey] - 1
        return true
    end
    return false
end

function Pokemon:hasPP(moveKey)
    return self.pp[moveKey] and self.pp[moveKey] > 0
end

-- Preserve legacy bool first return; structured second result gives new levels
-- and learning choices. The queue remains until a UI/session owner resolves it.
function Pokemon:gainXP(amount)
    self:attributes() -- Validate durable inputs before any XP/stats/choice mutation.
    amount = type(amount) == "number" and math.tointeger(amount) or nil
    assert(amount and amount >= 0, "XP gain must be a nonnegative native integer")
    local oldLevel = self.level
    local room = self:xpForLevel(100) - self.xp
    local gained = self:isAlive() and math.min(amount, room) or 0
    local targetXP = self.xp + gained -- Clamp BEFORE addition: native MAX is valid.
    local targetLevel, levels = oldLevel, {}
    while targetLevel < 100 and targetXP >= self:xpForLevel(targetLevel + 1) do
        targetLevel = targetLevel + 1
        levels[#levels + 1] = targetLevel
    end
    -- Plan and validate every new choice before committing XP, stats or queue.
    -- The next counter must remain representable after all allocations; MAX is
    -- a valid exhausted counter, not permission to wrap to a negative ID.
    local planned, seen = {}, {}
    for _, key in ipairs(self.moves) do seen[key] = true end
    for _, choice in ipairs(self.pendingMoveChoices) do seen[choice.move] = true end
    for _, entry in ipairs(Pokemon.learnsetEntriesFor(self.species, oldLevel + 1, targetLevel)) do
        if not seen[entry.move] then
            moveDefinition(entry.move)
            planned[#planned + 1] = entry
            seen[entry.move] = true
        end
    end
    local nextId = math.tointeger(self.nextMoveChoiceId)
    assert(nextId and nextId >= 1 and nextId <= 2147483647, "invalid-move-choice-counter")
    assert(#planned <= 2147483647 - nextId, "move-choice-id-exhausted")
    local result = {fromLevel = oldLevel, toLevel = targetLevel, levels = levels, moveChoices = {},
        gained = gained, totalXP = targetXP, capped = gained < amount}
    self.xp, self.level = targetXP, targetLevel
    self.xpToNext = self:xpForLevel(math.min(100, targetLevel + 1))
    if targetLevel > oldLevel then self:recalcStats() end
    self.nextMoveChoiceId = nextId
    for _, entry in ipairs(planned) do
        local choice = {id = self.nextMoveChoiceId, move = entry.move, level = entry.level,
            sourceOrder = entry.order, sourceMoveId = entry.id, reason = "level-up"}
        self.nextMoveChoiceId = self.nextMoveChoiceId + 1
        self.pendingMoveChoices[#self.pendingMoveChoices + 1] = choice
        result.moveChoices[#result.moveChoices + 1] = copyChoice(choice)
    end
    if self.level > oldLevel then
        self.pendingEvolution=nil
        for _, rule in ipairs(EvolutionData.rules[self.species] or {}) do
            if rule.trigger=="level" and self.level>=rule.minimum then
                self.pendingEvolution={species=self.species,level=self.level}
                result.evolution={species=self.species,level=self.level}
                break
            end
        end
    end
    return self.level > oldLevel, result
end

function Pokemon:individuals()
    local iv,ev=IndividualStats.normalize(self.ivs,self.evs)
    return {version=1,ivs=iv,evs=ev}
end
function Pokemon:calculatedStats()
    return IndividualStats.calculate(pokemonData[self.species],self.level,self.natureId,self.ivs,self.evs)
end
function Pokemon:recalcStats()
    local stats=self:calculatedStats()
    local hp=IndividualStats.hpAfterRecalc(self.hp,self.maxHP,stats.maxHP)
    self.maxHP,self.hp=stats.maxHP,hp
    self.atk,self.def,self.spa,self.spd,self.spe=stats.atk,stats.def,stats.spa,stats.spd,stats.spe
end

-- Species-aware thresholds, including level 1 = 0 and level 100 maximum.
function Pokemon:xpForLevel(level)
    return xpForLevel(level, self.species)
end

-- Conscious participants share the base before recipient scaling; original OT,
-- no held/item/Pass Power boosts. Omitted count preserves single-member callers.
-- Eligibility/cap return the actual amount that gainXP can accept.
function Pokemon:calcExpGain(defeated, trainerBattle, participants)
    assert(type(trainerBattle) == "boolean", "calcExpGain requires trainer battle flag")
    participants = participants == nil and 1 or (type(participants)=="number" and math.tointeger(participants))
    assert(participants and participants>=1 and participants<=6,"invalid conscious participant count")
    if not self:isAlive() or self.level == 100 then return 0 end
    return math.min(self:xpForLevel(100) - self.xp,
        Growth.battleAward(baseExpYield(defeated.species), defeated.level, self.level, trainerBattle, participants, NPCTrades.isOutsider(self)))
end
