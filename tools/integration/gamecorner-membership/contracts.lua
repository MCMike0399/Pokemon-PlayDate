-- Private bounded differential. Root alone executes this SDK contract packet.
GameCornerMembershipContracts = {}
local function same(a, b)
    assert(type(a) == type(b), "projection type differs")
    if type(a) ~= "table" then
        assert(a == b, "projection value differs")
        return
    end
    for key, value in pairs(a) do
        same(value, b[key])
    end
    for key in pairs(b) do
        assert(a[key] ~= nil, "projection key differs")
    end
end
local function copy(value)
    return GameSession._copy(value)
end
local function empty()
    return {schema = 1, zone_count = 0, zones = {}}
end
-- Count the actual original public copier; do not substitute its result.
local function measured(project, world, spec)
    local original <const> = SourceMaps.compact
    local before <const> = copy(world)
    local specBefore <const> = copy(spec)
    local calls = 0
    SourceMaps.compact = function()
        calls = calls + 1
        return original()
    end
    local ok, value = pcall(project, world, spec)
    SourceMaps.compact = original
    same(world, before)
    same(spec, specBefore)
    return ok, value, calls
end
local function compare(world, spec, expectedCalls, rejection)
    local oldOK, oldValue, oldCalls = measured(GameCornerMembershipBaseline.projectBlock, world, spec)
    collectgarbage("collect")
    local newOK, newValue, newCalls = measured(RocketHideoutStoryWorld.projectBlock, world, spec)
    assert(oldCalls == expectedCalls, "original whole-catalogue call count differs")
    assert(newCalls == 0, "candidate copied whole catalogue")
    assert(oldOK == newOK, "projection acceptance differs")
    if rejection then
        assert(not oldOK, "invalid projection accepted")
        assert(tostring(oldValue):find(rejection, 1, true), tostring(oldValue))
        assert(tostring(newValue):find(rejection, 1, true), tostring(newValue))
    else
        assert(oldOK, oldValue)
        same(oldValue, newValue)
    end
    collectgarbage("collect")
end
function GameCornerMembershipContracts.run()
    local report = {ok = true, passed = 0, failed = 0, tests = {}}
    local function test(name, callback)
        local ok, why = pcall(callback)
        report.tests[#report.tests + 1] = {name = name, ok = ok, error = not ok and tostring(why) or nil}
        if ok then
            report.passed = report.passed + 1
        else
            report.failed = report.failed + 1
            report.ok = false
        end
    end
    test("boolean parity for every catalogue key and unknown/nonstring values", function()
        local data <const> = SourceMaps.compact()
        local count = 0
        local function parity(key)
            local value <const> = SourceMaps.hasTile(key)
            assert(type(value) == "boolean")
            assert(value == not not data.tiles[key], "tile truthiness differs")
        end
        for key in pairs(data.tiles) do
            parity(key)
            count = count + 1
        end
        parity(nil)
        for _, key in ipairs({"", "unknown:tile", false, true, 0, 17, {}, function() end, 0 / 0}) do
            parity(key)
        end
        assert(count > 0)
        report.catalogue_keys = count
        -- Public defensive getters remain detached from the membership owner.
        local key <const> = next(data.tiles)
        data.tiles[key] = false
        assert(SourceMaps.hasTile(key))
        local descriptor <const> = SourceMaps.descriptor("GameCorner")
        descriptor.width = -1
        assert(SourceMaps.descriptor("GameCorner").width > 0)
    end)
    test("all six effects with empty, unrelated and overlapping world data: old4/new0", function()
        local count = 0
        for _, spec in pairs(RocketHideoutStory.scenes().terrain) do
            local world <const> = empty()
            compare(world, spec, 4)
            local target <const> = RocketHideoutStoryWorld.projectBlock(world, spec)
            compare(target, spec, 4)
            local other <const> = copy(RocketHideoutStory.scenes().terrain[spec.map == "GameCorner" and "b4-closed" or "entrance-open"])
            local nonempty <const> = RocketHideoutStoryWorld.projectBlock(target, other)
            -- Force a pre-existing target record with a cell outside the block.
            local entry <const> = SourceMaps.entry(spec.map)
            local revision <const> = WorldDeltas.definitionProvider():descriptor(entry.id).revision
            local record
            for _, value in ipairs(nonempty.zones) do
                if value.zone_id == entry.id then
                    record = value
                end
            end
            if not record then
                record = {schema = 1, zone_id = entry.id, definition_revision = revision, tiles = {}}
                nonempty.zones[#nonempty.zones + 1] = record
            end
            record.tiles[#record.tiles + 1] = {x = 0, y = 0, key = spec.keys[1]}
            record.tile_count = #record.tiles
            nonempty.zone_count = #nonempty.zones
            compare(nonempty, spec, 4)
            count = count + 1
        end
        assert(count == 6, "Hideout effect inventory changed")
        report.effects = count
    end)
    test("valid corner blocks and out-of-bounds source cell rejection", function()
        local spec <const> = copy(RocketHideoutStory.scenes().terrain["entrance-open"])
        local entry <const> = SourceMaps.entry(spec.map)
        for _, position in ipairs({{0, 0}, {(entry.width - entry.padding - 2) // 2, (entry.height - 2) // 2}}) do
            spec.x = position[1]
            spec.y = position[2]
            compare(empty(), spec, 4)
        end
        for _, position in ipairs({{-1, 0}, {0, -1}, {entry.width, 0}, {0, entry.height}}) do
            spec.x = position[1]
            spec.y = position[2]
            compare(empty(), spec, 1, "source cell outside map")
        end
    end)
    test("unknown tile rejected at every quadrant with original assertion", function()
        for quadrant = 1, 4 do
            local spec <const> = copy(RocketHideoutStory.scenes().terrain["entrance-open"])
            spec.keys[quadrant] = "unknown:Hideout:tile"
            compare(empty(), spec, quadrant, "content atlas lacks source Hideout block")
        end
    end)
    test("fixture truthiness and restoration retain origin fences", function()
        local records <const> = {
            ["data/sourceMaps.json"] = SourceMaps.record("data/sourceMaps.json"),
            ["data/sourceMapCache/compact.json"] = SourceMaps.record("data/sourceMapCache/compact.json"),
        }
        local tiles <const> = records["data/sourceMapCache/compact.json"].tiles
        tiles["fixture:false"] = false
        tiles["fixture:zero"] = 0
        tiles["fixture:empty"] = ""
        SourceMaps._withRecords(records, function()
            assert(not SourceMaps._usesQualifiedInputs())
            assert(not SourceMaps._isQualifiedCompact(SourceMaps._sharedCompact()))
            assert(not SourceMaps.hasTile("fixture:false"))
            assert(SourceMaps.hasTile("fixture:zero"))
            assert(SourceMaps.hasTile("fixture:empty"))
            local detached <const> = SourceMaps.compact()
            detached.tiles["fixture:zero"] = nil
            assert(SourceMaps.hasTile("fixture:zero"))
        end)
        assert(not SourceMaps.hasTile("fixture:zero"), "fixture leaked")
    end)
    test("lazy record schema, revision and descriptor validation still fail closed", function()
        local manifest <const> = SourceMaps.record("data/sourceMaps.json")
        local compact <const> = SourceMaps.record("data/sourceMapCache/compact.json")
        for _, fault in ipairs({"schema", "revision", "descriptor"}) do
            local bad <const> = copy(compact)
            if fault == "schema" then
                bad.schema = 99
            elseif fault == "revision" then
                bad.source_revision = "unverified"
            else
                bad.maps.GameCorner.width = -1
            end
            local records <const> = {["data/sourceMaps.json"] = manifest, ["data/sourceMapCache/compact.json"] = bad}
            for _, query in ipairs({
                function()
                    return SourceMaps.compact().tiles["unknown"]
                end,
                function()
                    return SourceMaps.hasTile("unknown")
                end,
            }) do
                local ok, why = pcall(function()
                    SourceMaps._withRecords(records, query)
                end)
                assert(not ok, "invalid lazy catalogue accepted")
                local expected <const> = fault == "descriptor" and "generated source descriptor differs from manifest" or "unverified source record"
                assert(tostring(why):find(expected, 1, true), tostring(why))
            end
        end
        assert(SourceMaps.hasTile(RocketHideoutStory.scenes().terrain["entrance-open"].keys[1]))
    end)
    return report
end
