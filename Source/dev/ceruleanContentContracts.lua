-- Root-run real SDK checks. This suite neither installs campaign content nor
-- opens exits. It exercises installed records and shared production owners.
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
    for name, entry in pairs(entries) do
        test("shared source projection: " .. name, function()
            local raw = SourceMaps.definition(name)
            local padded = SourceMaps.padded(name)
            local descriptor = SourceMaps.descriptor(name)
            local installed = SourceMaps.entry(name)
            for field, value in pairs(entry) do same(installed[field], value) end
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
    test("installed inventory constructs all thirty maps with actual actor and surface owners", function()
        assert(#SourceMaps.names() == 65, "installed source inventory differs")
        local registry = TileRegistry()
        local function absent() return false end
        local profiles = SourceMaps.legacyProfiles({
            dispatch = function() error("map witness cannot dispatch") end,
            questFlag = absent, sourceFlag = absent,
        })
        local provider = SourceMaps.createProvider(profiles, registry)
        local oldRegistry, oldList, oldZone = zoneRegistry, zoneList, currentZone
        zoneRegistry, zoneList, currentZone = {}, {}, nil
        local ok, problem = pcall(function()
            WorldDeltas._withDefinitionProvider(provider, function()
                assert(#provider:inventory() == 65)
                for _, name in ipairs(SourceMaps.names()) do
                    local entry = SourceMaps.entry(name)
                    local definition = SourceMaps.padded(name)
                    local surface = provider:surface(entry.id, provider:export())
                    local zone = provider:ensure(entry.key)
                    assert(zone.stableID == entry.id and zone:isSliceReady())
                    assert(surface.width == zone.width and surface.height == zone.height)
                    assert(#zone.npcDefs == #definition.events.objects)
                    local actors = SourceActors.describeSource(entry.id, provider:export())
                    if entry.profile == "viridian" then
                        assert(actors == nil, "legacy static actor policy changed")
                    else
                        assert(actors.zone_id == entry.id and #actors.actors == #definition.events.objects)
                        for index, event in ipairs(definition.events.objects) do
                            local actor = actors.actors[index]
                            assert(actor.id == event.id and actor.x == event.x and actor.y == event.y)
                            assert(zone.npcDefs[index].source_event_id == event.id)
                        end
                    end
                    -- Every unresolved event/script stays visible in the real
                    -- Zone diagnostics. Registration of a scene may close its
                    -- gap later; merely installing its map never does.
                    local issues = {}
                    for _, issue in ipairs(zone:getBindingIssues()) do issues[issue.id] = issue end
                    local options = profiles[entry.profile].options(name, definition)
                    local specs = SourceBindings.specs(name, definition, options.hasEvent)
                    for id, spec in pairs(specs) do
                        if spec.status == "blocked" then
                            assert(issues[id], "unreported source gap: " .. id)
                        else
                            assert(issues[id] == nil, "resolved source event reported as a gap: " .. id)
                        end
                    end
                    for y = 0, zone.height - 1 do
                        for x = 0, zone.width - 1 do
                            assert(zone.collision[y + 1][x + 1] == surface.collision[y + 1][x + 1])
                        end
                    end
                end
            end)
        end)
        provider:disposeCache()
        zoneRegistry, zoneList, currentZone = oldRegistry, oldList, oldZone
        if not ok then error(problem, 0) end
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
            if value == "_MtMoonPokecenterClipboardText" then
                -- The pinned source deliberately opens and closes an empty box.
                -- Qualify this exact body; every other label must have text.
                local record = CeruleanContent.text(value)
                assert(record.source == "text/MtMoonPokecenter.asm")
                same(record.recipe, {
                    { op = "control", source = "text_start", source_line = 47 },
                    { op = "control", source = "done", source_line = 48 },
                })
                assert(#pages == 0, "source clipboard gained invented dialogue")
            else
                assert(#pages > 0, "empty source dialogue: " .. value)
            end
        elseif type(value) == "table" then
            for _, item in pairs(value) do checkText(item) end
        end
    end
    test("ordinary event and sign text uses real source text renderer", function()
        checkText(events)
        checkText(CeruleanContent.signs())
    end)
    test("source bank payout and RAM names remain literal valid UTF-8", function()
        local ram = { player = "RÉD", rival = "BLÜE", wAmountMoneyWon = 175 }
        local pages = EventText.pagesFrom({ "_MoneyForWinningText" }, CeruleanContent.text, ram)
        assert(#pages == 1 and pages[1].text == "RÉD got ¥175 for winning!")
        assert(utf8.len(pages[1].text))
        assert(SourceText.expand("<PLAYER> / <RIVAL>", ram) == "RÉD / BLÜE")
        for _, symbol in ipairs({ "wPlayerName", "wRivalName" }) do
            local value = symbol == "wPlayerName" and ram.player or ram.rival
            local resolved = EventText.pagesFrom({ "_NameWitness" }, function()
                return { source = "native RAM witness", recipe = { { op = "text_ram", symbol = symbol } } }
            end, { [symbol] = value })
            assert(#resolved == 1 and resolved[1].text == value and utf8.len(resolved[1].text))
        end
    end)
    test("tutorial sleepy recipe ends before Fisher global and renders source paragraphs", function()
        local texts = SourceMaps.record("data/tutorialEscort/scenes.json").texts
        local pages = EventText.pagesFrom({ "_ViridianCityOldManSleepyPrivatePropertyText" },
            function(label) return texts[label] end)
        assert(#pages == 2)
        assert(pages[1].text == "You can't go through here!")
        assert(pages[2].text == "This is private property!")
    end)
    test("source renderer still rejects unknown controls and invalid UTF-8 RAM", function()
        local function resolve()
            return { source = "native invalid witness", recipe = {
                { op = "control", source = "unsupported_control" },
            } }
        end
        assert(not pcall(EventText.pagesFrom, { "_InvalidWitness" }, resolve))
        assert(not pcall(SourceText.expand, "<PLAYER>", { player = string.char(255) }))
        assert(not pcall(SourceText.expand, "<RIVAL>", { rival = string.char(255) }))
        assert(not pcall(EventText.pagesFrom, { "_InvalidWitness" }, function()
            return { source = "native invalid witness", recipe = { { op = "text_ram", symbol = "wPlayerName" } } }
        end, { wPlayerName = string.char(255) }))
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
                assert(width == 32 and height == 32 and rendered:getMaskImage(), "source sprite image/mask missing")
            end
        end
    end)
    return report
end
