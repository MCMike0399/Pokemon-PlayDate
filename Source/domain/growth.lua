-- B2W2 growth and conscious-participant scaled battle XP, with explicit local outsider provenance.
-- Import data/growthData before this module. No floats or wide native products.
Growth = {}
local function integer(value, low, high, label)
    local n = type(value) == "number" and math.tointeger(value) or nil
    assert(n and n >= low and n <= high, label .. " must be a native integer in " .. low .. ".." .. high)
    return n
end
function Growth.threshold(group, level)
    group = integer(group, 0, 5, "growth group")
    level = integer(level, 1, 100, "level")
    return GrowthData.thresholds[group][level]
end
function Growth.species(dex)
    dex = integer(dex, 1, 151, "species dex")
    local record = GrowthData.species[dex]
    return record[1], record[2]
end
-- floor(a*b/d), with all intermediates bounded below 2 million. Straight
-- multiplication exceeds signed int32 for legal high-level XP calculations.
local function multiplyDivide(a, b, d)
    local quotient, remainder, bit = 0, 0, 1
    while bit <= b // 2 do bit = bit * 2 end
    while bit > 0 do
        quotient = quotient * 2
        remainder = remainder * 2
        if b // bit % 2 == 1 then remainder = remainder + a end
        quotient = quotient + remainder // d
        remainder = remainder % d
        bit = bit // 2
    end
    return quotient
end
-- Native fixed_round after level scaling, before the final award cap. Only
-- local-language outsiders are authorized; no foreign-language multiplier.
function Growth.outsiderAward(award, outsider)
    award = integer(award, 0, 1000000, "scaled award")
    assert(type(outsider) == "boolean", "outsider flag must be boolean")
    -- fixed_round(x, 0x1800) keeps a 0x800 fraction rounded down. Splitting
    -- the exact Q12 product avoids signed int32 overflow before the cap.
    local boosted <const> = outsider and (award + award // 2) or award
    return math.min(100000, boosted)
end
function Growth.battleAward(baseEXP, opponentLevel, recipientLevel, trainer, participants, outsider)
    baseEXP = integer(baseEXP, 1, 395, "Gen V original151 base EXP")
    opponentLevel = integer(opponentLevel, 1, 100, "opponent level")
    recipientLevel = integer(recipientLevel, 1, 100, "recipient level")
    assert(type(trainer) == "boolean", "trainer flag must be boolean")
    participants = integer(participants == nil and 1 or participants, 1, 6, "conscious participants")
    assert(outsider == nil or type(outsider) == "boolean", "outsider flag must be boolean")
    if recipientLevel == 100 then return 0 end
    local z = baseEXP * opponentLevel // 5
    if trainer then z = z * 3 // 2 end
    z = z // participants -- Gen V shares the base BEFORE recipient-level scaling.
    local x, y = opponentLevel * 2 + 10, opponentLevel + recipientLevel + 10
    -- Floor the Q12-root products independently, then the ratio, then add one.
    -- Intentionally no cartridge unsigned32 overflow glitch emulation.
    local award <const> = multiplyDivide(GrowthData.scaledPower[x], z, GrowthData.scaledPower[y]) + 1
    return Growth.outsiderAward(award, outsider == true)
end
