-- Blue water encounter projection. Zone still owns the fail-close; this module
-- is the projection lane A can call without copying a land table onto water.
-- data/wild/maps/SeaRoutes.asm SeaRoutesWildMons is the Route 19 and Route 20
-- table (data/wild/grass_water.asm). Slot weights are the Blue 256-roll odds.
WaterEncounters = {}

function WaterEncounters.project(water)
    assert(type(water) == "table", "Blue water encounter table required")
    assert(Party._integer(water.rate_byte, 0, 255), "invalid Blue water encounter byte")
    if water.rate_byte == 0 then
        assert(Party._array(water.slots, 64) and #water.slots == 0, "invalid disabled water slots")
        return {kind = "byte", value = 0, slots = water.slots}
    end
    assert(Party._array(water.slots, 64) and #water.slots == 10, "invalid Blue water slots")
    local slots, total = {}, 0
    for index, slot in ipairs(water.slots) do
        assert(type(slot.species) == "string" and pokemonData[slot.species], "unresolved Blue water species")
        assert(Party._integer(slot.level, 1, 100) and Party._integer(slot.weight_256, 1, 256),
            "invalid Blue water slot")
        slots[index] = {species = slot.species, minLevel = slot.level, maxLevel = slot.level, weight = slot.weight_256}
        total = total + slot.weight_256
    end
    assert(total == 256, "Blue water weights must sum to 256")
    return {kind = "byte", value = water.rate_byte, slots = slots}
end