-- Additive pinned Blue presentation. No sprite installation, movement, timers,
-- session writes, input or RNG. Callers treat returned images as immutable.
FieldGearArt = {}
local gfx <const> = playdate.graphics
local revision <const> = "af519899719f0754965776faac0e836a3b906e6d"
local directions <const> = {"down", "up", "left", "right"}
local cached
local images

local function copy(value)
    if type(value) ~= "table" then
        return value
    end
    local result = {}
    for key, child in pairs(value) do
        result[key] = copy(child)
    end
    return result
end

local function data()
    if not cached then
        cached = assert(json.decodeFile("data/fieldGearArt.json"), "field gear art missing")
        assert(cached.schema == 1 and cached.source_revision == revision, "unverified field gear art")
        assert(cached.pattern_phase[1] == 0 and cached.pattern_phase[2] == 0, "explicit source character phase required")
    end
    return cached
end

function FieldGearArt.data()
    return copy(data())
end

local function direction(value)
    assert(value == "down" or value == "up" or value == "left" or value == "right", "source gear direction required")
end

-- Rod OAM uses index-zero transparency, including any enclosed zero pixels.
-- Characters retain SpriteFactory's established border-connected mask instead.
local function rodTile(tile)
    local padded = {}
    for y = 1, 16 do
        padded[y] = y <= 8 and tile.grid[y] .. "........" or "................"
    end
    local full <const> = TileFactory.renderGrid(padded, nil, {0, 0})
    local image <const> = gfx.image.new(16, 16, gfx.kColorWhite)
    local mask <const> = gfx.image.new(16, 16, gfx.kColorBlack)
    gfx.pushContext(image)
    gfx.setDrawOffset(0, 0)
    gfx.clearClipRect()
    gfx.clearStencil()
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    full:draw(0, 0)
    gfx.popContext()
    gfx.pushContext(mask)
    gfx.setDrawOffset(0, 0)
    gfx.clearClipRect()
    gfx.clearStencil()
    gfx.setColor(gfx.kColorWhite)
    for y, row in ipairs(tile.mask) do
        for x = 1, 8 do
            if row:sub(x, x) == "1" then
                gfx.fillRect((x - 1) * 2, (y - 1) * 2, 2, 2)
            end
        end
    end
    gfx.popContext()
    image:setMaskImage(mask)
    return image
end

-- Root may warm these immutable images at bootstrap/catalog registration.
function FieldGearArt.prepare()
    if images then
        return
    end
    local definition <const> = data()
    local prepared = {bicycle={}, fishing={}, rods={}}
    for _, pose in ipairs({"stand", "walk", "alternate"}) do
        prepared.bicycle[pose] = {}
        for _, facing in ipairs(directions) do
            local sourceFacing <const> = facing == "right" and "left" or facing
            local frames <const> = pose == "stand" and definition.bicycle.standing or definition.bicycle.walking
            local index <const> = assert(frames[sourceFacing])
            local image = SpriteFactory.makeSprite(definition.bicycle.frames[tostring(index)], {0, 0})
            if facing == "right" or pose == "alternate" and (facing == "down" or facing == "up") then
                image = SpriteFactory.flipped(image)
            end
            prepared.bicycle[pose][facing] = image
        end
    end
    for _, facing in ipairs({"down", "up", "left"}) do
        prepared.fishing[facing] = SpriteFactory.makeSprite(definition.fishing.frames[facing], {0, 0})
    end
    prepared.fishing.right = SpriteFactory.flipped(prepared.fishing.left)
    for _, tile in ipairs({"fd", "fe"}) do
        prepared.rods[tile] = rodTile(definition.rod.tiles[tile])
    end
    prepared.rods.right = SpriteFactory.flipped(prepared.rods.fe)
    -- Reuse the reviewed source emote; do not regenerate its pixels or mask.
    prepared.exclamation = assert(PewterSprites.exclamation())
    images = prepared
end

function FieldGearArt.bicycle(facing, pose)
    direction(facing)
    pose = pose or "stand"
    assert(pose == "stand" or pose == "walk" or pose == "alternate", "source bicycle pose required")
    FieldGearArt.prepare()
    return images.bicycle[pose][facing]
end

function FieldGearArt.fishing(facing)
    direction(facing)
    FieldGearArt.prepare()
    return images.fishing[facing]
end

-- Native offsets are relative to the player's 32x32 graphic top-left, not its
-- grid cell or hardware OAM position. The controller adds the world origin.
function FieldGearArt.rod(facing)
    direction(facing)
    FieldGearArt.prepare()
    local placement <const> = data().rod.directions[facing]
    return {image=facing == "right" and images.rods.right or images.rods[placement.tile],
        x=placement.native_offset[1], y=placement.native_offset[2]}
end

function FieldGearArt.fishingSourceFrame(frame, response, facing)
    direction(facing)
    assert(type(frame) == "number" and frame % 1 == 0 and frame >= 0, "zero-based source fishing frame required")
    assert(response == 0 or response == 1 or response == 2, "source wRodResponse 0/1/2 required")
    local timing <const> = data().timing
    local castStart <const> = timing.precast_frames
    local shakeStart <const> = castStart + timing.cast_frames
    local bubbleStart <const> = shakeStart + timing.shake_count * timing.shake_hold_frames
    local textStart <const> = response == 1 and bubbleStart + timing.bubble_frames + timing.bubble_refresh_frames or shakeStart
    local result = {sourceFrame=frame, playerOffsetY=0, phase="precast"}
    if frame < castStart then
        return result -- Keep the caller's existing protected RED image.
    end
    result.character = FieldGearArt.fishing(facing)
    result.rod = FieldGearArt.rod(facing)
    if frame >= textStart then
        result.phase = "text"
        result.textLabel = timing.response_labels[tostring(response)]
    elseif response == 1 and frame >= bubbleStart then
        result.phase = "bubble"
        result.exclamation = {image=images.exclamation, x=0, y=-32}
        if facing == "up" then
            result.rod = nil
        end
    elseif response == 1 and frame >= shakeStart then
        result.phase = "shake"
        local index <const> = (frame - shakeStart) // timing.shake_hold_frames + 1
        result.playerOffsetY = timing.shake_source_offsets[index] * 2
        result.rod.y = result.rod.y + result.playerOffsetY
    else
        result.phase = "cast"
    end
    return result
end

function FieldGearArt.fishingFrame(tick, response, facing)
    assert(type(tick) == "number" and tick % 1 == 0 and tick >= 0, "zero-based native fishing tick required")
    return FieldGearArt.fishingSourceFrame(tick * 2 + 1, response, facing)
end

-- The existing catalog sink owns masks/composites/publication. These additions
-- expose only distinct new art and useful directional placement samples.
function FieldGearArt.catalogInventory()
    local result = {}
    local function add(name, width, height, category)
        result[#result + 1] = {name=name, width=width, height=height, category=category}
    end
    for _, pose in ipairs({"stand", "walk", "alternate"}) do
        for _, facing in ipairs(directions) do
            -- Side alternate is exactly the same image as side walk.
            if pose ~= "alternate" or facing == "up" or facing == "down" then
                add("field-gear-bike-" .. pose .. "-" .. facing, 32, 32, "field-gear-character")
            end
        end
    end
    for _, facing in ipairs(directions) do
        add("field-gear-fishing-" .. facing, 32, 32, "field-gear-character")
    end
    for _, name in ipairs({"vertical", "left", "right"}) do
        add("field-gear-rod-" .. name, 16, 16, "field-gear-overlay")
    end
    for _, phase in ipairs({"cast", "shake", "bubble"}) do
        for _, facing in ipairs(directions) do
            add("field-gear-fishing-" .. phase .. "-" .. facing, 64, 96, "field-gear-placement")
        end
    end
    return result
end

local function placement(tick, facing)
    local frame <const> = FieldGearArt.fishingFrame(tick, 1, facing)
    local image <const> = gfx.image.new(64, 96, gfx.kColorClear)
    gfx.pushContext(image)
    gfx.setDrawOffset(0, 0)
    gfx.clearClipRect()
    gfx.clearStencil()
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    local ok, problem = pcall(function()
        frame.character:draw(16, 40 + frame.playerOffsetY)
        if frame.rod then
            frame.rod.image:draw(16 + frame.rod.x, 40 + frame.rod.y)
        end
        if frame.exclamation then
            frame.exclamation.image:draw(16 + frame.exclamation.x, 40 + frame.exclamation.y)
        end
    end)
    gfx.popContext()
    assert(ok, problem)
    return image
end

function FieldGearArt.catalogAssets()
    FieldGearArt.prepare()
    local result = {}
    local function add(name, image, category)
        result[#result + 1] = {name=name, image=image, category=category}
    end
    for _, pose in ipairs({"stand", "walk", "alternate"}) do
        for _, facing in ipairs(directions) do
            if pose ~= "alternate" or facing == "up" or facing == "down" then
                add("field-gear-bike-" .. pose .. "-" .. facing,
                    FieldGearArt.bicycle(facing, pose), "field-gear-character")
            end
        end
    end
    for _, facing in ipairs(directions) do
        add("field-gear-fishing-" .. facing, FieldGearArt.fishing(facing), "field-gear-character")
    end
    add("field-gear-rod-vertical", images.rods.fd, "field-gear-overlay")
    add("field-gear-rod-left", images.rods.fe, "field-gear-overlay")
    add("field-gear-rod-right", images.rods.right, "field-gear-overlay")
    for _, sample in ipairs({{phase="cast", tick=5}, {phase="shake", tick=55}, {phase="bubble", tick=70}}) do
        for _, facing in ipairs(directions) do
            add("field-gear-fishing-" .. sample.phase .. "-" .. facing,
                placement(sample.tick, facing), "field-gear-placement")
        end
    end
    return result
end
