-- Host check for TrackPlayTime's counters. No Playdate SDK.
dofile("Source/domain/playTime.lua")

local function same(clock, hours, minutes, seconds, frames, maxed)
    assert(clock.hours == hours and clock.minutes == minutes
        and clock.seconds == seconds and clock.frames == frames
        and clock.maxed == maxed,
        string.format("clock %d:%02d:%02d.%02d maxed=%s",
            clock.hours, clock.minutes, clock.seconds, clock.frames, tostring(clock.maxed)))
end

local zero = PlayTime.normalize(nil)
same(zero, 0, 0, 0, 0, false)

local clock = PlayTime.empty()
for _ = 1, 59 do
    PlayTime.advance(clock)
end
same(clock, 0, 0, 0, 59, false)
PlayTime.advance(clock)
same(clock, 0, 0, 1, 0, false)

clock.seconds = 59
clock.frames = 59
PlayTime.advance(clock)
same(clock, 0, 1, 0, 0, false)

clock.minutes = 59
clock.seconds = 59
clock.frames = 59
PlayTime.advance(clock)
same(clock, 1, 0, 0, 0, false)

clock.hours = 254
clock.minutes = 59
clock.seconds = 59
clock.frames = 59
PlayTime.advance(clock)
same(clock, 255, 0, 0, 0, true)
PlayTime.advance(clock)
same(clock, 255, 0, 0, 0, true)

local saved = PlayTime.normalize({hours = 12, minutes = 3, seconds = 4, frames = 5, maxed = false})
same(saved, 12, 3, 4, 5, false)
assert(saved ~= clock, "normalize returns a new record")
local capped = PlayTime.normalize({hours = 255, minutes = 0, seconds = 0, frames = 0, maxed = true})
same(capped, 255, 0, 0, 0, true)

local function rejected(value)
    local ok = pcall(PlayTime.normalize, value)
    assert(not ok, "invalid play time was accepted")
end
rejected({hours = 255, minutes = 0, seconds = 0, frames = 0, maxed = false})
rejected({hours = 1, minutes = 0, seconds = 0, frames = 0, maxed = true})
rejected({hours = 1, minutes = 60, seconds = 0, frames = 0, maxed = false})
rejected({hours = 1, minutes = 0, seconds = 0, frames = 0, maxed = false, counting = true})

print("play-time-ok")
