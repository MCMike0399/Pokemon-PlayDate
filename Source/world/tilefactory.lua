-- ============================================================
-- TileFactory: Runtime tile generation using Shade system
-- ============================================================
-- Tiles are authored as 16x16 four-shade pixel grids (the Game
-- Boy metatile resolution) and rendered at native 32x32: each
-- authored pixel becomes a 2x2 block, but the LIGHT/DARK dither
-- patterns are applied in screen space, so the dots stay fine
-- instead of doubling into chunky 2x2 dots.
--
-- Grid shade codes:
--   .  WHITE  (ground, highlights, window shine)
--   1  LIGHT  (~12.5% dither — paths, glass, plank shadows)
--   2  DARK   (50% checkerboard — roofs, doors, tree canopy)
--   #  BLACK  (outlines, ridges, blades)

local gfx <const> = playdate.graphics

Class("TileFactory")

-- ============================================================
-- HELPERS
-- ============================================================

local SHADES <const> = { ["1"] = Shade.LIGHT, ["2"] = Shade.DARK, ["#"] = Shade.BLACK }

-- rows: 16 strings of 16 shade codes -> native 32x32 image
local function makeShadeTile(rows)
    local img = gfx.image.new(32, 32, gfx.kColorWhite)
    gfx.pushContext(img)
    for y = 1, 16 do
        local row = rows[y]
        assert(row and #row == 16, "tile row " .. y .. " must be 16 chars")
        local x = 1
        while x <= 16 do
            local c = row:sub(x, x)
            local x2 = x
            while x2 < 16 and row:sub(x2 + 1, x2 + 1) == c do x2 = x2 + 1 end
            local shade = SHADES[c]
            if shade then
                Shade.set(shade)
                gfx.fillRect((x - 1) * 2, (y - 1) * 2, (x2 - x + 1) * 2, 2)
            end
            x = x2 + 1
        end
    end
    Shade.reset()
    gfx.popContext()
    return img
end

-- fn(x, y) -> shade code, for tiles easier to express procedurally
local function makeShadeTileFn(fn)
    local rows = {}
    for y = 0, 15 do
        local chars = {}
        for x = 0, 15 do
            chars[x + 1] = fn(x, y)
        end
        rows[y + 1] = table.concat(chars)
    end
    return makeShadeTile(rows)
end

local function tuftTile(points)
    return makeShadeTileFn(function(x, y)
        for _, p in ipairs(points) do
            if p[1] == x and p[2] == y then return "#" end
        end
        return "."
    end)
end

-- ============================================================
-- PUBLIC API
-- ============================================================

function TileFactory.generateAll()
    local tiles = gfx.imagetable.new(NUM_TILE_TYPES)
    tiles:setImage(1,  TileFactory.grass())
    tiles:setImage(2,  TileFactory.path())
    tiles:setImage(3,  TileFactory.wall())
    tiles:setImage(4,  TileFactory.water())
    tiles:setImage(5,  TileFactory.tree())
    tiles:setImage(6,  TileFactory.door())
    tiles:setImage(7,  TileFactory.fence())
    tiles:setImage(8,  TileFactory.tallGrass())
    tiles:setImage(9,  TileFactory.roof())
    tiles:setImage(10, TileFactory.sign())
    tiles:setImage(11, TileFactory.flowers())
    tiles:setImage(12, TileFactory.shore())
    tiles:setImage(13, TileFactory.labWall())
    tiles:setImage(14, TileFactory.mailbox())
    tiles:setImage(15, TileFactory.roofLeft())
    tiles:setImage(16, TileFactory.roofRight())
    tiles:setImage(17, TileFactory.wallWindow())
    tiles:setImage(18, TileFactory.grassA())
    tiles:setImage(19, TileFactory.grassB())
    tiles:setImage(20, TileFactory.grassC())
    return tiles
end

-- ROM TILE GENERATION (using ColorMapper)

function TileFactory.generateFromROM(tilesetPath, tileIndices)
    local success = ColorMapper:loadTileset(tilesetPath)
    if not success then
        print('ERROR: Failed to load ROM tileset')
        return TileFactory.generateAll()
    end

    local tiles = gfx.imagetable.new(#tileIndices)
    for i, tileIndex in ipairs(tileIndices) do
        local tile = ColorMapper:getTile(tileIndex)
        if tile then
            tiles:setImage(i, tile)
        else
            tiles:setImage(i, TileFactory.grass())
        end
    end

    return tiles
end

-- ============================================================
-- TILE DEFINITIONS
-- ============================================================

-- 1: Grass — clean white ground (GB light gray = 1-bit white)
function TileFactory.grass()
    return gfx.image.new(32, 32, gfx.kColorWhite)
end

-- 18-20: Grass variants with decorative tufts
function TileFactory.grassA()
    return tuftTile({ {10, 11}, {11, 10} })
end

function TileFactory.grassB()
    return tuftTile({ {3, 5}, {4, 4}, {11, 12}, {12, 11} })
end

function TileFactory.grassC()
    return tuftTile({ {2, 4}, {3, 3}, {11, 7}, {12, 6}, {6, 13}, {7, 12} })
end

-- 2: Path — light-gray dithered dirt with dark pebble clusters
function TileFactory.path()
    return makeShadeTile({
        "1111111111111111",
        "1111111111111111",
        "111#211111111111",
        "1112211111##2111",
        "1111111111122111",
        "1111111111111111",
        "1111111111111111",
        "11111111#2111111",
        "1111111122211111",
        "1111111111111111",
        "11##111111111111",
        "112211111111#211",
        "1111111111122111",
        "1111111111111111",
        "1111111111111111",
        "1111111111111111",
    })
end

-- 3: Wall — horizontal plank siding with shadowed seams + joints
function TileFactory.wall()
    return makeShadeTile({
        "################",
        "1111111111111111",
        ".......#........",
        ".......#........",
        "################",
        "1111111111111111",
        "...#.......#....",
        "...#.......#....",
        "################",
        "1111111111111111",
        ".......#........",
        ".......#........",
        "################",
        "1111111111111111",
        "...#.......#....",
        "...#.......#....",
    })
end

-- 4: Water — light water with staggered dark wave dashes
function TileFactory.water()
    return makeShadeTileFn(function(x, y)
        if y % 4 == 2 then
            local phase = ((y // 4) % 2) * 4
            if (x + phase) % 8 < 4 then return "#" end
        end
        return "1"
    end)
end

-- 5: Tree — full-width bushy canopy so borders tile into a forest wall
function TileFactory.tree()
    return makeShadeTile({
        "..####....####..",
        ".#2222#..#2222#.",
        "#211222##222222#",
        "#21122222222222#",
        "#11222222222222#",
        "#22222222222222#",
        "#22221122222222#",
        "#22222222222222#",
        "#22222222222222#",
        "#22211222222222#",
        "#22222222222222#",
        ".#222222222222#.",
        "..#22##22##22#..",
        "...##..##..##...",
        "......1##1......",
        "................",
    })
end

-- 6: Door — recessed dark doorway with white knob, plank lintel
function TileFactory.door()
    return makeShadeTile({
        "################",
        "1111111111111111",
        "................",
        "...##########...",
        "..#2222222222#..",
        "..#2222222222#..",
        "..#2222222222#..",
        "..#2222222222#..",
        "..#2222222.22#..",
        "..#2222222222#..",
        "..#2222222222#..",
        "..#2222222222#..",
        "..#2222222222#..",
        "..#2222222222#..",
        "..#2222222222#..",
        "..############..",
    })
end

-- 7: Fence — pickets with two rails (8px period for seamless tiling)
function TileFactory.fence()
    return makeShadeTile({
        "................",
        "................",
        ".##......##.....",
        ".##......##.....",
        "################",
        "2222222222222222",
        ".##......##.....",
        ".##......##.....",
        "################",
        "2222222222222222",
        ".##......##.....",
        ".##......##.....",
        ".##......##.....",
        ".11......11.....",
        "................",
        "................",
    })
end

-- 8: Tall Grass — layered zigzag blade rows over light ground
function TileFactory.tallGrass()
    return makeShadeTileFn(function(x, y)
        local band = y // 4
        local brow = y % 4
        local lx = (x + (band % 2) * 2) % 4
        if brow == 0 and lx == 1 then return "#" end
        if brow == 1 and (lx == 0 or lx == 2) then return "#" end
        return "1"
    end)
end

-- Shared roof shingle banding: ridge line, highlight, dark, dark
local function roofBand(y)
    local m = y % 4
    if m == 0 then return "#" end
    if m == 1 then return "1" end
    return "2"
end

-- 9: Roof — horizontal shingle bands
function TileFactory.roof()
    return makeShadeTileFn(function(_, y)
        return roofBand(y)
    end)
end

-- 15: Roof Left — '/' peaked end, white outside, shingles inside
function TileFactory.roofLeft()
    return makeShadeTileFn(function(x, y)
        local edge = 15 - y
        if x < edge then return "." end
        if x == edge then return "#" end
        return roofBand(y)
    end)
end

-- 16: Roof Right — '\' peaked end, shingles inside, white outside
function TileFactory.roofRight()
    return makeShadeTileFn(function(x, y)
        local edge = y
        if x > edge then return "." end
        if x == edge then return "#" end
        return roofBand(y)
    end)
end

-- 10: Sign — outlined board with text squiggles + post
function TileFactory.sign()
    return makeShadeTile({
        "................",
        ".############...",
        ".#..........#...",
        ".#.22.22.22..#..",
        ".#..........#...",
        ".#.22.22.22..#..",
        ".#..........#...",
        ".############...",
        "......##........",
        "......##........",
        "......##........",
        "......##........",
        "......##........",
        ".....1##1.......",
        "................",
        "................",
    })
end

-- 11: Flowers — outlined blooms with light centers + tuft
function TileFactory.flowers()
    return makeShadeTile({
        "................",
        "....#...........",
        "...#1#..........",
        "..#111#.........",
        "...#1#..........",
        "....#...........",
        "............#...",
        "...........#1#..",
        "..........#111#.",
        "...........#1#..",
        "............#...",
        "................",
        "..##............",
        "..#.............",
        "................",
        "................",
    })
end

-- 12: Shore — white land, gentle wavy black edge, water below
function TileFactory.shore()
    return makeShadeTileFn(function(x, y)
        local edgeY = 8 + math.floor(0.5 + math.sin(x * math.pi / 8))
        if y < edgeY then
            return "."
        elseif y == edgeY then
            return "#"
        else
            if y % 4 == 2 then
                local phase = ((y // 4) % 2) * 4
                if (x + phase) % 8 < 4 then return "#" end
            end
            return "1"
        end
    end)
end

-- 13: Lab Wall — taller stone courses with shadowed seams
function TileFactory.labWall()
    return makeShadeTile({
        "################",
        "1111111111111111",
        ".....#..........",
        ".....#..........",
        ".....#..........",
        "################",
        "1111111111111111",
        "..........#.....",
        "..........#.....",
        "..........#.....",
        "################",
        "1111111111111111",
        "...#............",
        "...#............",
        "...#............",
        "################",
    })
end

-- 14: Mailbox — outlined box with dark slot front + post
function TileFactory.mailbox()
    return makeShadeTile({
        "................",
        "...#######......",
        "..#1111111#.....",
        "..#1111111#.##..",
        "..#2222222#..#..",
        "..#2222222#.##..",
        "..#1111111####..",
        "...#######......",
        ".....##.........",
        ".....##.........",
        ".....##.........",
        ".....##.........",
        ".....##.........",
        "....1##1........",
        "................",
        "................",
    })
end

-- 17: Wall Window — plank wall with two-pane window
function TileFactory.wallWindow()
    return makeShadeTile({
        "################",
        "1111111111111111",
        "................",
        "...##########...",
        "...#..111111#...",
        "...#.1111111#...",
        "...#11111111#...",
        "...##########...",
        "...#11111111#...",
        "...#11111111#...",
        "...#11111111#...",
        "...##########...",
        "################",
        "1111111111111111",
        ".......#........",
        ".......#........",
    })
end
