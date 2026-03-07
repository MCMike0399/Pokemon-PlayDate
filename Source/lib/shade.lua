-- ============================================================
-- Shade: Game Boy 4-shade dithering for 1-bit display
-- ============================================================
-- Simulates the Game Boy's 2-bit (4 shade) palette on Playdate's
-- 1-bit display using 2x2 Bayer ordered dithering:
--
--   WHITE  (0% black)   — pure white (highlights, window glass)
--   LIGHT  (25% black)  — sparse dots (ground, walls, paths)
--   DARK   (50% black)  — checkerboard (roofs, water)
--   BLACK  (100% black) — solid black (outlines, doors, canopy)
--
-- Usage:
--   Shade.set(Shade.LIGHT)            -- set draw pattern
--   gfx.fillRect(0, 0, 16, 16)       -- draws with light gray
--   Shade.reset()                     -- back to solid black
--
--   local img = Shade.newImage(Shade.DARK, 16, 16)

local gfx <const> = playdate.graphics

Class("Shade")

-- 8x8 dither patterns (Playdate format: 8 bytes, MSB-first, 1=white 0=black)
--
-- Densities tuned for 16x16 tiles scaled 2x (each dot = 2x2 on screen):
--   WHITE:  0% black — pure white
--   LIGHT: ~12.5% black — staggered sparse dots (ground, walls)
--   DARK:   50% black — checkerboard (roofs, water)
--   BLACK: 100% black — solid black

Shade.WHITE = "white"
Shade.LIGHT = {0xBB, 0xFF, 0xEE, 0xFF, 0xBB, 0xFF, 0xEE, 0xFF}
Shade.DARK  = {0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA}
Shade.BLACK = "black"

-- Set graphics context to draw with a shade
function Shade.set(shade)
    if shade == Shade.WHITE then
        gfx.setColor(gfx.kColorWhite)
    elseif shade == Shade.BLACK then
        gfx.setColor(gfx.kColorBlack)
    else
        gfx.setPattern(shade)
    end
end

-- Reset to solid black
function Shade.reset()
    gfx.setColor(gfx.kColorBlack)
end

-- Fill a rectangle with a shade
function Shade.fillRect(shade, x, y, w, h)
    Shade.set(shade)
    gfx.fillRect(x, y, w, h)
end

-- Create image filled with a shade
function Shade.newImage(shade, w, h)
    local img = gfx.image.new(w, h, gfx.kColorWhite)
    if shade ~= Shade.WHITE then
        gfx.pushContext(img)
            Shade.set(shade)
            gfx.fillRect(0, 0, w, h)
        gfx.popContext()
    end
    return img
end

-- Pixel-level shade tests (for custom tile drawing)
-- Returns true where a black pixel should be placed
function Shade.isLightDot(x, y)
    return (x % 4 == 1 and y % 4 == 0) or (x % 4 == 3 and y % 4 == 2)
end

function Shade.isDarkDot(x, y)
    return (x + y) % 2 == 0
end
