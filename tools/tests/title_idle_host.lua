-- Host check for the Blue title idle. No Simulator.
local root = arg[1]
assert(root and root ~= "", "usage: lua title_idle_host.lua <repo>")
dofile(root .. "/Source/game/titleIdle.lua")

local function eq(actual, expected, label)
    if actual ~= expected then
        error(label .. ": " .. tostring(actual) .. " ~= " .. tostring(expected), 2)
    end
end

local function contains(species)
    for _, name in ipairs(TitleIdle.MONS) do
        if name == species then return true end
    end
    return false
end

local function run(state, frames, random)
    for _ = 1, frames do TitleIdle.advance(state, random) end
end

local fixed = 2
local function randomFixed()
    return fixed
end

local state = TitleIdle.start()
eq(state.species, "squirtle", "first species")
eq(state.phase, "hold", "first phase")
run(state, TitleIdle.HOLD, randomFixed)
eq(state.phase, "hold", "still holding on frame 200")
eq(state.hold, TitleIdle.HOLD, "hold count")
TitleIdle.advance(state, randomFixed)
eq(state.phase, "out", "scroll out after the wait")
eq(state.offset, 0, "out starts at home")
run(state, TitleIdle.OUT_FRAMES, randomFixed)
eq(state.phase, "out", "last out frame stays out")
eq(state.offset, -TitleIdle.OUT_DISTANCE, "out distance")
TitleIdle.advance(state, randomFixed)
eq(state.phase, "ball", "starter leaving plays the ball")
eq(state.species, "squirtle", "ball still belongs to the starter")
run(state, #TitleIdle.BALL_Y, randomFixed)
eq(state.phase, "ball", "fifth ball step is still the ball")
eq(state.ball, #TitleIdle.BALL_Y, "ball index")
eq(TitleIdle.BALL_Y[state.ball], 0x6c, "last played ball row")
TitleIdle.advance(state, randomFixed)
eq(state.phase, "in", "next species scrolls in")
eq(state.species, "charmander", "fixed pick is the second TitleMon")
eq(state.offset, TitleIdle.IN_DISTANCE, "in starts off the right")
run(state, TitleIdle.IN_FRAMES, randomFixed)
eq(state.offset, 0, "in lands at home")
eq(state.phase, "in", "last in frame stays in")
TitleIdle.advance(state, randomFixed)
eq(state.phase, "hold", "hold the species that scrolled in")
eq(state.species, "charmander", "held species")

local skipped = TitleIdle.start()
skipped.species = "mankey"
skipped.phase = "out"
skipped.cursor = TitleIdle.OUT_FRAMES
skipped.offset = -TitleIdle.OUT_DISTANCE
TitleIdle.advance(skipped, function() return 12 end)
eq(skipped.phase, "in", "non-starter skips the ball")
eq(skipped.species, "poliwag", "index 12 is poliwag")
assert(contains(skipped.species), "picked species is a TitleMon")
assert(skipped.species ~= "mankey", "pick rejects the current species")

local stuck = 0
local function alwaysSquirtle()
    stuck = stuck + 1
    return 1
end
local fallback = TitleIdle.pick("squirtle", alwaysSquirtle)
eq(fallback, "charmander", "a stuck roll still changes species")
assert(stuck == 32, "reject loop is bounded")

for _, starter in ipairs({ "charmander", "bulbasaur" }) do
    local leaving = TitleIdle.start()
    leaving.species = starter
    leaving.phase = "out"
    leaving.cursor = TitleIdle.OUT_FRAMES
    TitleIdle.advance(leaving, randomFixed)
    eq(leaving.phase, "ball", starter .. " plays the ball")
end

print("title-idle-host ok")
