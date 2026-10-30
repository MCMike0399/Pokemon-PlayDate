-- Direct Source and harness builds keep all validation. Production staging
-- changes these literals only after checking the exact copied source/cache bytes.
ShippedDataPolicy = {}
local mapsQualified <const> = false
local immutableContentQualified <const> = false

function ShippedDataPolicy.maps()
    return mapsQualified and HarnessBuild == nil
end

function ShippedDataPolicy.immutableContent()
    return immutableContentQualified and HarnessBuild == nil
end
