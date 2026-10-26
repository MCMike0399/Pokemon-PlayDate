-- Root-run real SDK checks. This suite neither installs campaign content nor
-- opens exits. It exercises detached source records and shared planners.
import "data/ceruleanContent"
CeruleanContentContracts = {}

local function same(actual, expected)
    assert(type(actual) == type(expected), "source value type differs")
    if type(actual) ~= "table" then
        assert(actual == expected, "source value differs")
        return
    end
    for key, value in pairs(expected) do same(actual[key], value) end
    for key in pairs(actual) do assert(expected[key] ~= nil, "unexpected source field") end
end

local function observation(full)
    local items, capacity = {}, {}
    for id in pairs(ItemData.definitions) do
        items[id] = 0
        capacity[id] = not full
    end
    return { intro = "done", flags = {}, items = items, can_add = capacity,
        trainers = {}, mode = "talk" }
end

function CeruleanContentContracts.run()
    local report = { ok = true, passed = 0, failed = 0, tests = {} }
    local function test(name, fn)
        local ok, problem = pcall(fn)
        report.tests[#report.tests + 1] = { name = name, ok = ok, error = not ok and tostring(problem) or nil }
        if ok then report.passed = report.passed + 1
        else report.failed = report.failed + 1; report.ok = false end
    end
    local entries = SourceMaps.record("data/sourceSlice/manifest-entries.json").maps
    local candidates = {
        ["data/sourceMaps.json"] = SourceMaps.record("data/ceruleanSourceMaps.json"),
        ["data/sourceMapCache/compact.json"] = SourceMaps.record("data/ceruleanMapCache/compact.json"),
        ["data/sourceMapCache/tile-grids.json"] = SourceMaps.record("data/ceruleanMapCache/tile-grids.json"),
    }
    SourceMaps._withRecords(candidates, function()
        for name, entry in pairs(entries) do
            test("shared source projection: " .. name, function()
                local raw = SourceMaps.definition(name)
                local padded = SourceMaps.padded(name)
                local descriptor = SourceMaps.descriptor(name)
                same(SourceMaps.entry(name), entry)
                assert(entry.profile == "source" and raw.name == name)
                assert(descriptor.source_sha256 == entry.source_sha256)
                assert(padded.dimensions.cells[1] == entry.width)
                for y = 0, entry.height - 1 do
                    for x = entry.padding, entry.padding + raw.dimensions.cells[1] - 1 do
                        local cell = SourceMaps.cell(name, x, y)
                        local grid = raw.grids[raw.tile_ids[y + 1][x - entry.padding + 1]]
                        same(SourceMaps.tile(cell.key).grid, grid.grid)
                        assert(cell.terrain.foot_tile == grid.terrain.foot_tile)
                    end
                end
                for _, event in ipairs(raw.events.objects) do
                    local strip = CeruleanContent.sprite(event.sprite)
                    assert(strip.standing.down ~= nil, "source actor lacks standing pose")
                end
            end)
        end
    end)

    local events = CeruleanContent.events()
    for id, descriptor in pairs(events) do
        test("ordinary source plan: " .. id, function()
            local state = observation(false)
            local before = GameSession._copy(state)
            local plan = SourceEvents.compile(descriptor, state, id)
            same(state, before)
            assert(plan.id == id and type(plan.steps) == "table")
            for _, step in ipairs(plan.steps) do SourceEvents.validateStep(step) end
            if descriptor.kind == "pickup" or descriptor.kind == "gift" then
                assert(ItemData.definitions[descriptor.item], "source reward item missing")
                assert(plan.changes.items[1].id == descriptor.item)
                local full = SourceEvents.compile(descriptor, observation(true), id)
                assert(full.changes == nil, "full bag granted source reward")
                state.flags[descriptor.flag] = true
                local repeated = SourceEvents.compile(descriptor, state, id)
                assert(repeated.changes == nil, "completed source reward repeated")
            end
        end)
    end

    local function checkText(value)
        if type(value) == "string" and value:sub(1, 1) == "_" then
            local pages = EventText.pagesFrom({ value }, CeruleanContent.text,
                { wStringBuffer = "TEST ITEM", wAmountMoneyWon = 100 })
            assert(#pages > 0, "empty source dialogue")
        elseif type(value) == "table" then
            for _, item in pairs(value) do checkText(item) end
        end
    end
    test("ordinary event and sign text uses real source text renderer", function()
        checkText(events)
        checkText(CeruleanContent.signs())
    end)
    test("source content copies do not mutate immutable definitions", function()
        local first = CeruleanContent.trainers()
        local id = "pokered:CERULEAN_GYM:objects:1"
        first[id].party[1].level = 100
        assert(CeruleanContent.trainers()[id].party[1].level == 18)
        local text = CeruleanContent.text("_SSTicketReceivedText")
        text.recipe[1].text = "changed"
        assert(CeruleanContent.text("_SSTicketReceivedText").recipe[1].text ~= "changed")
    end)
    test("every direct trainer resolves to production species and bounded source payout", function()
        for id, trainer in pairs(CeruleanContent.trainers()) do
            assert(trainer.id == id and trainer.map_id == "pokered:" .. id:match("^pokered:([^:]+):"))
            assert(trainer.payout == trainer.base_money * trainer.party[#trainer.party].level)
            for _, mon in ipairs(trainer.party) do
                assert(pokemonData[mon.species], "unresolved trainer species: " .. mon.species)
            end
        end
    end)
    test("new source sprite family renders with the real SDK and explicit phase", function()
        local sprites = SourceMaps.record("data/sourceSlice/sprites.json").sprites
        for _, strip in pairs(sprites) do
            for _, grid in pairs(strip.frames) do
                local rendered = SpriteFactory.makeSprite(grid, { 0, 0 })
                local width, height = rendered:getSize()
                assert(width == 32 and height == 32 and rendered:getMask(), "source sprite image/mask missing")
            end
        end
    end)
    return report
end
