-- Battle, map, jingle, and HP decisions. No Playdate and no gameplay state.
-- KantoEvents is the generated table from audio/events.lua.

function KantoEvents.mapScore(id)
    if type(id) ~= "string" then
        return nil
    end
    return KantoEvents.maps[KantoEvents.aliases[id] or id]
end

function KantoEvents.fieldBed(mode, mapScore)
    if mode == "surfing" then
        return "surfing"
    end
    if mode == "bicycle" then
        return "bicycle"
    end
    return mapScore
end

-- audio/play_battle_music.asm PlayBattleMusic.
-- A nil gymLeaderNo infers the eight classes that only battle as leaders.
-- Giovanni infers only in Viridian Gym. An explicit 0 is trainer music.
-- Species below OPP_ID_OFFSET, including the static legendaries, use wild.
function KantoEvents.battleScore(info)
    info = info or {}
    local class = info.trainerClass
    local gym = info.gymLeaderNo
    if type(gym) == "number" and gym ~= 0 then
        return "gym_leader"
    end
    local wild = info.wild == true or class == nil or class == ""
    if wild then
        return "wild"
    end
    if class == "OPP_RIVAL3" then
        return "final"
    end
    if class == "OPP_LANCE" then
        return "gym_leader"
    end
    if gym == nil and KantoEvents.uniqueGym[class] then
        return "gym_leader"
    end
    if gym == nil and class == "OPP_GIOVANNI" and info.zone == KantoEvents.giovanniZone then
        return "gym_leader"
    end
    return "trainer"
end

function KantoEvents.battleKind(info)
    info = info or {}
    local score = KantoEvents.battleScore(info)
    if score == "wild" and info.species and KantoEvents.legendary[info.species] then
        return "legendary"
    end
    if score == "final" then
        return "champion"
    end
    if score == "gym_leader" then
        return "gym"
    end
    return score
end

-- engine/battle/core.asm: wild, trainer, or gym (gym flag or rival3).
function KantoEvents.victoryScore(info)
    local score = KantoEvents.battleScore(info)
    if score == "wild" then
        return "defeated_wild"
    end
    if score == "gym_leader" or score == "final" then
        return "defeated_gym"
    end
    return "defeated_trainer"
end

-- home/trainers.asm PlayTrainerMusic. Rivals return without a jingle.
-- A nonzero gym flag also returns. At EngageMapTrainer that flag is still 0,
-- so gym leaders do get their class jingle.
function KantoEvents.trainerJingle(class, gymLeaderNo)
    if type(class) ~= "string" or class == "" then
        return nil
    end
    if KantoEvents.rivalSilent[class] then
        return nil
    end
    if type(gymLeaderNo) == "number" and gymLeaderNo ~= 0 then
        return nil
    end
    if KantoEvents.evil[class] then
        return "meet_evil"
    end
    if KantoEvents.female[class] then
        return "meet_female"
    end
    return "meet_male"
end

-- engine/gfx/hp_bar.asm GetHPBarLength. Pixels = hp * 48 / maxHP, minimum 1.
-- When maxHP >= 256 both the product and maxHP shift right by 2 first.
function KantoEvents.hpBarPixels(hp, maxHP)
    if type(hp) ~= "number" or type(maxHP) ~= "number" or hp <= 0 or maxHP <= 0 then
        return 0
    end
    local product = hp * 48
    local denom = maxHP
    if maxHP >= 256 then
        product = product // 4
        denom = denom // 4
        if denom < 1 then
            denom = 1
        end
    end
    local pixels = product // denom
    if pixels < 1 then
        pixels = 1
    elseif pixels > 48 then
        pixels = 48
    end
    return pixels
end

-- home/palettes.asm GetHealthBarColor: under 10 pixels is red.
-- The alarm is the player's living mon only (hp > 0).
function KantoEvents.lowHP(hp, maxHP)
    return type(hp) == "number" and hp > 0 and KantoEvents.hpBarPixels(hp, maxHP) < 10
end

-- Start menu opens with SFX_START_MENU. Other menus and cursor moves use
-- SFX_PRESS_AB. The title menu does not play the start-menu sound.
-- previousRoot nil skips the first frame so boot does not chirp.
function KantoEvents.menuCue(topName, previousRoot, previousMenu, menu, previousCursor, cursor)
    if previousRoot == nil or not menu then
        return nil
    end
    if menu ~= previousMenu then
        if topName == "pause" then
            return "start_menu"
        end
        if topName == "title" then
            return nil
        end
        return "menu"
    end
    if cursor ~= previousCursor then
        return "menu"
    end
    return nil
end
