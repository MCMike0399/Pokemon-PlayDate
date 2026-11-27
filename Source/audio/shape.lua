-- Shared pitch and envelope curve for the game synth and the host renderer.
--
-- Pitch slides follow pret/pokered audio/engine_1.asm:
--   Audio1_InitPitchSlideVars stores the step, and Audio1_ApplyPitchSlide
--   walks it. A step that passes the target is not written. The decreasing
--   path doubles the fraction and borrows, which is the source's
--   `add a` / `sbc` pair. The increasing path keeps the source borrow bug
--   already applied when the step was stored (delta + 0x200).
-- Vibrato follows Audio1_ApplyMusicAffects `.vibrato` / `.applyVibrato`.
-- The extent byte packs n/2 below and n/2+n%2 above; this module stores n
-- and applies those two distances. Each application reads the note-on low
-- byte (wChannelFrequencyLowBytes). The routine writes NR13 and does not
-- store the result back, so the pitch toggles around that byte. It does not
-- run on a frame where Audio1_ApplyPitchSlide still owns the channel.
-- The ADSR arguments are the ones engine.lua passes to synth:setADSR.
-- gain() is that curve: attack 0→1, decay 1→sustain, then sustain.

KantoShape = {}

function KantoShape.adsr(envelope, voice)
    envelope = envelope or 0
    if voice == 3 then
        return 0, 0, 1, 0.002
    end
    local pace = envelope & 7
    local rising = (envelope & 8) ~= 0
    if pace == 0 then
        return 0, 0, 1, 0.002
    end
    local steps = envelope >> 4
    if rising then
        steps = 15 - steps
    end
    local envelopeTime = pace * steps / 64
    if rising then
        return envelopeTime, 0, 1, 0.002
    end
    return 0, envelopeTime, 0, 0.002
end

function KantoShape.gain(attack, decay, sustain, _release, elapsed)
    attack = attack or 0
    decay = decay or 0
    sustain = sustain or 1
    if elapsed < 0 then
        elapsed = 0
    end
    if attack > 0 and elapsed < attack then
        return elapsed / attack
    end
    local after = elapsed - attack
    if decay > 0 and after < decay then
        return 1 + (sustain - 1) * (after / decay)
    end
    return sustain
end

local function slideOnce(slide)
    -- Audio1_ApplyPitchSlide. Returning true means the target was crossed
    -- and the register must keep the previous period.
    if slide.decreasing then
        local doubled = slide.fraction * 2
        local borrow = doubled > 255 and 1 or 0
        slide.fraction = doubled & 255
        local nxt = (slide.current - slide.step - borrow) & 65535
        if nxt < slide.target then
            return true
        end
        slide.current = nxt
        return false
    end
    local acc = slide.currentFraction + slide.fraction
    slide.currentFraction = acc & 255
    local nxt = (slide.current + slide.step + (acc >> 8)) & 65535
    if nxt > slide.target then
        return true
    end
    slide.current = nxt
    return false
end

local function vibratoLow(state)
    -- Audio1_ApplyMusicAffects `.vibrato`. nil means the low byte is unchanged
    -- this frame (delay, a rate count, or no extent).
    if state.delay > 0 then
        state.delay = state.delay - 1
        return nil
    end
    if state.depth == 0 then
        return nil
    end
    if state.rate % 16 ~= 0 then
        state.rate = (state.rate - 1) & 255
        return nil
    end
    local swapped = ((state.rate << 4) | (state.rate >> 4)) & 255
    state.rate = (state.rate | swapped) & 255
    local low = state.low
    if state.direction then
        state.direction = false
        low = low - math.floor(state.depth / 2)
        if low < 0 then
            low = 0
        end
    else
        state.direction = true
        low = low + math.floor((state.depth + 1) / 2)
        if low > 255 then
            low = 255
        end
    end
    return low
end

function KantoShape.periodAt(note, elapsed)
    local shape = note[#note]
    if type(shape) ~= "table" or type(shape.p) ~= "number" then
        return nil
    end
    local written = shape.p
    local slide = nil
    if shape.s then
        slide = {
            current = shape.s[1],
            target = shape.s[2],
            step = shape.s[3],
            fraction = shape.s[4],
            decreasing = shape.s[5] == 1,
            currentFraction = shape.s[4],
        }
    end
    local vib = nil
    if shape.v then
        vib = {
            delay = shape.v[1],
            depth = shape.v[2],
            rate = shape.v[3],
            low = shape.v[4],
            direction = shape.v[5] == 1,
        }
    end
    for _ = 1, elapsed or 0 do
        if slide then
            if slideOnce(slide) then
                slide = nil
            else
                written = slide.current
            end
        elseif vib then
            local low = vibratoLow(vib)
            if low then
                written = (written & 0xff00) | low
            end
        end
    end
    return written
end

function KantoShape.hz(note, elapsed)
    local period = KantoShape.periodAt(note, elapsed)
    local raw
    if period == nil then
        raw = note[4]
    else
        local denom = 2048 - (period & 2047)
        if denom <= 0 then
            raw = 16000
        else
            raw = (note[2] == 3 and 65536 or 131072) / denom
        end
        if raw < 20 then
            raw = 20
        elseif raw > 16000 then
            raw = 16000
        end
    end
    return math.floor(raw * 10000 + 0.5) / 10000
end
