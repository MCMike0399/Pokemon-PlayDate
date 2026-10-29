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
--
-- Grid DATA lives in world/sprites/<character>.lua -- one file per
-- character (red/oak/rival/mom/daisy) so each can be tuned in
-- isolation. This file owns the shared make/mask/flip machinery and
-- assembles the grids into ready-to-draw images.

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

function SpriteFactory.makeSprite(grid, patternPhase)
    assert(#grid == 16, "sprite grid must have 16 rows")
    local img = TileFactory.renderGrid(grid, nil, patternPhase)
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

-- ------------------------------------------------------------
-- Grid data: one file per character, each assigns into this table.
-- ------------------------------------------------------------

SpriteFactory.grids = {}

import "world/sprites/red"
import "world/sprites/oak"
import "world/sprites/rival"
import "world/sprites/mom"
import "world/sprites/daisy"

-- ------------------------------------------------------------
-- Assemble: player (7 frames) + NPCs (down/up/left, right = flip).
-- ------------------------------------------------------------

-- Player imports capture these tables before startup; publish frames in place.
SpriteFactory.playerStand = {}
SpriteFactory.playerWalk1 = {}
SpriteFactory.playerWalk2 = {}
SpriteFactory.npc = {}

local initialized = false

local function copyFrames(target, frames)
    for direction, image in pairs(frames) do
        target[direction] = image
    end
end

-- Called once by the root initialization coroutine before content or actors.
function SpriteFactory.initialize()
    if initialized then
        return
    end

    -- PLAYER (RED)
    local P <const> = SpriteFactory.grids.red
    local stand = { down = make(P.down), up = make(P.up), left = make(P.left) }
    stand.right = flip(stand.left)
    GameBootstrap.yieldIfDue()
    local walk1 = { down = make(P.down_walk), up = make(P.up_walk), left = make(P.left_walk1) }
    walk1.right = flip(walk1.left)
    GameBootstrap.yieldIfDue()
    -- walk2 vertical frames are the walk frames X-flipped (Gen 1 lead-foot trick)
    local walk2 = { down = flip(make(P.down_walk)), up = flip(make(P.up_walk)), left = make(P.left_walk2) }
    walk2.right = flip(walk2.left)
    GameBootstrap.yieldIfDue()

    copyFrames(SpriteFactory.playerStand, stand)
    copyFrames(SpriteFactory.playerWalk1, walk1)
    copyFrames(SpriteFactory.playerWalk2, walk2)

    -- NPCs: up/left fall back to down until authored; right = flipped left.
    for _, key in ipairs({ "oak", "rival", "mom", "daisy" }) do
        local frames = SpriteFactory.grids[key]
        local set = { down = make(frames.down) }
        GameBootstrap.yieldIfDue()
        set.up = frames.up and make(frames.up) or set.down
        GameBootstrap.yieldIfDue()
        set.left = frames.left and make(frames.left) or set.down
        GameBootstrap.yieldIfDue()
        set.right = frames.left and flip(set.left) or set.down
        GameBootstrap.yieldIfDue()
        SpriteFactory.npc[key] = set
    end

    initialized = true
end
