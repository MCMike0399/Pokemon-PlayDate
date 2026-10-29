import "data/lazyLearnsets"
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
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "tackle|1|-|33;growl|3|-|45;leechSeed|7|-|73;vineWhip|9|-|22;poisonPowder|13|1|77;sleepPowder|13|2|79;takeDown|15|-|36;razorLeaf|19|-|75;sweetScent|21|-|230;growth|25|-|74;doubleEdge|27|-|38;worrySeed|31|-|388;synthesis|33|-|235;seedBomb|37|-|402"
        -- END B2W2 LEARNSET
    },
    ivysaur = {
        name = "IVYSAUR", dex = 2, type = "grass", type2 = "poison",
        baseHP = 60, baseAtk = 62, baseDef = 63, baseSpA = 80, baseSpD = 80, baseSpe = 60, baseExp = 142,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "tackle|1|1|33;growl|1|2|45;leechSeed|1|3|73;growl|3|-|45;leechSeed|7|-|73;vineWhip|9|-|22;poisonPowder|13|1|77;sleepPowder|13|2|79;takeDown|15|-|36;razorLeaf|20|-|75;sweetScent|23|-|230;growth|28|-|74;doubleEdge|31|-|38;worrySeed|36|-|388;synthesis|39|-|235;solarBeam|44|-|76"
        -- END B2W2 LEARNSET
    },
    venusaur = {
        name = "VENUSAUR", dex = 3, type = "grass", type2 = "poison",
        baseHP = 80, baseAtk = 82, baseDef = 83, baseSpA = 100, baseSpD = 100, baseSpe = 80, baseExp = 236,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "tackle|1|1|33;growl|1|2|45;leechSeed|1|3|73;vineWhip|1|4|22;growl|3|-|45;leechSeed|7|-|73;vineWhip|9|-|22;poisonPowder|13|1|77;sleepPowder|13|2|79;takeDown|15|-|36;razorLeaf|20|-|75;sweetScent|23|-|230;growth|28|-|74;doubleEdge|31|-|38;petalDance|32|-|80;worrySeed|39|-|388;synthesis|45|-|235;solarBeam|53|-|76"
        -- END B2W2 LEARNSET
    },
    charmander = {
        name = "CHARMANDER", dex = 4, type = "fire", type2 = nil,
        baseHP = 39, baseAtk = 52, baseDef = 43, baseSpA = 60, baseSpD = 50, baseSpe = 65, baseExp = 62,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "scratch|1|1|10;growl|1|2|45;ember|7|-|52;smokescreen|10|-|108;dragonRage|16|-|82;scaryFace|19|-|184;fireFang|25|-|424;flameBurst|28|-|481;slash|34|-|163;flamethrower|37|-|53;fireSpin|43|-|83;inferno|46|-|517"
        -- END B2W2 LEARNSET
    },
    charmeleon = {
        name = "CHARMELEON", dex = 5, type = "fire", type2 = nil,
        baseHP = 58, baseAtk = 64, baseDef = 58, baseSpA = 80, baseSpD = 65, baseSpe = 80, baseExp = 142,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "scratch|1|1|10;growl|1|2|45;ember|1|3|52;ember|7|-|52;smokescreen|10|-|108;dragonRage|17|-|82;scaryFace|21|-|184;fireFang|28|-|424;flameBurst|32|-|481;slash|39|-|163;flamethrower|43|-|53;fireSpin|50|-|83;inferno|54|-|517"
        -- END B2W2 LEARNSET
    },
    charizard = {
        name = "CHARIZARD", dex = 6, type = "fire", type2 = "flying",
        baseHP = 78, baseAtk = 84, baseDef = 78, baseSpA = 109, baseSpD = 85, baseSpe = 100, baseExp = 240,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "dragonClaw|1|1|337;shadowClaw|1|2|421;airSlash|1|3|403;scratch|1|4|10;growl|1|5|45;ember|1|6|52;smokescreen|1|7|108;ember|7|-|52;smokescreen|10|-|108;dragonRage|17|-|82;scaryFace|21|-|184;fireFang|28|-|424;flameBurst|32|-|481;wingAttack|36|-|17;slash|41|-|163;flamethrower|47|-|53;fireSpin|56|-|83;inferno|62|-|517;heatWave|71|-|257;flareBlitz|77|-|394"
        -- END B2W2 LEARNSET
    },
    squirtle = {
        name = "SQUIRTLE", dex = 7, type = "water", type2 = nil,
        baseHP = 44, baseAtk = 48, baseDef = 65, baseSpA = 50, baseSpD = 64, baseSpe = 43, baseExp = 63,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "tackle|1|-|33;tailWhip|4|-|39;bubble|7|-|145;withdraw|10|-|110;waterGun|13|-|55;bite|16|-|44;rapidSpin|19|-|229;protect|22|-|182;waterPulse|25|-|352;aquaTail|28|-|401;skullBash|31|-|130;ironDefense|34|-|334;rainDance|37|-|240;hydroPump|40|-|56"
        -- END B2W2 LEARNSET
    },
    wartortle = {
        name = "WARTORTLE", dex = 8, type = "water", type2 = nil,
        baseHP = 59, baseAtk = 63, baseDef = 80, baseSpA = 65, baseSpD = 80, baseSpe = 58, baseExp = 142,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "tackle|1|1|33;tailWhip|1|2|39;bubble|1|3|145;tailWhip|4|-|39;bubble|7|-|145;withdraw|10|-|110;waterGun|13|-|55;bite|16|-|44;rapidSpin|20|-|229;protect|24|-|182;waterPulse|28|-|352;aquaTail|32|-|401;skullBash|36|-|130;ironDefense|40|-|334;rainDance|44|-|240;hydroPump|48|-|56"
        -- END B2W2 LEARNSET
    },
    blastoise = {
        name = "BLASTOISE", dex = 9, type = "water", type2 = nil,
        baseHP = 79, baseAtk = 83, baseDef = 100, baseSpA = 85, baseSpD = 105, baseSpe = 78, baseExp = 239,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "flashCannon|1|1|430;tackle|1|2|33;tailWhip|1|3|39;bubble|1|4|145;withdraw|1|5|110;tailWhip|4|-|39;bubble|7|-|145;withdraw|10|-|110;waterGun|13|-|55;bite|16|-|44;rapidSpin|20|-|229;protect|24|-|182;waterPulse|28|-|352;aquaTail|32|-|401;skullBash|39|-|130;ironDefense|46|-|334;rainDance|53|-|240;hydroPump|60|-|56"
        -- END B2W2 LEARNSET
    },
    caterpie = {
        name = "CATERPIE", dex = 10, type = "bug", type2 = nil,
        baseHP = 45, baseAtk = 30, baseDef = 35, baseSpA = 20, baseSpD = 20, baseSpe = 45, baseExp = 39,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "tackle|1|1|33;stringShot|1|2|81;bugBite|15|-|450"
        -- END B2W2 LEARNSET
    },
    metapod = {
        name = "METAPOD", dex = 11, type = "bug", type2 = nil,
        baseHP = 50, baseAtk = 20, baseDef = 55, baseSpA = 25, baseSpD = 25, baseSpe = 30, baseExp = 72,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "harden|1|-|106;harden|7|-|106"
        -- END B2W2 LEARNSET
    },
    butterfree = {
        name = "BUTTERFREE", dex = 12, type = "bug", type2 = "flying",
        baseHP = 60, baseAtk = 45, baseDef = 50, baseSpA = 80, baseSpD = 80, baseSpe = 70, baseExp = 173,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "confusion|1|-|93;confusion|10|-|93;poisonPowder|12|1|77;stunSpore|12|2|78;sleepPowder|12|3|79;gust|16|-|16;supersonic|18|-|48;whirlwind|22|-|18;psybeam|24|-|60;silverWind|28|-|318;tailwind|30|-|366;ragePowder|34|-|476;safeguard|36|-|219;captivate|40|-|445;bugBuzz|42|-|405;quiverDance|46|-|483"
        -- END B2W2 LEARNSET
    },
    weedle = {
        name = "WEEDLE", dex = 13, type = "bug", type2 = "poison",
        baseHP = 40, baseAtk = 35, baseDef = 30, baseSpA = 20, baseSpD = 20, baseSpe = 50, baseExp = 39,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "poisonSting|1|1|40;stringShot|1|2|81;bugBite|15|-|450"
        -- END B2W2 LEARNSET
    },
    kakuna = {
        name = "KAKUNA", dex = 14, type = "bug", type2 = "poison",
        baseHP = 45, baseAtk = 25, baseDef = 50, baseSpA = 25, baseSpD = 25, baseSpe = 35, baseExp = 72,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "harden|1|-|106;harden|7|-|106"
        -- END B2W2 LEARNSET
    },
    beedrill = {
        name = "BEEDRILL", dex = 15, type = "bug", type2 = "poison",
        baseHP = 65, baseAtk = 80, baseDef = 40, baseSpA = 45, baseSpD = 80, baseSpe = 75, baseExp = 173,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "furyAttack|1|-|31;furyAttack|10|-|31;focusEnergy|13|-|116;twineedle|16|-|41;rage|19|-|99;pursuit|22|-|228;toxicSpikes|25|-|390;pinMissile|28|-|42;agility|31|-|97;assurance|34|-|372;poisonJab|37|-|398;endeavor|40|-|283"
        -- END B2W2 LEARNSET
    },
    pidgey = {
        name = "PIDGEY", dex = 16, type = "normal", type2 = "flying",
        baseHP = 40, baseAtk = 45, baseDef = 40, baseSpA = 35, baseSpD = 35, baseSpe = 56, baseExp = 50,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "tackle|1|-|33;sandAttack|5|-|28;gust|9|-|16;quickAttack|13|-|98;whirlwind|17|-|18;twister|21|-|239;featherDance|25|-|297;agility|29|-|97;wingAttack|33|-|17;roost|37|-|355;tailwind|41|-|366;mirrorMove|45|-|119;airSlash|49|-|403;hurricane|53|-|542"
        -- END B2W2 LEARNSET
    },
    pidgeotto = {
        name = "PIDGEOTTO", dex = 17, type = "normal", type2 = "flying",
        baseHP = 63, baseAtk = 60, baseDef = 55, baseSpA = 50, baseSpD = 50, baseSpe = 71, baseExp = 122,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "tackle|1|1|33;sandAttack|1|2|28;gust|1|3|16;sandAttack|5|-|28;gust|9|-|16;quickAttack|13|-|98;whirlwind|17|-|18;twister|22|-|239;featherDance|27|-|297;agility|32|-|97;wingAttack|37|-|17;roost|42|-|355;tailwind|47|-|366;mirrorMove|52|-|119;airSlash|57|-|403;hurricane|62|-|542"
        -- END B2W2 LEARNSET
    },
    pidgeot = {
        name = "PIDGEOT", dex = 18, type = "normal", type2 = "flying",
        baseHP = 83, baseAtk = 80, baseDef = 75, baseSpA = 70, baseSpD = 70, baseSpe = 91, baseExp = 211,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "tackle|1|1|33;sandAttack|1|2|28;gust|1|3|16;quickAttack|1|4|98;sandAttack|5|-|28;gust|9|-|16;quickAttack|13|-|98;whirlwind|17|-|18;twister|22|-|239;featherDance|27|-|297;agility|32|-|97;wingAttack|38|-|17;roost|44|-|355;tailwind|50|-|366;mirrorMove|56|-|119;airSlash|62|-|403;hurricane|68|-|542"
        -- END B2W2 LEARNSET
    },
    rattata = {
        name = "RATTATA", dex = 19, type = "normal", type2 = nil,
        baseHP = 30, baseAtk = 56, baseDef = 35, baseSpA = 25, baseSpD = 35, baseSpe = 72, baseExp = 51,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "tackle|1|1|33;tailWhip|1|2|39;quickAttack|4|-|98;focusEnergy|7|-|116;bite|10|-|44;pursuit|13|-|228;hyperFang|16|-|158;suckerPunch|19|-|389;crunch|22|-|242;assurance|25|-|372;superFang|28|-|162;doubleEdge|31|-|38;endeavor|34|-|283"
        -- END B2W2 LEARNSET
    },
    raticate = {
        name = "RATICATE", dex = 20, type = "normal", type2 = nil,
        baseHP = 55, baseAtk = 81, baseDef = 60, baseSpA = 50, baseSpD = 70, baseSpe = 97, baseExp = 145,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "swordsDance|1|1|14;tackle|1|2|33;tailWhip|1|3|39;quickAttack|1|4|98;focusEnergy|1|5|116;quickAttack|4|-|98;focusEnergy|7|-|116;bite|10|-|44;pursuit|13|-|228;hyperFang|16|-|158;suckerPunch|19|-|389;scaryFace|20|-|184;crunch|24|-|242;assurance|29|-|372;superFang|34|-|162;doubleEdge|39|-|38;endeavor|44|-|283"
        -- END B2W2 LEARNSET
    },
    spearow = {
        name = "SPEAROW", dex = 21, type = "normal", type2 = "flying",
        baseHP = 40, baseAtk = 60, baseDef = 30, baseSpA = 31, baseSpD = 31, baseSpe = 70, baseExp = 52,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "peck|1|1|64;growl|1|2|45;leer|5|-|43;furyAttack|9|-|31;pursuit|13|-|228;aerialAce|17|-|332;mirrorMove|21|-|119;agility|25|-|97;assurance|29|-|372;roost|33|-|355;drillPeck|37|-|65"
        -- END B2W2 LEARNSET
    },
    fearow = {
        name = "FEAROW", dex = 22, type = "normal", type2 = "flying",
        baseHP = 65, baseAtk = 90, baseDef = 65, baseSpA = 61, baseSpD = 61, baseSpe = 100, baseExp = 155,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "pluck|1|1|365;peck|1|2|64;growl|1|3|45;leer|1|4|43;furyAttack|1|5|31;leer|5|-|43;furyAttack|9|-|31;pursuit|13|-|228;aerialAce|17|-|332;mirrorMove|23|-|119;agility|29|-|97;assurance|35|-|372;roost|41|-|355;drillPeck|47|-|65;drillRun|53|-|529"
        -- END B2W2 LEARNSET
    },
    ekans = {
        name = "EKANS", dex = 23, type = "poison", type2 = nil,
        baseHP = 35, baseAtk = 60, baseDef = 44, baseSpA = 40, baseSpD = 54, baseSpe = 55, baseExp = 58,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "wrap|1|1|35;leer|1|2|43;poisonSting|4|-|40;bite|9|-|44;glare|12|-|137;screech|17|-|103;acid|20|-|51;stockpile|25|1|254;swallow|25|2|256;spitUp|25|3|255;acidSpray|28|-|491;mudBomb|33|-|426;gastroAcid|36|-|380;haze|41|-|114;coil|44|-|489;gunkShot|49|-|441"
        -- END B2W2 LEARNSET
    },
    arbok = {
        name = "ARBOK", dex = 24, type = "poison", type2 = nil,
        baseHP = 60, baseAtk = 85, baseDef = 69, baseSpA = 65, baseSpD = 79, baseSpe = 80, baseExp = 153,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "iceFang|1|1|423;thunderFang|1|2|422;fireFang|1|3|424;wrap|1|4|35;leer|1|5|43;poisonSting|1|6|40;bite|1|7|44;poisonSting|4|-|40;bite|9|-|44;glare|12|-|137;screech|17|-|103;acid|20|-|51;crunch|22|-|242;stockpile|27|1|254;swallow|27|2|256;spitUp|27|3|255;acidSpray|32|-|491;mudBomb|39|-|426;gastroAcid|44|-|380;haze|51|-|114;coil|56|-|489;gunkShot|63|-|441"
        -- END B2W2 LEARNSET
    },
    pikachu = {
        name = "PIKACHU", dex = 25, type = "electric", type2 = nil,
        baseHP = 35, baseAtk = 55, baseDef = 30, baseSpA = 50, baseSpD = 40, baseSpe = 90, baseExp = 105,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "growl|1|1|45;thunderShock|1|2|84;tailWhip|5|-|39;thunderWave|10|-|86;quickAttack|13|-|98;electroBall|18|-|486;doubleTeam|21|-|104;slam|26|-|21;thunderbolt|29|-|85;feint|34|-|364;agility|37|-|97;discharge|42|-|435;lightScreen|45|-|113;thunder|50|-|87"
        -- END B2W2 LEARNSET
    },
    raichu = {
        name = "RAICHU", dex = 26, type = "electric", type2 = nil,
        baseHP = 60, baseAtk = 90, baseDef = 55, baseSpA = 90, baseSpD = 80, baseSpe = 100, baseExp = 214,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "thunderShock|1|1|84;tailWhip|1|2|39;quickAttack|1|3|98;thunderbolt|1|4|85"
        -- END B2W2 LEARNSET
    },
    sandshrew = {
        name = "SANDSHREW", dex = 27, type = "ground", type2 = nil,
        baseHP = 50, baseAtk = 75, baseDef = 85, baseSpA = 20, baseSpD = 30, baseSpe = 40, baseExp = 60,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "scratch|1|1|10;defenseCurl|1|2|111;sandAttack|3|-|28;poisonSting|5|-|40;rollout|7|-|205;rapidSpin|9|-|229;swift|11|-|129;furyCutter|14|-|210;magnitude|17|-|222;furySwipes|20|-|154;sandTomb|23|-|328;slash|26|-|163;dig|30|-|91;gyroBall|34|-|360;swordsDance|38|-|14;sandstorm|42|-|201;earthquake|46|-|89"
        -- END B2W2 LEARNSET
    },
    sandslash = {
        name = "SANDSLASH", dex = 28, type = "ground", type2 = nil,
        baseHP = 75, baseAtk = 100, baseDef = 110, baseSpA = 45, baseSpD = 55, baseSpe = 65, baseExp = 158,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "scratch|1|1|10;defenseCurl|1|2|111;sandAttack|1|3|28;poisonSting|1|4|40;sandAttack|3|-|28;poisonSting|5|-|40;rollout|7|-|205;rapidSpin|9|-|229;swift|11|-|129;furyCutter|14|-|210;magnitude|17|-|222;furySwipes|20|-|154;crushClaw|22|-|306;sandTomb|23|-|328;slash|26|-|163;dig|30|-|91;gyroBall|34|-|360;swordsDance|38|-|14;sandstorm|42|-|201;earthquake|46|-|89"
        -- END B2W2 LEARNSET
    },
    nidoranF = {
        name = "NIDORAN F", dex = 29, type = "poison", type2 = nil,
        baseHP = 55, baseAtk = 47, baseDef = 52, baseSpA = 40, baseSpD = 40, baseSpe = 41, baseExp = 55,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "growl|1|1|45;scratch|1|2|10;tailWhip|7|-|39;doubleKick|9|-|24;poisonSting|13|-|40;furySwipes|19|-|154;bite|21|-|44;helpingHand|25|-|270;toxicSpikes|31|-|390;flatter|33|-|260;crunch|37|-|242;captivate|43|-|445;poisonFang|45|-|305"
        -- END B2W2 LEARNSET
    },
    nidorina = {
        name = "NIDORINA", dex = 30, type = "poison", type2 = nil,
        baseHP = 70, baseAtk = 62, baseDef = 67, baseSpA = 55, baseSpD = 55, baseSpe = 56, baseExp = 128,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "growl|1|1|45;scratch|1|2|10;tailWhip|7|-|39;doubleKick|9|-|24;poisonSting|13|-|40;furySwipes|20|-|154;bite|23|-|44;helpingHand|28|-|270;toxicSpikes|35|-|390;flatter|38|-|260;crunch|43|-|242;captivate|50|-|445;poisonFang|58|-|305"
        -- END B2W2 LEARNSET
    },
    nidoqueen = {
        name = "NIDOQUEEN", dex = 31, type = "poison", type2 = "ground",
        baseHP = 90, baseAtk = 82, baseDef = 87, baseSpA = 75, baseSpD = 85, baseSpe = 76, baseExp = 223,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "scratch|1|1|10;tailWhip|1|2|39;doubleKick|1|3|24;poisonSting|1|4|40;chipAway|23|-|498;bodySlam|35|-|34;earthPower|43|-|414;superpower|58|-|276"
        -- END B2W2 LEARNSET
    },
    nidoranM = {
        name = "NIDORAN M", dex = 32, type = "poison", type2 = nil,
        baseHP = 46, baseAtk = 57, baseDef = 40, baseSpA = 40, baseSpD = 40, baseSpe = 50, baseExp = 55,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "leer|1|1|43;peck|1|2|64;focusEnergy|7|-|116;doubleKick|9|-|24;poisonSting|13|-|40;furyAttack|19|-|31;hornAttack|21|-|30;helpingHand|25|-|270;toxicSpikes|31|-|390;flatter|33|-|260;poisonJab|37|-|398;captivate|43|-|445;hornDrill|45|-|32"
        -- END B2W2 LEARNSET
    },
    nidorino = {
        name = "NIDORINO", dex = 33, type = "poison", type2 = nil,
        baseHP = 61, baseAtk = 72, baseDef = 57, baseSpA = 55, baseSpD = 55, baseSpe = 65, baseExp = 128,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "leer|1|1|43;peck|1|2|64;focusEnergy|7|-|116;doubleKick|9|-|24;poisonSting|13|-|40;furyAttack|20|-|31;hornAttack|23|-|30;helpingHand|28|-|270;toxicSpikes|35|-|390;flatter|38|-|260;poisonJab|43|-|398;captivate|50|-|445;hornDrill|58|-|32"
        -- END B2W2 LEARNSET
    },
    nidoking = {
        name = "NIDOKING", dex = 34, type = "poison", type2 = "ground",
        baseHP = 81, baseAtk = 92, baseDef = 77, baseSpA = 85, baseSpD = 75, baseSpe = 85, baseExp = 223,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "peck|1|1|64;focusEnergy|1|2|116;doubleKick|1|3|24;poisonSting|1|4|40;chipAway|23|-|498;thrash|35|-|37;earthPower|43|-|414;megahorn|58|-|224"
        -- END B2W2 LEARNSET
    },
    clefairy = {
        name = "CLEFAIRY", dex = 35, type = "normal", type2 = nil,
        baseHP = 70, baseAtk = 45, baseDef = 48, baseSpA = 60, baseSpD = 65, baseSpe = 35, baseExp = 113,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "pound|1|1|1;growl|1|2|45;encore|4|-|227;sing|7|-|47;doubleSlap|10|-|3;defenseCurl|13|-|111;followMe|16|-|266;bestow|19|-|516;wakeUpSlap|22|-|358;minimize|25|-|107;storedPower|28|-|500;metronome|31|-|118;cosmicPower|34|-|322;luckyChant|37|-|381;bodySlam|40|-|34;moonlight|43|-|236;lightScreen|46|-|113;gravity|49|-|356;meteorMash|52|-|309;healingWish|55|-|361;afterYou|58|-|495"
        -- END B2W2 LEARNSET
    },
    clefable = {
        name = "CLEFABLE", dex = 36, type = "normal", type2 = nil,
        baseHP = 95, baseAtk = 70, baseDef = 73, baseSpA = 85, baseSpD = 90, baseSpe = 60, baseExp = 213,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "sing|1|1|47;doubleSlap|1|2|3;minimize|1|3|107;metronome|1|4|118"
        -- END B2W2 LEARNSET
    },
    vulpix = {
        name = "VULPIX", dex = 37, type = "fire", type2 = nil,
        baseHP = 38, baseAtk = 41, baseDef = 40, baseSpA = 50, baseSpD = 65, baseSpe = 65, baseExp = 60,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "ember|1|-|52;tailWhip|4|-|39;roar|7|-|46;quickAttack|10|-|98;fireSpin|12|-|83;confuseRay|15|-|109;imprison|18|-|286;feintAttack|20|-|185;flameBurst|23|-|481;willOWisp|26|-|261;hex|28|-|506;payback|31|-|371;flamethrower|34|-|53;safeguard|36|-|219;extrasensory|39|-|326;fireBlast|42|-|126;grudge|44|-|288;captivate|47|-|445;inferno|50|-|517"
        -- END B2W2 LEARNSET
    },
    ninetales = {
        name = "NINETALES", dex = 38, type = "fire", type2 = nil,
        baseHP = 73, baseAtk = 76, baseDef = 75, baseSpA = 81, baseSpD = 100, baseSpe = 100, baseExp = 177,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "nastyPlot|1|1|417;ember|1|2|52;quickAttack|1|3|98;confuseRay|1|4|109;safeguard|1|5|219"
        -- END B2W2 LEARNSET
    },
    jigglypuff = {
        name = "JIGGLYPUFF", dex = 39, type = "normal", type2 = nil,
        baseHP = 115, baseAtk = 45, baseDef = 20, baseSpA = 45, baseSpD = 25, baseSpe = 20, baseExp = 95,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "sing|1|-|47;defenseCurl|5|-|111;pound|9|-|1;disable|13|-|50;round|17|-|496;rollout|21|-|205;doubleSlap|25|-|3;rest|29|-|156;bodySlam|33|-|34;gyroBall|37|-|360;wakeUpSlap|41|-|358;mimic|45|-|102;hyperVoice|49|-|304;doubleEdge|53|-|38"
        -- END B2W2 LEARNSET
    },
    wigglytuff = {
        name = "WIGGLYTUFF", dex = 40, type = "normal", type2 = nil,
        baseHP = 140, baseAtk = 70, baseDef = 45, baseSpA = 75, baseSpD = 50, baseSpe = 45, baseExp = 191,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "sing|1|1|47;disable|1|2|50;defenseCurl|1|3|111;doubleSlap|1|4|3"
        -- END B2W2 LEARNSET
    },
    zubat = {
        name = "ZUBAT", dex = 41, type = "poison", type2 = "flying",
        baseHP = 40, baseAtk = 45, baseDef = 35, baseSpA = 30, baseSpD = 40, baseSpe = 55, baseExp = 49,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "leechLife|1|-|141;supersonic|4|-|48;astonish|8|-|310;bite|12|-|44;wingAttack|15|-|17;confuseRay|19|-|109;swift|23|-|129;airCutter|26|-|314;acrobatics|30|-|512;meanLook|34|-|212;poisonFang|37|-|305;haze|41|-|114;airSlash|45|-|403"
        -- END B2W2 LEARNSET
    },
    golbat = {
        name = "GOLBAT", dex = 42, type = "poison", type2 = "flying",
        baseHP = 75, baseAtk = 80, baseDef = 70, baseSpA = 65, baseSpD = 75, baseSpe = 90, baseExp = 159,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "screech|1|1|103;leechLife|1|2|141;supersonic|1|3|48;astonish|1|4|310;supersonic|4|-|48;astonish|8|-|310;bite|12|-|44;wingAttack|15|-|17;confuseRay|19|-|109;swift|24|-|129;airCutter|28|-|314;acrobatics|33|-|512;meanLook|38|-|212;poisonFang|42|-|305;haze|47|-|114;airSlash|52|-|403"
        -- END B2W2 LEARNSET
    },
    oddish = {
        name = "ODDISH", dex = 43, type = "grass", type2 = "poison",
        baseHP = 45, baseAtk = 50, baseDef = 55, baseSpA = 75, baseSpD = 65, baseSpe = 30, baseExp = 64,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "absorb|1|-|71;sweetScent|5|-|230;acid|9|-|51;poisonPowder|13|-|77;stunSpore|15|-|78;sleepPowder|17|-|79;megaDrain|21|-|72;luckyChant|25|-|381;naturalGift|29|-|363;moonlight|33|-|236;gigaDrain|37|-|202;petalDance|41|-|80"
        -- END B2W2 LEARNSET
    },
    gloom = {
        name = "GLOOM", dex = 44, type = "grass", type2 = "poison",
        baseHP = 60, baseAtk = 65, baseDef = 70, baseSpA = 85, baseSpD = 75, baseSpe = 40, baseExp = 138,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "absorb|1|1|71;sweetScent|1|2|230;acid|1|3|51;sweetScent|5|-|230;acid|9|-|51;poisonPowder|13|-|77;stunSpore|15|-|78;sleepPowder|17|-|79;megaDrain|23|-|72;luckyChant|29|-|381;naturalGift|35|-|363;moonlight|41|-|236;gigaDrain|47|-|202;petalDance|53|-|80"
        -- END B2W2 LEARNSET
    },
    vileplume = {
        name = "VILEPLUME", dex = 45, type = "grass", type2 = "poison",
        baseHP = 75, baseAtk = 80, baseDef = 85, baseSpA = 100, baseSpD = 90, baseSpe = 50, baseExp = 216,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "megaDrain|1|1|72;aromatherapy|1|2|312;stunSpore|1|3|78;poisonPowder|1|4|77;petalDance|53|-|80;solarBeam|65|-|76"
        -- END B2W2 LEARNSET
    },
    paras = {
        name = "PARAS", dex = 46, type = "bug", type2 = "grass",
        baseHP = 35, baseAtk = 70, baseDef = 55, baseSpA = 45, baseSpD = 55, baseSpe = 25, baseExp = 57,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "scratch|1|-|10;stunSpore|6|1|78;poisonPowder|6|2|77;leechLife|11|-|141;furyCutter|17|-|210;spore|22|-|147;slash|27|-|163;growth|33|-|74;gigaDrain|38|-|202;aromatherapy|43|-|312;ragePowder|49|-|476;xScissor|54|-|404"
        -- END B2W2 LEARNSET
    },
    parasect = {
        name = "PARASECT", dex = 47, type = "bug", type2 = "grass",
        baseHP = 60, baseAtk = 95, baseDef = 80, baseSpA = 60, baseSpD = 80, baseSpe = 30, baseExp = 142,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "crossPoison|1|1|440;scratch|1|2|10;stunSpore|1|3|78;poisonPowder|1|4|77;leechLife|1|5|141;stunSpore|6|1|78;poisonPowder|6|2|77;leechLife|11|-|141;furyCutter|17|-|210;spore|22|-|147;slash|29|-|163;growth|37|-|74;gigaDrain|44|-|202;aromatherapy|51|-|312;ragePowder|59|-|476;xScissor|66|-|404"
        -- END B2W2 LEARNSET
    },
    venonat = {
        name = "VENONAT", dex = 48, type = "bug", type2 = "poison",
        baseHP = 60, baseAtk = 55, baseDef = 50, baseSpA = 40, baseSpD = 55, baseSpe = 45, baseExp = 61,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "tackle|1|1|33;disable|1|2|50;foresight|1|3|193;supersonic|5|-|48;confusion|11|-|93;poisonPowder|13|-|77;leechLife|17|-|141;stunSpore|23|-|78;psybeam|25|-|60;sleepPowder|29|-|79;signalBeam|35|-|324;zenHeadbutt|37|-|428;poisonFang|41|-|305;psychic|47|-|94"
        -- END B2W2 LEARNSET
    },
    venomoth = {
        name = "VENOMOTH", dex = 49, type = "bug", type2 = "poison",
        baseHP = 70, baseAtk = 65, baseDef = 60, baseSpA = 90, baseSpD = 75, baseSpe = 90, baseExp = 158,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "silverWind|1|1|318;tackle|1|2|33;disable|1|3|50;foresight|1|4|193;supersonic|1|5|48;supersonic|5|-|48;confusion|11|-|93;poisonPowder|13|-|77;leechLife|17|-|141;stunSpore|23|-|78;psybeam|25|-|60;sleepPowder|29|-|79;gust|31|-|16;signalBeam|37|-|324;zenHeadbutt|41|-|428;poisonFang|47|-|305;psychic|55|-|94;bugBuzz|59|-|405;quiverDance|63|-|483"
        -- END B2W2 LEARNSET
    },
    diglett = {
        name = "DIGLETT", dex = 50, type = "ground", type2 = nil,
        baseHP = 10, baseAtk = 55, baseDef = 25, baseSpA = 35, baseSpD = 45, baseSpe = 95, baseExp = 53,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "scratch|1|1|10;sandAttack|1|2|28;growl|4|-|45;astonish|7|-|310;mudSlap|12|-|189;magnitude|15|-|222;bulldoze|18|-|523;suckerPunch|23|-|389;mudBomb|26|-|426;earthPower|29|-|414;dig|34|-|91;slash|37|-|163;earthquake|40|-|89;fissure|45|-|90"
        -- END B2W2 LEARNSET
    },
    dugtrio = {
        name = "DUGTRIO", dex = 51, type = "ground", type2 = nil,
        baseHP = 35, baseAtk = 80, baseDef = 50, baseSpA = 50, baseSpD = 70, baseSpe = 120, baseExp = 142,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "nightSlash|1|1|400;triAttack|1|2|161;scratch|1|3|10;sandAttack|1|4|28;growl|1|5|45;growl|4|-|45;astonish|7|-|310;mudSlap|12|-|189;magnitude|15|-|222;bulldoze|18|-|523;suckerPunch|23|-|389;sandTomb|26|-|328;mudBomb|28|-|426;earthPower|33|-|414;dig|40|-|91;slash|45|-|163;earthquake|50|-|89;fissure|57|-|90"
        -- END B2W2 LEARNSET
    },
    meowth = {
        name = "MEOWTH", dex = 52, type = "normal", type2 = nil,
        baseHP = 40, baseAtk = 45, baseDef = 35, baseSpA = 40, baseSpD = 40, baseSpe = 90, baseExp = 58,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "scratch|1|1|10;growl|1|2|45;bite|6|-|44;fakeOut|9|-|252;furySwipes|14|-|154;screech|17|-|103;feintAttack|22|-|185;taunt|25|-|269;payDay|30|-|6;slash|33|-|163;nastyPlot|38|-|417;assurance|41|-|372;captivate|46|-|445;nightSlash|49|-|400;feint|54|-|364"
        -- END B2W2 LEARNSET
    },
    persian = {
        name = "PERSIAN", dex = 53, type = "normal", type2 = nil,
        baseHP = 65, baseAtk = 70, baseDef = 60, baseSpA = 65, baseSpD = 65, baseSpe = 115, baseExp = 154,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "switcheroo|1|1|415;scratch|1|2|10;growl|1|3|45;bite|1|4|44;fakeOut|1|5|252;bite|6|-|44;fakeOut|9|-|252;furySwipes|14|-|154;screech|17|-|103;feintAttack|22|-|185;taunt|25|-|269;swift|28|-|129;powerGem|32|-|408;slash|37|-|163;nastyPlot|44|-|417;assurance|49|-|372;captivate|56|-|445;nightSlash|61|-|400;feint|68|-|364"
        -- END B2W2 LEARNSET
    },
    psyduck = {
        name = "PSYDUCK", dex = 54, type = "water", type2 = nil,
        baseHP = 50, baseAtk = 52, baseDef = 48, baseSpA = 65, baseSpD = 50, baseSpe = 55, baseExp = 64,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "waterSport|1|1|346;scratch|1|2|10;tailWhip|4|-|39;waterGun|8|-|55;disable|11|-|50;confusion|15|-|93;waterPulse|18|-|352;furySwipes|22|-|154;screech|25|-|103;zenHeadbutt|29|-|428;aquaTail|32|-|401;soak|36|-|487;psychUp|39|-|244;amnesia|43|-|133;hydroPump|46|-|56;wonderRoom|50|-|472"
        -- END B2W2 LEARNSET
    },
    golduck = {
        name = "GOLDUCK", dex = 55, type = "water", type2 = nil,
        baseHP = 80, baseAtk = 82, baseDef = 78, baseSpA = 95, baseSpD = 80, baseSpe = 85, baseExp = 175,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "aquaJet|1|1|453;waterSport|1|2|346;scratch|1|3|10;tailWhip|1|4|39;waterGun|1|5|55;tailWhip|4|-|39;waterGun|8|-|55;disable|11|-|50;confusion|15|-|93;waterPulse|18|-|352;furySwipes|22|-|154;screech|25|-|103;zenHeadbutt|29|-|428;aquaTail|32|-|401;soak|38|-|487;psychUp|43|-|244;amnesia|49|-|133;hydroPump|54|-|56;wonderRoom|60|-|472"
        -- END B2W2 LEARNSET
    },
    mankey = {
        name = "MANKEY", dex = 56, type = "fighting", type2 = nil,
        baseHP = 40, baseAtk = 80, baseDef = 35, baseSpA = 35, baseSpD = 45, baseSpe = 70, baseExp = 61,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "covet|1|1|343;scratch|1|2|10;lowKick|1|3|67;leer|1|4|43;focusEnergy|1|5|116;furySwipes|9|-|154;karateChop|13|-|2;seismicToss|17|-|69;screech|21|-|103;assurance|25|-|372;swagger|33|-|207;crossChop|37|-|238;thrash|41|-|37;punishment|45|-|386;closeCombat|49|-|370;finalGambit|53|-|515"
        -- END B2W2 LEARNSET
    },
    primeape = {
        name = "PRIMEAPE", dex = 57, type = "fighting", type2 = nil,
        baseHP = 65, baseAtk = 105, baseDef = 60, baseSpA = 60, baseSpD = 70, baseSpe = 95, baseExp = 159,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "fling|1|1|374;scratch|1|2|10;lowKick|1|3|67;leer|1|4|43;focusEnergy|1|5|116;furySwipes|9|-|154;karateChop|13|-|2;seismicToss|17|-|69;screech|21|-|103;assurance|25|-|372;rage|28|-|99;swagger|35|-|207;crossChop|41|-|238;thrash|47|-|37;punishment|53|-|386;closeCombat|59|-|370;finalGambit|63|-|515"
        -- END B2W2 LEARNSET
    },
    growlithe = {
        name = "GROWLITHE", dex = 58, type = "fire", type2 = nil,
        baseHP = 55, baseAtk = 70, baseDef = 45, baseSpA = 70, baseSpD = 50, baseSpe = 60, baseExp = 70,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "bite|1|1|44;roar|1|2|46;ember|6|-|52;leer|8|-|43;odorSleuth|10|-|316;helpingHand|12|-|270;flameWheel|17|-|172;reversal|19|-|179;fireFang|21|-|424;takeDown|23|-|36;flameBurst|28|-|481;agility|30|-|97;retaliate|32|-|514;flamethrower|34|-|53;crunch|39|-|242;heatWave|41|-|257;outrage|43|-|200;flareBlitz|45|-|394"
        -- END B2W2 LEARNSET
    },
    arcanine = {
        name = "ARCANINE", dex = 59, type = "fire", type2 = nil,
        baseHP = 90, baseAtk = 110, baseDef = 80, baseSpA = 100, baseSpD = 80, baseSpe = 95, baseExp = 194,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "thunderFang|1|1|422;bite|1|2|44;roar|1|3|46;odorSleuth|1|4|316;fireFang|1|5|424;extremeSpeed|34|-|245"
        -- END B2W2 LEARNSET
    },
    poliwag = {
        name = "POLIWAG", dex = 60, type = "water", type2 = nil,
        baseHP = 40, baseAtk = 50, baseDef = 40, baseSpA = 40, baseSpD = 40, baseSpe = 90, baseExp = 60,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "waterSport|1|-|346;bubble|5|-|145;hypnosis|8|-|95;waterGun|11|-|55;doubleSlap|15|-|3;rainDance|18|-|240;bodySlam|21|-|34;bubbleBeam|25|-|61;mudShot|28|-|341;bellyDrum|31|-|187;wakeUpSlap|35|-|358;hydroPump|38|-|56;mudBomb|41|-|426"
        -- END B2W2 LEARNSET
    },
    poliwhirl = {
        name = "POLIWHIRL", dex = 61, type = "water", type2 = nil,
        baseHP = 65, baseAtk = 65, baseDef = 65, baseSpA = 50, baseSpD = 50, baseSpe = 90, baseExp = 135,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "waterSport|1|1|346;bubble|1|2|145;hypnosis|1|3|95;bubble|5|-|145;hypnosis|8|-|95;waterGun|11|-|55;doubleSlap|15|-|3;rainDance|18|-|240;bodySlam|21|-|34;bubbleBeam|27|-|61;mudShot|32|-|341;bellyDrum|37|-|187;wakeUpSlap|43|-|358;hydroPump|48|-|56;mudBomb|53|-|426"
        -- END B2W2 LEARNSET
    },
    poliwrath = {
        name = "POLIWRATH", dex = 62, type = "water", type2 = "fighting",
        baseHP = 90, baseAtk = 85, baseDef = 95, baseSpA = 70, baseSpD = 90, baseSpe = 70, baseExp = 225,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "bubbleBeam|1|1|61;hypnosis|1|2|95;doubleSlap|1|3|3;submission|1|4|66;dynamicPunch|32|-|223;mindReader|43|-|170;circleThrow|53|-|509"
        -- END B2W2 LEARNSET
    },
    abra = {
        name = "ABRA", dex = 63, type = "psychic", type2 = nil,
        baseHP = 25, baseAtk = 20, baseDef = 15, baseSpA = 105, baseSpD = 55, baseSpe = 90, baseExp = 62,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "teleport|1|-|100"
        -- END B2W2 LEARNSET
    },
    kadabra = {
        name = "KADABRA", dex = 64, type = "psychic", type2 = nil,
        baseHP = 40, baseAtk = 35, baseDef = 30, baseSpA = 120, baseSpD = 70, baseSpe = 105, baseExp = 140,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "teleport|1|1|100;kinesis|1|2|134;confusion|1|3|93;confusion|16|-|93;disable|18|-|50;miracleEye|22|-|357;allySwitch|24|-|502;psybeam|28|-|60;reflect|30|-|115;telekinesis|34|-|477;recover|36|-|105;psychoCut|40|-|427;rolePlay|42|-|272;psychic|46|-|94;futureSight|48|-|248;trick|52|-|271"
        -- END B2W2 LEARNSET
    },
    alakazam = {
        name = "ALAKAZAM", dex = 65, type = "psychic", type2 = nil,
        baseHP = 55, baseAtk = 50, baseDef = 45, baseSpA = 135, baseSpD = 85, baseSpe = 120, baseExp = 221,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "teleport|1|1|100;kinesis|1|2|134;confusion|1|3|93;confusion|16|-|93;disable|18|-|50;miracleEye|22|-|357;allySwitch|24|-|502;psybeam|28|-|60;reflect|30|-|115;telekinesis|34|-|477;recover|36|-|105;psychoCut|40|-|427;calmMind|42|-|347;psychic|46|-|94;futureSight|48|-|248;trick|52|-|271"
        -- END B2W2 LEARNSET
    },
    machop = {
        name = "MACHOP", dex = 66, type = "fighting", type2 = nil,
        baseHP = 70, baseAtk = 80, baseDef = 50, baseSpA = 35, baseSpD = 35, baseSpe = 35, baseExp = 61,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "lowKick|1|1|67;leer|1|2|43;focusEnergy|7|-|116;karateChop|10|-|2;lowSweep|13|-|490;foresight|19|-|193;seismicToss|22|-|69;revenge|25|-|279;vitalThrow|31|-|233;submission|34|-|66;wakeUpSlap|37|-|358;crossChop|43|-|238;scaryFace|46|-|184;dynamicPunch|49|-|223"
        -- END B2W2 LEARNSET
    },
    machoke = {
        name = "MACHOKE", dex = 67, type = "fighting", type2 = nil,
        baseHP = 80, baseAtk = 100, baseDef = 70, baseSpA = 50, baseSpD = 60, baseSpe = 45, baseExp = 142,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "lowKick|1|1|67;leer|1|2|43;focusEnergy|1|3|116;karateChop|1|4|2;focusEnergy|7|-|116;karateChop|10|-|2;lowSweep|13|-|490;foresight|19|-|193;seismicToss|22|-|69;revenge|25|-|279;vitalThrow|32|-|233;submission|36|-|66;wakeUpSlap|40|-|358;crossChop|44|-|238;scaryFace|51|-|184;dynamicPunch|55|-|223"
        -- END B2W2 LEARNSET
    },
    machamp = {
        name = "MACHAMP", dex = 68, type = "fighting", type2 = nil,
        baseHP = 90, baseAtk = 130, baseDef = 80, baseSpA = 65, baseSpD = 85, baseSpe = 55, baseExp = 227,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "wideGuard|1|1|469;lowKick|1|2|67;leer|1|3|43;focusEnergy|1|4|116;karateChop|1|5|2;focusEnergy|7|-|116;karateChop|10|-|2;lowSweep|13|-|490;foresight|19|-|193;seismicToss|22|-|69;revenge|25|-|279;vitalThrow|32|-|233;submission|36|-|66;wakeUpSlap|40|-|358;crossChop|44|-|238;scaryFace|51|-|184;dynamicPunch|55|-|223"
        -- END B2W2 LEARNSET
    },
    bellsprout = {
        name = "BELLSPROUT", dex = 69, type = "grass", type2 = "poison",
        baseHP = 50, baseAtk = 75, baseDef = 35, baseSpA = 70, baseSpD = 30, baseSpe = 40, baseExp = 60,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "vineWhip|1|-|22;growth|7|-|74;wrap|11|-|35;sleepPowder|13|-|79;poisonPowder|15|-|77;stunSpore|17|-|78;acid|23|-|51;knockOff|27|-|282;sweetScent|29|-|230;gastroAcid|35|-|380;razorLeaf|39|-|75;slam|41|-|21;wringOut|47|-|378"
        -- END B2W2 LEARNSET
    },
    weepinbell = {
        name = "WEEPINBELL", dex = 70, type = "grass", type2 = "poison",
        baseHP = 65, baseAtk = 90, baseDef = 50, baseSpA = 85, baseSpD = 45, baseSpe = 55, baseExp = 137,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "vineWhip|1|1|22;growth|1|2|74;wrap|1|3|35;growth|7|-|74;wrap|11|-|35;sleepPowder|13|-|79;poisonPowder|15|-|77;stunSpore|17|-|78;acid|23|-|51;knockOff|27|-|282;sweetScent|29|-|230;gastroAcid|35|-|380;razorLeaf|39|-|75;slam|41|-|21;wringOut|47|-|378"
        -- END B2W2 LEARNSET
    },
    victreebel = {
        name = "VICTREEBEL", dex = 71, type = "grass", type2 = "poison",
        baseHP = 80, baseAtk = 105, baseDef = 65, baseSpA = 100, baseSpD = 60, baseSpe = 70, baseExp = 216,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "stockpile|1|1|254;swallow|1|2|256;spitUp|1|3|255;vineWhip|1|4|22;sleepPowder|1|5|79;sweetScent|1|6|230;razorLeaf|1|7|75;leafTornado|27|-|536;leafStorm|47|1|437;leafBlade|47|2|348"
        -- END B2W2 LEARNSET
    },
    tentacool = {
        name = "TENTACOOL", dex = 72, type = "water", type2 = "poison",
        baseHP = 40, baseAtk = 40, baseDef = 35, baseSpA = 50, baseSpD = 100, baseSpe = 70, baseExp = 67,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "poisonSting|1|-|40;supersonic|5|-|48;constrict|8|-|132;acid|12|-|51;toxicSpikes|15|-|390;bubbleBeam|19|-|61;wrap|22|-|35;acidSpray|26|-|491;barrier|29|-|112;waterPulse|33|-|352;poisonJab|36|-|398;screech|40|-|103;hex|43|-|506;hydroPump|47|-|56;sludgeWave|50|-|482;wringOut|54|-|378"
        -- END B2W2 LEARNSET
    },
    tentacruel = {
        name = "TENTACRUEL", dex = 73, type = "water", type2 = "poison",
        baseHP = 80, baseAtk = 70, baseDef = 65, baseSpA = 80, baseSpD = 120, baseSpe = 100, baseExp = 180,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "poisonSting|1|1|40;supersonic|1|2|48;constrict|1|3|132;supersonic|5|-|48;constrict|8|-|132;acid|12|-|51;toxicSpikes|15|-|390;bubbleBeam|19|-|61;wrap|22|-|35;acidSpray|26|-|491;barrier|29|-|112;waterPulse|34|-|352;poisonJab|38|-|398;screech|43|-|103;hex|47|-|506;hydroPump|52|-|56;sludgeWave|56|-|482;wringOut|61|-|378"
        -- END B2W2 LEARNSET
    },
    geodude = {
        name = "GEODUDE", dex = 74, type = "rock", type2 = "ground",
        baseHP = 40, baseAtk = 80, baseDef = 100, baseSpA = 30, baseSpD = 30, baseSpe = 20, baseExp = 60,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "tackle|1|1|33;defenseCurl|1|2|111;mudSport|4|-|300;rockPolish|8|-|397;rockThrow|11|-|88;magnitude|15|-|222;rollout|18|-|205;rockBlast|22|-|350;smackDown|25|-|479;selfDestruct|29|-|120;bulldoze|32|-|523;stealthRock|36|-|446;earthquake|39|-|89;explosion|43|-|153;doubleEdge|46|-|38;stoneEdge|50|-|444"
        -- END B2W2 LEARNSET
    },
    graveler = {
        name = "GRAVELER", dex = 75, type = "rock", type2 = "ground",
        baseHP = 55, baseAtk = 95, baseDef = 115, baseSpA = 45, baseSpD = 45, baseSpe = 35, baseExp = 137,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "tackle|1|1|33;defenseCurl|1|2|111;mudSport|1|3|300;rockPolish|1|4|397;mudSport|4|-|300;rockPolish|8|-|397;rockThrow|11|-|88;magnitude|15|-|222;rollout|18|-|205;rockBlast|22|-|350;smackDown|27|-|479;selfDestruct|31|-|120;bulldoze|36|-|523;stealthRock|42|-|446;earthquake|47|-|89;explosion|53|-|153;doubleEdge|58|-|38;stoneEdge|64|-|444"
        -- END B2W2 LEARNSET
    },
    golem = {
        name = "GOLEM", dex = 76, type = "rock", type2 = "ground",
        baseHP = 80, baseAtk = 110, baseDef = 130, baseSpA = 55, baseSpD = 65, baseSpe = 45, baseExp = 218,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "tackle|1|1|33;defenseCurl|1|2|111;mudSport|1|3|300;rockPolish|1|4|397;mudSport|4|-|300;rockPolish|8|-|397;rockThrow|11|-|88;magnitude|15|-|222;steamroller|18|-|537;rockBlast|22|-|350;smackDown|27|-|479;selfDestruct|31|-|120;bulldoze|36|-|523;stealthRock|42|-|446;earthquake|47|-|89;explosion|53|-|153;doubleEdge|58|-|38;stoneEdge|64|-|444;heavySlam|69|-|484"
        -- END B2W2 LEARNSET
    },
    ponyta = {
        name = "PONYTA", dex = 77, type = "fire", type2 = nil,
        baseHP = 50, baseAtk = 85, baseDef = 55, baseSpA = 65, baseSpD = 65, baseSpe = 90, baseExp = 82,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "growl|1|1|45;tackle|1|2|33;tailWhip|4|-|39;ember|9|-|52;flameWheel|13|-|172;stomp|17|-|23;flameCharge|21|-|488;fireSpin|25|-|83;takeDown|29|-|36;inferno|33|-|517;agility|37|-|97;fireBlast|41|-|126;bounce|45|-|340;flareBlitz|49|-|394"
        -- END B2W2 LEARNSET
    },
    rapidash = {
        name = "RAPIDASH", dex = 78, type = "fire", type2 = nil,
        baseHP = 65, baseAtk = 100, baseDef = 70, baseSpA = 80, baseSpD = 80, baseSpe = 105, baseExp = 175,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "poisonJab|1|1|398;megahorn|1|2|224;growl|1|3|45;quickAttack|1|4|98;tailWhip|1|5|39;ember|1|6|52;tailWhip|4|-|39;ember|9|-|52;flameWheel|13|-|172;stomp|17|-|23;flameCharge|21|-|488;fireSpin|25|-|83;takeDown|29|-|36;inferno|33|-|517;agility|37|-|97;furyAttack|40|-|31;fireBlast|41|-|126;bounce|45|-|340;flareBlitz|49|-|394"
        -- END B2W2 LEARNSET
    },
    slowpoke = {
        name = "SLOWPOKE", dex = 79, type = "water", type2 = "psychic",
        baseHP = 90, baseAtk = 65, baseDef = 65, baseSpA = 40, baseSpD = 40, baseSpe = 15, baseExp = 63,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "curse|1|1|174;yawn|1|2|281;tackle|1|3|33;growl|5|-|45;waterGun|9|-|55;confusion|14|-|93;disable|19|-|50;headbutt|23|-|29;waterPulse|28|-|352;zenHeadbutt|32|-|428;slackOff|36|-|303;amnesia|41|-|133;psychic|45|-|94;rainDance|49|-|240;psychUp|54|-|244;healPulse|58|-|505"
        -- END B2W2 LEARNSET
    },
    slowbro = {
        name = "SLOWBRO", dex = 80, type = "water", type2 = "psychic",
        baseHP = 95, baseAtk = 75, baseDef = 110, baseSpA = 100, baseSpD = 80, baseSpe = 30, baseExp = 172,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "curse|1|1|174;yawn|1|2|281;tackle|1|3|33;growl|1|4|45;growl|5|-|45;waterGun|9|-|55;confusion|14|-|93;disable|19|-|50;headbutt|23|-|29;waterPulse|28|-|352;zenHeadbutt|32|-|428;slackOff|36|-|303;withdraw|37|-|110;amnesia|43|-|133;psychic|49|-|94;rainDance|55|-|240;psychUp|62|-|244;healPulse|68|-|505"
        -- END B2W2 LEARNSET
    },
    magnemite = {
        name = "MAGNEMITE", dex = 81, type = "electric", type2 = "steel",
        baseHP = 25, baseAtk = 35, baseDef = 70, baseSpA = 95, baseSpD = 55, baseSpe = 45, baseExp = 65,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "tackle|1|-|33;supersonic|4|-|48;thunderShock|7|-|84;sonicBoom|11|-|49;thunderWave|15|-|86;magnetBomb|18|-|443;spark|21|-|209;mirrorShot|25|-|429;metalSound|29|-|319;electroBall|32|-|486;flashCannon|35|-|430;screech|39|-|103;discharge|43|-|435;lockOn|46|-|199;magnetRise|49|-|393;gyroBall|53|-|360;zapCannon|57|-|192"
        -- END B2W2 LEARNSET
    },
    magneton = {
        name = "MAGNETON", dex = 82, type = "electric", type2 = "steel",
        baseHP = 50, baseAtk = 60, baseDef = 95, baseSpA = 120, baseSpD = 70, baseSpe = 70, baseExp = 163,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "triAttack|1|1|161;tackle|1|2|33;supersonic|1|3|48;thunderShock|1|4|84;sonicBoom|1|5|49;supersonic|4|-|48;thunderShock|7|-|84;sonicBoom|11|-|49;thunderWave|15|-|86;magnetBomb|18|-|443;spark|21|-|209;mirrorShot|25|-|429;metalSound|29|-|319;electroBall|34|-|486;flashCannon|39|-|430;screech|45|-|103;discharge|51|-|435;lockOn|56|-|199;magnetRise|62|-|393;gyroBall|67|-|360;zapCannon|73|-|192"
        -- END B2W2 LEARNSET
    },
    farfetchd = {
        name = "FARFETCHD", dex = 83, type = "normal", type2 = "flying",
        baseHP = 52, baseAtk = 65, baseDef = 55, baseSpA = 58, baseSpD = 62, baseSpe = 60, baseExp = 123,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "poisonJab|1|1|398;peck|1|2|64;sandAttack|1|3|28;leer|1|4|43;furyCutter|1|5|210;furyAttack|7|-|31;knockOff|9|-|282;aerialAce|13|-|332;slash|19|-|163;airCutter|21|-|314;swordsDance|25|-|14;agility|31|-|97;nightSlash|33|-|400;acrobatics|37|-|512;feint|43|-|364;falseSwipe|45|-|206;airSlash|49|-|403;braveBird|55|-|413"
        -- END B2W2 LEARNSET
    },
    doduo = {
        name = "DODUO", dex = 84, type = "normal", type2 = "flying",
        baseHP = 35, baseAtk = 85, baseDef = 45, baseSpA = 35, baseSpD = 35, baseSpe = 75, baseExp = 62,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "peck|1|1|64;growl|1|2|45;quickAttack|5|-|98;rage|10|-|99;furyAttack|14|-|31;pursuit|19|-|228;uproar|23|-|253;acupressure|28|-|367;doubleHit|32|-|458;agility|37|-|97;drillPeck|41|-|65;endeavor|46|-|283;thrash|50|-|37"
        -- END B2W2 LEARNSET
    },
    dodrio = {
        name = "DODRIO", dex = 85, type = "normal", type2 = "flying",
        baseHP = 60, baseAtk = 110, baseDef = 70, baseSpA = 60, baseSpD = 60, baseSpe = 100, baseExp = 161,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "pluck|1|1|365;peck|1|2|64;growl|1|3|45;quickAttack|1|4|98;rage|1|5|99;quickAttack|5|-|98;rage|10|-|99;furyAttack|14|-|31;pursuit|19|-|228;uproar|23|-|253;acupressure|28|-|367;triAttack|34|-|161;agility|41|-|97;drillPeck|47|-|65;endeavor|54|-|283;thrash|60|-|37"
        -- END B2W2 LEARNSET
    },
    seel = {
        name = "SEEL", dex = 86, type = "water", type2 = nil,
        baseHP = 65, baseAtk = 45, baseDef = 55, baseSpA = 45, baseSpD = 70, baseSpe = 45, baseExp = 65,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "headbutt|1|-|29;growl|3|-|45;waterSport|7|-|346;icyWind|11|-|196;encore|13|-|227;iceShard|17|-|420;rest|21|-|156;aquaRing|23|-|392;auroraBeam|27|-|62;aquaJet|31|-|453;brine|33|-|362;takeDown|37|-|36;dive|41|-|291;aquaTail|43|-|401;iceBeam|47|-|58;safeguard|51|-|219;hail|53|-|258"
        -- END B2W2 LEARNSET
    },
    dewgong = {
        name = "DEWGONG", dex = 87, type = "water", type2 = "ice",
        baseHP = 90, baseAtk = 70, baseDef = 80, baseSpA = 70, baseSpD = 95, baseSpe = 70, baseExp = 166,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "headbutt|1|1|29;growl|1|2|45;signalBeam|1|3|324;icyWind|1|4|196;growl|3|-|45;signalBeam|7|-|324;icyWind|11|-|196;encore|13|-|227;iceShard|17|-|420;rest|21|-|156;aquaRing|23|-|392;auroraBeam|27|-|62;aquaJet|31|-|453;brine|33|-|362;sheerCold|34|-|329;takeDown|39|-|36;dive|45|-|291;aquaTail|49|-|401;iceBeam|55|-|58;safeguard|61|-|219;hail|65|-|258"
        -- END B2W2 LEARNSET
    },
    grimer = {
        name = "GRIMER", dex = 88, type = "poison", type2 = nil,
        baseHP = 80, baseAtk = 80, baseDef = 50, baseSpA = 40, baseSpD = 50, baseSpe = 25, baseExp = 65,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "pound|1|1|1;poisonGas|1|2|139;harden|4|-|106;mudSlap|7|-|189;disable|12|-|50;sludge|15|-|124;minimize|18|-|107;mudBomb|21|-|426;sludgeBomb|26|-|188;fling|29|-|374;screech|32|-|103;sludgeWave|37|-|482;acidArmor|40|-|151;gunkShot|43|-|441;memento|48|-|262"
        -- END B2W2 LEARNSET
    },
    muk = {
        name = "MUK", dex = 89, type = "poison", type2 = nil,
        baseHP = 105, baseAtk = 105, baseDef = 75, baseSpA = 65, baseSpD = 100, baseSpe = 50, baseExp = 175,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "pound|1|1|1;poisonGas|1|2|139;harden|1|3|106;mudSlap|1|4|189;harden|4|-|106;mudSlap|7|-|189;disable|12|-|50;sludge|15|-|124;minimize|18|-|107;mudBomb|21|-|426;sludgeBomb|26|-|188;fling|29|-|374;screech|32|-|103;sludgeWave|37|-|482;acidArmor|43|-|151;gunkShot|49|-|441;memento|57|-|262"
        -- END B2W2 LEARNSET
    },
    shellder = {
        name = "SHELLDER", dex = 90, type = "water", type2 = nil,
        baseHP = 30, baseAtk = 65, baseDef = 100, baseSpA = 45, baseSpD = 25, baseSpe = 40, baseExp = 61,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "tackle|1|-|33;withdraw|4|-|110;supersonic|8|-|48;icicleSpear|13|-|333;protect|16|-|182;leer|20|-|43;clamp|25|-|128;iceShard|28|-|420;razorShell|32|-|534;auroraBeam|37|-|62;whirlpool|40|-|250;brine|44|-|362;ironDefense|49|-|334;iceBeam|52|-|58;shellSmash|56|-|504;hydroPump|61|-|56"
        -- END B2W2 LEARNSET
    },
    cloyster = {
        name = "CLOYSTER", dex = 91, type = "water", type2 = "ice",
        baseHP = 50, baseAtk = 95, baseDef = 180, baseSpA = 85, baseSpD = 45, baseSpe = 70, baseExp = 184,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "toxicSpikes|1|1|390;withdraw|1|2|110;supersonic|1|3|48;protect|1|4|182;auroraBeam|1|5|62;spikeCannon|13|-|131;spikes|28|-|191;icicleCrash|52|-|556"
        -- END B2W2 LEARNSET
    },
    gastly = {
        name = "GASTLY", dex = 92, type = "ghost", type2 = "poison",
        baseHP = 30, baseAtk = 35, baseDef = 30, baseSpA = 100, baseSpD = 35, baseSpe = 80, baseExp = 62,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "hypnosis|1|1|95;lick|1|2|122;spite|5|-|180;meanLook|8|-|212;curse|12|-|174;nightShade|15|-|101;confuseRay|19|-|109;suckerPunch|22|-|389;payback|26|-|371;shadowBall|29|-|247;dreamEater|33|-|138;darkPulse|36|-|399;destinyBond|40|-|194;hex|43|-|506;nightmare|47|-|171"
        -- END B2W2 LEARNSET
    },
    haunter = {
        name = "HAUNTER", dex = 93, type = "ghost", type2 = "poison",
        baseHP = 45, baseAtk = 50, baseDef = 45, baseSpA = 115, baseSpD = 55, baseSpe = 95, baseExp = 142,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "hypnosis|1|1|95;lick|1|2|122;spite|1|3|180;spite|5|-|180;meanLook|8|-|212;curse|12|-|174;nightShade|15|-|101;confuseRay|19|-|109;suckerPunch|22|-|389;shadowPunch|25|-|325;payback|28|-|371;shadowBall|33|-|247;dreamEater|39|-|138;darkPulse|44|-|399;destinyBond|50|-|194;hex|55|-|506;nightmare|61|-|171"
        -- END B2W2 LEARNSET
    },
    gengar = {
        name = "GENGAR", dex = 94, type = "ghost", type2 = "poison",
        baseHP = 60, baseAtk = 65, baseDef = 60, baseSpA = 130, baseSpD = 75, baseSpe = 110, baseExp = 225,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "hypnosis|1|1|95;lick|1|2|122;spite|1|3|180;spite|5|-|180;meanLook|8|-|212;curse|12|-|174;nightShade|15|-|101;confuseRay|19|-|109;suckerPunch|22|-|389;shadowPunch|25|-|325;payback|28|-|371;shadowBall|33|-|247;dreamEater|39|-|138;darkPulse|44|-|399;destinyBond|50|-|194;hex|55|-|506;nightmare|61|-|171"
        -- END B2W2 LEARNSET
    },
    onix = {
        name = "ONIX", dex = 95, type = "rock", type2 = "ground",
        baseHP = 35, baseAtk = 45, baseDef = 160, baseSpA = 30, baseSpD = 45, baseSpe = 70, baseExp = 77,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "mudSport|1|1|300;tackle|1|2|33;harden|1|3|106;bind|1|4|20;curse|4|-|174;rockThrow|7|-|88;rage|10|-|99;rockTomb|13|-|317;stealthRock|16|-|446;rockPolish|19|-|397;smackDown|22|-|479;dragonBreath|25|-|225;slam|28|-|21;screech|31|-|103;rockSlide|34|-|157;sandTomb|37|-|328;ironTail|40|-|231;dig|43|-|91;stoneEdge|46|-|444;doubleEdge|49|-|38;sandstorm|52|-|201"
        -- END B2W2 LEARNSET
    },
    drowzee = {
        name = "DROWZEE", dex = 96, type = "psychic", type2 = nil,
        baseHP = 60, baseAtk = 48, baseDef = 45, baseSpA = 43, baseSpD = 90, baseSpe = 42, baseExp = 66,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "pound|1|1|1;hypnosis|1|2|95;disable|5|-|50;confusion|9|-|93;headbutt|13|-|29;poisonGas|17|-|139;meditate|21|-|96;psybeam|25|-|60;headbutt|29|-|29;psychUp|33|-|244;synchronoise|37|-|485;zenHeadbutt|41|-|428;swagger|45|-|207;psychic|49|-|94;nastyPlot|53|-|417;psyshock|57|-|473;futureSight|61|-|248"
        -- END B2W2 LEARNSET
    },
    hypno = {
        name = "HYPNO", dex = 97, type = "psychic", type2 = nil,
        baseHP = 85, baseAtk = 73, baseDef = 70, baseSpA = 73, baseSpD = 115, baseSpe = 67, baseExp = 169,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "nightmare|1|1|171;switcheroo|1|2|415;pound|1|3|1;hypnosis|1|4|95;disable|1|5|50;confusion|1|6|93;disable|5|-|50;confusion|9|-|93;headbutt|13|-|29;poisonGas|17|-|139;meditate|21|-|96;psybeam|25|-|60;headbutt|29|-|29;psychUp|33|-|244;synchronoise|37|-|485;zenHeadbutt|41|-|428;swagger|45|-|207;psychic|49|-|94;nastyPlot|53|-|417;psyshock|57|-|473;futureSight|61|-|248"
        -- END B2W2 LEARNSET
    },
    krabby = {
        name = "KRABBY", dex = 98, type = "water", type2 = nil,
        baseHP = 30, baseAtk = 105, baseDef = 90, baseSpA = 25, baseSpD = 25, baseSpe = 50, baseExp = 65,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "mudSport|1|1|300;bubble|1|2|145;viceGrip|5|-|11;leer|9|-|43;harden|11|-|106;bubbleBeam|15|-|61;mudShot|19|-|341;metalClaw|21|-|232;stomp|25|-|23;protect|29|-|182;guillotine|31|-|12;slam|35|-|21;brine|39|-|362;crabhammer|41|-|152;flail|45|-|175"
        -- END B2W2 LEARNSET
    },
    kingler = {
        name = "KINGLER", dex = 99, type = "water", type2 = nil,
        baseHP = 55, baseAtk = 130, baseDef = 115, baseSpA = 50, baseSpD = 50, baseSpe = 75, baseExp = 166,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "wideGuard|1|1|469;mudSport|1|2|300;bubble|1|3|145;viceGrip|1|4|11;leer|1|5|43;viceGrip|5|-|11;leer|9|-|43;harden|11|-|106;bubbleBeam|15|-|61;mudShot|19|-|341;metalClaw|21|-|232;stomp|25|-|23;protect|32|-|182;guillotine|37|-|12;slam|44|-|21;brine|51|-|362;crabhammer|56|-|152;flail|63|-|175"
        -- END B2W2 LEARNSET
    },
    voltorb = {
        name = "VOLTORB", dex = 100, type = "electric", type2 = nil,
        baseHP = 40, baseAtk = 30, baseDef = 50, baseSpA = 55, baseSpD = 55, baseSpe = 100, baseExp = 66,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "charge|1|-|268;tackle|5|-|33;sonicBoom|8|-|49;spark|12|-|209;rollout|15|-|205;screech|19|-|103;chargeBeam|22|-|451;lightScreen|26|-|113;electroBall|29|-|486;selfDestruct|33|-|120;swift|36|-|129;magnetRise|40|-|393;gyroBall|43|-|360;explosion|47|-|153;mirrorCoat|50|-|243"
        -- END B2W2 LEARNSET
    },
    electrode = {
        name = "ELECTRODE", dex = 101, type = "electric", type2 = nil,
        baseHP = 60, baseAtk = 50, baseDef = 70, baseSpA = 80, baseSpD = 80, baseSpe = 140, baseExp = 168,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "charge|1|1|268;tackle|1|2|33;sonicBoom|1|3|49;spark|1|4|209;tackle|5|-|33;sonicBoom|8|-|49;spark|12|-|209;rollout|15|-|205;screech|19|-|103;chargeBeam|22|-|451;lightScreen|26|-|113;electroBall|29|-|486;selfDestruct|35|-|120;swift|40|-|129;magnetRise|46|-|393;gyroBall|51|-|360;explosion|57|-|153;mirrorCoat|62|-|243"
        -- END B2W2 LEARNSET
    },
    exeggcute = {
        name = "EXEGGCUTE", dex = 102, type = "grass", type2 = "psychic",
        baseHP = 60, baseAtk = 40, baseDef = 80, baseSpA = 60, baseSpD = 45, baseSpe = 40, baseExp = 65,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "barrage|1|1|140;uproar|1|2|253;hypnosis|1|3|95;reflect|7|-|115;leechSeed|11|-|73;bulletSeed|17|-|331;stunSpore|19|-|78;poisonPowder|21|-|77;sleepPowder|23|-|79;confusion|27|-|93;worrySeed|33|-|388;naturalGift|37|-|363;solarBeam|43|-|76;extrasensory|47|-|326;bestow|53|-|516"
        -- END B2W2 LEARNSET
    },
    exeggutor = {
        name = "EXEGGUTOR", dex = 103, type = "grass", type2 = "psychic",
        baseHP = 95, baseAtk = 95, baseDef = 85, baseSpA = 125, baseSpD = 65, baseSpe = 55, baseExp = 182,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "seedBomb|1|1|402;barrage|1|2|140;hypnosis|1|3|95;confusion|1|4|93;stomp|1|5|23;psyshock|17|-|473;eggBomb|27|-|121;woodHammer|37|-|452;leafStorm|47|-|437"
        -- END B2W2 LEARNSET
    },
    cubone = {
        name = "CUBONE", dex = 104, type = "ground", type2 = nil,
        baseHP = 50, baseAtk = 50, baseDef = 95, baseSpA = 40, baseSpD = 50, baseSpe = 35, baseExp = 64,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "growl|1|-|45;tailWhip|3|-|39;boneClub|7|-|125;headbutt|11|-|29;leer|13|-|43;focusEnergy|17|-|116;bonemerang|21|-|155;rage|23|-|99;falseSwipe|27|-|206;thrash|31|-|37;fling|33|-|374;boneRush|37|-|198;endeavor|41|-|283;doubleEdge|43|-|38;retaliate|47|-|514"
        -- END B2W2 LEARNSET
    },
    marowak = {
        name = "MAROWAK", dex = 105, type = "ground", type2 = nil,
        baseHP = 60, baseAtk = 80, baseDef = 110, baseSpA = 50, baseSpD = 80, baseSpe = 45, baseExp = 149,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "growl|1|1|45;tailWhip|1|2|39;boneClub|1|3|125;headbutt|1|4|29;tailWhip|3|-|39;boneClub|7|-|125;headbutt|11|-|29;leer|13|-|43;focusEnergy|17|-|116;bonemerang|21|-|155;rage|23|-|99;falseSwipe|27|-|206;thrash|33|-|37;fling|37|-|374;boneRush|43|-|198;endeavor|49|-|283;doubleEdge|53|-|38;retaliate|59|-|514"
        -- END B2W2 LEARNSET
    },
    hitmonlee = {
        name = "HITMONLEE", dex = 106, type = "fighting", type2 = nil,
        baseHP = 50, baseAtk = 120, baseDef = 53, baseSpA = 35, baseSpD = 110, baseSpe = 87, baseExp = 159,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "revenge|1|1|279;doubleKick|1|2|24;meditate|5|-|96;rollingKick|9|-|27;jumpKick|13|-|26;brickBreak|17|-|280;focusEnergy|21|-|116;feint|25|-|364;highJumpKick|29|-|136;mindReader|33|-|170;foresight|37|-|193;wideGuard|41|-|469;blazeKick|45|-|299;endure|49|-|203;megaKick|53|-|25;closeCombat|57|-|370;reversal|61|-|179"
        -- END B2W2 LEARNSET
    },
    hitmonchan = {
        name = "HITMONCHAN", dex = 107, type = "fighting", type2 = nil,
        baseHP = 50, baseAtk = 105, baseDef = 79, baseSpA = 35, baseSpD = 110, baseSpe = 76, baseExp = 159,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "revenge|1|1|279;cometPunch|1|2|4;agility|6|-|97;pursuit|11|-|228;machPunch|16|1|183;bulletPunch|16|2|418;feint|21|-|364;vacuumWave|26|-|410;quickGuard|31|-|501;thunderPunch|36|1|9;icePunch|36|2|8;firePunch|36|3|7;skyUppercut|41|-|327;megaPunch|46|-|5;detect|51|-|197;focusPunch|56|-|264;counter|61|-|68;closeCombat|66|-|370"
        -- END B2W2 LEARNSET
    },
    lickitung = {
        name = "LICKITUNG", dex = 108, type = "normal", type2 = nil,
        baseHP = 90, baseAtk = 55, baseDef = 75, baseSpA = 60, baseSpD = 75, baseSpe = 30, baseExp = 77,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "lick|1|-|122;supersonic|5|-|48;defenseCurl|9|-|111;knockOff|13|-|282;wrap|17|-|35;stomp|21|-|23;disable|25|-|50;slam|29|-|21;rollout|33|-|205;chipAway|37|-|498;meFirst|41|-|382;refresh|45|-|287;screech|49|-|103;powerWhip|53|-|438;wringOut|57|-|378"
        -- END B2W2 LEARNSET
    },
    koffing = {
        name = "KOFFING", dex = 109, type = "poison", type2 = nil,
        baseHP = 40, baseAtk = 65, baseDef = 95, baseSpA = 60, baseSpD = 45, baseSpe = 35, baseExp = 68,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "poisonGas|1|1|139;tackle|1|2|33;smog|4|-|123;smokescreen|7|-|108;assurance|12|-|372;clearSmog|15|-|499;sludge|18|-|124;selfDestruct|23|-|120;haze|26|-|114;gyroBall|29|-|360;sludgeBomb|34|-|188;explosion|37|-|153;destinyBond|40|-|194;memento|45|-|262"
        -- END B2W2 LEARNSET
    },
    weezing = {
        name = "WEEZING", dex = 110, type = "poison", type2 = nil,
        baseHP = 65, baseAtk = 90, baseDef = 120, baseSpA = 85, baseSpD = 70, baseSpe = 60, baseExp = 172,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "poisonGas|1|1|139;tackle|1|2|33;smog|1|3|123;smokescreen|1|4|108;smog|4|-|123;smokescreen|7|-|108;assurance|12|-|372;clearSmog|15|-|499;sludge|18|-|124;selfDestruct|23|-|120;haze|26|-|114;doubleHit|29|-|458;sludgeBomb|34|-|188;explosion|40|-|153;destinyBond|46|-|194;memento|54|-|262"
        -- END B2W2 LEARNSET
    },
    rhyhorn = {
        name = "RHYHORN", dex = 111, type = "ground", type2 = "rock",
        baseHP = 80, baseAtk = 85, baseDef = 95, baseSpA = 30, baseSpD = 30, baseSpe = 25, baseExp = 69,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "hornAttack|1|1|30;tailWhip|1|2|39;stomp|8|-|23;furyAttack|12|-|31;scaryFace|19|-|184;rockBlast|23|-|350;bulldoze|30|-|523;chipAway|34|-|498;takeDown|41|-|36;drillRun|45|-|529;stoneEdge|52|-|444;earthquake|56|-|89;hornDrill|63|-|32;megahorn|67|-|224"
        -- END B2W2 LEARNSET
    },
    rhydon = {
        name = "RHYDON", dex = 112, type = "ground", type2 = "rock",
        baseHP = 105, baseAtk = 130, baseDef = 120, baseSpA = 45, baseSpD = 45, baseSpe = 40, baseExp = 170,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "hornAttack|1|1|30;tailWhip|1|2|39;stomp|1|3|23;furyAttack|1|4|31;stomp|9|-|23;furyAttack|12|-|31;scaryFace|19|-|184;rockBlast|23|-|350;bulldoze|30|-|523;chipAway|34|-|498;takeDown|41|-|36;hammerArm|42|-|359;drillRun|47|-|529;stoneEdge|56|-|444;earthquake|62|-|89;hornDrill|71|-|32;megahorn|77|-|224"
        -- END B2W2 LEARNSET
    },
    chansey = {
        name = "CHANSEY", dex = 113, type = "normal", type2 = nil,
        baseHP = 250, baseAtk = 5, baseDef = 5, baseSpA = 35, baseSpD = 105, baseSpe = 50, baseExp = 395,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "defenseCurl|1|1|111;pound|1|2|1;growl|1|3|45;tailWhip|5|-|39;refresh|9|-|287;doubleSlap|12|-|3;softBoiled|16|-|135;bestow|20|-|516;minimize|23|-|107;takeDown|27|-|36;sing|31|-|47;fling|34|-|374;healPulse|38|-|505;eggBomb|42|-|121;lightScreen|46|-|113;healingWish|50|-|361;doubleEdge|54|-|38"
        -- END B2W2 LEARNSET
    },
    tangela = {
        name = "TANGELA", dex = 114, type = "grass", type2 = nil,
        baseHP = 65, baseAtk = 55, baseDef = 115, baseSpA = 100, baseSpD = 40, baseSpe = 60, baseExp = 87,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "ingrain|1|1|275;constrict|1|2|132;sleepPowder|4|-|79;vineWhip|7|-|22;absorb|10|-|71;poisonPowder|14|-|77;bind|17|-|20;growth|20|-|74;megaDrain|23|-|72;knockOff|27|-|282;stunSpore|30|-|78;naturalGift|33|-|363;gigaDrain|36|-|202;ancientPower|40|-|246;slam|43|-|21;tickle|46|-|321;wringOut|49|-|378;powerWhip|53|-|438"
        -- END B2W2 LEARNSET
    },
    kangaskhan = {
        name = "KANGASKHAN", dex = 115, type = "normal", type2 = nil,
        baseHP = 105, baseAtk = 95, baseDef = 80, baseSpA = 40, baseSpD = 80, baseSpe = 90, baseExp = 172,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "cometPunch|1|1|4;leer|1|2|43;fakeOut|7|-|252;tailWhip|10|-|39;bite|13|-|44;doubleHit|19|-|458;rage|22|-|99;megaPunch|25|-|5;chipAway|31|-|498;dizzyPunch|34|-|146;crunch|37|-|242;endure|43|-|203;outrage|46|-|200;suckerPunch|49|-|389;reversal|55|-|179"
        -- END B2W2 LEARNSET
    },
    horsea = {
        name = "HORSEA", dex = 116, type = "water", type2 = nil,
        baseHP = 30, baseAtk = 40, baseDef = 70, baseSpA = 70, baseSpD = 25, baseSpe = 60, baseExp = 59,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "bubble|1|-|145;smokescreen|4|-|108;leer|8|-|43;waterGun|11|-|55;focusEnergy|14|-|116;bubbleBeam|18|-|61;agility|23|-|97;twister|26|-|239;brine|30|-|362;hydroPump|35|-|56;dragonDance|38|-|349;dragonPulse|42|-|406"
        -- END B2W2 LEARNSET
    },
    seadra = {
        name = "SEADRA", dex = 117, type = "water", type2 = nil,
        baseHP = 55, baseAtk = 65, baseDef = 95, baseSpA = 95, baseSpD = 45, baseSpe = 85, baseExp = 154,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "bubble|1|1|145;smokescreen|1|2|108;leer|1|3|43;waterGun|1|4|55;smokescreen|4|-|108;leer|8|-|43;waterGun|11|-|55;focusEnergy|14|-|116;bubbleBeam|18|-|61;agility|23|-|97;twister|26|-|239;brine|30|-|362;hydroPump|40|-|56;dragonDance|48|-|349;dragonPulse|57|-|406"
        -- END B2W2 LEARNSET
    },
    goldeen = {
        name = "GOLDEEN", dex = 118, type = "water", type2 = nil,
        baseHP = 45, baseAtk = 67, baseDef = 60, baseSpA = 35, baseSpD = 50, baseSpe = 63, baseExp = 64,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "peck|1|1|64;tailWhip|1|2|39;waterSport|1|3|346;supersonic|7|-|48;hornAttack|11|-|30;waterPulse|17|-|352;flail|21|-|175;aquaRing|27|-|392;furyAttack|31|-|31;waterfall|37|-|127;hornDrill|41|-|32;agility|47|-|97;soak|51|-|487;megahorn|57|-|224"
        -- END B2W2 LEARNSET
    },
    seaking = {
        name = "SEAKING", dex = 119, type = "water", type2 = nil,
        baseHP = 80, baseAtk = 92, baseDef = 65, baseSpA = 65, baseSpD = 80, baseSpe = 68, baseExp = 158,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "poisonJab|1|1|398;peck|1|2|64;tailWhip|1|3|39;waterSport|1|4|346;supersonic|1|5|48;supersonic|7|-|48;hornAttack|11|-|30;waterPulse|17|-|352;flail|21|-|175;aquaRing|27|-|392;furyAttack|31|-|31;waterfall|40|-|127;hornDrill|47|-|32;agility|56|-|97;soak|63|-|487;megahorn|72|-|224"
        -- END B2W2 LEARNSET
    },
    staryu = {
        name = "STARYU", dex = 120, type = "water", type2 = nil,
        baseHP = 30, baseAtk = 45, baseDef = 55, baseSpA = 70, baseSpD = 55, baseSpe = 85, baseExp = 68,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "tackle|1|1|33;harden|1|2|106;waterGun|6|-|55;rapidSpin|10|-|229;recover|12|-|105;camouflage|15|-|293;swift|18|-|129;bubbleBeam|22|-|61;minimize|25|-|107;gyroBall|30|-|360;lightScreen|33|-|113;brine|36|-|362;reflectType|40|-|513;powerGem|43|-|408;cosmicPower|48|-|322;hydroPump|52|-|56"
        -- END B2W2 LEARNSET
    },
    starmie = {
        name = "STARMIE", dex = 121, type = "water", type2 = "psychic",
        baseHP = 60, baseAtk = 75, baseDef = 85, baseSpA = 100, baseSpD = 85, baseSpe = 115, baseExp = 182,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "waterGun|1|1|55;rapidSpin|1|2|229;recover|1|3|105;swift|1|4|129;confuseRay|22|-|109"
        -- END B2W2 LEARNSET
    },
    mr = {
        name = "MR", dex = 122, type = "psychic", type2 = nil,
        baseHP = 40, baseAtk = 45, baseDef = 65, baseSpA = 100, baseSpD = 120, baseSpe = 90, baseExp = 161,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "magicalLeaf|1|1|345;quickGuard|1|2|501;wideGuard|1|3|469;powerSwap|1|4|384;guardSwap|1|5|385;barrier|1|6|112;confusion|1|7|93;copycat|4|-|383;meditate|8|-|96;doubleSlap|11|-|3;mimic|15|1|102;psywave|15|2|149;encore|18|-|227;lightScreen|22|1|113;reflect|22|2|115;psybeam|25|-|60;substitute|29|-|164;recycle|32|-|278;trick|36|-|271;psychic|39|-|94;rolePlay|43|-|272;batonPass|46|-|226;safeguard|50|-|219"
        -- END B2W2 LEARNSET
    },
    scyther = {
        name = "SCYTHER", dex = 123, type = "bug", type2 = "flying",
        baseHP = 70, baseAtk = 110, baseDef = 80, baseSpA = 55, baseSpD = 80, baseSpe = 105, baseExp = 100,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "vacuumWave|1|1|410;quickAttack|1|2|98;leer|1|3|43;focusEnergy|5|-|116;pursuit|9|-|228;falseSwipe|13|-|206;agility|17|-|97;wingAttack|21|-|17;furyCutter|25|-|210;slash|29|-|163;razorWind|33|-|13;doubleTeam|37|-|104;xScissor|41|-|404;nightSlash|45|-|400;doubleHit|49|-|458;airSlash|53|-|403;swordsDance|57|-|14;feint|61|-|364"
        -- END B2W2 LEARNSET
    },
    jynx = {
        name = "JYNX", dex = 124, type = "ice", type2 = "psychic",
        baseHP = 65, baseAtk = 50, baseDef = 35, baseSpA = 115, baseSpD = 95, baseSpe = 95, baseExp = 159,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "pound|1|1|1;lick|1|2|122;lovelyKiss|1|3|142;powderSnow|1|4|181;lick|5|-|122;lovelyKiss|8|-|142;powderSnow|11|-|181;doubleSlap|15|-|3;icePunch|18|-|8;heartStamp|21|-|531;meanLook|25|-|212;fakeTears|28|-|313;wakeUpSlap|33|-|358;avalanche|39|-|419;bodySlam|44|-|34;wringOut|49|-|378;perishSong|55|-|195;blizzard|60|-|59"
        -- END B2W2 LEARNSET
    },
    electabuzz = {
        name = "ELECTABUZZ", dex = 125, type = "electric", type2 = nil,
        baseHP = 65, baseAtk = 83, baseDef = 57, baseSpA = 95, baseSpD = 85, baseSpe = 105, baseExp = 172,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "quickAttack|1|1|98;leer|1|2|43;thunderShock|1|3|84;thunderShock|5|-|84;lowKick|8|-|67;swift|12|-|129;shockWave|15|-|351;thunderWave|19|-|86;electroBall|22|-|486;lightScreen|26|-|113;thunderPunch|29|-|9;discharge|36|-|435;screech|42|-|103;thunderbolt|49|-|85;thunder|55|-|87"
        -- END B2W2 LEARNSET
    },
    magmar = {
        name = "MAGMAR", dex = 126, type = "fire", type2 = nil,
        baseHP = 65, baseAtk = 95, baseDef = 57, baseSpA = 100, baseSpD = 85, baseSpe = 93, baseExp = 173,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "smog|1|1|123;leer|1|2|43;ember|1|3|52;ember|5|-|52;smokescreen|8|-|108;feintAttack|12|-|185;fireSpin|15|-|83;clearSmog|19|-|499;flameBurst|22|-|481;confuseRay|26|-|109;firePunch|29|-|7;lavaPlume|36|-|436;sunnyDay|42|-|241;flamethrower|49|-|53;fireBlast|55|-|126"
        -- END B2W2 LEARNSET
    },
    pinsir = {
        name = "PINSIR", dex = 127, type = "bug", type2 = nil,
        baseHP = 65, baseAtk = 125, baseDef = 100, baseSpA = 55, baseSpD = 70, baseSpe = 85, baseExp = 175,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "viceGrip|1|1|11;focusEnergy|1|2|116;bind|4|-|20;seismicToss|8|-|69;harden|11|-|106;revenge|15|-|279;brickBreak|18|-|280;vitalThrow|22|-|233;submission|26|-|66;xScissor|29|-|404;stormThrow|33|-|480;thrash|36|-|37;swordsDance|40|-|14;superpower|43|-|276;guillotine|47|-|12"
        -- END B2W2 LEARNSET
    },
    tauros = {
        name = "TAUROS", dex = 128, type = "normal", type2 = nil,
        baseHP = 75, baseAtk = 100, baseDef = 95, baseSpA = 40, baseSpD = 70, baseSpe = 110, baseExp = 172,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "tackle|1|-|33;tailWhip|3|-|39;rage|5|-|99;hornAttack|8|-|30;scaryFace|11|-|184;pursuit|15|-|228;rest|19|-|156;payback|24|-|371;workUp|29|-|526;zenHeadbutt|35|-|428;takeDown|41|-|36;swagger|48|-|207;thrash|55|-|37;gigaImpact|63|-|416"
        -- END B2W2 LEARNSET
    },
    magikarp = {
        name = "MAGIKARP", dex = 129, type = "water", type2 = nil,
        baseHP = 20, baseAtk = 10, baseDef = 55, baseSpA = 15, baseSpD = 20, baseSpe = 80, baseExp = 40,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "splash|1|-|150;tackle|15|-|33;flail|30|-|175"
        -- END B2W2 LEARNSET
    },
    gyarados = {
        name = "GYARADOS", dex = 130, type = "water", type2 = "flying",
        baseHP = 95, baseAtk = 125, baseDef = 79, baseSpA = 60, baseSpD = 100, baseSpe = 81, baseExp = 189,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "thrash|1|-|37;bite|20|-|44;dragonRage|23|-|82;leer|26|-|43;twister|29|-|239;iceFang|32|-|423;aquaTail|35|-|401;rainDance|38|-|240;hydroPump|41|-|56;dragonDance|44|-|349;hyperBeam|47|-|63"
        -- END B2W2 LEARNSET
    },
    lapras = {
        name = "LAPRAS", dex = 131, type = "water", type2 = "ice",
        baseHP = 130, baseAtk = 85, baseDef = 80, baseSpA = 85, baseSpD = 95, baseSpe = 60, baseExp = 187,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "sing|1|1|47;growl|1|2|45;waterGun|1|3|55;mist|4|-|54;confuseRay|7|-|109;iceShard|10|-|420;waterPulse|14|-|352;bodySlam|18|-|34;rainDance|22|-|240;perishSong|27|-|195;iceBeam|32|-|58;brine|37|-|362;safeguard|43|-|219;hydroPump|49|-|56;sheerCold|55|-|329"
        -- END B2W2 LEARNSET
    },
    ditto = {
        name = "DITTO", dex = 132, type = "normal", type2 = nil,
        baseHP = 48, baseAtk = 48, baseDef = 48, baseSpA = 48, baseSpD = 48, baseSpe = 48, baseExp = 101,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "transform|1|-|144"
        -- END B2W2 LEARNSET
    },
    eevee = {
        name = "EEVEE", dex = 133, type = "normal", type2 = nil,
        baseHP = 55, baseAtk = 55, baseDef = 50, baseSpA = 45, baseSpD = 65, baseSpe = 55, baseExp = 65,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "helpingHand|1|1|270;tackle|1|2|33;tailWhip|1|3|39;sandAttack|5|-|28;growl|9|-|45;quickAttack|13|-|98;bite|17|-|44;covet|21|-|343;takeDown|25|-|36;charm|29|-|204;batonPass|33|-|226;doubleEdge|37|-|38;lastResort|41|-|387;trumpCard|45|-|376"
        -- END B2W2 LEARNSET
    },
    vaporeon = {
        name = "VAPOREON", dex = 134, type = "water", type2 = nil,
        baseHP = 130, baseAtk = 65, baseDef = 60, baseSpA = 110, baseSpD = 95, baseSpe = 65, baseExp = 184,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "helpingHand|1|1|270;tackle|1|2|33;tailWhip|1|3|39;sandAttack|5|-|28;waterGun|9|-|55;quickAttack|13|-|98;waterPulse|17|-|352;auroraBeam|21|-|62;aquaRing|25|-|392;acidArmor|29|-|151;haze|33|-|114;muddyWater|37|-|330;lastResort|41|-|387;hydroPump|45|-|56"
        -- END B2W2 LEARNSET
    },
    jolteon = {
        name = "JOLTEON", dex = 135, type = "electric", type2 = nil,
        baseHP = 65, baseAtk = 65, baseDef = 60, baseSpA = 110, baseSpD = 95, baseSpe = 130, baseExp = 184,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "helpingHand|1|1|270;tackle|1|2|33;tailWhip|1|3|39;sandAttack|5|-|28;thunderShock|9|-|84;quickAttack|13|-|98;doubleKick|17|-|24;thunderFang|21|-|422;pinMissile|25|-|42;agility|29|-|97;thunderWave|33|-|86;discharge|37|-|435;lastResort|41|-|387;thunder|45|-|87"
        -- END B2W2 LEARNSET
    },
    flareon = {
        name = "FLAREON", dex = 136, type = "fire", type2 = nil,
        baseHP = 65, baseAtk = 130, baseDef = 60, baseSpA = 95, baseSpD = 110, baseSpe = 65, baseExp = 184,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "helpingHand|1|1|270;tackle|1|2|33;tailWhip|1|3|39;sandAttack|5|-|28;ember|9|-|52;quickAttack|13|-|98;bite|17|-|44;fireFang|21|-|424;fireSpin|25|-|83;scaryFace|29|-|184;smog|33|-|123;lavaPlume|37|-|436;lastResort|41|-|387;fireBlast|45|-|126"
        -- END B2W2 LEARNSET
    },
    porygon = {
        name = "PORYGON", dex = 137, type = "normal", type2 = nil,
        baseHP = 65, baseAtk = 60, baseDef = 70, baseSpA = 85, baseSpD = 75, baseSpe = 40, baseExp = 79,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "conversion2|1|1|176;tackle|1|2|33;conversion|1|3|160;sharpen|1|4|159;psybeam|7|-|60;agility|12|-|97;recover|18|-|105;magnetRise|23|-|393;signalBeam|29|-|324;recycle|34|-|278;discharge|40|-|435;lockOn|45|-|199;triAttack|51|-|161;magicCoat|56|-|277;zapCannon|62|-|192"
        -- END B2W2 LEARNSET
    },
    omanyte = {
        name = "OMANYTE", dex = 138, type = "rock", type2 = "water",
        baseHP = 35, baseAtk = 40, baseDef = 100, baseSpA = 90, baseSpD = 55, baseSpe = 35, baseExp = 71,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "constrict|1|1|132;withdraw|1|2|110;bite|7|-|44;waterGun|10|-|55;rollout|16|-|205;leer|19|-|43;mudShot|25|-|341;brine|28|-|362;protect|34|-|182;ancientPower|37|-|246;tickle|43|-|321;rockBlast|46|-|350;shellSmash|52|-|504;hydroPump|55|-|56"
        -- END B2W2 LEARNSET
    },
    omastar = {
        name = "OMASTAR", dex = 139, type = "rock", type2 = "water",
        baseHP = 70, baseAtk = 60, baseDef = 125, baseSpA = 115, baseSpD = 70, baseSpe = 55, baseExp = 173,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "constrict|1|1|132;withdraw|1|2|110;bite|1|3|44;bite|7|-|44;waterGun|10|-|55;rollout|16|-|205;leer|19|-|43;mudShot|25|-|341;brine|28|-|362;protect|34|-|182;ancientPower|37|-|246;spikeCannon|40|-|131;tickle|48|-|321;rockBlast|56|-|350;shellSmash|67|-|504;hydroPump|75|-|56"
        -- END B2W2 LEARNSET
    },
    kabuto = {
        name = "KABUTO", dex = 140, type = "rock", type2 = "water",
        baseHP = 30, baseAtk = 80, baseDef = 90, baseSpA = 55, baseSpD = 45, baseSpe = 55, baseExp = 71,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "scratch|1|1|10;harden|1|2|106;absorb|6|-|71;leer|11|-|43;mudShot|16|-|341;sandAttack|21|-|28;endure|26|-|203;aquaJet|31|-|453;megaDrain|36|-|72;metalSound|41|-|319;ancientPower|46|-|246;wringOut|51|-|378"
        -- END B2W2 LEARNSET
    },
    kabutops = {
        name = "KABUTOPS", dex = 141, type = "rock", type2 = "water",
        baseHP = 60, baseAtk = 115, baseDef = 105, baseSpA = 65, baseSpD = 70, baseSpe = 80, baseExp = 173,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "feint|1|1|364;scratch|1|2|10;harden|1|3|106;absorb|1|4|71;leer|1|5|43;absorb|6|-|71;leer|11|-|43;mudShot|16|-|341;sandAttack|21|-|28;endure|26|-|203;aquaJet|31|-|453;megaDrain|36|-|72;slash|40|-|163;metalSound|45|-|319;ancientPower|54|-|246;wringOut|63|-|378;nightSlash|72|-|400"
        -- END B2W2 LEARNSET
    },
    aerodactyl = {
        name = "AERODACTYL", dex = 142, type = "rock", type2 = "flying",
        baseHP = 80, baseAtk = 105, baseDef = 65, baseSpA = 60, baseSpD = 75, baseSpe = 130, baseExp = 180,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "iceFang|1|1|423;fireFang|1|2|424;thunderFang|1|3|422;wingAttack|1|4|17;supersonic|1|5|48;bite|1|6|44;scaryFace|1|7|184;roar|9|-|46;agility|17|-|97;ancientPower|25|-|246;crunch|33|-|242;takeDown|41|-|36;skyDrop|49|-|507;ironHead|57|-|442;hyperBeam|65|-|63;rockSlide|73|-|157;gigaImpact|81|-|416"
        -- END B2W2 LEARNSET
    },
    snorlax = {
        name = "SNORLAX", dex = 143, type = "normal", type2 = nil,
        baseHP = 160, baseAtk = 110, baseDef = 65, baseSpA = 65, baseSpD = 110, baseSpe = 30, baseExp = 189,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "tackle|1|-|33;defenseCurl|4|-|111;amnesia|9|-|133;lick|12|-|122;bellyDrum|17|-|187;yawn|20|-|281;chipAway|25|-|498;rest|28|1|156;snore|28|2|173;sleepTalk|33|-|214;bodySlam|36|-|34;block|41|-|335;rollout|44|-|205;crunch|49|-|242;heavySlam|52|-|484;gigaImpact|57|-|416"
        -- END B2W2 LEARNSET
    },
    articuno = {
        name = "ARTICUNO", dex = 144, type = "ice", type2 = "flying",
        baseHP = 90, baseAtk = 85, baseDef = 100, baseSpA = 95, baseSpD = 125, baseSpe = 85, baseExp = 261,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "gust|1|1|16;powderSnow|1|2|181;mist|8|-|54;iceShard|15|-|420;mindReader|22|-|170;ancientPower|29|-|246;agility|36|-|97;iceBeam|43|-|58;reflect|50|-|115;roost|57|-|355;tailwind|64|-|366;blizzard|71|-|59;sheerCold|78|-|329;hail|85|-|258;hurricane|92|-|542"
        -- END B2W2 LEARNSET
    },
    zapdos = {
        name = "ZAPDOS", dex = 145, type = "electric", type2 = "flying",
        baseHP = 90, baseAtk = 90, baseDef = 85, baseSpA = 125, baseSpD = 90, baseSpe = 100, baseExp = 261,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "peck|1|1|64;thunderShock|1|2|84;thunderWave|8|-|86;detect|15|-|197;pluck|22|-|365;ancientPower|29|-|246;charge|36|-|268;agility|43|-|97;discharge|50|-|435;roost|57|-|355;lightScreen|64|-|113;drillPeck|71|-|65;thunder|78|-|87;rainDance|85|-|240;zapCannon|92|-|192"
        -- END B2W2 LEARNSET
    },
    moltres = {
        name = "MOLTRES", dex = 146, type = "fire", type2 = "flying",
        baseHP = 90, baseAtk = 100, baseDef = 90, baseSpA = 125, baseSpD = 85, baseSpe = 90, baseExp = 261,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "wingAttack|1|1|17;ember|1|2|52;fireSpin|8|-|83;agility|15|-|97;endure|22|-|203;ancientPower|29|-|246;flamethrower|36|-|53;safeguard|43|-|219;airSlash|50|-|403;roost|57|-|355;heatWave|64|-|257;solarBeam|71|-|76;skyAttack|78|-|143;sunnyDay|85|-|241;hurricane|92|-|542"
        -- END B2W2 LEARNSET
    },
    dratini = {
        name = "DRATINI", dex = 147, type = "dragon", type2 = nil,
        baseHP = 41, baseAtk = 64, baseDef = 45, baseSpA = 50, baseSpD = 50, baseSpe = 50, baseExp = 60,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "wrap|1|1|35;leer|1|2|43;thunderWave|5|-|86;twister|11|-|239;dragonRage|15|-|82;slam|21|-|21;agility|25|-|97;dragonTail|31|-|525;aquaTail|35|-|401;dragonRush|41|-|407;safeguard|45|-|219;dragonDance|51|-|349;outrage|55|-|200;hyperBeam|61|-|63"
        -- END B2W2 LEARNSET
    },
    dragonair = {
        name = "DRAGONAIR", dex = 148, type = "dragon", type2 = nil,
        baseHP = 61, baseAtk = 84, baseDef = 65, baseSpA = 70, baseSpD = 70, baseSpe = 70, baseExp = 147,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "wrap|1|1|35;leer|1|2|43;thunderWave|1|3|86;twister|1|4|239;thunderWave|5|-|86;twister|11|-|239;dragonRage|15|-|82;slam|21|-|21;agility|25|-|97;dragonTail|33|-|525;aquaTail|39|-|401;dragonRush|47|-|407;safeguard|53|-|219;dragonDance|61|-|349;outrage|67|-|200;hyperBeam|75|-|63"
        -- END B2W2 LEARNSET
    },
    dragonite = {
        name = "DRAGONITE", dex = 149, type = "dragon", type2 = "flying",
        baseHP = 91, baseAtk = 134, baseDef = 95, baseSpA = 100, baseSpD = 100, baseSpe = 80, baseExp = 270,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "firePunch|1|1|7;thunderPunch|1|2|9;roost|1|3|355;wrap|1|4|35;leer|1|5|43;thunderWave|1|6|86;twister|1|7|239;thunderWave|5|-|86;twister|11|-|239;dragonRage|15|-|82;slam|21|-|21;agility|25|-|97;dragonTail|33|-|525;aquaTail|39|-|401;dragonRush|47|-|407;safeguard|53|-|219;wingAttack|55|-|17;dragonDance|61|-|349;outrage|67|-|200;hyperBeam|75|-|63;hurricane|81|-|542"
        -- END B2W2 LEARNSET
    },
    mewtwo = {
        name = "MEWTWO", dex = 150, type = "psychic", type2 = nil,
        baseHP = 106, baseAtk = 110, baseDef = 90, baseSpA = 154, baseSpD = 90, baseSpe = 130, baseExp = 306,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "confusion|1|1|93;disable|1|2|50;barrier|1|3|112;swift|8|-|129;futureSight|15|-|248;psychUp|22|-|244;miracleEye|29|-|357;mist|36|-|54;psychoCut|43|-|427;amnesia|50|-|133;powerSwap|57|1|384;guardSwap|57|2|385;psychic|64|-|94;meFirst|71|-|382;recover|79|-|105;safeguard|86|-|219;auraSphere|93|-|396;psystrike|100|-|540"
        -- END B2W2 LEARNSET
    },
    mew = {
        name = "MEW", dex = 151, type = "psychic", type2 = nil,
        baseHP = 100, baseAtk = 100, baseDef = 100, baseSpA = 100, baseSpD = 100, baseSpe = 100, baseExp = 270,
        moves = false,
        -- BEGIN B2W2 LEARNSET
        learnset = "pound|1|1|1;reflectType|1|2|513;transform|1|3|144;megaPunch|10|-|5;metronome|20|-|118;psychic|30|-|94;barrier|40|-|112;ancientPower|50|-|246;amnesia|60|-|133;meFirst|70|-|382;batonPass|80|-|226;nastyPlot|90|-|417;auraSphere|100|-|396"
        -- END B2W2 LEARNSET
    },
}
PokemonLearnsets.install(pokemonData)

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
        Growth.battleAward(baseExpYield(defeated.species), defeated.level, self.level, trainerBattle, participants))
end
