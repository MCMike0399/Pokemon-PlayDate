-- ============================================================
-- TileFactory: Runtime tile generation using Shade system
-- ============================================================
-- Generates all 17 tile types programmatically using the 4-shade
-- dithering system. No external PNG files needed.
--
-- Shade mapping (matching Game Boy Pallet Town):
--   WHITE  — ground, paths, wall/building backgrounds
--   DARK   — roofs, water (only mid-tone areas)
--   BLACK  — outlines, doors, tree canopy, mortar lines
--
-- Each tile is drawn at 16x16 and scaled 2x to 32x32 (TILE_SIZE).

local gfx <const> = playdate.graphics
local S <const> = 16

Class("TileFactory")

-- ============================================================
-- HELPERS
-- ============================================================

local function makeTile(shade, drawer)
    local img = gfx.image.new(S, S, gfx.kColorWhite)
    gfx.pushContext(img)
        if shade then
            Shade.set(shade)
            gfx.fillRect(0, 0, S, S)
        end
        if drawer then
            gfx.setColor(gfx.kColorBlack)
            drawer()
        end
    gfx.popContext()
    return img:scaledImage(2)
end

local function makePixelTile(pixelFn)
    local img = gfx.image.new(S, S, gfx.kColorWhite)
    gfx.pushContext(img)
        gfx.setColor(gfx.kColorBlack)
        for y = 0, S - 1 do
            for x = 0, S - 1 do
                if pixelFn(x, y) then
                    gfx.fillRect(x, y, 1, 1)
                end
            end
        end
    gfx.popContext()
    return img:scaledImage(2)
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
    return tiles
end

-- ============================================================
-- TILE DEFINITIONS
-- ============================================================

-- 1: Grass — clean white ground (GB light gray = 1-bit white)
function TileFactory.grass()
    return makeTile(nil)
end

-- 2: Path — same as grass (clean white)
function TileFactory.path()
    return makeTile(nil)
end

-- 3: Wall — white base + black mortar lines
function TileFactory.wall()
    return makeTile(nil, function()
        for _, y in ipairs({0, 4, 8, 12}) do
            gfx.drawLine(0, y, 15, y)
        end
        gfx.drawLine(7, 1, 7, 3)
        gfx.drawLine(3, 5, 3, 7)
        gfx.drawLine(11, 5, 11, 7)
        gfx.drawLine(7, 9, 7, 11)
        gfx.drawLine(3, 13, 3, 15)
        gfx.drawLine(11, 13, 11, 15)
    end)
end

-- 4: Water — dark gray checkerboard + white wave highlights
function TileFactory.water()
    return makeTile(Shade.DARK, function()
        gfx.setColor(gfx.kColorWhite)
        for wave = 0, 3 do
            local baseY = wave * 4 + 2
            local offset = (wave % 2) * 4
            for x = 0, 15 do
                local wy = baseY + math.floor(0.5 + math.sin((x + offset) * math.pi / 4))
                gfx.fillRect(x, wy, 1, 1)
                gfx.fillRect(x, wy - 1, 1, 1)
            end
        end
    end)
end

-- 5: Tree — dense black canopy with white leaf specks, white ground at edges
function TileFactory.tree()
    return makeTile(nil, function()
        for y = 0, 15 do
            local x1, x2
            if y == 0 or y == 15 then
                x1, x2 = 4, 11
            elseif y == 1 or y == 14 then
                x1, x2 = 2, 13
            else
                x1, x2 = 1, 14
            end
            gfx.fillRect(x1, y, x2 - x1 + 1, 1)
        end
        gfx.setColor(gfx.kColorWhite)
        local specks = {
            {4,3}, {10,2}, {7,4}, {13,3},
            {3,6}, {8,5}, {12,7},
            {5,8}, {10,9}, {3,10},
            {7,11}, {12,10}, {5,13},
            {9,12}, {11,4}, {6,7},
        }
        for _, s in ipairs(specks) do
            gfx.fillRect(s[1], s[2], 1, 1)
        end
    end)
end

-- 6: Door — white wall top + solid black door opening
function TileFactory.door()
    return makeTile(nil, function()
        gfx.drawLine(0, 0, 15, 0)
        gfx.drawLine(3, 1, 3, 3)
        gfx.drawLine(11, 1, 11, 3)
        gfx.drawLine(0, 4, 15, 4)
        gfx.fillRect(4, 5, 8, 11)
    end)
end

-- 7: Fence — white pickets on white ground
function TileFactory.fence()
    return makeTile(nil, function()
        gfx.drawLine(0, 3, 15, 3)
        gfx.drawLine(0, 11, 15, 11)
        for _, postX in ipairs({1, 5, 9, 13}) do
            gfx.drawLine(postX, 2, postX, 13)
        end
    end)
end

-- 8: Tall Grass — V-blade pattern ~30% density (unique texture, not a shade)
function TileFactory.tallGrass()
    return makePixelTile(function(x, y)
        local by = y % 4
        local bx = x % 4
        return (by == 0 and bx % 2 == 1)
            or (by == 1 and bx % 2 == 0)
            or (by == 2 and bx % 2 == 1)
    end)
end

-- 9: Roof — dark gray checkerboard + shingle ridge lines
function TileFactory.roof()
    return makeTile(Shade.DARK, function()
        for _, y in ipairs({3, 7, 11, 15}) do
            gfx.drawLine(0, y, 15, y)
        end
    end)
end

-- 10: Sign — white board with outline on white ground + post
function TileFactory.sign()
    return makeTile(nil, function()
        gfx.drawRect(3, 1, 10, 6)
        gfx.drawLine(7, 7, 7, 14)
        gfx.drawLine(8, 7, 8, 14)
    end)
end

-- 11: Flowers — + shapes on white ground
function TileFactory.flowers()
    return makeTile(nil, function()
        local positions = {{4,3}, {11,3}, {7,8}, {3,12}, {12,12}}
        for _, f in ipairs(positions) do
            local fx, fy = f[1], f[2]
            gfx.fillRect(fx, fy, 1, 1)
            gfx.fillRect(fx-1, fy, 1, 1)
            gfx.fillRect(fx+1, fy, 1, 1)
            gfx.fillRect(fx, fy-1, 1, 1)
            gfx.fillRect(fx, fy+1, 1, 1)
        end
    end)
end

-- 12: Shore — white land → black edge → dark gray water
function TileFactory.shore()
    return makePixelTile(function(x, y)
        local edgeY = 7 + math.floor(0.5 + 1.5 * math.sin(x * math.pi / 4))
        if y < edgeY then
            return false -- white land
        elseif y == edgeY then
            return true -- black edge
        else
            return Shade.isDarkDot(x, y) -- dark gray water
        end
    end)
end

-- 13: Lab Wall — white base + wider brick mortar
function TileFactory.labWall()
    return makeTile(nil, function()
        for _, y in ipairs({0, 5, 10, 15}) do
            gfx.drawLine(0, y, 15, y)
        end
        gfx.drawLine(8, 1, 8, 4)
        gfx.drawLine(4, 6, 4, 9)
        gfx.drawLine(12, 6, 12, 9)
        gfx.drawLine(8, 11, 8, 14)
    end)
end

-- 14: Mailbox — white box with outline + post on white ground
function TileFactory.mailbox()
    return makeTile(nil, function()
        gfx.drawRect(4, 3, 8, 6)
        -- Flag
        gfx.drawRect(12, 4, 3, 3)
        -- Post
        gfx.drawLine(7, 9, 7, 14)
        gfx.drawLine(8, 9, 8, 14)
    end)
end

-- 15: Roof Left — / diagonal, dark gray inside, white outside
function TileFactory.roofLeft()
    return makePixelTile(function(x, y)
        local edgeX = 15 - y
        if x > edgeX then
            return Shade.isDarkDot(x, y) or y % 4 == 3
        elseif x == edgeX then
            return true
        else
            return false -- white outside
        end
    end)
end

-- 16: Roof Right — \ diagonal, dark gray inside, white outside
function TileFactory.roofRight()
    return makePixelTile(function(x, y)
        local edgeX = y
        if x < edgeX then
            return Shade.isDarkDot(x, y) or y % 4 == 3
        elseif x == edgeX then
            return true
        else
            return false -- white outside
        end
    end)
end

-- 17: Wall Window — white brick wall with mullioned window
function TileFactory.wallWindow()
    local img = gfx.image.new(S, S, gfx.kColorWhite)
    gfx.pushContext(img)
        -- Wall mortar
        gfx.setColor(gfx.kColorBlack)
        for _, y in ipairs({0, 4, 8, 12}) do
            gfx.drawLine(0, y, 15, y)
        end
        gfx.drawLine(7, 1, 7, 3)
        gfx.drawLine(3, 5, 3, 7)
        gfx.drawLine(11, 5, 11, 7)
        gfx.drawLine(7, 9, 7, 11)
        gfx.drawLine(3, 13, 3, 15)
        gfx.drawLine(11, 13, 11, 15)
        -- Window frame
        gfx.drawRect(5, 4, 6, 8)
        -- Mullion cross
        gfx.drawLine(6, 8, 9, 8)
        gfx.drawLine(8, 5, 8, 10)
    gfx.popContext()
    return img:scaledImage(2)
end
