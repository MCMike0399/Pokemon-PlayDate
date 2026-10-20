-- Rules randomness is independent of rendering and math.random's cosmetic stream.
-- Park-Miller (16807), using Schrage arithmetic for the SDK's 32-bit integers.
-- Versioned snapshots are plain data suitable for traces and replay saves.
import "domain/decimalInteger"

RulesRNG = {}
local MODULUS <const> = 2147483647
local ALGORITHM <const> = "park-miller-16807-v1"
local Stream = {}
Stream.__index = Stream

local MAX_INTEGER <const> = 2147483647
local MIN_INTEGER <const> = -2147483647 - 1
local DATA_VERSION <const> = 1

local function integer(value, label)
    assert(type(value) == "number", label .. " must be a native integer")
    local normalized = math.tointeger(value)
    assert(normalized ~= nil and normalized >= MIN_INTEGER and normalized <= MAX_INTEGER,
        label .. " must be a native integer")
    return normalized
end

local function validated(seed, state, rolls)
    seed, state, rolls = integer(seed, "seed"), integer(state, "state"), integer(rolls, "rolls")
    assert(seed >= 1 and seed < MODULUS and state >= 1 and state < MODULUS
        and rolls >= 0, "invalid RNG snapshot")
    return seed, state, rolls
end

-- Shared exact decimal codec has no Store/filesystem dependency.
local function decimal(text, minimum, maximum, label)
    local value, problem = DecimalInteger.decode(text, minimum, maximum)
    assert(value ~= nil, label .. ": " .. tostring(problem))
    return value
end

function Stream:seed(value)
    value = integer(value, "seed")
    self.initialSeed = value % (MODULUS - 1)
    if self.initialSeed <= 0 then self.initialSeed = self.initialSeed + MODULUS - 1 end
    self.state = self.initialSeed
    self.rolls = 0
    return self:snapshot()
end

function Stream:random(low, high)
    if low ~= nil then
        if high == nil then high = low; low = 1 end
        low = integer(low, "lower bound")
        high = integer(high, "upper bound")
        assert(low >= -1073741823 and high <= 1073741823
            and low <= high and high - low < MODULUS - 1, "invalid RNG interval")
    end
    local span = low ~= nil and (high - low + 1) or nil
    local limit = span and ((MODULUS - 1) // span) * span or nil
    local state, rolls = self.state, self.rolls
    repeat
        assert(rolls < MAX_INTEGER, "RNG roll counter exhausted")
        -- All products stay within signed 32-bit range (no float precision loss).
        local nextState = 16807 * (state % 127773) - 2836 * (state // 127773)
        if nextState <= 0 then nextState = nextState + MODULUS end
        state = nextState
        rolls = rolls + 1
    until not limit or state - 1 < limit
    self.state, self.rolls = state, rolls
    -- 24-bit unit interval stays strictly below 1 even with SDK float32.
    if low == nil then return ((self.state - 1) // 128) / 16777216 end
    return low + (self.state - 1) % span
end

function Stream:snapshot()
    return { algorithm = ALGORITHM, seed = self.initialSeed, state = self.state, rolls = self.rolls }
end

function Stream:restore(snapshot)
    assert(type(snapshot) == "table" and snapshot.algorithm == ALGORITHM, "unsupported RNG snapshot")
    local seed, state, rolls = validated(snapshot.seed, snapshot.state, snapshot.rolls)
    self.initialSeed, self.state, self.rolls = seed, state, rolls
end

-- Persistence uses strings for all wide integers; SDK JSON numbers use float32
-- and cannot preserve every valid state/roll count. Numeric snapshots are trace
-- data only and remain separate from this versioned lossless representation.
function Stream:toData()
    local seed, state, rolls = validated(self.initialSeed, self.state, self.rolls)
    return {version = DATA_VERSION, algorithm = ALGORITHM,
        seed = assert(DecimalInteger.encode(seed, 1, MODULUS - 1)),
        state = assert(DecimalInteger.encode(state, 1, MODULUS - 1)),
        rolls = assert(DecimalInteger.encode(rolls, 0, MAX_INTEGER))}
end

function Stream:restoreData(data)
    assert(type(data) == "table" and getmetatable(data) == nil and data.algorithm == ALGORITHM, "unsupported RNG data algorithm")
    assert(integer(data.version, "RNG data version") == DATA_VERSION, "unsupported RNG data version")
    for key in pairs(data) do
        assert(key == "version" or key == "algorithm" or key == "seed" or key == "state" or key == "rolls",
            "unknown RNG data field: " .. tostring(key))
    end
    local seed = decimal(data.seed, 1, MODULUS - 1, "seed")
    local state = decimal(data.state, 1, MODULUS - 1, "state")
    local rolls = decimal(data.rolls, 0, MAX_INTEGER, "rolls")
    -- Commit only after every field is validated.
    self.initialSeed, self.state, self.rolls = seed, state, rolls
    return self:snapshot()
end

function RulesRNG.new(seed)
    local stream = setmetatable({}, Stream)
    stream:seed(seed or 1)
    return stream
end

local rules = RulesRNG.new(1)
function RulesRNG.seed(seed) return rules:seed(seed) end
function RulesRNG.random(low, high) return rules:random(low, high) end
function RulesRNG.snapshot() return rules:snapshot() end
function RulesRNG.restore(snapshot) return rules:restore(snapshot) end

function RulesRNG.toData() return rules:toData() end
function RulesRNG.restoreData(data) return rules:restoreData(data) end
