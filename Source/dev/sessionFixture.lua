-- Historical wire fixtures omit fields introduced after their declared version.
-- Production validation remains strict; this only builds old test inputs.
SessionFixture = {}
function SessionFixture.forVersion(record, version)
    local result = GameSession._copy(record)
    result.version = version
    if version < 4 then
        result.fieldTravel = nil
        result.safari = nil
        result.coins = nil
    end
    if version < 3 then
        result.daycare = nil
    end
    if version < 2 then
        result.fieldWorld = nil
    end
    return result
end

-- Imported entries can be absent after any two-map cache eviction.
function SessionFixture.loadZone(key)
    local provider = WorldDeltas.definitionProvider()
    if provider and provider:hasKey(key) then
        return provider:ensure(key)
    end
    return assert(zoneRegistry[key], "fixture zone is not installed: " .. tostring(key))
end

-- Mutable geometry fixtures use a private registry and the real art preparation.
function SessionFixture.createZone(name, options)
    local profiles = SourceMaps.legacyProfiles({
        dispatch = options.dispatch,
        questFlag = options.questFlag,
        sourceFlag = options.sourceFlag or function()
            return false
        end,
    })
    local profile = profiles[SourceMaps.entry(name).profile]
    return SourceMaps.createZone(name, profile, options.registry, options)
end

-- Synchronous capacity setup does not return to the ordinary frame GC step.
-- Collect discarded preparation objects without advancing any game owners.
function SessionFixture.collectPreparationGarbage(completed)
    if completed % 32 == 0 then
        collectgarbage("collect")
    end
end
