-- ============================================================
-- Zone definitions using declarative syntax
-- ============================================================
-- Tile codes:
--   .  = Grass    Pa = Path     Wa = Wall     Wt = Water
--   Tr = Tree     Dr = Door     Fn = Fence    TG = Tall Grass
--   Rf = Roof     Sg = Sign     Fl = Flowers  Sh = Shore
--   LW = Lab Wall Mb = Mailbox  RL = Roof Left RR = Roof Right
--   WW = Wall Window
-- Interior codes:
--   Fo = Floor    IW = Int Wall Ma = Door Mat Tb = Table
--   Bk = Bookshelf Tv = TV      Pl = Plant    St = Stairs
--   Bd = Bed      PC = PC desk  LM = Lab Machine Vd = Void
--
-- Collision is auto-generated from tile types (no manual arrays!)
-- Interior rooms are padded with Vd to at least 13x8 tiles so the
-- camera clamp (which assumes map >= screen) keeps working.

TILE_SIZE = 32
NUM_TILE_TYPES = 36

-- ============================================================
-- PALLET TOWN (faithful Gen I recreation, 20x18)
-- ============================================================
registerZone("pallet_town", Zone({
    name = "Pallet Town",
    spawn = { x = 5, y = 6 },

    tileRows = {
    --  0  1  2  3  4  5  6  7  8  9  10 11 12 13 14 15 16 17 18 19
        "Tr Tr Tr Tr Tr Tr Tr Tr Tr Pa Pa Tr Tr Tr Tr Tr Tr Tr Tr Tr", -- 0  north border + Route 1 gap
        "Tr .  .  .  .  .  .  .  TG TG TG TG .  .  .  .  .  .  .  Tr", -- 1  Route 1 tall grass at the exit
        "Tr .  .  .  .  .  .  .  TG TG TG TG .  .  .  .  .  .  .  Tr", -- 2  (walk north into it, Gen 1 style)
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
        "Tr .  .  Fn Fn Fn .  .  .  .  .  .  .  .  Fn Fn Fn .  .  Tr", -- 13 garden fences (Gen 1 style)
        "Tr .  .  Fl Fl Fl .  .  .  .  .  .  .  .  Fl Fl Fl .  .  Tr", -- 14 flower beds under the fences
        "Tr .  .  .  .  .  Sh Sh Sh Sh Sh Sh Sh Sh .  .  .  .  .  Tr", -- 15 shore
        "Tr .  .  .  .  .  Wt Wt Wt Wt Wt Wt Wt Wt .  .  .  .  .  Tr", -- 16 water (Route 21)
        "Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr Tr", -- 17 south border
    },

    npcs = {
        {
            -- Rival loiters outside his house (Oak is inside the lab)
            gridX = 12, gridY = 6,
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
        { label = "Tall Grass",    x = 9,  y = 1  },
        { label = "Shore",         x = 9,  y = 15 },
        { label = "Route 1 Exit",  x = 9,  y = 0  },
    },

    doors = {
        { x = 5,  y = 5,  to = "reds_house",  toX = 3, toY = 7, facing = "up" },
        { x = 13, y = 5,  to = "blues_house", toX = 3, toY = 7, facing = "up" },
        { x = 10, y = 11, to = "oaks_lab",    toX = 5, toY = 9, facing = "up" },
    },
}))

-- ============================================================
-- INTERIORS — Red's house (1F + 2F), Blue's house, Oak's lab.
-- Rooms sit inside a Vd (void) surround; exit mats and stairs are
-- door defs back to the overworld / between floors.
-- ============================================================

registerZone("reds_house", Zone({
    name = "Red's House 1F",
    spawn = { x = 3, y = 7, facing = "up" },

    tileRows = {
    --  0  1  2  3  4  5  6  7  8  9  10 11 12
        "Vd Vd Vd Vd Vd Vd Vd Vd Vd Vd Vd Vd Vd", -- 0
        "Vd Vd IW IW IW IW IW IW IW IW Vd Vd Vd", -- 1  back wall
        "Vd Vd Fo Fo Tv Fo Fo Fo Fo St Vd Vd Vd", -- 2  TV + stairs up
        "Vd Vd Fo Fo Fo Fo Fo Fo Fo Fo Vd Vd Vd", -- 3
        "Vd Vd Fo Tb Tb Fo Fo Fo Fo Fo Vd Vd Vd", -- 4  dining table (Mom beside)
        "Vd Vd Fo Fo Fo Fo Fo Fo Pl Fo Vd Vd Vd", -- 5
        "Vd Vd Fo Fo Fo Fo Fo Fo Fo Fo Vd Vd Vd", -- 6
        "Vd Vd Ma Ma Fo Fo Fo Fo Fo Fo Vd Vd Vd", -- 7  exit mats
    },

    npcs = {
        {
            gridX = 5, gridY = 4,
            name = "Mom",
            dialog = {
                "MOM: Right. All boys leave home someday.",
                "It said so on TV!",
                "Rest up before you head out, honey.",
            },
            sprite = "mom",
        },
    },

    warps = {
        { label = "Exit Mat", x = 3, y = 7 },
        { label = "Stairs",   x = 9, y = 2 },
    },

    doors = {
        { x = 2, y = 7, to = "pallet_town",   toX = 5, toY = 5, facing = "down" },
        { x = 3, y = 7, to = "pallet_town",   toX = 5, toY = 5, facing = "down" },
        { x = 9, y = 2, to = "reds_house_2f", toX = 9, toY = 2, facing = "left" },
    },
}))

registerZone("reds_house_2f", Zone({
    name = "Red's Room",
    spawn = { x = 5, y = 4 },

    tileRows = {
    --  0  1  2  3  4  5  6  7  8  9  10 11 12
        "Vd Vd Vd Vd Vd Vd Vd Vd Vd Vd Vd Vd Vd", -- 0
        "Vd Vd IW IW IW IW IW IW IW IW Vd Vd Vd", -- 1  back wall
        "Vd Vd Bd Fo Fo Tv Fo PC Fo St Vd Vd Vd", -- 2  bed, SNES corner, PC, stairs
        "Vd Vd Fo Fo Fo Fo Fo Fo Fo Fo Vd Vd Vd", -- 3
        "Vd Vd Fo Fo Fo Fo Fo Fo Fo Fo Vd Vd Vd", -- 4
        "Vd Vd Fo Fo Fo Fo Fo Fo Pl Fo Vd Vd Vd", -- 5
        "Vd Vd Fo Fo Fo Fo Fo Fo Fo Fo Vd Vd Vd", -- 6
        "Vd Vd Vd Vd Vd Vd Vd Vd Vd Vd Vd Vd Vd", -- 7
    },

    warps = {
        { label = "Stairs", x = 9, y = 2 },
    },

    doors = {
        { x = 9, y = 2, to = "reds_house", toX = 9, toY = 2, facing = "left" },
    },
}))

registerZone("blues_house", Zone({
    name = "Blue's House",
    spawn = { x = 3, y = 7, facing = "up" },

    tileRows = {
    --  0  1  2  3  4  5  6  7  8  9  10 11 12
        "Vd Vd Vd Vd Vd Vd Vd Vd Vd Vd Vd Vd Vd", -- 0
        "Vd Vd IW IW IW IW IW IW IW IW Vd Vd Vd", -- 1  back wall
        "Vd Vd Fo Fo Fo Fo Fo Fo Bk Bk Vd Vd Vd", -- 2  bookshelves
        "Vd Vd Fo Fo Fo Fo Fo Fo Fo Fo Vd Vd Vd", -- 3
        "Vd Vd Fo Fo Tb Tb Fo Fo Fo Fo Vd Vd Vd", -- 4  table (Daisy beside)
        "Vd Vd Fo Fo Fo Fo Fo Fo Pl Fo Vd Vd Vd", -- 5
        "Vd Vd Fo Fo Fo Fo Fo Fo Fo Fo Vd Vd Vd", -- 6
        "Vd Vd Ma Ma Fo Fo Fo Fo Fo Fo Vd Vd Vd", -- 7  exit mats
    },

    npcs = {
        {
            gridX = 6, gridY = 4,
            name = "Daisy",
            dialog = {
                "DAISY: Hi! My brother is out at Grandpa's lab.",
                "Pallet Town is so peaceful and pretty!",
            },
            sprite = "daisy",
        },
    },

    warps = {
        { label = "Exit Mat", x = 3, y = 7 },
    },

    doors = {
        { x = 2, y = 7, to = "pallet_town", toX = 13, toY = 5, facing = "down" },
        { x = 3, y = 7, to = "pallet_town", toX = 13, toY = 5, facing = "down" },
    },
}))

registerZone("oaks_lab", Zone({
    name = "Oak's Lab",
    spawn = { x = 5, y = 9, facing = "up" },

    tileRows = {
    --  0  1  2  3  4  5  6  7  8  9  10 11 12
        "Vd Vd Vd Vd Vd Vd Vd Vd Vd Vd Vd Vd Vd", -- 0
        "Vd IW IW IW IW IW IW IW IW IW IW Vd Vd", -- 1  back wall
        "Vd LM LM Fo Fo Fo Tb Tb Tb Bk Bk Vd Vd", -- 2  machine, starter table, shelves
        "Vd Fo Fo Fo Fo Fo Fo Fo Fo Fo Fo Vd Vd", -- 3  Oak stands here
        "Vd Fo Fo Fo Fo Fo Fo Fo Fo Fo Fo Vd Vd", -- 4
        "Vd Bk Bk Bk Bk Fo Fo Bk Bk Bk Bk Vd Vd", -- 5  library stacks
        "Vd Fo Fo Fo Fo Fo Fo Fo Fo Fo Fo Vd Vd", -- 6
        "Vd Bk Bk Bk Bk Fo Fo Bk Bk Bk Bk Vd Vd", -- 7  library stacks
        "Vd Pl Fo Fo Fo Fo Fo Fo Fo Fo Pl Vd Vd", -- 8
        "Vd Fo Fo Fo Fo Ma Ma Fo Fo Fo Fo Vd Vd", -- 9  exit mats
    },

    npcs = {
        {
            gridX = 5, gridY = 3,
            name = "Prof. Oak",
            dialog = {
                "OAK: Welcome to my lab!",
                "I study Pokemon as a profession.",
                "The world of Pokemon awaits. Go catch 'em all!",
            },
            sprite = "oak",
        },
    },

    warps = {
        { label = "Exit Mat",      x = 5, y = 9 },
        { label = "Starter Table", x = 6, y = 3 },
    },

    doors = {
        { x = 5, y = 9, to = "pallet_town", toX = 10, toY = 11, facing = "down" },
        { x = 6, y = 9, to = "pallet_town", toX = 10, toY = 11, facing = "down" },
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
