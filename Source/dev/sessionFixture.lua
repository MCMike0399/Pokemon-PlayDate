-- Historical wire fixtures omit fields introduced after their declared version.
-- Production validation remains strict; this only builds old test inputs.
SessionFixture = {}
function SessionFixture.forVersion(record, version)
    local result = GameSession._copy(record)
    result.version = version
    if version < 4 then
        result.fieldTravel = nil
    end
    if version < 3 then
        result.daycare = nil
    end
    if version < 2 then
        result.fieldWorld = nil
    end
    return result
end
