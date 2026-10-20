-- Explicit developer fixtures; no campaign links, story bindings or NPC substitutes.
PilotWorld = {}
local definitions = {}
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end
function PilotWorld.definition(name)
    assert(name == "Route1" or name == "ViridianMart", "unknown pilot map")
    if not definitions[name] then
        local value = assert(json.decodeFile("data/pilotWorld/" .. name .. ".json"))
        assert(value.source_revision == "af519899719f0754965776faac0e836a3b906e6d" and value.schema == 1, "wrong pilot reference revision/schema")
        definitions[name] = value
    end
    return copy(definitions[name])
end
function PilotWorld.create(name, options)
    options = options or {}
    return Zone.fromMapDefinition(PilotWorld.definition(name), options.registry or WorldTiles, options)
end
function PilotWorld.registerFixtures()
    local route = PilotWorld.create("Route1", { terrainFixture = true, spawn = { x = 10, y = 35, facing = "up" } })
    local mart = PilotWorld.create("ViridianMart", { terrainFixture = true, spawn = { x = 3, y = 6, facing = "up" } })
    registerZone("pilot_route1", route)
    registerZone("pilot_viridian_mart", mart)
    return { route = route, mart = mart }
end
function PilotWorld.writeImages(outputDir)
    assert(playdate.isSimulator, "pilot export requires the actual SDK Simulator")
    assert(type(outputDir) == "string" and outputDir:sub(1, 1) == "/" and outputDir:sub(-1) == "/", "absolute existing output directory with trailing slash required")
    local report = { images = {}, binding_issues = {} }
    for _, name in ipairs({ "Route1", "ViridianMart" }) do
        local zone = PilotWorld.create(name, { terrainFixture = true })
        local view = WorldView(zone, { attach = false })
        local image = view:render()
        local filename = name .. "-sdk.png"
        playdate.simulator.writeToFile(image, outputDir .. filename)
        report.images[#report.images + 1] = { path = filename, width = zone.width * TILE_SIZE, height = zone.height * TILE_SIZE, opaque = true }
        report.binding_issues[name] = zone:getBindingIssues()
        view:dispose()
    end
    return report
end
