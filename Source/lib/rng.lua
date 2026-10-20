-- Rules randomness is independent of rendering and math.random's cosmetic stream.
-- Park-Miller (16807), using Schrage arithmetic for the SDK's 32-bit integers.
-- Versioned snapshots are plain data suitable for traces and replay saves.
RulesRNG = {}
local MODULUS <const> = 2147483647
local ALGORITHM <const> = "park-miller-16807-v1"
local Stream = {}
Stream.__index = Stream

local function integer(value, label)
    assert(type(value) == "number" and value == math.floor(value)
        and value > -math.huge and value < math.huge, label .. " must be a finite integer")
    return value
end

function Stream:seed(value)
    integer(value, "seed")
    self.initialSeed = value % (MODULUS - 1)
    if self.initialSeed <= 0 then self.initialSeed = self.initialSeed + MODULUS - 1 end
    self.state = self.initialSeed
    self.rolls = 0
    return self:snapshot()
end

function Stream:random(low, high)
    if low ~= nil then
        if high == nil then high = low; low = 1 end
        integer(low, "lower bound")
        integer(high, "upper bound")
        assert(low >= -1073741823 and high <= 1073741823
            and low <= high and high - low < MODULUS - 1, "invalid RNG interval")
    end
    local span = low ~= nil and (high - low + 1) or nil
    local limit = span and ((MODULUS - 1) // span) * span or nil
    repeat
        -- All products stay within signed 32-bit range (no float precision loss).
        local nextState = 16807 * (self.state % 127773) - 2836 * (self.state // 127773)
        if nextState <= 0 then nextState = nextState + MODULUS end
        self.state = nextState
        self.rolls = self.rolls + 1
    until not limit or self.state - 1 < limit
    -- 24-bit unit interval stays strictly below 1 even with SDK float32.
    if low == nil then return ((self.state - 1) // 128) / 16777216 end
    return low + (self.state - 1) % span
end

function Stream:snapshot()
    return { algorithm = ALGORITHM, seed = self.initialSeed, state = self.state, rolls = self.rolls }
end

function Stream:restore(snapshot)
    assert(type(snapshot) == "table" and snapshot.algorithm == ALGORITHM, "unsupported RNG snapshot")
    integer(snapshot.seed, "seed")
    integer(snapshot.state, "state")
    integer(snapshot.rolls, "rolls")
    assert(snapshot.seed >= 1 and snapshot.seed < MODULUS and snapshot.state >= 1
        and snapshot.state < MODULUS and snapshot.rolls >= 0, "invalid RNG snapshot")
    self.initialSeed, self.state, self.rolls = snapshot.seed, snapshot.state, snapshot.rolls
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
