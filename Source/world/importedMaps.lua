-- Immutable definition validation + sparse durable deltas, independent of the
-- bounded Zone/view cache. Validation never calls the factory/registry.
Class("ImportedMaps")
local stores=setmetatable({},{__mode="k"})
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    local count = 0
    for key, item in pairs(value) do
        result[key] = copy(item)
        count = count + 1
        if count % 32 == 0 and GameBootstrap then
            GameBootstrap.yieldIfDue()
        end
    end
    return result
end
local function object(value,allowed)
    assert(type(value)=="table" and getmetatable(value)==nil,"plain imported world record required")
    for key in pairs(value) do assert(allowed[key],"unsupported imported world field: "..tostring(key)) end
end
local function integer(value,low,high) return type(value)=="number" and value%1==0 and value>=low and value<=high end
local function array(value,count)
    assert(type(value)=="table" and #value==count,"imported world count mismatch")
    local seen=0;for key in pairs(value) do assert(integer(key,1,count),"invalid imported array key");seen=seen+1 end
    assert(seen==count,"sparse imported array")
end
local function rowKey(store,d,x,y)
    assert(integer(x,0,d.width-1) and integer(y,0,d.height-1),"imported cell outside map")
    local id=assert(tonumber(d.tile_rows[y+1]:sub(x*2+1,x*2+2),16),"invalid compact cell index")
    return assert(d.palette[id],"unknown compact palette index")
end
local function metadata(store,key)
    local value=store.data.tiles[key] or store.base[key]
    assert(value,"unknown persistent imported tile key: "..tostring(key))
    return value
end
local function normalized(store,payload)
    object(payload,{schema=true,zone_count=true,zones=true})
    assert(payload.schema==1 and integer(payload.zone_count,0,store.count),"invalid imported world schema/count")
    array(payload.zones,payload.zone_count)
    local zones,seen={},{ }
    for _,value in ipairs(payload.zones) do
        object(value,{schema=true,zone_id=true,definition_revision=true,tile_count=true,tiles=true})
        local d=assert(store.byID[value.zone_id],"unknown imported map delta")
        assert(not seen[d.id] and value.schema==1 and value.definition_revision==d.revision,"duplicate/wrong imported map revision")
        seen[d.id]=true
        assert(integer(value.tile_count,0,d.width*d.height),"invalid imported tile count");array(value.tiles,value.tile_count)
        local tiles,occupied={},{}
        for _,tile in ipairs(value.tiles) do
            object(tile,{x=true,y=true,key=true});local baseline=rowKey(store,d,tile.x,tile.y);local index=tile.y*d.width+tile.x+1
            assert(type(tile.key)=="string" and not occupied[index],"duplicate/invalid imported tile delta")
            occupied[index]=true;metadata(store,tile.key)
            assert(not d.blocked[tostring(index)] or tile.key==baseline,"cannot mutate unresolved imported surface")
            tiles[#tiles+1]={x=tile.x,y=tile.y,key=tile.key}
        end
        table.sort(tiles,function(a,b)return a.y==b.y and a.x<b.x or a.y<b.y end)
        zones[#zones+1]={schema=1,zone_id=d.id,definition_revision=d.revision,tile_count=#tiles,tiles=tiles}
    end
    table.sort(zones,function(a,b)return a.zone_id<b.zone_id end)
    return {schema=1,zone_count=#zones,zones=zones}
end
local function asLedger(payload)
    local ledger={};for _,record in ipairs(payload.zones) do if record.tile_count>0 then ledger[record.zone_id]=record end end;return ledger
end
local function empty(d) return {schema=1,zone_id=d.id,definition_revision=d.revision,tile_count=0,tiles={}} end
local function removeRegistry(store,zone)
    local d=store.byID[zone.stableID]
    assert(zoneRegistry[d.key]==zone,"imported registry ownership replaced")
    zoneRegistry[d.key]=nil
    for index,key in ipairs(zoneList) do if key==d.key then table.remove(zoneList,index);break end end
end
function ImportedMaps:init(data,factory)
    assert(type(data)=="table" and data.schema==1 and data.source_revision=="af519899719f0754965776faac0e836a3b906e6d","unverified compact imported definitions")
    assert(type(factory)=="table" and type(factory.create)=="function" and type(factory.ensureKeys)=="function" and type(factory.release)=="function","explicit native imported factory required")
    -- Only the validated SourceMaps catalogue may be shared read-only. Arbitrary
    -- constructor inputs retain defensive ownership, even with a pinned revision.
    local definitions = data
    if not (SourceMaps and SourceMaps._isSharedCompact(data)) then
        definitions = copy(data)
    end
    local store={data=definitions,factory=factory,byID={},byKey={},base={},ledger={},cache={},order={},pins={},count=0}
    -- Explicit constructor fixtures may reserve identities. The shipping source
    -- provider reserves none: every imported map uses the two disposable slots.
    store.resident = copy(factory.residentKeys or {})
    store.residentCount = 0
    for id=1,37 do local entry=WorldTiles:entry(id);store.base[entry.key]={key=entry.key,collision=entry.collision,terrain=entry.terrain} end
    for name,d in pairs(store.data.maps) do
        assert(d.name==name and not store.byID[d.id] and not store.byKey[d.key] and type(d.revision)=="string","duplicate imported descriptor identity")
        assert(integer(d.width,1,4096) and integer(d.height,1,4096),"invalid imported descriptor dimensions");array(d.tile_rows,d.height)
        for _,row in ipairs(d.tile_rows) do assert(type(row)=="string" and #row==d.width*2 and not row:find("[^0-9a-f]"),"invalid compact imported row") end
        for _,key in ipairs(d.palette) do metadata(store,key) end
        for y = 0, d.height - 1 do
            for x = 0, d.width - 1 do rowKey(store, d, x, y) end
            if GameBootstrap then
                GameBootstrap.yieldIfDue()
            end
        end
        store.byID[d.id],store.byKey[d.key]=d,d;store.count=store.count+1
    end
    for key, resident in pairs(store.resident) do
        assert(resident == true and store.byKey[key], "unknown resident source map")
        store.residentCount = store.residentCount + 1
    end
    stores[self]=store
end
function ImportedMaps:hasID(id) return stores[self].byID[id]~=nil end
function ImportedMaps:hasKey(key) return stores[self].byKey[key]~=nil end
function ImportedMaps:keyForID(id) local d=stores[self].byID[id];return d and d.key end
function ImportedMaps:descriptor(idOrKey)
    local store=stores[self];return copy(assert(store.byID[idOrKey] or store.byKey[idOrKey],"unknown imported descriptor"))
end
function ImportedMaps:owns(zone) return zone and stores[self].cache[zone.stableID]==zone or false end
function ImportedMaps:validate(payload) return normalized(stores[self],payload) end
function ImportedMaps:resolveLocation(location,candidate,options)
    local store=stores[self];local d=assert(store.byID[location.zone_id],"unknown imported location")
    assert(options and options.sliceZones and options.sliceZones[d.id]==true,"imported location outside explicit supported slice")
    assert(location.facing=="up" or location.facing=="down" or location.facing=="left" or location.facing=="right","invalid imported facing")
    local key=rowKey(store,d,location.x,location.y)
    local desired=normalized(store,candidate)
    for _,zone in ipairs(desired.zones) do if zone.zone_id==d.id then
        for _,tile in ipairs(zone.tiles) do if tile.x==location.x and tile.y==location.y then key=tile.key end end
    end end
    assert(not d.blocked[tostring(location.y*d.width+location.x+1)] and metadata(store,key).collision==0,"imported location blocked in candidate world")
    return {zone_id=d.id,x=location.x,y=location.y,facing=location.facing}
end
function ImportedMaps:export()
    local store=stores[self];local zones={}
    for _,value in pairs(store.ledger) do zones[#zones+1]=copy(value) end
    table.sort(zones,function(a,b)return a.zone_id<b.zone_id end)
    return {schema=1,zone_count=#zones,zones=zones}
end
function ImportedMaps:pin(zone)
    local store=stores[self];assert(self:owns(zone),"cannot pin foreign imported Zone")
    local id=zone.stableID;store.pins[id]=(store.pins[id] or 0)+1;local released=false
    return function() if not released then store.pins[id]=store.pins[id]-1;released=true end end
end
function ImportedMaps:_ensure(key)
    local store=stores[self];local d=assert(store.byKey[key],"unknown imported map key")
    local found=store.cache[d.id]
    if found then
        for i,id in ipairs(store.order) do if id==d.id then table.remove(store.order,i);break end end
        store.order[#store.order+1]=d.id;return found
    end
    assert(not zoneRegistry[key],"imported registry key already owned")
    local evict
    local dynamicCount = 0
    for _, id in ipairs(store.order) do
        if not store.resident[store.byID[id].key] then dynamicCount = dynamicCount + 1 end
    end
    if not store.resident[key] and dynamicCount >= 2 then
        for _, id in ipairs(store.order) do
            if not store.resident[store.byID[id].key] and (store.pins[id] or 0) == 0
                and (not currentZone or currentZone.stableID ~= id) then
                evict = id
                break
            end
        end
        assert(evict, "all bounded imported Zone slots are in use")
    end
    local desired=copy(store.ledger[d.id] or empty(d))
    local zone=assert(store.factory.create(d.name,desired),"imported Zone construction failed")
    assert(zone.stableID==d.id and zone.width==d.width and zone.height==d.height,"constructed imported identity/dimensions differ")
    assert(not zoneRegistry[key],"factory may not register imported maps")
    if evict then
        local old=store.cache[evict];store.factory.release(old);removeRegistry(store,old);store.cache[evict]=nil
        for i,id in ipairs(store.order) do if id==evict then table.remove(store.order,i);break end end
    end
    zone:bindDefinitionProvider(self);registerZone(key,zone)
    store.cache[d.id]=zone;store.order[#store.order+1]=d.id
    return zone
end
function ImportedMaps:ensure(key)
    local store=stores[self];local d=assert(store.byKey[key],"unknown imported map key")
    if store.cache[d.id] then return self:_ensure(key) end
    local undoCache=self:checkpointRuntime();local undoTiles=(store.factory.registry or WorldTiles):checkpointRuntime()
    local ok,result=pcall(self._ensure,self,key)
    if not ok then undoCache();undoTiles();error(result,0) end
    return result
end
function ImportedMaps:apply(payload)
    local store=stores[self];local desired=normalized(store,payload);local ledger=asLedger(desired);local undo={}
    local undoRegistry=(store.factory.registry or WorldTiles):checkpointRuntime()
    local ok,problem=pcall(function()
        for id,zone in pairs(store.cache) do
            local record=ledger[id] or empty(store.byID[id]);store.factory.ensureKeys(record.tiles)
            undo[#undo+1]=zone:_commitTiles(zone:_prepareDeltas(record))
        end
    end)
    if not ok then for i=#undo,1,-1 do undo[i]() end;undoRegistry();error(problem,0) end
    local previous=store.ledger;store.ledger=ledger
    return function() for i=#undo,1,-1 do undo[i]() end;store.ledger=previous;undoRegistry() end
end
function ImportedMaps:mutate(zone,x,y,key)
    assert(self:owns(zone),"evicted/foreign imported Zone cannot mutate durable world")
    local store=stores[self];local d=store.byID[zone.stableID];rowKey(store,d,x,y);metadata(store,key)
    local record=copy(store.ledger[d.id] or empty(d));local tiles={}
    for _,tile in ipairs(record.tiles) do if tile.x~=x or tile.y~=y then tiles[#tiles+1]=tile end end
    if key~=rowKey(store,d,x,y) then tiles[#tiles+1]={x=x,y=y,key=key} end;record.tiles,record.tile_count=tiles,#tiles
    local normalizedOne=normalized(store,{schema=1,zone_count=1,zones={record}})
    local undoRegistry=zone.registry:checkpointRuntime()
    local ok,problem=pcall(function()
        store.factory.ensureKeys({{x=x,y=y,key=key}})
        local id=zone.registry:id(key);local entry=zone.registry:entry(id)
        zone:_commitTiles({{x=x,y=y,id=id,collision=d.blocked[tostring(y*d.width+x+1)] and 1 or entry.collision,terrain=entry.terrain}})
    end)
    if not ok then undoRegistry();error(problem,0) end
    store.ledger[d.id]=record.tile_count>0 and normalizedOne.zones[1] or nil
    return key
end
function ImportedMaps:snapshot()
    local store=stores[self];local keys={};for _,id in ipairs(store.order) do keys[#keys+1]=store.byID[id].key end
    return {capacity=2+store.residentCount,cached=keys,delta_zones=self:export().zone_count}
end

-- Capture private cache references before installation; the returned closure is
-- single-use and not a mutable serialized plan. Caller restores currentZone
-- before rollback so native actors/views cannot be evicted beneath an overlay.
function ImportedMaps:checkpointRuntime()
    local store=stores[self];local oldCache,oldOrder,oldLedger,oldList={},{},copy(store.ledger),{}
    for i,key in ipairs(zoneList) do oldList[i]=key end
    for id,zone in pairs(store.cache) do oldCache[id]=zone end
    for i,id in ipairs(store.order) do oldOrder[i]=id end
    local used=false
    return function()
        if used then return end;used=true
        for id,zone in pairs(store.cache) do
            if oldCache[id]~=zone then store.factory.release(zone);removeRegistry(store,zone) end
        end
        for id,zone in pairs(oldCache) do
            local key=store.byID[id].key
            assert(not zoneRegistry[key] or zoneRegistry[key]==zone,"imported rollback registry conflict")
            if not zoneRegistry[key] then registerZone(key,zone) end
        end
        for i=#zoneList,1,-1 do zoneList[i]=nil end
        for i,key in ipairs(oldList) do zoneList[i]=key end
        store.cache,store.order,store.ledger=oldCache,oldOrder,oldLedger
    end
end

-- Explicit actor/session teardown only. Sparse durable state is independent;
-- ordinary eviction never invokes this reset or changes quest/trainer flags.
-- Resident compatibility Zones retain the same lifetime as their former eager
-- registrations; WorldDeltas.reset applies their terrain reset separately.
function ImportedMaps:disposeCache()
    local store=stores[self]
    for _,count in pairs(store.pins) do assert(count==0,"imported actor/view still pinned during reset") end
    local cache, order = {}, {}
    for _, id in ipairs(store.order) do
        local zone = store.cache[id]
        if store.resident[store.byID[id].key] then
            cache[id] = zone
            order[#order + 1] = id
        else
            store.factory.release(zone)
            removeRegistry(store, zone)
        end
    end
    store.cache, store.order, store.pins = cache, order, {}
end
function ImportedMaps:inventory()
    local result={};for _,d in pairs(stores[self].data.maps) do
        result[#result+1]={id=d.id,key=d.key,name=d.name,width=d.width,height=d.height,revision=d.revision}
    end
    table.sort(result,function(a,b)return a.id<b.id end);return result
end

-- Pure current-map collision/foot surface for candidate saves. Numeric palette
-- IDs and native Zones are never allocated; caller receives defensive arrays.
function ImportedMaps:surface(id,candidateWorld)
    local store=stores[self];local d=assert(store.byID[id],"unknown imported surface")
    local records={}
    for _,record in ipairs(candidateWorld.zones)do if store.byID[record.zone_id]then records[#records+1]=record end end
    local checked=normalized(store,{schema=1,zone_count=#records,zones=records});local deltas={}
    for _,record in ipairs(checked.zones)do if record.zone_id==id then
        for _,tile in ipairs(record.tiles)do deltas[tile.y*d.width+tile.x+1]=tile.key end
    end end
    local collision,feet={},{}
    for y=0,d.height-1 do collision[y+1],feet[y+1]={},{}
        for x=0,d.width-1 do
            local index=y*d.width+x+1;local entry=metadata(store,deltas[index]or rowKey(store,d,x,y))
            collision[y+1][x+1]=d.blocked[tostring(index)]and 1 or entry.collision
            feet[y+1][x+1]=entry.terrain.foot_tile
        end
    end
    return {zone_id=id,revision=d.revision,width=d.width,height=d.height,collision=collision,feet=feet}
end

-- Shared source importer/factory used by both world installation facades.
import "world/sourceMapProvider"
