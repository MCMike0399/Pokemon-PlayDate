-- Expand a shared source cry program into one transient synth score.
import "audio/crydata"

KantoCries = {}

local duties <const> = {0.125, 0.25, 0.5, 0.75}
local noiseDivisors <const> = {8, 16, 32, 48, 64, 80, 96, 112}
local aliases <const> = {
    nidoranF = "nidoran_f",
    nidoranM = "nidoran_m",
    mr = "mr_mime",
}

local function rounded(value)
    return math.floor(value * 10000 + 0.5) / 10000
end

function KantoCries.score(species, family)
    species = aliases[species] or species
    local parameters = KantoCrySpecies[species]
    if not parameters then
        return nil, "unknown cry species"
    end

    local asset = KantoCryBases[parameters[1]][family]
    if not asset then
        return nil, "unknown cry bank"
    end
    local program = KantoCryPrograms[KantoCryHeaders[asset]]
    local pitch = parameters[2]
    local length = parameters[3]
    local notes = {}
    local ends = {}

    for _, voice in ipairs({1, 2, 4}) do
        local tick = 0
        local fraction = 0
        for _, row in ipairs(program[voice]) do
            -- The source stops applying modifiers after pulse 1 returns.
            -- Noise always uses tempo 256, even while cry pitch is applied.
            local modified = voice == 1 or tick < ends[1]
            local tempo = modified and voice ~= 4 and length + 128 or 256
            local accumulator = (fraction + row[1] * tempo) & 65535
            local gate = accumulator >> 8
            fraction = accumulator & 255
            if gate == 0 then
                gate = 256
            end

            local value = row[3] + (modified and pitch or 0)
            local hz
            if voice == 4 then
                local nr = value & 255
                hz = 524288 / noiseDivisors[(nr & 7) + 1] / (2 ^ (nr >> 4))
            else
                hz = 131072 / (2048 - (value & 2047))
            end
            local envelope = row[2]
            local volume = (envelope >> 4) / 15
            if volume > 0 then
                notes[#notes + 1] = {
                    tick, voice, gate, rounded(hz), rounded(volume),
                    duties[row[4] + 1], envelope,
                }
            end
            tick = tick + gate
        end
        ends[voice] = tick
    end

    table.sort(notes, function(a, b)
        if a[1] == b[1] then
            return a[2] < b[2]
        end
        return a[1] < b[1]
    end)
    local holds = {
        ends[1], math.max(ends[1], ends[2]),
        ends[1], math.max(ends[1], ends[4]),
    }
    return {
        asset = asset,
        ticks = math.max(table.unpack(holds)) + 1,
        notes = notes,
        holds = holds,
    }
end
