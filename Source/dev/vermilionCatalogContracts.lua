-- Root-only real-SDK witnesses. Import/register explicitly in private staging.
VermilionCatalogContracts = {}
local gfx <const> = playdate.graphics
local exporter <const> = VermilionCatalogExporter

local function equal(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function paths(inventory)
    local result = {}
    for _, entry in ipairs(inventory.images) do
        assert(not result[entry.path], "duplicate declaration")
        result[entry.path] = entry
    end
    return result
end

-- Independent source-bit oracle; no Shade constants or second renderer.
local function color(code, x, y)
    if code == "." then return gfx.kColorWhite end
    if code == "#" then return gfx.kColorBlack end
    local light <const> = {0xBB, 0xFF, 0xEE, 0xFF, 0xBB, 0xFF, 0xEE, 0xFF}
    local dark <const> = {0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA}
    assert(code == "1" or code == "2", "source shade required")
    local byte <const> = (code == "1" and light or dark)[y % 8 + 1]
    return byte & (0x80 >> (x % 8)) ~= 0 and gfx.kColorWhite or gfx.kColorBlack
end

-- Connectivity relaxation independently checks the production border mask.
local function sourcePixels(image, grid, masked, flip)
    local outside = {}
    if masked then
        local changed = true
        while changed do
            changed = false
            for y = 1, 16 do
                for x = 1, 16 do
                    local id <const> = (y - 1) * 16 + x
                    if grid[y]:sub(x, x) == "." and not outside[id]
                        and (x == 1 or x == 16 or y == 1 or y == 16
                            or x > 1 and outside[id - 1] or x < 16 and outside[id + 1]
                            or y > 1 and outside[id - 16] or y < 16 and outside[id + 16]) then
                        outside[id], changed = true, true
                    end
                end
            end
        end
    end
    local mask <const> = masked and assert(image:getMaskImage())
    for y = 0, 31 do
        for x = 0, 31 do
            local sourceX <const> = flip and 31 - x or x
            local transparent <const> = outside[(y // 2) * 16 + sourceX // 2 + 1]
            if mask then equal(mask:sample(x, y), transparent and gfx.kColorBlack or gfx.kColorWhite) end
            if not transparent then
                equal(image:sample(x, y), color(grid[y // 2 + 1]:sub(sourceX // 2 + 1, sourceX // 2 + 1), sourceX, y))
            end
        end
    end
end

local function pixelsEqual(a, b)
    local width, height = a:getSize()
    local bw, bh = b:getSize()
    equal(width, bw)
    equal(height, bh)
    for y = 0, height - 1 do
        for x = 0, width - 1 do equal(a:sample(x, y), b:sample(x, y)) end
    end
end

function VermilionCatalogContracts.run()
    local report = {ok = true, passed = 0, failed = 0, tests = {}}
    local function test(name, callback)
        local ok, problem = pcall(callback)
        report.tests[#report.tests + 1] = {name = name, ok = ok, error = not ok and tostring(problem) or nil}
        if ok then report.passed = report.passed + 1
        else report.failed = report.failed + 1; report.ok = false end
    end
    test("Package-derived inventory preserves earlier paths and gives every actor one owner", function()
        local before <const> = CatalogRuntime.snapshot()
        local inventory <const> = exporter.inventory()
        local additions <const> = paths(inventory)
        local previous <const> = paths(CeruleanCatalogExporter.inventory())
        local legacy <const> = paths(VisualCatalog.expectedInventory().exporters.pewter)
        local protected <const> = paths(assert(json.decodeFile("dev/catalogProtected.json")))
        local packages <const> = SourceMaps.record("data/vermilionPreparation/manifest-entries.json").maps
        local mapCount, actorCount, frameCount, poseCount = 0, 0, 0, 0
        for _, name in ipairs(exporter.maps()) do
            equal(SourceMaps.entry(name).path, assert(packages[name]).path)
            mapCount = mapCount + 1
        end
        equal(mapCount, inventory.map_count)
        for path in pairs(additions) do
            assert(not previous[path] and not legacy[path] and not protected[path], "earlier path reclaimed")
        end
        for _, entry in ipairs(inventory.shared_images) do
            assert(CatalogRuntime.same(entry, previous[entry.path]), "shared declaration differs")
        end
        for source, entry in pairs(exporter.actors()) do
            actorCount = actorCount + 1
            local strip <const> = CeruleanContent.sprite(source)
            assert(CatalogRuntime.same(strip, entry.strip), "production resolver differs from package")
            for index in pairs(strip.frames) do
                frameCount = frameCount + 1
                assert((entry.owner == "vermilion" and additions or previous)[entry.owner .. "-frame-" .. source .. "-" .. index .. ".png"])
            end
        end
        for _, pose in ipairs(exporter.poses()) do
            poseCount = poseCount + 1
            assert((pose.owner == "vermilion" and additions or previous)[pose.name .. ".png"])
            if pose.source == "SPRITE_BLUE" then
                equal(pose.owner, "cerulean")
                equal(pose.phase_policy, "legacy-omitted")
                equal(pose.mapping, "greyhair")
                if pose.pose == "stand" then
                    equal(CeruleanContent.poseImage(pose.source, pose.pose, pose.direction), SpriteFactory.npc.rival[pose.direction])
                end
            else equal(pose.phase_policy, "explicit-zero") end
        end
        equal(actorCount, inventory.actor_strip_count)
        equal(frameCount, inventory.source_frame_count)
        equal(poseCount, inventory.directional_pose_count)
        inventory.images[1].width = 1
        assert(exporter.inventory().images[1].width ~= 1, "mutable inventory escaped")
        assert(CatalogRuntime.same(before, CatalogRuntime.snapshot()), "inventory touched live state")
    end)
    test("All pinned actor frames, world phases and shared BLUE identity use production policy", function()
        local before <const> = CatalogRuntime.snapshot()
        for source, entry in pairs(exporter.actors()) do
            for index, grid in pairs(entry.strip.frames) do
                sourcePixels(CeruleanCatalogExporter.frame(source, tonumber(index)), grid, true)
            end
        end
        local make <const> = SpriteFactory.makeSprite
        local source
        SpriteFactory.makeSprite = function(grid, phase)
            if source == "SPRITE_BLUE" then
                equal(phase, nil)
                for _, row in ipairs(grid) do assert(not row:find("1", 1, true), "BLUE greyhair mapping changed") end
            else
                assert(type(phase) == "table", "actor omitted phase")
                equal(phase[1], 0)
                equal(phase[2], 0)
            end
            return make(grid, phase)
        end
        local ok, problem = pcall(function()
            for _, pose in ipairs(exporter.poses()) do
                source = pose.source
                local image <const> = CeruleanContent.poseImage(source, pose.pose, pose.direction)
                if source == "SPRITE_BLUE" then
                    if pose.pose == "stand" then equal(image, SpriteFactory.npc.rival[pose.direction]) end
                else
                    sourcePixels(image, CeruleanContent.sprite(source).frames[tostring(pose.source_frame)], true, pose.flip_x)
                end
            end
        end)
        SpriteFactory.makeSprite = make
        assert(ok, problem)
        assert(CatalogRuntime.same(before, CatalogRuntime.snapshot()), "actor probes touched live state")
    end)
    for _, name in ipairs(exporter.maps()) do
        test("Native isolated map cells, phase and collision: " .. name, function()
            local before <const> = CatalogRuntime.snapshot()
            CatalogRuntime.guard(function()
                local zone <const> = SourceMaps.isolated(name)
                assert(zone.registry ~= WorldTiles)
                local view <const> = WorldView(zone, {attach = false})
                local ok, problem = pcall(function()
                    local image <const> = view:render()
                    local width, height = image:getSize()
                    equal(width, zone.width * 32)
                    equal(height, zone.height * 32)
                    for y = 0, zone.height - 1 do
                        for x = 0, zone.width - 1 do
                            local cell <const> = SourceMaps.cell(name, x, y)
                            equal(zone.collision[y + 1][x + 1], cell.collision)
                            equal(zone.registry:key(zone.tiles[y + 1][x + 1]), cell.key)
                            local grid <const> = SourceMaps.tile(cell.key).grid
                            for _, point in ipairs({{0, 0}, {15, 15}, {16, 16}, {31, 31}}) do
                                local px, py = point[1], point[2]
                                equal(image:sample(x * 32 + px, y * 32 + py), color(grid[py // 2 + 1]:sub(px // 2 + 1, px // 2 + 1), px, py))
                            end
                        end
                    end
                end)
                view:dispose()
                assert(ok, problem)
            end)
            assert(CatalogRuntime.same(before, CatalogRuntime.snapshot()), "isolated map touched live state")
        end)
    end
    test("Actual writer pixels, standalone masks, composites and provenance remain pure", function()
        local before <const> = CatalogRuntime.snapshot()
        local saved = {}
        local function forbid(owner, key)
            saved[#saved + 1] = {owner = owner, key = key, value = owner[key]}
            owner[key] = function() error("catalog attempted live progression: " .. key) end
        end
        forbid(Story, "get")
        forbid(Story, "isActive")
        forbid(CeruleanContent, "installArt")
        forbid(CeruleanContent, "stepImage")
        forbid(WorldDeltas, "ensureZone")
        forbid(ImportedMaps, "ensure")
        forbid(ImportedMaps, "_ensure")
        forbid(RulesRNG, "random")
        forbid(playdate.timer, "new")
        forbid(playdate.frameTimer, "new")
        local isolated <const> = SourceMaps.isolated
        saved[#saved + 1] = {owner = SourceMaps, key = "isolated", value = isolated}
        SourceMaps.isolated = function(name)
            local zone <const> = isolated(name)
            for _, def in ipairs(zone.npcDefs) do def.appearsIf = function() error("visibility predicate evaluated") end end
            return zone
        end
        local poses = {}
        for _, pose in ipairs(exporter.poses()) do poses[pose.name] = pose end
        local base, baseStem, count = nil, nil, 0
        local ok, metadata = pcall(function()
            return VisualCatalog.runExporter("vermilion", function(stem, image, category, mask)
                count = count + 1
                local background <const> = stem:match("__(white)$") or stem:match("__(black)$") or stem:match("__(texture)$")
                if mask then
                    assert(stem == baseStem .. "__mask")
                    local original <const> = base:getMaskImage()
                    if original then pixelsEqual(image, original)
                    else
                        local width, height = image:getSize()
                        for y = 0, height - 1 do for x = 0, width - 1 do equal(image:sample(x, y), gfx.kColorWhite) end end
                    end
                    return
                elseif background then
                    local width, height = image:getSize()
                    local opacity <const> = base:getMaskImage()
                    for y = 0, height - 1 do
                        for x = 0, width - 1 do
                            local visible <const> = not opacity or opacity:sample(x, y) == gfx.kColorWhite
                            local bg <const> = background == "black" or background == "texture" and (x // 4 + y // 4) % 2 == 0
                            equal(image:sample(x, y), visible and base:sample(x, y) or bg and gfx.kColorBlack or gfx.kColorWhite)
                        end
                    end
                    return
                end
                base, baseStem = image, stem
                if category == "source-frame" then
                    local source, index = stem:match("^vermilion%-frame%-(SPRITE_[A-Z_]+)%-(%d+)$")
                    sourcePixels(image, CeruleanContent.sprite(source).frames[index], true)
                elseif category == "source-strip" then
                    local source <const> = stem:sub(#"vermilion-strip-" + 1)
                    for index, grid in pairs(CeruleanContent.sprite(source).frames) do
                        for y = 0, 31 do for x = 0, 31 do
                            equal(image:sample(x, tonumber(index) * 32 + y), color(grid[y // 2 + 1]:sub(x // 2 + 1, x // 2 + 1), x, y))
                        end end
                    end
                elseif category == "vermilion-character" then
                    local pose <const> = assert(poses[stem])
                    sourcePixels(image, CeruleanContent.sprite(pose.source).frames[tostring(pose.source_frame)], true, pose.flip_x)
                elseif category == "imported-tile" then
                    local key <const> = stem:sub(#"tile_imported_" + 1):gsub("..", function(byte) return string.char(tonumber(byte, 16)) end)
                    sourcePixels(image, SourceMaps.tile(key).grid, false)
                elseif category == "ship-source-art" and stem == "vermilion-ship-smoke" then
                    local data <const> = VermilionShipArt.data().smoke
                    local opacity <const> = assert(image:getMaskImage())
                    for y = 0, 31 do for x = 0, 31 do
                        local visible <const> = data.source_indices[(y // 2) % 8 + 1][(x // 2) % 8 + 1] ~= 0
                        equal(opacity:sample(x, y), visible and gfx.kColorWhite or gfx.kColorBlack)
                        if visible then equal(image:sample(x, y), gfx.kColorWhite) end
                    end end
                elseif category == "ship-source-art" and stem == "vermilion-ship-hull" then
                    for cy, row in ipairs(VermilionShipArt.data().hull.cells) do
                        for cx, cell in ipairs(row) do
                            for y = 0, 31 do for x = 0, 31 do
                                equal(image:sample((cx - 1) * 32 + x, (cy - 1) * 32 + y), color(cell.grid[y // 2 + 1]:sub(x // 2 + 1, x // 2 + 1), x, y))
                            end end
                        end
                    end
                elseif category == "ship-presentation" then
                    local frame <const> = assert(tonumber(stem:match("(%d+)$")))
                    local art <const> = VermilionShipArt.data()
                    local timing <const> = VermilionShipTimeline.data()
                    local start <const> = timing.smoke_load_wait + timing.initial_wait + timing.transfer_wait
                    local finish <const> = start + timing.chunks * timing.pixels_per_chunk * timing.source_frames_per_pixel
                    local step <const> = frame < start and 0 or (frame - start) // timing.source_frames_per_pixel
                    local hullX <const> = art.hull.source_x * 32 - step * 2
                    local chunk <const> = step // timing.pixels_per_chunk
                    local hardwareX <const> = (timing.oam_initial_x - (chunk + 1) * timing.puff_chunk_decrement
                        + (step % timing.pixels_per_chunk + 1) * timing.puff_step_drift) & 255
                    local puffX <const> = (timing.reference_view_left + hardwareX - timing.oam_x_offset) * 2
                    local puffY <const> = (timing.oam_y - timing.oam_y_offset - timing.band_top) * 2
                    local width, height = image:getSize()
                    for y = 0, height - 1 do for x = 0, width - 1 do
                        local px, py = x % 32, y % 32
                        local expected = color(art.water_grid[py // 2 + 1]:sub(px // 2 + 1, px // 2 + 1), px, py)
                        local hx <const> = x - hullX
                        if frame < finish and hx >= 0 and hx < 256 then
                            local grid <const> = art.hull.cells[y // 32 + 1][hx // 32 + 1].grid
                            expected = color(grid[py // 2 + 1]:sub((hx % 32) // 2 + 1, (hx % 32) // 2 + 1), hx % 32, py)
                        end
                        local sx, sy = x - puffX, y - puffY
                        if frame >= start and frame < finish and hardwareX > 0 and hardwareX < timing.hardware_width + timing.oam_x_offset
                            and sx >= 0 and sx < 32 and sy >= 0 and sy < 32
                            and art.smoke.source_indices[(sy // 2) % 8 + 1][(sx // 2) % 8 + 1] ~= 0 then
                            expected = gfx.kColorWhite
                        end
                        equal(image:sample(x, y), expected)
                    end end
                elseif category == "cut-presentation" then
                    local frame <const> = assert(tonumber(stem:match("(%d+)$")))
                    local field <const> = FieldMoves.data()
                    local ground <const> = field.tiles["pokered:OVERWORLD:cell:2c-2c-2c-2c"].grid
                    local palette <const> = frame % 2 == 0 and 128 or 228
                    local codes <const> = {["."] = 0, ["1"] = 1, ["2"] = 2, ["#"] = 3}
                    for y = 0, 31 do for x = 0, 63 do
                        local expected = gfx.kColorWhite
                        if x >= 16 and x < 48 then
                            expected = color(ground[y // 2 + 1]:sub((x - 16) // 2 + 1, (x - 16) // 2 + 1), x - 16, y)
                        end
                        local shift <const> = (frame + 1) * 2
                        local tx <const> = x - 16 - (y < 16 and shift or -shift)
                        if tx >= 0 and tx < 32 then
                            local code <const> = field.tree_grid[y // 2 + 1]:sub(tx // 2 + 1, tx // 2 + 1)
                            if code ~= "." then
                                local shade <const> = (palette >> (codes[code] * 2)) & 3
                                expected = color((".12#"):sub(shade + 1, shade + 1), tx, y)
                            end
                        end
                        equal(image:sample(x, y), expected)
                    end end
                elseif category == "cut-source-art" then
                    local palette <const> = assert(tonumber(stem:match("(%d+)$")))
                    local opacity <const> = assert(image:getMaskImage())
                    local codes <const> = {["."] = 0, ["1"] = 1, ["2"] = 2, ["#"] = 3}
                    local grid <const> = FieldMoves.data().tree_grid
                    for y = 0, 31 do for x = 0, 31 do
                        local code <const> = grid[y // 2 + 1]:sub(x // 2 + 1, x // 2 + 1)
                        local shade <const> = (palette >> (codes[code] * 2)) & 3
                        equal(opacity:sample(x, y), code == "." and gfx.kColorBlack or gfx.kColorWhite)
                        if code ~= "." then equal(image:sample(x, y), color((".12#"):sub(shade + 1, shade + 1), x, y)) end
                    end end
                end
            end)
        end)
        for _, record in ipairs(saved) do record.owner[record.key] = record.value end
        assert(ok, metadata)
        equal(count, #exporter.inventory().images)
        equal(#metadata.maps, exporter.inventory().map_count)
        for _, map in ipairs(metadata.maps) do
            local definition <const> = SourceMaps.padded(map.name)
            equal(#map.actors, #definition.events.objects)
            equal(#map.events, #definition.events.objects + #definition.events.background_events + #definition.events.warps + #exporter.hiddenEvents(map.name))
            equal(#map.connections, #definition.connections)
        end
        assert(CatalogRuntime.same(before, CatalogRuntime.snapshot()), "writer touched live state")
    end)
    test("Missing and extra native outputs fail the declared writer protocol", function()
        local row <const> = {path = "vermilion-protocol-probe.png", width = 32, height = 32, category = "probe", mask = false}
        for _, mode in ipairs({"missing", "extra"}) do
            local unregister <const> = VisualCatalog.registerExporter("vermilion-probe-" .. mode, {
                inventory = function() return {images = {row}} end,
                writer = function(sink)
                    if mode == "extra" then sink.save("vermilion-undeclared", gfx.image.new(32, 32, gfx.kColorWhite), "probe") end
                end,
            })
            local ok, problem = pcall(function() VisualCatalog.runExporter("vermilion-probe-" .. mode, function() end) end)
            unregister()
            assert(not ok and tostring(problem):find(mode == "missing" and "missing declared exporter output" or "undeclared exporter path", 1, true), tostring(problem))
        end
        local before <const> = CatalogRuntime.snapshot()
        local ok, problem = pcall(function() VisualCatalog.runExporter("vermilion", function() error("controlled Vermilion consumer failure") end) end)
        assert(not ok and tostring(problem):find("controlled Vermilion consumer failure", 1, true), tostring(problem))
        assert(CatalogRuntime.same(before, CatalogRuntime.snapshot()), "failed consumer touched live state")
    end)
    return report
end
