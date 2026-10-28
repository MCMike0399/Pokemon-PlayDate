-- Development-only catalog additions for the three immutable 5.5 packages.
-- Active SourceMaps entries own membership; no provider or live actor is loaded.
MidgameCatalogExporter = {}
local shared <const> = CeruleanCatalogExporter
local packages <const> = {"midgameEast", "midgameSouth", "midgameSaffron"}
local kinds <const> = {"terrain", "viewport", "collision", "actors", "events"}

local function keys(values)
    local result = {}
    for key in pairs(values) do
        result[#result + 1] = key
    end
    table.sort(result)
    return result
end

local function packageFor(name)
    local path <const> = SourceMaps.entry(name).path
    for _, package in ipairs(packages) do
        if path == "data/" .. package .. "/" .. name .. ".json" then
            return package
        end
    end
end

function MidgameCatalogExporter.maps()
    local result = {}
    for _, name in ipairs(SourceMaps.names()) do
        if packageFor(name) then
            result[#result + 1] = name
        end
    end
    table.sort(result)
    return result
end

function MidgameCatalogExporter.actors()
    local result = {}
    local previous = {}
    for _, package in ipairs({{root="sourceSlice", owner="cerulean"}, {root="vermilionPreparation", owner="vermilion"}}) do
        for source, strip in pairs(SourceMaps.record("data/" .. package.root .. "/sprites.json").sprites) do
            if previous[source] then
                assert(CatalogRuntime.same(previous[source].strip, strip), "earlier source strip differs")
            else
                previous[source] = {owner=package.owner, strip=strip}
            end
        end
    end
    -- Include only actors actually used by the active new maps.
    for _, name in ipairs(MidgameCatalogExporter.maps()) do
        local package <const> = packageFor(name)
        local strips <const> = SourceMaps.record("data/" .. package .. "/sprites.json").sprites
        for _, event in ipairs(SourceMaps.definition(name).events.objects) do
            local source <const> = event.sprite
            local strip <const> = assert(strips[source], "active map source strip missing")
            assert(CatalogRuntime.same(CeruleanContent.sprite(source), strip), "production source resolver differs")
            local old <const> = previous[source] or result[source]
            assert(not old or CatalogRuntime.same(old.strip, strip), "conflicting midgame strip")
            result[source] = {owner=old and old.owner or "midgame", strip=strip}
        end
    end
    return result
end

function MidgameCatalogExporter.tiles()
    local previous = PewterCatalogExporter.legacyTiles()
    for key, tile in pairs(shared.tiles()) do
        previous[key] = tile
    end
    for key, tile in pairs(VermilionCatalogExporter.tiles()) do
        previous[key] = tile
    end
    local metadata <const> = SourceMaps.compact()
    local result = {}
    for _, name in ipairs(MidgameCatalogExporter.maps()) do
        for _, key in ipairs(metadata.maps[name].palette) do
            if not previous[key] then
                result[key] = assert(metadata.tiles[key], "active palette tile missing")
            end
        end
    end
    return result
end

function MidgameCatalogExporter.poses()
    local result = {}
    for source, entry in pairs(MidgameCatalogExporter.actors()) do
        if entry.owner == "midgame" then
            for _, pose in ipairs(shared.poseInventory({[source]=entry.strip}, "midgame")) do
                result[#result + 1] = pose
            end
        end
    end
    table.sort(result, function(a, b)
        return a.name < b.name
    end)
    return result
end

function MidgameCatalogExporter.inventory()
    local result = {images={}, map_count=0, tile_count=0, actor_strip_count=0,
        source_frame_count=0, directional_pose_count=0, reused_actor_strip_count=0}
    local function add(stem, width, height, category, mask)
        result.images[#result.images + 1] = {path=stem .. ".png", width=width, height=height,
            category=category, mask=mask or false}
    end
    local function asset(stem, width, height, category, composites)
        add(stem, width, height, category)
        add(stem .. "__mask", width, height, category, true)
        if composites then
            for _, background in ipairs({"white", "black", "texture"}) do
                add(stem .. "__" .. background, width, height, category .. "-background")
            end
        end
    end
    for _, name in ipairs(MidgameCatalogExporter.maps()) do
        result.map_count = result.map_count + 1
        local map <const> = SourceMaps.descriptor(name)
        for _, kind in ipairs(kinds) do
            local viewport <const> = kind == "viewport"
            add("midgame-" .. name .. "-" .. kind,
                viewport and 400 or map.width * 32, viewport and 240 or map.height * 32,
                viewport and "map-viewport" or kind == "events" and "events-warps-connections" or kind)
        end
    end
    for _, key in ipairs(keys(MidgameCatalogExporter.tiles())) do
        result.tile_count = result.tile_count + 1
        asset("tile_imported_" .. VisualCatalog.stableName(key), 32, 32, "imported-tile", false)
    end
    for source, entry in pairs(MidgameCatalogExporter.actors()) do
        if entry.owner == "midgame" then
            result.actor_strip_count = result.actor_strip_count + 1
            asset("midgame-strip-" .. source, entry.strip.size[1] * 2, entry.strip.size[2] * 2, "source-strip", true)
            for _, frame in ipairs(keys(entry.strip.frames)) do
                result.source_frame_count = result.source_frame_count + 1
                asset("midgame-frame-" .. source .. "-" .. frame, 32, 32, "source-frame", true)
            end
        else
            result.reused_actor_strip_count = result.reused_actor_strip_count + 1
        end
    end
    for _, pose in ipairs(MidgameCatalogExporter.poses()) do
        result.directional_pose_count = result.directional_pose_count + 1
        asset(pose.name, 32, 32, "midgame-character", true)
    end
    table.sort(result.images, function(a, b)
        return a.path < b.path
    end)
    return result
end

function MidgameCatalogExporter.writer(sink)
    local report = {schema=1, source_revision="af519899719f0754965776faac0e836a3b906e6d",
        maps={}, tiles={}, strips={}, characters=MidgameCatalogExporter.poses(),
        review_status="unreviewed; root native inspection required",
        phase_policy="shared imported tone renderer; source frames explicit-zero; protected world poses unchanged"}
    for _, key in ipairs(keys(MidgameCatalogExporter.tiles())) do
        local tile <const> = SourceMaps.tile(key)
        local stem <const> = "tile_imported_" .. VisualCatalog.stableName(key)
        sink.asset(stem, TileRegistry.renderImportedGrid(tile.grid, TileFactory.renderGrid), "imported-tile", false)
        report.tiles[#report.tiles + 1] = {stable_key=key, path=stem .. ".png", terrain=tile.terrain}
    end
    for _, name in ipairs(MidgameCatalogExporter.maps()) do
        local package <const> = packageFor(name)
        local function hiddenEvents(mapName)
            return shared.hiddenEvents(mapName, "data/" .. package .. "/scripts.json")
        end
        report.maps[#report.maps + 1] = shared.mapImages(name, sink, "midgame", hiddenEvents)
    end
    local actors <const> = MidgameCatalogExporter.actors()
    for _, source in ipairs(keys(actors)) do
        local entry <const> = actors[source]
        local strip <const> = entry.strip
        if entry.owner == "midgame" then
            sink.asset("midgame-strip-" .. source, shared.sourceStrip(source), "source-strip", true)
            for _, frame in ipairs(keys(strip.frames)) do
                sink.asset("midgame-frame-" .. source .. "-" .. frame,
                    shared.frame(source, tonumber(frame)), "source-frame", true)
            end
        end
        report.strips[#report.strips + 1] = {source=source, owner=entry.owner, source_path=strip.source,
            source_sha256=strip.sha256, size=strip.size, frames=keys(strip.frames),
            standing=strip.standing, walking=strip.walking, fixed=strip.fixed,
            catalog_stem=entry.owner .. "-strip-" .. source}
    end
    for _, pose in ipairs(report.characters) do
        sink.asset(pose.name, CeruleanContent.poseImage(pose.source, pose.pose, pose.direction), "midgame-character", true)
    end
    return report
end

function MidgameCatalogExporter.register()
    local maps, npcs = {}, {}
    local tiles <const> = MidgameCatalogExporter.tiles()
    for _, name in ipairs(MidgameCatalogExporter.maps()) do
        maps[SourceMaps.entry(name).id] = true
    end
    for source, entry in pairs(MidgameCatalogExporter.actors()) do
        if entry.owner == "midgame" then
            npcs[CeruleanContent.key(source)] = true
        end
    end
    return VisualCatalog.registerExporter("midgame", {
        inventory=MidgameCatalogExporter.inventory,
        writer=MidgameCatalogExporter.writer,
        ownsZone=function(zone)
            return maps[zone.stableID] == true
        end,
        ownsTile=function(key)
            return tiles[key] ~= nil
        end,
        ownsNPC=function(key)
            return npcs[key] == true
        end,
    })
end
