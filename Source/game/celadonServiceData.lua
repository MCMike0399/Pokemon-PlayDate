-- Immutable, compact projections of pinned English Blue source only.
CeladonServiceData = {}
local cache = {}
local function record(name)
    if not cache[name] then
        local value = assert(json.decodeFile("data/celadonServices/" .. name .. ".json"))
        assert(value.schema == 1 and value.source_revision == "af519899719f0754965776faac0e836a3b906e6d",
            "unverified Celadon service data")
        cache[name] = value
    end
    return cache[name]
end
function CeladonServiceData.policy()
    return GameSession._copy(record("policy").policy)
end
function CeladonServiceData.text(label)
    local value = record("dialogue").texts[label]
    if value then
        return GameSession._copy(value)
    end
    return CeruleanContent.text(label)
end
