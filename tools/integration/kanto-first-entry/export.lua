-- PRIVATE SDK export. Loaded only by export.py into its identified harness.
-- Wrapping the deep installers proves their existing checks before publication.
local sources <const> = {}
local fileAPI <const> = playdate.file
local function wrap(owner, name, required)
    local install <const> = owner.install
    owner.install = function(options)
        local before = SourceEvents.trainerDefinitions()
        install(options)
        local trainers, dependencies = {}, {}
        for id, definition in pairs(SourceEvents.trainerDefinitions()) do
            if not before[id] then trainers[id] = definition end
        end
        for _, id in ipairs(required) do
            assert(before[id], "missing shared trainer during export")
            dependencies[#dependencies + 1] = id
        end
        -- Story compares each shared roster in its ordinary deep installer.
        if name == "ceruleanStory" then
            for id in pairs(owner.trainers()) do
                if before[id] then dependencies[#dependencies + 1] = id end
            end
        end
        sources[name] = {events=owner.descriptors(), trainers=trainers, required_trainers=dependencies}
    end
end
wrap(CeruleanStory, "ceruleanStory", {})
wrap(CeruleanRoutes, "ceruleanRoutes", {
    "pokered:CERULEAN_CITY:objects:2", "pokered:ROUTE_24:objects:1",
})
GameBootstrap.afterReady(function()
    assert(sources.ceruleanStory and sources.ceruleanRoutes, "deep Kanto export incomplete")
    local packet = {schema=1, simulator=not not playdate.isSimulator,
        build_id=HarnessBuild.build_id, sources=sources}
    local file = assert(fileAPI.open("kanto-first-entry.tmp", fileAPI.kFileWrite))
    assert(file:write(json.encode(packet)))
    file:close()
    assert(fileAPI.rename("kanto-first-entry.tmp", "kanto-first-entry.json"))
end)
