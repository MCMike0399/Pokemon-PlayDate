-- Optional root-owner observer. Collection ONLY via explicit profiling GC; no view creation, movement, writes,
-- RNG draws or registry/cache mutation. Import/call only in a profiling build.
WorldProfile={}
local samples={}
local frames={}
local full=false
local LIMIT <const> = 512
local function observation(label)
    assert(type(label)=="string" and #label>=1 and #label<=80,"bounded profile label required")
    local value={label=label,time_ms=playdate.getCurrentTimeMilliseconds(),lua_heap_kib=collectgarbage("count"),
        simulator=not not playdate.isSimulator,simulator_value_type=type(playdate.isSimulator),native_heap_available=false,observer_rows=#samples}
    if playdate.graphics and playdate.graphics.sprite then value.sprite_count=#playdate.graphics.sprite.getAllSprites() end
    if zoneRegistry then
        value.zone_count=0;local registries={}
        for _,zone in pairs(zoneRegistry) do value.zone_count=value.zone_count+1;registries[zone.registry]=true end
        value.registry_count,value.tile_slots=0,0
        value.zone_cells=0;for _,zone in pairs(zoneRegistry) do value.zone_cells=value.zone_cells+zone.width*zone.height end
        for registry in pairs(registries) do value.registry_count=value.registry_count+1;value.tile_slots=value.tile_slots+registry:maxID() end
    end
    -- SDK3.1.2 getStats returns nil in Simulator; Lua heap is not total SDK heap.
    return value
end
function WorldProfile.sample(label)
    assert(#samples<LIMIT,"profile sample limit reached")
    local row=observation(label);samples[#samples+1]=row;return row
end
function WorldProfile.begin(label)
    assert(type(label)=="string" and #label<=74,"profile span label requires room for end suffix")
    local row=WorldProfile.sample(label..":begin");row.span_label=label;return row
end
function WorldProfile.finish(token)
    assert(type(token)=="table" and token.time_ms and token.lua_heap_kib,"profile token required")
    local row=WorldProfile.sample((token.span_label or token.label)..":end")
    row.elapsed_ms=row.time_ms-token.time_ms;row.lua_heap_delta_kib=row.lua_heap_kib-token.lua_heap_kib
    if row.sprite_count and token.sprite_count then row.sprite_delta=row.sprite_count-token.sprite_count end
    return row
end
function WorldProfile.collect(label)
    WorldProfile.sample(label..":pre-gc")
    local started=playdate.getCurrentTimeMilliseconds()
    collectgarbage("collect");collectgarbage("collect") -- two explicit profiling passes include finalizer followup
    local elapsed=playdate.getCurrentTimeMilliseconds()-started
    local row=WorldProfile.sample(label..":post-gc")
    row.profiling_gc=true;row.gc_passes=2;row.gc_elapsed_ms=elapsed
end
function WorldProfile.frame(elapsed,phase)
    local item=frames[phase] or {count=0,total_ms=0,max_ms=0,min_ms=1000000}
    item.count=item.count+1;item.total_ms=item.total_ms+elapsed;item.max_ms=math.max(item.max_ms,elapsed);item.min_ms=math.min(item.min_ms,elapsed)
    frames[phase]=item
end
function WorldProfile.publish() full=true end
function WorldProfile.snapshot()
    if full then return WorldProfile.report() end
    return {sample_count=#samples,last=samples[#samples],native_heap_available=false,simulator=not not playdate.isSimulator,simulator_value_type=type(playdate.isSimulator)}
end
function WorldProfile.report()
    local result={schema=1,status="profiling build; no hardware capacity verdict",native_heap_available=false,simulator=not not playdate.isSimulator,simulator_value_type=type(playdate.isSimulator),samples={},frames={}}
    for phase,row in pairs(frames) do result.frames[phase]={count=row.count,mean_ms=row.total_ms/row.count,min_ms=row.min_ms,max_ms=row.max_ms} end
    for i,row in ipairs(samples) do
        local copy={};for key,value in pairs(row) do copy[key]=value end;result.samples[i]=copy
    end
    return result
end
