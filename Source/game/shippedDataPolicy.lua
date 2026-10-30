-- Direct Source and harness builds keep all validation. Production staging
-- changes these literals only after checking the exact copied source/cache bytes.
ShippedDataPolicy = {}
local fileAPI <const> = playdate.file
local decodeJSON <const> = json.decodeFile
local mapsQualified <const> = false
local immutableContentQualified <const> = false
local regionDeclarationsQualified <const> = false

function ShippedDataPolicy.maps()
    return mapsQualified and HarnessBuild == nil and fileAPI.kFileRead == 3
end

-- SDK 3.1.2 exposes Lua kFileRead=3 (PDX read | Data read). The raw C
-- kFileRead bit is 1: the real SDK origin probe confirms it reads only PDX.
function ShippedDataPolicy.openBundle(path)
    assert(fileAPI.kFileRead == 3, "unsupported shipped file read mode")
    return fileAPI.open(path, 1)
end

function ShippedDataPolicy.readBundleJSON(path)
    local file = assert(ShippedDataPolicy.openBundle(path), "missing shipped JSON: " .. path)
    local ok, value, problem = pcall(decodeJSON, file)
    file:close()
    assert(ok and value, problem or value)
    return value
end

function ShippedDataPolicy.immutableContent()
    return immutableContentQualified and HarnessBuild == nil and fileAPI.kFileRead == 3
end

function ShippedDataPolicy.regionDeclarations()
    return regionDeclarationsQualified and HarnessBuild == nil and fileAPI.kFileRead == 3
end
