-- Blue credits roll from pret/pokered af519899 engine/movie/credits.asm.
-- One advance is one source frame. The Hall of Fame PC preamble runs first,
-- then each CreditsOrder command. CRED_THE_END fades in and returns to the
-- title. This player does not write a save or a badge.
CreditsPlayer = {}

local FADE_MON <const> = "CRED_TEXT_FADE_MON"
local TEXT_MON <const> = "CRED_TEXT_MON"
local FADE <const> = "CRED_TEXT_FADE"
local TEXT <const> = "CRED_TEXT"
local THE_END <const> = "CRED_THE_END"

local function scrollCount(timing)
    return timing.scroll_tiles[1] + timing.scroll_tiles[2]
end

local function begin(state)
    local frame <const> = state.frames[state.index]
    local command <const> = frame.command
    local timing <const> = state.timing
    state.command = command
    state.lines = frame.lines
    state.mon = frame.mon
    state.copyright = frame.copyright == true
    state.ending = command == THE_END
    state.graphic = frame.graphic
    if command == FADE_MON or command == FADE then
        state.phase = "fade"
        state.fade_step = 1
        state.left = timing.fade_hold
        state.after_hold = command == FADE_MON and "scroll" or "next"
    elseif command == THE_END then
        state.phase = "hold"
        state.left = timing.hold[command]
        state.after_hold = "fade"
    elseif command == TEXT_MON or command == TEXT then
        state.phase = "hold"
        state.left = timing.hold[command]
        state.after_hold = command == TEXT_MON and "scroll" or "next"
    else
        error("unknown credits command: " .. tostring(command))
    end
end

function CreditsPlayer.start(frames, timing)
    assert(type(frames) == "table" and #frames > 0, "credit frames required")
    assert(frames[1].command == FADE_MON and frames[1].mon == "venusaur", "blue credits opening changed")
    assert(frames[#frames].command == THE_END and frames[#frames]["end"] == true, "credits must end on THE END")
    assert(timing.preamble_frames[1] == 100 and timing.preamble_frames[2] == 128, "hall of fame preamble changed")
    assert(timing.fade_steps == 4 and timing.fade_hold == 5, "credit fade changed")
    assert(timing.scroll_tiles[1] == 7 and timing.scroll_tiles[2] == 20, "credit scroll changed")
    assert(timing.hold[FADE_MON] == 90 and timing.hold[TEXT_MON] == 110
        and timing.hold[FADE] == 120 and timing.hold[TEXT] == 140
        and timing.hold[THE_END] == 16, "credit hold changed")
    return {
        frames = frames,
        timing = timing,
        index = 1,
        phase = "preamble",
        left = timing.preamble_frames[1] + timing.preamble_frames[2],
        fade_step = 0,
        scroll = 0,
        done = false,
        return_to = nil,
        lines = {},
        mon = nil,
        copyright = false,
        ending = false,
    }
end

local function nextFrame(state)
    if state.index == #state.frames then
        error("credits order ended before THE END")
    end
    state.index = state.index + 1
    begin(state)
end

function CreditsPlayer.advance(state)
    if state.done then
        return state
    end
    if state.left <= 0 then
        error("credits frame counter underrun")
    end
    state.left = state.left - 1
    if state.left > 0 then
        if state.phase == "scroll" then
            state.scroll = state.scroll + 1
        end
        return state
    end
    if state.phase == "preamble" then
        begin(state)
        return state
    end
    local timing <const> = state.timing
    if state.phase == "fade" then
        if state.fade_step < timing.fade_steps then
            state.fade_step = state.fade_step + 1
            state.left = timing.fade_hold
            return state
        end
        if state.command == THE_END then
            state.done = true
            state.phase = "done"
            state.return_to = "title"
            return state
        end
        state.phase = "hold"
        state.left = timing.hold[state.command]
        return state
    end
    if state.phase == "hold" then
        if state.after_hold == "scroll" then
            state.phase = "scroll"
            state.scroll = 0
            state.left = scrollCount(timing)
            return state
        end
        if state.after_hold == "fade" then
            state.phase = "fade"
            state.fade_step = 1
            state.left = timing.fade_hold
            return state
        end
        nextFrame(state)
        return state
    end
    if state.phase == "scroll" then
        state.scroll = state.scroll + 1
        nextFrame(state)
        return state
    end
    error("unknown credits phase: " .. tostring(state.phase))
end

function CreditsPlayer.view(state)
    return {
        phase = state.phase,
        index = state.index,
        command = state.command,
        lines = state.lines,
        mon = state.mon,
        copyright = state.copyright,
        ending = state.ending,
        graphic = state.graphic,
        fade_step = state.fade_step,
        scroll = state.scroll,
        done = state.done,
        return_to = state.return_to,
    }
end
