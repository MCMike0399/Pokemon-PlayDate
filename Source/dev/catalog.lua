import "dev/catalogRuntime"
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

-- One string-keyed table cannot grow past 8192 slots in this pool. Path sets
-- for the full export are split so each part stays under that rehash.
local PATH_BUCKETS <const> = 16
local function pathSlot(path)
    local n = #path
    local hash = n * 131 + string.byte(path, 1) + string.byte(path, n)
    if n > 8 then hash = hash + string.byte(path, n - 4) * 17 + string.byte(path, 4) * 257 end
    return (hash % PATH_BUCKETS) + 1
end
local function pathBuckets()
    local buckets = {}
    for index = 1, PATH_BUCKETS do buckets[index] = {} end
    return buckets
end

-- A dense Lua array cannot grow past 8192 slots in this pool: the 16384-slot
-- vector is one contiguous allocation the simulator will not satisfy. Image
-- lists are stored in 4096-entry chunks and sorted through the path buckets.
local IMAGE_CHUNK <const> = 4096
local function sortedImageChunks(groups)
    for index = 1, #groups do
        table.sort(groups[index], function(a, b) return a.path < b.path end)
    end
    local heads = {}
    for index = 1, #groups do heads[index] = 1 end
    local chunks, count = {}, 0
    while true do
        local best, bestPath, bestIndex
        for index = 1, #groups do
            local entry = groups[index][heads[index]]
            if entry and (not bestPath or entry.path < bestPath) then
                best, bestPath, bestIndex = entry, entry.path, index
            end
        end
        if not best then break end
        heads[bestIndex] = heads[bestIndex] + 1
        count = count + 1
        local chunkIndex = math.floor((count - 1) / IMAGE_CHUNK) + 1
        local slot = (count - 1) % IMAGE_CHUNK + 1
        local chunk = chunks[chunkIndex]
        if not chunk then chunk = {}; chunks[chunkIndex] = chunk end
        chunk[slot] = best
    end
    return chunks, count
end

function VisualCatalog.iterImages(inventory)
    local chunks = inventory.image_chunks or {inventory.images}
    local chunk, slot = 1, 0
    return function()
        slot = slot + 1
        local part = chunks[chunk]
        if not part or slot > #part then
            chunk = chunk + 1
            slot = 1
            part = chunks[chunk]
            if not part then return nil end
        end
        return part[slot]
    end
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

-- Only newly added compiled capture bitmaps need materialization before raw
-- Simulator export. Drawing honors the loaded image's logical padding; export
-- disagrees for these loaded images on SDK3.1.2 (observed). The suspected
-- trimmed-storage cause is not a documented SDK guarantee. Never touch factories.
function VisualCatalog.materializeCaptureImage(image)
    local w,h=image:getSize()
    local logical=render(w,h,gfx.kColorClear,function() image:draw(0,0) end)
    -- All nine pinned PNGs store white RGB beneath alpha0. A clear SDK canvas
    -- exports black RGB there; preserve exact source bytes, not only visibility.
    local output=render(w,h,gfx.kColorWhite,function() image:draw(0,0) end)
    output:setMaskImage(assert(logical:getMaskImage(),"capture logical mask missing"))
    return output
end

-- Reversible UTF-8 byte encoding; allocation IDs never enter added filenames.
local function stableName(key)
    assert(type(key)=="string" and #key>0 and #key<=100,"stable content key required (1..100 bytes)")
    return (key:gsub(".",function(c) return string.format("%02x",string.byte(c)) end))
end
VisualCatalog.stableName=stableName
local function same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local exporters={}
local exporting=false
local collecting=false
local registering=false
local protected
local function protection()
    if not protected then
        protected=assert(json.decodeFile("dev/catalogProtected.json"),"reviewed catalog inventory missing")
        assert(protected.schema==1 and #protected.images==1635,"reviewed catalog inventory changed")
    end
    return protected
end
local function pathOK(path)
    return type(path)=="string" and #path<=255 and path:match("^[A-Za-z0-9_-]+%.png$")~=nil
end
local function copyImageList(list)
    local out={}
    for index,entry in ipairs(list) do
        out[index]=Party._primitive(entry)
        list[index]=nil
        -- One full extra copy of a Vermilion-sized list does not fit beside the
        -- original. Drop each source row as its detached copy is kept.
        if index%256==0 then collectgarbage("collect") end
    end
    return out
end
local function rows(record)
    local inventory=CatalogRuntime.guard(record.inventory)
    assert(type(inventory)=="table" and type(inventory.images)=="table","exporter image inventory required")
    assert(Party._array(inventory.images,16384),"bounded dense exporter inventory required")
    local seen={}
    for _,entry in ipairs(inventory.images) do
        assert(pathOK(entry.path) and not seen[entry.path],"unsafe/duplicate exporter inventory path")
        assert(Party._integer(entry.width,1,32768) and Party._integer(entry.height,1,32768),"explicit image dimensions required")
        assert(type(entry.category)=="string" and type(entry.mask)=="boolean","explicit category and mask required")
        seen[entry.path]=true
    end
    seen=nil
    collectgarbage("collect")
    local detached={}
    for key,value in pairs(inventory) do
        if key=="images" or key=="shared_images" then
            assert(Party._array(value,16384),"bounded dense exporter inventory required")
            detached[key]=copyImageList(value)
        else
            detached[key]=Party._primitive(value)
        end
    end
    return detached
end
function VisualCatalog.registerExporter(name,record)
    assert(not exporting and not collecting and not registering,"cannot register during export")
    assert(type(name)=="string" and #name<=64 and name:match("^[a-z][a-z0-9-]*$") and not exporters[name],"invalid/duplicate exporter name")
    assert(type(record)=="table" and type(record.writer)=="function" and type(record.inventory)=="function","named writer/inventory protocol required")
    for key,value in pairs(record) do
        assert(key=="writer" or key=="inventory" or key=="ownsZone" or key=="ownsTile" or key=="ownsNPC","unknown exporter protocol field")
        assert(type(value)=="function","exporter capabilities must be functions")
    end
    local entry={};for key,value in pairs(record) do entry[key]=value end
    registering=true;local checked,problem=pcall(rows,entry);registering=false;assert(checked,problem);exporters[name]=entry
    return function() assert(not exporting and not collecting and not registering,"cannot unregister during export");if exporters[name]==entry then exporters[name]=nil end end
end
function VisualCatalog.runExporter(name,consume,prepared)
    assert(type(consume)=="function","image consumer required")
    local record=assert(exporters[name],"unknown exporter")
    -- The catalog command already built this inventory. Building it again
    -- beside the retained declarations does not fit in the pool.
    local inventory=prepared or rows(record);local allowed,seen={},{}
    for _,entry in ipairs(inventory.images) do allowed[entry.path]=entry end
    assert(not collecting,"exporter already collecting");collecting=true
    local values=table.pack(pcall(function() return CatalogRuntime.guard(function()
        local sink={}
        function sink.save(stem,image,category,mask)
            local path=stem..".png"
            local declared=assert(allowed[path],"undeclared exporter path: "..path)
            assert(not seen[path],"duplicate exporter path: "..path)
            local w,h=image:getSize()
            assert(w==declared.width and h==declared.height and category==declared.category and (mask or false)==declared.mask,"exporter dimensions/metadata mismatch: "..path)
            seen[path]=true;consume(stem,image,category,mask);allowed[path]=nil
        end
        function sink.asset(stem,image,category,backgrounds)
            sink.save(stem,image,category)
            local w,h=image:getSize()
            sink.save(stem.."__mask",image:getMaskImage() or gfx.image.new(w,h,gfx.kColorWhite),category,true)
            if backgrounds then for _,bg in ipairs({"white","black","texture"}) do
                local composite=render(w,h,bg=="black" and gfx.kColorBlack or gfx.kColorWhite,function()
                    if bg=="texture" then for y=0,h-1,4 do for x=0,w-1,4 do if (x//4+y//4)%2==0 then gfx.fillRect(x,y,4,4) end end end end
                    image:draw(0,0)
                end)
                sink.save(stem.."__"..bg,composite,category.."-background")
            end end
        end
        local metadata=record.writer(sink)
        for path in pairs(allowed) do assert(seen[path],"missing declared exporter output: "..path) end
        allowed=nil
        inventory.images, inventory.shared_images = nil, nil
        if VisualCatalog._dropSavedDeclarations then VisualCatalog._dropSavedDeclarations() end
        if SourceMaps and SourceMaps._releaseSharedCompact then SourceMaps._releaseSharedCompact() end
        if SourceMaps and SourceMaps._releaseTileGrids then SourceMaps._releaseTileGrids() end
        collectgarbage("collect")
        -- Copy one top-level record at a time so the source report can be
        -- collected before the next map or pose list is duplicated.
        local function detachReport(value, depth)
            if type(value) ~= "table" then return value end
            local out, keys = {}, {}
            for key in pairs(value) do keys[#keys + 1] = key end
            for index, key in ipairs(keys) do
                local item = value[key]
                value[key] = nil
                out[key] = detachReport(item, depth + 1)
                if depth == 1 and index % 8 == 0 then collectgarbage("collect") end
            end
            return out
        end
        return detachReport(metadata or {}, 0)
    end) end))
    collecting=false;assert(values[1],values[2]);return table.unpack(values,2,values.n)
end
local function owns(kind,value)
    for _,record in pairs(exporters) do if record[kind] and record[kind](value) then return true end end
    return false
end
local function legacyZone(key,zone) return protection().maps[key] or not owns("ownsZone",zone) end
local function legacyNPC(key) return protection().npcs[key] or not owns("ownsNPC",key) end
local function legacyTile(key) return protection().tiles[key] or not owns("ownsTile",key) end
function VisualCatalog.expectedInventory()
    -- Decode the shared map catalogue before the protected image list is
    -- copied. Doing it afterwards asks for the catalogue while the Lua heap
    -- is already near the 16 MiB pool, and the decode dies with
    -- "not enough memory".
    if SourceMaps and SourceMaps._sharedCompact then SourceMaps._sharedCompact() end
    collectgarbage("collect")
    local result={schema=1,exporters={},protected_count=1635,review_status="additions unreviewed"}
    -- The combined export is past 8192 rows. One array of that length cannot
    -- be allocated, so each path bucket keeps its own short list.
    local lists=pathBuckets()
    local seen=pathBuckets()
    local count=0
    -- rows() already returns a detached copy. Share that detached row,
    -- including the decoded protected rows. The export only reads those fields.
    local function add(entry)
        local path=entry.path
        assert(pathOK(path),"duplicate/unsafe catalog path: "..tostring(path))
        local index=pathSlot(path)
        assert(not seen[index][path],"duplicate/unsafe catalog path: "..path)
        seen[index][path]=true
        lists[index][#lists[index]+1]=entry
        count=count+1
    end
    -- Copying the 1635 protected rows first leaves too little of the 16 MiB
    -- pool for the exporter frame lists (cerulean starts near 13696 KiB and
    -- dies). Build the exporter lists while the heap is still near the
    -- post-boot live set, then copy the protected rows.
    for _,name in ipairs(keys(exporters)) do
        collectgarbage("collect")
        local inventory=rows(exporters[name]);result.exporters[name]=inventory
        for _,entry in ipairs(inventory.images) do add(entry) end
        collectgarbage("collect")
        local mark=playdate.file.open("catalog-mark.txt", playdate.file.kFileAppend)
        if mark then mark:write("rows-after "..name.."\t"..tostring(collectgarbage("count")).."\n"); mark:close() end
    end
    local function heapMark(label)
        local file=playdate.file.open("catalog-mark.txt", playdate.file.kFileAppend)
        if file then file:write(label.."\t"..tostring(collectgarbage("count")).."\n"); file:close() end
    end
    local protectedImages=protection().images
    collectgarbage("collect")
    heapMark("protected-decoded "..tostring(#protectedImages).." flat "..tostring(count))
    -- The flat image array is already on its 8192-slot part. Appending the
    -- protected rows grows it to 16384, and that contiguous rehash does not
    -- fit beside the shared catalogue. The rows themselves do not point at
    -- the catalogue, so drop it for the append and the sort, then put it back.
    local provider=WorldDeltas and WorldDeltas.definitionProvider and WorldDeltas.definitionProvider()
    if provider and provider.releaseCatalogue and SourceMaps and SourceMaps._releaseSharedCompact then
        provider:releaseCatalogue()
        SourceMaps._releaseSharedCompact()
        collectgarbage("collect")
    end
    heapMark("protected-catalogue-released "..tostring(collectgarbage("count")))
    for _, entry in ipairs(protectedImages) do add(entry) end
    seen=nil
    collectgarbage("collect")
    heapMark("protected-after "..tostring(count))
    local chunks,packed=sortedImageChunks(lists)
    lists=nil
    collectgarbage("collect")
    assert(packed==count,"catalog image chunks dropped a row")
    result.image_chunks,result.image_count=chunks,packed
    heapMark("images-sorted "..tostring(packed))
    if provider and provider.retargetCatalogue and SourceMaps and SourceMaps._sharedCompact then
        provider:retargetCatalogue(SourceMaps._sharedCompact())
    end
    heapMark("inventory-retargeted "..tostring(collectgarbage("count")))
    return result
end

local function importedTiles()
    local registries,entries={},{}
    if WorldTiles then registries[WorldTiles]=true end
    for key,zone in pairs(zoneRegistry) do if legacyZone(key,zone) then registries[zone.registry]=true end end
    for registry in pairs(registries) do
        for id=1,registry:maxID() do
            local entry=registry:entry(id)
            if entry.kind~="base" and legacyTile(entry.key) then
                assert(entry.kind=="grid","unsupported catalog tile kind")
                assert(not entries[entry.key] or same(entries[entry.key],entry),"conflicting stable catalog tile key: "..entry.key)
                entries[entry.key]=entry
            end
        end
    end
    return entries
end
local function sourceSprites()
    if not SliceSprites then return nil end
    local data=assert(json.decodeFile("data/viridianSlice/sprites.json"),"slice sprite inventory missing")
    assert(data.schema==1 and data.source_revision=="af519899719f0754965776faac0e836a3b906e6d","unverified NPC sprite source")
    return data
end
local function importedMapName(zone) return "map_imported_"..stableName(zone.stableID) end
local originalNPC={oak=true,rival=true,mom=true,daisy=true}
-- Pure inventory seam for root SDK contracts and independent host coverage.
local function additionInventory()
    local result={images={},tiles={},npcs={},maps={},event_art={},runtime_art={}}
    local function add(name,category,backgrounds)
        result.images[#result.images+1]={path=name..".png",category=category,mask=false}
        result.images[#result.images+1]={path=name.."__mask.png",category=category,mask=true}
        if backgrounds then for _,bg in ipairs({"white","black","texture"}) do
            result.images[#result.images+1]={path=name.."__"..bg..".png",category=category.."-background",mask=false}
        end end
    end
    if EventArt then
        assert(type(EventArt.catalogInventory)=="function","EventArt catalog seam required")
        for _,entry in ipairs(EventArt.catalogInventory()) do
            add(entry.name,"event-character",true);result.event_art[#result.event_art+1]=entry
        end
    end
    if CaptureAnimationData then
        for _,name in ipairs(keys(CaptureAnimationData.assets)) do
            assert(name:match("^[a-z0-9-]+$"),"unsafe capture asset key")
            add("capture_"..name,"capture-animation",true)
            result.runtime_art[#result.runtime_art+1]={path="capture_"..name..".png",source_id="pokered:battle-capture:"..name,
                source_path=CaptureAnimationData.assets[name]..".png",phase_policy="original-OAM-monochrome-2x"}
        end
    end
    if Player.getJumpShadowImage then
        add("jump_shadow","jump-shadow",true)
        result.runtime_art[#result.runtime_art+1]={path="jump_shadow.png",source_id="pokered:ledge-shadow:four-oam-quarters",
            source_path="gfx/overworld/shadow.png",phase_policy="black-white-phase-independent"}
    end
    local entries=importedTiles()
    for _,key in ipairs(keys(entries)) do
        add("tile_imported_"..stableName(key),"imported-tile")
        result.tiles[#result.tiles+1]={key=key,collision=entries[key].collision,terrain=entries[key].terrain}
    end
    for _,name in ipairs(keys(SpriteFactory.npc)) do if not originalNPC[name] and legacyNPC(name) then
        assert(#name<=100 and name:match("^[A-Za-z0-9_]+$"),"unsafe runtime NPC key")
        local facings={}
        for _,dir in ipairs({"down","up","left","right"}) do if SpriteFactory.npc[name][dir] then
            add("npc_"..name.."_"..dir,"character",true);facings[#facings+1]=dir
        end end
        result.npcs[#result.npcs+1]={runtime_key=name,facings=facings}
    end end
    local source=sourceSprites()
    if source then for _,name in ipairs(keys(source.sprites)) do
        for _,frame in ipairs(keys(source.sprites[name].frames)) do
            assert(frame=="0" or frame:match("^[1-9]%d?$"),"invalid original sprite frame index")
            add("npc_source_"..stableName(name).."_frame_"..frame,"source-character",true)
        end
    end end
    for _,key in ipairs(keys(zoneRegistry)) do local zone=zoneRegistry[key]
        if zone.imported and legacyZone(key,zone) then
            local prefix=importedMapName(zone)
            for _,suffix in ipairs({"","__viewport","__collision","__events"}) do
                result.images[#result.images+1]={path=prefix..suffix..".png",category="map"}
            end
            result.maps[#result.maps+1]={registry_key=key,stable_id=zone.stableID}
        end
    end
    table.sort(result.images,function(a,b) return a.path<b.path end)
    return result
end

function VisualCatalog.additionInventory() return additionInventory() end

local function writeCatalog(outputDir)
    collectgarbage("collect")
    assert(playdate.isSimulator and playdate.simulator, "catalog requires Simulator")
    assert(type(outputDir) == "string" and outputDir:sub(1, 1) == "/", "absolute output directory required")
    local expected=VisualCatalog.expectedInventory()
    local mark=playdate.file.open("catalog-mark.txt", playdate.file.kFileAppend)
    if mark then mark:write("inventory-done\t"..tostring(collectgarbage("count")).."\n"); mark:close() end
    local declarations,seen=pathBuckets(),pathBuckets()
    for entry in VisualCatalog.iterImages(expected) do declarations[pathSlot(entry.path)][entry.path]=entry end
    -- Map bitmaps are native allocations from the same pool as this Lua heap.
    -- The shared catalogue is not read while the legacy frames are drawn.
    local provider=WorldDeltas and WorldDeltas.definitionProvider and WorldDeltas.definitionProvider()
    if provider and provider.releaseCatalogue and SourceMaps and SourceMaps._releaseSharedCompact then
        provider:releaseCatalogue()
        SourceMaps._releaseSharedCompact()
        collectgarbage("collect")
    end
    local released=playdate.file.open("catalog-mark.txt", playdate.file.kFileAppend)
    if released then released:write("draw-catalogue-released\t"..tostring(collectgarbage("count")).."\n"); released:close() end
    local written=pathBuckets()
    local writtenCount=0
    local manifest = { expected_inventory=expected, exporters={}, schema = 1, images = {}, missing = {}, maps = {}, tiles = {}, source_npcs = {}, event_art = {}, runtime_art = {},
        added_inventory = VisualCatalog.additionInventory(),
        phase = { waterShifts = {0,1,2,3,4,3,2,1}, flowerFrames = {1,2,3,1}, map = "initial factory phase; current zone definitions" },
        limitations = { "Static catalog does not replace frame-sequence journeys.",
            "Map event overlay shows declared NPC/spawn/door positions, not unmodeled scripted trigger regions.",
            "Battle PNGs reproduce pinned pokered art exactly; historical importer revision remains unknown." } }
    local function save(name, image, category, mask)
        local filename = name .. ".png"
        local index=pathSlot(filename)
        assert(pathOK(filename) and not seen[index][filename],"unsafe/duplicate catalog filename: "..filename)
        local declared=assert(declarations[index][filename],"undeclared catalog path: "..filename)
        seen[index][filename]=true
        local w, h = image:getSize()
        assert(w==declared.width and h==declared.height,"catalog dimensions disagree with declaration: "..filename)
        assert(category==declared.category and (mask or false)==declared.mask,"catalog metadata differs from declaration: "..filename)
        playdate.simulator.writeToFile(image, outputDir .. "/" .. filename)
        local row={ path = filename, width = w, height = h, category = category, mask = mask or false }
        written[index][#written[index] + 1] = row
        writtenCount = writtenCount + 1
        -- Native image buffers are larger than their Lua userdata wrappers, so
        -- the Lua heap can sit near 13 MiB while unreferenced map frames still
        -- fill the 16 MiB pool. A full route is hundreds of KiB. Collect after
        -- every large frame so the previous buffer is gone before the next
        -- route is allocated. Small tiles stay on the 32-image cadence.
        -- The image argument is still referenced, so this collect frees only
        -- earlier frames.
        if w * h > 400 * 240 or writtenCount % 32 == 0 then
            collectgarbage("collect")
        end
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
            if legacyNPC(name) then
            for _, dir in ipairs({"down", "up", "left", "right"}) do
                local image=SpriteFactory.npc[name][dir]
                if image then asset("npc_" .. name .. "_" .. dir,image,"character",true) end
            end
        end
        end
        local source=sourceSprites()
        if source then
            for _,name in ipairs(keys(source.sprites)) do
                local entry=source.sprites[name]
                for _,frame in ipairs(keys(entry.frames)) do
                    local prefix="npc_source_"..stableName(name).."_frame_"..frame
                    asset(prefix,SpriteFactory.makeSprite(entry.frames[frame],{0,0}),"source-character",true)
                    manifest.source_npcs[#manifest.source_npcs+1]={name=name,frame=frame,path=prefix..".png",
                        source_revision=source.source_revision,standing=entry.standing,fixed=entry.fixed,pattern_phase={0,0}}
                end
            end
        end
        if EventArt then
            assert(type(EventArt.catalogImages)=="function","EventArt catalog seam required")
            for _,entry in ipairs(EventArt.catalogImages()) do
                asset(entry.name,entry.image,"event-character",true)
                local metadata={}
                for field,value in pairs(entry) do if field~="image" then metadata[field]=value end end
                manifest.event_art[#manifest.event_art+1]=metadata
            end
        end
        if CaptureAnimationData then
            for _,name in ipairs(keys(CaptureAnimationData.assets)) do
                local image=assert(gfx.image.new(CaptureAnimationData.assets[name]),"capture animation image missing")
                asset("capture_"..name,VisualCatalog.materializeCaptureImage(image),"capture-animation",true)
                manifest.runtime_art[#manifest.runtime_art+1]={path="capture_"..name..".png",source_id="pokered:battle-capture:"..name,
                    source_path=CaptureAnimationData.assets[name]..".png",source_revision="af519899719f0754965776faac0e836a3b906e6d",phase_policy="original-OAM-monochrome-2x"}
            end
        end
        if Player.getJumpShadowImage then
            asset("jump_shadow",Player.getJumpShadowImage(),"jump-shadow",true)
            manifest.runtime_art[#manifest.runtime_art+1]={path="jump_shadow.png",source_id="pokered:ledge-shadow:four-oam-quarters",
                source_path="gfx/overworld/shadow.png",source_revision=KantoJumpData.revision,phase_policy="black-white-phase-independent"}
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
                image = nil
            end
            collectgarbage("collect")
        end
        local imported=importedTiles()
        local localImages={}
        for _,key in ipairs(keys(imported)) do
            local entry=imported[key]
            local image = TileRegistry.renderImportedGrid(entry.grid, TileFactory.renderGrid)
            localImages[key]=image
            local prefix="tile_imported_"..stableName(key)
            asset(prefix,image,"imported-tile")
            manifest.tiles[#manifest.tiles+1]={key=key,path=prefix..".png",collision=entry.collision,
                terrain=entry.terrain,kind=entry.kind,pattern_phase={0,0}}
        end
        for _, key in ipairs(keys(zoneRegistry)) do
            local zone = zoneRegistry[key]
            if legacyZone(key,zone) then
            local mapMark=playdate.file.open("catalog-mark.txt", playdate.file.kFileAppend)
            if mapMark then mapMark:write("map "..key.."\t"..tostring(zone.width).."x"..tostring(zone.height).."\t"..tostring(collectgarbage("count")).."\n"); mapMark:close() end
            local prefix=zone.imported and importedMapName(zone) or "map_"..key
            local events={}
            local registryKeys={}
            local kinds = {}
            local w, h = zone.width * TILE_SIZE, zone.height * TILE_SIZE
            local map = render(w, h, gfx.kColorWhite, function()
                for y = 1, zone.height do for x = 1, zone.width do
                    local id=zone.tiles[y][x]
                    local stable=zone.registry:key(id)
                    registryKeys[stable]=true
                    local kind = kinds[id]
                    if not kind then
                        kind = zone.registry:entry(id).kind
                        kinds[id] = kind
                    end
                    local image = kind == "base" and tiles:getImage(zone.registry:id(id))
                        or assert(localImages[stable], "catalog imported tile missing")
                    image:draw((x - 1) * TILE_SIZE, (y - 1) * TILE_SIZE)
                end end
            end)
            save(prefix, map, "map")
            local cx = math.max(0, math.min(w - 400, zone.spawn.x * TILE_SIZE - 200))
            local cy = math.max(0, math.min(h - 240, zone.spawn.y * TILE_SIZE - 120))
            save(prefix .. "__viewport", render(400, 240, gfx.kColorWhite, function()
                map:draw(-cx, -cy)
            end), "map-viewport")
            save(prefix .. "__collision", render(w, h, gfx.kColorWhite, function()
                for y = 1, zone.height do for x = 1, zone.width do
                    if zone.collision[y][x] == 1 then gfx.fillRect((x-1)*TILE_SIZE, (y-1)*TILE_SIZE, TILE_SIZE, TILE_SIZE) end
                end end
            end), "collision")
            -- The collision frame is unreferenced now. Drop it before the
            -- events frame, which has to keep the map image beside it.
            collectgarbage("collect")
            save(prefix .. "__events", render(w, h, gfx.kColorWhite, function()
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
                if zone.imported then
                    for y=0,zone.height-1 do for x=0,zone.width-1 do
                        local rows=zone:sourceEventsAt(x,y)
                        for _,event in ipairs(rows) do
                            events[#events+1]={id=event.id,kind=event.kind,status=event.status,x=x,y=y}
                        end
                        if #rows>0 then
                            local row=rows[1]
                            local label=row.kind=="warps" and "W" or row.kind=="objects" and "O" or "B"
                            mark(x,y,label..(row.status=="bound" and "+" or "?"))
                        end
                    end end
                end
                mark(zone.spawn.x, zone.spawn.y, "S")
            end), "events")
            manifest.maps[#manifest.maps + 1] = { key = key, stable_id=zone.stableID, imported=zone.imported, path=prefix..".png",
                registry_keys=keys(registryKeys), source_events=events, binding_issues=zone:getBindingIssues(),
                width = zone.width, height = zone.height, doors = zone.doors,
                coordinates = "zero-based movement cells; 32 Playdate pixels/cell", npcPolicy = "all definitions, including conditional; predicates not evaluated" }
            map = nil
            collectgarbage("collect")
            end
        end
        localImages = nil
        collectgarbage("collect")
        if SourceMaps and SourceMaps._separateCatalogueCaches then SourceMaps._separateCatalogueCaches(true) end
        -- One exporter's rows plus the compact catalogue fit. All four
        -- inventories together do not, so the idle ones are spilled to files
        -- and restored when that exporter draws.
        local function eachEntry(list, fn)
            if type(list) ~= "table" then return end
            local count = #list
            for index = 1, count do
                local entry = list[index]
                if type(entry) == "table" and entry.path then fn(entry) end
            end
        end
        local function spill(name, kind, list)
            local file = playdate.file.open("catalog-keep-" .. name .. "-" .. kind .. ".txt", playdate.file.kFileWrite)
            assert(file, "catalog keep file")
            eachEntry(list, function(entry)
                file:write(entry.path .. "\t" .. tostring(entry.width) .. "\t" .. tostring(entry.height) .. "\t" .. entry.category .. "\t" .. (entry.mask and "1" or "0") .. "\n")
            end)
            file:close()
        end
        local function restore(name, kind)
            local list = {}
            local file = playdate.file.open("catalog-keep-" .. name .. "-" .. kind .. ".txt")
            if file then
                while true do
                    local line = file:readline()
                    if not line or line == "" then break end
                    local path, width, height, category, mask = line:match("^([^\t]+)\t(%d+)\t(%d+)\t([^\t]+)\t([01])$")
                    assert(path, "catalog keep line")
                    local entry = {path = path, width = tonumber(width), height = tonumber(height), category = category, mask = mask == "1"}
                    local slot = pathSlot(path)
                    if not seen[slot][path] then
                        list[#list + 1] = entry
                        declarations[slot][path] = entry
                    end
                end
                file:close()
            end
            return list
        end
        local owned = pathBuckets()
        for _, name in ipairs(keys(exporters)) do
            local inventory = expected.exporters[name]
            spill(name, "images", inventory.images)
            spill(name, "shared", inventory.shared_images)
            eachEntry(inventory.images, function(entry) owned[pathSlot(entry.path)][entry.path] = name end)
            eachEntry(inventory.shared_images, function(entry) owned[pathSlot(entry.path)][entry.path] = name end)
        end
        local function parkOthers(active)
            -- A later exporter can list the same path in shared_images. That
            -- must not drop the row while the exporter that writes it is active.
            local keep = pathBuckets()
            local activeInventory = expected.exporters[active]
            if activeInventory then
                eachEntry(activeInventory.images, function(entry) keep[pathSlot(entry.path)][entry.path] = true end)
                eachEntry(activeInventory.shared_images, function(entry) keep[pathSlot(entry.path)][entry.path] = true end)
            end
            for slot = 1, PATH_BUCKETS do
                for path, owner in pairs(owned[slot]) do
                    if seen[slot][path] or (owner ~= active and not keep[slot][path]) then
                        declarations[slot][path] = nil
                    end
                end
                for path in pairs(seen[slot]) do declarations[slot][path] = nil end
            end
            expected.image_chunks = nil
            for other, inventory in pairs(expected.exporters) do
                if other ~= active then inventory.images, inventory.shared_images = nil, nil end
            end
            local inventory = expected.exporters[active]
            local function compact(list)
                local out = {}
                eachEntry(list, function(entry)
                    if not seen[pathSlot(entry.path)][entry.path] then out[#out + 1] = entry end
                end)
                return out
            end
            if inventory then
                inventory.images = compact(inventory.images)
                inventory.shared_images = compact(inventory.shared_images)
            end
            collectgarbage("collect")
        end
        -- Saved rows stay in the manifest. The declaration copies of those
        -- rows are what push the next catalogue decode over the pool.
        VisualCatalog._dropSavedDeclarations = function()
            for slot = 1, PATH_BUCKETS do
                for path in pairs(seen[slot]) do declarations[slot][path] = nil end
            end
            local function drop(list)
                if type(list) ~= "table" then return end
                local count = #list
                for index = 1, count do
                    local entry = list[index]
                    if type(entry) == "table" and entry.path and seen[pathSlot(entry.path)][entry.path] then
                        list[index] = nil
                    end
                end
            end
            if expected.image_chunks then
                for _, chunk in ipairs(expected.image_chunks) do drop(chunk) end
            end
            for _, inventory in pairs(expected.exporters) do
                drop(inventory.images)
                drop(inventory.shared_images)
            end
            collectgarbage("collect")
        end
        local exporterNames=keys(exporters)
        for index,name in ipairs(exporterNames) do
            if index > 1 then
                local inventory=expected.exporters[name]
                inventory.images=restore(name,"images")
                inventory.shared_images=restore(name,"shared")
            end
            parkOthers(name)
            local exporterMark=playdate.file.open("catalog-mark.txt", playdate.file.kFileAppend)
            if exporterMark then exporterMark:write("exporter "..name.."\t"..tostring(collectgarbage("count")).."\n"); exporterMark:close() end
            manifest.exporters[name]=VisualCatalog.runExporter(name,save,expected.exporters[name])
            expected.exporters[name].images, expected.exporters[name].shared_images = nil, nil
            if provider and provider.releaseCatalogue and SourceMaps and SourceMaps._releaseSharedCompact then
                provider:releaseCatalogue()
                SourceMaps._releaseSharedCompact()
                collectgarbage("collect")
            end
        end
        for index=1,PATH_BUCKETS do for path in pairs(declarations[index]) do assert(seen[index][path],"missing declared catalog output: "..path) end end
    end)
    gfx.popContext()
    assert(ok, err)
    local chunks,packed=sortedImageChunks(written)
    assert(packed==writtenCount,"catalog manifest dropped an image row")
    manifest.images=chunks
    return manifest
end
-- One exporter per Simulator process. The 16 MiB pool resets on the next
-- launch; this does not shrink or split the image list inside one export.
local function writeOneExporter(outputDir, name)
    collectgarbage("collect")
    assert(playdate.isSimulator and playdate.simulator, "catalog requires Simulator")
    assert(type(outputDir) == "string" and outputDir:sub(1, 1) == "/", "absolute output directory required")
    assert(type(name) == "string" and exporters[name], "unknown catalog exporter: " .. tostring(name))
    if Contracts and Contracts.releaseSuiteCode then Contracts.releaseSuiteCode() end
    local written, seen = {}, {}
    gfx.pushContext()
    local function save(stem, image, category, mask)
        local filename = stem .. ".png"
        assert(pathOK(filename) and not seen[filename], "unsafe/duplicate catalog filename: " .. filename)
        seen[filename] = true
        local w, h = image:getSize()
        playdate.simulator.writeToFile(image, outputDir .. "/" .. filename)
        written[#written + 1] = { path = filename, width = w, height = h, category = category, mask = mask or false }
        if w * h > 400 * 240 then collectgarbage("collect") end
    end
    local ok, metadata = pcall(function() return VisualCatalog.runExporter(name, save) end)
    gfx.popContext()
    assert(ok, metadata)
    table.sort(written, function(a, b) return a.path < b.path end)
    return { schema = 1, exporter = name, images = written, missing = {}, exporters = { [name] = metadata } }
end
function VisualCatalog.write(outputDir, only)
    if only ~= nil then
        collectgarbage("collect")
        assert(not exporting, "catalog export already running")
        exporting = true
        local result = table.pack(pcall(function()
            return CatalogRuntime.guard(function() return writeOneExporter(outputDir, only) end)
        end))
        exporting = false
        assert(result[1], result[2])
        return table.unpack(result, 2, result.n)
    end
    collectgarbage("collect")
    -- Suite closures are not part of the export. Drop them before the one
    -- inventory pass so the declarations and the map frames share the pool.
    if Contracts and Contracts.releaseSuiteCode then Contracts.releaseSuiteCode() end
    local mark=playdate.file.open("catalog-mark.txt", playdate.file.kFileWrite)
    if mark then mark:write("after-release\t"..tostring(collectgarbage("count")).."\n"); mark:close() end
    assert(not exporting,"catalog export already running")
    exporting=true
    local result=table.pack(pcall(function() return CatalogRuntime.guard(function() return writeCatalog(outputDir) end) end))
    exporting=false
    assert(result[1],result[2]);return table.unpack(result,2,result.n)
end
