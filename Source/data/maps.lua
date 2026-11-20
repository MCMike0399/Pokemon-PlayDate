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

-- Padded source collision, drawn with the existing floor/wall tiles.
-- Two cells stay open because the campaign already stands on them:
-- Pallet (9, 0) is the Route 1 seam, and Red's house (5, 5) faces MOM.
local function registerPalletZones()
    local function grid(file, pad, width)
        local data = assert(json.decodeFile("data/zRemainder/" .. file .. ".json"), file)
        local rows = assert(data.collision, file)
        local raw = #rows[1]
        local right = width - raw - pad
        assert(right >= 0, file)
        local cells = {}
        for y, row in ipairs(rows) do
            local line = {}
            for _ = 1, pad do line[#line + 1] = 1 end
            for x = 1, raw do line[#line + 1] = row[x] end
            for _ = 1, right do line[#line + 1] = 1 end
            cells[y] = line
        end
        return cells
    end
    local function rows(cells, openCode, blockedCode)
        local lines = {}
        for _, line in ipairs(cells) do
            local parts = {}
            for x = 1, #line do parts[x] = line[x] == 0 and openCode or blockedCode end
            lines[#lines + 1] = table.concat(parts, " ")
        end
        return lines
    end
    local function open(cells, x, y)
        cells[y + 1][x + 1] = 0
    end
    local function zone(key, file, name, pad, width, indoor, spawn, doors, npcs)
        local cells = grid(file, pad, width)
        if key == "pallet_town" then open(cells, 9, 0) end
        if key == "reds_house" then open(cells, 5, 5) end
        registerZone(key, Zone({
            name = name,
            id = key,
            spawn = spawn,
            tileRows = rows(cells, indoor and "Fo" or "Pa", indoor and "IW" or "Wa"),
            doors = doors,
            npcs = npcs,
        }))
        GameBootstrap.yieldIfDue()
    end
    zone("reds_house_2f", "RedsHouse2F", "Red's Room", 2, 13, true, { x = 5, y = 3, facing = "up" }, {
        { x = 9, y = 1, to = "reds_house", toX = 9, toY = 1, facing = "down" },
    })
    zone("reds_house", "RedsHouse1F", "Red's House 1F", 2, 13, true, { x = 3, y = 7, facing = "up" }, {
        { x = 4, y = 7, edge = "down", to = "pallet_town", toX = 5, toY = 6, facing = "down" },
        { x = 5, y = 7, edge = "down", to = "pallet_town", toX = 5, toY = 6, facing = "down" },
        { x = 9, y = 1, to = "reds_house_2f", toX = 9, toY = 1, facing = "up" },
    }, {
        { gridX = 5, gridY = 4, name = "MOM", sprite = "mom", dialog = { "MOM: Take care out there, honey!" } },
    })
    zone("blues_house", "BluesHouse", "Blue's House", 2, 13, true, { x = 5, y = 6, facing = "up" }, {
        { x = 4, y = 7, edge = "down", to = "pallet_town", toX = 13, toY = 6, facing = "down" },
        { x = 5, y = 7, edge = "down", to = "pallet_town", toX = 13, toY = 6, facing = "down" },
    }, {
        -- The town-map scene stands at (6, 5) facing this cell. Source object 2
        -- is also Daisy at (6, 4) before the house is padded.
        { gridX = 6, gridY = 4, name = "Daisy", sprite = "daisy", dialog = { "DAISY: Hi! My brother is out at Grandpa's lab." } },
    })
    zone("oaks_lab", "OaksLab", "Oak's Lab", 1, 13, true, { x = 6, y = 10, facing = "up" }, {
        { x = 5, y = 11, edge = "down", to = "pallet_town", toX = 12, toY = 12, facing = "down" },
        { x = 6, y = 11, edge = "down", to = "pallet_town", toX = 12, toY = 12, facing = "down" },
    }, {
        -- pret/pokered af519899 data/maps/objects/OaksLab.asm
        -- object_event 5, 2, SPRITE_OAK, STAY, DOWN, TEXT_OAKSLAB_OAK1
        -- Manifest padding 1 places him at (6, 2). Parcel handoff starts only for an actor named OAK.
        { gridX = 6, gridY = 2, name = "OAK", sprite = "oak", facing = "down" },
    })
    zone("pallet_town", "PalletTown", "Pallet Town", 0, 20, false, { x = 5, y = 6, facing = "down" }, {
        { x = 5, y = 5, to = "reds_house", toX = 5, toY = 6, facing = "up" },
        { x = 13, y = 5, to = "blues_house", toX = 5, toY = 6, facing = "up" },
        { x = 12, y = 11, to = "oaks_lab", toX = 6, toY = 10, facing = "up" },
    })
end

-- Called once by the root initialization coroutine before content or context.
function AuthoredMaps.initialize()
    if initialized then
        return
    end

    -- Pallet and its houses use the padded pokered collision. The registry
    -- keys are the ones sessions already store. Fly still names pokered:PALLET_TOWN.
    registerPalletZones()

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
