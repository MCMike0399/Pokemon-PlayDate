-- Private milestone 5.4 catalog. Immutable package reads and native renderers
-- only; never materialize a provider, install actors or evaluate visibility.
VermilionCatalogExporter = {}
local gfx <const> = playdate.graphics
local shared <const> = CeruleanCatalogExporter
local root <const> = "data/vermilionPreparation/"
local kinds <const> = {"terrain", "viewport", "collision", "actors", "events"}
local shipFrames <const> = {0, 4, 124, 130, 137, 138, 258, 770, 1153, 1154, 1156, 1276, 1280, 1283}
local grassSourceFrames <const> = {0, 7, 8, 15, 16, 23, 24, 31}
local prepared

local function keys(source)
    local result = {}
    for key in pairs(source) do result[#result + 1] = key end
    table.sort(result)
    return result
end

function VermilionCatalogExporter.maps()
    local result = {}
    for _, name in ipairs(SourceMaps.names()) do
        if SourceMaps.entry(name).path == root .. name .. ".json" then
            result[#result + 1] = name
        end
    end
    return result
end

function VermilionCatalogExporter.actors()
    local result = {}
    local previous = SourceMaps.record("data/sourceSlice/sprites.json").sprites
    for source, strip in pairs(SourceMaps.record(root .. "sprites.json").sprites) do
        result[source] = {owner = previous[source] and "cerulean" or "vermilion", strip = strip}
    end
    return result
end

function VermilionCatalogExporter.tiles()
    local previous = PewterCatalogExporter.legacyTiles()
    for key, tile in pairs(shared.tiles()) do previous[key] = tile end
    local metadata <const> = SourceMaps.compact()
    local result = {}
    for _, name in ipairs(VermilionCatalogExporter.maps()) do
        for _, key in ipairs(metadata.maps[name].palette) do
            if not previous[key] then result[key] = assert(metadata.tiles[key]) end
        end
    end
    return result
end

function VermilionCatalogExporter.poses()
    local result = {}
    for source, entry in pairs(VermilionCatalogExporter.actors()) do
        for _, pose in ipairs(shared.poseInventory({[source] = entry.strip}, entry.owner)) do
            pose.owner = entry.owner
            result[#result + 1] = pose
        end
    end
    table.sort(result, function(a, b) return a.name < b.name end)
    return result
end

function VermilionCatalogExporter.hiddenEvents(name)
    return shared.hiddenEvents(name, root .. "scripts.json")
end

-- Counts derive from the pinned package's definitions. Shared families are
-- explicit dependencies, not duplicate PNGs or overlapping ownership claims.
function VermilionCatalogExporter.inventory()
    local result = {images = {}, shared_images = {}, map_count = 0, tile_count = 0,
        actor_strip_count = 0, source_frame_count = 0, directional_pose_count = 0,
        new_actor_strip_count = 0, new_source_frame_count = 0, new_pose_count = 0}
    local seen = {}
    local function add(target, name, width, height, category, mask)
        local path <const> = name .. ".png"
        assert(not seen[path], "duplicate Vermilion declaration")
        seen[path] = true
        target[#target + 1] = {path = path, width = width, height = height,
            category = category, mask = mask or false}
    end
    local function asset(target, name, width, height, category, composites)
        add(target, name, width, height, category)
        add(target, name .. "__mask", width, height, category, true)
        if composites then
            for _, background in ipairs({"white", "black", "texture"}) do
                add(target, name .. "__" .. background, width, height, category .. "-background")
            end
        end
    end
    for _, name in ipairs(VermilionCatalogExporter.maps()) do
        result.map_count = result.map_count + 1
        local descriptor <const> = SourceMaps.descriptor(name)
        for _, kind in ipairs(kinds) do
            local viewport <const> = kind == "viewport"
            add(result.images, "vermilion-" .. name .. "-" .. kind,
                viewport and 400 or descriptor.width * 32, viewport and 240 or descriptor.height * 32,
                viewport and "map-viewport" or kind == "events" and "events-warps-connections" or kind)
        end
    end
    local packageMaps <const> = SourceMaps.record(root .. "manifest-entries.json").maps
    assert(result.map_count == #keys(packageMaps), "Vermilion package map membership differs")
    for name, entry in pairs(packageMaps) do
        assert(SourceMaps.entry(name).path == entry.path and entry.path == root .. name .. ".json",
            "Vermilion map belongs to another package")
    end
    for _, key in ipairs(keys(VermilionCatalogExporter.tiles())) do
        result.tile_count = result.tile_count + 1
        asset(result.images, "tile_imported_" .. VisualCatalog.stableName(key), 32, 32, "imported-tile", false)
    end
    local actors <const> = VermilionCatalogExporter.actors()
    for _, source in ipairs(keys(actors)) do
        local entry <const> = actors[source]
        local strip <const> = entry.strip
        local owned <const> = entry.owner == "vermilion"
        local target <const> = owned and result.images or result.shared_images
        result.actor_strip_count = result.actor_strip_count + 1
        if owned then result.new_actor_strip_count = result.new_actor_strip_count + 1 end
        asset(target, entry.owner .. "-strip-" .. source, strip.size[1] * 2, strip.size[2] * 2, "source-strip", true)
        for _, index in ipairs(keys(strip.frames)) do
            result.source_frame_count = result.source_frame_count + 1
            if owned then result.new_source_frame_count = result.new_source_frame_count + 1 end
            asset(target, entry.owner .. "-frame-" .. source .. "-" .. index, 32, 32, "source-frame", true)
        end
    end
    for _, pose in ipairs(VermilionCatalogExporter.poses()) do
        local owned <const> = pose.owner == "vermilion"
        result.directional_pose_count = result.directional_pose_count + 1
        if owned then result.new_pose_count = result.new_pose_count + 1 end
        asset(owned and result.images or result.shared_images, pose.name, 32, 32, pose.owner .. "-character", true)
    end
    local ship <const> = SourceMaps.record("data/vermilionShip/art.json")
    asset(result.images, "vermilion-ship-hull", #ship.hull.cells[1] * 32, #ship.hull.cells * 32, "ship-source-art", true)
    asset(result.images, "vermilion-ship-smoke", 32, 32, "ship-source-art", true)
    asset(result.images, "vermilion-ship-water", 32, 32, "ship-source-art", true)
    for _, frame in ipairs(shipFrames) do
        add(result.images, "vermilion-ship-frame-" .. frame, ship.map_width_cells * 32,
            ship.band.height_cells * 32, "ship-presentation")
    end
    local field <const> = SourceMaps.record("data/fieldMoves.json")
    for _, palette in ipairs({"228", "128"}) do
        asset(result.images, "vermilion-cut-palette-" .. palette, 32, 32, "cut-source-art", true)
    end
    for frame = 0, field.tree_frames - 1 do
        add(result.images, "vermilion-cut-frame-" .. frame, 64, 32, "cut-presentation")
    end
    result.grass_leaf_palette_count = 2
    result.grass_source_sample_count = #grassSourceFrames
    result.grass_native_update_count = field.grass_frames // 2
    for _, palette in ipairs({228, 128}) do
        asset(result.images, "vermilion-grass-leaf-palette-" .. palette, 16, 16, "grass-source-art", true)
    end
    for _, frame in ipairs(grassSourceFrames) do
        add(result.images, "vermilion-grass-source-frame-" .. frame, 128, 96, "grass-source-presentation")
    end
    for update = 0, result.grass_native_update_count - 1 do
        add(result.images, "vermilion-grass-native-update-" .. update, 128, 96, "grass-native-presentation")
    end
    table.sort(result.images, function(a, b) return a.path < b.path end)
    table.sort(result.shared_images, function(a, b) return a.path < b.path end)
    return result
end

function VermilionCatalogExporter.writer(sink)
    assert(prepared, "Vermilion art must be warmed at bootstrap registration")
    local report = {schema = 1, source_revision = "af519899719f0754965776faac0e836a3b906e6d",
        maps = {}, tiles = {}, strips = {}, characters = VermilionCatalogExporter.poses(),
        shared_images = VermilionCatalogExporter.inventory().shared_images, ship = {}, cut = {},
        grass = {source_hz = 60, native_hz = 30, source_position_count = 32,
            native_update_count = 16, source_samples = {}, native_samples = {},
            leaf_source = "gfx/battle/move_anim_1.png", leaf_tile = 6,
            palette_values = {228, 128}, frame_numbering = "zero-based; positions are frame + 1",
            sampling = "second source position per two-VBlank native interval",
            crop = "128x96; aligned 2x2 replacement at 32,16; facing target at 32,16"},
        review_status = "unreviewed; root native size/motion/purity inspection required",
        phase_policy = "explicit-zero; shared BLUE world poses retain protected legacy-omitted"}
    for _, key in ipairs(keys(VermilionCatalogExporter.tiles())) do
        local tile <const> = SourceMaps.tile(key)
        local stem <const> = "tile_imported_" .. VisualCatalog.stableName(key)
        sink.asset(stem, TileRegistry.renderImportedGrid(tile.grid, TileFactory.renderGrid), "imported-tile", false)
        report.tiles[#report.tiles + 1] = {stable_key = key, path = stem .. ".png"}
    end
    for _, name in ipairs(VermilionCatalogExporter.maps()) do
        report.maps[#report.maps + 1] = shared.mapImages(name, sink, "vermilion", VermilionCatalogExporter.hiddenEvents)
    end
    local actors <const> = VermilionCatalogExporter.actors()
    for _, source in ipairs(keys(actors)) do
        local entry <const> = actors[source]
        local strip <const> = entry.strip
        if entry.owner == "vermilion" then
            sink.asset("vermilion-strip-" .. source, shared.sourceStrip(source), "source-strip", true)
            for _, index in ipairs(keys(strip.frames)) do
                sink.asset("vermilion-frame-" .. source .. "-" .. index, shared.frame(source, tonumber(index)), "source-frame", true)
            end
        end
        report.strips[#report.strips + 1] = {source = source, owner = entry.owner, source_path = strip.source,
            source_sha256 = strip.sha256, size = strip.size, frames = keys(strip.frames),
            standing = strip.standing, walking = strip.walking, fixed = strip.fixed, mapping = strip.mapping}
    end
    for _, pose in ipairs(report.characters) do
        if pose.owner == "vermilion" then
            sink.asset(pose.name, CeruleanContent.poseImage(pose.source, pose.pose, pose.direction), "vermilion-character", true)
        end
    end
    for _, name in ipairs({"hull", "smoke", "water"}) do
        sink.asset("vermilion-ship-" .. name, prepared.ship[name], "ship-source-art", true)
    end
    local ship <const> = VermilionShipArt.data()
    for _, frame in ipairs(shipFrames) do
        local state <const> = VermilionShipTimeline.at(frame)
        local image <const> = shared.render(ship.map_width_cells * 32, ship.band.height_cells * 32,
            gfx.kColorWhite, function() end)
        VermilionShipArt.render(image, state)
        sink.save("vermilion-ship-frame-" .. frame, image, "ship-presentation")
        report.ship[#report.ship + 1] = state
    end
    for index, palette in ipairs({228, 128}) do
        sink.asset("vermilion-cut-palette-" .. palette, prepared.cut.treeFrames[index], "cut-source-art", true)
    end
    for frame, image in ipairs(prepared.cutFrames) do
        sink.save("vermilion-cut-frame-" .. (frame - 1), image, "cut-presentation")
        report.cut[#report.cut + 1] = {frame = frame - 1, palette = frame % 2 == 1 and 128 or 228,
            split_shift = frame * 2, crop = "64x32; target at 16,0; production ground and clipped split tree"}
    end
    for _, palette in ipairs({228, 128}) do
        sink.asset("vermilion-grass-leaf-palette-" .. palette, prepared.grass.palettes[palette], "grass-source-art", true)
    end
    for _, frame in ipairs(grassSourceFrames) do
        sink.save("vermilion-grass-source-frame-" .. frame, prepared.grassSourceFrames[frame], "grass-source-presentation")
        report.grass.source_samples[#report.grass.source_samples + 1] = {source_frame = frame, source_position = frame + 1}
    end
    for index, image in ipairs(prepared.grassNativeFrames) do
        local update <const> = index - 1
        local frame <const> = FieldMoveState.grassSourceFrame(update)
        sink.save("vermilion-grass-native-update-" .. update, image, "grass-native-presentation")
        report.grass.native_samples[#report.grass.native_samples + 1] = {
            native_update = update, source_frame = frame, source_position = frame + 1
        }
    end
    return report
end

function VermilionCatalogExporter.register()
    assert(not prepared, "Vermilion catalog already prepared")
    -- Warm immutable production art only during bootstrap. This private draw
    -- record has no game/session/token and cannot execute field progression.
    local field <const> = FieldMoves.data()
    local cut = {active = true, phase = "effect", frame = 0, effect = FieldMoves.effectData(),
        preview = {key = "cut", target = {x = 0.5, y = 0},
            cells = {{x = 0.5, y = 0, after = "pokered:OVERWORLD:cell:2c-2c-2c-2c"}}}}
    local frames = {}
    for frame = 0, field.tree_frames - 1 do
        cut.frame = frame
        frames[#frames + 1] = shared.render(64, 32, gfx.kColorWhite, function() FieldMoveState.draw(cut) end)
    end
    local grass <const> = FieldMoveState.prepareGrassPresentation(FieldMoves.effectData(), {
        target = {x = 1, y = 0.5},
        cells = {
            {x = 1, y = 0.5, after = "pokered:OVERWORLD:cell:2c-2c-2c-2c"},
            {x = 2, y = 0.5, after = "pokered:OVERWORLD:cell:2c-2c-2c-2c"},
            {x = 1, y = 1.5, after = "pokered:OVERWORLD:cell:2c-2c-2c-2c"},
            {x = 2, y = 1.5, after = "pokered:OVERWORLD:cell:2c-2c-2c-2c"}
        }
    })
    local sourceFrames, nativeFrames = {}, {}
    local function renderGrass(sourceFrame)
        return shared.render(128, 96, gfx.kColorWhite, function()
            FieldMoveState.drawGrassPresentation(grass, sourceFrame, 0, 0)
        end)
    end
    for _, frame in ipairs(grassSourceFrames) do
        sourceFrames[frame] = renderGrass(frame)
    end
    for update = 0, field.grass_frames // 2 - 1 do
        nativeFrames[#nativeFrames + 1] = renderGrass(FieldMoveState.grassSourceFrame(update))
    end
    prepared = {ship = VermilionShipArt.images(), cut = cut, cutFrames = frames,
        grass = grass, grassSourceFrames = sourceFrames, grassNativeFrames = nativeFrames}
    VermilionShipTimeline.data()
    local tiles <const> = VermilionCatalogExporter.tiles()
    local maps, npcs = {}, {}
    for _, name in ipairs(VermilionCatalogExporter.maps()) do maps[SourceMaps.entry(name).id] = true end
    for source, entry in pairs(VermilionCatalogExporter.actors()) do
        if entry.owner == "vermilion" then npcs[CeruleanContent.key(source)] = true end
    end
    return VisualCatalog.registerExporter("vermilion", {
        inventory = VermilionCatalogExporter.inventory, writer = VermilionCatalogExporter.writer,
        ownsZone = function(zone) return maps[zone.stableID] == true end,
        ownsTile = function(key) return tiles[key] ~= nil end,
        ownsNPC = function(key) return npcs[key] == true end,
    })
end
