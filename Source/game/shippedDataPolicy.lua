-- Direct Source and harness builds keep all validation. Production staging
-- changes only this literal after checking the exact copied map/cache bytes.
ShippedDataPolicy = {}
local mapsQualified <const> = false

function ShippedDataPolicy.maps()
    return mapsQualified and HarnessBuild == nil
end
