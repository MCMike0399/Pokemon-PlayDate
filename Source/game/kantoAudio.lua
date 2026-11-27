-- Read-only audio observer. Import once; call updateGame after input.
-- Score notes load on first play from audio/score/<name>.lua.
import "audio/events"
import "audio/select"
import "audio/engine"
import "audio/moveSfx"

KantoAudio = {}

local mapScore = nil
local inBattle = false
local traversal = nil
local observer = {}
local tickSeconds <const> = 70224 / 4194304

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
        local bed = KantoEvents.fieldBed(traversal, mapScore)
        local tolerate = FieldTravelRuntime and FieldTravelRuntime.consumeMissedBed
            and FieldTravelRuntime.consumeMissedBed()
        if not tolerate then
            KantoSynth.music(bed, true)
        else
            -- The destination atlas can leave no contiguous inflate window.
            -- A missed bed stays silent; the map entry still stands.
            local ok, err = pcall(KantoSynth.music, bed, true)
            local text = tostring(err)
            if not ok and err ~= nil and not text:find("out of memory", 1, true)
                and not text:find("inflate", 1, true) then
                error(err, 0)
            end
        end
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
        -- import inside a function is not compiled, and an imported module
        -- stays in the main chunk. The table is a separate file.run target.
        playdate.file.run("audio/moveSfxData")
    end
    return KantoMoveSfx[key]
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

    pumpSFX()

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
            KantoSynth.music("title")
        end
    else
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
            observer.pendingCry = nil
            observer.pendingCryFrames = nil
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

            if observer.pendingCryFrames then
                observer.pendingCryFrames = observer.pendingCryFrames - 1
                if observer.pendingCryFrames <= 0 then
                    observer.pendingCryFrames = nil
                    if observer.pendingCry then
                        KantoAudio.playCry(observer.pendingCry)
                    end
                    observer.pendingCry = nil
                end
            end
            if faint then
                -- FaintEnemyPokemon waits out the move row, then the thud.
                -- The player's own faint is the cry after that row.
                local species = battle.player and battle.player.species
                local moveKey = battle.currentMoveKey
                local moveCue = moveKey and moveScore(moveKey)
                if battle.player and battle.player.hp ~= nil and battle.player.hp <= 0 and species then
                    -- playSFX returns false for a cue with no score.
                    -- scoreTicks would then assert "unknown Kanto score".
                    local played = moveCue and KantoAudio.playSFX(moveCue)
                    if played then
                        observer.pendingCry = species
                        observer.pendingCryFrames = sfxFrames(moveCue)
                    else
                        observer.pendingCry = species
                        KantoAudio.playCry(observer.pendingCry)
                    end
                else
                    KantoAudio.playSFX("faint")
                end
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
            -- AnimateHealingMachine plays SFX_HEALING_MACHINE once per
            -- party ball, waits DelayFrames(30), then MUSIC_PKMN_HEALED.
            -- FlashSprite8Times overlaps the jingle. The routine returns
            -- after that jingle and DelayFrames(32). KantoHeal.plan is
            -- that schedule. 30 Game Boy frames are 15 Playdate frames.
            local count = healing.healCount
            if not KantoHeal then
                playdate.file.run("audio/healSchedule")
            end
            local events = KantoHeal.plan(count)
            KantoAudio.playSFX(events[1].name)
            for index = 2, #events do
                enqueueSFX(events[index].name, events[index].at - events[index - 1].at)
            end
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
                elseif phase == "result" and evo.result and evo.result.kind == "complete" and evo.info then
                    KantoAudio.playCry(evo.info.species or evo.info.to)
                end
                observer.evoPhase = phase
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
