import "game/fieldGestures"

-- game/overworldState.lua — Overworld play, with its own substate machine
--
-- Substates:
--   explore  — normal play: movement, NPC interaction, wild encounter checks
--   irisOut  — Gen 1 battle transition: world keeps animating while a black
--              iris closes in, then fires a callback (usually -> battle)
--   doorWarp — door/mat/stairs transition: GB-style shade fade to black,
--              then re-enters the overworld in the door's target zone
--
-- Dialog and the debug menu are NOT substates: they are pushed onto the ROOT
-- machine, so the overworld keeps updating (and drawing) beneath them while
-- input is routed to the overlay only.

local gfx <const> = playdate.graphics

-- ============================================================
-- EXPLORE substate
-- ============================================================

Class("ExploreSubstate"):extends(State)

function ExploreSubstate:init(owner)
    ExploreSubstate.super.init(self, "explore")
    self.owner = owner   -- the OverworldState
end

function ExploreSubstate:enter()
    self.gestures = FieldGestures()
    self.pendingAction = nil
    self.owner.game.player.running = false
end

function ExploreSubstate:exit()
    self.owner.game.player.running = false
end

function ExploreSubstate:update()
    local game = self.owner.game
    local player = game.player

    if self.owner.fieldArrival then
        local arrival = self.owner.fieldArrival
        self.owner.fieldArrival = nil
        SourceEvents.worldHook("beforeSpawn", game, {actors = game.npcManager.motion:snapshot()})
        SourceEvents.worldHook("onEnter", game, {fieldArrival = arrival.kind})
        if KantoWorld then
            KantoWorld.onEnter(game, {fieldArrival = arrival.kind})
        end
        if not self.owner:isTop() then
            return
        end
    end
    if player.pendingBoulder then
        local push = player.pendingBoulder
        player.pendingBoulder = nil
        FieldTravelState.openPush(game, push.npc, push.direction)
        return
    end

    -- Edge-exit doors (Gen 2/3 gates): the player walked into the room
    -- edge from an exit mat during the previous handleInput
    if player.pendingEdgeDoor then
        local door = player.pendingEdgeDoor
        player.pendingEdgeDoor = nil
        self.machine:change("doorWarp", door)
        return
    end

    -- Intro storyline triggers (cutscene dialogs, the scripted rival
    -- battle); they preempt doors and encounters
    if player.fieldStep then
        local px, py = player:getPixelCenter()
        local mw, mh = getMapPixelSize()
        game.camera:follow(px, py, mw, mh)
        game.camera:apply()
        gfx.sprite.update()
        self.owner:_presentedWorld()
        if not player.fieldStep and player.stepJustFinished then
            game.session:daycareStep()
        end
        return
    end
    if Story.check(game, self.owner) then return end
    if SourceEvents.worldHook("explore", game) then return end

    -- Door warp check: landing on a step-triggered door/stairs tile
    if player.stepJustFinished then
        local door = currentZone:getDoorAt(player.gridX, player.gridY)
        if door then
            self.machine:change("doorWarp", door)
            return
        end
    end

    if PewterWorld and PewterWorld.trySight(game) then return end

    -- Wild encounter check (player.stepJustFinished was set during the
    -- previous frame's sprite update, exactly like the old main loop).
    -- No pokemon yet (pre-starter intro) = no wild battles.
    if player.stepJustFinished and not DEBUG_FLAGS.noEncounters
       and game.session:party():firstUsable()
       and not SourceEvents.worldHook("suppressEncounters", game) then
        local session,zone=game.session,currentZone
        local plan,reason=FieldEncounters.prepare({session=session,party=session:party(),zone=zone,x=player.gridX,y=player.gridY})
        if plan then
            local ok, result, gap = FieldEncounters.resolve(plan)
            if gap then
                game.lastEncounterAttempt = {kind="none", reason="unimplemented-acquisition", gap=gap}
                game.lastEncounterSession = session
                game.fieldAbilityGaps = game.fieldAbilityGaps or {}
                game.fieldAbilityGaps[#game.fieldAbilityGaps + 1] = gap
                if #game.fieldAbilityGaps > 12 then
                    table.remove(game.fieldAbilityGaps, 1)
                end
                print("FIELD ability gap: " .. gap.hook)
                player.stepJustFinished = false
                self.owner.machine:push("dialog", {"But it failed!"})
                return
            end
            assert(ok, result)
            game.lastEncounterAttempt=result.receipt;game.lastEncounterSession=session
            if result.kind=="encounter"then
                local enemy=result.pokemon
                local px,py=player:getPixelCenter();local ox,oy=gfx.getDrawOffset()
                local rootMachine=self.owner.machine
                self.machine:change("irisOut",px+ox,py+oy,function()
                    if game.session~=session or currentZone~=zone or game.player~=player then return false,"stale-wild-transition"end
                    assert(FieldBattle.start(game,game:getPlayerPokemon(),enemy,nil))
                end)
                return
            end
        else
            assert(reason=="ineligible-terrain"or reason=="disabled-rate",reason)
        end
    end

    if game.npcManager.motion:tick()then return end

    playdate.frameTimer.updateTimers()

    local px, py = player:getPixelCenter()
    local mw, mh = getMapPixelSize()
    game.camera:follow(px, py, mw, mh)
    game.camera:apply()
    -- Only a cell completed by this ordinary exploration pass earns XP.
    -- A sprite-only/script pass may leave stepJustFinished set on entry;
    -- overlays, idle callbacks and stale completion flags must not earn it.
    local wasMoving = player.isMoving and player:updatesEnabled()
    gfx.sprite.update()
    if wasMoving and not player.isMoving and player.stepJustFinished then
        game.session:daycareStep()
    end
    self.owner:_presentedWorld()
end

function ExploreSubstate:interact()
    local game = self.owner.game
    local player = game.player
    local fx, fy = player:getFacingTile()
    if Story.tryInteract(game, fx, fy) then
        return
    end
    if KantoWorld and KantoWorld.tryInteract(game) then
        return
    end
    local npc = game.npcManager:getNPCAt(fx, fy)
    if npc then
        npc:faceTowards(player.gridX, player.gridY)
        local rootMachine = self.owner.machine
        local lines = npc:getDialogLines()
        local battleData = npc:getBattleData()
        if battleData and not npc:hasInteracted() and game.session:party():firstUsable() then
            local session=game.session
            rootMachine:push("dialog", lines, function()
                if game.session ~= session or rootMachine:current() ~= self.owner
                    or not Specimen.isActiveSession(session) or not session:party():firstUsable() then
                    return false, "stale-trainer-creation"
                end
                local enemy = assert(Specimen.createForSession(session,battleData.species,battleData.level,"trainer",
                    Specimen.blueTrainerPolicy(assert(npc.trainerID,"missing-authored-trainer-identity"))))
                assert(FieldBattle.start(game, game:getPlayerPokemon(), enemy, npc))
            end)
        else
            rootMachine:push("dialog", lines)
        end
    end
end

function ExploreSubstate:handleInput()
    local game = self.owner.game
    local player = game.player
    local direction = playdate.buttonIsPressed(playdate.kButtonUp)
        or playdate.buttonIsPressed(playdate.kButtonDown)
        or playdate.buttonIsPressed(playdate.kButtonLeft)
        or playdate.buttonIsPressed(playdate.kButtonRight)
    local action, running = self.gestures:step(playdate.buttonIsPressed(playdate.kButtonA),
        playdate.buttonIsPressed(playdate.kButtonB), direction, player.isMoving)
    self.pendingAction = self.pendingAction or action
    player.running = running and not self.pendingAction
    if self.pendingAction then
        if player.isMoving or player.stepJustFinished then
            return
        end
        local selected = self.pendingAction
        self.pendingAction = nil
        if selected == "registered" then
            BagState.useRegistered(game)
        elseif selected == "pause" then
            game.npcManager.motion:cancelPending()
            self.owner.machine:push("pause")
        else
            self:interact()
        end
        return
    end
    if player.isMoving or self.gestures.phase == "a" or self.gestures.phase == "consumed" then
        return
    end
    if playdate.buttonIsPressed(playdate.kButtonUp) then
        player:tryMove(0, -1)
    elseif playdate.buttonIsPressed(playdate.kButtonDown) then
        player:tryMove(0, 1)
    elseif playdate.buttonIsPressed(playdate.kButtonLeft) then
        player:tryMove(-1, 0)
    elseif playdate.buttonIsPressed(playdate.kButtonRight) then
        player:tryMove(1, 0)
    end
end

-- ============================================================
-- IRIS-OUT substate (overworld -> battle transition)
-- ============================================================

Class("IrisOutSubstate"):extends(State)

local IRIS_DURATION <const> = 15
local IRIS_MAX_RADIUS <const> = 260

function IrisOutSubstate:init(owner)
    IrisOutSubstate.super.init(self, "irisOut")
    self.owner = owner
end

function IrisOutSubstate:enter(cx, cy, callback)
    self.timer = 0
    self.cx = cx
    self.cy = cy
    self.callback = callback
end

function IrisOutSubstate:update()
    self.timer = self.timer + 1
    playdate.frameTimer.updateTimers()

    local game = self.owner.game
    local px, py = game.player:getPixelCenter()
    local mw, mh = getMapPixelSize()
    game.camera:follow(px, py, mw, mh)
    game.camera:apply()
    gfx.sprite.update()
    self.owner:_presentedWorld()

    if self.timer >= IRIS_DURATION then
        local callback = self.callback
        self.callback = nil
        if callback then callback() end
    end
end

function IrisOutSubstate:draw()
    local game = self.owner.game
    game.camera:reset()

    local progress = self.timer / IRIS_DURATION
    local radius = math.floor(IRIS_MAX_RADIUS * (1 - progress))
    if radius > 0 then
        local stencilImg = gfx.image.new(400, 240, gfx.kColorWhite)
        gfx.pushContext(stencilImg)
            gfx.setColor(gfx.kColorBlack)
            gfx.fillCircleAtPoint(self.cx, self.cy, radius)
        gfx.popContext()
        gfx.setStencilImage(stencilImg)
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(0, 0, 400, 240)
        gfx.clearStencil()
    else
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(0, 0, 400, 240)
    end

    game.camera:apply()
end

-- ============================================================
-- DOOR-WARP substate (zone -> zone transition through a door def)
-- ============================================================

Class("DoorWarpSubstate"):extends(State)

local DOOR_FADE_FRAMES <const> = 12

function DoorWarpSubstate:init(owner)
    DoorWarpSubstate.super.init(self, "doorWarp")
    self.owner = owner
end

function DoorWarpSubstate:enter(door)
    if VermilionStory and not VermilionStory.allowDoor(self.owner.game,door) then
        self.owner.game.player.stepJustFinished=false
        self.owner.game.player.pendingEdgeDoor=nil
        self.owner.game.player.pendingConnection=nil
        self.machine:change("explore")
        return
    end
    self.timer = 0
    self.door = door
end

function DoorWarpSubstate:update()
    self.timer = self.timer + 1
    playdate.frameTimer.updateTimers()
    gfx.sprite.update()
    self.owner:_presentedWorld()

    if self.timer >= DOOR_FADE_FRAMES then
        local door = self.door
        self.door = nil
        local facing=door.preserveFacing and self.owner.game.player.facing or door.facing
        local provider = WorldDeltas.definitionProvider()
        local destination = provider and provider:hasKey(door.to) and provider:descriptor(door.to).id or door.to
        SourceEvents.worldHook("onLeave", self.owner.game, destination, door)
        switchZone(door.to)
        self.owner.machine:change("overworld", {
            entry = { x = door.toX, y = door.toY, facing = facing },
            fromDoor = not door.connection,
        })
        -- Connections skip Player's ordinary completed-step animation.
        if door.connection then
            self.owner.game.session:daycareStep()
        end
    end
end

function DoorWarpSubstate:draw()
    -- GB-style palette fade: light -> dark -> black over the whole screen
    local game = self.owner.game
    game.camera:reset()

    local t = self.timer / DOOR_FADE_FRAMES
    if t < 1 / 3 then
        Shade.set(Shade.LIGHT)
    elseif t < 2 / 3 then
        Shade.set(Shade.DARK)
    else
        Shade.set(Shade.BLACK)
    end
    gfx.fillRect(0, 0, 400, 240)
    Shade.reset()

    game.camera:apply()
end

-- ============================================================
-- OVERWORLD top-level state
-- ============================================================

Class("OverworldState"):extends(State)

function OverworldState:init(game)
    OverworldState.super.init(self, "overworld")
    self.game = game
    self.builtZone = nil   -- zone the current world/sprites were built for
    self.savedPos = nil    -- player position remembered across battles

    self.sub = StateMachine()
    self.sub:register("explore", ExploreSubstate(self))
    self.sub:register("irisOut", IrisOutSubstate(self))
    self.sub:register("doorWarp", DoorWarpSubstate(self))
end

-- opts.respawn = true forces the zone spawn point (blackout, zone switch);
-- opts.entry = {x, y, facing} places the player exactly there (door warps)
function OverworldState:enter(opts)
    self.presentationVisit = nil
    local game = self.game
    if game.lastEncounterSession~=game.session then
        game.lastEncounterSession,game.lastEncounterAttempt=nil,nil
    end

    local pos = currentZone.spawn
    local saved = self.savedPos
    local respawn = opts and opts.respawn
    local entry = opts and opts.entry
    local retainedVisit = saved and saved.zone == currentZone and not respawn and not entry
        and self.builtSession == game.session and not (opts and opts.fieldReloadReason)
    if entry then
        pos = entry
    elseif saved and saved.zone == currentZone and not respawn then
        pos = saved
    end

    -- Opted in by root only. A retained visit returns from battle unchanged;
    -- real entries/reloads restore source blocks before constructing the view.
    if game.fieldWorld and not (opts and opts.fieldRestore)
        and self.builtSession == game.session and self.builtZone
        and (self.builtZone ~= currentZone or entry or respawn or (opts and opts.fieldReloadReason)) then
        local actors = opts and opts.actors
        if not actors and self.builtZone == currentZone then
            actors = game.npcManager.motion:snapshot()
        end
        local reason = opts and opts.fieldReloadReason or (self.builtZone == currentZone and "reload" or "map")
        local accepted, problem = game.fieldWorld.enter(game, self.builtZone.stableID,
            {zone_id = currentZone.stableID, x = pos.x, y = pos.y, facing = pos.facing or "down"},
            actors or WorldMotionData.empty(), reason)
        assert(accepted, problem)
    end
    gfx.sprite.removeAll()
    setupOverworld()
    self.builtZone, self.builtSession = currentZone, game.session

    game.player = Player(pos.x, pos.y, currentZone.collision, game.npcManager)
    if pos.facing then
        game.player.facing = pos.facing
        game.player:updateSprite()
    end

    local actorRecord=opts and opts.actors
    local reconcile=false
    if not actorRecord and not entry and not respawn and self.savedActorsSession==game.session
        and self.savedActors and self.savedActors.zone_id==currentZone.stableID then
        actorRecord=self.savedActors;reconcile=true
    end
    local context = {actors=actorRecord,reconcile=reconcile}
    SourceEvents.worldHook("beforeSpawn", game, context)
    currentZone:spawnNPCs(game.npcManager)
    game.npcManager.motion:attach(game,currentZone,context.actors,context.reconcile)
    SourceEvents.worldHook("onEnter", game, opts)

    -- An empty session remains empty until an explicit acquisition.

    local px, py = game.player:getPixelCenter()
    local mw, mh = getMapPixelSize()
    game.camera:snapTo(px, py, mw, mh)

    self.sub:change("explore")
    -- StateMachine queues this overlay until enter/change completes, so the
    -- first Mart event is top before ordinary input, doors or encounters run.
    if KantoWorld then KantoWorld.onEnter(game,opts) end
    self:_beginPresentationVisit(getOverworldView())
    if not retainedVisit and not (opts and opts.fieldRestore) then
        local travel = FieldTravel.enter(game.session:fieldTravelData(), currentZone.stableID,
            game.session:fieldTravelData().mode)
        assert(game.session:captureTraversal({world = WorldDeltas.export(),
            location = {zone_id = currentZone.stableID, x = pos.x, y = pos.y, facing = pos.facing or "down"},
            actors = game.npcManager.motion:snapshot(), fieldTravel = travel}))
    end
end

function OverworldState:exit()
    self.presentationVisit = nil
    self.builtView = nil
    self.savedActors=self.game.npcManager.motion:snapshot();self.savedActorsSession=self.game.session
    self:resume()
    local player = self.game.player
    if player then
        self.savedPos = {
            x = player.gridX, y = player.gridY,
            facing = player.facing, zone = self.builtZone,
        }
    end
end

-- Menus/dialogue retain world rendering and tile animation, while movement,
-- encounter/door triggers and actor update callbacks wait for the overlay.
function OverworldState:pause()
    if self.game.player then
        self.game.player.running = false
    end
    local explore = self.sub and self.sub:get("explore")
    if explore then
        if explore.gestures then
            explore.gestures:reset()
        end
        explore.pendingAction = nil
    end
    self.pausedSprites = {}
    local function suspend(sprite)
        if sprite and sprite.updatesEnabled then
            self.pausedSprites[#self.pausedSprites + 1] = {sprite = sprite, enabled = sprite:updatesEnabled()}
            sprite:setUpdatesEnabled(false)
        end
    end
    suspend(self.game.player)
    for _, npc in ipairs(self.game.npcManager.npcs) do suspend(npc) end
end

function OverworldState:resume()
    for _, item in ipairs(self.pausedSprites or {}) do item.sprite:setUpdatesEnabled(item.enabled) end
    self.pausedSprites = nil
    if self.presentationVisit then self.presentationVisit.pending = true end
end

function OverworldState:update()
    updateOverworldAnimations()
    if self:isTop() then
        self.sub:update()
    else
        self.game.camera:apply()
        gfx.sprite.update()
        self:_presentedWorld()
    end
end

function OverworldState:handleInput()
    self.sub:handleInput()
end

function OverworldState:draw()
    self.sub:draw()
end

-- A visit owns the view and actors built by enter. Presentation requests never
-- survive an exit/session replacement or target a disposed/replaced view.
function OverworldState:_beginPresentationVisit(view)
    assert(view and view.zone == self.builtZone and not view.disposed, "world presentation requires the actual live view")
    self.builtView = view
    if self.presentationMachine ~= self.machine then
        if self.presentationMachine then self.presentationMachine:off("changed", self.presentationListener) end
        local machine = self.machine
        self.presentationListener = function(kind)
            -- A nested overlay can resume another overlay while still exposing
            -- the same world. Its old fullscreen pixels must also be erased.
            local visit = self.presentationVisit
            if kind == "pop" and self.machine == machine and self:_ownsPresentation(visit) then visit.pending = true end
        end
        self.presentationMachine = machine
        machine:on("changed", self.presentationListener)
    end
    self.presentationVisit = { view = view, zone = self.builtZone,
        player = self.game.player, session = self.game.session, pending = true }
end

function OverworldState:_ownsPresentation(visit)
    return visit and self.presentationVisit == visit and self.builtView == visit.view
        and not visit.view.disposed and visit.zone == self.builtZone and visit.zone == currentZone
        and self.game.player == visit.player and self.game.session == visit.session
        and self.machine and self.machine.stack[1] == self
end

function OverworldState:_presentedWorld()
    local visit = self.presentationVisit
    if self:_ownsPresentation(visit) then visit.pending = false end
end

-- Called once after input, before root draw; never from draw. SDK Lua exposes
-- one combined callback-update/redraw pass. Suppress callbacks only for this
-- pending entry/resume presentation, restoring every original flag on failure.
function OverworldState:flushPendingPresentation()
    local visit = self.presentationVisit
    if not visit or not visit.pending then return false end
    if not self:_ownsPresentation(visit) then visit.pending = false; return false end
    local states = {}
    local ox, oy = gfx.getDrawOffset()
    local ok, problem = pcall(function()
        self.game.camera:apply()
        for _, sprite in ipairs(gfx.sprite.getAllSprites()) do
            local enabled = sprite:updatesEnabled()
            states[#states + 1] = { sprite = sprite, enabled = enabled }
            if enabled then sprite:setUpdatesEnabled(false) end
        end
        gfx.sprite.addDirtyRect(0, 0, 400, 240)
        gfx.sprite.update()
    end)
    for _, state in ipairs(states) do state.sprite:setUpdatesEnabled(state.enabled) end
    if not ok then gfx.setDrawOffset(ox, oy); error(problem, 0) end
    if self.presentationVisit == visit then visit.pending = false end
    return true
end
