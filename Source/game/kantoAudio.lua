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
-- or draw the fight intro. The title clock is still the title.asm sequence.
-- PlayIntro's shooting star and nidorino lunge have no movie state, so those
-- two sounds sit on this clock before the crash, on frames that title.asm
-- does not already use.
-- Crash: title.asm plays SFX_INTRO_CRASH when the scroll amount becomes -3,
-- after DelayFrame counts 16+4. intro.asm:88 uses the same score for the
-- Gengar slash; that movie is not a visible state here.
-- Whoosh: the remaining bounce is 4+2+2+2+2 frames, then DelayFrames 36,
-- so SFX_INTRO_WHOOSH (title.asm:193) is 68 frames from the start. It is not
-- in intro.asm. The traced whoosh lasts 34 ticks. The 28-frame version scroll
-- and Delay3 finish while it is still playing, and WaitForSoundToFinish holds
-- Music_TitleScreen until those 34 ticks end.
local TITLE_STAR_FRAME <const> = 1
local TITLE_LUNGE_FRAME <const> = 10
local TITLE_CRASH_FRAME <const> = 20
local TITLE_WHOOSH_FRAME <const> = 68
local TITLE_MUSIC_FRAME <const> = 102
-- Story.OAK_STOP's first line. Visible on the dialog; no intro getter.
local MEET_OAK_LINE <const> = "OAK: Hey! Wait! Don't go out!"
-- ChampionsRoomOakArrivesScript. The rendered line substitutes the player name.
local OAK_ARRIVAL_PREFIX <const> = "OAK:"
-- Route22SecondRivalBattleScript walks this object in on the slow rival bed.
local ROUTE22_RIVAL <const> = "pokered:ROUTE_22:objects:2"
-- First page of _Route22RivalAfterBattleText2. The exit music starts after it.
local ROUTE22_LEAGUE_LINE <const> = "That loosened me"
-- home/text.asm TextCommand_SOUND. Dewgong's byte is unused, so it is not played.
local NIDORINA_LINE <const> = "For some people,"
local PIDGEOT_LINE <const> = "PIDGEOT:"

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
    -- EventState:dialog is the page method. Indexing it as a Dialog
    -- crashes the nurse before YES, while A is still just-pressed.
    local dialog = top.dialog
    if type(dialog) == "table" and dialog.isActive then
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

local function sfxFrames(name)
    return math.max(1, math.ceil(KantoSynth.scoreTicks(name) * tickSeconds * 30))
end

local function enqueueSFX(name, frames)
    observer.sfxQueue = observer.sfxQueue or {}
    observer.sfxQueue[#observer.sfxQueue + 1] = {name = name, frames = frames}
end

local function moveScore(key)
    if not KantoMoveSfx then
        import "audio/moveSfx"
    end
    return KantoMoveSfx[key]
end

local function ratingCue(owned)
    -- audio/pokedex_rating_sfx.asm OwnedMonValues: 10, 40, 60, 90, 120, 150.
    owned = owned or 0
    if owned < 10 then return "denied" end
    if owned < 40 then return "pokedex_rating" end
    if owned < 60 then return "item" end
    if owned < 90 then return "caught" end
    if owned < 120 then return "level_up" end
    if owned < 150 then return "key_item" end
    return "item2"
end

local function playSafariPA()
    -- SafariZoneGameOver and ShakeElevator stop the bed, then play this
    -- announcement on the music channel until it finishes.
    KantoSynth.music(nil)
    KantoAudio.playSFX("safari_pa")
end

local function noteReceipts(game)
    local shop = game.machine:get("shop")
    local bought = shop and shop.phase == "result" and shop.trade == "buy" and shop.result
    if bought and bought.ok and bought ~= observer.purchase then
        observer.purchase = bought
        KantoAudio.playSFX("purchase")
    end

    local pc = game.machine:get("pc")
    local box = pc and pc.phase == "result" and pc.result
    if box and box.ok and box.reason == "saved" and box ~= observer.boxSave then
        observer.boxSave = box
        KantoAudio.playSFX("save")
    end
    local saved = game.lastSave
    if saved and saved.ok and saved ~= observer.menuSave then
        observer.menuSave = saved
        KantoAudio.playSFX("save")
    end

    local use = game.lastItemUse
    if use and use ~= observer.itemUse then
        observer.itemUse = use
        if use.effect == "cure" then
            KantoAudio.playSFX("heal_ailment")
        elseif use.effect == "heal" or use.effect == "fullRestore" or use.effect == "revive" then
            KantoAudio.playSFX("heal_hp")
        end
    end

    local poison = game.lastFieldPoison
    if poison and poison ~= observer.poison then
        observer.poison = poison
        KantoAudio.playSFX("poisoned")
    end

    local rating = game.lastDexRating
    if rating and rating ~= observer.dexRating then
        observer.dexRating = rating
        KantoAudio.playCue(ratingCue(rating.owned))
    end

    local ride = game.lastElevator
    if ride and ride ~= observer.elevator then
        observer.elevator = ride
        playSafariPA()
    end

    local event = game.machine:get("event")
    local waiting = event and event.waiting
    if waiting ~= observer.eventWaiting then
        observer.eventWaiting = waiting
        -- VermilionGymTrashSuccessText1, the Game Corner poster, and
        -- BillsHouseInitiatedText each play SFX_SWITCH as that page starts.
        if waiting == "_VermilionGymTrashSuccessText1"
            or waiting == "_GameCornerPosterSwitchBehindPosterText"
            or waiting == "_BillsHouseInitiatedText" then
            KantoAudio.playSFX("switch")
        end
    end
    local separator = event and event.phase == "story-machine" and waiting == "cell-separator"
    if separator and not observer.billShrink then
        observer.billShrink = true
        KantoAudio.playSFX("shrink")
    elseif not separator then
        observer.billShrink = nil
    end

    local passage = game.machine:get("safariPassage")
    if passage and passage.phase == "announcement" and observer.safariPA ~= passage then
        observer.safariPA = passage
        playSafariPA()
    end
end

local function playSequence(names)
    KantoAudio.playSFX(names[1])
    local wait = sfxFrames(names[1])
    for index = 2, #names do
        enqueueSFX(names[index], wait)
        wait = sfxFrames(names[index])
    end
end

local function pumpSFX()
    local queue = observer.sfxQueue
    local head = queue and queue[1]
    if not head then
        return
    end
    head.frames = head.frames - 1
    if head.frames <= 0 then
        table.remove(queue, 1)
        KantoAudio.playSFX(head.name)
    end
end

local function sameZone(id, authoredName)
    local zone = currentZone
    if not zone then
        return false
    end
    local stable = zone.stableID
    if stable == id or KantoEvents.aliases[stable] == id then
        return true
    end
    return authoredName ~= nil and (stable == authoredName or zone.name == authoredName)
end

-- Production dialog keeps pages on dialog.lines. Host stubs use top.lines.
local function dialogLine(top)
    if not top or top.name ~= "dialog" then
        return nil
    end
    local dialog = top.dialog
    local lines = dialog and dialog.lines or top.lines
    if not lines then
        return nil
    end
    local index = dialog and dialog.lines and (dialog.currentLine or 1) or 1
    local line = lines[index]
    if type(line) == "table" then
        line = line.text
    end
    if type(line) ~= "string" then
        return nil
    end
    return line
end

-- alternate_tempo.asm Music_RivalAlternateStart, after each earlier exit.
local function noteRivalExit(line)
    if type(line) ~= "string" then
        return
    end
    local function once(flag)
        if observer[flag] then
            return
        end
        observer[flag] = true
        KantoAudio.playCue("meet_rival_start")
    end
    if sameZone("pokered:OAKS_LAB", "Oak's Lab") then
        if line:find("Smell you later!", 1, true) then
            once("rivalLabExit")
        elseif line:match("^%S+: Gramps!$") then
            once("rivalGramps")
        elseif line:find("Leave it", 1, true) then
            once("rivalDex")
        end
    elseif sameZone("pokered:ROUTE_22") and line:find("I heard", 1, true) then
        once("rivalRoute22")
    elseif sameZone("pokered:CERULEAN_CITY") and line:find("BILL", 1, true) then
        once("rivalCerulean")
    elseif sameZone("pokered:POKEMON_TOWER_2F") and line:find("How's your", 1, true) then
        once("rivalTower")
    elseif sameZone("pokered:SS_ANNE_2F") and line:find("CUT", 1, true) then
        once("rivalAnne")
    elseif sameZone("pokered:SILPH_CO_7F") and line:find("good luck", 1, true) then
        once("rivalSilph")
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
        pumpSFX()
        if topIsTitle and (phase == "preparing" or phase == "menu") then
            observer.titleFrames = (observer.titleFrames or 0) + 1
            local frame = observer.titleFrames
            -- PlayShootingStar (splash.asm) and the nidorino lunge (intro.asm)
            -- run before PrepareTitleScreen. Frames 1 and 10 are free before
            -- the crash at 20, so the title.asm clock is left where it was.
            if frame == TITLE_STAR_FRAME then
                KantoAudio.playSFX("shooting_star")
            elseif frame == TITLE_LUNGE_FRAME then
                KantoAudio.playSFX("intro_lunge")
            elseif frame == TITLE_CRASH_FRAME then
                KantoAudio.playSFX("intro_crash")
            elseif frame == TITLE_WHOOSH_FRAME then
                KantoAudio.playSFX("intro_whoosh")
            elseif frame == TITLE_MUSIC_FRAME and not observer.titleMusic then
                observer.titleMusic = true
                KantoSynth.music("title")
            end
        end
        -- TextCommand_SOUND TX_SOUND_CRY_NIDORINA, between oak speech 2A and 2B.
        local opening = dialogLine(top)
        if opening and opening:sub(1, #NIDORINA_LINE) == NIDORINA_LINE and not observer.nidorina then
            observer.nidorina = true
            KantoAudio.playCry("nidorina")
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

        pumpSFX()
        local lastTravel = game.lastFieldTravel
        if lastTravel and lastTravel ~= observer.travel and lastTravel.mode then
            observer.travel = lastTravel
            KantoAudio.setTraversal(lastTravel.mode)
        end
        -- EnterMapAnim and LeaveMapAnim each play SFX_FLY when BIT_USED_FLY is set.
        local fieldTravel = game.machine:get("fieldTravel")
        local flyPhase = fieldTravel and fieldTravel.key == "fly" and fieldTravel.phase or nil
        if flyPhase == "fade" and observer.flyPhase ~= "fade" then
            KantoAudio.playSFX("fly")
        end
        observer.flyPhase = flyPhase
        if lastTravel and lastTravel ~= observer.flyReceipt and lastTravel.key == "fly"
            and lastTravel.kind == "complete" then
            observer.flyReceipt = lastTravel
            KantoAudio.playSFX("fly")
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
            observer.moveKey = nil
            observer.capturePhase = nil
            observer.ran = nil
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
            local enemyFaint = false
            for _, mon in ipairs({battle.player, battle.enemy}) do
                if mon and type(mon.hp) == "number" then
                    local before = hp[mon]
                    if before and mon.hp < before then
                        hit = true
                        if mon.hp <= 0 then
                            faint = true
                            if mon == battle.enemy then
                                enemyFaint = true
                            end
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
            -- ItemUseBallText06 plays SFX_DEX_PAGE_ADDED when the caught
            -- species was not already owned. throwBall sets dexPageAdded.
            if battle.dexPageAdded and observer.dexPage ~= battle then
                observer.dexPage = battle
                KantoAudio.playSFX("dex_page")
            end
            if battle.outcome == "run" and not observer.ran then
                -- EnemyRan and the successful player escape both play SFX_RUN.
                observer.ran = true
                KantoAudio.playSFX("run")
            end

            local moveKey = battle.currentMoveKey
            local moveCue = nil
            if moveKey ~= observer.moveKey then
                observer.moveKey = moveKey
                moveCue = moveKey and moveScore(moveKey)
            end

            -- FaintEnemyPokemon (core.asm) waits out SFX_FAINT_FALL, then
            -- plays SFX_FAINT_THUD. A wild win skips the fall and plays the
            -- victory bed instead. The player's own faint is the thud alone.
            -- GetMoveSound plays the move's row first. When the damage lands
            -- in the same update, the hit or fall follows that row.
            if observer.pendingThud then
                observer.pendingThud = observer.pendingThud - 1
                if observer.pendingThud <= 0 then
                    observer.pendingThud = nil
                    KantoAudio.playSFX("faint")
                end
            end
            if enemyFaint and not info.wild then
                if moveCue then
                    playSequence({moveCue, "faint_fall"})
                    observer.pendingThud = sfxFrames(moveCue) + sfxFrames("faint_fall")
                else
                    KantoAudio.playSFX("faint_fall")
                    observer.pendingThud = sfxFrames("faint_fall")
                end
            elseif faint then
                observer.pendingThud = nil
                if moveCue then
                    playSequence({moveCue, "faint"})
                else
                    KantoAudio.playSFX("faint")
                end
            elseif hit then
                if moveCue then
                    playSequence({moveCue, "hit"})
                else
                    KantoAudio.playSFX("hit")
                end
            elseif moveCue then
                KantoAudio.playSFX(moveCue)
            end
            noteCries(battle, battleState)
            -- DoPoofSpecialEffects plays SFX_BALL_POOF when the poof subanim
            -- counter is 5. The capture scene uses that poof for absorb and
            -- for a failed breakout.
            local scene = battleState.scene
            local capture = scene and scene.captureAnimation
            local capturePhase = capture and capture.phase
            if capturePhase ~= observer.capturePhase then
                observer.capturePhase = capturePhase
                if capturePhase == "throw" then
                    -- DoBallTossSpecialEffects plays this at the start of the toss.
                    KantoAudio.playSFX("ball_toss")
                elseif capturePhase == "absorb" or capturePhase == "breakout" then
                    KantoAudio.playSFX("ball_poof")
                end
            end
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

        local line = dialogLine(top)
        if line then
            local zoneId = currentZone and currentZone.stableID
            local pallet = zoneId == "pokered:PALLET_TOWN"
                or KantoEvents.aliases[zoneId] == "pokered:PALLET_TOWN"
            if not observer.meetOak and pallet and line == MEET_OAK_LINE then
                observer.meetOak = true
                KantoAudio.playJingle("meet_oak")
            end
            -- alternate_tempo.asm Music_Cities1AlternateTempo. Channel 1 is
            -- tempo 232; the other channels stay on the Cities1 header.
            local champions = zoneId == "pokered:CHAMPIONS_ROOM"
                or KantoEvents.aliases[zoneId] == "pokered:CHAMPIONS_ROOM"
            if champions and line:sub(1, #OAK_ARRIVAL_PREFIX) == OAK_ARRIVAL_PREFIX
                and not observer.oakArrival then
                observer.oakArrival = true
                KantoAudio.playCue("cities1_oak")
            end
            local route22 = zoneId == "pokered:ROUTE_22"
                or KantoEvents.aliases[zoneId] == "pokered:ROUTE_22"
            if route22 and line:sub(1, #ROUTE22_LEAGUE_LINE) == ROUTE22_LEAGUE_LINE
                and not observer.route22League then
                observer.route22League = true
                KantoAudio.playCue("meet_rival_league")
            end
            noteRivalExit(line)
            -- TextCommand_SOUND TX_SOUND_CRY_PIDGEOT after the Saffron line.
            if sameZone("pokered:SAFFRON_CITY") and line:sub(1, #PIDGEOT_LINE) == PIDGEOT_LINE
                and not observer.pidgeot then
                observer.pidgeot = true
                KantoAudio.playCry("pidgeot")
            end
        end

        -- Music_RivalAlternateTempo while the second Route 22 rival walks in.
        if event and event.id == ROUTE22_RIVAL and event.phase == "move-npc" and not observer.route22Tempo then
            observer.route22Tempo = true
            KantoAudio.playCue("meet_rival_slow")
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
            -- A resolved source warp whose arrival is not a door tile sets
            -- preserveFacing. That is the visible stand-in for a warp pad:
            -- LeaveMapAnim plays EXIT_1, and EnterMapAnim then plays ENTER_1
            -- and ENTER_2. Door tiles and map connections stay go inside/outside.
            -- Holes are silent on the way out; the hole bit is not on the door.
            if door.preserveFacing and not door.connection then
                playSequence({"teleport_exit_1", "teleport_enter_1", "teleport_enter_2"})
            else
                KantoAudio.playSFX(door.connection and "go_inside" or "go_outside")
            end
        end

        local move = game.machine:get("fieldMove")
        if move and move.phase == "effect" and move.preview and move.preview.key == "cut" then
            if observer.cut ~= move or observer.cutPhase ~= "effect" then
                KantoAudio.playSFX("cut")
            end
        end
        observer.cut = move
        observer.cutPhase = move and move.phase

        -- ItemUseEscapeRope, Dig, and field Teleport set BIT_ESCAPE_WARP and
        -- BIT_FLY_WARP. Leave plays EXIT_2 then EXIT_1. Arrival plays ENTER_1
        -- then ENTER_2. Only the escape rope sets lastFieldItem today.
        local fieldItem = game.lastFieldItem
        if fieldItem and fieldItem ~= observer.fieldItem and fieldItem.kind == "escape-rope"
            and fieldItem.ok ~= false then
            observer.fieldItem = fieldItem
            playSequence({
                "teleport_exit_2", "teleport_exit_1", "teleport_enter_1", "teleport_enter_2",
            })
        end

        local travel = game.machine:get("fieldTravel")
        if travel and travel.key == "push" and travel.phase == "push" and travel.boulder
            and observer.push ~= travel.boulder then
            observer.push = travel.boulder
            KantoAudio.playSFX("boulder")
        end

        -- SwitchPartyMon plays SFX_SWAP only after the two roster slots
        -- exchange. Cancel returns to the list without swapReceipt.
        local party = game.machine:get("party")
        noteReceipts(game)

        local swapReceipt = party and party.swapReceipt
        if swapReceipt and swapReceipt ~= observer.swapReceipt then
            observer.swapReceipt = swapReceipt
            KantoAudio.playSFX("swap")
        end

        local ship
        for _, state in ipairs(stack) do
            if state.vermilionShip and state.vermilionShip.cues then
                ship = state.vermilionShip
            end
        end
        if ship then
            local seen = observer.shipCues or 0
            for index = seen + 1, #ship.cues do
                local symbol = ship.cues[index].symbol
                if symbol == "SFX_SS_ANNE_HORN" then
                    KantoAudio.playSFX("anne_horn")
                elseif symbol == "SFX_STOP_ALL_MUSIC" then
                    KantoSynth.music(nil)
                elseif symbol == "MUSIC_SURFING" then
                    KantoAudio.playCue("surf")
                end
            end
            observer.shipCues = #ship.cues
        end

        local player = game.player
        if observer.collisionCooldown then
            observer.collisionCooldown = observer.collisionCooldown - 1
            if observer.collisionCooldown <= 0 then
                observer.collisionCooldown = nil
            end
        end
        local block = player and player.lastTraversalBlock
        -- home/overworld.asm plays SFX_COLLISION on a blocked step, and skips
        -- a restart while that sound is still the current one.
        if block and block ~= observer.block and not observer.collisionCooldown
            and (block.kind == "terrain" or block.kind == "npc") then
            observer.block = block
            KantoAudio.playSFX("collision")
            observer.collisionCooldown = sfxFrames("collision")
        elseif block then
            observer.block = block
        end
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
