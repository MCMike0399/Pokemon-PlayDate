-- Simulator-only, read-only catalog of actual production images.
-- The host creates outputDir and publishes the returned table as catalog.json.
local gfx <const> = playdate.graphics
VisualCatalog = {}

local function keys(t)
    local out = {}
    for key in pairs(t) do out[#out + 1] = key end
    table.sort(out)
    return out
end

local function render(w, h, background, draw)
    local image = gfx.image.new(w, h, background)
    gfx.pushContext(image)
    gfx.setDrawOffset(0, 0)
    gfx.clearClipRect()
    gfx.clearStencil()
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setColor(gfx.kColorBlack)
    local ok, err = pcall(draw)
    gfx.popContext()
    assert(ok, err)
    return image
end

function VisualCatalog.write(outputDir)
    assert(playdate.isSimulator and playdate.simulator, "catalog requires Simulator")
    assert(type(outputDir) == "string" and outputDir:sub(1, 1) == "/", "absolute output directory required")
    local manifest = { schema = 1, images = {}, missing = {}, maps = {},
        phase = { waterShifts = {0,1,2,3,4,3,2,1}, flowerFrames = {1,2,3,1}, map = "initial factory phase; current zone definitions" },
        limitations = { "Static catalog does not replace frame-sequence journeys.",
            "Map event overlay shows declared NPC/spawn/door positions, not unmodeled scripted trigger regions.",
            "Checked-in battle PNG upstream provenance is unknown; source checksums are tracked separately." } }
    local function save(name, image, category, mask)
        local filename = name .. ".png"
        local w, h = image:getSize()
        playdate.simulator.writeToFile(image, outputDir .. "/" .. filename)
        manifest.images[#manifest.images + 1] = { path = filename, width = w, height = h, category = category, mask = mask or false }
    end
    local function asset(name, image, category, backgrounds)
        save(name, image, category)
        local w, h = image:getSize()
        local mask = image:getMaskImage()
        -- Opaque images have no mask. Still publish an explicit all-opaque mask.
        save(name .. "__mask", mask or gfx.image.new(w, h, gfx.kColorWhite), category, true)
        if backgrounds then
            for _, bg in ipairs({"white", "black", "texture"}) do
                save(name .. "__" .. bg, render(w, h, bg == "black" and gfx.kColorBlack or gfx.kColorWhite, function()
                    if bg == "texture" then
                        for y = 0, h - 1, 4 do
                            for x = 0, w - 1, 4 do
                                if (x // 4 + y // 4) % 2 == 0 then gfx.fillRect(x, y, 4, 4) end
                            end
                        end
                    end
                    image:draw(0, 0)
                end), category .. "-background")
            end
        end
    end
    -- One outer context protects the caller from every factory's color/pattern
    -- changes. Never touch display offset, live imagetables, sprites or timers.
    gfx.pushContext()
    gfx.setDrawOffset(0, 0)
    gfx.clearClipRect()
    gfx.clearStencil()
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setFont(gfx.getSystemFont())
    gfx.setLineWidth(1)
    local ok, err = pcall(function()
        local tiles = TileFactory.generateAll()
        local tileCount = tiles:getLength()
        for id = 1, tileCount do asset(string.format("tile_%02d", id), tiles:getImage(id), "tile") end
        for i, shift in ipairs(manifest.phase.waterShifts) do
            asset("water_" .. i, TileFactory.water(shift), "animation")
            asset("shore_" .. i, TileFactory.shore(shift), "animation")
        end
        for i, frame in ipairs(manifest.phase.flowerFrames) do asset("flowers_" .. i, TileFactory.flowers(frame), "animation") end
        asset("grass_rustle", TileFactory.tallGrassRustle(), "terrain")
        for _, kind in ipairs({"normal", "rustle"}) do
            local tile = kind == "normal" and TileFactory.tallGrass() or TileFactory.tallGrassRustle()
            asset("grass_overlay_" .. kind, render(TILE_SIZE, TILE_SIZE // 2, gfx.kColorClear, function() tile:draw(0, -TILE_SIZE // 2) end), "terrain", true)
        end
        for _, pose in ipairs({"Stand", "Walk1", "Walk2"}) do
            for _, dir in ipairs({"down", "up", "left", "right"}) do
                asset("player_" .. pose:lower() .. "_" .. dir, SpriteFactory["player" .. pose][dir], "character", true)
            end
        end
        for _, name in ipairs(keys(SpriteFactory.npc)) do
            for _, dir in ipairs({"down", "up", "left", "right"}) do asset("npc_" .. name .. "_" .. dir, SpriteFactory.npc[name][dir], "character", true) end
        end
        if Player.getExitArrowImages then
            for _, dir in ipairs({"down", "up", "left", "right"}) do asset("exit_arrow_" .. dir, Player.getExitArrowImages()[dir], "terrain", true) end
        else
            manifest.missing[#manifest.missing + 1] = { category = "exit-arrows", reason = "Player.getExitArrowImages not exposed" }
        end
        save("sheet_tiles", render(8 * 48, math.ceil(tileCount / 8) * 52, gfx.kColorWhite, function()
            for id = 1, tileCount do
                local x, y = ((id - 1) % 8) * 48, ((id - 1) // 8) * 52
                tiles:getImage(id):draw(x, y)
                gfx.drawText(tostring(id), x, y + 32)
            end
        end), "contact-sheet")
        for _, species in ipairs(keys(pokemonData)) do
            for _, view in ipairs({"front", "back"}) do
                local source = PokemonArt.path(species, view)
                local image = gfx.image.new(source)
                if image then asset("battle_" .. species .. "_" .. view, image, "battle")
                else manifest.missing[#manifest.missing + 1] = { category = "battle", species = species, view = view, lookup = source, reason = "runtime canonical lookup missing" } end
            end
        end
        for _, key in ipairs(keys(zoneRegistry)) do
            local zone = zoneRegistry[key]
            local w, h = zone.width * TILE_SIZE, zone.height * TILE_SIZE
            local map = render(w, h, gfx.kColorWhite, function()
                for y = 1, zone.height do for x = 1, zone.width do
                    tiles:getImage(zone.tiles[y][x]):draw((x - 1) * TILE_SIZE, (y - 1) * TILE_SIZE)
                end end
            end)
            save("map_" .. key, map, "map")
            local cx = math.max(0, math.min(w - 400, zone.spawn.x * TILE_SIZE - 200))
            local cy = math.max(0, math.min(h - 240, zone.spawn.y * TILE_SIZE - 120))
            save("map_" .. key .. "__viewport", render(400, 240, gfx.kColorWhite, function()
                map:draw(-cx, -cy)
            end), "map-viewport")
            save("map_" .. key .. "__collision", render(w, h, gfx.kColorWhite, function()
                for y = 1, zone.height do for x = 1, zone.width do
                    if zone.collision[y][x] == 1 then gfx.fillRect((x-1)*TILE_SIZE, (y-1)*TILE_SIZE, TILE_SIZE, TILE_SIZE) end
                end end
            end), "collision")
            save("map_" .. key .. "__events", render(w, h, gfx.kColorWhite, function()
                map:draw(0, 0)
                local function mark(x, y, label)
                    gfx.setColor(gfx.kColorWhite)
                    gfx.fillRect(x*TILE_SIZE, y*TILE_SIZE, TILE_SIZE, 18)
                    gfx.setColor(gfx.kColorBlack)
                    gfx.drawRect(x*TILE_SIZE, y*TILE_SIZE, TILE_SIZE, TILE_SIZE)
                    gfx.drawText(label, x*TILE_SIZE, y*TILE_SIZE)
                end
                for _, door in ipairs(zone.doors) do mark(door.x, door.y, door.edge and "E" or "D") end
                for _, npc in ipairs(zone.npcDefs) do mark(npc.gridX, npc.gridY, "N") end
                mark(zone.spawn.x, zone.spawn.y, "S")
            end), "events")
            manifest.maps[#manifest.maps + 1] = { key = key, width = zone.width, height = zone.height, doors = zone.doors,
                coordinates = "zero-based movement cells; 32 Playdate pixels/cell", npcPolicy = "all definitions, including conditional; predicates not evaluated" }
        end
    end)
    gfx.popContext()
    assert(ok, err)
    return manifest
end
