-- Production staging excludes dev/. Direct Source builds and all contract
-- harnesses stay deep. Root may change only this literal in private DS1 staging
-- to "production-profile" to measure the production export path with guards.
local mode <const> = "production"
SaveBuildPolicy = {}

function SaveBuildPolicy.ownerExports()
    if HarnessBuild ~= nil then
        return false
    end
    if not playdate or not playdate.file or type(playdate.file.exists) ~= "function" then
        return false
    end
    if playdate.file.exists("dev/saveContracts.pdz") or playdate.file.exists("dev/saveContracts.lua") then
        return false
    end
    if DEVICE_TEST_BUILD then
        return mode == "production-profile"
    end
    return mode == "production"
end
