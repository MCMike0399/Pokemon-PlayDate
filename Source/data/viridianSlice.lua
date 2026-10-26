-- Explicit four-map slice. Source coordinates remain inspectable after padding.
KantoSlice = {}
import "world/sourceMapProvider"
local names, zoneKeys = {}, {}
for _, name in ipairs(SourceMaps.names("viridian")) do
    names[name] = true
    zoneKeys[name] = SourceMaps.entry(name).key
end
function KantoSlice.definition(name)
    assert(names[name], "map outside explicit slice")
    return SourceMaps.definition(name)
end
function KantoSlice.padded(name)
    assert(names[name], "map outside explicit slice")
    return SourceMaps.padded(name)
end
function KantoSlice.specs(name,definitions)
    return SourceBindings.specs(name,definitions[name],SliceEvents.has)
end
function KantoSlice.create(name,options)
    assert(names[name], "map outside explicit slice")
    options = options or {}
    local adapter = {
        options = function() return SourceBindings.options("viridian",options) end,
    }
    return SourceMaps.createZone(name, adapter, options.registry or WorldTiles)
end
function KantoSlice.connection(name,x,y,direction,intro)
    assert(intro=="done","original Pallet exit remains gated by completed intro")
    if name=="pallet_town" and direction=="up" and y==0 and (x==9 or x==10) then
        return {to=zoneKeys.Route1,x=x+1,y=35,facing="up",source="authored Pallet adaptation +1"}
    end
    if name=="Route1" and direction=="down" and y==35 and (x==10 or x==11) then
        return {to="pallet_town",x=x-1,y=0,facing="down",source="authored Pallet adaptation -1"}
    end
    local value = SourceMaps.connection(name,x,y,direction)
    if value then return value end
    error("unimplemented or invalid source connection: "..tostring(name)..":"..tostring(direction))
end
