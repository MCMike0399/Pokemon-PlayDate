-- ============================================================
-- ColorMapper: Game Boy 2-bit color to Playdate shade mapping
-- ============================================================
-- Maps the Game Boy's 2-bit (4 shade) palette to Playdate's 1-bit
-- display using the Shade dithering system.
--
-- Game Boy palette (2 bits per pixel):
--   00 = White  (0% black)   - Shade.WHITE
--   01 = Light  (25% black)  - Shade.LIGHT  
--   10 = Dark   (50% black)  - Shade.DARK
--   11 = Black  (100% black) - Shade.BLACK
--
-- Usage:
--   ColorMapper:loadTileset(path)     -- load authentic GB tiles
--   ColorMapper:getTile(index)        -- get converted Playdate image
--   ColorMapper:setPalette(palette)   -- custom palette mapping

local gfx <const> = playdate.graphics
local setmetatable <const> = setmetatable

Class("ColorMapper")

-- ============================================================
-- DEFAULT PALETTE MAPPINGS
-- ============================================================

ColorMapper.GB_GREEN = {
    [0] = Shade.WHITE,
    [1] = Shade.LIGHT,
    [2] = Shade.DARK,
    [3] = Shade.BLACK,
}

ColorMapper.SGB_PALETTE = {
    [0] = Shade.WHITE,
    [1] = Shade.LIGHT,
    [2] = Shade.DARK,
    [3] = Shade.BLACK,
}

ColorMapper.HIGH_CONTRAST = {
    [0] = Shade.WHITE,
    [1] = Shade.WHITE,
    [2] = Shade.BLACK,
    [3] = Shade.BLACK,
}

-- ============================================================
-- INTERNAL STATE
-- ============================================================

ColorMapper.currentPalette = ColorMapper.GB_GREEN
ColorMapper.tileCache = {}
ColorMapper.tilesetImage = nil
ColorMapper.TILE_WIDTH = 8
ColorMapper.TILE_HEIGHT = 8
ColorMapper.tilesPerRow = 16

-- ============================================================
-- PALETTE MANAGEMENT
-- ============================================================

function ColorMapper:setPalette(palette)
    self.currentPalette = palette
    self.tileCache = {}
end

function ColorMapper:map(gbValue)
    return self.currentPalette[gbValue] or Shade.WHITE
end

function ColorMapper:grayToGB(grayValue)
    if grayValue >= 192 then
        return 0
    elseif grayValue >= 128 then
        return 1
    elseif grayValue >= 64 then
        return 2
    else
        return 3
    end
end

-- ============================================================
-- TILESET LOADING
-- ============================================================

function ColorMapper:loadTileset(imagePath, tilesPerRow)
    self.tilesetImage = gfx.image.new(imagePath)
    if not self.tilesetImage then
        print("ERROR: Failed to load tileset: " .. imagePath)
        return false
    end
    
    self.tilesPerRow = tilesPerRow or 16
    self.tileCache = {}
    
    local w, h = self.tilesetImage:getSize()
    print(string.format("ColorMapper: Loaded tileset %dx%d (%d tiles)", 
        w, h, (w / self.TILE_WIDTH) * (h / self.TILE_HEIGHT)))
    
    return true
end

function ColorMapper:getTileCount()
    if not self.tilesetImage then return 0 end
    local w, h = self.tilesetImage:getSize()
    return math.floor(w / self.TILE_WIDTH) * math.floor(h / self.TILE_HEIGHT)
end

-- ============================================================
-- TILE CONVERSION
-- ============================================================

function ColorMapper:getTile(tileIndex)
    if self.tileCache[tileIndex] then
        return self.tileCache[tileIndex]
    end
    
    if not self.tilesetImage then
        print("ERROR: No tileset loaded")
        return nil
    end
    
    local tileX = (tileIndex % self.tilesPerRow) * self.TILE_WIDTH
    local tileY = math.floor(tileIndex / self.tilesPerRow) * self.TILE_HEIGHT
    
    local tileImg = gfx.image.new(self.TILE_WIDTH, self.TILE_HEIGHT, gfx.kColorWhite)
    
    gfx.pushContext(tileImg)
        for y = 0, self.TILE_HEIGHT - 1 do
            for x = 0, self.TILE_WIDTH - 1 do
                local pixelColor = self.tilesetImage:sample(tileX + x + 0.5, tileY + y + 0.5)
                local gray = pixelColor and pixelColor:lightness() or 1.0
                local grayValue = math.floor((1.0 - gray) * 255)
                local gbValue = self:grayToGB(grayValue)
                local shade = self:map(gbValue)
                
                if shade ~= Shade.WHITE then
                    Shade.set(shade)
                    gfx.fillRect(x, y, 1, 1)
                end
            end
        end
        Shade.reset()
    gfx.popContext()
    
    local scaledImg = tileImg:scaledImage(2)
    self.tileCache[tileIndex] = scaledImg
    
    return scaledImg
end

function ColorMapper:getTiles(startIndex, count)
    local images = {}
    for i = 0, count - 1 do
        images[i + 1] = self:getTile(startIndex + i)
    end
    return images
end

-- ============================================================
-- UTILITY
-- ============================================================

function ColorMapper:clearCache()
    self.tileCache = {}
    collectgarbage("collect")
end

function ColorMapper:createImageTable(startIndex, count)
    local imgTable = gfx.imagetable.new(count)
    for i = 0, count - 1 do
        local img = self:getTile(startIndex + i)
        if img then
            imgTable:setImage(i + 1, img)
        end
    end
    return imgTable
end

return ColorMapper
