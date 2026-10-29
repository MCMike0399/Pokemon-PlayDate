-- Eight reviewed source maps. Raw definitions are weakly cached, not eagerly
-- constructed/registered. Existing zoneRegistry remains the sole Zone owner.
PewterSlice={}
import "world/sourceBindings"
local names = {}
for _, name in ipairs(SourceMaps.names("pewter")) do names[name] = true end
local trainerData,sprites,texts
local function copy(v) if type(v)~="table" then return v end;local out={};for k,x in pairs(v) do out[k]=copy(x) end;return out end
local function record(filename)
    return SourceMaps.record("data/pewterSlice/" .. filename .. ".json")
end
function PewterSlice.names()
    local out={};for name in pairs(names) do out[#out+1]=name end;table.sort(out);return out
end
function PewterSlice.descriptor(name)
    assert(names[name],"map outside Pewter slice")
    local d = SourceMaps.descriptor(name)
    local result = {}
    for _, field in ipairs({"name","id","key","source_width","width","height","padding","warps","connections"}) do result[field] = d[field] end
    result.tileset = d.tileset.constant
    return result
end
function PewterSlice.definition(name)
    assert(names[name], "map outside Pewter slice")
    return SourceMaps.definition(name)
end
local function trainers()
    if not trainerData then
        trainerData={}
        local trainerMeta=record("trainerNames");local display=trainerMeta.names
        for _,d in ipairs(record("trainers").trainers) do
            assert(not trainerData[d.id] and type(d.payout)=="number" and d.payout>=0,"invalid source trainer identity")
            for _,mon in ipairs(d.party) do assert(pokemonData[mon.species] and mon.level>=1 and mon.level<=100,"unresolved trainer species") end
            d.name=assert(display[d.class_source],"unresolved original trainer name")
            d.sprite_source=assert(trainerMeta.sprites[d.id],"unresolved original trainer sprite")
            trainerData[d.id]=d
        end
    end
    return trainerData
end
function PewterSlice.trainers()
    return copy(trainers())
end
function PewterSlice.trainer(id)
    return copy(trainers()[id])
end
function PewterSlice.sprite(source)
    if not sprites then sprites=record("sprites") end
    local binding=assert(sprites.mapping[source],"unresolved original Pewter sprite constant")
    return copy(assert(sprites.sprites[binding.name])),binding.name
end
function PewterSlice.text(label)
    if not texts then texts=record("dialogue").texts end
    return copy(assert(texts[label],"missing original Pewter text: "..tostring(label)))
end
function PewterSlice.compact() return SourceMaps.compact() end
function PewterSlice.cell(name,x,y) return SourceMaps.cell(name,x,y) end
function PewterSlice.tile(key) return SourceMaps.tile(key) end
function PewterSlice.isDoor(name,x,y) return SourceMaps.isDoor(name,x,y) end
function PewterSlice.padded(name)
    assert(names[name], "map outside Pewter slice")
    return SourceMaps.padded(name)
end
function PewterSlice.nameForID(id)
    return SourceMaps.nameForID(id, "pewter")
end
function PewterSlice.warpSpec(name,event) return SourceMaps.warpSpec(name,event) end
function PewterSlice.specs(name,d)
    return SourceBindings.specs(name,d or SourceMaps.padded(name),PewterEvents.has)
end
