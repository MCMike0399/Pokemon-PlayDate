-- ============================================================
-- Zone definitions using declarative syntax
-- ============================================================
-- Tile codes:
--   .  = Grass    Pa = Path     Wa = Wall     Wt = Water
--   Tr = Tree     Dr = Door     Fn = Fence    TG = Tall Grass
--   Rf = Roof     Sg = Sign     Fl = Flowers  Sh = Shore
--   LW = Lab Wall Mb = Mailbox  RL = Roof Left RR = Roof Right
--   WW = Wall Window
--
-- Collision is auto-generated from tile types (no manual arrays!)

TILE_SIZE = 32
NUM_TILE_TYPES = 17

-- ============================================================
-- PALLET TOWN (faithful Gen I recreation, 20x18)
-- ============================================================
registerZone("pallet_town", Zone({
    name = "Pallet Town",
    spawn = { x = 5, y = 6 },

    tileRows = {
    --  0  1  2  3  4  5  6  7  8  9  10 11 12 13 14 15 16 17 18 19
        "Tr Tr Tr Tr Tr Tr Tr Tr Tr Pa Pa Tr Tr Tr Tr Tr Tr Tr Tr Tr", -- 0  north border + Route 1 gap
        "Tr TG TG TG .  .  .  .  .  Pa Pa .  .  .  .  .  TG TG TG Tr", -- 1  tall grass
        "Tr TG TG TG .  Fl .  .  .  Pa Pa .  .  .  Fl .  TG TG TG Tr", -- 2  tall grass + flowers
        "Tr .  .  RL Rf Rf RR .  .  .  .  .  RL Rf Rf RR .  .  .  Tr", -- 3  peaked house roofs
        "Tr .  .  Wa WW WW Wa .  .  .  .  .  Wa WW WW Wa .  .  .  Tr", -- 4  house walls + windows
        "Tr .  Mb Wa Wa Dr Wa .  .  .  .  .  Wa Dr Wa Wa Mb .  .  Tr", -- 5  doors + mailboxes
        "Tr .  .  .  .  Pa .  .  .  .  .  .  .  Pa .  .  .  .  .  Tr", -- 6  paths from doors
        "Tr .  Sg .  .  Pa Pa Pa Pa Pa Pa Pa Pa Pa .  .  .  Sg .  Tr", -- 7  main east-west path
        "Tr .  .  .  .  .  Pa Pa Pa Pa Pa Pa Pa Pa Pa .  .  .  .  Tr", -- 8  path wraps around lab
        "Tr .  .  .  .  .  Pa RL Rf Rf Rf Rf Rf RR Pa .  .  .  .  Tr", -- 9  peaked lab roof
        "Tr .  .  .  .  .  Pa LW WW LW LW LW WW LW Pa .  .  .  .  Tr", -- 10 lab walls + windows
        "Tr .  .  .  .  .  Pa LW LW LW Dr LW LW LW Pa .  .  .  .  Tr", -- 11 lab door + side paths
        "Tr .  .  .  .  .  Pa Pa Pa Pa Pa Pa Pa Pa Pa .  .  .  .  Tr", -- 12 path around lab
        "Tr .  .  Fn Fn Fn .  .  .  .  .  .  .  .  Fn Fn Fn .  .  Tr", -- 13 fences
        "Tr .  .  .  .  .  .  Fl .  .  .  .  .  Fl .  .  .  .  .  Tr", -- 14 flower beds
        "Tr .  .  .  .  .  Sh Sh Sh Sh Sh Sh Sh Sh .  .  .  .  .  Tr", -- 15 shore
        "Tr .  .  .  .  .  Wt Wt Wt Wt Wt Wt Wt Wt .  .  .  .  .  Tr", -- 16 water (Route 21)
        "Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr", -- 17 south border
    },

    npcs = {
        {
            gridX = 10, gridY = 12,
            name = "Prof. Oak",
            dialog = { "Welcome to Pallet Town!", "The world of Pokemon awaits!", "Take care out there!" },
            sprite = "oak",
        },
        {
            gridX = 13, gridY = 6,
            name = "Rival",
            dialog = { "Hey! Let's battle!" },
            battleData = { species = "charmander", level = 5 },
            sprite = "rival",
            postBattleLines = { "Good battle!" },
        },
    },

    encounters = {
        { species = "rattata",  minLevel = 2, maxLevel = 4, weight = 40 },
        { species = "pidgey",   minLevel = 2, maxLevel = 5, weight = 35 },
        { species = "caterpie", minLevel = 3, maxLevel = 5, weight = 15 },
        { species = "weedle",   minLevel = 3, maxLevel = 5, weight = 10 },
    },

    warps = {
        { label = "Red's House",   x = 5,  y = 6  },
        { label = "Blue's House",  x = 13, y = 6  },
        { label = "Oak's Lab",     x = 10, y = 12 },
        { label = "Main Path",     x = 9,  y = 7  },
        { label = "Tall Grass",    x = 2,  y = 1  },
        { label = "Shore",         x = 9,  y = 15 },
        { label = "Route 1 Exit",  x = 9,  y = 0  },
    },
}))

-- ============================================================
-- TEST ZONE (original PoC map, 20x15)
-- ============================================================
registerZone("test_zone", Zone({
    name = "Test Zone",
    spawn = { x = 6, y = 7 },

    tileRows = {
        "Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr",
        "Tr .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  Tr",
        "Tr .  RL Rf RR .  .  .  .  .  .  .  .  RL Rf RR .  .  .  Tr",
        "Tr .  Wa WW Wa .  .  .  .  .  .  .  .  Wa WW Wa .  .  .  Tr",
        "Tr .  Wa Dr Wa .  .  .  .  .  .  .  .  Wa Dr Wa .  .  .  Tr",
        "Tr .  .  Pa .  .  .  .  .  .  .  .  .  .  Pa .  .  .  .  Tr",
        "Tr .  .  Pa .  .  .  .  .  .  .  .  .  .  Pa .  .  .  .  Tr",
        "Tr .  .  Pa Pa Pa Pa Pa Pa Pa Pa Pa Pa Pa Pa .  .  .  .  Tr",
        "Tr .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  Tr",
        "Tr .  Fn Fn Fn Fn .  .  .  .  .  .  .  .  .  Fn Fn Fn .  Tr",
        "Tr .  .  .  .  .  .  .  Wt Wt Wt Wt TG TG TG TG TG TG .  Tr",
        "Tr .  .  .  .  .  .  .  Wt Wt Wt Wt TG TG TG TG TG TG .  Tr",
        "Tr .  .  .  .  .  .  .  Wt Wt Wt Wt TG TG TG TG TG TG .  Tr",
        "Tr .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  Tr",
        "Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr",
    },

    npcs = {
        {
            gridX = 10, gridY = 7,
            name = "Prof. Oak",
            dialog = { "Welcome to the Test Zone!", "This is the original map.", "Explore freely!" },
            sprite = "oak",
        },
        {
            gridX = 13, gridY = 9,
            name = "Rival",
            dialog = { "Hey! Let's battle!" },
            battleData = { species = "charmander", level = 5 },
            sprite = "rival",
            postBattleLines = { "Good battle!" },
        },
    },

    encounters = {
        { species = "rattata",  minLevel = 2, maxLevel = 4, weight = 40 },
        { species = "pidgey",   minLevel = 2, maxLevel = 5, weight = 35 },
        { species = "caterpie", minLevel = 3, maxLevel = 5, weight = 15 },
        { species = "weedle",   minLevel = 3, maxLevel = 5, weight = 10 },
    },

    warps = {
        { label = "Spawn (6,7)",   x = 6,  y = 7  },
        { label = "Oak (10,7)",    x = 9,  y = 7  },
        { label = "Rival (13,9)", x = 12, y = 9  },
        { label = "Pond (8,10)",   x = 7,  y = 10 },
        { label = "South (10,13)", x = 10, y = 13 },
    },
}))

-- Default zone
currentZone = zoneRegistry.pallet_town
