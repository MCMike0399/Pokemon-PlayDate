-- wPlayTimeHours, wPlayTimeMaxed, wPlayTimeMinutes, wPlayTimeSeconds, wPlayTimeFrames.
-- TrackPlayTime rolls 60 frames into a second, 60 seconds into a minute, and
-- 60 minutes into an hour. Reaching hour 255 sets the maxed byte and later
-- calls leave the clock where it is. The input-ignore countdown that shares
-- the vblank call is not part of this record.
PlayTime = {}

local FIELDS <const> = {hours = true, minutes = true, seconds = true, frames = true, maxed = true}

local function integer(value, low, high)
    local whole = math.tointeger(value)
    assert(whole ~= nil and whole >= low and whole <= high, "invalid play time")
    return whole
end

function PlayTime.empty()
    return {hours = 0, minutes = 0, seconds = 0, frames = 0, maxed = false}
end

function PlayTime.normalize(value)
    if value == nil then
        return PlayTime.empty()
    end
    assert(type(value) == "table" and getmetatable(value) == nil, "plain object required")
    for key in pairs(value) do
        assert(FIELDS[key], "unknown field: " .. tostring(key))
    end
    local hours <const> = integer(value.hours, 0, 255)
    local minutes <const> = integer(value.minutes, 0, 59)
    local seconds <const> = integer(value.seconds, 0, 59)
    local frames <const> = integer(value.frames, 0, 59)
    assert(type(value.maxed) == "boolean", "invalid play time")
    -- The increment that reaches 255 sets wPlayTimeMaxed in the same call.
    assert(value.maxed == (hours == 255), "invalid play time")
    return {hours = hours, minutes = minutes, seconds = seconds, frames = frames, maxed = value.maxed}
end

function PlayTime.advance(clock)
    if clock.maxed then
        return clock
    end
    clock.frames = clock.frames + 1
    if clock.frames < 60 then
        return clock
    end
    clock.frames = 0
    clock.seconds = clock.seconds + 1
    if clock.seconds < 60 then
        return clock
    end
    clock.seconds = 0
    clock.minutes = clock.minutes + 1
    if clock.minutes < 60 then
        return clock
    end
    clock.minutes = 0
    clock.hours = clock.hours + 1
    if clock.hours == 255 then
        clock.maxed = true
    end
    return clock
end
