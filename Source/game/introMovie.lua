-- Skip rules from pret/pokered af519899.
-- engine/movie/intro.asm PlayIntro / PlayIntroScene
-- engine/movie/splash.asm PlayShootingStar / AnimateShootingStar
-- home/overworld.asm CheckForUserInterruption (A or Start; Up+Select+B)
-- DelayFrames ignores the button. CheckForUserInterruption does not.
-- A press during AnimateShootingStar skips the rest of the star and the
-- 40-frame hold (jr c, .next). A press during PlayIntroScene returns out
-- of the fight. The English intro does not show the unused PRESENTS graphic.

IntroMovie = {}

local function scene(id, frames, input, cast)
    return {id = id, frames = frames, input = input, cast = cast}
end

IntroMovie.SCENES = {
    scene("copyright", 180, "ignore", nil),
    scene("black-bars", 64, "ignore", nil),
    -- Big star: OAM Y 16 steps by 4 until $a0 (36). Logo flash 3*10.
    -- Six small-star waves, each MoveDownSmallStars 8*3 frames.
    scene("shooting-star", 36 + 30 + 144, "next", nil),
    scene("after-star", 40, "ignore", nil),
    scene("nidorino-enter", 40 * 2, "finish", "nidorino"),
    scene("hip-1", 5 * 5, "finish", "nidorino"),
    scene("hop-1", 5 * 5, "finish", "nidorino"),
    scene("wait-10", 10, "finish", "both"),
    scene("hip-2", 5 * 5, "finish", "nidorino"),
    scene("hop-2", 5 * 5, "finish", "nidorino"),
    scene("wait-30-a", 30, "finish", "both"),
    scene("gengar-raise", 4 * 2, "finish", "gengar"),
    scene("wait-30-b", 30, "finish", "gengar"),
    scene("gengar-slash", 8 * 2, "finish", "gengar"),
    scene("hip-3", 5 * 5, "finish", "both"),
    scene("wait-30-c", 30, "finish", "both"),
    scene("gengar-return", 4 * 2, "finish", "gengar"),
    scene("wait-60", 60, "finish", "both"),
    scene("hip-4", 5 * 5, "finish", "nidorino"),
    scene("hop-5", 5 * 5, "finish", "nidorino"),
    scene("wait-20", 20, "finish", "nidorino"),
    scene("hip-6", 4 * 5, "finish", "nidorino"),
    scene("wait-30-d", 30, "finish", "nidorino"),
    scene("lunge", 4 * 5, "finish", "nidorino"),
}

IntroMovie.COPYRIGHT = "(C) '95.'96.'98 Nintendo"
IntroMovie.COPYRIGHT_LINES = {
    "(C) '95.'96.'98 Nintendo",
    "(C) '95.'96.'98 Creatures inc.",
    "(C) '95.'96.'98 GAME FREAK inc.",
}

function IntroMovie.start()
    return {index = 1, frame = 0, done = false}
end

function IntroMovie.current(state)
    return IntroMovie.SCENES[state.index]
end

local function gotoId(state, id)
    for index, sceneRow in ipairs(IntroMovie.SCENES) do
        if sceneRow.id == id then
            state.index = index
            state.frame = 0
            return
        end
    end
    state.done = true
    state.index = #IntroMovie.SCENES + 1
    state.frame = 0
end

function IntroMovie.advance(state, pressed)
    if state.done then return end
    local sceneRow = IntroMovie.SCENES[state.index]
    if not sceneRow then
        state.done = true
        return
    end
    if pressed and sceneRow.input == "finish" then
        state.done = true
        state.index = #IntroMovie.SCENES + 1
        state.frame = 0
        return
    end
    if pressed and sceneRow.input == "next" then
        gotoId(state, "nidorino-enter")
        return
    end
    state.frame = state.frame + 1
    if state.frame >= sceneRow.frames then
        state.index = state.index + 1
        state.frame = 0
        if state.index > #IntroMovie.SCENES then
            state.done = true
        end
    end
end

function IntroMovie.sound(kind)
    if type(KantoAudio) ~= "table" then return false end
    if kind == "intro" and type(KantoAudio.playIntro) == "function" then
        return pcall(KantoAudio.playIntro) == true
    end
    return false
end

function IntroMovie.draw(state, gfx)
    if not gfx or not state then return end
    local sceneRow = IntroMovie.SCENES[state.index]
    gfx.clear(gfx.kColorWhite)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, 400, 48)
    gfx.fillRect(0, 192, 400, 48)
    if not sceneRow then
        gfx.drawText("...", 24, 100)
        return
    end
    if sceneRow.id == "copyright" then
        for index, line in ipairs(IntroMovie.COPYRIGHT_LINES) do
            gfx.drawText(line, 24, 64 + (index - 1) * 22)
        end
        return
    end
    gfx.drawText(sceneRow.id, 24, 56)
end
