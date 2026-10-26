-- Root-run contracts for private preparation; no registrations or activation.
VermilionPreparationContracts = {}
local root <const> = "data/vermilionPreparation/"

function VermilionPreparationContracts.run()
    local report = {ok=true, passed=0, failed=0, tests={}}
    local function test(name, fn)
        local ok, problem = pcall(fn)
        report.tests[#report.tests + 1] = {name=name, ok=ok, error=not ok and tostring(problem) or nil}
        if ok then report.passed = report.passed + 1
        else report.failed = report.failed + 1; report.ok = false end
    end
    local events = SourceMaps.record(root .. "events.json")
    local texts = SourceMaps.record(root .. "dialogue.json").texts
    local trainers = SourceMaps.record(root .. "trainers.json").trainers
    local entries = SourceMaps.record(root .. "manifest-entries.json").maps
    local function text(label) return assert(texts[label], "missing preparation text") end
    local function observation(full)
        local items, canAdd = {}, {}
        for id in pairs(ItemData.definitions) do items[id] = 0; canAdd[id] = not full end
        return {intro="done", flags={}, items=items, can_add=canAdd, trainers={}, mode="talk"}
    end
    test("installed batch resolves through the shared sixty-five-map manifest", function()
        assert(#SourceMaps.names() == 65)
        for name, entry in pairs(entries) do
            assert(SourceMaps.nameForID(entry.id) == name)
            local installed = SourceMaps.entry(name)
            assert(installed.path == entry.path and installed.source_sha256 == entry.source_sha256)
        end
    end)
    for _, group in ipairs({events.events, events.signs}) do
        for id, descriptor in pairs(group) do
            test("shared planner preparation " .. id, function()
                local state = observation(false)
                local before = json.encode(state)
                local plan = SourceEvents.compile(descriptor, state, id)
                assert(plan.id == id and #plan.steps > 0)
                assert(json.encode(state) == before, "planner mutated observation")
                if descriptor.kind == "trainer" then
                    local roster = assert(trainers[id])
                    for _, mon in ipairs(roster.party) do assert(pokemonData[mon.species]) end
                    state.trainers[id] = true
                    local after = SourceEvents.compile(descriptor, state, id)
                    assert(after.status == "ready" and after.steps[1].op == "dialog")
                elseif descriptor.kind == "pickup" then
                    assert(ItemData.definitions[descriptor.item])
                    assert(plan.changes.items[1].id == descriptor.item)
                    assert(not SourceEvents.compile(descriptor, observation(true), id).changes)
                    state.flags[descriptor.flag] = true
                    assert(not SourceEvents.compile(descriptor, state, id).changes)
                end
                for _, step in ipairs(plan.steps) do
                    SourceEvents.validateStep(step)
                    local labels = step.labels or step.before
                    if type(labels) == "table" then
                        local pages = EventText.pagesFrom(labels, text,
                            {wStringBuffer="TEST ITEM", wAmountMoneyWon=175})
                        assert(#pages > 0)
                        for _, page in ipairs(pages) do assert(utf8.len(page.text)) end
                    end
                end
            end)
        end
    end
    test("SDK reads literal UTF-8 payout and non-underscore recipe boundaries", function()
        local pages = EventText.pagesFrom({"_MoneyForWinningText"}, text,
            {player="RÉD", wAmountMoneyWon=175})
        assert(pages[1].text == "RÉD got ¥175 for winning!")
        assert(#EventText.pagesFrom({"SSAnneKitchenCook7SalmonDuSaladText"}, text) > 0)
    end)
    test("standard Center has shared fourteen by eight healing geometry", function()
        local d = SourceMaps.record(root .. "VermilionPokecenter.json")
        assert(d.tileset.constant == "POKECENTER" and d.dimensions.cells[1] == 14 and d.dimensions.cells[2] == 8)
        local overrides = {
            ["data/sourceMaps.json"] = SourceMaps.record(root .. "proposed-source-maps.json"),
            ["data/sourceMapCache/compact.json"] = SourceMaps.record(root .. "proposed-compact.json"),
            ["data/sourceMapCache/tile-grids.json"] = SourceMaps.record(root .. "proposed-tile-grids.json"),
            [root .. "VermilionPokecenter.json"] = d,
        }
        SourceMaps._withRecords(overrides, function()
            local layout = HealingComposition.layout({stableID=d.id})
            assert(layout.monitor.x == 56 and layout.monitor.y == 8 and #layout.balls == 6)
        end)
        assert(#SourceMaps.names() == 65, "private source records leaked")
    end)
    return report
end
