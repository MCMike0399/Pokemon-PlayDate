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

-- ldpal a, SHADE_BLACK, SHADE_DARK, SHADE_LIGHT, SHADE_WHITE
-- macros/code.asm: ld \1, \2 << 6 | \3 << 4 | \4 << 2 | \5
-- hardware.inc: WHITE 00, LIGHT 01, DARK 10, BLACK 11
-- Result 0xE4 is written to rBGP, rOBP0 and rOBP1.
-- RunPaletteCommand returns immediately when wOnSGB is 0, so
-- SET_PAL_NIDORINO_INTRO does not change these DMG registers.
IntroMovie.SHADE_WHITE = 0
IntroMovie.SHADE_LIGHT = 1
IntroMovie.SHADE_DARK = 2
IntroMovie.SHADE_BLACK = 3
IntroMovie.LIGHT = {0x55, 0xBB, 0x55, 0xFF, 0x55, 0xBB, 0x55, 0xFF}
IntroMovie.DARK = {0x00, 0xAA, 0x44, 0xAA, 0x00, 0xAA, 0x44, 0xAA}

function IntroMovie.dmgPalette()
    return (IntroMovie.SHADE_BLACK << 6)
        | (IntroMovie.SHADE_DARK << 4)
        | (IntroMovie.SHADE_LIGHT << 2)
        | IntroMovie.SHADE_WHITE
end

function IntroMovie.registers()
    local value = IntroMovie.dmgPalette()
    return {bgp = value, obp0 = value, obp1 = value, sgb = false}
end

function IntroMovie.shade(index)
    if index == IntroMovie.SHADE_WHITE then return "white" end
    if index == IntroMovie.SHADE_LIGHT then return IntroMovie.LIGHT end
    if index == IntroMovie.SHADE_DARK then return IntroMovie.DARK end
    if index == IntroMovie.SHADE_BLACK then return "black" end
end

-- IntroClearScreen writes tile 0. After the column-major dedupe, tile 0
-- is the blank color-0 tile, so the field is white under 0xE4.
-- IntroPlaceBlackTiles writes tile 1, the solid color-3 bar.
IntroMovie.FIELD = 0
IntroMovie.LETTERBOX = 3
IntroMovie.BAR_ROWS = 4
-- hlcoord 13, 7 and the 6-by-6 front after the 40-step enter.
IntroMovie.GENGAR_AT = {col = 13, row = 7, tiles = 7}
IntroMovie.JIGGLY_AT = {col = 9, row = 9, tiles = 6}

function IntroMovie.backFrame(id)
    if id == "gengar-raise" or id == "wait-30-b" then return "gengar_2" end
    if id == "gengar-slash" or id == "hip-3" or id == "wait-30-c" then return "gengar_3" end
    return "gengar_1"
end

function IntroMovie.frontFrame(id)
    if id == "lunge" then return "fight_jiggly_3" end
    -- FightIntroFrontMon2 until the hip that clears wIntroNidorinoBaseTile,
    -- then again for Animation6. The lunge uses FightIntroFrontMon3.
    if id == "hip-3" or id == "wait-30-c" or id == "gengar-return" or id == "wait-60"
        or id == "hip-6" or id == "wait-30-d" then
        return "fight_jiggly_2"
    end
    return "fight_jiggly_1"
end

function IntroMovie.draw(state, gfx)
    if not gfx or not state then return end
    local sceneRow = IntroMovie.SCENES[state.index]
    local row = (TitleIdle and TitleIdle.ROW) or 13
    local bar = IntroMovie.BAR_ROWS * row
    gfx.clear(gfx.kColorWhite)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, 400, bar)
    gfx.fillRect(0, 14 * row, 400, bar)
    if not sceneRow then
        gfx.drawText("...", 24, 100)
        return
    end
    if sceneRow.id == "copyright" then
        for index, line in ipairs(IntroMovie.COPYRIGHT_LINES) do
            gfx.drawText(line, 24, 64 + (index - 1) * 22)
        end
    end
end
