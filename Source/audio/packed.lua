-- Packed score records. file.run loads this the first time a score plays,
-- and unloadAll drops it before the next city is inflated.
-- Layout matches tools/audio/scores.py NOTE_STRUCT.

KantoPacked = {}

local b64values = {}
do
    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    for index = 1, #alphabet do
        b64values[alphabet:byte(index)] = index - 1
    end
end

local function b64decode(text)
    local chunks = {}
    local bytes = {}
    local count = 0
    local acc, bits = 0, 0
    for index = 1, #text do
        local value = b64values[text:byte(index)]
        if value then
            acc = (acc << 6) | value
            bits = bits + 6
            if bits >= 8 then
                bits = bits - 8
                count = count + 1
                bytes[count] = (acc >> bits) & 255
                -- A few dozen pack arguments stay inside Playdate's Lua stack.
                if count == 24 then
                    chunks[#chunks + 1] = string.pack(string.rep("B", 24), table.unpack(bytes, 1, 24))
                    count = 0
                end
            end
        end
    end
    if count > 0 then
        chunks[#chunks + 1] = string.pack(string.rep("B", count), table.unpack(bytes, 1, count))
    end
    return table.concat(chunks)
end

local function readRecords(score)
    local file = playdate.file.open(score.bin, playdate.file.kFileRead)
    if not file then
        error("missing Kanto score " .. tostring(score.bin), 0)
    end
    file:seek(score.at or 0, playdate.file.kSeekSet)
    local raw, count = file:read(score.bytes)
    file:close()
    if type(raw) ~= "string" or count ~= score.bytes or score.bytes % 32 ~= 0 then
        error("Kanto score record length is not 32 bytes", 0)
    end
    score.raw = raw
    score.bin = nil
    score.count = #raw // 32
end

function KantoPacked.bind(score)
    if type(score) ~= "table" then
        return score
    end
    if type(score.bin) == "string" then
        readRecords(score)
    end
    if type(score.packed) == "string" then
        local raw = b64decode(score.packed)
        if #raw % 32 ~= 0 then
            error("Kanto score record length is not 32 bytes", 0)
        end
        score.raw = raw
        score.packed = nil
        score.count = #raw // 32
    end
    if score.parts then
        for _, part in ipairs(score.parts) do
            KantoPacked.bind(part)
        end
    end
    return score
end

function KantoPacked.count(score)
    if score.notes then
        return #score.notes
    end
    return score.count or 0
end

function KantoPacked.noteAt(score, index)
    if score.notes then
        return score.notes[index]
    end
    local raw = score.raw
    local count = score.count or 0
    if not raw or index < 1 or index > count then
        return nil
    end
    local tick, gate, voice, flags, hz, amp, duty, env, wave, period,
        s1, s2, s3, s4, s5, v1, v2, v3, v4, v5 =
        string.unpack("<HHBBIHHBBHHHHHBBBBBB", raw, (index - 1) * 32 + 1)
    local note = {
        tick, voice, gate, hz / 10000, amp / 10000, duty / 10000, env,
    }
    if flags & 32 ~= 0 then
        local waves = score.waves
        note[#note + 1] = waves and waves[wave]
    end
    if flags & 1 ~= 0 then
        local shape = {p = period}
        if flags & 2 ~= 0 then
            shape.s = {s1, s2, s3, s4, s5}
        end
        if flags & 4 ~= 0 then
            shape.v = {v1, v2, v3, v4, v5}
        end
        note[#note + 1] = shape
    end
    return note
end
