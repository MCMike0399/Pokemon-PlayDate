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
--   Pb = Table with POKE BALL (starter choice)
--
-- Collision is auto-generated from tile types (no manual arrays!)
-- Interior rooms are padded with Vd to at least 13x8 tiles so the
-- camera clamp (which assumes map >= screen) keeps working.
--
-- Exit mats are EDGE doors (`edge = "down"`): the warp fires when the
-- player stands on the mat and walks down into the room edge, Gen 2/3
-- style — landing on the mat alone does nothing. Outside doors and
-- stairs stay step-triggered.

TILE_SIZE = 32
NUM_TILE_TYPES = 37

-- Zone registry tables are declared by world/zone and retain their identities.
AuthoredMaps = {}
local initialized = false

-- Called once by the root initialization coroutine before content or context.
function AuthoredMaps.initialize()
    if initialized then
        return
    end

    -- Pallet Town, Oak's Lab, Red's house and Blue's house are the imported
    -- kanto_* maps (kanto_pallet_town, kanto_oaks_lab, kanto_reds_house_1f,
    -- kanto_reds_house_2f, kanto_blues_house). Their hand-authored tile rows
    -- are retired. New Game starts in pokered:REDS_HOUSE_2F.

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
                name = "OAK",
                dialog = { "Welcome to the Test Zone!", "This is the original map.", "Explore freely!" },
                sprite = "oak",
            },
            {
                gridX = 13, gridY = 9,
                name = "BLUE",
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
    GameBootstrap.yieldIfDue()

    -- Default zone
    currentZone = zoneRegistry.test_zone

    initialized = true
end
