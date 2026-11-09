-- ============================================================
-- Shade: Game Boy 4-shade dithering for 1-bit display
-- ============================================================
-- Simulates the Game Boy's 2-bit palette on Playdate's 1-bit display.
-- Miguel approved this on 2026-11-09 from the style-option frames:
-- every Shade.LIGHT and Shade.DARK caller, including Pallet Town,
-- its interiors, and runtime character grids, uses the imported
-- fixed-phase Bayer patterns. Explicit phase (0, 0) matches the
-- imported-terrain samples. 1 is white and 0 is black, MSB first.
--
--   WHITE  (0% black)
--   LIGHT  (31.25% black, 20 of 64 bits)
--   DARK   (68.75% black, 44 of 64 bits)
--   BLACK  (100% black)
--
-- Usage:
--   Shade.set(Shade.LIGHT)            -- set draw pattern
--   gfx.fillRect(0, 0, 16, 16)       -- draws with light gray
--   Shade.reset()                     -- back to solid black

local gfx <const> = playdate.graphics

Class("Shade")

-- 8x8 patterns (Playdate format: 8 bytes, MSB-first, 1=white, 0=black).
-- Same bytes as Source/data/importedTonePatterns.json at phase (0, 0).
--   WHITE:  0% black
--   LIGHT: 31.25% black
--   DARK:  68.75% black
--   BLACK: 100% black

Shade.WHITE = "white"
Shade.LIGHT = {0x55, 0xBB, 0x55, 0xFF, 0x55, 0xBB, 0x55, 0xFF}
Shade.DARK  = {0x00, 0xAA, 0x44, 0xAA, 0x00, 0xAA, 0x44, 0xAA}
Shade.BLACK = "black"

-- Set graphics context to draw with a shade
function Shade.set(shade)
    if shade == Shade.WHITE then
        gfx.setColor(gfx.kColorWhite)
    elseif shade == Shade.BLACK then
        gfx.setColor(gfx.kColorBlack)
    else
        -- Omitted phase is not phase (0, 0) on SDK 3.1.2. The approved
        -- mapping asks for the explicit origin used by imported terrain.
        gfx.setPattern(shade, 0, 0)
    end
end

-- Reset to solid black
function Shade.reset()
    gfx.setColor(gfx.kColorBlack)
end
