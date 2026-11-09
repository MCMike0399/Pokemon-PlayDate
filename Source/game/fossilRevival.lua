-- Unactivated Cinnabar Lab fossil revival. Maps stay uninstalled.
-- This module does not register the scientist, place the lab, or run from main.
-- ROOT_HOOK: import "game/fossilRevival"
-- ROOT_ANCHOR: import "domain/gameSession"
-- That line belongs directly after the anchor. Loading the module does not make the lab playable.
import "game/lateKantoStory"

FossilRevival = {}
local pending = setmetatable({}, {__mode = "k"})
local speciesByName

local function speciesId(symbol)
    if not speciesByName then
        speciesByName = {}
        for id, name in pairs(PokemonNames) do
            assert(speciesByName[name] == nil, "duplicate species name")
            speciesByName[name] = id
        end
    end
    return assert(speciesByName[symbol], "unknown fossil species")
end

local function itemId(symbol)
    return assert(ItemData.bySymbol[symbol], "unknown fossil item")
end

local function rows(revival)
    local byItem = {}
    local seenSpecies = {}
    assert(type(revival.results) == "table" and #revival.results >= 1, "fossil results required")
    for _, row in ipairs(revival.results) do
        assert(type(row) == "table" and type(row.item) == "string" and type(row.species) == "string",
            "fossil result changed")
        assert(byItem[row.item] == nil and seenSpecies[row.species] == nil, "fossil results are not distinct")
        byItem[row.item] = row
        seenSpecies[row.species] = true
        itemId(row.item)
        speciesId(row.species)
    end
    return byItem
end

-- The pinned table names every flag. Gave is the give flag the island does not clear.
local function identity(revival)
    local clear = revival.still_reviving_cleared_on_map_load
    assert(type(clear) == "table" and type(clear.event) == "string" and type(clear.map_constant) == "string"
        and type(clear.map) == "string", "fossil map clear changed")
    assert(revival.handover_when_still_reviving_clear == true, "fossil handover gate changed")
    local still = clear.event
    local gave
    assert(type(revival.give_sets) == "table", "fossil give flags changed")
    for _, flag in ipairs(revival.give_sets) do
        assert(type(flag) == "string", "fossil give flags changed")
        if flag ~= still then
            assert(gave == nil, "fossil give flags changed")
            gave = flag
        end
    end
    assert(gave ~= nil, "fossil give flags changed")
    assert(type(revival.handover_sets) == "table" and #revival.handover_sets == 1, "fossil handover flag changed")
    local handing = revival.handover_sets[1]
    assert(type(handing) == "string" and handing ~= gave and handing ~= still, "fossil handover flag changed")
    local reset = {}
    assert(type(revival.success_resets) == "table", "fossil success reset changed")
    for _, flag in ipairs(revival.success_resets) do
        assert(reset[flag] == nil, "fossil success reset changed")
        reset[flag] = true
    end
    assert(reset[gave] and reset[still] and reset[handing], "fossil success reset changed")
    local extras = 0
    for _ in pairs(reset) do extras = extras + 1 end
    assert(extras == 3, "fossil success reset changed")
    local level = type(revival.level) == "number" and math.tointeger(revival.level) or nil
    assert(level and level >= 1 and level <= 100, "fossil level changed")
    rows(revival)
    return gave, still, handing, level
end

local function bind(revival)
    if revival == nil then
        revival = LateKantoStory.scenes().fossil_revival
    end
    assert(type(revival) == "table", "fossil revival table required")
    identity(revival)
    return revival
end

local function pack(ok, status, extra)
    local result = {ok = ok, status = status}
    if extra then
        for key, value in pairs(extra) do result[key] = value end
    end
    return result
end

function FossilRevival.plan()
    return GameSession._copy(bind(nil))
end

function FossilRevival.pending(session)
    local value = pending[session]
    if not value then return nil end
    return {item = value.item, species = value.species}
end

function FossilRevival.fossilsInBag(session, revival)
    revival = bind(revival)
    local bag = session:inventory()
    local found = {}
    for _, row in ipairs(revival.results) do
        if bag:quantity(itemId(row.item)) > 0 then
            found[#found + 1] = row.item
        end
    end
    return found
end

-- Menu cancel (B) writes no fossil register, item, or flag.
function FossilRevival.cancel()
    return pack(true, "cancelled")
end

-- Selecting a listed fossil records wFossilItem/wFossilMon before Yes/No.
-- Yes then removes that one key item and sets the two give flags together.
function FossilRevival.confirm(session, itemSymbol, accepted, revival)
    revival = bind(revival)
    local gave, still, handing = identity(revival)
    assert(type(accepted) == "boolean", "explicit fossil decision required")
    if session:questFlag(gave) then
        return pack(false, "already-reviving")
    end
    local row = rows(revival)[itemSymbol]
    if not row then
        return pack(false, "not-a-fossil")
    end
    local id = itemId(row.item)
    if session:inventory():quantity(id) < 1 then
        return pack(false, "no-fossil")
    end
    pending[session] = {item = row.item, species = row.species}
    if not accepted then
        return pack(true, "cancelled")
    end
    local expectedItems = {}
    for _, candidate in ipairs(revival.results) do
        local candidateId = itemId(candidate.item)
        expectedItems[candidateId] = session:inventory():quantity(candidateId)
    end
    local ok, reason = session:transact(
        {flags = {[gave] = false, [still] = false, [handing] = false}, items = expectedItems},
        {flags = {[gave] = true, [still] = true}, items = {{op = "handoff", id = id, quantity = 1}}})
    if not ok then
        return pack(false, reason)
    end
    return pack(true, "reviving")
end

local function handover(session, revival)
    local gave, still, handing, level = identity(revival)
    assert(session:questFlag(gave) and not session:questFlag(still), "fossil is not ready")
    local record = pending[session]
    if not record then
        return pack(false, "missing-fossil-mon")
    end
    local row = rows(revival)[record.item]
    assert(row and row.species == record.species, "fossil selection changed")
    -- Source sets the handover flag before GivePokemon and leaves it set on failure.
    assert(session:setQuestFlag(handing, true) == true, "fossil handover flag failed")
    local stream = RulesRNG.new(1)
    stream:restoreData(session:rngData())
    local mon, receipt = Specimen.create(speciesId(record.species), level, "gift", stream)
    if not mon then
        return pack(false, "invalid-specimen", {detail = tostring(receipt)})
    end
    local accepted, result = session:recruit(mon)
    if not accepted then
        return pack(false, result)
    end
    for _, flag in ipairs(revival.success_resets) do
        assert(session:setQuestFlag(flag, false) == true, "fossil success reset failed")
    end
    RulesRNG.restore(stream:snapshot())
    return pack(true, "revived", {destination = result.destination, box = result.box,
        species = record.species, level = level, index = result.index})
end

function FossilRevival.talk(session, revival)
    revival = bind(revival)
    local gave, still = identity(revival)
    if not session:questFlag(gave) then
        local fossils = FossilRevival.fossilsInBag(session, revival)
        if #fossils == 0 then
            return pack(true, "no-fossils")
        end
        return pack(true, "offer", {fossils = fossils})
    end
    if session:questFlag(still) then
        return pack(true, "still-reviving")
    end
    return handover(session, revival)
end

-- Cinnabar Island's map script clears only the still-reviving flag.
function FossilRevival.onMapLoad(session, mapConstant, revival)
    revival = bind(revival)
    local clear = revival.still_reviving_cleared_on_map_load
    if mapConstant ~= clear.map_constant then
        return pack(true, "ignored")
    end
    assert(session:setQuestFlag(clear.event, false) == true, "fossil map clear failed")
    return pack(true, "cleared")
end
