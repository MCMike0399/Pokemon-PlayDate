-- ============================================================
-- SpriteFactory: runtime overworld-sprite generation
-- ============================================================
-- The companion to TileFactory. Characters are authored as 16x16
-- four-shade grids (same convention as tiles: . white / 1 light /
-- 2 dark / # black) and rendered at native 32x32 through the shared
-- TileFactory.renderGrid, then given an ALPHA MASK so the character
-- shape sits transparently over the world.
--
-- The mask is a cell-level border flood-fill: a "." cell reachable
-- from the edge through other "." cells is OUTSIDE (transparent);
-- every other cell -- shaded cells and any "." enclosed by a solid
-- "#" outline -- is body (opaque). A body must therefore be sealed by
-- a continuous "#" outline or the fill leaks in.
--
-- Right-facing frames are the left frame flipped, exactly like the
-- old PNG pipeline. This replaces the Python generators; visuals are
-- verified with the autopilot "atlas" command (a contact sheet).

local gfx <const> = playdate.graphics

Class("SpriteFactory")

-- ------------------------------------------------------------
-- Core: grid -> masked 32x32 sprite
-- ------------------------------------------------------------

local function computeMask(grid)
    -- 4-connected flood-fill over 16x16 cells from the border, through
    -- "." cells only. Marked cells are transparent; the rest opaque.
    local outside = {}
    for y = 1, 16 do outside[y] = {} end
    local q = {}
    local function seed(x, y)
        if x >= 1 and x <= 16 and y >= 1 and y <= 16
           and not outside[y][x] and grid[y]:sub(x, x) == "." then
            outside[y][x] = true
            q[#q + 1] = x * 100 + y
        end
    end
    for x = 1, 16 do seed(x, 1); seed(x, 16) end
    for y = 1, 16 do seed(1, y); seed(16, y) end
    local head = 1
    while head <= #q do
        local v = q[head]; head = head + 1
        local x, y = v // 100, v % 100
        seed(x - 1, y); seed(x + 1, y); seed(x, y - 1); seed(x, y + 1)
    end

    -- Mask image: white = opaque (body), black = transparent (outside)
    local mask = gfx.image.new(32, 32, gfx.kColorBlack)
    gfx.pushContext(mask)
    gfx.setColor(gfx.kColorWhite)
    for y = 1, 16 do
        for x = 1, 16 do
            if not outside[y][x] then
                gfx.fillRect((x - 1) * 2, (y - 1) * 2, 2, 2)
            end
        end
    end
    gfx.popContext()
    return mask
end

function SpriteFactory.makeSprite(grid)
    assert(#grid == 16, "sprite grid must have 16 rows")
    local img = TileFactory.renderGrid(grid)
    img:setMaskImage(computeMask(grid))
    return img
end

-- Mirror a finished sprite (right = flipped left). Drawing the masked
-- source into a cleared image bakes the transparency in.
function SpriteFactory.flipped(img)
    local w, h = img:getSize()
    local out = gfx.image.new(w, h, gfx.kColorClear)
    gfx.pushContext(out)
    img:draw(0, 0, gfx.kImageFlippedX)
    gfx.popContext()
    return out
end

local make <const> = SpriteFactory.makeSprite
local flip <const> = SpriteFactory.flipped

-- ============================================================
-- PLAYER (RED) -- transcribed verbatim from the proven grids; the
-- atlas pixel-diff confirms these stay identical to the old PNGs.
-- ============================================================

local PLAYER <const> = {
    down = {
        "................",
        ".....######.....",
        "....#......#....",
        "...#........#...",
        "...#........#...",
        "..###......###..",
        "..############..",
        ".#.#........#.#.",
        ".#....#..#....#.",
        ".###..#..#..##..",
        ".#.##......#.#..",
        "..##########.#..",
        "...##.####..##..",
        "...#.##..##.#...",
        "...#...##...#...",
        "....###..###....",
    },
    down_walk = {
        "................",
        "................",
        ".....######.....",
        "....#......#....",
        "...#........#...",
        "...#........#...",
        "..###......###..",
        "..############..",
        ".#.#........#.#.",
        ".#....#..#....#.",
        "..##..#..#..###.",
        "..#.#......##.#.",
        "..#.##########..",
        "..##..####.##...",
        "....#..##.##....",
        ".....###........",
    },
    up = {
        "................",
        ".....######.....",
        "....#......#....",
        "...#........#...",
        "...#........#...",
        "..##........##..",
        "..###......###..",
        ".#.##########.#.",
        ".#..########..#.",
        ".###..####..##..",
        ".#.###....####..",
        "..###.####.#..#.",
        "...##......##...",
        "...#.######.#...",
        "...#...##...#...",
        "....###..###....",
    },
    up_walk = {
        "................",
        "................",
        ".....######.....",
        "....#......#....",
        "...#........#...",
        "...#........#...",
        "..##........##..",
        "..###......###..",
        ".#.##########.#.",
        ".#..########..#.",
        "..##..####..###.",
        "..####....###.#.",
        ".#..#.####.###..",
        ".#..#.....###...",
        "....#.####......",
        ".....###........",
    },
    left = {
        "................",
        ".....######.....",
        "....#......#....",
        "...#........#...",
        "..##........#...",
        ".#.........###..",
        "..##...#######..",
        "...#.#..######..",
        "...#.#..#..##...",
        "....#....##.#...",
        ".....#####..#...",
        "......##..#.#...",
        "......##..#.#...",
        ".....#..####....",
        ".....#....#.....",
        "......####......",
    },
    left_walk1 = {
        "................",
        "................",
        ".....######.....",
        "....#......#....",
        "...#........#...",
        "..##........#...",
        ".#.........###..",
        "..##...#######..",
        "...#.#..######..",
        "...#.#..#..##...",
        "....#....##.#...",
        ".....######.#...",
        "...######..##...",
        "..#..#..#..#.#..",
        "...#..#####..#..",
        "....###....##...",
    },
    left_walk2 = {
        "................",
        "................",
        ".....######.....",
        "....#......#....",
        "...#........#...",
        "..##........#...",
        ".#.........###..",
        "..##...#######..",
        "...#.#..######..",
        "...#.#..#..##...",
        "....#....##.#...",
        ".....######.#...",
        "...######..##...",
        "..#..#..#..#.#..",
        "...##.#####.##..",
        ".......###......",
    },
}

local stand = { down = make(PLAYER.down), up = make(PLAYER.up), left = make(PLAYER.left) }
stand.right = flip(stand.left)
local walk1 = { down = make(PLAYER.down_walk), up = make(PLAYER.up_walk), left = make(PLAYER.left_walk1) }
walk1.right = flip(walk1.left)
-- walk2 vertical frames are the walk frames X-flipped (Gen 1 lead-foot trick)
local walk2 = { down = flip(make(PLAYER.down_walk)), up = flip(make(PLAYER.up_walk)), left = make(PLAYER.left_walk2) }
walk2.right = flip(walk2.left)

SpriteFactory.playerStand = stand
SpriteFactory.playerWalk1 = walk1
SpriteFactory.playerWalk2 = walk2

-- ============================================================
-- NPCs -- down/up/left standing frames (right = flipped left). up/left
-- fall back to down until authored.
-- ============================================================

local NPC <const> = {}

-- Professor Oak: bushy white hair, glasses, open white lab coat over a
-- dark shirt. Light dither reads as grey hair; the coat is sealed top
-- and bottom by a black hem so the flood fill can't eat it.
NPC.oak = {
    down = {
        "................",
        ".....######.....",
        "....#111111#....",
        "...#11111111#...",
        "...#11111111#...",
        "...##111111##...",
        "....#......#....",
        "....#.#..#.#....",
        "....#......#....",
        "....#.####.#....",
        ".....#....#.....",
        "...##########...",
        "...#.2....2.#...",
        "...#..2222..#...",
        "...#........#...",
        "...##########...",
    },
    up = {  -- back: white hair fills the head, coat back
        "................",
        ".....######.....",
        "....#111111#....",
        "...#11111111#...",
        "...#11111111#...",
        "...#11111111#...",
        "...#11111111#...",
        "...##111111##...",
        ".....#....#.....",
        "...##########...",
        "...#........#...",
        "...#...##...#...",
        "...#........#...",
        "...#........#...",
        "...#........#...",
        "...##########...",
    },
    left = {  -- side profile facing left
        "................",
        "....#####.......",
        "...#11111#......",
        "..#1111111#.....",
        "..#1111111#.....",
        ".##11111#.......",
        "#1.#1111#.......",
        "#..#111#........",
        ".#.#####........",
        "..#######.......",
        "..#......#......",
        ".##.2....#......",
        ".#.......#......",
        ".#......##......",
        ".#......#.......",
        "..######........",
    },
}

-- Blue (rival): jagged spiky dark hair (the clearest tell vs Red's
-- smooth cap), white shirt with arms, dark trousers.
NPC.rival = {
    down = {
        "................",
        "...#..#..#.#....",
        "..############..",
        "..#22222222#....",
        "..###......###..",
        "..############..",
        ".#.#........#.#.",
        ".#....#..#....#.",
        ".###..#..#..##..",
        ".#.##......#.#..",
        "..##########.#..",
        "...##.####..##..",
        "...#.##..##.#...",
        "...#.2#..#2.#...",
        "...#.2#..#2.#...",
        "....###..###....",
    },
    up = {  -- back: spiky dark hair, shirt back
        "................",
        "...#..#..#.#....",
        "..############..",
        "..############..",
        "..############..",
        "..############..",
        "..############..",
        "..############..",
        "...########.....",
        ".#.##......#.#..",
        "..##########.#..",
        "...##.####..##..",
        "...#.##..##.#...",
        "...#.2#..#2.#...",
        "...#.2#..#2.#...",
        "....###..###....",
    },
    left = {  -- side: spiky hair, one eye
        "................",
        "..#..#.#........",
        ".#########......",
        "#222222###......",
        "#2222###........",
        ".####1#.........",
        ".#.#1#..........",
        ".###1#..........",
        "..####..........",
        ".######.........",
        "#......#........",
        ".#....##........",
        ".#.##..#........",
        ".#.#...#........",
        ".#.#..##........",
        "..##..#.........",
    },
}

-- Mom: shoulder-length dark hair, a dress that flares to the floor.
NPC.mom = {
    down = {
        "................",
        ".....######.....",
        "....########....",
        "...##222222##...",
        "...#2......2#...",
        "....#......#....",
        "....#.#..#.#....",
        "....#......#....",
        "...#2#....#2#...",
        "....#......#....",
        "...########.....",
        "..#........#....",
        "..#.222222.#....",
        ".#..222222..#...",
        ".#.22222222.#...",
        ".############...",
    },
    up = {  -- back: long dark hair, dress back
        "................",
        ".....######.....",
        "....########....",
        "...##222222##...",
        "...#22222222#...",
        "...#22222222#...",
        "...#22222222#...",
        "...#22222222#...",
        "...#22222222#...",
        "....#......#....",
        "...########.....",
        "..#........#....",
        "..#.222222.#....",
        ".#..222222..#...",
        ".#.22222222.#...",
        ".############...",
    },
    left = {  -- side: hair, dress
        "................",
        "....#####.......",
        "...#22222#......",
        "..#2222222#.....",
        "..#2222222#.....",
        ".#.#2222#2#.....",
        ".#.#222#22#.....",
        ".#..22#222#.....",
        "..#####22#......",
        "...####.........",
        "...#....#.......",
        "..#.....#.......",
        "..#.222.#.......",
        ".#..222..#......",
        ".#.2222..#......",
        "..######........",
    },
}

-- Daisy: long light hair past the shoulders, dress (lighter than Mom).
NPC.daisy = {
    down = {
        "................",
        ".....######.....",
        "....########....",
        "...#11111111#...",
        "...#1#....#1#...",
        "...#1#....#1#...",
        "....#.#..#.#....",
        "...#1........1#.",
        "...#1#....#1#...",
        "....#......#....",
        "...########.....",
        "..#........#....",
        "..#.111111.#....",
        ".#..111111..#...",
        ".#.11111111.#...",
        ".############...",
    },
    up = {  -- back: long light hair, dress back
        "................",
        ".....######.....",
        "....########....",
        "...#11111111#...",
        "...#11111111#...",
        "...#11111111#...",
        "...#11111111#...",
        "..#1111111111#..",
        "..#1111111111#..",
        "....#......#....",
        "...########.....",
        "..#........#....",
        "..#.111111.#....",
        ".#..111111..#...",
        ".#.11111111.#...",
        ".############...",
    },
    left = {  -- side: long light hair, dress
        "................",
        "....#####.......",
        "...#11111#......",
        "..#1111111#.....",
        "..#1111111#.....",
        ".#.#1111#1#.....",
        ".#.#111#11#.....",
        ".#..11#111#.....",
        "..####1111#.....",
        "...####11#......",
        "...#....#.......",
        "..#.....#.......",
        "..#.111.#.......",
        ".#..111..#......",
        ".#.1111..#......",
        "..######........",
    },
}

SpriteFactory.npc = {}
for key, frames in pairs(NPC) do
    local set = { down = make(frames.down) }
    set.up = frames.up and make(frames.up) or set.down
    set.left = frames.left and make(frames.left) or set.down
    set.right = frames.left and flip(set.left) or set.down
    SpriteFactory.npc[key] = set
end
