-- Pure sparse world projection: only pinned source block identities. New tile
-- grids/metadata still come from the content worker's one shared atlas/cache.
local terrain
local function copy(v) return GameSession._copy(v) end
function VermilionStory.terrainEffects()
    if not terrain then
        terrain=assert(json.decodeFile("data/vermilionStory/terrain.json"))
        assert(terrain.schema==1 and terrain.source_revision=="af519899719f0754965776faac0e836a3b906e6d")
    end
    return copy(terrain.effects)
end
function VermilionStory.sourceWorld(world,effect)
    local spec=assert(VermilionStory.terrainEffects()[effect],"unsupported Vermilion terrain effect")
    local entry=SourceMaps.entry(spec.map)
    local descriptor=WorldDeltas.definitionProvider():descriptor(entry.id)
    local result=copy(world)
    local record
    for _,value in ipairs(result.zones) do if value.zone_id==entry.id then record=value end end
    if not record then
        record={schema=1,zone_id=entry.id,definition_revision=descriptor.revision,tiles={},tile_count=0}
        result.zones[#result.zones+1]=record
    end
    local cells={}
    for _,tile in ipairs(record.tiles) do cells[tile.y*entry.width+tile.x+1]=tile end
    for _,block in ipairs(spec.targets) do
        for q=0,3 do
            local x,y=block.x*2+q%2+entry.padding,block.y*2+q//2
            local key=spec.keys[q+1]
            -- An absent state tile is an integration error; no guessed art,
            -- global tile registration or mutable definition fallback here.
            assert(SourceMaps.compact().tiles[key],"content atlas lacks pinned scene tile: "..key)
            local index=y*entry.width+x+1
            cells[index]=SourceMaps.cell(spec.map,x,y).key~=key and {x=x,y=y,key=key} or nil
        end
    end
    record.tiles={}
    for _,tile in pairs(cells) do record.tiles[#record.tiles+1]=tile end
    table.sort(record.tiles,function(a,b) return a.y==b.y and a.x<b.x or a.y<b.y end)
    record.tile_count=#record.tiles
    if record.tile_count==0 then
        for i,value in ipairs(result.zones) do if value==record then table.remove(result.zones,i);break end end
    end
    table.sort(result.zones,function(a,b) return a.zone_id<b.zone_id end)
    result.zone_count=#result.zones
    return result
end
function VermilionStory.reconcileWorld(game)
    local effect
    if currentZone.stableID=="pokered:VERMILION_GYM" then
        effect=game.session:questFlag("EVENT_2ND_LOCK_OPENED") and "gym-open" or "gym-close"
    elseif currentZone.stableID=="pokered:VERMILION_DOCK" and game.session:questFlag("EVENT_SS_ANNE_LEFT") then
        effect="ship-departed"
    end
    if not effect then return end
    local before=WorldDeltas.export()
    local candidate=VermilionStory.projectWorld(before,effect)
    local function equal(a,b)
        if type(a)~=type(b) then return false end
        if type(a)~="table" then return a==b end
        for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
        for k in pairs(b) do if a[k]==nil then return false end end
        return true
    end
    if equal(before,candidate) then return end
    local ok,reason=VermilionStory.commitIntent(game,"barrier")
    assert(ok,reason)
end
