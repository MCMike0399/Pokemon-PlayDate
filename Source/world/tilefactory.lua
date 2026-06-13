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
-- With a baseImage the tile is drawn over a copy of it: "." paints
-- explicit white and " " leaves the base showing through (overlays)
local function makeShadeTile(rows, baseImage)
    local img = baseImage and baseImage:copy() or gfx.image.new(32, 32, gfx.kColorWhite)
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
            if not shade and baseImage and c == "." then
                shade = Shade.WHITE
            end
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
local function makeShadeTileFn(fn, baseImage)
    local rows = {}
    for y = 0, 15 do
        local chars = {}
        for x = 0, 15 do
            chars[x + 1] = fn(x, y)
        end
        rows[y + 1] = table.concat(chars)
    end
    return makeShadeTile(rows, baseImage)
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
    -- Roof corners composited over textured ground (resolved in Zone:init):
    -- the triangle outside the diagonal shows the surrounding terrain
    -- instead of punching a white hole into it
    tiles:setImage(21, TileFactory.roofLeft(TileFactory.path()))
    tiles:setImage(22, TileFactory.roofRight(TileFactory.path()))
    tiles:setImage(23, TileFactory.roofLeft(TileFactory.tallGrass()))
    tiles:setImage(24, TileFactory.roofRight(TileFactory.tallGrass()))
    -- Interior tiles (houses, Oak's lab)
    tiles:setImage(25, TileFactory.floor())
    tiles:setImage(26, TileFactory.interiorWall())
    tiles:setImage(27, TileFactory.mat())
    tiles:setImage(28, TileFactory.table())
    tiles:setImage(29, TileFactory.bookshelf())
    tiles:setImage(30, TileFactory.tv())
    tiles:setImage(31, TileFactory.plant())
    tiles:setImage(32, TileFactory.stairs())
    tiles:setImage(33, TileFactory.bed())
    tiles:setImage(34, TileFactory.pc())
    tiles:setImage(35, TileFactory.labMachine())
    tiles:setImage(36, TileFactory.void())
    tiles:setImage(37, TileFactory.tableBall())
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

-- Authentic Gen 1 water tile ($14 in pokered): dark field with two
-- diagonal white wave streaks. The GB animates it by rotating the
-- tile's bytes horizontally — `shift` reproduces that as a wrapped
-- sample offset (the streaks slide, the field stays put).
local WATER_ROWS <const> = {
    "2222..22",
    "222..222",
    "222..222",
    "2222..22",
    "22222...",
    "..222222",
    "22..2222",
    "222..222",
}

local function waterCode(x, y, shift)
    local row = WATER_ROWS[(y % 8) + 1]
    local i = (((x - (shift or 0)) % 8) + 8) % 8 + 1
    return row:sub(i, i)
end

-- 4: Water — Gen 1 streaked water, oscillates +-4px via shift
function TileFactory.water(shift)
    return makeShadeTileFn(function(x, y)
        return waterCode(x, y, shift)
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

-- Authentic Gen 1 tall grass tile ($52, the Route 1 encounter grass):
-- comma-shaped blade clumps, tiled 2x2 across the 16x16 metatile
local TALL_GRASS_ROWS <const> = {
    "......21",
    ".....2.2",
    "22..2112",
    "2.2.2121",
    "2.12222.",
    ".2.1221.",
    "112122..",
    ".11221..",
}

-- 8: Tall Grass
function TileFactory.tallGrass()
    return makeShadeTileFn(function(x, y)
        local row = TALL_GRASS_ROWS[(y % 8) + 1]
        return row:sub((x % 8) + 1, (x % 8) + 1)
    end)
end

-- Rustle variant for the step-into-grass splay (FRLG juice): the
-- blades part outward from the tile's center for a few frames
function TileFactory.tallGrassRustle()
    return makeShadeTileFn(function(x, y)
        local sx = (x < 8) and (x + 1) or (x - 1)
        local row = TALL_GRASS_ROWS[(y % 8) + 1]
        return row:sub((sx % 8) + 1, (sx % 8) + 1)
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

-- 15: Roof Left — '/' peaked end, shingles inside; outside the diagonal
-- shows the ground tile passed as base (white grass when omitted)
function TileFactory.roofLeft(base)
    return makeShadeTileFn(function(x, y)
        local edge = 15 - y
        if x < edge then return base and " " or "." end
        if x == edge then return "#" end
        return roofBand(y)
    end, base)
end

-- 16: Roof Right — '\' peaked end, shingles inside, ground outside
function TileFactory.roofRight(base)
    return makeShadeTileFn(function(x, y)
        local edge = y
        if x > edge then return base and " " or "." end
        if x == edge then return "#" end
        return roofBand(y)
    end, base)
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

-- Authentic Gen 1 flower frames (gfx/tilesets/flower/flower1-3.png):
-- the same blossom bobbing 1px (mid / down-right / up). One blossom
-- per 8x8 sub-tile, placed diagonally in the metatile over the
-- dither "mat" the original garden beds use.
local FLOWER_FRAMES <const> = {
    { "1......1", "...22...", "..2..2..", "12.22121",
      ".2.1112.", "2.2112.2", ".222222.", "1..22..1" },
    { "1......1", "....22..", "...2..2.", "1.2.2212",
      "222.1112", ".2221122", "..22222.", "1..22..1" },
    { "1..22..1", "..2..2..", ".2.2212.", "12.11121",
      "..2112..", "22.22.22", ".222222.", "1..22..1" },
}

-- 11: Flowers — two blossoms on a dither mat, 3 bob frames
function TileFactory.flowers(frame)
    local f = FLOWER_FRAMES[frame or 1]
    return makeShadeTileFn(function(x, y)
        if (x < 8) == (y < 8) then
            local row = f[(y % 8) + 1]
            return row:sub((x % 8) + 1, (x % 8) + 1)
        end
        return "1"
    end)
end

-- 12: Shore — white land over the Gen 1 scalloped diamond-chain
-- bank edging, animated water below (shares the water's shift)
function TileFactory.shore(shift)
    return makeShadeTileFn(function(x, y)
        if y < 6 then return "." end
        local m = x % 4
        if y == 6 or y == 8 then return (m == 1) and "#" or "." end
        if y == 7 then return (m == 0 or m == 2) and "#" or "." end
        return waterCode(x, y, shift)
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

-- ============================================================
-- INTERIOR TILES (25+)
-- ============================================================

-- 25: Floor — wood planks: seam line every 4 rows, staggered joints
function TileFactory.floor()
    return makeShadeTile({
        "............1...",
        "............1...",
        "............1...",
        "1111111111111111",
        "....1...........",
        "....1...........",
        "....1...........",
        "1111111111111111",
        "............1...",
        "............1...",
        "............1...",
        "1111111111111111",
        "....1...........",
        "....1...........",
        "....1...........",
        "1111111111111111",
    })
end

-- 26: Interior Wall — dark crown molding over paneled wainscot
function TileFactory.interiorWall()
    return makeShadeTile({
        "################",
        "2222222222222222",
        "2222222222222222",
        "################",
        "111#111#111#111#",
        "111#111#111#111#",
        "111#111#111#111#",
        "111#111#111#111#",
        "111#111#111#111#",
        "111#111#111#111#",
        "111#111#111#111#",
        "111#111#111#111#",
        "111#111#111#111#",
        "111#111#111#111#",
        "1111111111111111",
        "################",
    })
end

-- 27: Door Mat — bordered rug; standing on it shows the animated exit
-- arrow (Player.updateExitArrow) and walking into the edge leaves
function TileFactory.mat()
    return makeShadeTile({
        "################",
        "#..............#",
        "#.############.#",
        "#.#1111111111#.#",
        "#.#1111111111#.#",
        "#.#1111111111#.#",
        "#.#1111111111#.#",
        "#.#1111111111#.#",
        "#.#1111111111#.#",
        "#.#1111111111#.#",
        "#.#1111111111#.#",
        "#.#1111111111#.#",
        "#.#1111111111#.#",
        "#.############.#",
        "#..............#",
        "################",
    })
end

-- 28: Table / counter — white top with sheen, dark front panel.
-- One tile tall; tile horizontally for longer counters (lab benches)
function TileFactory.table()
    return makeShadeTile({
        "################",
        "#..............#",
        "#.111111111111.#",
        "#.111111111111.#",
        "#.111111111111.#",
        "#..............#",
        "################",
        "2222222222222222",
        "2222222222222222",
        "2222222222222222",
        "2222222222222222",
        "2222222222222222",
        "2222222222222222",
        "2222222222222222",
        "2222222222222222",
        "################",
    })
end

-- 29: Bookshelf — three shelf rows of alternating book spines
function TileFactory.bookshelf()
    return makeShadeTile({
        "################",
        "#11111111111111#",
        "################",
        "#.2#.2#.2#.2#.2#",
        "#.2#.2#.2#.2#.2#",
        "#.2#.2#.2#.2#.2#",
        "################",
        "#.2#.2#.2#.2#.2#",
        "#.2#.2#.2#.2#.2#",
        "#.2#.2#.2#.2#.2#",
        "################",
        "#2.#2.#2.#2.#2.#",
        "#2.#2.#2.#2.#2.#",
        "#2.#2.#2.#2.#2.#",
        "################",
        "2222222222222222",
    })
end

-- 30: TV — dark screen with a diagonal glint, feet below
function TileFactory.tv()
    return makeShadeTile({
        "................",
        ".##############.",
        ".#............#.",
        ".#.##########.#.",
        ".#.#..112222#.#.",
        ".#.#.1122222#.#.",
        ".#.#11222222#.#.",
        ".#.#12222222#.#.",
        ".#.#22222222#.#.",
        ".#.#22222222#.#.",
        ".#.##########.#.",
        ".#............#.",
        ".##############.",
        "................",
        "...##......##...",
        "................",
    })
end

-- 31: Potted Plant — bushy canopy over a striped pot
function TileFactory.plant()
    return makeShadeTile({
        "................",
        ".....######.....",
        "...##222222##...",
        "..#2222#2222#...",
        "..#222222222#...",
        "...##222222##...",
        ".....######.....",
        "......1##1......",
        "....########....",
        "....#111111#....",
        "....#111111#....",
        ".....#1111#.....",
        ".....#1111#.....",
        ".....######.....",
        "................",
        "................",
    })
end

-- 32: Stairs — tread bands (Gen 1 uses the same art up and down;
-- the door def decides where they lead)
function TileFactory.stairs()
    return makeShadeTileFn(function(_, y)
        local m = y % 4
        if m == 0 then return "#" end
        if m == 2 then return "1" end
        return "."
    end)
end

-- 33: Bed — outlined pillow up top, striped blanket below
function TileFactory.bed()
    return makeShadeTile({
        "################",
        "#..............#",
        "#..##########..#",
        "#..#........#..#",
        "#..##########..#",
        "#..............#",
        "################",
        "#22222222222222#",
        "#22222222222222#",
        "#11111111111111#",
        "#22222222222222#",
        "#22222222222222#",
        "#11111111111111#",
        "#22222222222222#",
        "#22222222222222#",
        "################",
    })
end

-- 34: PC — monitor on a desk with a keyboard
function TileFactory.pc()
    return makeShadeTile({
        "................",
        "...##########...",
        "...#11111111#...",
        "...#1......1#...",
        "...#1......1#...",
        "...#11111111#...",
        "...##########...",
        "......####......",
        "................",
        "################",
        "#..............#",
        "#.221122112211.#",
        "#..............#",
        "2222222222222222",
        "2222222222222222",
        "################",
    })
end

-- 35: Lab Machine — console with indicator windows and dials
function TileFactory.labMachine()
    return makeShadeTile({
        "################",
        "#11111111111111#",
        "#1############1#",
        "#1#..22..22..#1#",
        "#1#..22..22..#1#",
        "#1############1#",
        "#11111111111111#",
        "################",
        "#..............#",
        "#.##..##..##...#",
        "#.##..##..##...#",
        "#..............#",
        "#.111111111111.#",
        "#.111111111111.#",
        "#..............#",
        "################",
    })
end

-- 36: Void — solid black surround outside room bounds
function TileFactory.void()
    return gfx.image.new(32, 32, gfx.kColorBlack)
end

-- 37: Table with a POKE BALL on top (starter choice in Oak's lab);
-- the dark front panel matches the plain table so they tile together
function TileFactory.tableBall()
    return makeShadeTile({
        "################",
        "#.....####.....#",
        "#....#2222#....#",
        "#...#222222#...#",
        "#...########...#",
        "#....#.##.#....#",
        "################",
        "2222222222222222",
        "2222222222222222",
        "2222222222222222",
        "2222222222222222",
        "2222222222222222",
        "2222222222222222",
        "2222222222222222",
        "2222222222222222",
        "################",
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
