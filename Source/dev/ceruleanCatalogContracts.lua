-- Root-run SDK contracts. Host checks never substitute for these native pixels.
CeruleanCatalogContracts = {}
local gfx <const> = playdate.graphics
local function eq(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function rejects(callback, fragment)
    local ok, problem = pcall(callback)
    assert(not ok and tostring(problem):find(fragment, 1, true), "expected rejection: " .. tostring(problem))
end
local function paths(inventory)
    local result = {}
    for _, entry in ipairs(inventory.images) do
        assert(not result[entry.path], "duplicate image path")
        result[entry.path] = entry
    end
    return result
end

-- Independent explicit-zero source-bit oracle. Do not read Shade constants or
-- generate a second expected image through the renderer under test.
local function color(code, x, y)
    if code == "." then return gfx.kColorWhite end
    if code == "#" then return gfx.kColorBlack end
    local light = {0xBB,0xFF,0xEE,0xFF,0xBB,0xFF,0xEE,0xFF}
    local dark = {0x55,0xAA,0x55,0xAA,0x55,0xAA,0x55,0xAA}
    assert(code == "1" or code == "2", "unknown source shade")
    local byte = (code == "1" and light or dark)[y % 8 + 1]
    return byte & (0x80 >> (x % 8)) ~= 0 and gfx.kColorWhite or gfx.kColorBlack
end

local function sourcePixels(image, grid, masked)
    local outside = {}
    if masked then
        -- Repeated connectivity relaxation, independent of the factory's queue.
        local changed = true
        while changed do
            changed = false
            for y = 1, 16 do
                for x = 1, 16 do
                    local id = (y-1)*16+x
                    if grid[y]:sub(x,x) == "." and not outside[id]
                        and (x == 1 or x == 16 or y == 1 or y == 16
                            or outside[id-1] or outside[id+1] or outside[id-16] or outside[id+16]) then
                        outside[id], changed = true, true
                    end
                end
            end
        end
    end
    local mask = masked and assert(image:getMaskImage(), "source mask missing")
    for y = 0, 31 do
        for x = 0, 31 do
            local transparent = outside[(y//2)*16+x//2+1]
            if masked then eq(mask:sample(x,y), transparent and gfx.kColorBlack or gfx.kColorWhite) end
            if not transparent then eq(image:sample(x,y), color(grid[y//2+1]:sub(x//2+1,x//2+1), x, y)) end
        end
    end
end

local function imageEqual(a, b)
    local width, height = a:getSize()
    local bw, bh = b:getSize()
    eq(width, bw); eq(height, bh)
    for y = 0, height-1 do for x = 0, width-1 do eq(a:sample(x,y), b:sample(x,y)) end end
    local am, bm = a:getMaskImage(), b:getMaskImage()
    assert((am == nil) == (bm == nil), "mask presence differs")
    if am then
        for y = 0, height-1 do for x = 0, width-1 do eq(am:sample(x,y), bm:sample(x,y)) end end
    end
end

function CeruleanCatalogContracts.run()
    local report = { ok = true, passed = 0, failed = 0, tests = {} }
    local function test(name, callback)
        local ok, problem = pcall(callback)
        report.tests[#report.tests+1] = { name = name, ok = ok, error = not ok and tostring(problem) or nil }
        if ok then report.passed = report.passed+1
        else report.failed = report.failed+1; report.ok = false end
    end
    test("Exact immutable additions leave all 2494 protected names and metadata intact", function()
        local before = CatalogRuntime.snapshot()
        local inventory = CeruleanCatalogExporter.inventory()
        eq(#inventory.images, 2448)
        local first = paths(inventory)
        local baseline = assert(json.decodeFile("dev/catalogProtected.json"))
        for _, entry in ipairs(baseline.images) do assert(not first[entry.path], "protected path claimed") end
        local global = VisualCatalog.expectedInventory()
        eq(#global.images, 2494+2448); eq(#global.exporters.pewter.images, 859)
        local legacy = paths(global.exporters.pewter)
        for path in pairs(legacy) do assert(not first[path], "legacy Pewter path claimed") end
        inventory.images[1].width = 1
        assert(CeruleanCatalogExporter.inventory().images[1].width ~= 1, "inventory exposes mutable owner")
        assert(CatalogRuntime.same(before, CatalogRuntime.snapshot()), "inventory mutated live state")
    end)
    test("All 28 actors declare complete source frames and four-direction pose variants", function()
        local inventory = paths(CeruleanCatalogExporter.inventory())
        local source = SourceMaps.record("data/sourceSlice/sprites.json").sprites
        local stripCount, frameCount, poseCount = 0, 0, 0
        for name, strip in pairs(source) do
            stripCount = stripCount+1
            for frame in pairs(strip.frames) do
                frameCount = frameCount+1
                for _, suffix in ipairs({"", "__mask", "__white", "__black", "__texture"}) do
                    assert(inventory["cerulean-frame-" .. name .. "-" .. frame .. suffix .. ".png"])
                end
            end
        end
        for _, pose in ipairs(CeruleanCatalogExporter.poses()) do
            poseCount = poseCount+1
            local strip = source[pose.source]
            if strip.fixed then eq(pose.pose, "stand"); eq(pose.flip_x, false) end
            for _, suffix in ipairs({"", "__mask", "__white", "__black", "__texture"}) do
                assert(inventory[pose.name .. suffix .. ".png"])
            end
        end
        eq(stripCount, 28); eq(frameCount, 124); eq(poseCount, 240)
    end)
    for _, name in ipairs(SourceMaps.names("source")) do
        test("Private unvisited map terrain and collision: " .. name, function()
            local before = CatalogRuntime.snapshot()
            CatalogRuntime.guard(function()
                local zone = SourceMaps.isolated(name)
                local descriptor = SourceMaps.descriptor(name)
                assert(zone.registry ~= WorldTiles)
                eq(zone.width, descriptor.width); eq(zone.height, descriptor.height)
                eq(#zone.npcDefs, #SourceMaps.padded(name).events.objects)
                local view = WorldView(zone, {attach=false})
                local ok, problem = pcall(function()
                    local image = view:render()
                    for y = 0, zone.height-1 do
                        for x = 0, zone.width-1 do
                            local cell = SourceMaps.cell(name, x, y)
                            eq(zone.collision[y+1][x+1], cell.collision)
                            eq(zone.registry:key(zone.tiles[y+1][x+1]), cell.key)
                            local grid = SourceMaps.tile(cell.key).grid
                            for _, point in ipairs({{0,0}, {15,15}, {16,16}, {31,31}}) do
                                local px, py = point[1], point[2]
                                eq(image:sample(x*32+px,y*32+py), color(grid[py//2+1]:sub(px//2+1,px//2+1),px,py))
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
    test("Native named writer exports actual source pixels, poses, masks and all map layers without installation", function()
        local before = CatalogRuntime.snapshot()
        local forbidden = function() error("catalog attempted runtime installation or progression") end
        local saved = {}
        local function forbid(owner, key)
            saved[#saved+1] = {owner=owner,key=key,value=owner[key]}
            owner[key] = forbidden
        end
        local isolated = SourceMaps.isolated
        saved[#saved+1] = {owner=SourceMaps,key="isolated",value=isolated}
        SourceMaps.isolated = function(name)
            local zone = isolated(name)
            for _, def in ipairs(zone.npcDefs) do def.appearsIf = forbidden end
            return zone
        end
        forbid(Story, "get")
        forbid(Story, "isActive")
        forbid(CeruleanContent, "installArt")
        forbid(CeruleanContent, "stepImage")
        forbid(WorldDeltas, "ensureZone")
        forbid(RulesRNG, "random")
        forbid(playdate.timer, "new")
        forbid(playdate.frameTimer, "new")
        local count, frames, poses, tiles = 0, 0, 0, 0
        local poseByName = {}
        for _, pose in ipairs(CeruleanCatalogExporter.poses()) do poseByName[pose.name] = pose end
        local ok, metadata = pcall(function()
            return VisualCatalog.runExporter("cerulean", function(stem, image, category, mask)
                count = count+1
                if mask or stem:find("__", 1, true) then return end
                if category == "source-frame" then
                    local source, index = stem:match("^cerulean%-frame%-(SPRITE_[A-Z_]+)%-(%d+)$")
                    sourcePixels(image, CeruleanContent.sprite(source).frames[index], true)
                    frames = frames+1
                elseif category == "cerulean-character" then
                    local pose = assert(poseByName[stem])
                    local expected = CeruleanCatalogExporter.frame(pose.source, pose.source_frame)
                    if pose.flip_x then expected = SpriteFactory.flipped(expected) end
                    imageEqual(image, expected)
                    poses = poses+1
                elseif category == "imported-tile" then
                    local key = stem:sub(#"tile_imported_"+1):gsub("..", function(byte) return string.char(tonumber(byte,16)) end)
                    sourcePixels(image, SourceMaps.tile(key).grid, false)
                    tiles = tiles+1
                elseif category == "tutorial-source-art" then
                    local name = stem:sub(#"cerulean-tutorial-"+1)
                    local art = TutorialEscortData.get().art[name]
                    local width, height = image:getSize()
                    eq(width, art.width*2); eq(height, art.height*2)
                    for y = 0, height-1 do
                        for x = 0, width-1 do
                            eq(image:sample(x,y), color(art.rows[y//2+1]:sub(x//2+1,x//2+1), x, y))
                        end
                    end
                elseif category == "tutorial-source-frame" then
                    local name, index = stem:match("^cerulean%-tutorial%-(%a+)%-frame%-(%d+)$")
                    local grid = {}
                    local art = TutorialEscortData.get().art[name]
                    for row = 1, 16 do grid[row] = art.rows[tonumber(index)*16+row] end
                    sourcePixels(image, grid, true)
                end
            end)
        end)
        for _, record in ipairs(saved) do record.owner[record.key] = record.value end
        assert(ok, metadata)
        eq(count, 2448); eq(frames, 124); eq(poses, 240); eq(tiles, 154); eq(#metadata.maps, 18)
        local hiddenCount = 0
        for _, map in ipairs(metadata.maps) do
            local definition = SourceMaps.padded(map.name)
            eq(#map.actors, #definition.events.objects)
            eq(#map.events, #definition.events.objects+#definition.events.warps+#definition.events.background_events
                + #CeruleanCatalogExporter.hiddenEvents(map.name))
            eq(#map.connections, #definition.connections)
            hiddenCount = hiddenCount + #CeruleanCatalogExporter.hiddenEvents(map.name)
        end
        eq(hiddenCount, 21)
        local pc = CeruleanCatalogExporter.hiddenEvents("BillsHouse")[1]
        eq(pc.id, "pokered:BILLS_HOUSE:hidden_events:1")
        eq(pc.source_x, 1); eq(pc.source_y, 4)
        eq(pc.x, 1+SourceMaps.descriptor("BillsHouse").padding)
        assert(CatalogRuntime.same(before, CatalogRuntime.snapshot()), "writer mutated live state")
    end)
    test("Unknown source actors, missing frames, tiles and failed consumers reject explicitly", function()
        rejects(function() CeruleanCatalogExporter.frame("SPRITE_UNKNOWN", 0) end, "missing Blue source sprite")
        rejects(function() CeruleanCatalogExporter.frame("SPRITE_BLUE", 99) end, "missing original actor frame")
        rejects(function() SourceMaps.isolated("UnknownMap") end, "map outside source manifest")
        local records = { ["data/sourceMapCache/tile-grids.json"] = SourceMaps.record("data/sourceMapCache/tile-grids.json") }
        local key = next(CeruleanCatalogExporter.tiles())
        records["data/sourceMapCache/tile-grids.json"].tiles[key] = nil
        SourceMaps._withRecords(records, function()
            rejects(function() SourceMaps.tile(key) end, "unknown canonical source tile")
        end)
        local before = CatalogRuntime.snapshot()
        rejects(function()
            VisualCatalog.runExporter("cerulean", function() error("controlled consumer failure") end)
        end, "controlled consumer failure")
        assert(CatalogRuntime.same(before, CatalogRuntime.snapshot()), "failed writer leaked state")
        rejects(function() VisualCatalog.runExporter("unknown-cerulean", function() end) end, "unknown exporter")
    end)
    return report
end
