-- Native source pixels through the existing explicit-zero renderer. These are
-- temporary scene images, never a second tile registry or a terrain mutation.
VermilionShipArt = {}

local gfx <const> = playdate.graphics
local REVISION <const> = "af519899719f0754965776faac0e836a3b906e6d"
local PHASE <const> = {0, 0}
local CELL <const> = 32
local cached
local images

local function definition()
    if not cached then
        cached = assert(json.decodeFile("data/vermilionShip/art.json"))
        assert(cached.schema == 1 and cached.source_revision == REVISION,
            "unverified ship art")
        assert(cached.pattern_phase[1] == 0 and cached.pattern_phase[2] == 0,
            "ship art requires explicit zero dither phase")
    end
    return cached
end

function VermilionShipArt.data()
    return GameSession._copy(definition())
end

function VermilionShipArt.images()
    if images then
        return images
    end
    local data <const> = definition()
    local hull = gfx.image.new(8 * CELL, 3 * CELL, gfx.kColorWhite)
    gfx.pushContext(hull)
    gfx.setDrawOffset(0, 0)
    gfx.clearClipRect()
    gfx.clearStencil()
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    for y, row in ipairs(data.hull.cells) do
        for x, cell in ipairs(row) do
            TileFactory.renderGrid(cell.grid, nil, PHASE):draw((x - 1) * CELL, (y - 1) * CELL)
        end
    end
    gfx.popContext()

    -- OBP1=$00 makes every nonzero source sprite index white. Preserve the
    -- pinned transparent index-zero mask; do not flood-fill or recolor it grey.
    local puff = gfx.image.new(CELL, CELL, gfx.kColorWhite)
    local mask = gfx.image.new(CELL, CELL, gfx.kColorBlack)
    gfx.pushContext(mask)
    gfx.setDrawOffset(0, 0)
    gfx.clearClipRect()
    gfx.clearStencil()
    gfx.setColor(gfx.kColorWhite)
    for y, row in ipairs(data.smoke.mask) do
        for x = 1, 16 do
            if row:sub(x, x) == "1" then
                gfx.fillRect((x - 1) * 2, (y - 1) * 2, 2, 2)
            end
        end
    end
    gfx.popContext()
    puff:setMaskImage(mask)

    images = {
        hull = hull,
        smoke = puff,
        water = TileFactory.renderGrid(data.water_grid, nil, PHASE),
    }
    return images
end

function VermilionShipArt.render(image, state)
    local data <const> = definition()
    local art <const> = VermilionShipArt.images()
    local width <const> = data.map_width_cells * CELL
    local height <const> = data.band.height_cells * CELL
    gfx.pushContext(image)
    gfx.setDrawOffset(0, 0)
    gfx.clearClipRect()
    gfx.clearStencil()
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    -- Repaint the complete band before moving its source hull. Its fixed world
    -- position keeps the dock, player and camera stationary above that band.
    for y = 0, height - 1, CELL do
        for x = 0, width - 1, CELL do
            art.water:draw(x, y)
        end
    end
    if not state.erased then
        art.hull:draw(data.hull.source_x * CELL - state.scroll_pixels * 2, 0)
        if state.puff_visible then
            art.smoke:draw(state.puff_world_x, state.puff_band_y)
        end
    end
    gfx.popContext()
end
