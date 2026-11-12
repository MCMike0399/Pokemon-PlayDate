-- Read-only audio observer. Import once; call updateGame after input.
-- Score notes load on first play from audio/score/<name>.lua.
import "audio/events"
import "audio/select"
import "audio/engine"

KantoAudio = {}

local mapScore = nil
local inBattle = false
local traversal = nil
local observer = {}
local tickSeconds <const> = 70224 / 4194304
-- Observer updates stand in for GB frames. The port does not bounce the logo
-- or play the fight intro, so this clock is the title.asm sequence, which is
-- where both sounds and the attract cry actually are.
-- Crash: title.asm plays SFX_INTRO_CRASH when the scroll amount becomes -3,
-- after DelayFrame counts 16+4. intro.asm:88 uses the same score for the
-- Gengar slash; that movie is not a visible state here.
-- Whoosh: the remaining bounce is 4+2+2+2+2 frames, then DelayFrames 36,
-- so SFX_INTRO_WHOOSH (title.asm:193) is 68 frames from the start. It is not
-- in intro.asm. The traced whoosh lasts 34 ticks. The 28-frame version scroll
-- and Delay3 finish while it is still playing, and WaitForSoundToFinish holds
-- Music_TitleScreen until those 34 ticks end.
local TITLE_CRASH_FRAME <const> = 20
local TITLE_WHOOSH_FRAME <const> = 68
local TITLE_MUSIC_FRAME <const> = 102
-- Story.OAK_STOP's first line. Visible on the dialog; no intro getter.
local MEET_OAK_LINE <const> = "OAK: Hey! Wait! Don't go out!"

local function battleInfo(battle, zone)
    return {
        trainerClass = battle.trainerClass,
        gymLeaderNo = battle.gymLeaderNo,
        species = battle.enemy and battle.enemy.species,
        wild = battle.trainerName == nil,
        zone = observer.battleZone or zone,
    }
end

local function restoreField()
    KantoSynth.music(KantoEvents.fieldBed(traversal, mapScore))
end

function KantoAudio.enterMap(zone)
    local id = type(zone) == "table" and zone.stableID or zone
    mapScore = KantoEvents.mapScore(id)
    if not inBattle then
        KantoSynth.music(KantoEvents.fieldBed(traversal, mapScore), true)
    end
end

function KantoAudio.setTraversal(mode)
    if mode ~= "surfing" and mode ~= "bicycle" then
        mode = nil
    end
    if mode == traversal then
        return
    end
    traversal = mode
    if not inBattle then
        KantoSynth.music(KantoEvents.fieldBed(traversal, mapScore), true)
    end
end

function KantoAudio.battleStart(info)
    inBattle = true
    KantoSynth.lowHP(false)
    local score = "wild"
    local keepMeet = false
    if type(info) == "table" then
        score = KantoEvents.battleScore(info)
        keepMeet = info.keepMeet == true
    elseif info == "trainer" then
        score = "trainer"
    end
    KantoSynth.music(score, keepMeet)
end

function KantoAudio.battleEnd()
    inBattle = false
    KantoSynth.lowHP(false)
    if observer.victoryFrames and observer.victoryFrames > 0 then
        return
    end
    restoreField()
end

function KantoAudio.playCue(name)
    local cue = KantoEvents.cues[name]
    if not cue then
        return false, "unknown Kanto cue"
    end
    if cue.kind == "music" then
        KantoSynth.music(cue.score)
        return true
    end
    if cue.kind == "jingle" then
        return KantoSynth.jingle(cue.score)
    end
    return KantoSynth.sfx(cue.score)
end

function KantoAudio.playSFX(name)
    if KantoEvents.cues[name] then
        return KantoAudio.playCue(name)
    end
    return KantoSynth.sfx(name)
end

function KantoAudio.playJingle(name)
    local cue = KantoEvents.cues[name]
    if cue and cue.kind == "jingle" then
        return KantoSynth.jingle(cue.score)
    end
    if cue and cue.kind == "music" then
        KantoSynth.music(cue.score)
        return true
    end
    return KantoSynth.jingle(name)
end

function KantoAudio.playCry(species)
    return KantoSynth.cry(species)
end

function KantoAudio.trainerJingle(class, gymLeaderNo)
    return KantoEvents.trainerJingle(class, gymLeaderNo)
end

function KantoAudio.battleScore(info)
    return KantoEvents.battleScore(info)
end

function KantoAudio.battleKind(info)
    return KantoEvents.battleKind(info)
end

function KantoAudio.noteBattle(zone)
    observer.battleZone = type(zone) == "table" and zone.stableID or zone
end

function KantoAudio.setLowHP(flag)
    KantoSynth.lowHP(inBattle and flag == true)
end

function KantoAudio.update()
    KantoSynth.update()
end

function KantoAudio.stop()
    inBattle = false
    mapScore = nil
    traversal = nil
    observer = {}
    KantoSynth.stop()
end

-- Read only the active stack and presentation fields. Never calls gameplay
-- getters, callbacks, RNG, or installs listeners. Keeps its own small snapshot.
local function visibleMenu(top)
    if not top then
        return
    end

    local menu = top.menu
    if menu and menu.isActive then
        return menu, menu.selectedIndex
    end

    local scene = top.name == "battle" and top.scene
    if scene then
        for _, key in ipairs({"moveMenu", "mainMenu"}) do
            menu = scene[key]
            if menu and menu.isActive then
                return menu, menu.selectedIndex
            end
        end
    end

    if top.phase == "list" or top.phase == "swap" or top.phase == "browse" then
        if type(top.selected) == "number" then
            return top, top.selected
        end
    end
end

local function textAdvance(top, menu)
    if menu or not top or not playdate.buttonJustPressed(playdate.kButtonA) then
        return false
    end
    if top.name == "dialog" then
        return true
    end
    if top.dialog and top.dialog.isActive then
        return true
    end
    local scene = top.scene
    return scene and scene.messageDialog and scene.messageDialog.isActive or false
end

local function noteCries(battle, battleState)
    local scene = battleState.scene
    if not scene then
        return
    end
    if scene.introPhase == "ready" and observer.introCry ~= battle then
        observer.introCry = battle
        if not battle.trainerName and battle.enemy and battle.enemy.species then
            KantoAudio.playCry(battle.enemy.species)
        end
    end
    if scene.playerShown and scene.playerShown ~= observer.playerShown then
        observer.playerShown = scene.playerShown
        if scene.playerShown.species then
            KantoAudio.playCry(scene.playerShown.species)
        end
    end
    if battle.trainerName and scene.enemyShown and scene.enemyShown ~= observer.enemyShown then
        observer.enemyShown = scene.enemyShown
        if scene.enemyShown.species then
            KantoAudio.playCry(scene.enemyShown.species)
        end
    end
end

function KantoAudio.updateGame(game)
    local stack = game and game.machine and game.machine.stack
    local root = stack and stack[1]
    local top = stack and stack[#stack]
    if not root then
        if observer.root then
            KantoAudio.stop()
        end
        return
    end

    if observer.game ~= game or observer.session ~= game.session then
        KantoAudio.stop()
        observer.game = game
        observer.session = game.session
    end

    if observer.victoryFrames then
        observer.victoryFrames = observer.victoryFrames - 1
        if observer.victoryFrames <= 0 then
            observer.victoryFrames = nil
            if not inBattle then
                restoreField()
            end
        end
    end

    if root.name == "title" then
        if observer.root ~= "title" then
            KantoAudio.stop()
            observer.game = game
            observer.session = game.session
            observer.titleFrames = 0
            observer.titleMusic = false
            observer.titleCry = false
        end
        local phase = root.phase
        local topIsTitle = top and top.name == "title"
        if topIsTitle and (phase == "preparing" or phase == "menu") then
            observer.titleFrames = (observer.titleFrames or 0) + 1
            local frame = observer.titleFrames
            if frame == TITLE_CRASH_FRAME then
                KantoAudio.playSFX("intro_crash")
            elseif frame == TITLE_WHOOSH_FRAME then
                KantoAudio.playSFX("intro_whoosh")
            elseif frame == TITLE_MUSIC_FRAME and not observer.titleMusic then
                observer.titleMusic = true
                KantoSynth.music("title")
            end
        end
        if root.idle and root.idle.species then
            observer.titleSpecies = root.idle.species
        end
        -- title.asm .finishedWaiting cries wTitleMonSpecies on the way out of
        -- the attract loop. Confirm, message, and closed are that exit.
        -- Opening another state on top of a still-idle title is not.
        if phase ~= "preparing" and phase ~= "menu" and not observer.titleCry then
            observer.titleCry = true
            if not observer.titleMusic then
                observer.titleMusic = true
                KantoSynth.music("title")
            end
            if observer.titleSpecies then
                KantoAudio.playCry(observer.titleSpecies)
            end
        end
    else
        if observer.root == "title" and not observer.titleCry and observer.titleSpecies then
            observer.titleCry = true
            KantoAudio.playCry(observer.titleSpecies)
        end
        local zone = currentZone and currentZone.stableID
        if observer.root == "title" or observer.zone ~= zone then
            KantoAudio.enterMap(zone)
            observer.zone = zone
        end

        local lastTravel = game.lastFieldTravel
        if lastTravel and lastTravel ~= observer.travel and lastTravel.mode then
            observer.travel = lastTravel
            KantoAudio.setTraversal(lastTravel.mode)
        end
        local lastGear = game.lastFieldGear
        if lastGear and lastGear ~= observer.gear and lastGear.kind == "bicycle" then
            observer.gear = lastGear
            local gear = game.machine:get("fieldGear")
            local mode = gear and gear.plan and gear.plan.travel and gear.plan.travel.mode
            if mode then
                KantoAudio.setTraversal(mode)
            end
        end

        local battleState
        for _, state in ipairs(stack) do
            if state.name == "battle" then
                battleState = state
                break
            end
        end

        local battle = battleState and battleState.battle
        if battle ~= observer.battle then
            observer.hp = {}
            observer.introCry = nil
            observer.playerShown = nil
            observer.enemyShown = nil
            observer.victory = nil
            observer.caught = nil
            observer.level = nil
            observer.levelMon = nil
            if battle then
                KantoAudio.battleStart(battleInfo(battle, zone))
            elseif observer.battle then
                KantoAudio.battleEnd()
            end
            observer.battle = battle
            observer.lowHP = nil
        end

        if battle then
            local info = battleInfo(battle, zone)
            local hp = observer.hp
            local hit = false
            local faint = false
            for _, mon in ipairs({battle.player, battle.enemy}) do
                if mon and type(mon.hp) == "number" then
                    local before = hp[mon]
                    if before and mon.hp < before then
                        hit = true
                        if mon.hp <= 0 then
                            faint = true
                        end
                    end
                    hp[mon] = mon.hp
                end
            end

            local mon = battle.player
            local low = mon and KantoEvents.lowHP(mon.hp, mon.maxHP) or false
            if low ~= observer.lowHP then
                KantoAudio.setLowHP(low)
                observer.lowHP = low
            end

            if mon and type(mon.level) == "number" then
                if observer.levelMon == mon and type(observer.level) == "number" and mon.level > observer.level then
                    KantoAudio.playCue("level_up")
                end
                observer.levelMon = mon
                observer.level = mon.level
            end

            if battle.outcome == "victory" and not observer.victory then
                observer.victory = true
                local name = KantoEvents.victoryScore(info)
                KantoSynth.music(name)
                observer.victoryFrames = math.ceil(KantoSynth.scoreTicks(name) * tickSeconds * 30)
            elseif battle.outcome == "caught" and not observer.caught then
                observer.caught = true
                KantoAudio.playCue("caught")
            end

            if faint then
                KantoAudio.playSFX("faint")
            elseif hit then
                KantoAudio.playSFX("hit")
            end
            noteCries(battle, battleState)
        end

        local healing
        for _, state in ipairs(stack) do
            if state.phase == "heal-animation" then
                healing = state
                break
            end
        end
        if healing and observer.healing ~= healing then
            KantoAudio.playSFX("healing_machine")
            KantoAudio.playCue("heal")
        end
        observer.healing = healing

        local ceremony
        for _, state in ipairs(stack) do
            if state.phase == "hall-photo" then
                ceremony = "hall_of_fame"
            elseif state.phase == "credits" then
                ceremony = "credits"
            end
        end
        if ceremony and observer.ceremony ~= ceremony then
            KantoAudio.playCue(ceremony)
        end
        observer.ceremony = ceremony

        local evo = game.machine:get("evolution")
        if evo and evo.active and evo.sub then
            local phase = evo.sub:getCurrent()
            if phase ~= observer.evoPhase then
                if phase == "announce" then
                    KantoAudio.playSFX("tink")
                elseif phase == "animate" then
                    if evo.info and evo.info.from then
                        KantoAudio.playCry(evo.info.from)
                    end
                    KantoAudio.playCue("evolution")
                elseif phase == "result" and evo.result and evo.info then
                    -- evolution.asm .done stops the bed, then cries the species
                    -- on screen: the new one after a success, wEvoOldSpecies
                    -- after .evolutionCancelled jumps to .done.
                    if evo.result.kind == "complete" then
                        KantoSynth.music(nil)
                        KantoAudio.playCry(evo.info.species or evo.info.to)
                    elseif evo.result.kind == "cancelled" and evo.info.from then
                        KantoSynth.music(nil)
                        KantoAudio.playCry(evo.info.from)
                    end
                end
                observer.evoPhase = phase
            end
        elseif observer.evoPhase then
            observer.evoPhase = nil
            if not inBattle then
                restoreField()
            end
        end

        local event = game.machine:get("event")
        local receiptDialog
        if event and event.phase == "receipt" and event.waiting then
            for _, state in ipairs(stack) do
                if state.name == "dialog" then
                    receiptDialog = state
                end
            end
            if receiptDialog and receiptDialog ~= observer.receiptDialog then
                observer.receiptDialog = receiptDialog
                local fanfare = KantoEvents.fieldReceipts[event.waiting]
                if fanfare then
                    KantoAudio.playCue(fanfare)
                end
            end
        end

        if top and top.name == "dialog" and top.lines and not observer.meetOak then
            local line = top.lines[1]
            if type(line) == "table" then
                line = line.text
            end
            local zoneId = currentZone and currentZone.stableID
            local pallet = zoneId == "pokered:PALLET_TOWN"
                or KantoEvents.aliases[zoneId] == "pokered:PALLET_TOWN"
            if pallet and line == MEET_OAK_LINE then
                observer.meetOak = true
                KantoAudio.playJingle("meet_oak")
            end
        end

        local pc = game.machine:get("pc")
        if pc and pc.active then
            if pc ~= observer.pc or pc.phase ~= observer.pcPhase then
                local previous = observer.pc == pc and observer.pcPhase or "closed"
                if pc.phase == "top" and previous == "closed" then
                    KantoAudio.playSFX("pc_on")
                elseif pc.phase == "storage" and previous ~= "storage" then
                    KantoAudio.playSFX("pc_enter")
                elseif pc.phase == "list" and previous ~= "list"
                    and (pc.operation == "withdraw" or pc.operation == "deposit") then
                    KantoAudio.playSFX("pc_withdraw")
                end
                observer.pc = pc
                observer.pcPhase = pc.phase
            end
        elseif observer.pcPhase and observer.pcPhase ~= "closed" then
            KantoAudio.playSFX("pc_off")
            observer.pc = nil
            observer.pcPhase = "closed"
        end

        local overworld = game.machine:get("overworld")
        local sub = overworld and overworld.sub
        local warp = sub and sub:get("doorWarp")
        -- door.connection stands in for PlayMapChangeSound's $0b tile test.
        local door = warp and sub:getCurrent() == "doorWarp" and warp.door
        if door and door ~= observer.door then
            observer.door = door
            KantoAudio.playSFX(door.connection and "go_inside" or "go_outside")
        end

        local move = game.machine:get("fieldMove")
        if move and move.phase == "effect" and move.preview and move.preview.key == "cut" then
            if observer.cut ~= move or observer.cutPhase ~= "effect" then
                KantoAudio.playSFX("cut")
            end
        end
        observer.cut = move
        observer.cutPhase = move and move.phase

        local travel = game.machine:get("fieldTravel")
        if travel and travel.key == "push" and travel.phase == "push" and travel.boulder
            and observer.push ~= travel.boulder then
            observer.push = travel.boulder
            KantoAudio.playSFX("boulder")
        end

        local player = game.player
        if player and player.isJumping and not observer.jumping then
            KantoAudio.playSFX("ledge")
        end
        observer.jumping = player and player.isJumping or false
    end

    local menu, cursor = visibleMenu(top)
    local cue = KantoEvents.menuCue(top and top.name, observer.root, observer.menu, menu, observer.cursor, cursor)
    if cue then
        KantoAudio.playSFX(cue)
    elseif textAdvance(top, menu) then
        KantoAudio.playSFX("text")
    end
    observer.root = root.name
    observer.menu = menu
    observer.cursor = cursor
    KantoAudio.update()
end
