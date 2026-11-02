-- Private bounded SDK differential; no journey/driver or production registration.
GameCornerMetadataContracts = {}
local function same(a, b)
    assert(type(a) == type(b), "metadata value type differs")
    if type(a) ~= "table" then
        assert(a == b, "metadata value differs")
        return
    end
    for key, value in pairs(a) do
        same(value, b[key])
    end
    for key in pairs(b) do
        assert(a[key] ~= nil, "metadata key differs")
    end
end
function GameCornerMetadataContracts.run()
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
    local function compare(id)
        same(MidgameGymStory.actorMetadata(id), GameCornerMetadataBaseline.actorMetadata(id))
    end
    test("all shipped source event IDs at current activation", function()
        local ids <const> = assert(json.decodeFile("dev/gamecorner_metadata_ids.json"))
        for index, id in ipairs(ids) do
            compare(id)
            if index % 16 == 0 then
                collectgarbage("collect")
            end
        end
        report.source_ids = #ids
    end)
    test("empty, unrelated and non-string keys", function()
        compare("")
        compare("pokered:UNRELATED:objects:1")
        compare("pokered:GAME_CORNER:objects:1")
        compare(false)
        compare(17)
        compare(nil)
    end)
    local original <const> = SourceMaps.nameForID
    for _, active in ipairs({false, true}) do
        test("both Dojo gifts with activation " .. tostring(active), function()
            local ok, why = pcall(function()
                SourceMaps.nameForID = function(id, profile)
                    if id == "pokered:FIGHTING_DOJO" then
                        return active and "FightingDojo" or nil
                    end
                    return original(id, profile)
                end
                for _, index in ipairs({6, 7}) do
                    local id <const> = "pokered:FIGHTING_DOJO:objects:" .. index
                    compare(id)
                    local value <const> = MidgameGymStory.actorMetadata(id)
                    if active then
                        local flag <const> = index == 6 and "EVENT_GOT_HITMONLEE" or "EVENT_GOT_HITMONCHAN"
                        same(value, {visibility = {{group = "quest", id = flag, equals = false}}})
                        value.visibility[1].id = "mutated"
                        compare(id)
                        -- The returned condition must preserve all four flag tuples.
                        for _, lee in ipairs({false, true}) do
                            for _, chan in ipairs({false, true}) do
                                local flags <const> = {EVENT_GOT_HITMONLEE = lee, EVENT_GOT_HITMONCHAN = chan}
                                local condition <const> = MidgameGymStory.actorMetadata(id).visibility[1]
                                assert((flags[condition.id] == condition.equals) == not flags[flag])
                            end
                        end
                    else
                        same(value, {})
                    end
                end
                same(MidgameGymStory.descriptors(), GameCornerMetadataBaseline.descriptors())
            end)
            SourceMaps.nameForID = original
            assert(ok, why)
        end)
    end
    test("unrelated actor performs zero descriptor copies", function()
        local originalCopy <const> = GameSession._copy
        local copies = 0
        local ok, why = pcall(function()
            GameSession._copy = function(value)
                copies = copies + 1
                return originalCopy(value)
            end
            local id <const> = "pokered:GAME_CORNER:objects:1"
            GameCornerMetadataBaseline.actorMetadata(id)
            assert(copies == 2, "exact B baseline must copy Erika and Koga")
            copies = 0
            same(MidgameGymStory.actorMetadata(id), {})
            assert(copies == 0, "unrelated metadata copied descriptors")
        end)
        GameSession._copy = originalCopy
        assert(ok, why)
    end)
    test("public projection remains detached", function()
        local projected <const> = MidgameGymStory.descriptors()
        same(projected, GameCornerMetadataBaseline.descriptors())
        for _, descriptor in pairs(projected) do
            descriptor.species = "mutated"
        end
        same(MidgameGymStory.descriptors(), GameCornerMetadataBaseline.descriptors())
    end)
    return report
end
