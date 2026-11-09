-- Blue title idle from pret/pokered af519899.
-- data/pokemon/title_mons.asm (DEF _BLUE) and engine/movie/title2.asm.
-- DisplayTitleScreen waits 200 frames, then TitleScreenScrollInMon passes
-- d=0. TitleScroll treats 0 as TitleScroll_Out, so the current species
-- leaves to the left. TitleScreenAnimateBallIfStarterOut then plays the
-- first five TitleBallYTable steps when that species is Charmander,
-- Squirtle, or Bulbasaur. TitleScreenPickNewMon passes d=1, which
-- TitleScroll treats as TitleScroll_In, so a different TitleMon enters
-- from the right. The inline "scroll in" / "scroll out" comments are
-- swapped relative to that branch.

TitleIdle = {}

TitleIdle.MONS = {
    "squirtle", "charmander", "bulbasaur", "mankey", "hitmonlee", "vulpix",
    "chansey", "aerodactyl", "jolteon", "snorlax", "gloom", "poliwag",
    "doduo", "porygon", "gengar", "raichu",
}
TitleIdle.HOLD = 200
TitleIdle.BALL_REST = 0x74
TitleIdle.BALL_Y = { 0x71, 0x6f, 0x6e, 0x6d, 0x6c }

local STARTERS <const> = { squirtle = true, charmander = true, bulbasaur = true }
local OUT_SPEEDS <const> = { 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 8, 8, 8, 9, 9, 9 }
local IN_SPEEDS <const> = { 10, 10, 9, 9, 9, 9, 8, 8, 8, 8, 6, 6, 6, 5, 5, 3, 1 }
TitleIdle.OUT_FRAMES = #OUT_SPEEDS
TitleIdle.IN_FRAMES = #IN_SPEEDS
TitleIdle.OUT_DISTANCE = 93
TitleIdle.IN_DISTANCE = 120

local function beginIn(state, random)
    state.species = TitleIdle.pick(state.species, random)
    state.phase = "in"
    state.cursor = 0
    state.offset = TitleIdle.IN_DISTANCE
    state.ball = nil
end

function TitleIdle.start()
    return { species = "squirtle", phase = "hold", hold = 0, cursor = 0, offset = 0, ball = nil }
end

function TitleIdle.pick(current, random)
    for _ = 1, 32 do
        local species = TitleIdle.MONS[random(#TitleIdle.MONS)]
        if species ~= current then return species end
    end
    for index, species in ipairs(TitleIdle.MONS) do
        if species == current then return TitleIdle.MONS[index % #TitleIdle.MONS + 1] end
    end
    return TitleIdle.MONS[1]
end

function TitleIdle.advance(state, random)
    if state.phase == "hold" then
        if state.hold == TitleIdle.HOLD then
            state.phase = "out"
            state.cursor = 0
            state.offset = 0
            state.ball = nil
            return
        end
        state.hold = state.hold + 1
        return
    end
    if state.phase == "out" then
        if state.cursor == #OUT_SPEEDS then
            if STARTERS[state.species] then
                state.phase = "ball"
                state.ball = 0
            else
                beginIn(state, random)
            end
            return
        end
        state.cursor = state.cursor + 1
        state.offset = state.offset - OUT_SPEEDS[state.cursor]
        return
    end
    if state.phase == "ball" then
        if state.ball == #TitleIdle.BALL_Y then
            beginIn(state, random)
            return
        end
        state.ball = state.ball + 1
        return
    end
    if state.cursor == #IN_SPEEDS then
        state.phase = "hold"
        state.hold = 0
        state.cursor = 0
        state.offset = 0
        state.ball = nil
        return
    end
    state.cursor = state.cursor + 1
    state.offset = state.offset - IN_SPEEDS[state.cursor]
end
