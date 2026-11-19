-- pokered SRAM Hall of Fame teams. Each team is the party that was recorded,
-- newest last. The 51st team drops the oldest. Names are the ten-character
-- wNameBuffer copy. This is not a photo and it does not play the credits.
HallOfFame = {}
local CAPACITY <const> = 50
local PARTY <const> = 6

local function member(value)
    assert(type(value) == "table" and getmetatable(value) == nil, "hall of fame member required")
    local species <const> = value.species
    local name <const> = value.name
    assert(type(species) == "string" and species:match("^[A-Za-z][A-Za-z0-9]*$") ~= nil and #species <= 16,
        "invalid hall of fame species")
    -- wNameBuffer is NAME_LENGTH (11) bytes. The visible nickname is 1 to 10
    -- glyphs: printable ASCII, plus × ($f1), ♂ ($ef), and ♀ ($f5).
    assert(type(name) == "string" and utf8.len(name) ~= nil, "invalid hall of fame name")
    local nameCount = 0
    for _, code in utf8.codes(name) do
        assert((code >= 32 and code <= 126) or code == 0x00D7 or code == 0x2642 or code == 0x2640,
            "invalid hall of fame name")
        nameCount = nameCount + 1
    end
    assert(nameCount >= 1 and nameCount <= 10, "invalid hall of fame name")
    assert(Party._integer(value.level, 1, 100), "invalid hall of fame level")
    for key in pairs(value) do
        assert(key == "species" or key == "level" or key == "name", "unknown hall of fame member field")
    end
    return {species = species, level = assert(math.tointeger(value.level)), name = name}
end

local function team(value)
    assert(Party._array(value, PARTY) and #value >= 1, "hall of fame team required")
    local record = {}
    for index, mon in ipairs(value) do
        record[index] = member(mon)
    end
    return record
end

function HallOfFame.empty()
    return {version = 1, teams = {}}
end

function HallOfFame.normalize(value)
    if value == nil then
        return HallOfFame.empty()
    end
    assert(type(value) == "table" and getmetatable(value) == nil, "hall of fame record required")
    for key in pairs(value) do
        assert(key == "version" or key == "teams", "unknown hall of fame field")
    end
    assert(value.version == 1, "unsupported hall of fame version")
    assert(Party._array(value.teams, CAPACITY), "hall of fame team list required")
    local teams = {}
    for index, row in ipairs(value.teams) do
        teams[index] = team(row)
    end
    return {version = 1, teams = teams}
end

function HallOfFame.append(record, members)
    local current <const> = HallOfFame.normalize(record)
    local teams = {}
    local start <const> = #current.teams >= CAPACITY and 2 or 1
    for index = start, #current.teams do
        teams[#teams + 1] = current.teams[index]
    end
    teams[#teams + 1] = team(members)
    return HallOfFame.normalize({version = 1, teams = teams})
end
