-- One prepared SDK contract per new behavior. Root alone executes these.
FieldTravelContracts = {}

local function cell(water)
    return {
        binding_blocked = false, occupied = false, adapter_padding = false,
        water_candidate = water, foot_tile = water and 0x14 or 0,
        land_passable = not water
    }
end

function FieldTravelContracts.run(test)
    test("field-travel: Surf enters water, lands, and respects source pair barriers", function()
        local travel = FieldTravel.empty()
        local position = {zone_id = "pokered:FUCHSIA_CITY", x = 3, y = 4, facing = "down"}
        local before = Party._primitive(travel)
        local plan = assert(FieldTravel.surf(travel, position, cell(false), cell(true), "OVERWORLD", {}))
        assert(plan.travel.mode == "surfing" and plan.location.y == 5)
        assert(FieldMoves.same(travel, before))
        local step = assert(FieldTravel.surfStep(plan.travel, plan.location, cell(true), cell(true), "OVERWORLD"))
        assert(step.travel.mode == "surfing" and step.location.y == 6)
        local landing = assert(FieldTravel.surfStep(step.travel, step.location, cell(true), cell(false), "OVERWORLD"))
        assert(landing.travel.mode == "walking" and landing.location.y == 7)
        local shore = cell(false)
        shore.foot_tile = 0x32
        local coastal = assert(FieldTravel.surf(travel, position, cell(false), shore, "OVERWORLD", {}))
        assert(coastal.travel.mode == "surfing")
        assert(FieldTravel.surfStep(coastal.travel, position, shore, shore, "OVERWORLD").travel.mode == "surfing")
        assert(not FieldTravel.surf(travel, position, cell(false), shore, "SHIP_PORT", {}))
        local blocked = cell(false)
        blocked.foot_tile = 0x05
        assert(not FieldTravel.surfStep(plan.travel, plan.location, cell(true), blocked, "CAVERN"))
        blocked = cell(true)
        blocked.binding_blocked = true
        assert(not FieldTravel.surf(travel, position, cell(false), blocked, "OVERWORLD", {}))
        assert(not FieldTravel.surf(travel, position, cell(false), cell(true), "OVERWORLD", {forcedBicycle = true}))
    end)

    test("field-travel: Strength activates and plans source boulders through actor ownership", function()
        local travel = FieldTravel.empty()
        local active = FieldTravel.strength(travel).travel
        assert(active.strength and not travel.strength)
        local position = {zone_id = "pokered:WARDENS_HOUSE", x = 7, y = 4, facing = "right"}
        local actor = {id = "pokered:WARDENS_HOUSE:objects:3", x = 8, y = 4,
            source_sprite = "SPRITE_BOULDER", movement_byte_2 = 0x10}
        local target = cell(false)
        target.pair_blocked = false
        target.protected = false
        assert(not FieldTravel.push(travel, position, actor, target, 2))
        assert(not FieldTravel.push(active, position, actor, target, 1))
        local push = assert(FieldTravel.push(active, position, actor, target, 2))
        assert(push.to.x == 9 and push.from.x == 8 and actor.x == 8)
        target.occupied = true
        assert(not FieldTravel.push(active, position, actor, target, 2))
        assert(not FieldTravel.enter(active, "pokered:WARDENS_HOUSE").strength)
    end)

    test("field-travel: Fly uses durable visited cities without granting route destinations", function()
        local travel = FieldTravel.empty()
        travel = FieldTravel.enter(travel, "pokered:CERULEAN_CITY")
        travel = FieldTravel.enter(travel, "pokered:ROUTE_4")
        travel = FieldTravel.enter(travel, "pokered:CERULEAN_CITY")
        assert(#travel.visited == 1 and #FieldTravel.destinations(travel) == 1)
        local position = {zone_id = "pokered:ROUTE_2", x = 2, y = 3, facing = "up"}
        local function arrival(entry)
            return {zone_id = entry.id, x = entry.x, y = entry.y, facing = "down"}
        end
        local plan = assert(FieldTravel.fly(travel, position, "pokered:CERULEAN_CITY", true, arrival))
        assert(plan.location.x == 19 and plan.location.y == 18)
        assert(plan.travel.mode == "walking")
        assert(not FieldTravel.fly(travel, position, "pokered:ROUTE_4", true, arrival))
        assert(not FieldTravel.fly(travel, position, "pokered:CERULEAN_CITY", false, arrival))
        assert(not FieldTravel.fly(travel, position, "pokered:CERULEAN_CITY", true, function() return nil end))
        assert(not pcall(FieldTravel.normalize, {version = 1, mode = "walking", strength = false,
            visited = {"pokered:CERULEAN_CITY", "pokered:CERULEAN_CITY"}}))
    end)
end
