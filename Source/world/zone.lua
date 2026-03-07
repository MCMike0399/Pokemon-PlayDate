-- ============================================================
-- Zone: Dart/Flutter-style declarative map definitions
-- ============================================================
-- Usage:
--   registerZone("pallet_town", Zone({
--       name = "Pallet Town",
--       spawn = { x = 5, y = 6 },
--       tileRows = {
--           "Tr Tr Tr Tr Pa Pa Tr Tr Tr Tr",
--           "Tr .  .  .  Pa Pa .  .  .  Tr",
--       },
--       npcs = {
--           { gridX=10, gridY=12, name="Prof. Oak", dialog={...}, sprite="oak" },
--       },
--       encounters = {
--           { species="rattata", minLevel=2, maxLevel=4, weight=40 },
--       },
--       warps = {
--           { label="Red's House", x=5, y=6 },
--       },
--   }))
-- ============================================================

Class("Zone")

-- 2-char tile codes -> IDs (readable map authoring)
-- Use "." as shorthand for grass (most common tile)
local CODES = {
    ["."]  = 1,   -- Grass (shorthand)
    Gr = 1,       -- Grass
    Pa = 2,       -- Path
    Wa = 3,       -- Wall
    Wt = 4,       -- Water
    Tr = 5,       -- Tree
    Dr = 6,       -- Door
    Fn = 7,       -- Fence
    TG = 8,       -- Tall Grass
    Rf = 9,       -- Roof
    Sg = 10,      -- Sign
    Fl = 11,      -- Flowers
    Sh = 12,      -- Shore
    LW = 13,      -- Lab Wall
    Mb = 14,      -- Mailbox
    RL = 15,      -- Roof Left (peaked edge)
    RR = 16,      -- Roof Right (peaked edge)
    WW = 17,      -- Wall Window
}

-- Auto-collision: true = solid, false = walkable
local SOLID = {
    [1]  = false, -- Grass
    [2]  = false, -- Path
    [3]  = true,  -- Wall
    [4]  = true,  -- Water
    [5]  = true,  -- Tree
    [6]  = false, -- Door
    [7]  = true,  -- Fence
    [8]  = false, -- Tall Grass
    [9]  = true,  -- Roof
    [10] = true,  -- Sign
    [11] = false, -- Flowers
    [12] = false, -- Shore
    [13] = true,  -- Lab Wall
    [14] = true,  -- Mailbox
    [15] = true,  -- Roof Left
    [16] = true,  -- Roof Right
    [17] = true,  -- Wall Window
    [18] = false, -- Grass variant A (1 tuft)
    [19] = false, -- Grass variant B (2 tufts)
    [20] = false, -- Grass variant C (3 tufts)
}

local TALL_GRASS_ID <const> = 8

-- Parse "Tr Tr Pa .  Dr Wa" -> {5, 5, 2, 1, 6, 3}
local function parseRow(str)
    local row = {}
    for code in str:gmatch("%S+") do
        local id = CODES[code]
        if not id then error("Unknown tile code: '" .. code .. "'") end
        row[#row + 1] = id
    end
    return row
end

function Zone:init(config)
    self.name = config.name or "Unnamed"
    self.spawn = config.spawn or { x = 1, y = 1 }
    self.npcDefs = config.npcs or {}
    self.encounters = config.encounters or {}
    self.encounterRate = config.encounterRate or 0.15
    self.warps = config.warps or {}

    -- Parse tile grid from string rows
    if config.tileRows then
        self.tiles = {}
        for _, rowStr in ipairs(config.tileRows) do
            self.tiles[#self.tiles + 1] = parseRow(rowStr)
        end
        self.height = #self.tiles
        self.width = #self.tiles[1]
    else
        self.tiles = config.tiles
        self.width = config.width
        self.height = config.height
    end

    -- Scatter grass tuft variants over plain grass (IDs 18-20)
    -- Original GB Pallet Town: mostly plain, very sparse tufts,
    -- with 3-tuft clusters near signs
    local GRASS_ID <const> = 1
    local SIGN_ID <const> = 10
    -- First pass: place 3-tuft grass (grassC=20) adjacent to signs
    for y = 1, self.height do
        for x = 1, self.width do
            if self.tiles[y][x] == SIGN_ID then
                local neighbors = {{x-1,y},{x+1,y},{x,y-1},{x,y+1},
                                   {x-1,y-1},{x+1,y-1},{x-1,y+1},{x+1,y+1}}
                for _, n in ipairs(neighbors) do
                    local nx, ny = n[1], n[2]
                    if ny >= 1 and ny <= self.height and nx >= 1 and nx <= self.width
                       and self.tiles[ny][nx] == GRASS_ID then
                        self.tiles[ny][nx] = 20  -- grassC (3 tufts)
                    end
                end
            end
        end
    end
    -- Second pass: very sparse random tufts (~12% of remaining grass)
    for y = 1, self.height do
        for x = 1, self.width do
            if self.tiles[y][x] == GRASS_ID then
                local hash = (x * 7 + y * 13 + x * y * 3) % 17
                if hash == 0 then
                    self.tiles[y][x] = 18  -- grassA (1 tuft)
                elseif hash == 5 then
                    self.tiles[y][x] = 19  -- grassB (2 tufts)
                end
            end
        end
    end

    -- Auto-generate collision from tile types
    self.collision = {}
    for y = 1, self.height do
        self.collision[y] = {}
        for x = 1, self.width do
            self.collision[y][x] = SOLID[self.tiles[y][x]] and 1 or 0
        end
    end
end

-- Spawn NPCs defined in this zone
function Zone:spawnNPCs(npcManager)
    npcManager:clear()
    local created = {}
    for _, def in ipairs(self.npcDefs) do
        local npc = NPC(def.gridX, def.gridY, def.name, def.dialog, def.battleData, def.sprite)
        if def.postBattleLines then
            npc.postBattleLines = def.postBattleLines
        end
        npcManager:addNPC(npc)
        created[def.name] = npc
    end
    return created
end

-- Check wild encounter at grid position
function Zone:checkEncounter(tileX, tileY)
    if tileY + 1 > self.height or tileX + 1 > self.width then return false end
    return self.tiles[tileY + 1][tileX + 1] == TALL_GRASS_ID
       and math.random() < self.encounterRate
end

-- Roll a random wild Pokemon from encounter table
function Zone:rollEncounter()
    local total = 0
    for _, e in ipairs(self.encounters) do total = total + e.weight end
    if total == 0 then return Pokemon("rattata", 3) end

    local roll = math.random(1, total)
    local sum = 0
    for _, e in ipairs(self.encounters) do
        sum = sum + e.weight
        if roll <= sum then
            return Pokemon(e.species, math.random(e.minLevel, e.maxLevel))
        end
    end
    return Pokemon("rattata", 3)
end

-- ============================================================
-- ZONE REGISTRY
-- ============================================================
zoneRegistry = {}
zoneList = {}
currentZone = nil

function registerZone(key, zone)
    zoneRegistry[key] = zone
    zoneList[#zoneList + 1] = key
end

function getCurrentZoneKey()
    for key, zone in pairs(zoneRegistry) do
        if zone == currentZone then return key end
    end
    return zoneList[1]
end

function switchZone(key)
    if zoneRegistry[key] then
        currentZone = zoneRegistry[key]
    end
end
