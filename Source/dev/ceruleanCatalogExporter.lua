-- Development-only immutable source inventory. No provider materialization,
-- actor installation, visibility evaluation or campaign execution belongs here.
CeruleanCatalogExporter = {}
local gfx <const> = playdate.graphics
local revision <const> = "af519899719f0754965776faac0e836a3b906e6d"
local directions <const> = { "down", "up", "left", "right" }
local backgrounds <const> = { "white", "black", "texture" }
local tutorialImages
local mapKinds <const> = { "terrain", "viewport", "collision", "actors", "events" }

local function keys(source)
    local result = {}
    for key in pairs(source) do result[#result + 1] = key end
    table.sort(result)
    return result
end

local function actors()
    return SourceMaps.record("data/sourceSlice/sprites.json").sprites
end

function CeruleanCatalogExporter.tiles()
    local metadata = SourceMaps.compact()
    local legacy = PewterCatalogExporter.legacyTiles()
    local result = {}
    for _, name in ipairs(SourceMaps.names("source")) do
        for _, key in ipairs(metadata.maps[name].palette) do
            if not legacy[key] then result[key] = assert(metadata.tiles[key], "source palette tile missing") end
        end
    end
    return result
end

-- Raw source-frame provenance stays explicit-zero and four-shade. World
-- poses below use the pure production policy, never installArt/stepImage caches.
function CeruleanCatalogExporter.frame(source, index)
    local strip = CeruleanContent.sprite(source)
    assert(type(index) == "number" and index % 1 == 0, "integer source frame required")
    return SpriteFactory.makeSprite(assert(strip.frames[tostring(index)], "missing original actor frame"), {0,0})
end

function CeruleanCatalogExporter.poses()
    local result = {}
    for _, source in ipairs(keys(actors())) do
        local strip = CeruleanContent.sprite(source)
        for _, pose in ipairs({ "stand", "walk", "alternate" }) do
            if pose == "stand" or next(strip.walking) then
                for _, direction in ipairs(directions) do
                    local sourceDirection = direction == "right" and "left" or direction
                    local index = (pose == "stand" and strip.standing or strip.walking)[sourceDirection]
                    if strip.fixed then index = strip.standing.down end
                    assert(index ~= nil, "missing exact source pose")
                    local flip = not strip.fixed and (direction == "right"
                        or pose == "alternate" and (direction == "up" or direction == "down")) or false
                    result[#result + 1] = {
                        name = "cerulean-pose-" .. source .. "-" .. pose .. "-" .. direction,
                        source = source, source_id = strip.id, source_path = strip.source,
                        source_sha256 = strip.sha256, source_frame = index, flip_x = flip,
                        pose = pose, direction = direction,
                        phase_policy = source == "SPRITE_BLUE" and "legacy-omitted" or "explicit-zero",
                        mapping = source == "SPRITE_BLUE" and "greyhair" or strip.mapping,
                        image_policy = source == "SPRITE_BLUE" and pose == "stand"
                            and "protected-canonical-rival" or "source-frame",
                        native_ticks = pose == "stand" and {1,4,5,8} or pose == "walk" and {2,3} or {6,7},
                        walking_available = next(strip.walking) ~= nil,
                        direction_policy = strip.fixed and "fixed-down-image; no directional source frames"
                            or "source-direction; mirrored-right",
                    }
                end
            end
        end
    end
    return result
end

local function render(width, height, color, callback)
    local image = assert(gfx.image.new(width, height, color), "catalog image allocation failed")
    gfx.pushContext(image)
    gfx.setDrawOffset(0, 0)
    gfx.clearClipRect()
    gfx.clearStencil()
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(1)
    gfx.setFont(gfx.getSystemFont())
    local ok, problem = pcall(callback)
    gfx.popContext()
    assert(ok, problem)
    return image
end

-- An opaque contact strip retains original source frame order and dimensions;
-- individual frames below separately expose production transparency/masks.
local function sourceStrip(source)
    local strip = CeruleanContent.sprite(source)
    return render(strip.size[1] * 2, strip.size[2] * 2, gfx.kColorWhite, function()
        for _, index in ipairs(keys(strip.frames)) do
            TileFactory.renderGrid(strip.frames[index], nil, {0,0}):draw(0, tonumber(index) * 32)
        end
    end)
end

function CeruleanCatalogExporter.inventory()
    local result = { images = {}, map_count = 18, tile_count = 154, actor_strip_count = 28,
        source_frame_count = 124, directional_pose_count = 240, tutorial_art_count = 5,
        tutorial_frame_count = 13 }
    local function add(name, width, height, category, mask)
        result.images[#result.images + 1] = { path = name .. ".png", width = width, height = height,
            category = category, mask = mask or false }
    end
    local function asset(name, width, height, category, composites)
        add(name, width, height, category)
        add(name .. "__mask", width, height, category, true)
        if composites then
            for _, background in ipairs(backgrounds) do
                add(name .. "__" .. background, width, height, category .. "-background")
            end
        end
    end
    local maps = SourceMaps.names("source")
    assert(#maps == result.map_count, "explicit Cerulean map inventory changed")
    local tiles = keys(CeruleanCatalogExporter.tiles())
    assert(#tiles == result.tile_count, "explicit Cerulean tile inventory changed")
    for _, key in ipairs(tiles) do
        asset("tile_imported_" .. VisualCatalog.stableName(key), 32, 32, "imported-tile", false)
    end
    for _, name in ipairs(maps) do
        local descriptor = SourceMaps.descriptor(name)
        for _, kind in ipairs(mapKinds) do
            local viewport = kind == "viewport"
            -- Map images have no synthetic mask/composites.
            add("cerulean-" .. name .. "-" .. kind, viewport and 400 or descriptor.width * 32,
                viewport and 240 or descriptor.height * 32,
                viewport and "map-viewport" or kind == "events" and "events-warps-connections" or kind)
        end
    end
    local strips, frames = 0, 0
    for _, source in ipairs(keys(actors())) do
        local strip = CeruleanContent.sprite(source)
        strips = strips + 1
        asset("cerulean-strip-" .. source, strip.size[1] * 2, strip.size[2] * 2, "source-strip", true)
        for _, index in ipairs(keys(strip.frames)) do
            frames = frames + 1
            asset("cerulean-frame-" .. source .. "-" .. index, 32, 32, "source-frame", true)
        end
    end
    assert(strips == result.actor_strip_count and frames == result.source_frame_count, "explicit source strip inventory changed")
    local poses = CeruleanCatalogExporter.poses()
    assert(#poses == result.directional_pose_count, "explicit source pose inventory changed")
    for _, pose in ipairs(poses) do asset(pose.name, 32, 32, "cerulean-character", true) end
    local art = TutorialEscortData.get().art
    local artCount, frameCount = 0, 0
    for _, name in ipairs(keys(art)) do
        local entry = art[name]
        artCount = artCount + 1
        asset("cerulean-tutorial-" .. name, entry.width * 2, entry.height * 2, "tutorial-source-art", true)
        if entry.width == 16 then
            for index = 0, entry.height // 16 - 1 do
                frameCount = frameCount + 1
                asset("cerulean-tutorial-" .. name .. "-frame-" .. index, 32, 32, "tutorial-source-frame", true)
            end
        end
    end
    assert(artCount == result.tutorial_art_count and frameCount == result.tutorial_frame_count, "explicit tutorial art inventory changed")
    table.sort(result.images, function(a, b) return a.path < b.path end)
    assert(#result.images == 2448, "explicit Cerulean image inventory changed")
    return result
end

function CeruleanCatalogExporter.hiddenEvents(name)
    local descriptor = SourceMaps.descriptor(name)
    local result = {}
    for _, event in ipairs(SourceMaps.record("data/sourceSlice/scripts.json").hidden_events) do
        if event.map_id == descriptor.id then
            local index = #result + 1
            result[index] = { id = descriptor.id .. ":hidden_events:" .. index, kind = "hidden",
                x = event.x + descriptor.padding, y = event.y, source_x = event.x, source_y = event.y,
                handler_source = event["function"], argument_source = event.argument,
                status = "source inventory; external hidden dispatch not inferred" }
        end
    end
    return result
end

local function mapImages(name, sink)
    local descriptor = SourceMaps.descriptor(name)
    local definition = SourceMaps.padded(name)
    local zone = SourceMaps.isolated(name)
    assert(zone.registry ~= WorldTiles, "catalog requires a private palette")
    local view
    local ok, result = pcall(function()
        view = WorldView(zone, { attach = false })
        local terrain = view:render()
        local width, height = terrain:getSize()
        local prefix = "cerulean-" .. name .. "-"
        sink.save(prefix .. "terrain", terrain, "terrain")
        local cx = math.max(0, math.min(width - 400, zone.spawn.x * TILE_SIZE - 200))
        local cy = math.max(0, math.min(height - 240, zone.spawn.y * TILE_SIZE - 120))
        sink.save(prefix .. "viewport", render(400, 240, gfx.kColorWhite, function()
            terrain:draw(-cx, -cy)
        end), "map-viewport")
        sink.save(prefix .. "collision", render(width, height, gfx.kColorWhite, function()
            for y, row in ipairs(zone.collision) do
                for x, value in ipairs(row) do
                    if value == 1 then gfx.fillRect((x-1)*TILE_SIZE, (y-1)*TILE_SIZE, TILE_SIZE, TILE_SIZE) end
                end
            end
        end), "collision")
        local actorRows = {}
        sink.save(prefix .. "actors", render(width, height, gfx.kColorWhite, function()
            terrain:draw(0, 0)
            -- Every source row, including hidden/fossil/rival alternatives.
            -- Never evaluate def.appearsIf or invoke a Story/session reader.
            for _, def in ipairs(zone.npcDefs) do
                local strip = CeruleanContent.sprite(def.source_sprite)
                local direction = def.facing
                local index = strip.standing[strip.fixed and "down" or direction == "right" and "left" or direction]
                local image = CeruleanContent.poseImage(def.source_sprite, "stand", direction)
                image:draw(def.gridX*TILE_SIZE, def.gridY*TILE_SIZE-8)
                actorRows[#actorRows + 1] = { id = def.source_event_id, sprite = def.source_sprite,
                    x = def.gridX, y = def.gridY, direction = direction, frame = index,
                    visibility_policy = "all source rows; predicates never evaluated" }
            end
        end), "actors")
        local specs = SourceBindings.specs(name, definition, SourceEvents.has)
        local events, connections = {}, {}
        sink.save(prefix .. "events", render(width, height, gfx.kColorWhite, function()
            terrain:draw(0, 0)
            local function label(x, y, text)
                gfx.setColor(gfx.kColorWhite)
                gfx.fillRect(x+1, y+1, 30, 22)
                gfx.setColor(gfx.kColorBlack)
                gfx.drawRect(x+1, y+1, 30, 22)
                gfx.drawText(text, x+3, y+3)
            end
            for _, kind in ipairs({ "objects", "background_events", "warps" }) do
                for index, event in ipairs(definition.events[kind]) do
                    label(event.x*TILE_SIZE, event.y*TILE_SIZE,
                        (kind == "objects" and "O" or kind == "warps" and "W" or "B") .. index)
                    events[#events + 1] = { id = event.id, kind = kind, x = event.x, y = event.y,
                        source_x = event.source_x or event.x-descriptor.padding, source_y = event.source_y or event.y,
                        status = assert(specs[event.id]).status, destination = event.destination, sprite = event.sprite }
                end
            end
            for index, event in ipairs(CeruleanCatalogExporter.hiddenEvents(name)) do
                label(event.x*TILE_SIZE, event.y*TILE_SIZE, "H" .. index)
                events[#events + 1] = event
            end
            for _, connection in ipairs(definition.connections) do
                local direction = connection.direction
                local x = direction == "west" and 0 or direction == "east" and width-32 or width//2-16
                local y = direction == "north" and 0 or direction == "south" and height-32 or height//2-16
                label(x, y, direction:sub(1,1):upper())
                local id = direction .. ":" .. connection.target_map
                connections[#connections + 1] = { id = id, direction = direction, target_map = connection.target_map,
                    entry_lateral_adjustment_cells = connection.entry_lateral_adjustment_cells,
                    status = assert(specs[id]).status }
            end
        end), "events-warps-connections")
        return { name = name, zone_id = descriptor.id, key = descriptor.key,
            width = zone.width, height = zone.height, source_width = descriptor.source_width, padding = descriptor.padding,
            source_sha256 = descriptor.source_sha256, actors = actorRows, events = events, connections = connections,
            directional_rules = definition.directional_rules, issues = zone:getBindingIssues(),
            campaign_ready = zone:isCampaignReady(), slice_ready = zone:isSliceReady() }
    end)
    if view then view:dispose() end
    if not ok then error(result, 0) end
    return result
end

function CeruleanCatalogExporter.writer(sink)
    local report = { schema = 1, source_revision = revision, maps = {}, tiles = {}, characters = {},
        strips = {}, tutorial = {}, missing = {}, phase_policy = "explicit-zero; BLUE world poses retain legacy-omitted",
        review_status = "all new assets unreviewed; root native inspection required" }
    for _, key in ipairs(keys(CeruleanCatalogExporter.tiles())) do
        local tile = SourceMaps.tile(key)
        local name = "tile_imported_" .. VisualCatalog.stableName(key)
        sink.asset(name, TileFactory.renderGrid(tile.grid, nil, {0,0}), "imported-tile", false)
        report.tiles[#report.tiles + 1] = { stable_key = key, path = name .. ".png",
            terrain = tile.terrain, collision = tile.collision }
    end
    for _, name in ipairs(SourceMaps.names("source")) do report.maps[#report.maps + 1] = mapImages(name, sink) end
    for _, source in ipairs(keys(actors())) do
        local strip = CeruleanContent.sprite(source)
        sink.asset("cerulean-strip-" .. source, sourceStrip(source), "source-strip", true)
        for _, index in ipairs(keys(strip.frames)) do
            sink.asset("cerulean-frame-" .. source .. "-" .. index,
                CeruleanCatalogExporter.frame(source, tonumber(index)), "source-frame", true)
        end
        report.strips[#report.strips + 1] = { source = source, source_id = strip.id, source_path = strip.source,
            source_sha256 = strip.sha256, size = strip.size, frames = keys(strip.frames), standing = strip.standing,
            walking = strip.walking, fixed = strip.fixed, mapping = strip.mapping }
    end
    for _, pose in ipairs(CeruleanCatalogExporter.poses()) do
        local image = CeruleanContent.poseImage(pose.source, pose.pose, pose.direction)
        sink.asset(pose.name, image, "cerulean-character", true)
        report.characters[#report.characters + 1] = pose
    end
    for _, name in ipairs(keys(TutorialEscortData.get().art)) do
        local art = TutorialEscortData.get().art[name]
        sink.asset("cerulean-tutorial-" .. name,
            assert(tutorialImages and tutorialImages[name], "tutorial art must be prepared during exporter registration"),
            "tutorial-source-art", true)
        if art.width == 16 then
            for index = 0, art.height // 16 - 1 do
                sink.asset("cerulean-tutorial-" .. name .. "-frame-" .. index,
                    TutorialDemoArt.actorFrame(name, index), "tutorial-source-frame", true)
            end
        end
        report.tutorial[#report.tutorial + 1] = { name = name, source_path = art.source,
            width = art.width, height = art.height }
    end
    return report
end

function CeruleanCatalogExporter.register()
    -- Warm the production tutorial renderer only at root bootstrap. Writer
    -- commands merely read these images and never populate its private cache.
    tutorialImages = {}
    for name in pairs(TutorialEscortData.get().art) do tutorialImages[name] = TutorialDemoArt.image(name) end
    local tiles = CeruleanCatalogExporter.tiles()
    local npcs = {}
    for source in pairs(actors()) do npcs[CeruleanContent.key(source)] = true end
    return VisualCatalog.registerExporter("cerulean", {
        inventory = CeruleanCatalogExporter.inventory, writer = CeruleanCatalogExporter.writer,
        ownsZone = function(zone) return SourceMaps.nameForID(zone.stableID, "source") ~= nil end,
        ownsTile = function(key) return tiles[key] ~= nil end,
        ownsNPC = function(key) return npcs[key] == true end,
    })
end
